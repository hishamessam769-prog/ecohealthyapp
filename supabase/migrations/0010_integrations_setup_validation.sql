begin;

create table public.system_installations(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null unique references public.organizations(id) on delete cascade,
  installed_by uuid not null references public.profiles(id),
  installed_at timestamptz not null default now(),
  application_version text not null default '1.0.0',
  is_demo boolean not null default false
);

create table public.integration_accounts(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null check(provider in('google_calendar','email','whatsapp','web_push','mock')),display_name text not null,
  status text not null default 'disconnected' check(status in('disconnected','connected','error','revoked')),configuration jsonb not null default '{}'::jsonb,
  encrypted_secret_reference text,last_connected_at timestamptz,last_error text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(organization_id,provider,display_name)
);
create table public.calendar_events(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
  session_id uuid not null references public.doctor_sessions(id) on delete cascade,integration_account_id uuid references public.integration_accounts(id),
  google_calendar_event_id text,google_calendar_id text,google_meet_url text,google_sync_status text not null default 'pending' check(google_sync_status in('pending','synced','failed','cancelled')),
  google_sync_error text,last_synced_at timestamptz,google_event_etag text,idempotency_key text not null,provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(organization_id,idempotency_key),unique(session_id)
);
create table public.retry_queue(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
  job_type text not null,related_type text not null,related_id uuid not null,payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check(status in('queued','processing','completed','failed','dead_letter')),attempt_count integer not null default 0,max_attempts integer not null default 5,
  run_after timestamptz not null default now(),last_error text,idempotency_key text not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(organization_id,idempotency_key)
);
create index retry_queue_ready_idx on public.retry_queue(status,run_after) where status in('queued','failed');
create trigger integration_accounts_set_updated_at before update on public.integration_accounts for each row execute function public.set_updated_at();
create trigger calendar_events_set_updated_at before update on public.calendar_events for each row execute function public.set_updated_at();
create trigger retry_queue_set_updated_at before update on public.retry_queue for each row execute function public.set_updated_at();
create trigger audit_integration_accounts after insert or update or delete on public.integration_accounts for each row execute function public.audit_row_change();
create trigger audit_calendar_events after insert or update or delete on public.calendar_events for each row execute function public.audit_row_change();

create or replace function public.claim_initial_setup(
  p_user_id uuid,p_company_name text,p_company_code text,p_admin_name text
)
returns table(organization_id uuid,branch_id uuid)
language plpgsql security definer set search_path='' set row_security=off as $$
declare v_org_id uuid;v_branch_id uuid;v_role_id uuid;
begin
  perform pg_advisory_xact_lock(814205001);
  if exists(select 1 from public.system_installations) then raise exception 'setup is already completed'; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'admin auth user does not exist'; end if;
  update public.profiles set full_name=p_admin_name,is_active=true where id=p_user_id;
  insert into public.organizations(code,name,created_by) values(upper(p_company_code),p_company_name,p_user_id) returning id into v_org_id;
  insert into public.organization_memberships(organization_id,user_id,status,invited_by,activated_at) values(v_org_id,p_user_id,'active',p_user_id,now());
  select r.id into v_role_id from public.roles r where r.code='ceo_super_admin' and r.organization_id is null;
  insert into public.user_roles(organization_id,user_id,role_id,assigned_by) values(v_org_id,p_user_id,v_role_id,p_user_id);
  insert into public.branches(organization_id,code,name,status,created_by) values(v_org_id,'MAIN','الفرع الرئيسي','active',p_user_id) returning id into v_branch_id;
  insert into public.user_branch_access(organization_id,user_id,branch_id,access_level,granted_by) values(v_org_id,p_user_id,v_branch_id,'manage',p_user_id);
  insert into public.app_settings(organization_id,key,value,description,updated_by) values
    (v_org_id,'organization.timezone','"Africa/Cairo"'::jsonb,'Operational timezone',p_user_id),
    (v_org_id,'organization.base_currency','"EGP"'::jsonb,'Base currency',p_user_id);
  insert into public.notification_providers(organization_id,channel,provider_code,display_name,is_mock,is_active) values
    (v_org_id,'in_app','native','In-App',true,true),(v_org_id,'email','mock','Mock Email',true,true),(v_org_id,'whatsapp','mock','Mock WhatsApp',true,true);
  insert into public.system_installations(organization_id,installed_by) values(v_org_id,p_user_id);
  organization_id:=v_org_id;branch_id:=v_branch_id;return next;
end; $$;
revoke all on function public.claim_initial_setup(uuid,text,text,text) from public;
grant execute on function public.claim_initial_setup(uuid,text,text,text) to service_role;

create or replace function public.create_mock_calendar_event(p_session_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_session public.doctor_sessions;v_event_id uuid;v_key text;
begin
  select * into v_session from public.doctor_sessions where id=p_session_id;
  if v_session.id is null or v_session.status not in('confirmed','calendar_pending','scheduled') then raise exception 'confirmed session required'; end if;
  v_key:='calendar.session:'||v_session.id::text;
  insert into public.calendar_events(organization_id,session_id,google_calendar_event_id,google_calendar_id,google_meet_url,google_sync_status,last_synced_at,idempotency_key,provider_payload,is_demo)
  values(v_session.organization_id,v_session.id,'mock-event-'||v_session.id::text,'mock-calendar','https://meet.google.com/mock-'||substr(replace(v_session.id::text,'-',''),1,12),'synced',now(),v_key,
    jsonb_build_object('mock',true,'starts_at',v_session.scheduled_start,'ends_at',v_session.scheduled_end),v_session.is_demo)
  on conflict(organization_id,idempotency_key) do update set last_synced_at=excluded.last_synced_at returning id into v_event_id;
  update public.doctor_sessions set status='scheduled' where id=v_session.id and status in('confirmed','calendar_pending');
  return v_event_id;
end; $$;

create or replace function public.queue_calendar_on_confirmation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status in('confirmed','calendar_pending') and old.status is distinct from new.status then
    insert into public.retry_queue(organization_id,job_type,related_type,related_id,payload,idempotency_key,is_demo)
    values(new.organization_id,'calendar.sync','doctor_session',new.id,jsonb_build_object('action','upsert'),'calendar.sync:'||new.id::text,new.is_demo)
    on conflict(organization_id,idempotency_key) do nothing;
  elsif new.status in('customer_cancelled','doctor_cancelled') and old.status is distinct from new.status then
    update public.calendar_events set google_sync_status='cancelled',last_synced_at=now() where session_id=new.id;
  end if;
  return new;
end; $$;
create trigger session_calendar_outbox after update of status on public.doctor_sessions for each row execute function public.queue_calendar_on_confirmation();

alter table public.system_installations enable row level security;
alter table public.integration_accounts enable row level security;
alter table public.calendar_events enable row level security;
alter table public.retry_queue enable row level security;
create policy installation_admin_read on public.system_installations for select to authenticated using(public.has_permission('settings.manage',organization_id));
create policy integrations_manage on public.integration_accounts for all to authenticated using(
  (provider='google_calendar' and public.has_permission('integrations.google.manage',organization_id)) or
  (provider='email' and public.has_permission('integrations.email.manage',organization_id)) or
  (provider='whatsapp' and public.has_permission('integrations.whatsapp.manage',organization_id)) or
  public.has_permission('settings.manage',organization_id)
) with check(public.is_organization_member(organization_id));
create policy calendar_events_scope on public.calendar_events for select to authenticated using(exists(select 1 from public.doctor_sessions s where s.id=session_id));
create policy retry_queue_admin on public.retry_queue for select to authenticated using(public.has_permission('settings.manage',organization_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('erp-attachments','erp-attachments',false,20971520,array['application/pdf','image/png','image/jpeg','image/webp','audio/mpeg','audio/mp4'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy erp_attachments_read on storage.objects for select to authenticated using(bucket_id='erp-attachments' and public.is_organization_member((storage.foldername(name))[1]::uuid));
create policy erp_attachments_insert on storage.objects for insert to authenticated with check(bucket_id='erp-attachments' and public.is_organization_member((storage.foldername(name))[1]::uuid) and owner_id=auth.uid()::text);
create policy erp_attachments_delete on storage.objects for delete to authenticated using(bucket_id='erp-attachments' and owner_id=auth.uid()::text);

-- Complete write policies that are intentionally server-governed but still safe for direct authenticated clients.
create policy package_versions_manage on public.package_versions for all to authenticated
using(exists(select 1 from public.packages p where p.id=package_id and public.has_permission('catalog.manage',p.organization_id)))
with check(exists(select 1 from public.packages p where p.id=package_id and public.has_permission('catalog.manage',p.organization_id)));
create policy discount_limits_manage on public.discount_limits for all to authenticated using(public.has_permission('catalog.manage',organization_id)) with check(public.has_permission('catalog.manage',organization_id));
create policy invoices_insert on public.invoices for insert to authenticated with check(public.has_permission('sales.invoice',organization_id) and created_by=auth.uid() and public.can_access_branch(organization_id,branch_id));
create policy invoice_lines_manage on public.invoice_lines for all to authenticated using(exists(select 1 from public.invoices i where i.id=invoice_id and public.has_permission('sales.invoice',i.organization_id))) with check(exists(select 1 from public.invoices i where i.id=invoice_id and public.has_permission('sales.invoice',i.organization_id)));
create policy subscriptions_manage on public.subscriptions for all to authenticated using(public.has_permission('subscriptions.manage',organization_id)) with check(public.has_permission('subscriptions.manage',organization_id));
create policy refunds_insert on public.refunds for insert to authenticated with check(requested_by=auth.uid() and public.has_permission('refunds.request',organization_id));
create policy sessions_create on public.doctor_sessions for insert to authenticated with check(created_by=auth.uid() and public.has_permission('sessions.create',organization_id));
create policy sessions_update on public.doctor_sessions for update to authenticated using(public.has_permission('sessions.assign',organization_id) or exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid())) with check(public.is_organization_member(organization_id));
create policy session_notes_write on public.session_notes for all to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid())) with check(exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid()));

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text)
language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=10,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.tasks'::regclass,'public.customers'::regclass,'public.payment_submissions'::regclass,'public.doctor_sessions'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=70,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket';
$$;
revoke all on function public.validate_eco_healthy_installation() from public;
grant execute on function public.validate_eco_healthy_installation() to service_role;

insert into public.schema_versions(version,name) values
(1,'foundation_identity_access'),(2,'audit_settings_financial_periods'),(3,'foundation_security_hardening'),(10,'integrations_setup_validation')
on conflict(version) do nothing;

commit;
