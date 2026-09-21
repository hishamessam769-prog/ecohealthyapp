begin;

alter table public.organizations add column if not exists is_demo boolean not null default false;
alter table public.branches add column if not exists is_demo boolean not null default false;
alter table public.departments add column if not exists is_demo boolean not null default false;
alter table public.teams add column if not exists is_demo boolean not null default false;
alter table public.audit_logs add column if not exists is_demo boolean not null default false;

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  old_json jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  new_json jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  source_json jsonb := coalesce(new_json, old_json, '{}'::jsonb);
  v_org_id uuid;
  v_entity_id uuid;
  v_actor uuid;
  v_is_demo boolean := coalesce((source_json ->> 'is_demo')::boolean, false);
begin
  v_org_id := case when tg_table_name = 'organizations' then nullif(source_json ->> 'id', '')::uuid else nullif(source_json ->> 'organization_id', '')::uuid end;
  v_entity_id := nullif(source_json ->> 'id', '')::uuid;
  v_actor := coalesce(auth.uid(), nullif(source_json ->> 'updated_by', '')::uuid, nullif(source_json ->> 'created_by', '')::uuid,
    nullif(source_json ->> 'assigned_by', '')::uuid, nullif(source_json ->> 'granted_by', '')::uuid, nullif(source_json ->> 'invited_by', '')::uuid);
  insert into public.audit_logs(organization_id,actor_user_id,action,entity_type,entity_id,old_values,new_values,request_id,is_demo)
  values(v_org_id,v_actor,lower(tg_op),tg_table_name,v_entity_id,old_json,new_json,nullif(current_setting('request.headers',true),'')::jsonb ->> 'x-request-id',v_is_demo);
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_demo and (auth.role() = 'service_role' or current_user in ('postgres','supabase_admin')) then return old; end if;
  raise exception 'audit_logs are append-only';
end;
$$;

create table public.schema_versions (
  version integer primary key,
  name text not null unique,
  installed_at timestamptz not null default now(),
  checksum text
);

create table public.attachments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  entity_type text not null,
  entity_id uuid not null,
  file_name text not null,
  storage_path text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  visibility text not null default 'internal' check (visibility in ('internal','customer','restricted')),
  uploaded_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, storage_path)
);

create table public.domain_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid references public.profiles(id),
  idempotency_key text not null,
  published_at timestamptz,
  is_demo boolean not null default false,
  unique (organization_id, idempotency_key)
);

create table public.notification_providers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  channel text not null check (channel in ('in_app','email','web_push','whatsapp')),
  provider_code text not null,
  display_name text not null,
  configuration jsonb not null default '{}'::jsonb,
  is_mock boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, channel, provider_code)
);

create table public.notification_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  event_type text not null,
  channel text not null check (channel in ('in_app','email','web_push','whatsapp')),
  locale text not null default 'ar' check (locale in ('ar','en')),
  subject_template text,
  body_template text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, event_type, channel, locale)
);

create table public.notification_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  domain_event_id uuid references public.domain_events(id) on delete cascade,
  recipient_user_id uuid references public.profiles(id),
  recipient_address text,
  channel text not null check (channel in ('in_app','email','web_push','whatsapp')),
  template_id uuid references public.notification_templates(id),
  related_type text,
  related_id uuid,
  subject text,
  body text not null,
  status text not null default 'queued' check (status in ('queued','processing','sent','delivered','failed','cancelled')),
  scheduled_at timestamptz not null default now(),
  sent_at timestamptz,
  delivered_at timestamptz,
  failed_at timestamptz,
  retry_count integer not null default 0 check (retry_count >= 0),
  provider_message_id text,
  failure_reason text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, channel, idempotency_key)
);

create table public.notification_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  message_id uuid not null references public.notification_messages(id) on delete cascade,
  attempt_number integer not null check (attempt_number > 0),
  provider_code text not null,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb not null default '{}'::jsonb,
  status text not null check (status in ('sent','delivered','failed')),
  error_message text,
  attempted_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (message_id, attempt_number)
);

create table public.approval_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  entity_type text not null,
  entity_id uuid not null,
  approval_type text not null,
  requested_by uuid not null references public.profiles(id),
  assigned_to uuid references public.profiles(id),
  threshold_amount numeric(18,2),
  status text not null default 'pending' check (status in ('pending','approved','rejected','returned','cancelled')),
  decision_reason text,
  decided_by uuid references public.profiles(id),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  is_demo boolean not null default false,
  check (decided_by is null or decided_by <> requested_by)
);

create index attachments_entity_idx on public.attachments(organization_id, entity_type, entity_id);
create index domain_events_unpublished_idx on public.domain_events(occurred_at) where published_at is null;
create index notification_messages_queue_idx on public.notification_messages(status, scheduled_at);
create index notification_messages_recipient_idx on public.notification_messages(recipient_user_id, created_at desc);
create index approval_requests_inbox_idx on public.approval_requests(organization_id, assigned_to, status, requested_at desc);

create trigger notification_providers_set_updated_at before update on public.notification_providers for each row execute function public.set_updated_at();
create trigger notification_templates_set_updated_at before update on public.notification_templates for each row execute function public.set_updated_at();
create trigger notification_messages_set_updated_at before update on public.notification_messages for each row execute function public.set_updated_at();
create trigger audit_approval_requests after insert or update or delete on public.approval_requests for each row execute function public.audit_row_change();

create or replace function public.enqueue_domain_event(
  p_organization_id uuid,
  p_branch_id uuid,
  p_event_type text,
  p_aggregate_type text,
  p_aggregate_id uuid,
  p_payload jsonb,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_is_demo boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_id uuid;
begin
  insert into public.domain_events (
    organization_id, branch_id, event_type, aggregate_type, aggregate_id,
    payload, actor_user_id, idempotency_key, is_demo
  ) values (
    p_organization_id, p_branch_id, p_event_type, p_aggregate_type, p_aggregate_id,
    coalesce(p_payload, '{}'::jsonb), p_actor_user_id, p_idempotency_key, p_is_demo
  )
  on conflict (organization_id, idempotency_key) do update
    set idempotency_key = excluded.idempotency_key
  returning id into v_event_id;
  return v_event_id;
end;
$$;

create or replace function public.process_mock_notifications(p_limit integer default 100)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_message record;
begin
  for v_message in
    select m.id, m.retry_count
    from public.notification_messages m
    join public.notification_providers p
      on p.organization_id = m.organization_id and p.channel = m.channel
    where m.status in ('queued','failed') and m.scheduled_at <= now()
      and p.is_active and p.is_mock
    order by m.scheduled_at
    limit greatest(p_limit, 0)
    for update of m skip locked
  loop
    insert into public.notification_attempts (
      message_id, attempt_number, provider_code, status, response_payload
    ) values (
      v_message.id, v_message.retry_count + 1, 'mock', 'delivered', '{"mock":true}'::jsonb
    );
    update public.notification_messages
    set status = 'delivered', sent_at = coalesce(sent_at, now()), delivered_at = now(),
        retry_count = retry_count + 1, provider_message_id = 'mock-' || id::text,
        failure_reason = null, failed_at = null
    where id = v_message.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

alter table public.attachments enable row level security;
alter table public.domain_events enable row level security;
alter table public.notification_providers enable row level security;
alter table public.notification_templates enable row level security;
alter table public.notification_messages enable row level security;
alter table public.notification_attempts enable row level security;
alter table public.approval_requests enable row level security;

create policy attachments_select_scope on public.attachments for select to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)));
create policy attachments_write_scope on public.attachments for all to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)))
with check (public.is_organization_member(organization_id) and uploaded_by = auth.uid() and (branch_id is null or public.can_access_branch(organization_id, branch_id)));

create policy domain_events_select_audit on public.domain_events for select to authenticated
using (public.has_permission('audit.view', organization_id));
create policy notifications_select_own on public.notification_messages for select to authenticated
using (recipient_user_id = auth.uid() or public.has_permission('notifications.manage_routes', organization_id));
create policy notifications_update_own on public.notification_messages for update to authenticated
using (recipient_user_id = auth.uid()) with check (recipient_user_id = auth.uid());
create policy notification_attempts_select_manager on public.notification_attempts for select to authenticated
using (exists (select 1 from public.notification_messages m where m.id = message_id and (m.recipient_user_id = auth.uid() or public.has_permission('notifications.manage_routes', m.organization_id))));
create policy notification_config_manage on public.notification_providers for all to authenticated
using (public.has_permission('notifications.manage_routes', organization_id))
with check (public.has_permission('notifications.manage_routes', organization_id));
create policy notification_templates_manage on public.notification_templates for all to authenticated
using (public.has_permission('notifications.manage_routes', organization_id))
with check (public.has_permission('notifications.manage_routes', organization_id));
create policy approvals_select_scope on public.approval_requests for select to authenticated
using (requested_by = auth.uid() or assigned_to = auth.uid() or public.has_permission('approvals.view', organization_id));
create policy approvals_act_scope on public.approval_requests for update to authenticated
using (assigned_to = auth.uid() and public.has_permission('approvals.act', organization_id))
with check (decided_by = auth.uid() and requested_by <> auth.uid());

insert into public.schema_versions(version, name) values (4, 'shared_events_notifications');

commit;
