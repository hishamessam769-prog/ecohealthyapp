begin;

create type public.financial_period_status as enum ('open', 'closing', 'closed', 'reopened');

create table public.app_settings (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  key text not null,
  value jsonb not null,
  description text,
  is_sensitive boolean not null default false,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_settings_key_format check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint app_settings_org_key_unique unique (organization_id, key)
);

create table public.financial_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  starts_on date not null,
  ends_on date not null,
  status public.financial_period_status not null default 'open',
  closed_by uuid references public.profiles(id),
  closed_at timestamptz,
  reopened_by uuid references public.profiles(id),
  reopened_at timestamptz,
  reopen_reason text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_period_dates check (ends_on >= starts_on),
  constraint financial_period_org_code_unique unique (organization_id, code)
);

create table public.audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references public.organizations(id),
  actor_user_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_values jsonb,
  new_values jsonb,
  reason text,
  approval_reference uuid,
  request_id text,
  ip_address inet,
  session_info jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index app_settings_org_key_idx on public.app_settings(organization_id, key);
create index financial_periods_org_dates_idx on public.financial_periods(organization_id, starts_on, ends_on, status);
create index audit_logs_org_time_idx on public.audit_logs(organization_id, occurred_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, occurred_at desc);
create index audit_logs_actor_idx on public.audit_logs(actor_user_id, occurred_at desc);

create trigger app_settings_set_updated_at before update on public.app_settings for each row execute function public.set_updated_at();
create trigger financial_periods_set_updated_at before update on public.financial_periods for each row execute function public.set_updated_at();

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
begin
  v_org_id := case
    when tg_table_name = 'organizations' then nullif(source_json ->> 'id', '')::uuid
    else nullif(source_json ->> 'organization_id', '')::uuid
  end;
  v_entity_id := nullif(source_json ->> 'id', '')::uuid;
  v_actor := coalesce(
    auth.uid(),
    nullif(source_json ->> 'updated_by', '')::uuid,
    nullif(source_json ->> 'created_by', '')::uuid,
    nullif(source_json ->> 'assigned_by', '')::uuid,
    nullif(source_json ->> 'granted_by', '')::uuid,
    nullif(source_json ->> 'invited_by', '')::uuid
  );

  insert into public.audit_logs (
    organization_id, actor_user_id, action, entity_type, entity_id,
    old_values, new_values, request_id
  ) values (
    v_org_id, v_actor, lower(tg_op), tg_table_name, v_entity_id,
    old_json, new_json, nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-request-id'
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_logs are append-only';
end;
$$;

create trigger audit_logs_no_update_or_delete
before update or delete on public.audit_logs
for each row execute function public.prevent_audit_log_mutation();

create trigger audit_organizations after insert or update or delete on public.organizations for each row execute function public.audit_row_change();
create trigger audit_memberships after insert or update or delete on public.organization_memberships for each row execute function public.audit_row_change();
create trigger audit_branches after insert or update or delete on public.branches for each row execute function public.audit_row_change();
create trigger audit_departments after insert or update or delete on public.departments for each row execute function public.audit_row_change();
create trigger audit_teams after insert or update or delete on public.teams for each row execute function public.audit_row_change();
create trigger audit_roles after insert or update or delete on public.roles for each row execute function public.audit_row_change();
create trigger audit_user_roles after insert or update or delete on public.user_roles for each row execute function public.audit_row_change();
create trigger audit_branch_access after insert or update or delete on public.user_branch_access for each row execute function public.audit_row_change();
create trigger audit_app_settings after insert or update or delete on public.app_settings for each row execute function public.audit_row_change();
create trigger audit_financial_periods after insert or update or delete on public.financial_periods for each row execute function public.audit_row_change();

alter table public.app_settings enable row level security;
alter table public.financial_periods enable row level security;
alter table public.audit_logs enable row level security;

create policy app_settings_select_member on public.app_settings for select to authenticated
using (public.is_organization_member(organization_id) and (not is_sensitive or public.has_permission('settings.manage', organization_id)));
create policy app_settings_manage on public.app_settings for all to authenticated
using (public.has_permission('settings.manage', organization_id))
with check (public.has_permission('settings.manage', organization_id));

create policy financial_periods_select_member on public.financial_periods for select to authenticated
using (public.is_organization_member(organization_id));
create policy financial_periods_insert_manager on public.financial_periods for insert to authenticated
with check (public.has_permission('finance.period_close', organization_id));
create policy financial_periods_update_manager on public.financial_periods for update to authenticated
using (
  (status <> 'closed' and public.has_permission('finance.period_close', organization_id))
  or public.has_permission('finance.period_reopen', organization_id)
)
with check (
  public.has_permission('finance.period_close', organization_id)
  or public.has_permission('finance.period_reopen', organization_id)
);

create policy audit_logs_select_authorized on public.audit_logs for select to authenticated
using (organization_id is not null and public.has_permission('audit.view', organization_id));

commit;
