-- Eco Healthy ERP — destructive reset and complete installer
-- WARNING: This permanently deletes every object and row in the public schema.
-- Use only on the dedicated Supabase project whose old ERP database must be replaced.
-- Supabase Auth users and stored file objects are intentionally not deleted.
-- Delete obsolete Auth users from Authentication > Users before /setup if reusing an email.

begin;
drop policy if exists erp_attachments_read on storage.objects;
drop policy if exists erp_attachments_insert on storage.objects;
drop policy if exists erp_attachments_delete on storage.objects;
drop schema if exists public cascade;
create schema public authorization postgres;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant create on schema public to postgres, service_role;
alter default privileges for role postgres in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on functions to postgres, anon, authenticated, service_role;
commit;

-- Eco Healthy ERP — complete database installer
-- Generated from the numbered migrations. Run once in a new Supabase SQL Editor.
-- Contains no passwords, tokens, API keys, or demo data.

-- ============================================================================
-- 0001_foundation_identity_access.sql
-- ============================================================================
begin;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

create type public.membership_status as enum ('invited', 'active', 'suspended', 'disabled');
create type public.branch_status as enum ('active', 'inactive');
create type public.branch_access_level as enum ('view', 'operate', 'manage');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email extensions.citext not null,
  full_name text not null,
  phone text,
  job_title text,
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar', 'en')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index profiles_email_uidx on public.profiles (lower(email::text));

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null,
  name text not null,
  base_currency char(3) not null default 'EGP',
  timezone text not null default 'Africa/Cairo',
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organizations_code_format check (code ~ '^[A-Z0-9_]{2,20}$'),
  constraint organizations_code_unique unique (code)
);

create table public.organization_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.membership_status not null default 'invited',
  invited_by uuid references auth.users(id),
  invited_at timestamptz not null default now(),
  activated_at timestamptz,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_memberships_unique unique (organization_id, user_id)
);

create table public.branches (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  address jsonb not null default '{}'::jsonb,
  contact_info jsonb not null default '{}'::jsonb,
  working_hours jsonb not null default '{}'::jsonb,
  status public.branch_status not null default 'active',
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branches_code_format check (code ~ '^[A-Z0-9_]{2,20}$'),
  constraint branches_org_code_unique unique (organization_id, code)
);

create table public.departments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  code text not null,
  name text not null,
  head_user_id uuid references public.profiles(id),
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint departments_org_code_unique unique (organization_id, code)
);

create table public.teams (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  department_id uuid references public.departments(id),
  code text not null,
  name text not null,
  leader_user_id uuid references public.profiles(id),
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teams_org_code_unique unique (organization_id, code)
);

create table public.team_members (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at date not null default current_date,
  left_at date,
  created_at timestamptz not null default now(),
  constraint team_members_dates check (left_at is null or left_at >= joined_at),
  constraint team_members_unique unique (team_id, user_id, joined_at)
);

create table public.permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  name text not null,
  module text not null,
  description text,
  is_sensitive boolean not null default false,
  created_at timestamptz not null default now(),
  constraint permissions_code_format check (code ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$')
);

create table public.roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_code_format check (code ~ '^[a-z][a-z0-9_]{1,49}$')
);

create unique index roles_global_code_uidx on public.roles (code) where organization_id is null;
create unique index roles_org_code_uidx on public.roles (organization_id, code) where organization_id is not null;

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.user_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  assigned_by uuid references auth.users(id),
  assigned_at timestamptz not null default now(),
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  constraint user_roles_dates check (valid_until is null or valid_until > valid_from),
  constraint user_roles_unique unique (organization_id, user_id, role_id)
);

create table public.user_branch_access (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  access_level public.branch_access_level not null default 'view',
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  constraint user_branch_access_dates check (valid_until is null or valid_until > valid_from),
  constraint user_branch_access_unique unique (organization_id, user_id, branch_id)
);

create index organization_memberships_user_idx on public.organization_memberships(user_id, status);
create index branches_organization_idx on public.branches(organization_id, status);
create index departments_organization_idx on public.departments(organization_id, branch_id);
create index teams_organization_idx on public.teams(organization_id, branch_id, department_id);
create index team_members_user_idx on public.team_members(user_id, team_id);
create index role_permissions_permission_idx on public.role_permissions(permission_id, role_id);
create index user_roles_lookup_idx on public.user_roles(user_id, organization_id, valid_from, valid_until);
create index user_branch_access_lookup_idx on public.user_branch_access(user_id, organization_id, branch_id, valid_until);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger organizations_set_updated_at before update on public.organizations for each row execute function public.set_updated_at();
create trigger memberships_set_updated_at before update on public.organization_memberships for each row execute function public.set_updated_at();
create trigger branches_set_updated_at before update on public.branches for each row execute function public.set_updated_at();
create trigger departments_set_updated_at before update on public.departments for each row execute function public.set_updated_at();
create trigger teams_set_updated_at before update on public.teams for each row execute function public.set_updated_at();
create trigger roles_set_updated_at before update on public.roles for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    coalesce(new.email, new.id::text || '@pending.local'),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(coalesce(new.email, 'User'), '@', 1))
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert or update of email on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.is_organization_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1 from public.organization_memberships m
    join public.profiles p on p.id = m.user_id and p.is_active
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.has_permission(p_code text, p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.organization_memberships m
    join public.user_roles ur on ur.organization_id = m.organization_id and ur.user_id = m.user_id
    join public.roles r on r.id = ur.role_id and r.is_active
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and p.code = p_code
      and ur.valid_from <= now()
      and (ur.valid_until is null or ur.valid_until > now())
  );
$$;

create or replace function public.has_permission_in_any_organization(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.user_id = auth.uid()
      and m.status = 'active'
      and public.has_permission(p_code, m.organization_id)
  );
$$;

create or replace function public.shares_active_organization(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.organization_memberships mine
    join public.organization_memberships theirs on theirs.organization_id = mine.organization_id
    where mine.user_id = auth.uid() and mine.status = 'active'
      and theirs.user_id = p_user_id and theirs.status in ('active', 'invited')
      and public.has_permission('users.view', mine.organization_id)
  );
$$;

create or replace function public.can_access_branch(p_organization_id uuid, p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select public.has_permission('branches.manage', p_organization_id)
    or exists (
      select 1 from public.user_branch_access uba
      where uba.organization_id = p_organization_id
        and uba.branch_id = p_branch_id
        and uba.user_id = auth.uid()
        and uba.valid_from <= now()
        and (uba.valid_until is null or uba.valid_until > now())
    );
$$;

create or replace function public.my_permission_codes(p_organization_id uuid)
returns table(permission_code text)
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select distinct p.code
  from public.organization_memberships m
  join public.user_roles ur on ur.organization_id = m.organization_id and ur.user_id = m.user_id
  join public.roles r on r.id = ur.role_id and r.is_active
  join public.role_permissions rp on rp.role_id = r.id
  join public.permissions p on p.id = rp.permission_id
  where m.organization_id = p_organization_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and ur.valid_from <= now()
    and (ur.valid_until is null or ur.valid_until > now())
  order by p.code;
$$;

revoke all on function public.is_organization_member(uuid) from public;
revoke all on function public.has_permission(text, uuid) from public;
revoke all on function public.has_permission_in_any_organization(text) from public;
revoke all on function public.shares_active_organization(uuid) from public;
revoke all on function public.can_access_branch(uuid, uuid) from public;
revoke all on function public.my_permission_codes(uuid) from public;
grant execute on function public.is_organization_member(uuid) to authenticated;
grant execute on function public.has_permission(text, uuid) to authenticated;
grant execute on function public.has_permission_in_any_organization(text) to authenticated;
grant execute on function public.shares_active_organization(uuid) to authenticated;
grant execute on function public.can_access_branch(uuid, uuid) to authenticated;
grant execute on function public.my_permission_codes(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.branches enable row level security;
alter table public.departments enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.user_branch_access enable row level security;

create policy profiles_select_self_or_scoped on public.profiles for select to authenticated
using (id = auth.uid() or public.shares_active_organization(id));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create policy organizations_select_member on public.organizations for select to authenticated
using (public.is_organization_member(id));
create policy organizations_update_manager on public.organizations for update to authenticated
using (public.has_permission('settings.manage', id)) with check (public.has_permission('settings.manage', id));

create policy memberships_select_self_or_manager on public.organization_memberships for select to authenticated
using (user_id = auth.uid() or public.has_permission('users.view', organization_id));
create policy memberships_manage on public.organization_memberships for all to authenticated
using (public.has_permission('users.manage', organization_id))
with check (public.has_permission('users.manage', organization_id));

create policy branches_select_scoped on public.branches for select to authenticated
using (public.is_organization_member(organization_id) and public.can_access_branch(organization_id, id));
create policy branches_manage on public.branches for all to authenticated
using (public.has_permission('branches.manage', organization_id))
with check (public.has_permission('branches.manage', organization_id));

create policy departments_select_member on public.departments for select to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)));
create policy departments_manage on public.departments for all to authenticated
using (public.has_permission('branches.manage', organization_id))
with check (public.has_permission('branches.manage', organization_id));

create policy teams_select_member on public.teams for select to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)));
create policy teams_manage on public.teams for all to authenticated
using (public.has_permission('branches.manage', organization_id))
with check (public.has_permission('branches.manage', organization_id));

create policy team_members_select_member on public.team_members for select to authenticated
using (public.is_organization_member(organization_id));
create policy team_members_manage on public.team_members for all to authenticated
using (public.has_permission('users.manage', organization_id))
with check (public.has_permission('users.manage', organization_id));

create policy permissions_select_authorized on public.permissions for select to authenticated
using (public.has_permission_in_any_organization('permissions.view'));

create policy roles_select_member on public.roles for select to authenticated
using (organization_id is null or public.is_organization_member(organization_id));
create policy roles_insert_manager on public.roles for insert to authenticated
with check (organization_id is not null and public.has_permission('roles.manage', organization_id) and not is_system);
create policy roles_update_manager on public.roles for update to authenticated
using (organization_id is not null and public.has_permission('roles.manage', organization_id) and not is_system)
with check (organization_id is not null and public.has_permission('roles.manage', organization_id) and not is_system);

create policy role_permissions_select_member on public.role_permissions for select to authenticated
using (exists (select 1 from public.roles r where r.id = role_id and (r.organization_id is null or public.is_organization_member(r.organization_id))));
create policy role_permissions_manage on public.role_permissions for all to authenticated
using (exists (select 1 from public.roles r where r.id = role_id and r.organization_id is not null and public.has_permission('roles.manage', r.organization_id)))
with check (exists (select 1 from public.roles r where r.id = role_id and r.organization_id is not null and public.has_permission('roles.manage', r.organization_id)));

create policy user_roles_select_self_or_manager on public.user_roles for select to authenticated
using (user_id = auth.uid() or public.has_permission('users.view', organization_id));
create policy user_roles_manage on public.user_roles for all to authenticated
using (public.has_permission('roles.assign', organization_id))
with check (public.has_permission('roles.assign', organization_id));

create policy user_branch_access_select_self_or_manager on public.user_branch_access for select to authenticated
using (user_id = auth.uid() or public.has_permission('branches.view', organization_id));
create policy user_branch_access_manage on public.user_branch_access for all to authenticated
using (public.has_permission('branches.manage', organization_id))
with check (public.has_permission('branches.manage', organization_id));

insert into public.permissions (code, name, module, description, is_sensitive) values
('dashboard.view', 'View dashboard', 'Core', 'Open the role-aware dashboard', false),
('users.view', 'View users', 'Identity', 'View users in allowed organizations', true),
('users.manage', 'Manage users', 'Identity', 'Invite and manage user memberships', true),
('roles.view', 'View roles', 'Identity', 'View roles and their definitions', true),
('roles.manage', 'Manage roles', 'Identity', 'Create and change custom roles', true),
('roles.assign', 'Assign roles', 'Identity', 'Assign roles to users', true),
('permissions.view', 'View permissions', 'Identity', 'View the permission catalog', true),
('branches.view', 'View branches', 'Organization', 'View branches in assigned scope', false),
('branches.manage', 'Manage branches', 'Organization', 'Create branches and assign access', true),
('audit.view', 'View audit log', 'Governance', 'View governed change history', true),
('audit.export', 'Export audit log', 'Governance', 'Export sensitive audit information', true),
('settings.view', 'View settings', 'Configuration', 'View organization settings', false),
('settings.manage', 'Manage settings', 'Configuration', 'Change governed organization settings', true),
('notifications.view', 'View notifications', 'Core', 'Open the notification center', false),
('notifications.manage_routes', 'Manage notification routing', 'Configuration', 'Change recipients and escalation rules', true),
('approvals.view', 'View approvals', 'Approvals', 'Open approvals assigned to the user', false),
('approvals.act', 'Act on approvals', 'Approvals', 'Approve, reject or return eligible requests', true),
('projects.view', 'View projects', 'Projects', 'View projects in scope', false),
('projects.manage', 'Manage projects', 'Projects', 'Create and manage projects', true),
('tasks.view', 'View tasks', 'Projects', 'View tasks in scope', false),
('tasks.manage', 'Manage tasks', 'Projects', 'Create and assign tasks', false),
('tasks.approve_completion', 'Approve task completion', 'Projects', 'Approve completion evidence', true),
('finance.period_close', 'Close financial period', 'Finance', 'Close a financial posting period', true),
('finance.period_reopen', 'Reopen financial period', 'Finance', 'Reopen a closed period with approval', true);

insert into public.roles (code, name, description, is_system) values
('ceo_super_admin', 'CEO / Super Admin', 'Full governed access across the organization', true),
('finance_manager', 'Finance Manager', 'Finance review, approvals and reporting', true),
('finance_accountant', 'Finance Accountant', 'Finance operations within assigned branches', true),
('sales_manager', 'Sales Manager', 'Sales team and commercial workflow management', true),
('sales_team_leader', 'Sales Team Leader', 'Team-level sales supervision', true),
('sales_representative', 'Sales Representative', 'Own leads, customers and submissions', true),
('customer_service', 'Customer Service', 'Customer service and operational requests', true),
('operations_manager', 'Operations Manager', 'Subscriber operations and delivery confirmation', true),
('kitchen_viewer', 'Kitchen Viewer', 'Restricted operational and dietary visibility', true),
('delivery_viewer', 'Delivery Viewer', 'Restricted address and delivery visibility', true),
('project_manager', 'Project Manager', 'Assigned project and task management', true),
('department_head', 'Department Head', 'Department work and approvals', true),
('task_assignee', 'Task Assignee', 'Own assigned tasks', true),
('read_only_auditor', 'Read-Only Auditor', 'Read-only governed access and audit visibility', true);

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p where r.code = 'ceo_super_admin';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','users.view','roles.view','permissions.view','branches.view','audit.view','settings.view','notifications.view','approvals.view')
where r.code = 'read_only_auditor';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','users.view','roles.view','branches.view','audit.view','settings.view','notifications.view','approvals.view','approvals.act','finance.period_close')
where r.code in ('finance_manager','finance_accountant');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','users.view','roles.view','branches.view','notifications.view','approvals.view','approvals.act')
where r.code in ('sales_manager','sales_team_leader','operations_manager','department_head');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','notifications.view')
where r.code in ('sales_representative','customer_service','kitchen_viewer','delivery_viewer');

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','notifications.view','approvals.view','projects.view','projects.manage','tasks.view','tasks.manage','tasks.approve_completion')
where r.code = 'project_manager';

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('dashboard.view','notifications.view','tasks.view')
where r.code = 'task_assignee';

commit;

-- ============================================================================
-- 0002_audit_settings_financial_periods.sql
-- ============================================================================
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

-- ============================================================================
-- 0003_foundation_security_hardening.sql
-- ============================================================================
begin;

insert into public.permissions (code, name, module, description, is_sensitive) values
  ('roles.assign_sensitive', 'Assign sensitive roles', 'Identity', 'Assign or revoke CEO / Super Admin authority', true),
  ('users.suspend', 'Suspend users', 'Identity', 'Suspend and reactivate organization users', true),
  ('tasks.create', 'Create tasks', 'Tasks', 'Create tasks and follow-ups', false),
  ('tasks.assign', 'Assign tasks', 'Tasks', 'Assign tasks to users, teams and departments', true),
  ('tasks.view_own', 'View own tasks', 'Tasks', 'View tasks assigned to the current user', false),
  ('tasks.view_team', 'View team tasks', 'Tasks', 'View tasks assigned within managed teams', false),
  ('tasks.view_all', 'View all tasks', 'Tasks', 'View all organization tasks within branch scope', true),
  ('tasks.respond', 'Respond to tasks', 'Tasks', 'Submit official responses and completion evidence', false),
  ('tasks.review', 'Review tasks', 'Tasks', 'Approve or reject task responses and evidence', true),
  ('tasks.reopen', 'Reopen tasks', 'Tasks', 'Reopen a completed or rejected task with a reason', true),
  ('doctors.view', 'View doctors', 'Doctors', 'View the doctor directory', false),
  ('doctors.manage', 'Manage doctors', 'Doctors', 'Create and maintain doctor master data', true),
  ('doctors.view_financials', 'View doctor financials', 'Doctors', 'View restricted doctor contract and payout information', true),
  ('doctors.manage_availability', 'Manage doctor availability', 'Doctors', 'Maintain doctor schedules, blocks and vacations', true),
  ('sessions.create', 'Create doctor sessions', 'Doctor Sessions', 'Create a doctor session request', false),
  ('sessions.assign', 'Assign doctor sessions', 'Doctor Sessions', 'Assign or override the doctor selection', true),
  ('sessions.view_own', 'View own doctor sessions', 'Doctor Sessions', 'View sessions assigned to the current doctor or user', false),
  ('sessions.view_team', 'View team doctor sessions', 'Doctor Sessions', 'View sessions in managed teams and branches', false),
  ('sessions.reschedule', 'Reschedule doctor sessions', 'Doctor Sessions', 'Reschedule confirmed or scheduled sessions', true),
  ('sessions.cancel', 'Cancel doctor sessions', 'Doctor Sessions', 'Cancel a doctor session under policy', true),
  ('sessions.complete', 'Complete doctor sessions', 'Doctor Sessions', 'Mark an attended session completed', false),
  ('sessions.write_notes', 'Write session notes', 'Doctor Sessions', 'Write governed session outcomes and recommendations', false),
  ('sessions.view_medical_notes', 'View medical session notes', 'Doctor Sessions', 'View restricted internal clinical notes', true),
  ('doctor_commissions.view_own', 'View own doctor commissions', 'Doctor Accounting', 'View the current doctor commission subledger', false),
  ('doctor_commissions.review', 'Review doctor commissions', 'Doctor Accounting', 'Review eligible doctor commission entries', true),
  ('doctor_commissions.approve', 'Approve doctor commissions', 'Doctor Accounting', 'Approve doctor commissions under maker-checker', true),
  ('doctor_commissions.pay', 'Pay doctor commissions', 'Doctor Accounting', 'Execute and confirm doctor payouts', true),
  ('doctor_commissions.reverse', 'Reverse doctor commissions', 'Doctor Accounting', 'Reverse or claw back doctor commission entries', true),
  ('integrations.google.manage', 'Manage Google integration', 'Integrations', 'Configure governed Google Calendar integration', true),
  ('integrations.whatsapp.manage', 'Manage WhatsApp integration', 'Integrations', 'Configure governed WhatsApp providers and templates', true),
  ('integrations.email.manage', 'Manage email integration', 'Integrations', 'Configure governed email providers and templates', true)
on conflict (code) do nothing;

-- The global CEO role receives new catalog permissions explicitly because the
-- original role seed predates this additive migration.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'ceo_super_admin'
  and r.organization_id is null
on conflict (role_id, permission_id) do nothing;

create or replace function public.user_has_permission(
  p_user_id uuid,
  p_code text,
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.organization_memberships m
    join public.profiles profile on profile.id = m.user_id and profile.is_active
    join public.user_roles ur on ur.organization_id = m.organization_id and ur.user_id = m.user_id
    join public.roles r on r.id = ur.role_id and r.is_active
    join public.role_permissions rp on rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
      and p.code = p_code
      and ur.valid_from <= now()
      and (ur.valid_until is null or ur.valid_until > now())
  );
$$;

create or replace function public.user_has_role(
  p_user_id uuid,
  p_role_code text,
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
set row_security = off
as $$
  select exists (
    select 1
    from public.organization_memberships m
    join public.user_roles ur on ur.organization_id = m.organization_id and ur.user_id = m.user_id
    join public.roles r on r.id = ur.role_id and r.is_active
    where m.organization_id = p_organization_id
      and m.user_id = p_user_id
      and m.status = 'active'
      and r.code = p_role_code
      and ur.valid_from <= now()
      and (ur.valid_until is null or ur.valid_until > now())
  );
$$;

create or replace function public.enforce_user_role_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.user_roles;
  v_role public.roles;
begin
  v_row := case when tg_op = 'DELETE' then old else new end;

  if v_actor is null or auth.role() = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if not public.user_has_permission(v_actor, 'roles.assign', v_row.organization_id) then
    raise exception 'roles.assign is required' using errcode = '42501';
  end if;
  if v_row.user_id = v_actor then
    raise exception 'self role assignment is not allowed' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = v_row.organization_id
      and m.user_id = v_row.user_id
      and m.status in ('invited', 'active', 'suspended', 'disabled')
  ) then
    raise exception 'target user is not in the organization' using errcode = '23514';
  end if;

  select * into v_role from public.roles where id = v_row.role_id;
  if v_role.id is null
    or not v_role.is_active
    or (v_role.organization_id is not null and v_role.organization_id <> v_row.organization_id) then
    raise exception 'role is outside the organization or inactive' using errcode = '23514';
  end if;

  if v_role.code = 'ceo_super_admin'
    and not public.user_has_permission(v_actor, 'roles.assign_sensitive', v_row.organization_id) then
    raise exception 'roles.assign_sensitive is required' using errcode = '42501';
  end if;

  if tg_op <> 'DELETE' and exists (
    select 1
    from public.role_permissions rp
    join public.permissions p on p.id = rp.permission_id
    where rp.role_id = v_row.role_id
      and not public.user_has_permission(v_actor, p.code, v_row.organization_id)
  ) then
    raise exception 'cannot assign a role with permissions outside actor authority' using errcode = '42501';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger enforce_user_role_mutation
before insert or update or delete on public.user_roles
for each row execute function public.enforce_user_role_mutation();

create or replace function public.enforce_branch_access_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.user_branch_access;
begin
  v_row := case when tg_op = 'DELETE' then old else new end;

  if not exists (
    select 1 from public.organization_memberships m
    where m.organization_id = v_row.organization_id
      and m.user_id = v_row.user_id
      and m.status in ('invited', 'active', 'suspended', 'disabled')
  ) then
    raise exception 'target user is not in the organization' using errcode = '23514';
  end if;
  if not exists (
    select 1 from public.branches b
    where b.id = v_row.branch_id and b.organization_id = v_row.organization_id
  ) then
    raise exception 'branch is not in the organization' using errcode = '23514';
  end if;

  if v_actor is not null and auth.role() <> 'service_role'
    and not public.user_has_permission(v_actor, 'branches.manage', v_row.organization_id) then
    raise exception 'branches.manage is required' using errcode = '42501';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger enforce_branch_access_mutation
before insert or update or delete on public.user_branch_access
for each row execute function public.enforce_branch_access_mutation();

create or replace function public.enforce_role_permission_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  v_actor uuid := auth.uid();
  v_role_id uuid := case when tg_op = 'DELETE' then old.role_id else new.role_id end;
  v_permission_id uuid := case when tg_op = 'DELETE' then old.permission_id else new.permission_id end;
  v_role public.roles;
  v_permission_code text;
begin
  if v_actor is null or auth.role() = 'service_role' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  select * into v_role from public.roles where id = v_role_id;
  select code into v_permission_code from public.permissions where id = v_permission_id;
  if v_role.id is null or v_role.organization_id is null or v_role.is_system then
    raise exception 'only organization custom roles can be changed' using errcode = '42501';
  end if;
  if not public.user_has_permission(v_actor, 'roles.manage', v_role.organization_id) then
    raise exception 'roles.manage is required' using errcode = '42501';
  end if;

  if tg_op <> 'DELETE' then
    if not public.user_has_permission(v_actor, v_permission_code, v_role.organization_id) then
      raise exception 'cannot grant a permission outside actor authority' using errcode = '42501';
    end if;
    if public.user_has_role(v_actor, v_role.code, v_role.organization_id) then
      raise exception 'cannot escalate a role held by the actor' using errcode = '42501';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger enforce_role_permission_mutation
before insert or update or delete on public.role_permissions
for each row execute function public.enforce_role_permission_mutation();

create or replace function public.enforce_membership_state_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = off
as $$
declare
  v_actor uuid := auth.uid();
begin
  if old.status = new.status or v_actor is null or auth.role() = 'service_role' then
    return new;
  end if;
  if new.user_id = v_actor then
    raise exception 'self suspension or reactivation is not allowed' using errcode = '42501';
  end if;
  if not public.user_has_permission(v_actor, 'users.suspend', new.organization_id) then
    raise exception 'users.suspend is required' using errcode = '42501';
  end if;
  if public.user_has_role(new.user_id, 'ceo_super_admin', new.organization_id)
    and not public.user_has_permission(v_actor, 'roles.assign_sensitive', new.organization_id) then
    raise exception 'sensitive authority is required for this user' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger enforce_membership_state_mutation
before update of status on public.organization_memberships
for each row execute function public.enforce_membership_state_mutation();

-- Profile state changes are security-relevant and must be present in the audit trail.
create trigger audit_profiles
after insert or update or delete on public.profiles
for each row execute function public.audit_row_change();

revoke all on function public.user_has_permission(uuid, text, uuid) from public;
revoke all on function public.user_has_role(uuid, text, uuid) from public;

commit;

-- ============================================================================
-- 0004_shared_events_notifications.sql
-- ============================================================================
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

-- ============================================================================
-- 0005_projects_tasks_followups.sql
-- ============================================================================
begin;

create table public.projects (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  project_number bigint generated by default as identity,
  name text not null,
  description text,
  owner_user_id uuid references public.profiles(id),
  sponsor_user_id uuid references public.profiles(id),
  department_id uuid references public.departments(id),
  status text not null default 'planned' check (status in ('planned','active','on_hold','at_risk','completed','cancelled')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  is_strategic boolean not null default false,
  starts_on date,
  due_on date,
  completed_on date,
  progress_percent numeric(5,2) not null default 0 check (progress_percent between 0 and 100),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, project_number),
  check (due_on is null or starts_on is null or due_on >= starts_on)
);

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  task_number bigint generated by default as identity,
  project_id uuid references public.projects(id) on delete set null,
  parent_task_id uuid references public.tasks(id) on delete set null,
  title text not null,
  detailed_description text,
  task_type text not null default 'task' check (task_type in ('task','open_task','customer_followup','lead_followup','feedback_request','approval_request','doctor_session','subscription','complaint','payment','refund','internal_action')),
  related_entity_type text,
  related_entity_id uuid,
  department_id uuid references public.departments(id),
  created_by uuid not null references public.profiles(id),
  reviewer_user_id uuid references public.profiles(id),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  status text not null default 'draft' check (status in ('draft','assigned','open','accepted','in_progress','waiting_for_customer','waiting_for_internal_department','waiting_for_approval','waiting_for_feedback','blocked','response_submitted','in_review','completed','rejected','reopened','cancelled')),
  start_at timestamptz,
  due_at timestamptz,
  open_until_response boolean not null default false,
  expected_response_type text,
  required_action text,
  response_required boolean not null default false,
  evidence_required boolean not null default false,
  reviewer_approval_required boolean not null default false,
  blocker text,
  escalation_level integer not null default 0 check (escalation_level between 0 and 4),
  first_response_at timestamptz,
  completed_at timestamptz,
  approved_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, task_number),
  check (due_at is null or start_at is null or due_at >= start_at)
);

create table public.task_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  assignee_type text not null check (assignee_type in ('user','team','department')),
  assignee_user_id uuid references public.profiles(id),
  assignee_team_id uuid references public.teams(id),
  assignee_department_id uuid references public.departments(id),
  assigned_by uuid not null references public.profiles(id),
  assigned_at timestamptz not null default now(),
  accepted_at timestamptz,
  ended_at timestamptz,
  is_primary boolean not null default true,
  is_demo boolean not null default false,
  check (num_nonnulls(assignee_user_id, assignee_team_id, assignee_department_id) = 1)
);

create table public.task_checklist_items (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  description text not null,
  display_order integer not null default 0,
  is_required boolean not null default true,
  is_completed boolean not null default false,
  completed_by uuid references public.profiles(id),
  completed_at timestamptz,
  is_demo boolean not null default false
);

create table public.task_dependencies (
  task_id uuid not null references public.tasks(id) on delete cascade,
  depends_on_task_id uuid not null references public.tasks(id) on delete cascade,
  dependency_type text not null default 'finish_to_start',
  is_blocking boolean not null default true,
  is_demo boolean not null default false,
  primary key (task_id, depends_on_task_id),
  check (task_id <> depends_on_task_id)
);

create table public.task_activities (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  activity_type text not null,
  actor_user_id uuid references public.profiles(id),
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.task_comments (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  author_user_id uuid not null references public.profiles(id),
  body text not null,
  mentions uuid[] not null default '{}'::uuid[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.task_responses (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  submitted_by uuid not null references public.profiles(id),
  response_type text not null default 'text',
  response_text text not null,
  version integer not null default 1,
  submitted_at timestamptz not null default now(),
  is_official boolean not null default true,
  is_demo boolean not null default false,
  unique (task_id, version)
);

create table public.task_completion_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  submitted_by uuid not null references public.profiles(id),
  evidence_text text not null,
  submitted_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.task_reviews (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  reviewer_user_id uuid not null references public.profiles(id),
  decision text not null check (decision in ('approved','rejected','changes_requested')),
  feedback text,
  reviewed_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.task_followups (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  contact_method text not null check (contact_method in ('phone','email','whatsapp','meeting','other')),
  contact_at timestamptz not null,
  contact_outcome text,
  customer_response text,
  next_action text,
  next_followup_at timestamptz,
  customer_interest text,
  objection_reason text,
  escalation_required boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create index projects_scope_idx on public.projects(organization_id, branch_id, status);
create index tasks_scope_idx on public.tasks(organization_id, branch_id, status, due_at);
create index tasks_related_idx on public.tasks(organization_id, related_entity_type, related_entity_id);
create index task_assignments_user_idx on public.task_assignments(assignee_user_id, ended_at, assigned_at);
create index task_activities_timeline_idx on public.task_activities(task_id, occurred_at);

create trigger projects_set_updated_at before update on public.projects for each row execute function public.set_updated_at();
create trigger tasks_set_updated_at before update on public.tasks for each row execute function public.set_updated_at();
create trigger task_comments_set_updated_at before update on public.task_comments for each row execute function public.set_updated_at();
create trigger audit_projects after insert or update or delete on public.projects for each row execute function public.audit_row_change();
create trigger audit_tasks after insert or update or delete on public.tasks for each row execute function public.audit_row_change();
create trigger audit_task_assignments after insert or update or delete on public.task_assignments for each row execute function public.audit_row_change();
create trigger audit_task_reviews after insert or update or delete on public.task_reviews for each row execute function public.audit_row_change();

create or replace function public.enforce_task_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'completed' and old.status is distinct from new.status then
    if new.response_required and not exists (select 1 from public.task_responses r where r.task_id = new.id and r.is_official) then
      raise exception 'official response is required before completion';
    end if;
    if new.evidence_required and not exists (select 1 from public.task_completion_evidence e where e.task_id = new.id) then
      raise exception 'completion evidence is required before completion';
    end if;
    if exists (select 1 from public.task_checklist_items c where c.task_id = new.id and c.is_required and not c.is_completed) then
      raise exception 'required checklist items are incomplete';
    end if;
    if new.reviewer_approval_required and not exists (select 1 from public.task_reviews r where r.task_id = new.id and r.decision = 'approved') then
      raise exception 'reviewer approval is required before completion';
    end if;
    new.completed_at := coalesce(new.completed_at, now());
    if new.reviewer_approval_required then new.approved_at := coalesce(new.approved_at, now()); end if;
  end if;
  return new;
end;
$$;
create trigger tasks_enforce_completion before update of status on public.tasks for each row execute function public.enforce_task_completion();

create or replace function public.record_task_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_actor uuid;
begin
  v_type := case when tg_op = 'INSERT' then 'task.created' else 'task.updated' end;
  if tg_op = 'UPDATE' and old.status is distinct from new.status then v_type := 'task.status_changed'; end if;
  v_actor := coalesce(auth.uid(), new.created_by);
  insert into public.task_activities(organization_id, task_id, activity_type, actor_user_id, details, is_demo)
  values (new.organization_id, new.id, v_type, v_actor,
    jsonb_build_object('status', new.status, 'previous_status', case when tg_op = 'UPDATE' then old.status else null end, 'due_at', new.due_at),
    new.is_demo);
  perform public.enqueue_domain_event(new.organization_id, new.branch_id, v_type, 'task', new.id,
    jsonb_build_object('title', new.title, 'status', new.status), v_actor,
    v_type || ':' || new.id::text || ':' || extract(epoch from new.updated_at)::bigint::text, new.is_demo);
  return new;
end;
$$;
create trigger tasks_record_activity after insert or update of status, due_at, reviewer_user_id on public.tasks for each row execute function public.record_task_activity();

create or replace function public.escalate_overdue_tasks(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  with escalated as (
    update public.tasks
    set escalation_level = least(escalation_level + 1, 4), updated_at = now()
    where due_at < p_now
      and status not in ('completed','cancelled','rejected')
      and escalation_level < 4
    returning id, organization_id, branch_id, title, escalation_level, is_demo
  ), events as (
    insert into public.domain_events(organization_id, branch_id, event_type, aggregate_type, aggregate_id, payload, idempotency_key, is_demo)
    select organization_id, branch_id, 'task.overdue', 'task', id,
      jsonb_build_object('title', title, 'escalation_level', escalation_level),
      'task.overdue:' || id::text || ':' || escalation_level::text, is_demo
    from escalated
    on conflict (organization_id, idempotency_key) do nothing
    returning 1
  ) select count(*) into v_count from escalated;
  return v_count;
end;
$$;

alter table public.projects enable row level security;
alter table public.tasks enable row level security;
alter table public.task_assignments enable row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_dependencies enable row level security;
alter table public.task_activities enable row level security;
alter table public.task_comments enable row level security;
alter table public.task_responses enable row level security;
alter table public.task_completion_evidence enable row level security;
alter table public.task_reviews enable row level security;
alter table public.task_followups enable row level security;

create policy projects_select_scope on public.projects for select to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)) and (public.has_permission('projects.view', organization_id) or owner_user_id = auth.uid()));
create policy projects_manage_scope on public.projects for all to authenticated
using (public.has_permission('projects.manage', organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)))
with check (public.has_permission('projects.manage', organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)));
create policy tasks_select_scope on public.tasks for select to authenticated
using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)) and (
  public.has_permission('tasks.view_all', organization_id) or public.has_permission('tasks.view_team', organization_id)
  or created_by = auth.uid() or reviewer_user_id = auth.uid()
  or exists (select 1 from public.task_assignments a where a.task_id = id and a.assignee_user_id = auth.uid() and a.ended_at is null)
));
create policy tasks_create_scope on public.tasks for insert to authenticated
with check (created_by = auth.uid() and public.has_permission('tasks.create', organization_id) and (branch_id is null or public.can_access_branch(organization_id, branch_id)));
create policy tasks_update_scope on public.tasks for update to authenticated
using (public.has_permission('tasks.assign', organization_id) or reviewer_user_id = auth.uid() or exists (select 1 from public.task_assignments a where a.task_id = id and a.assignee_user_id = auth.uid() and a.ended_at is null))
with check (public.is_organization_member(organization_id));

create policy task_children_select on public.task_assignments for select to authenticated using (exists (select 1 from public.tasks t where t.id = task_id));
create policy task_assignments_manage on public.task_assignments for all to authenticated using (public.has_permission('tasks.assign', organization_id)) with check (public.has_permission('tasks.assign', organization_id) and assigned_by = auth.uid());
create policy checklist_scope on public.task_checklist_items for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (exists (select 1 from public.tasks t where t.id = task_id));
create policy dependencies_scope on public.task_dependencies for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (exists (select 1 from public.tasks t where t.id = task_id));
create policy activities_select on public.task_activities for select to authenticated using (exists (select 1 from public.tasks t where t.id = task_id));
create policy comments_scope on public.task_comments for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (author_user_id = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id));
create policy responses_scope on public.task_responses for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (submitted_by = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id));
create policy evidence_scope on public.task_completion_evidence for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (submitted_by = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id));
create policy reviews_scope on public.task_reviews for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (reviewer_user_id = auth.uid() and public.has_permission('tasks.review', (select organization_id from public.tasks where id = task_id)));
create policy followups_scope on public.task_followups for all to authenticated using (exists (select 1 from public.tasks t where t.id = task_id)) with check (created_by = auth.uid() and exists (select 1 from public.tasks t where t.id = task_id));

insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('tasks.create','tasks.assign','tasks.view_own','tasks.view_team','tasks.view_all','tasks.respond','tasks.review','tasks.reopen')
where r.code = 'project_manager' on conflict do nothing;
insert into public.role_permissions(role_id, permission_id)
select r.id, p.id from public.roles r join public.permissions p on p.code in ('tasks.create','tasks.view_own','tasks.respond')
where r.code = 'task_assignee' on conflict do nothing;

insert into public.schema_versions(version, name) values (5, 'projects_tasks_followups');
commit;

-- ============================================================================
-- 0006_crm_customers_complaints.sql
-- ============================================================================
begin;

insert into public.permissions(code,name,module,description,is_sensitive) values
('leads.view','View leads','CRM','View leads in branch scope',false),
('leads.manage','Manage leads','CRM','Create and update leads',false),
('leads.assign','Assign leads','CRM','Assign and reassign leads',true),
('leads.convert','Convert leads','CRM','Convert a qualified lead to customer',false),
('customers.view','View customers','CRM','View customer profiles in branch scope',false),
('customers.manage','Manage customers','CRM','Create and update customer records',false),
('customers.view_sensitive','View sensitive customer data','CRM','View allergy and restricted customer notes',true),
('complaints.view','View complaints','Customer Service','View customer complaints',false),
('complaints.manage','Manage complaints','Customer Service','Create, investigate and resolve complaints',false)
on conflict (code) do nothing;

insert into public.role_permissions(role_id, permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('leads.view','leads.manage','leads.assign','leads.convert','customers.view','customers.manage','complaints.view')
where r.code in ('sales_manager','sales_team_leader') on conflict do nothing;
insert into public.role_permissions(role_id, permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('leads.view','leads.manage','leads.convert','customers.view','customers.manage')
where r.code = 'sales_representative' on conflict do nothing;
insert into public.role_permissions(role_id, permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('customers.view','customers.manage','customers.view_sensitive','complaints.view','complaints.manage')
where r.code in ('customer_service','operations_manager') on conflict do nothing;
insert into public.role_permissions(role_id, permission_id)
select r.id,p.id from public.roles r cross join public.permissions p where r.code='ceo_super_admin' on conflict do nothing;

create table public.staff_directory (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  profile_id uuid references public.profiles(id),
  employee_code text not null,
  display_name text not null,
  role_label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, employee_code)
);

create table public.leads (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  lead_number bigint generated by default as identity,
  full_name text not null,
  mobile text,
  email extensions.citext,
  source text,
  campaign text,
  status text not null default 'new' check (status in ('new','assigned','contacted','qualified','proposal','won','lost','converted')),
  temperature text not null default 'warm' check (temperature in ('cold','warm','hot')),
  assigned_user_id uuid references public.profiles(id),
  assigned_staff_id uuid references public.staff_directory(id),
  next_followup_at timestamptz,
  loss_reason text,
  converted_customer_id uuid,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, lead_number)
);

create table public.customers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  home_branch_id uuid references public.branches(id),
  customer_number bigint generated by default as identity,
  full_name text not null,
  mobile text,
  email extensions.citext,
  gender text,
  birth_date date,
  status text not null default 'active' check (status in ('active','inactive','blocked')),
  source_lead_id uuid references public.leads(id),
  owner_user_id uuid references public.profiles(id),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, customer_number)
);
alter table public.leads add constraint leads_converted_customer_fk foreign key (converted_customer_id) references public.customers(id) deferrable initially deferred;

create unique index customers_org_mobile_uidx on public.customers(organization_id, mobile) where mobile is not null and not is_demo;
create index leads_scope_idx on public.leads(organization_id, branch_id, status, next_followup_at);
create index customers_scope_idx on public.customers(organization_id, home_branch_id, status);

create table public.customer_addresses (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  label text not null,
  address_line text not null,
  area text,
  city text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  delivery_notes text,
  is_primary boolean not null default false,
  is_demo boolean not null default false
);

create table public.customer_preferences (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  preference_type text not null check (preference_type in ('like','dislike','restriction','goal','general')),
  value text not null,
  is_permanent boolean not null default true,
  valid_until date,
  visibility text not null default 'operations' check (visibility in ('all_staff','operations','medical')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.customer_allergies (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  allergen text not null,
  severity text not null default 'unknown' check (severity in ('unknown','mild','moderate','severe')),
  notes text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  is_demo boolean not null default false
);

create table public.customer_notes (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  note_type text not null default 'general' check (note_type in ('general','sales','operations','medical','finance')),
  body text not null,
  visibility text not null default 'internal' check (visibility in ('internal','restricted','customer_visible')),
  author_user_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false
);

create table public.complaint_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  default_sla_hours integer not null default 24 check (default_sla_hours > 0),
  is_active boolean not null default true,
  is_demo boolean not null default false,
  unique (organization_id, code)
);

create table public.complaints (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  complaint_number bigint generated by default as identity,
  customer_id uuid not null references public.customers(id),
  category_id uuid references public.complaint_categories(id),
  reason text not null,
  details text,
  severity text not null default 'normal' check (severity in ('low','normal','high','critical')),
  status text not null default 'open' check (status in ('open','investigating','waiting_customer','resolved','closed','reopened')),
  owner_user_id uuid references public.profiles(id),
  due_at timestamptz,
  root_cause text,
  corrective_action text,
  satisfaction_score integer check (satisfaction_score between 1 and 5),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  closed_at timestamptz,
  updated_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique (organization_id, complaint_number)
);

create table public.cancellation_reasons (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  category text not null,
  is_active boolean not null default true,
  is_demo boolean not null default false,
  unique (organization_id, code)
);

create table public.customer_timeline (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  event_type text not null,
  title text not null,
  details jsonb not null default '{}'::jsonb,
  related_type text,
  related_id uuid,
  actor_user_id uuid references public.profiles(id),
  occurred_at timestamptz not null default now(),
  is_demo boolean not null default false
);
create index customer_timeline_idx on public.customer_timeline(customer_id, occurred_at desc);
create index complaints_scope_idx on public.complaints(organization_id, branch_id, status, due_at);

create trigger leads_set_updated_at before update on public.leads for each row execute function public.set_updated_at();
create trigger customers_set_updated_at before update on public.customers for each row execute function public.set_updated_at();
create trigger complaints_set_updated_at before update on public.complaints for each row execute function public.set_updated_at();
create trigger audit_leads after insert or update or delete on public.leads for each row execute function public.audit_row_change();
create trigger audit_customers after insert or update or delete on public.customers for each row execute function public.audit_row_change();
create trigger audit_complaints after insert or update or delete on public.complaints for each row execute function public.audit_row_change();

create or replace function public.convert_lead_to_customer(p_lead_id uuid, p_actor_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_lead public.leads; v_customer_id uuid;
begin
  select * into v_lead from public.leads where id = p_lead_id for update;
  if v_lead.id is null or v_lead.status in ('converted','lost') then raise exception 'lead is not convertible'; end if;
  if p_actor_user_id is distinct from auth.uid() and auth.role() <> 'service_role' then raise exception 'actor mismatch'; end if;
  if auth.uid() is not null and not public.has_permission('leads.convert', v_lead.organization_id) then raise exception 'leads.convert is required'; end if;
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,source_lead_id,owner_user_id,created_by,is_demo)
  values(v_lead.organization_id,v_lead.branch_id,v_lead.full_name,v_lead.mobile,v_lead.email,v_lead.id,v_lead.assigned_user_id,p_actor_user_id,v_lead.is_demo)
  returning id into v_customer_id;
  update public.leads set status='converted',converted_customer_id=v_customer_id,updated_at=now() where id=v_lead.id;
  insert into public.customer_timeline(organization_id,customer_id,event_type,title,related_type,related_id,actor_user_id,is_demo)
  values(v_lead.organization_id,v_customer_id,'lead.converted','Converted from lead','lead',v_lead.id,p_actor_user_id,v_lead.is_demo);
  perform public.enqueue_domain_event(v_lead.organization_id,v_lead.branch_id,'lead.converted','customer',v_customer_id,jsonb_build_object('lead_id',v_lead.id),p_actor_user_id,'lead.converted:'||v_lead.id::text,v_lead.is_demo);
  return v_customer_id;
end;
$$;

alter table public.staff_directory enable row level security;
alter table public.leads enable row level security;
alter table public.customers enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.customer_preferences enable row level security;
alter table public.customer_allergies enable row level security;
alter table public.customer_notes enable row level security;
alter table public.complaint_categories enable row level security;
alter table public.complaints enable row level security;
alter table public.cancellation_reasons enable row level security;
alter table public.customer_timeline enable row level security;

create policy staff_scope on public.staff_directory for select to authenticated using (public.is_organization_member(organization_id) and (branch_id is null or public.can_access_branch(organization_id,branch_id)));
create policy leads_select_scope on public.leads for select to authenticated using (public.has_permission('leads.view',organization_id) and public.can_access_branch(organization_id,branch_id));
create policy leads_manage_scope on public.leads for all to authenticated using (public.has_permission('leads.manage',organization_id) and public.can_access_branch(organization_id,branch_id)) with check (public.has_permission('leads.manage',organization_id) and public.can_access_branch(organization_id,branch_id));
create policy customers_select_scope on public.customers for select to authenticated using (public.has_permission('customers.view',organization_id) and (home_branch_id is null or public.can_access_branch(organization_id,home_branch_id)));
create policy customers_manage_scope on public.customers for all to authenticated using (public.has_permission('customers.manage',organization_id) and (home_branch_id is null or public.can_access_branch(organization_id,home_branch_id))) with check (public.has_permission('customers.manage',organization_id));
create policy customer_addresses_scope on public.customer_addresses for all to authenticated using (exists(select 1 from public.customers c where c.id=customer_id)) with check (exists(select 1 from public.customers c where c.id=customer_id));
create policy customer_preferences_scope on public.customer_preferences for all to authenticated using (exists(select 1 from public.customers c where c.id=customer_id) and (visibility <> 'medical' or public.has_permission('customers.view_sensitive',(select organization_id from public.customers where id=customer_id)))) with check (exists(select 1 from public.customers c where c.id=customer_id));
create policy customer_allergies_scope on public.customer_allergies for all to authenticated using (public.has_permission('customers.view_sensitive',(select organization_id from public.customers where id=customer_id))) with check (public.has_permission('customers.view_sensitive',(select organization_id from public.customers where id=customer_id)));
create policy customer_notes_scope on public.customer_notes for all to authenticated using (exists(select 1 from public.customers c where c.id=customer_id) and (note_type <> 'medical' or public.has_permission('customers.view_sensitive',(select organization_id from public.customers where id=customer_id)))) with check (author_user_id=auth.uid() and exists(select 1 from public.customers c where c.id=customer_id));
create policy complaint_categories_scope on public.complaint_categories for select to authenticated using (public.is_organization_member(organization_id));
create policy complaints_select_scope on public.complaints for select to authenticated using (public.has_permission('complaints.view',organization_id) and (branch_id is null or public.can_access_branch(organization_id,branch_id)));
create policy complaints_manage_scope on public.complaints for all to authenticated using (public.has_permission('complaints.manage',organization_id)) with check (public.has_permission('complaints.manage',organization_id) and created_by=auth.uid());
create policy cancellation_reasons_scope on public.cancellation_reasons for select to authenticated using (public.is_organization_member(organization_id));
create policy timeline_scope on public.customer_timeline for select to authenticated using (public.has_permission('customers.view',organization_id));

insert into public.schema_versions(version,name) values(6,'crm_customers_complaints');
commit;

-- ============================================================================
-- 0007_sales_finance_subscriptions.sql
-- ============================================================================
begin;

insert into public.permissions(code,name,module,description,is_sensitive) values
('catalog.view','View catalog','Sales','View packages and price versions',false),
('catalog.manage','Manage catalog','Sales','Create versioned packages and pricing',true),
('sales.quote','Create quotations','Sales','Create and issue quotations',false),
('sales.invoice','Create invoices','Sales','Create invoices from accepted quotations',false),
('payments.submit','Submit payment proof','Finance','Submit customer payment proof for review',false),
('payments.review','Review payment submissions','Finance','Review payment proofs',true),
('payments.confirm','Confirm cash collection','Finance','Create confirmed cash transactions',true),
('refunds.request','Request refunds','Finance','Request a governed customer refund',false),
('refunds.approve','Approve refunds','Finance','Approve refunds under maker-checker',true),
('subscriptions.view','View subscriptions','Subscriptions','View subscriptions in branch scope',false),
('subscriptions.manage','Manage subscriptions','Subscriptions','Activate, freeze and cancel subscriptions',true),
('service.confirm_delivery','Confirm service delivery','Subscriptions','Confirm delivered service days',true),
('revenue.view','View revenue subledger','Finance','View deferred and recognized revenue',true)
on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('catalog.view','sales.quote','sales.invoice','payments.submit','subscriptions.view') where r.code in ('sales_manager','sales_team_leader','sales_representative') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('catalog.view','payments.review','payments.confirm','refunds.approve','subscriptions.view','revenue.view') where r.code in ('finance_manager','finance_accountant') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in ('subscriptions.view','subscriptions.manage','service.confirm_delivery') where r.code='operations_manager' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.code='ceo_super_admin' on conflict do nothing;

create table public.packages (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null, name text not null, description text, status text not null default 'active' check(status in('active','inactive')),
  created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), is_demo boolean not null default false,
  unique(organization_id,code)
);
create table public.package_versions (
  id uuid primary key default extensions.gen_random_uuid(), package_id uuid not null references public.packages(id) on delete cascade,
  version_number integer not null, effective_from date not null, effective_to date, currency char(3) not null default 'EGP', price numeric(18,2) not null check(price>=0),
  service_days integer not null check(service_days>0), meals_per_day integer not null default 1 check(meals_per_day>0),
  freeze_policy jsonb not null default '{}'::jsonb, cancellation_policy jsonb not null default '{}'::jsonb, recognition_policy jsonb not null default '{"method":"per_delivered_day"}'::jsonb,
  status text not null default 'active' check(status in('draft','active','expired')), created_by uuid references public.profiles(id), created_at timestamptz not null default now(), is_demo boolean not null default false,
  unique(package_id,version_number), check(effective_to is null or effective_to>=effective_from)
);
create table public.discount_limits (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  role_id uuid references public.roles(id), user_id uuid references public.profiles(id), maximum_percent numeric(5,2) not null check(maximum_percent between 0 and 100),
  effective_from date not null, effective_to date, approved_by uuid references public.profiles(id), is_demo boolean not null default false,
  check(num_nonnulls(role_id,user_id)=1)
);

create table public.quotations (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), quotation_number bigint generated by default as identity, customer_id uuid not null references public.customers(id),
  status text not null default 'draft' check(status in('draft','issued','accepted','rejected','expired','converted')),
  currency char(3) not null default 'EGP', subtotal numeric(18,2) not null default 0, discount_amount numeric(18,2) not null default 0,
  total_amount numeric(18,2) generated always as (subtotal-discount_amount) stored, valid_until date, notes text,
  created_by uuid not null references public.profiles(id), accepted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), is_demo boolean not null default false,
  unique(organization_id,quotation_number), check(discount_amount>=0 and discount_amount<=subtotal)
);
create table public.quotation_lines (
  id uuid primary key default extensions.gen_random_uuid(), quotation_id uuid not null references public.quotations(id) on delete cascade,
  package_version_id uuid references public.package_versions(id), description text not null, quantity numeric(12,2) not null default 1 check(quantity>0),
  unit_price numeric(18,2) not null check(unit_price>=0), discount_percent numeric(5,2) not null default 0 check(discount_percent between 0 and 100),
  line_total numeric(18,2) generated always as (quantity*unit_price*(1-discount_percent/100)) stored, price_snapshot jsonb not null default '{}'::jsonb, is_demo boolean not null default false
);
create table public.invoices (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), invoice_number bigint generated by default as identity, customer_id uuid not null references public.customers(id), quotation_id uuid references public.quotations(id),
  status text not null default 'issued' check(status in('draft','issued','partially_paid','paid','cancelled','refunded')),
  currency char(3) not null default 'EGP', total_amount numeric(18,2) not null check(total_amount>=0), confirmed_paid_amount numeric(18,2) not null default 0 check(confirmed_paid_amount>=0),
  issued_at timestamptz not null default now(), due_at timestamptz, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), is_demo boolean not null default false,
  unique(organization_id,invoice_number), check(confirmed_paid_amount<=total_amount)
);
create table public.invoice_lines (
  id uuid primary key default extensions.gen_random_uuid(), invoice_id uuid not null references public.invoices(id) on delete cascade,
  package_version_id uuid references public.package_versions(id), description text not null, quantity numeric(12,2) not null default 1, unit_price numeric(18,2) not null,
  line_total numeric(18,2) not null, source_snapshot jsonb not null default '{}'::jsonb, is_demo boolean not null default false
);

create table public.payment_submissions (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), submission_number bigint generated by default as identity, customer_id uuid not null references public.customers(id), invoice_id uuid references public.invoices(id),
  claimed_amount numeric(18,2) not null check(claimed_amount>0), currency char(3) not null default 'EGP', payment_method text not null,
  proof_reference text not null, external_reference text, status text not null default 'pending' check(status in('pending','under_review','confirmed','partially_confirmed','rejected','duplicate')),
  submitted_by uuid not null references public.profiles(id), submitted_at timestamptz not null default now(), reviewed_by uuid references public.profiles(id), reviewed_at timestamptz,
  confirmed_amount numeric(18,2), rejection_reason text, is_demo boolean not null default false,
  unique(organization_id,submission_number), check(reviewed_by is null or reviewed_by<>submitted_by)
);
create unique index payment_submission_reference_uidx on public.payment_submissions(organization_id,external_reference) where external_reference is not null;
create table public.payment_transactions (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), customer_id uuid not null references public.customers(id), submission_id uuid references public.payment_submissions(id),
  transaction_type text not null check(transaction_type in('collection','refund','reversal','adjustment')), amount numeric(18,2) not null check(amount<>0), currency char(3) not null default 'EGP',
  confirmed_by uuid not null references public.profiles(id), confirmed_at timestamptz not null default now(), reversal_of_id uuid references public.payment_transactions(id),
  idempotency_key text not null, is_demo boolean not null default false, unique(organization_id,idempotency_key)
);
create table public.payment_allocations (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  transaction_id uuid not null references public.payment_transactions(id), invoice_id uuid references public.invoices(id), subscription_id uuid,
  allocation_type text not null check(allocation_type in('invoice','subscription','customer_credit','advance','suspense')),
  amount numeric(18,2) not null check(amount>0), allocated_by uuid not null references public.profiles(id), allocated_at timestamptz not null default now(), reversed_at timestamptz, is_demo boolean not null default false
);

create table public.subscriptions (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), subscription_number bigint generated by default as identity, customer_id uuid not null references public.customers(id), invoice_id uuid not null references public.invoices(id),
  package_version_id uuid not null references public.package_versions(id), status text not null default 'pending_payment' check(status in('pending_payment','active','frozen','completed','cancelled')),
  starts_on date, ends_on date, purchased_service_days integer not null, delivered_service_days integer not null default 0,
  contract_value numeric(18,2) not null, deferred_balance numeric(18,2) not null default 0, recognized_revenue numeric(18,2) not null default 0,
  activated_by uuid references public.profiles(id), activated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), is_demo boolean not null default false,
  unique(organization_id,subscription_number), check(delivered_service_days between 0 and purchased_service_days), check(deferred_balance>=0 and recognized_revenue>=0)
);
alter table public.payment_allocations add constraint payment_allocations_subscription_fk foreign key(subscription_id) references public.subscriptions(id);
create table public.subscription_freezes (
  id uuid primary key default extensions.gen_random_uuid(), subscription_id uuid not null references public.subscriptions(id), starts_on date not null, ends_on date not null,
  reason text not null, status text not null default 'approved' check(status in('requested','approved','rejected','ended')), approved_by uuid references public.profiles(id), is_demo boolean not null default false,
  check(ends_on>=starts_on)
);
create table public.subscription_cancellations (
  id uuid primary key default extensions.gen_random_uuid(), subscription_id uuid not null references public.subscriptions(id), reason_id uuid references public.cancellation_reasons(id), details text,
  requested_by uuid not null references public.profiles(id), requested_at timestamptz not null default now(), approved_by uuid references public.profiles(id), approved_at timestamptz,
  status text not null default 'requested' check(status in('requested','approved','rejected','completed')), is_demo boolean not null default false,
  check(approved_by is null or approved_by<>requested_by)
);
create table public.refunds (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id), customer_id uuid not null references public.customers(id), subscription_id uuid references public.subscriptions(id),
  amount numeric(18,2) not null check(amount>0), reason text not null, status text not null default 'requested' check(status in('requested','under_review','approved','paid','rejected','cancelled')),
  requested_by uuid not null references public.profiles(id), approved_by uuid references public.profiles(id), paid_by uuid references public.profiles(id), payment_proof_reference text,
  requested_at timestamptz not null default now(), approved_at timestamptz, paid_at timestamptz, is_demo boolean not null default false,
  check(approved_by is null or approved_by<>requested_by)
);
create table public.planned_service_days (
  id uuid primary key default extensions.gen_random_uuid(), subscription_id uuid not null references public.subscriptions(id), service_date date not null,
  status text not null default 'planned' check(status in('planned','frozen','cancelled','not_delivered','exception','delivered_pending_confirmation')),
  branch_id uuid references public.branches(id), is_demo boolean not null default false, unique(subscription_id,service_date)
);
create table public.service_delivery_confirmations (
  id uuid primary key default extensions.gen_random_uuid(), planned_service_day_id uuid not null references public.planned_service_days(id), subscription_id uuid not null references public.subscriptions(id),
  status text not null check(status in('confirmed_delivered','reversed')), confirmed_by uuid not null references public.profiles(id), confirmed_at timestamptz not null default now(),
  reversal_of_id uuid references public.service_delivery_confirmations(id), reversal_reason text, is_demo boolean not null default false
);
create unique index one_active_delivery_confirmation on public.service_delivery_confirmations(planned_service_day_id) where status='confirmed_delivered';
create table public.revenue_entries (
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id), delivery_confirmation_id uuid references public.service_delivery_confirmations(id),
  entry_type text not null check(entry_type in('recognition','reversal','adjustment')), amount numeric(18,2) not null check(amount<>0), entry_date date not null,
  created_by uuid not null references public.profiles(id), idempotency_key text not null, is_demo boolean not null default false,
  unique(organization_id,idempotency_key)
);

create index quotations_scope_idx on public.quotations(organization_id,branch_id,status,created_at desc);
create index invoices_scope_idx on public.invoices(organization_id,branch_id,status,issued_at desc);
create index payment_submissions_queue_idx on public.payment_submissions(organization_id,status,submitted_at);
create index payment_transactions_customer_idx on public.payment_transactions(customer_id,confirmed_at desc);
create index subscriptions_ops_idx on public.subscriptions(organization_id,branch_id,status,ends_on);
create index planned_service_days_daily_idx on public.planned_service_days(service_date,branch_id,status);

create trigger packages_set_updated_at before update on public.packages for each row execute function public.set_updated_at();
create trigger quotations_set_updated_at before update on public.quotations for each row execute function public.set_updated_at();
create trigger invoices_set_updated_at before update on public.invoices for each row execute function public.set_updated_at();
create trigger subscriptions_set_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();
create trigger audit_quotations after insert or update or delete on public.quotations for each row execute function public.audit_row_change();
create trigger audit_invoices after insert or update or delete on public.invoices for each row execute function public.audit_row_change();
create trigger audit_payment_submissions after insert or update or delete on public.payment_submissions for each row execute function public.audit_row_change();
create trigger audit_payment_transactions after insert or update or delete on public.payment_transactions for each row execute function public.audit_row_change();
create trigger audit_subscriptions after insert or update or delete on public.subscriptions for each row execute function public.audit_row_change();
create trigger audit_refunds after insert or update or delete on public.refunds for each row execute function public.audit_row_change();
create trigger audit_delivery_confirmations after insert or update or delete on public.service_delivery_confirmations for each row execute function public.audit_row_change();

create or replace function public.confirm_payment_submission(p_submission_id uuid,p_confirmed_amount numeric,p_actor_user_id uuid,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_submission public.payment_submissions; v_transaction_id uuid; v_invoice public.invoices;
begin
  select * into v_submission from public.payment_submissions where id=p_submission_id for update;
  if v_submission.id is null or v_submission.status not in('pending','under_review') then raise exception 'payment submission is not confirmable'; end if;
  if p_actor_user_id=v_submission.submitted_by then raise exception 'maker cannot confirm own payment'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.confirm',v_submission.organization_id)) then raise exception 'payments.confirm is required'; end if;
  if p_confirmed_amount<=0 or p_confirmed_amount>v_submission.claimed_amount then raise exception 'invalid confirmed amount'; end if;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,submission_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_submission.organization_id,v_submission.branch_id,v_submission.customer_id,v_submission.id,'collection',p_confirmed_amount,v_submission.currency,p_actor_user_id,p_idempotency_key,v_submission.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.payment_submissions set status=case when p_confirmed_amount=v_submission.claimed_amount then 'confirmed' else 'partially_confirmed' end,
    confirmed_amount=p_confirmed_amount,reviewed_by=p_actor_user_id,reviewed_at=now() where id=v_submission.id;
  if v_submission.invoice_id is not null then
    select * into v_invoice from public.invoices where id=v_submission.invoice_id for update;
    update public.invoices set confirmed_paid_amount=least(total_amount,confirmed_paid_amount+p_confirmed_amount),
      status=case when confirmed_paid_amount+p_confirmed_amount>=total_amount then 'paid' else 'partially_paid' end where id=v_invoice.id;
    insert into public.payment_allocations(organization_id,transaction_id,invoice_id,allocation_type,amount,allocated_by,is_demo)
    values(v_submission.organization_id,v_transaction_id,v_invoice.id,'invoice',least(p_confirmed_amount,v_invoice.total_amount-v_invoice.confirmed_paid_amount),p_actor_user_id,v_submission.is_demo);
  end if;
  perform public.enqueue_domain_event(v_submission.organization_id,v_submission.branch_id,'payment.confirmed','payment_transaction',v_transaction_id,jsonb_build_object('amount',p_confirmed_amount,'invoice_id',v_submission.invoice_id),p_actor_user_id,'payment.confirmed:'||v_transaction_id::text,v_submission.is_demo);
  return v_transaction_id;
end; $$;

create or replace function public.activate_subscription(p_subscription_id uuid,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_invoice public.invoices;
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  select * into v_invoice from public.invoices where id=v_subscription.invoice_id;
  if v_invoice.status not in('paid','partially_paid') or v_invoice.confirmed_paid_amount<=0 then raise exception 'confirmed payment is required'; end if;
  if auth.uid() is not null and not public.has_permission('subscriptions.manage',v_subscription.organization_id) then raise exception 'subscriptions.manage is required'; end if;
  update public.subscriptions set status='active',activated_by=p_actor_user_id,activated_at=now(),deferred_balance=least(contract_value,v_invoice.confirmed_paid_amount),updated_at=now() where id=p_subscription_id;
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'subscription.activated','subscription',v_subscription.id,'{}'::jsonb,p_actor_user_id,'subscription.activated:'||v_subscription.id::text,v_subscription.is_demo);
end; $$;

create or replace function public.confirm_service_delivery(p_planned_day_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_day public.planned_service_days; v_subscription public.subscriptions; v_confirmation_id uuid; v_amount numeric(18,2);
begin
  select * into v_day from public.planned_service_days where id=p_planned_day_id for update;
  select * into v_subscription from public.subscriptions where id=v_day.subscription_id for update;
  if v_day.status not in('planned','delivered_pending_confirmation') or v_subscription.status<>'active' then raise exception 'service day is not deliverable'; end if;
  if auth.uid() is not null and not public.has_permission('service.confirm_delivery',v_subscription.organization_id) then raise exception 'service.confirm_delivery is required'; end if;
  insert into public.service_delivery_confirmations(planned_service_day_id,subscription_id,status,confirmed_by,is_demo)
  values(v_day.id,v_subscription.id,'confirmed_delivered',p_actor_user_id,v_day.is_demo) returning id into v_confirmation_id;
  v_amount:=round(v_subscription.contract_value/v_subscription.purchased_service_days,2);
  insert into public.revenue_entries(organization_id,subscription_id,delivery_confirmation_id,entry_type,amount,entry_date,created_by,idempotency_key,is_demo)
  values(v_subscription.organization_id,v_subscription.id,v_confirmation_id,'recognition',v_amount,v_day.service_date,p_actor_user_id,'delivery:'||v_day.id::text,v_day.is_demo);
  update public.planned_service_days set status='delivered_pending_confirmation' where id=v_day.id;
  update public.subscriptions set delivered_service_days=delivered_service_days+1,recognized_revenue=recognized_revenue+v_amount,deferred_balance=greatest(0,deferred_balance-v_amount),updated_at=now() where id=v_subscription.id;
  return v_confirmation_id;
end; $$;

create view public.subscriber_operations_v with(security_invoker=true) as
select s.id,s.organization_id,s.branch_id,s.subscription_number,s.status,s.starts_on,s.ends_on,s.purchased_service_days,s.delivered_service_days,
  s.purchased_service_days-s.delivered_service_days as remaining_service_days,s.deferred_balance,c.full_name as customer_name,p.name as package_name
from public.subscriptions s join public.customers c on c.id=s.customer_id join public.package_versions pv on pv.id=s.package_version_id join public.packages p on p.id=pv.package_id;
create view public.daily_subscriber_list_v with(security_invoker=true) as
select d.id,d.service_date,d.status,d.branch_id,s.subscription_number,c.full_name as customer_name,p.name as package_name
from public.planned_service_days d join public.subscriptions s on s.id=d.subscription_id join public.customers c on c.id=s.customer_id join public.package_versions pv on pv.id=s.package_version_id join public.packages p on p.id=pv.package_id;

do $$ declare t text; begin foreach t in array array['packages','package_versions','discount_limits','quotations','quotation_lines','invoices','invoice_lines','payment_submissions','payment_transactions','payment_allocations','subscriptions','subscription_freezes','subscription_cancellations','refunds','planned_service_days','service_delivery_confirmations','revenue_entries'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy package_select on public.packages for select to authenticated using(public.has_permission('catalog.view',organization_id));
create policy package_manage on public.packages for all to authenticated using(public.has_permission('catalog.manage',organization_id)) with check(public.has_permission('catalog.manage',organization_id));
create policy package_versions_scope on public.package_versions for select to authenticated using(exists(select 1 from public.packages p where p.id=package_id));
create policy quotations_scope on public.quotations for all to authenticated using(public.has_permission('sales.quote',organization_id) and public.can_access_branch(organization_id,branch_id)) with check(public.has_permission('sales.quote',organization_id) and created_by=auth.uid());
create policy quotation_lines_scope on public.quotation_lines for all to authenticated using(exists(select 1 from public.quotations q where q.id=quotation_id)) with check(exists(select 1 from public.quotations q where q.id=quotation_id));
create policy invoices_scope on public.invoices for select to authenticated using((public.has_permission('sales.invoice',organization_id) or public.has_permission('payments.review',organization_id)) and public.can_access_branch(organization_id,branch_id));
create policy invoice_lines_scope on public.invoice_lines for select to authenticated using(exists(select 1 from public.invoices i where i.id=invoice_id));
create policy payment_submissions_scope on public.payment_submissions for select to authenticated using((submitted_by=auth.uid() or public.has_permission('payments.review',organization_id)) and public.can_access_branch(organization_id,branch_id));
create policy payment_submissions_insert on public.payment_submissions for insert to authenticated with check(submitted_by=auth.uid() and public.has_permission('payments.submit',organization_id));
create policy payment_transactions_scope on public.payment_transactions for select to authenticated using(public.has_permission('payments.review',organization_id) and public.can_access_branch(organization_id,branch_id));
create policy allocations_scope on public.payment_allocations for select to authenticated using(public.has_permission('payments.review',organization_id));
create policy subscriptions_scope on public.subscriptions for select to authenticated using(public.has_permission('subscriptions.view',organization_id) and public.can_access_branch(organization_id,branch_id));
create policy freezes_scope on public.subscription_freezes for select to authenticated using(exists(select 1 from public.subscriptions s where s.id=subscription_id));
create policy cancellations_scope on public.subscription_cancellations for select to authenticated using(exists(select 1 from public.subscriptions s where s.id=subscription_id));
create policy refunds_scope on public.refunds for select to authenticated using((requested_by=auth.uid() or public.has_permission('refunds.approve',organization_id)) and public.can_access_branch(organization_id,branch_id));
create policy planned_days_scope on public.planned_service_days for select to authenticated using(exists(select 1 from public.subscriptions s where s.id=subscription_id));
create policy confirmations_scope on public.service_delivery_confirmations for select to authenticated using(exists(select 1 from public.subscriptions s where s.id=subscription_id));
create policy revenue_scope on public.revenue_entries for select to authenticated using(public.has_permission('revenue.view',organization_id));

insert into public.schema_versions(version,name) values(7,'sales_finance_subscriptions');
commit;

-- ============================================================================
-- 0008_targets_sales_commissions.sql
-- ============================================================================
begin;

insert into public.permissions(code,name,module,description,is_sensitive) values
('targets.view_own','View own targets','Performance','View personal target and attainment',false),
('targets.view_team','View team targets','Performance','View team target performance',false),
('targets.manage','Manage targets','Performance','Create and revise targets',true),
('sales_commissions.view_own','View own sales commissions','Performance','View personal sales commission entries',false),
('sales_commissions.review','Review sales commissions','Performance','Review eligible sales commissions',true),
('sales_commissions.approve','Approve sales commissions','Performance','Approve commissions under maker-checker',true)
on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_own','sales_commissions.view_own') where r.code='sales_representative' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_own','targets.view_team','sales_commissions.view_own','sales_commissions.review') where r.code in('sales_manager','sales_team_leader') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_team','targets.manage','sales_commissions.review','sales_commissions.approve') where r.code='finance_manager' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.code='ceo_super_admin' on conflict do nothing;

create table public.sales_targets(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id), target_type text not null check(target_type in('user','team')),
  user_id uuid references public.profiles(id), team_id uuid references public.teams(id), period_start date not null, period_end date not null,
  target_amount numeric(18,2) not null check(target_amount>=0), currency char(3) not null default 'EGP', created_by uuid references public.profiles(id), created_at timestamptz not null default now(), is_demo boolean not null default false,
  check(num_nonnulls(user_id,team_id)=1), check(period_end>=period_start)
);
create table public.sales_commission_policies(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, applies_to_role_code text, is_active boolean not null default true, created_at timestamptz not null default now(), is_demo boolean not null default false
);
create table public.sales_commission_policy_versions(
  id uuid primary key default extensions.gen_random_uuid(), policy_id uuid not null references public.sales_commission_policies(id) on delete cascade,
  version_number integer not null, method text not null check(method in('confirmed_cash_percent','fixed_per_sale','tiered')),
  value numeric(18,4) not null check(value>=0), team_leader_bonus_percent numeric(5,2) not null default 0 check(team_leader_bonus_percent between 0 and 100),
  tiers jsonb not null default '[]'::jsonb, effective_from date not null, effective_to date, created_by uuid references public.profiles(id), is_demo boolean not null default false,
  unique(policy_id,version_number), check(effective_to is null or effective_to>=effective_from)
);
create table public.sales_commission_entries(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id), beneficiary_user_id uuid not null references public.profiles(id), source_transaction_id uuid references public.payment_transactions(id), refund_id uuid references public.refunds(id),
  policy_version_id uuid references public.sales_commission_policy_versions(id), entry_type text not null check(entry_type in('commission','team_leader_bonus','clawback','adjustment')),
  basis_amount numeric(18,2) not null, amount numeric(18,2) not null, status text not null default 'eligible' check(status in('estimated','eligible','under_review','approved','paid','clawback_required','reversed','disputed')),
  created_at timestamptz not null default now(), reviewed_by uuid references public.profiles(id), approved_by uuid references public.profiles(id), approved_at timestamptz, is_demo boolean not null default false,
  check(approved_by is null or approved_by<>beneficiary_user_id)
);
create unique index sales_commission_collection_uidx on public.sales_commission_entries(beneficiary_user_id,source_transaction_id,entry_type) where source_transaction_id is not null;
create unique index sales_commission_refund_uidx on public.sales_commission_entries(beneficiary_user_id,refund_id,entry_type) where refund_id is not null;

create or replace function public.create_sales_commission_from_collection()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_quote public.quotations; v_version public.sales_commission_policy_versions; v_amount numeric(18,2);
begin
  if new.transaction_type<>'collection' then return new; end if;
  select i.* into v_invoice from public.invoices i join public.payment_submissions ps on ps.invoice_id=i.id where ps.id=new.submission_id;
  if v_invoice.id is null then return new; end if;
  select * into v_quote from public.quotations where id=v_invoice.quotation_id;
  if v_quote.created_by is null then return new; end if;
  select pv.* into v_version from public.sales_commission_policy_versions pv join public.sales_commission_policies p on p.id=pv.policy_id
  where p.organization_id=new.organization_id and p.is_active and current_date>=pv.effective_from and (pv.effective_to is null or current_date<=pv.effective_to)
  order by pv.effective_from desc limit 1;
  if v_version.id is null then return new; end if;
  v_amount:=case when v_version.method='fixed_per_sale' then v_version.value else round(new.amount*v_version.value/100,2) end;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,source_transaction_id,policy_version_id,entry_type,basis_amount,amount,status,is_demo)
  values(new.organization_id,new.branch_id,v_quote.created_by,new.id,v_version.id,'commission',new.amount,v_amount,'eligible',new.is_demo)
  on conflict do nothing;
  return new;
end; $$;
create trigger payment_transaction_sales_commission after insert on public.payment_transactions for each row execute function public.create_sales_commission_from_collection();

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_transaction_id uuid;
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' then raise exception 'refund is not payable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot pay own refund'; end if;
  if auth.uid() is not null and not public.has_permission('refunds.approve',v_refund.organization_id) then raise exception 'refund approval permission required'; end if;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  returning id into v_transaction_id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=p_proof_reference where id=v_refund.id;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,
    -least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(ce.basis_amount,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce join public.payment_transactions pt on pt.id=ce.source_transaction_id
  where pt.customer_id=v_refund.customer_id and ce.entry_type='commission' and ce.status not in('reversed')
  on conflict do nothing;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

create view public.sales_performance_v with(security_invoker=true) as
select t.id,t.organization_id,t.branch_id,t.target_type,t.user_id,t.team_id,t.period_start,t.period_end,t.target_amount,
  coalesce(sum(pt.amount) filter(where pt.transaction_type='collection' and pt.confirmed_at::date between t.period_start and t.period_end and (t.user_id is null or q.created_by=t.user_id)),0) as confirmed_cash,
  case when t.target_amount=0 then 0 else round(coalesce(sum(pt.amount) filter(where pt.transaction_type='collection' and pt.confirmed_at::date between t.period_start and t.period_end and (t.user_id is null or q.created_by=t.user_id)),0)/t.target_amount*100,2) end as achievement_percent
from public.sales_targets t left join public.quotations q on q.organization_id=t.organization_id left join public.invoices i on i.quotation_id=q.id
left join public.payment_submissions ps on ps.invoice_id=i.id left join public.payment_transactions pt on pt.submission_id=ps.id
group by t.id;

do $$ declare t text; begin foreach t in array array['sales_targets','sales_commission_policies','sales_commission_policy_versions','sales_commission_entries'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy targets_scope on public.sales_targets for select to authenticated using(user_id=auth.uid() or public.has_permission('targets.view_team',organization_id));
create policy targets_manage_scope on public.sales_targets for all to authenticated using(public.has_permission('targets.manage',organization_id)) with check(public.has_permission('targets.manage',organization_id));
create policy sales_policy_scope on public.sales_commission_policies for select to authenticated using(public.has_permission('sales_commissions.review',organization_id));
create policy sales_policy_versions_scope on public.sales_commission_policy_versions for select to authenticated using(exists(select 1 from public.sales_commission_policies p where p.id=policy_id and public.has_permission('sales_commissions.review',p.organization_id)));
create policy sales_commission_scope on public.sales_commission_entries for select to authenticated using(beneficiary_user_id=auth.uid() or public.has_permission('sales_commissions.review',organization_id));
create trigger audit_sales_targets after insert or update or delete on public.sales_targets for each row execute function public.audit_row_change();
create trigger audit_sales_commissions after insert or update or delete on public.sales_commission_entries for each row execute function public.audit_row_change();

insert into public.schema_versions(version,name) values(8,'targets_sales_commissions');
commit;

-- ============================================================================
-- 0009_doctors_sessions_accounting.sql
-- ============================================================================
begin;

create extension if not exists btree_gist with schema extensions;

insert into public.roles(code,name,description,is_system) values('doctor','Doctor','Doctor self-service sessions, notes and earnings',true) on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('dashboard.view','notifications.view','tasks.view_own','tasks.respond','doctors.view','doctors.manage_availability','sessions.view_own','sessions.complete','sessions.write_notes','sessions.view_medical_notes','doctor_commissions.view_own') where r.code='doctor' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('doctors.view','doctors.manage','doctors.manage_availability','sessions.create','sessions.assign','sessions.view_team','sessions.reschedule','sessions.cancel') where r.code in('operations_manager','customer_service') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('doctors.view','doctors.view_financials','doctor_commissions.review','doctor_commissions.approve','doctor_commissions.pay','doctor_commissions.reverse') where r.code in('finance_manager','finance_accountant') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.code='ceo_super_admin' on conflict do nothing;

create table public.specialties(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,name text not null,is_active boolean not null default true,is_demo boolean not null default false,unique(organization_id,code)
);
create table public.doctors(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid references public.profiles(id), doctor_number bigint generated by default as identity, full_name text not null,mobile text,email extensions.citext,
  qualifications text,license_information text,bio text,languages text[] not null default '{}',gender text,consultation_types text[] not null default '{}',
  online_enabled boolean not null default true,onsite_enabled boolean not null default true,standard_session_price numeric(18,2),status text not null default 'active' check(status in('active','inactive')),
  contract_start date,contract_end date,maximum_sessions_per_day integer not null default 8,break_minutes integer not null default 15,
  rating numeric(3,2),cancellation_rate numeric(5,2) not null default 0,no_show_rate numeric(5,2) not null default 0,notes text,profile_photo_path text,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(organization_id,doctor_number),check(contract_end is null or contract_start is null or contract_end>=contract_start)
);
create table public.doctor_specialties(
  doctor_id uuid not null references public.doctors(id) on delete cascade,specialty_id uuid not null references public.specialties(id),subspecialty text,is_primary boolean not null default false,is_demo boolean not null default false,primary key(doctor_id,specialty_id)
);
create table public.doctor_branches(
  doctor_id uuid not null references public.doctors(id) on delete cascade,branch_id uuid not null references public.branches(id),online_allowed boolean not null default true,onsite_allowed boolean not null default true,is_demo boolean not null default false,primary key(doctor_id,branch_id)
);
create table public.doctor_financial_profiles(
  id uuid primary key default extensions.gen_random_uuid(),doctor_id uuid not null unique references public.doctors(id) on delete cascade,
  payout_method text,bank_reference_encrypted text,contract_notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false
);
create table public.doctor_services(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,name text not null,specialty_id uuid references public.specialties(id),status text not null default 'active',is_demo boolean not null default false,unique(organization_id,code)
);
create table public.doctor_service_versions(
  id uuid primary key default extensions.gen_random_uuid(),service_id uuid not null references public.doctor_services(id) on delete cascade,version_number integer not null,
  duration_minutes integer not null check(duration_minutes>0),customer_price numeric(18,2) not null check(customer_price>=0),commission_type text not null check(commission_type in('fixed','percent_net','percent_confirmed_cash')),
  commission_value numeric(18,4) not null check(commission_value>=0),branch_id uuid references public.branches(id),delivery_mode text not null check(delivery_mode in('online','onsite','both')),
  tax_treatment text,requires_prepayment boolean not null default true,cancellation_policy jsonb not null default '{}'::jsonb,rescheduling_policy jsonb not null default '{}'::jsonb,
  active_from date not null,active_to date,status text not null default 'active',is_demo boolean not null default false,unique(service_id,version_number)
);
create table public.doctor_availability_rules(
  id uuid primary key default extensions.gen_random_uuid(),doctor_id uuid not null references public.doctors(id) on delete cascade,branch_id uuid references public.branches(id),
  day_of_week integer not null check(day_of_week between 0 and 6),start_time time not null,end_time time not null,session_duration_minutes integer not null,break_minutes integer not null default 0,
  delivery_mode text not null check(delivery_mode in('online','onsite','both')),maximum_daily_sessions integer not null default 8,minimum_notice_minutes integer not null default 120,
  effective_from date not null,effective_to date,is_active boolean not null default true,is_demo boolean not null default false,check(end_time>start_time)
);
create table public.doctor_unavailability(
  id uuid primary key default extensions.gen_random_uuid(),doctor_id uuid not null references public.doctors(id) on delete cascade,starts_at timestamptz not null,ends_at timestamptz not null,
  reason_type text not null check(reason_type in('blocked','vacation','emergency','external_conflict')),reason text,is_demo boolean not null default false,check(ends_at>starts_at)
);
create table public.doctor_slots(
  id uuid primary key default extensions.gen_random_uuid(),doctor_id uuid not null references public.doctors(id) on delete cascade,branch_id uuid references public.branches(id),
  starts_at timestamptz not null,ends_at timestamptz not null,delivery_mode text not null check(delivery_mode in('online','onsite')),status text not null default 'available' check(status in('available','held','booked','blocked')),
  hold_expires_at timestamptz,is_demo boolean not null default false,unique(doctor_id,starts_at),check(ends_at>starts_at)
);
create table public.doctor_sessions(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,branch_id uuid references public.branches(id),
  session_number bigint generated by default as identity,customer_id uuid not null references public.customers(id),doctor_id uuid references public.doctors(id),service_version_id uuid not null references public.doctor_service_versions(id),
  invoice_id uuid references public.invoices(id),payment_transaction_id uuid references public.payment_transactions(id),delivery_mode text not null check(delivery_mode in('online','onsite')),
  status text not null default 'requested' check(status in('draft','requested','doctor_matching','slot_held','awaiting_payment','payment_under_review','confirmed','calendar_pending','scheduled','reminder_sent','customer_checked_in','in_progress','completed_pending_notes','completed','customer_cancelled','doctor_cancelled','rescheduled','no_show','refund_requested','refunded','closed')),
  scheduled_start timestamptz not null,scheduled_end timestamptz not null,scheduled_range tstzrange generated always as(tstzrange(scheduled_start,scheduled_end,'[)')) stored,
  slot_hold_expires_at timestamptz,brief_reason text,customer_preference jsonb not null default '{}'::jsonb,created_by uuid not null references public.profiles(id),
  completed_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(organization_id,session_number),check(scheduled_end>scheduled_start)
);
alter table public.doctor_sessions add constraint doctor_sessions_no_double_booking exclude using gist(doctor_id with =,scheduled_range with &&) where(doctor_id is not null and status in('slot_held','confirmed','calendar_pending','scheduled','reminder_sent','customer_checked_in','in_progress','completed_pending_notes'));
create table public.session_assignments(
  id uuid primary key default extensions.gen_random_uuid(),session_id uuid not null references public.doctor_sessions(id) on delete cascade,doctor_id uuid not null references public.doctors(id),
  selection_method text not null check(selection_method in('round_robin','least_loaded','fixed_doctor','customer_selected','manual','specialty_queue')),
  rotation_position integer,assigned_by uuid references public.profiles(id),assigned_at timestamptz not null default now(),override_reason text,is_selected boolean not null default true,is_demo boolean not null default false
);
create table public.session_status_history(
  id uuid primary key default extensions.gen_random_uuid(),session_id uuid not null references public.doctor_sessions(id) on delete cascade,from_status text,to_status text not null,
  changed_by uuid references public.profiles(id),reason text,changed_at timestamptz not null default now(),is_demo boolean not null default false
);
create table public.session_notes(
  id uuid primary key default extensions.gen_random_uuid(),session_id uuid not null references public.doctor_sessions(id) on delete cascade,doctor_id uuid not null references public.doctors(id),
  attendance text,start_time timestamptz,end_time timestamptz,outcome text,customer_goals text,preferences text,restrictions text,
  clinical_note text,customer_visible_summary text,sales_recommendation text,operations_instruction text,followup_required boolean not null default false,escalation_required boolean not null default false,
  completed_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),is_demo boolean not null default false,unique(session_id)
);
create table public.doctor_recommendations(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,session_id uuid not null references public.doctor_sessions(id),doctor_id uuid not null references public.doctors(id),
  customer_id uuid not null references public.customers(id),package_version_id uuid references public.package_versions(id),recommended_at timestamptz not null default now(),attribution_expires_at timestamptz,
  sales_user_id uuid references public.profiles(id),customer_decision text,decline_reason text,confirmed_payment_transaction_id uuid references public.payment_transactions(id),commission_status text not null default 'pending',is_demo boolean not null default false
);
create table public.session_feedback(
  id uuid primary key default extensions.gen_random_uuid(),session_id uuid not null unique references public.doctor_sessions(id),session_rating integer check(session_rating between 1 and 5),doctor_rating integer check(doctor_rating between 1 and 5),
  booking_experience integer check(booking_experience between 1 and 5),punctuality integer check(punctuality between 1 and 5),helpfulness integer check(helpfulness between 1 and 5),recommendation_score integer check(recommendation_score between 0 and 10),
  comment text,complaint_required boolean not null default false,followup_required boolean not null default false,consent_to_share boolean not null default false,created_at timestamptz not null default now(),is_demo boolean not null default false
);

create table public.doctor_commission_policies(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,doctor_id uuid references public.doctors(id),service_id uuid references public.doctor_services(id),name text not null,is_active boolean not null default true,is_demo boolean not null default false
);
create table public.doctor_commission_policy_versions(
  id uuid primary key default extensions.gen_random_uuid(),policy_id uuid not null references public.doctor_commission_policies(id) on delete cascade,version_number integer not null,
  method text not null check(method in('fixed_session','percent_session_net','percent_confirmed_cash','fixed_referral','percent_recommended_package','tiered')),
  value numeric(18,4) not null,tiers jsonb not null default '[]'::jsonb,effective_from date not null,effective_to date,notes_required boolean not null default true,is_demo boolean not null default false,unique(policy_id,version_number)
);
create table public.doctor_commission_entries(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,doctor_id uuid not null references public.doctors(id),
  session_id uuid references public.doctor_sessions(id),recommendation_id uuid references public.doctor_recommendations(id),policy_version_id uuid references public.doctor_commission_policy_versions(id),
  entry_type text not null check(entry_type in('session','recommendation','adjustment','clawback')),basis_amount numeric(18,2) not null,amount numeric(18,2) not null,
  status text not null default 'estimated' check(status in('estimated','pending_payment_confirmation','pending_session_completion','eligible','under_finance_review','approved','scheduled_for_payout','paid','partially_paid','clawback_required','reversed','disputed')),
  reviewed_by uuid references public.profiles(id),approved_by uuid references public.profiles(id),created_at timestamptz not null default now(),is_demo boolean not null default false,
  unique(session_id,entry_type),check(approved_by is null or approved_by<>reviewed_by)
);
create table public.doctor_statements(
  id uuid primary key default extensions.gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,doctor_id uuid not null references public.doctors(id),
  period_start date not null,period_end date not null,gross_eligible numeric(18,2) not null default 0,adjustments numeric(18,2) not null default 0,clawbacks numeric(18,2) not null default 0,
  paid_amount numeric(18,2) not null default 0,outstanding_amount numeric(18,2) not null default 0,status text not null default 'draft' check(status in('draft','under_review','approved','partially_paid','paid')),
  approved_by uuid references public.profiles(id),approved_at timestamptz,payout_date date,payment_reference text,is_demo boolean not null default false,unique(doctor_id,period_start,period_end)
);
create table public.doctor_statement_lines(
  statement_id uuid not null references public.doctor_statements(id) on delete cascade,commission_entry_id uuid not null references public.doctor_commission_entries(id),amount numeric(18,2) not null,is_demo boolean not null default false,primary key(statement_id,commission_entry_id)
);
create table public.doctor_payouts(
  id uuid primary key default extensions.gen_random_uuid(),statement_id uuid not null references public.doctor_statements(id),amount numeric(18,2) not null check(amount>0),
  status text not null default 'pending_approval' check(status in('pending_approval','approved','paid','rejected')),requested_by uuid not null references public.profiles(id),approved_by uuid references public.profiles(id),paid_by uuid references public.profiles(id),
  payment_proof_reference text,paid_at timestamptz,is_demo boolean not null default false,check(approved_by is null or approved_by<>requested_by)
);

create index doctors_scope_idx on public.doctors(organization_id,status);
create index slots_search_idx on public.doctor_slots(starts_at,branch_id,delivery_mode,status);
create index sessions_calendar_idx on public.doctor_sessions(organization_id,doctor_id,scheduled_start,status);
create index doctor_commissions_idx on public.doctor_commission_entries(doctor_id,status,created_at);
create trigger doctors_set_updated_at before update on public.doctors for each row execute function public.set_updated_at();
create trigger doctor_financials_set_updated_at before update on public.doctor_financial_profiles for each row execute function public.set_updated_at();
create trigger sessions_set_updated_at before update on public.doctor_sessions for each row execute function public.set_updated_at();
create trigger session_notes_set_updated_at before update on public.session_notes for each row execute function public.set_updated_at();
create trigger audit_doctors after insert or update or delete on public.doctors for each row execute function public.audit_row_change();
create trigger audit_sessions after insert or update or delete on public.doctor_sessions for each row execute function public.audit_row_change();
create trigger audit_doctor_commissions after insert or update or delete on public.doctor_commission_entries for each row execute function public.audit_row_change();
create trigger audit_doctor_payouts after insert or update or delete on public.doctor_payouts for each row execute function public.audit_row_change();

create or replace function public.assign_session_round_robin(p_session_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_session public.doctor_sessions;v_specialty_id uuid;v_doctor_id uuid;
begin
  select * into v_session from public.doctor_sessions where id=p_session_id for update;
  if v_session.id is null then raise exception 'session not found'; end if;
  if auth.uid() is not null and not public.has_permission('sessions.assign',v_session.organization_id) then raise exception 'sessions.assign is required'; end if;
  select ds.specialty_id into v_specialty_id from public.doctor_service_versions sv join public.doctor_services ds on ds.id=sv.service_id where sv.id=v_session.service_version_id;
  select d.id into v_doctor_id from public.doctors d join public.doctor_specialties sp on sp.doctor_id=d.id and sp.specialty_id=v_specialty_id
  where d.organization_id=v_session.organization_id and d.status='active'
    and exists(select 1 from public.doctor_branches db where db.doctor_id=d.id and (v_session.branch_id is null or db.branch_id=v_session.branch_id))
    and not exists(select 1 from public.doctor_sessions s where s.doctor_id=d.id and s.status in('slot_held','confirmed','calendar_pending','scheduled','in_progress') and s.scheduled_range && v_session.scheduled_range)
  order by (select count(*) from public.doctor_sessions sx where sx.doctor_id=d.id and sx.scheduled_start::date=v_session.scheduled_start::date),d.id limit 1;
  if v_doctor_id is null then raise exception 'no eligible doctor available'; end if;
  update public.doctor_sessions set doctor_id=v_doctor_id,status=case when status='requested' then 'slot_held' else status end,slot_hold_expires_at=now()+interval '15 minutes' where id=v_session.id;
  insert into public.session_assignments(session_id,doctor_id,selection_method,assigned_by,is_demo) values(v_session.id,v_doctor_id,'round_robin',p_actor_user_id,v_session.is_demo);
  return v_doctor_id;
end; $$;

create or replace function public.complete_doctor_session(p_session_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_session public.doctor_sessions;v_notes public.session_notes;v_policy public.doctor_commission_policy_versions;v_service public.doctor_service_versions;v_entry_id uuid;v_amount numeric(18,2);
begin
  select * into v_session from public.doctor_sessions where id=p_session_id for update;
  select * into v_notes from public.session_notes where session_id=p_session_id;
  select * into v_service from public.doctor_service_versions where id=v_session.service_version_id;
  if v_session.doctor_id is null or v_session.status not in('in_progress','completed_pending_notes') then raise exception 'session is not completable'; end if;
  if v_service.requires_prepayment and v_session.payment_transaction_id is null then raise exception 'confirmed payment is required'; end if;
  if v_notes.id is null or v_notes.outcome is null then raise exception 'required session notes are incomplete'; end if;
  if auth.uid() is not null and p_actor_user_id<>auth.uid() then raise exception 'actor mismatch'; end if;
  update public.doctor_sessions set status='completed',completed_at=now() where id=v_session.id;
  select pv.* into v_policy from public.doctor_commission_policy_versions pv join public.doctor_commission_policies p on p.id=pv.policy_id
  where p.organization_id=v_session.organization_id and p.is_active and (p.doctor_id is null or p.doctor_id=v_session.doctor_id) and current_date>=pv.effective_from and (pv.effective_to is null or current_date<=pv.effective_to)
  order by(p.doctor_id is not null) desc,pv.effective_from desc limit 1;
  if v_policy.id is not null then
    v_amount:=case when v_policy.method='fixed_session' then v_policy.value else round(v_service.customer_price*v_policy.value/100,2) end;
    insert into public.doctor_commission_entries(organization_id,doctor_id,session_id,policy_version_id,entry_type,basis_amount,amount,status,is_demo)
    values(v_session.organization_id,v_session.doctor_id,v_session.id,v_policy.id,'session',v_service.customer_price,v_amount,'eligible',v_session.is_demo)
    on conflict(session_id,entry_type) do update set status=excluded.status returning id into v_entry_id;
  end if;
  perform public.enqueue_domain_event(v_session.organization_id,v_session.branch_id,'doctor_session.completed','doctor_session',v_session.id,'{}'::jsonb,p_actor_user_id,'doctor_session.completed:'||v_session.id::text,v_session.is_demo);
  return v_entry_id;
end; $$;

do $$ declare t text; begin foreach t in array array['specialties','doctors','doctor_specialties','doctor_branches','doctor_financial_profiles','doctor_services','doctor_service_versions','doctor_availability_rules','doctor_unavailability','doctor_slots','doctor_sessions','session_assignments','session_status_history','session_notes','doctor_recommendations','session_feedback','doctor_commission_policies','doctor_commission_policy_versions','doctor_commission_entries','doctor_statements','doctor_statement_lines','doctor_payouts'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy specialties_scope on public.specialties for select to authenticated using(public.has_permission('doctors.view',organization_id));
create policy doctors_scope on public.doctors for select to authenticated using(public.has_permission('doctors.view',organization_id) or profile_id=auth.uid());
create policy doctors_manage_scope on public.doctors for all to authenticated using(public.has_permission('doctors.manage',organization_id)) with check(public.has_permission('doctors.manage',organization_id));
create policy doctor_specialties_scope on public.doctor_specialties for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id));
create policy doctor_branches_scope on public.doctor_branches for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id));
create policy doctor_financials_scope on public.doctor_financial_profiles for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and (d.profile_id=auth.uid() or public.has_permission('doctors.view_financials',d.organization_id))));
create policy doctor_services_scope on public.doctor_services for select to authenticated using(public.has_permission('doctors.view',organization_id));
create policy doctor_service_versions_scope on public.doctor_service_versions for select to authenticated using(exists(select 1 from public.doctor_services s where s.id=service_id));
create policy availability_scope on public.doctor_availability_rules for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id));
create policy unavailability_scope on public.doctor_unavailability for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id));
create policy slots_scope on public.doctor_slots for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id));
create policy sessions_scope on public.doctor_sessions for select to authenticated using(public.has_permission('sessions.view_team',organization_id) or exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid()));
create policy session_assignments_scope on public.session_assignments for select to authenticated using(exists(select 1 from public.doctor_sessions s where s.id=session_id));
create policy session_history_scope on public.session_status_history for select to authenticated using(exists(select 1 from public.doctor_sessions s where s.id=session_id));
create policy session_notes_scope on public.session_notes for select to authenticated using(exists(select 1 from public.doctors d where d.id=doctor_id and (d.profile_id=auth.uid() or public.has_permission('sessions.view_medical_notes',d.organization_id))));
create policy recommendations_scope on public.doctor_recommendations for select to authenticated using(public.is_organization_member(organization_id));
create policy feedback_scope on public.session_feedback for select to authenticated using(exists(select 1 from public.doctor_sessions s where s.id=session_id));
create policy doctor_policy_scope on public.doctor_commission_policies for select to authenticated using(public.has_permission('doctor_commissions.review',organization_id));
create policy doctor_policy_versions_scope on public.doctor_commission_policy_versions for select to authenticated using(exists(select 1 from public.doctor_commission_policies p where p.id=policy_id and public.has_permission('doctor_commissions.review',p.organization_id)));
create policy doctor_commissions_scope on public.doctor_commission_entries for select to authenticated using(public.has_permission('doctor_commissions.review',organization_id) or exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid()));
create policy doctor_statements_scope on public.doctor_statements for select to authenticated using(public.has_permission('doctor_commissions.review',organization_id) or exists(select 1 from public.doctors d where d.id=doctor_id and d.profile_id=auth.uid()));
create policy statement_lines_scope on public.doctor_statement_lines for select to authenticated using(exists(select 1 from public.doctor_statements s where s.id=statement_id));
create policy doctor_payouts_scope on public.doctor_payouts for select to authenticated using(exists(select 1 from public.doctor_statements s where s.id=statement_id));

insert into public.schema_versions(version,name) values(9,'doctors_sessions_accounting');
commit;

-- ============================================================================
-- 0010_integrations_setup_validation.sql
-- ============================================================================
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

-- ============================================================================
-- 0011_hosted_commercial_cycle.sql
-- ============================================================================
begin;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='refunds.request'
where r.code in('sales_manager','customer_service','finance_accountant')
on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='customers.view'
where r.code in('finance_manager','finance_accountant','operations_manager')
on conflict do nothing;

-- The operational sales cycle is server-governed. Every public RPC below derives
-- organization, branch and customer from the selected record instead of trusting
-- browser-supplied scope fields.

alter table public.planned_service_days drop constraint if exists planned_service_days_status_check;
alter table public.planned_service_days add constraint planned_service_days_status_check
  check(status in('planned','frozen','cancelled','not_delivered','exception','delivered_pending_confirmation','confirmed_delivered'));

alter table public.invoices add constraint invoices_scope_identity_unique
  unique(id,organization_id,branch_id,customer_id);
alter table public.payment_submissions alter column invoice_id set not null;
alter table public.payment_submissions add constraint payment_submission_invoice_scope_fk
  foreign key(invoice_id,organization_id,branch_id,customer_id)
  references public.invoices(id,organization_id,branch_id,customer_id);
create unique index invoices_one_per_quotation_uidx on public.invoices(quotation_id) where quotation_id is not null;
create unique index subscriptions_invoice_package_uidx on public.subscriptions(invoice_id,package_version_id);

alter table public.refunds add column invoice_id uuid references public.invoices(id);
alter table public.refunds add column transaction_id uuid references public.payment_transactions(id);

drop policy if exists invoices_scope on public.invoices;
drop policy if exists invoices_insert on public.invoices;
create policy invoices_scope on public.invoices for select to authenticated using(
  (public.has_permission('sales.invoice',organization_id) or public.has_permission('payments.review',organization_id)
   or public.has_permission('subscriptions.manage',organization_id) or public.has_permission('refunds.request',organization_id))
  and public.can_access_branch(organization_id,branch_id)
);
drop policy if exists invoice_lines_scope on public.invoice_lines;
drop policy if exists invoice_lines_manage on public.invoice_lines;
create policy invoice_lines_scope on public.invoice_lines for select to authenticated using(exists(
  select 1 from public.invoices i where i.id=invoice_id
));
drop policy if exists quotations_scope on public.quotations;
create policy quotations_select_scope on public.quotations for select to authenticated using(
  public.has_permission('sales.quote',organization_id) and public.can_access_branch(organization_id,branch_id)
);
drop policy if exists payment_submissions_insert on public.payment_submissions;
drop policy if exists subscriptions_manage on public.subscriptions;
drop policy if exists refunds_insert on public.refunds;

create table public.sales_target_actuals(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  target_id uuid not null references public.sales_targets(id) on delete cascade,
  payment_transaction_id uuid not null references public.payment_transactions(id),
  salesperson_user_id uuid not null references public.profiles(id),
  amount numeric(18,2) not null check(amount>0),
  occurred_on date not null,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(target_id,payment_transaction_id)
);

create table public.deferred_revenue_entries(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id),
  delivery_confirmation_id uuid references public.service_delivery_confirmations(id),
  refund_id uuid references public.refunds(id),
  entry_type text not null check(entry_type in('activation','recognition','refund','reversal','adjustment')),
  deferred_delta numeric(18,2) not null,
  recognized_delta numeric(18,2) not null default 0,
  balance_after numeric(18,2) not null check(balance_after>=0),
  created_by uuid not null references public.profiles(id),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,idempotency_key)
);

create index sales_target_actuals_scope_idx on public.sales_target_actuals(organization_id,branch_id,occurred_on);
create index deferred_revenue_entries_subscription_idx on public.deferred_revenue_entries(subscription_id,created_at);

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path='' set row_security=off as $$
declare old_json jsonb:=case when tg_op in('UPDATE','DELETE') then to_jsonb(old) else null end;
  new_json jsonb:=case when tg_op in('INSERT','UPDATE') then to_jsonb(new) else null end;
  source_json jsonb:=coalesce(new_json,old_json,'{}'::jsonb); v_org_id uuid; v_entity_id uuid; v_actor uuid;
  v_is_demo boolean:=coalesce((source_json->>'is_demo')::boolean,false); v_subscription_id uuid;
begin
  v_org_id:=case when tg_table_name='organizations' then nullif(source_json->>'id','')::uuid else nullif(source_json->>'organization_id','')::uuid end;
  if v_org_id is null and nullif(source_json->>'subscription_id','') is not null then
    v_subscription_id:=nullif(source_json->>'subscription_id','')::uuid;
    select s.organization_id into v_org_id from public.subscriptions s where s.id=v_subscription_id;
  end if;
  v_entity_id:=nullif(source_json->>'id','')::uuid;
  v_actor:=coalesce(auth.uid(),nullif(source_json->>'updated_by','')::uuid,nullif(source_json->>'created_by','')::uuid,
    nullif(source_json->>'submitted_by','')::uuid,nullif(source_json->>'reviewed_by','')::uuid,nullif(source_json->>'confirmed_by','')::uuid,
    nullif(source_json->>'allocated_by','')::uuid,nullif(source_json->>'activated_by','')::uuid,nullif(source_json->>'requested_by','')::uuid,
    nullif(source_json->>'approved_by','')::uuid,nullif(source_json->>'paid_by','')::uuid,nullif(source_json->>'assigned_by','')::uuid,
    nullif(source_json->>'granted_by','')::uuid,nullif(source_json->>'invited_by','')::uuid);
  insert into public.audit_logs(organization_id,actor_user_id,action,entity_type,entity_id,old_values,new_values,request_id,is_demo)
  values(v_org_id,v_actor,lower(tg_op),tg_table_name,v_entity_id,old_json,new_json,nullif(current_setting('request.headers',true),'')::jsonb->>'x-request-id',v_is_demo);
  if tg_op='DELETE' then return old; end if; return new;
end; $$;

create trigger audit_payment_allocations after insert or update or delete on public.payment_allocations for each row execute function public.audit_row_change();
create trigger audit_planned_service_days after insert or update or delete on public.planned_service_days for each row execute function public.audit_row_change();
create trigger audit_revenue_entries after insert or update or delete on public.revenue_entries for each row execute function public.audit_row_change();
create trigger audit_target_actuals after insert or update or delete on public.sales_target_actuals for each row execute function public.audit_row_change();
create trigger audit_deferred_revenue after insert or update or delete on public.deferred_revenue_entries for each row execute function public.audit_row_change();

create or replace function public.capture_sales_target_actual()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_salesperson uuid; v_invoice_id uuid;
begin
  if new.transaction_type<>'collection' or new.amount<=0 or new.submission_id is null then return new; end if;
  select i.id,q.created_by into v_invoice_id,v_salesperson
  from public.payment_submissions ps
  join public.invoices i on i.id=ps.invoice_id
  join public.quotations q on q.id=i.quotation_id
  where ps.id=new.submission_id;
  if v_salesperson is null then return new; end if;
  insert into public.sales_target_actuals(organization_id,branch_id,target_id,payment_transaction_id,salesperson_user_id,amount,occurred_on,is_demo)
  select new.organization_id,new.branch_id,t.id,new.id,v_salesperson,new.amount,new.confirmed_at::date,new.is_demo
  from public.sales_targets t
  where t.organization_id=new.organization_id
    and (t.branch_id is null or t.branch_id=new.branch_id)
    and new.confirmed_at::date between t.period_start and t.period_end
    and ((t.target_type='user' and t.user_id=v_salesperson) or
      (t.target_type='team' and exists(select 1 from public.team_members tm where tm.team_id=t.team_id and tm.user_id=v_salesperson and tm.joined_at<=new.confirmed_at::date and (tm.left_at is null or tm.left_at>=new.confirmed_at::date))))
  on conflict(target_id,payment_transaction_id) do nothing;
  return new;
end; $$;
create trigger payment_transaction_target_actual after insert on public.payment_transactions
for each row execute function public.capture_sales_target_actual();

create or replace function public.create_customer_quotation(
  p_branch_id uuid,p_customer_name text,p_mobile text,p_package_version_id uuid,
  p_quantity numeric,p_discount_percent numeric,p_valid_until date,p_notes text,p_actor_user_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_package public.packages; v_version public.package_versions; v_customer_id uuid; v_quote_id uuid;
  v_subtotal numeric(18,2); v_discount numeric(18,2); v_limit numeric(5,2);
begin
  select b.organization_id into v_org from public.branches b where b.id=p_branch_id and b.status='active';
  if v_org is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_org) or not public.can_access_branch(v_org,p_branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  if nullif(trim(p_customer_name),'') is null or p_quantity<=0 or p_discount_percent not between 0 and 100 then raise exception 'invalid quotation input'; end if;
  select pv.* into v_version from public.package_versions pv join public.packages p on p.id=pv.package_id
  where pv.id=p_package_version_id and p.organization_id=v_org and p.status='active' and pv.status='active'
    and pv.effective_from<=current_date and (pv.effective_to is null or pv.effective_to>=current_date);
  if v_version.id is null then raise exception 'package version is not available for this organization'; end if;
  select p.* into v_package from public.packages p where p.id=v_version.package_id;
  select coalesce(max(dl.maximum_percent),case when public.has_permission('catalog.manage',v_org) then 100 else 0 end) into v_limit
  from public.discount_limits dl
  where dl.organization_id=v_org and dl.effective_from<=current_date and (dl.effective_to is null or dl.effective_to>=current_date)
    and (dl.user_id=p_actor_user_id or dl.role_id in(select ur.role_id from public.user_roles ur where ur.organization_id=v_org and ur.user_id=p_actor_user_id and ur.valid_from<=now() and (ur.valid_until is null or ur.valid_until>now())));
  if p_discount_percent>coalesce(v_limit,0) then raise exception 'discount exceeds authorized limit'; end if;
  v_subtotal:=round(p_quantity*v_version.price,2); v_discount:=round(v_subtotal*p_discount_percent/100,2);
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,status,owner_user_id,created_by)
  values(v_org,p_branch_id,trim(p_customer_name),nullif(trim(p_mobile),''),'active',p_actor_user_id,p_actor_user_id) returning id into v_customer_id;
  insert into public.quotations(organization_id,branch_id,customer_id,status,currency,subtotal,discount_amount,valid_until,notes,created_by)
  values(v_org,p_branch_id,v_customer_id,'issued',v_version.currency,v_subtotal,v_discount,p_valid_until,p_notes,p_actor_user_id) returning id into v_quote_id;
  insert into public.quotation_lines(quotation_id,package_version_id,description,quantity,unit_price,discount_percent,price_snapshot)
  values(v_quote_id,v_version.id,v_package.name,p_quantity,v_version.price,p_discount_percent,jsonb_build_object('package_id',v_package.id,'package_version_id',v_version.id,'version_number',v_version.version_number,'unit_price',v_version.price,'currency',v_version.currency));
  perform public.enqueue_domain_event(v_org,p_branch_id,'quotation.created','quotation',v_quote_id,jsonb_build_object('customer_id',v_customer_id,'package_version_id',v_version.id,'total',v_subtotal-v_discount),p_actor_user_id,'quotation.created:'||v_quote_id::text,false);
  return jsonb_build_object('customer_id',v_customer_id,'quotation_id',v_quote_id);
end; $$;

create or replace function public.accept_quotation(p_quotation_id uuid,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_quote public.quotations;
begin
  select * into v_quote from public.quotations where id=p_quotation_id for update;
  if v_quote.id is null or v_quote.status<>'issued' then raise exception 'issued quotation is required'; end if;
  if v_quote.valid_until is not null and v_quote.valid_until<current_date then raise exception 'quotation is expired'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_quote.organization_id) or not public.can_access_branch(v_quote.organization_id,v_quote.branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  update public.quotations set status='accepted',accepted_at=now(),updated_at=now() where id=v_quote.id;
  perform public.enqueue_domain_event(v_quote.organization_id,v_quote.branch_id,'quotation.accepted','quotation',v_quote.id,'{}'::jsonb,p_actor_user_id,'quotation.accepted:'||v_quote.id::text,v_quote.is_demo);
end; $$;

create or replace function public.convert_quotation_to_invoice(p_quotation_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_quote public.quotations; v_invoice_id uuid;
begin
  select * into v_quote from public.quotations where id=p_quotation_id for update;
  if v_quote.id is null or v_quote.status<>'accepted' then raise exception 'accepted quotation is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.invoice',v_quote.organization_id) or not public.can_access_branch(v_quote.organization_id,v_quote.branch_id)) then raise exception 'sales.invoice and branch access are required'; end if;
  insert into public.invoices(organization_id,branch_id,customer_id,quotation_id,status,currency,total_amount,due_at,created_by,is_demo)
  values(v_quote.organization_id,v_quote.branch_id,v_quote.customer_id,v_quote.id,'issued',v_quote.currency,v_quote.total_amount,now()+interval '7 days',p_actor_user_id,v_quote.is_demo)
  returning id into v_invoice_id;
  insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,source_snapshot,is_demo)
  select v_invoice_id,ql.package_version_id,ql.description,ql.quantity,ql.unit_price,ql.line_total,
    ql.price_snapshot||jsonb_build_object('quotation_line_id',ql.id,'quotation_id',v_quote.id),ql.is_demo
  from public.quotation_lines ql where ql.quotation_id=v_quote.id;
  update public.quotations set status='converted',updated_at=now() where id=v_quote.id;
  perform public.enqueue_domain_event(v_quote.organization_id,v_quote.branch_id,'invoice.created','invoice',v_invoice_id,jsonb_build_object('quotation_id',v_quote.id,'customer_id',v_quote.customer_id,'total',v_quote.total_amount),p_actor_user_id,'invoice.created:'||v_invoice_id::text,v_quote.is_demo);
  return v_invoice_id;
end; $$;

create or replace function public.submit_payment_proof(
  p_invoice_id uuid,p_claimed_amount numeric,p_payment_method text,p_proof_reference text,p_external_reference text,p_actor_user_id uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_submission_id uuid; v_remaining numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null or v_invoice.status not in('issued','partially_paid') then raise exception 'payable invoice is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.submit',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'payments.submit and branch access are required'; end if;
  v_remaining:=v_invoice.total_amount-v_invoice.confirmed_paid_amount;
  if p_claimed_amount<=0 or p_claimed_amount>v_remaining then raise exception 'claimed amount exceeds invoice remaining balance'; end if;
  if nullif(trim(p_proof_reference),'') is null then raise exception 'payment proof is required'; end if;
  insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,currency,payment_method,proof_reference,external_reference,status,submitted_by,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,p_claimed_amount,v_invoice.currency,p_payment_method,p_proof_reference,nullif(trim(p_external_reference),''),'pending',p_actor_user_id,v_invoice.is_demo)
  returning id into v_submission_id;
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'payment_proof.submitted','payment_submission',v_submission_id,jsonb_build_object('invoice_id',v_invoice.id,'amount',p_claimed_amount),p_actor_user_id,'payment_proof.submitted:'||v_submission_id::text,v_invoice.is_demo);
  return v_submission_id;
end; $$;

create or replace function public.confirm_payment_submission(p_submission_id uuid,p_confirmed_amount numeric,p_actor_user_id uuid,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_submission public.payment_submissions; v_transaction_id uuid; v_invoice public.invoices; v_remaining numeric(18,2);
begin
  select * into v_submission from public.payment_submissions where id=p_submission_id for update;
  if v_submission.id is null or v_submission.status not in('pending','under_review') then raise exception 'payment submission is not confirmable'; end if;
  if v_submission.invoice_id is null then raise exception 'payment submission must reference an invoice'; end if;
  if p_actor_user_id=v_submission.submitted_by then raise exception 'maker cannot confirm own payment'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.confirm',v_submission.organization_id) or not public.can_access_branch(v_submission.organization_id,v_submission.branch_id)) then raise exception 'payments.confirm and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_submission.invoice_id for update;
  if v_invoice.id is null or v_invoice.organization_id<>v_submission.organization_id or v_invoice.branch_id<>v_submission.branch_id or v_invoice.customer_id<>v_submission.customer_id then raise exception 'invoice scope mismatch'; end if;
  v_remaining:=v_invoice.total_amount-v_invoice.confirmed_paid_amount;
  if p_confirmed_amount<=0 or p_confirmed_amount>v_submission.claimed_amount or p_confirmed_amount>v_remaining then raise exception 'invalid confirmed amount'; end if;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,submission_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_submission.organization_id,v_submission.branch_id,v_submission.customer_id,v_submission.id,'collection',p_confirmed_amount,v_submission.currency,p_actor_user_id,p_idempotency_key,v_submission.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.payment_submissions set status=case when p_confirmed_amount=claimed_amount then 'confirmed' else 'partially_confirmed' end,
    confirmed_amount=p_confirmed_amount,reviewed_by=p_actor_user_id,reviewed_at=now(),rejection_reason=null where id=v_submission.id;
  update public.invoices set confirmed_paid_amount=confirmed_paid_amount+p_confirmed_amount,
    status=case when confirmed_paid_amount+p_confirmed_amount>=total_amount then 'paid' else 'partially_paid' end,updated_at=now() where id=v_invoice.id;
  insert into public.payment_allocations(organization_id,transaction_id,invoice_id,allocation_type,amount,allocated_by,is_demo)
  values(v_submission.organization_id,v_transaction_id,v_invoice.id,'invoice',p_confirmed_amount,p_actor_user_id,v_submission.is_demo);
  perform public.enqueue_domain_event(v_submission.organization_id,v_submission.branch_id,'payment.confirmed','payment_transaction',v_transaction_id,jsonb_build_object('submission_id',v_submission.id,'invoice_id',v_invoice.id,'amount',p_confirmed_amount),p_actor_user_id,'payment.confirmed:'||v_transaction_id::text,v_submission.is_demo);
  return v_transaction_id;
end; $$;

create or replace function public.reject_payment_submission(p_submission_id uuid,p_reason text,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_submission public.payment_submissions;
begin
  select * into v_submission from public.payment_submissions where id=p_submission_id for update;
  if v_submission.id is null or v_submission.status not in('pending','under_review') then raise exception 'payment submission is not reviewable'; end if;
  if p_actor_user_id=v_submission.submitted_by then raise exception 'maker cannot reject own payment'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'rejection reason is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.review',v_submission.organization_id) or not public.can_access_branch(v_submission.organization_id,v_submission.branch_id)) then raise exception 'payments.review and branch access are required'; end if;
  update public.payment_submissions set status='rejected',rejection_reason=trim(p_reason),reviewed_by=p_actor_user_id,reviewed_at=now() where id=v_submission.id;
  perform public.enqueue_domain_event(v_submission.organization_id,v_submission.branch_id,'payment.rejected','payment_submission',v_submission.id,jsonb_build_object('invoice_id',v_submission.invoice_id,'reason',trim(p_reason)),p_actor_user_id,'payment.rejected:'||v_submission.id::text,v_submission.is_demo);
end; $$;

create or replace function public.create_activate_subscription_from_invoice(p_invoice_id uuid,p_package_version_id uuid,p_starts_on date,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_version public.package_versions; v_subscription_id uuid; v_contract numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null or v_invoice.status<>'paid' or v_invoice.confirmed_paid_amount<>v_invoice.total_amount then raise exception 'fully paid invoice is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('subscriptions.manage',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'subscriptions.manage and branch access are required'; end if;
  select pv.* into v_version from public.package_versions pv where pv.id=p_package_version_id
    and exists(select 1 from public.invoice_lines il where il.invoice_id=v_invoice.id and il.package_version_id=pv.id);
  if v_version.id is null then raise exception 'package version must belong to the selected invoice'; end if;
  select sum(il.line_total) into v_contract from public.invoice_lines il where il.invoice_id=v_invoice.id and il.package_version_id=v_version.id;
  insert into public.subscriptions(organization_id,branch_id,customer_id,invoice_id,package_version_id,status,starts_on,ends_on,purchased_service_days,contract_value,deferred_balance,recognized_revenue,activated_by,activated_at,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,v_version.id,'active',p_starts_on,p_starts_on+v_version.service_days-1,v_version.service_days,v_contract,v_contract,0,p_actor_user_id,now(),v_invoice.is_demo)
  returning id into v_subscription_id;
  insert into public.planned_service_days(subscription_id,service_date,status,branch_id,is_demo)
  select v_subscription_id,p_starts_on+g,'planned',v_invoice.branch_id,v_invoice.is_demo from generate_series(0,v_version.service_days-1) g;
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_subscription_id,v_invoice.id,'activation',v_contract,0,v_contract,p_actor_user_id,'subscription.activation:'||v_subscription_id::text,v_invoice.is_demo);
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'subscription.activated','subscription',v_subscription_id,jsonb_build_object('invoice_id',v_invoice.id,'deferred_revenue',v_contract),p_actor_user_id,'subscription.activated:'||v_subscription_id::text,v_invoice.is_demo);
  return v_subscription_id;
end; $$;

create or replace function public.confirm_service_delivery(p_planned_day_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_day public.planned_service_days; v_subscription public.subscriptions; v_confirmation_id uuid; v_amount numeric(18,2); v_balance numeric(18,2);
begin
  select * into v_day from public.planned_service_days where id=p_planned_day_id for update;
  if v_day.id is null then raise exception 'planned service day is required'; end if;
  select * into v_subscription from public.subscriptions where id=v_day.subscription_id for update;
  if v_day.status not in('planned','delivered_pending_confirmation') or v_subscription.status<>'active' then raise exception 'service day is not deliverable'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('service.confirm_delivery',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'service.confirm_delivery and branch access are required'; end if;
  v_amount:=least(v_subscription.deferred_balance,round(v_subscription.contract_value/v_subscription.purchased_service_days,2));
  if v_amount<=0 then raise exception 'no deferred revenue remains'; end if;
  insert into public.service_delivery_confirmations(planned_service_day_id,subscription_id,status,confirmed_by,is_demo)
  values(v_day.id,v_subscription.id,'confirmed_delivered',p_actor_user_id,v_day.is_demo) returning id into v_confirmation_id;
  insert into public.revenue_entries(organization_id,subscription_id,delivery_confirmation_id,entry_type,amount,entry_date,created_by,idempotency_key,is_demo)
  values(v_subscription.organization_id,v_subscription.id,v_confirmation_id,'recognition',v_amount,v_day.service_date,p_actor_user_id,'delivery:'||v_day.id::text,v_day.is_demo);
  v_balance:=greatest(0,v_subscription.deferred_balance-v_amount);
  update public.planned_service_days set status='confirmed_delivered' where id=v_day.id;
  update public.subscriptions set delivered_service_days=delivered_service_days+1,recognized_revenue=recognized_revenue+v_amount,deferred_balance=v_balance,updated_at=now() where id=v_subscription.id;
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,delivery_confirmation_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_subscription.invoice_id,v_confirmation_id,'recognition',-v_amount,v_amount,v_balance,p_actor_user_id,'delivery.recognition:'||v_day.id::text,v_day.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'service_day.confirmed_delivered','planned_service_day',v_day.id,jsonb_build_object('subscription_id',v_subscription.id,'recognized_revenue',v_amount,'deferred_balance',v_balance),p_actor_user_id,'service_day.confirmed:'||v_day.id::text,v_day.is_demo);
  return v_confirmation_id;
end; $$;

create or replace function public.request_refund(p_invoice_id uuid,p_subscription_id uuid,p_amount numeric,p_reason text,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_refund_id uuid; v_refunded numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice is required'; end if;
  if p_subscription_id is not null and not exists(select 1 from public.subscriptions s where s.id=p_subscription_id and s.invoice_id=v_invoice.id) then raise exception 'subscription does not belong to invoice'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  select coalesce(sum(r.amount),0) into v_refunded from public.refunds r where r.invoice_id=v_invoice.id and r.status in('approved','paid');
  if p_amount<=0 or p_amount>v_invoice.confirmed_paid_amount-v_refunded then raise exception 'refund exceeds refundable confirmed cash'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'refund reason is required'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,status,requested_by,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,p_subscription_id,p_amount,trim(p_reason),'requested',p_actor_user_id,v_invoice.is_demo) returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,p_amount,v_invoice.is_demo);
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'amount',p_amount),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_invoice.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.approve_refund(p_refund_id uuid,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds;
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status not in('requested','under_review') then raise exception 'refund is not approvable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot approve own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  update public.refunds set status='approved',approved_by=p_actor_user_id,approved_at=now() where id=v_refund.id;
  update public.approval_requests set status='approved',decided_by=p_actor_user_id,decided_at=now() where entity_type='refund' and entity_id=v_refund.id and status='pending';
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.approved','refund',v_refund.id,jsonb_build_object('invoice_id',v_refund.invoice_id,'amount',v_refund.amount),p_actor_user_id,'refund.approved:'||v_refund.id::text,v_refund.is_demo);
end; $$;

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_subscription public.subscriptions; v_transaction_id uuid; v_new_deferred numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' or v_refund.invoice_id is null then raise exception 'approved invoice refund is required'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot pay own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,v_invoice.currency,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.invoices set confirmed_paid_amount=greatest(0,confirmed_paid_amount-v_refund.amount),
    status=case when confirmed_paid_amount-v_refund.amount<=0 then 'issued' when confirmed_paid_amount-v_refund.amount<total_amount then 'partially_paid' else status end,updated_at=now() where id=v_invoice.id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=p_proof_reference,transaction_id=v_transaction_id where id=v_refund.id;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,
    -least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(v_invoice.confirmed_paid_amount,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce
  join public.payment_transactions pt on pt.id=ce.source_transaction_id
  join public.payment_submissions ps on ps.id=pt.submission_id
  where ps.invoice_id=v_invoice.id and ce.entry_type='commission' and ce.status<>'reversed'
  on conflict do nothing;
  if v_refund.subscription_id is not null then
    select * into v_subscription from public.subscriptions where id=v_refund.subscription_id for update;
    v_new_deferred:=greatest(0,v_subscription.deferred_balance-least(v_refund.amount,v_subscription.deferred_balance));
    update public.subscriptions set deferred_balance=v_new_deferred,updated_at=now() where id=v_subscription.id;
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,refund_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,v_invoice.id,v_refund.id,'refund',-(v_subscription.deferred_balance-v_new_deferred),0,v_new_deferred,p_actor_user_id,'refund.deferred:'||v_refund.id::text,v_refund.is_demo);
  end if;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('invoice_id',v_invoice.id,'transaction_id',v_transaction_id,'amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

create view public.confirmed_cash_v with(security_invoker=true) as
select pt.organization_id,pt.branch_id,pt.customer_id,sum(pt.amount) as net_confirmed_cash,min(pt.confirmed_at) as first_transaction_at,max(pt.confirmed_at) as last_transaction_at
from public.payment_transactions pt where pt.transaction_type in('collection','refund','reversal') group by pt.organization_id,pt.branch_id,pt.customer_id;

create or replace function public.invoice_timeline(p_invoice_id uuid)
returns table(event_type text,aggregate_type text,aggregate_id uuid,payload jsonb,occurred_at timestamptz,actor_user_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices where id=p_invoice_id;
  if v_invoice.id is null then return; end if;
  if auth.uid() is not null and not ((public.has_permission('sales.invoice',v_invoice.organization_id) or public.has_permission('payments.review',v_invoice.organization_id) or public.has_permission('subscriptions.view',v_invoice.organization_id)) and public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'invoice access is required'; end if;
  return query
  select de.event_type,de.aggregate_type,de.aggregate_id,de.payload,de.occurred_at,de.actor_user_id
  from public.domain_events de
  where de.organization_id=v_invoice.organization_id and (
    (de.aggregate_type='invoice' and de.aggregate_id=v_invoice.id) or
    (de.aggregate_type='quotation' and de.aggregate_id=v_invoice.quotation_id) or
    de.payload->>'invoice_id'=v_invoice.id::text or
    (de.aggregate_type='payment_submission' and exists(select 1 from public.payment_submissions ps where ps.id=de.aggregate_id and ps.invoice_id=v_invoice.id)) or
    (de.aggregate_type='payment_transaction' and exists(select 1 from public.payment_transactions pt join public.payment_submissions ps on ps.id=pt.submission_id where pt.id=de.aggregate_id and ps.invoice_id=v_invoice.id)) or
    (de.aggregate_type='subscription' and exists(select 1 from public.subscriptions s where s.id=de.aggregate_id and s.invoice_id=v_invoice.id)) or
    (de.aggregate_type='refund' and exists(select 1 from public.refunds r where r.id=de.aggregate_id and r.invoice_id=v_invoice.id))
  ) order by de.occurred_at;
end; $$;

alter table public.sales_target_actuals enable row level security;
alter table public.deferred_revenue_entries enable row level security;
create policy sales_target_actuals_scope on public.sales_target_actuals for select to authenticated
using(public.has_permission('targets.view_team',organization_id) or salesperson_user_id=auth.uid());
create policy deferred_revenue_scope on public.deferred_revenue_entries for select to authenticated
using(public.has_permission('revenue.view',organization_id) and public.can_access_branch(organization_id,branch_id));

revoke all on function public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid) from public;
revoke all on function public.accept_quotation(uuid,uuid) from public;
revoke all on function public.convert_quotation_to_invoice(uuid,uuid) from public;
revoke all on function public.submit_payment_proof(uuid,numeric,text,text,text,uuid) from public;
revoke all on function public.confirm_payment_submission(uuid,numeric,uuid,text) from public;
revoke all on function public.reject_payment_submission(uuid,text,uuid) from public;
revoke all on function public.create_activate_subscription_from_invoice(uuid,uuid,date,uuid) from public;
revoke all on function public.confirm_service_delivery(uuid,uuid) from public;
revoke all on function public.request_refund(uuid,uuid,numeric,text,uuid) from public;
revoke all on function public.approve_refund(uuid,uuid) from public;
revoke all on function public.pay_refund_and_clawback(uuid,uuid,text,text) from public;
revoke all on function public.invoice_timeline(uuid) from public;
grant execute on function public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid) to authenticated;
grant execute on function public.accept_quotation(uuid,uuid) to authenticated;
grant execute on function public.convert_quotation_to_invoice(uuid,uuid) to authenticated;
grant execute on function public.submit_payment_proof(uuid,numeric,text,text,text,uuid) to authenticated;
grant execute on function public.confirm_payment_submission(uuid,numeric,uuid,text) to authenticated;
grant execute on function public.reject_payment_submission(uuid,text,uuid) to authenticated;
grant execute on function public.create_activate_subscription_from_invoice(uuid,uuid,date,uuid) to authenticated;
grant execute on function public.confirm_service_delivery(uuid,uuid) to authenticated;
grant execute on function public.request_refund(uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.approve_refund(uuid,uuid) to authenticated;
grant execute on function public.pay_refund_and_clawback(uuid,uuid,text,text) to authenticated;
grant execute on function public.invoice_timeline(uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text)
language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=11,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.tasks'::regclass,'public.customers'::regclass,'public.payment_submissions'::regclass,'public.doctor_sessions'::regclass,'public.deferred_revenue_entries'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=70,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs';
$$;

insert into public.schema_versions(version,name) values(11,'hosted_commercial_cycle');
commit;

-- ============================================================================
-- 0012_subscription_operations_acceptance.sql
-- ============================================================================
begin;

-- Subscription operations acceptance layer. This migration contains structure,
-- security and transactional functions only; demo records live in a separate seed.

insert into public.permissions(code,name,module,description,is_sensitive) values
('subscriptions.operate_daily','Operate daily subscriptions','Subscriptions','Freeze, skip and adjust daily portions in branch scope',true),
('refunds.pay','Pay approved refunds','Finance','Record refund cash transfer and proof',true)
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('subscriptions.operate_daily')
where r.code in('operations_manager','customer_service') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('refunds.pay')
where r.code in('finance_manager','finance_accountant') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='ceo_super_admin' on conflict do nothing;

create table public.delivery_zones(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  code text not null,
  name text not null,
  delivery_fee numeric(18,2) not null default 0 check(delivery_fee>=0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,code)
);

create table public.meal_menu_days(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cycle_name text not null default 'Standard 31-day menu',
  day_number integer not null check(day_number between 1 and 31),
  breakfast text not null,
  lunch text not null,
  dinner text not null,
  snack_1 text not null,
  snack_2 text not null,
  delivery_note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,cycle_name,day_number)
);

create table public.subscription_operation_events(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  planned_service_day_id uuid references public.planned_service_days(id) on delete set null,
  event_type text not null check(event_type in('freeze','reactivate','skip_day','extra_portions','meal_override','refund_requested','refund_paid')),
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid not null references public.profiles(id),
  occurred_at timestamptz not null default now(),
  is_demo boolean not null default false
);

alter table public.packages add column program_code text;
alter table public.packages add column meal_plan_code text;
alter table public.customer_addresses add column zone_id uuid references public.delivery_zones(id);
alter table public.customer_addresses add column gps_url text;
alter table public.customer_addresses add column delivery_contact_name text;
alter table public.customer_addresses add column delivery_contact_mobile text;
alter table public.customer_addresses add column delivery_window_start time;
alter table public.customer_addresses add column delivery_window_end time;
alter table public.customer_addresses add column delivery_time_confirmed boolean not null default false;
alter table public.subscriptions add column daily_portions integer not null default 1 check(daily_portions between 1 and 20);
alter table public.subscriptions add column operations_notes text;
alter table public.subscriptions add column meal_override jsonb not null default '{}'::jsonb;
alter table public.planned_service_days add column portion_multiplier integer not null default 1 check(portion_multiplier between 1 and 20);
alter table public.planned_service_days add column operations_note text;
alter table public.planned_service_days add column meal_override jsonb not null default '{}'::jsonb;
alter table public.refunds add column reason_code text;
alter table public.refunds add column calculation_basis jsonb not null default '{}'::jsonb;
alter table public.refunds add column recipient_method text;
alter table public.refunds add column recipient_account_name text;
alter table public.refunds add column recipient_account_reference text;

drop index if exists public.customers_org_mobile_uidx;
create unique index customers_org_mobile_uidx on public.customers(organization_id,mobile) where mobile is not null;
create index delivery_zones_scope_idx on public.delivery_zones(organization_id,branch_id,is_active,sort_order);
create index meal_menu_days_scope_idx on public.meal_menu_days(organization_id,cycle_name,day_number);
create index subscription_operation_events_idx on public.subscription_operation_events(subscription_id,occurred_at desc);

alter table public.delivery_zones enable row level security;
alter table public.meal_menu_days enable row level security;
alter table public.subscription_operation_events enable row level security;

create policy delivery_zones_select on public.delivery_zones for select to authenticated
using(public.has_permission('customers.view',organization_id) or public.has_permission('subscriptions.view',organization_id));
create policy meal_menu_days_select on public.meal_menu_days for select to authenticated
using(public.has_permission('subscriptions.view',organization_id));
create policy operation_events_select on public.subscription_operation_events for select to authenticated
using(public.has_permission('subscriptions.view',organization_id) and public.can_access_branch(organization_id,branch_id));

create trigger audit_delivery_zones after insert or update or delete on public.delivery_zones for each row execute function public.audit_row_change();
create trigger audit_meal_menu_days after insert or update or delete on public.meal_menu_days for each row execute function public.audit_row_change();
create trigger audit_subscription_operation_events after insert or update or delete on public.subscription_operation_events for each row execute function public.audit_row_change();

create or replace function public.create_customer_delivery_profile(
  p_branch_id uuid,p_full_name text,p_mobile text,p_email text,p_address_line text,p_area text,p_city text,
  p_latitude numeric,p_longitude numeric,p_gps_url text,p_zone_id uuid,p_delivery_notes text,
  p_delivery_window_start time,p_delivery_window_end time,p_delivery_contact_name text,p_delivery_contact_mobile text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_branch public.branches; v_customer_id uuid; v_zone public.delivery_zones;
begin
  select * into v_branch from public.branches where id=p_branch_id and status='active';
  if v_branch.id is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('customers.manage',v_branch.organization_id) or not public.can_access_branch(v_branch.organization_id,v_branch.id)) then raise exception 'customers.manage and branch access are required'; end if;
  if nullif(trim(p_full_name),'') is null or nullif(trim(p_mobile),'') is null then raise exception 'customer name and unique mobile are required'; end if;
  if nullif(trim(p_address_line),'') is null then raise exception 'detailed Arabic address is required'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'valid GPS coordinates are required'; end if;
  if p_delivery_window_start is null or p_delivery_window_end is null or p_delivery_window_end<=p_delivery_window_start then raise exception 'confirmed delivery window is required'; end if;
  select * into v_zone from public.delivery_zones where id=p_zone_id and organization_id=v_branch.organization_id and is_active;
  if v_zone.id is null then raise exception 'delivery zone must belong to the organization'; end if;
  if exists(select 1 from public.customers c where c.organization_id=v_branch.organization_id and c.mobile=trim(p_mobile)) then raise exception 'mobile already belongs to another customer'; end if;
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,owner_user_id,created_by)
  values(v_branch.organization_id,v_branch.id,trim(p_full_name),trim(p_mobile),nullif(trim(p_email),''),'active',p_actor_user_id,p_actor_user_id)
  returning id into v_customer_id;
  insert into public.customer_addresses(customer_id,label,address_line,area,city,latitude,longitude,delivery_notes,is_primary,zone_id,gps_url,delivery_contact_name,delivery_contact_mobile,delivery_window_start,delivery_window_end,delivery_time_confirmed)
  values(v_customer_id,'العنوان الرئيسي',trim(p_address_line),nullif(trim(p_area),''),nullif(trim(p_city),''),p_latitude,p_longitude,nullif(trim(p_delivery_notes),''),true,v_zone.id,nullif(trim(p_gps_url),''),coalesce(nullif(trim(p_delivery_contact_name),''),trim(p_full_name)),coalesce(nullif(trim(p_delivery_contact_mobile),''),trim(p_mobile)),p_delivery_window_start,p_delivery_window_end,true);
  insert into public.customer_timeline(organization_id,customer_id,event_type,title,details,actor_user_id)
  values(v_branch.organization_id,v_customer_id,'customer.created','إنشاء ملف عميل بعنوان توصيل مؤكد',jsonb_build_object('branch_id',v_branch.id,'zone_id',v_zone.id,'mobile',trim(p_mobile)),p_actor_user_id);
  return v_customer_id;
exception when unique_violation then
  raise exception 'mobile already belongs to another customer';
end; $$;

create or replace function public.freeze_subscription_period(p_subscription_id uuid,p_starts_on date,p_ends_on date,p_reason text,p_actor_user_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_count integer; v_last_date date; v_is_current boolean;
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active subscription is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('subscriptions.operate_daily',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'subscriptions.operate_daily and branch access are required'; end if;
  if p_starts_on is null or p_ends_on is null or p_ends_on<p_starts_on or nullif(trim(p_reason),'') is null then raise exception 'valid freeze period and reason are required'; end if;
  select count(*) into v_count from public.planned_service_days where subscription_id=v_subscription.id and service_date between p_starts_on and p_ends_on and status='planned';
  if v_count=0 then raise exception 'no planned service days in freeze period'; end if;
  select max(service_date) into v_last_date from public.planned_service_days where subscription_id=v_subscription.id;
  update public.planned_service_days set status='frozen',operations_note=concat_ws(' · ',operations_note,'Freeze: '||trim(p_reason)) where subscription_id=v_subscription.id and service_date between p_starts_on and p_ends_on and status='planned';
  insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,is_demo)
  select v_subscription.id,v_last_date+g,'planned',v_subscription.branch_id,v_subscription.daily_portions,'Replacement after freeze',v_subscription.is_demo from generate_series(1,v_count) g;
  v_is_current:=current_date between p_starts_on and p_ends_on;
  insert into public.subscription_freezes(subscription_id,starts_on,ends_on,reason,status,approved_by,is_demo)
  values(v_subscription.id,p_starts_on,p_ends_on,trim(p_reason),'approved',p_actor_user_id,v_subscription.is_demo);
  update public.subscriptions set status=case when v_is_current then 'frozen' else status end,ends_on=v_last_date+v_count,updated_at=now() where id=v_subscription.id;
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'freeze',jsonb_build_object('starts_on',p_starts_on,'ends_on',p_ends_on,'reason',trim(p_reason),'replacement_days',v_count),p_actor_user_id,v_subscription.is_demo);
  return v_count;
end; $$;

create or replace function public.apply_service_day_action(p_day_ids uuid[],p_action text,p_portions integer,p_reason text,p_actor_user_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_day public.planned_service_days; v_subscription public.subscriptions; v_count integer:=0; v_replacement date;
begin
  if coalesce(array_length(p_day_ids,1),0)=0 then raise exception 'select at least one service day'; end if;
  if p_action not in('skip','set_portions','confirm_delivered') then raise exception 'unsupported daily action'; end if;
  if p_action='set_portions' and (p_portions is null or p_portions not between 1 and 20) then raise exception 'portions must be between 1 and 20'; end if;
  if p_action='skip' and nullif(trim(p_reason),'') is null then raise exception 'skip reason is required'; end if;
  for v_day in select * from public.planned_service_days where id=any(p_day_ids) order by service_date,id for update loop
    select * into v_subscription from public.subscriptions where id=v_day.subscription_id for update;
    if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission(case when p_action='confirm_delivered' then 'service.confirm_delivery' else 'subscriptions.operate_daily' end,v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'daily operation permission and branch access are required'; end if;
    if p_action='confirm_delivered' then
      perform public.confirm_service_delivery(v_day.id,p_actor_user_id);
    elsif p_action='set_portions' then
      update public.planned_service_days set portion_multiplier=p_portions,operations_note=concat_ws(' · ',operations_note,nullif(trim(p_reason),'')) where id=v_day.id;
      insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,planned_service_day_id,event_type,details,actor_user_id,is_demo)
      values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_day.id,'extra_portions',jsonb_build_object('portions',p_portions,'note',nullif(trim(p_reason),'')),p_actor_user_id,v_day.is_demo);
    else
      if v_day.status<>'planned' then raise exception 'only planned days can be skipped'; end if;
      select coalesce(max(service_date),v_day.service_date)+1 into v_replacement from public.planned_service_days where subscription_id=v_subscription.id;
      update public.planned_service_days set status='not_delivered',operations_note=concat_ws(' · ',operations_note,'Skip: '||trim(p_reason)) where id=v_day.id;
      insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,is_demo)
      values(v_subscription.id,v_replacement,'planned',v_subscription.branch_id,v_day.portion_multiplier,'Replacement after skipped day',v_day.is_demo);
      update public.subscriptions set ends_on=greatest(coalesce(ends_on,v_replacement),v_replacement),updated_at=now() where id=v_subscription.id;
      insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,planned_service_day_id,event_type,details,actor_user_id,is_demo)
      values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_day.id,'skip_day',jsonb_build_object('reason',trim(p_reason),'replacement_date',v_replacement),p_actor_user_id,v_day.is_demo);
    end if;
    v_count:=v_count+1;
  end loop;
  if v_count<>array_length(p_day_ids,1) then raise exception 'one or more service days are outside your scope'; end if;
  return v_count;
end; $$;

create or replace function public.request_calculated_subscription_refund(
  p_subscription_id uuid,p_reason_code text,p_reason_details text,p_recipient_method text,p_recipient_account_name text,p_recipient_account_reference text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_invoice public.invoices; v_refund_id uuid; v_remaining_days integer; v_daily_value numeric(18,2); v_amount numeric(18,2); v_refunded numeric(18,2);
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active or frozen subscription is required'; end if;
  select * into v_invoice from public.invoices where id=v_subscription.invoice_id for update;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  if nullif(trim(p_reason_code),'') is null then raise exception 'refund reason is required'; end if;
  if p_recipient_method not in('instapay','mobile_wallet','bank_transfer','cash') or nullif(trim(p_recipient_account_name),'') is null or nullif(trim(p_recipient_account_reference),'') is null then raise exception 'complete refund recipient details are required'; end if;
  select count(*) into v_remaining_days from public.planned_service_days where subscription_id=v_subscription.id and status in('planned','frozen','not_delivered','exception');
  v_remaining_days:=least(v_remaining_days,greatest(0,v_subscription.purchased_service_days-v_subscription.delivered_service_days));
  v_daily_value:=round(v_subscription.contract_value/nullif(v_subscription.purchased_service_days,0),2);
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and status in('approved','paid');
  v_amount:=least(round(v_daily_value*v_remaining_days,2),v_subscription.deferred_balance,greatest(0,v_invoice.confirmed_paid_amount-v_refunded));
  if v_amount<=0 then raise exception 'no refundable balance remains'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.customer_id,v_subscription.invoice_id,v_subscription.id,v_amount,concat_ws(' — ',p_reason_code,nullif(trim(p_reason_details),'')),p_reason_code,'requested',p_actor_user_id,jsonb_build_object('remaining_days',v_remaining_days,'daily_value',v_daily_value,'deferred_balance',v_subscription.deferred_balance,'confirmed_cash_available',greatest(0,v_invoice.confirmed_paid_amount-v_refunded)),p_recipient_method,trim(p_recipient_account_name),trim(p_recipient_account_reference),v_subscription.is_demo)
  returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,v_amount,v_subscription.is_demo);
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'refund_requested',jsonb_build_object('refund_id',v_refund_id,'amount',v_amount,'remaining_days',v_remaining_days,'daily_value',v_daily_value),p_actor_user_id,v_subscription.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'subscription_id',v_subscription.id,'amount',v_amount),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_subscription.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_subscription public.subscriptions; v_transaction_id uuid; v_new_deferred numeric(18,2); v_paid_before numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' or v_refund.invoice_id is null then raise exception 'approved invoice refund is required'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'refund payer must be different from requester'; end if;
  if nullif(trim(p_proof_reference),'') is null then raise exception 'refund payment proof is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.pay',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.pay and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  v_paid_before:=v_invoice.confirmed_paid_amount;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,v_invoice.currency,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.invoices set confirmed_paid_amount=greatest(0,confirmed_paid_amount-v_refund.amount),status=case when confirmed_paid_amount-v_refund.amount<=0 then 'refunded' else 'partially_paid' end,updated_at=now() where id=v_invoice.id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=trim(p_proof_reference),transaction_id=v_transaction_id where id=v_refund.id;
  insert into public.payment_allocations(organization_id,transaction_id,invoice_id,subscription_id,allocation_type,amount,allocated_by,is_demo)
  values(v_refund.organization_id,v_transaction_id,v_invoice.id,v_refund.subscription_id,'invoice',v_refund.amount,p_actor_user_id,v_refund.is_demo);
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,-least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(v_paid_before,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce join public.payment_transactions pt on pt.id=ce.source_transaction_id join public.payment_submissions ps on ps.id=pt.submission_id
  where ps.invoice_id=v_invoice.id and ce.entry_type='commission' and ce.status<>'reversed' on conflict do nothing;
  if v_refund.subscription_id is not null then
    select * into v_subscription from public.subscriptions where id=v_refund.subscription_id for update;
    v_new_deferred:=greatest(0,v_subscription.deferred_balance-least(v_refund.amount,v_subscription.deferred_balance));
    update public.subscriptions set deferred_balance=v_new_deferred,status='cancelled',ends_on=current_date,updated_at=now() where id=v_subscription.id;
    update public.planned_service_days set status='cancelled',operations_note=concat_ws(' · ',operations_note,'Cancelled after paid refund') where subscription_id=v_subscription.id and status in('planned','frozen','not_delivered','exception');
    insert into public.subscription_cancellations(subscription_id,details,requested_by,requested_at,approved_by,approved_at,status,is_demo)
    values(v_subscription.id,v_refund.reason,v_refund.requested_by,v_refund.requested_at,v_refund.approved_by,v_refund.approved_at,'completed',v_refund.is_demo);
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,refund_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,v_invoice.id,v_refund.id,'refund',-(v_subscription.deferred_balance-v_new_deferred),0,v_new_deferred,p_actor_user_id,'refund.deferred:'||v_refund.id::text,v_refund.is_demo);
    insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,'refund_paid',jsonb_build_object('refund_id',v_refund.id,'amount',v_refund.amount,'transaction_id',v_transaction_id),p_actor_user_id,v_refund.is_demo);
  end if;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('invoice_id',v_invoice.id,'transaction_id',v_transaction_id,'amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

drop view if exists public.daily_subscriber_list_v;
drop view if exists public.subscriber_operations_v;

create view public.subscriber_operations_v with(security_invoker=true) as
select s.id,s.organization_id,s.branch_id,s.subscription_number,s.status,s.starts_on,s.ends_on,s.purchased_service_days,s.delivered_service_days,
  greatest(0,s.purchased_service_days-s.delivered_service_days) as remaining_service_days,s.contract_value,s.deferred_balance,s.recognized_revenue,
  round(s.contract_value/nullif(s.purchased_service_days,0),2) as daily_value,s.daily_portions,s.operations_notes,
  c.id as customer_id,c.full_name as customer_name,c.mobile,p.name as package_name,p.program_code,p.meal_plan_code,
  a.address_line,a.area,a.city,a.latitude,a.longitude,a.gps_url,a.delivery_notes,a.delivery_window_start,a.delivery_window_end,
  z.id as zone_id,z.name as zone_name
from public.subscriptions s
join public.customers c on c.id=s.customer_id
join public.package_versions pv on pv.id=s.package_version_id
join public.packages p on p.id=pv.package_id
left join lateral(select ca.* from public.customer_addresses ca where ca.customer_id=c.id order by ca.is_primary desc,ca.id limit 1) a on true
left join public.delivery_zones z on z.id=a.zone_id;

create view public.daily_subscriber_list_v with(security_invoker=true) as
select d.id,d.service_date,d.status,d.branch_id,d.portion_multiplier,d.operations_note,d.meal_override,
  s.id as subscription_id,s.subscription_number,s.deferred_balance,s.daily_portions,c.id as customer_id,c.full_name as customer_name,c.mobile,
  p.name as package_name,p.program_code,p.meal_plan_code,a.address_line,a.area,a.gps_url,a.delivery_notes,a.delivery_window_start,a.delivery_window_end,z.name as zone_name,
  m.breakfast,m.lunch,m.dinner,m.snack_1,m.snack_2,m.delivery_note as menu_delivery_note
from public.planned_service_days d
join public.subscriptions s on s.id=d.subscription_id
join public.customers c on c.id=s.customer_id
join public.package_versions pv on pv.id=s.package_version_id
join public.packages p on p.id=pv.package_id
left join lateral(select ca.* from public.customer_addresses ca where ca.customer_id=c.id order by ca.is_primary desc,ca.id limit 1) a on true
left join public.delivery_zones z on z.id=a.zone_id
left join public.meal_menu_days m on m.organization_id=s.organization_id and m.day_number=extract(day from d.service_date)::integer and m.is_active;

revoke all on function public.create_customer_delivery_profile(uuid,text,text,text,text,text,text,numeric,numeric,text,uuid,text,time,time,text,text,uuid) from public;
revoke all on function public.freeze_subscription_period(uuid,date,date,text,uuid) from public;
revoke all on function public.apply_service_day_action(uuid[],text,integer,text,uuid) from public;
revoke all on function public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid) from public;
grant execute on function public.create_customer_delivery_profile(uuid,text,text,text,text,text,text,numeric,numeric,text,uuid,text,time,time,text,text,uuid) to authenticated;
grant execute on function public.freeze_subscription_period(uuid,date,date,text,uuid) to authenticated;
grant execute on function public.apply_service_day_action(uuid[],text,integer,text,uuid) to authenticated;
grant execute on function public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text)
language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=12,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.tasks'::regclass,'public.customers'::regclass,'public.payment_submissions'::regclass,'public.doctor_sessions'::regclass,'public.deferred_revenue_entries'::regclass,'public.delivery_zones'::regclass,'public.meal_menu_days'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=85,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs'
  union all select 'subscription_operations',to_regprocedure('public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid)') is not null,'Daily operations and calculated refunds';
$$;

insert into public.schema_versions(version,name) values(12,'subscription_operations_acceptance');
commit;

-- ============================================================================
-- 0013_operational_usability_refund_policy.sql
-- ============================================================================
begin;

-- V13: operational usability, canonical Egyptian mobile identity, and the
-- approved cancellation/refund policy. No demo rows are created here.

create or replace function public.normalize_egypt_mobile(p_value text)
returns text language plpgsql immutable set search_path='' as $$
declare v_digits text;
begin
  v_digits := regexp_replace(coalesce(p_value,''), '[^0-9]', '', 'g');
  if v_digits like '0020%' then v_digits := substring(v_digits from 5); end if;
  if v_digits like '20%' and length(v_digits)=12 then v_digits := substring(v_digits from 3); end if;
  if v_digits like '1%' and length(v_digits)=10 then v_digits := '0'||v_digits; end if;
  if v_digits ~ '^01(0|1|2|5)[0-9]{8}$' then return v_digits; end if;
  return null;
end; $$;

alter table public.customers add column mobile_normalized text;

with normalized as (
  select id,public.normalize_egypt_mobile(mobile) as normalized_mobile,
    row_number() over(partition by organization_id,public.normalize_egypt_mobile(mobile) order by created_at,id) as duplicate_rank
  from public.customers where mobile is not null and public.normalize_egypt_mobile(mobile) is not null
)
update public.customers c
set mobile_normalized=case when n.duplicate_rank=1 then n.normalized_mobile else null end
from normalized n where n.id=c.id;

drop index if exists public.customers_org_mobile_uidx;
create unique index customers_org_mobile_normalized_uidx
on public.customers(organization_id,mobile_normalized) where mobile_normalized is not null;

create or replace function public.enforce_customer_mobile_identity()
returns trigger language plpgsql set search_path='' as $$
declare v_normalized text;
begin
  if nullif(trim(new.mobile),'') is null then
    new.mobile:=null; new.mobile_normalized:=null; return new;
  end if;
  v_normalized:=public.normalize_egypt_mobile(new.mobile);
  if v_normalized is null then raise exception 'valid Egyptian mobile is required (010/011/012/015 + 8 digits)'; end if;
  new.mobile:=v_normalized;
  new.mobile_normalized:=v_normalized;
  return new;
end; $$;

create trigger enforce_customer_mobile_identity
before insert or update of mobile on public.customers
for each row execute function public.enforce_customer_mobile_identity();

create or replace function public.create_customer_quotation(
  p_branch_id uuid,p_customer_name text,p_mobile text,p_package_version_id uuid,
  p_quantity numeric,p_discount_percent numeric,p_valid_until date,p_notes text,p_actor_user_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_package public.packages; v_version public.package_versions; v_customer_id uuid; v_quote_id uuid;
  v_subtotal numeric(18,2); v_discount numeric(18,2); v_limit numeric(5,2); v_mobile text;
begin
  select b.organization_id into v_org from public.branches b where b.id=p_branch_id and b.status='active';
  if v_org is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_org) or not public.can_access_branch(v_org,p_branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  v_mobile:=public.normalize_egypt_mobile(p_mobile);
  if nullif(trim(p_customer_name),'') is null or v_mobile is null or p_quantity<=0 or p_discount_percent not between 0 and 100 then raise exception 'customer name, valid unique mobile and quotation values are required'; end if;
  select pv.* into v_version from public.package_versions pv join public.packages p on p.id=pv.package_id
  where pv.id=p_package_version_id and p.organization_id=v_org and p.status='active' and pv.status='active'
    and pv.effective_from<=current_date and (pv.effective_to is null or pv.effective_to>=current_date);
  if v_version.id is null then raise exception 'package version is not available for this organization'; end if;
  select p.* into v_package from public.packages p where p.id=v_version.package_id;
  select coalesce(max(dl.maximum_percent),case when public.has_permission('catalog.manage',v_org) then 100 else 0 end) into v_limit
  from public.discount_limits dl
  where dl.organization_id=v_org and dl.effective_from<=current_date and (dl.effective_to is null or dl.effective_to>=current_date)
    and (dl.user_id=p_actor_user_id or dl.role_id in(select ur.role_id from public.user_roles ur where ur.organization_id=v_org and ur.user_id=p_actor_user_id and ur.valid_from<=now() and (ur.valid_until is null or ur.valid_until>now())));
  if p_discount_percent>coalesce(v_limit,0) then raise exception 'discount exceeds authorized limit'; end if;
  v_subtotal:=round(p_quantity*v_version.price,2); v_discount:=round(v_subtotal*p_discount_percent/100,2);
  select c.id into v_customer_id from public.customers c where c.organization_id=v_org and c.mobile_normalized=v_mobile order by c.created_at limit 1;
  if v_customer_id is null then
    insert into public.customers(organization_id,home_branch_id,full_name,mobile,status,owner_user_id,created_by)
    values(v_org,p_branch_id,trim(p_customer_name),v_mobile,'active',p_actor_user_id,p_actor_user_id) returning id into v_customer_id;
  end if;
  insert into public.quotations(organization_id,branch_id,customer_id,status,currency,subtotal,discount_amount,valid_until,notes,created_by)
  values(v_org,p_branch_id,v_customer_id,'issued',v_version.currency,v_subtotal,v_discount,p_valid_until,p_notes,p_actor_user_id) returning id into v_quote_id;
  insert into public.quotation_lines(quotation_id,package_version_id,description,quantity,unit_price,discount_percent,price_snapshot)
  values(v_quote_id,v_version.id,v_package.name,p_quantity,v_version.price,p_discount_percent,jsonb_build_object('package_id',v_package.id,'package_version_id',v_version.id,'version_number',v_version.version_number,'unit_price',v_version.price,'currency',v_version.currency));
  perform public.enqueue_domain_event(v_org,p_branch_id,'quotation.created','quotation',v_quote_id,jsonb_build_object('customer_id',v_customer_id,'package_version_id',v_version.id,'total',v_subtotal-v_discount),p_actor_user_id,'quotation.created:'||v_quote_id::text,false);
  return jsonb_build_object('customer_id',v_customer_id,'quotation_id',v_quote_id,'customer_reused',exists(select 1 from public.customers c where c.id=v_customer_id and c.created_at<now()-interval '1 second'));
end; $$;

alter table public.refunds add column policy_mode text not null default 'legacy' check(policy_mode in('legacy','early_six_day','finance_review'));
alter table public.refunds add column consumed_service_days integer not null default 0 check(consumed_service_days>=0);
alter table public.refunds add column deduction_amount numeric(18,2) not null default 0 check(deduction_amount>=0);
alter table public.refunds add column finance_decision_reason text;
alter table public.refunds add column refund_due_on date;

create or replace function public.request_calculated_subscription_refund(
  p_subscription_id uuid,p_reason_code text,p_reason_details text,p_recipient_method text,p_recipient_account_name text,p_recipient_account_reference text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_invoice public.invoices; v_refund_id uuid; v_consumed integer; v_deduction numeric(18,2); v_amount numeric(18,2); v_refunded numeric(18,2); v_cash numeric(18,2); v_policy text;
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active or frozen subscription is required'; end if;
  select * into v_invoice from public.invoices where id=v_subscription.invoice_id for update;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  if nullif(trim(p_reason_code),'') is null then raise exception 'refund reason is required'; end if;
  if p_recipient_method not in('instapay','mobile_wallet','bank_transfer') or nullif(trim(p_recipient_account_name),'') is null or nullif(trim(p_recipient_account_reference),'') is null then raise exception 'bank, InstaPay or mobile-wallet recipient details are required'; end if;
  select count(*) into v_consumed from public.planned_service_days where subscription_id=v_subscription.id and status='confirmed_delivered';
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and status in('approved','paid');
  v_cash:=greatest(0,v_invoice.confirmed_paid_amount-v_refunded);
  if v_cash<=0 then raise exception 'no refundable confirmed cash remains'; end if;
  if current_date < v_subscription.starts_on+6 then
    v_policy:='early_six_day'; v_deduction:=v_consumed*600; v_amount:=greatest(0,v_cash-v_deduction);
  else
    v_policy:='finance_review'; v_deduction:=0; v_amount:=v_cash;
  end if;
  if v_amount<=0 then raise exception 'consumed-day deduction leaves no refundable amount'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,policy_mode,consumed_service_days,deduction_amount,refund_due_on,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.customer_id,v_subscription.invoice_id,v_subscription.id,v_amount,concat_ws(' — ',p_reason_code,nullif(trim(p_reason_details),'')),p_reason_code,'requested',p_actor_user_id,jsonb_build_object('policy_mode',v_policy,'consumed_service_days',v_consumed,'consumed_day_rate',case when v_policy='early_six_day' then 600 else null end,'confirmed_cash_available',v_cash,'finance_review_required',v_policy='finance_review'),p_recipient_method,trim(p_recipient_account_name),trim(p_recipient_account_reference),v_policy,v_consumed,v_deduction,current_date+14,v_subscription.is_demo)
  returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,v_amount,v_subscription.is_demo);
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'refund_requested',jsonb_build_object('refund_id',v_refund_id,'amount',v_amount,'policy_mode',v_policy,'consumed_days',v_consumed,'deduction',v_deduction),p_actor_user_id,v_subscription.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'subscription_id',v_subscription.id,'amount',v_amount,'policy_mode',v_policy),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_subscription.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.approve_subscription_refund_policy(p_refund_id uuid,p_approved_deduction numeric,p_reason text,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_refunded numeric(18,2); v_cash numeric(18,2); v_deduction numeric(18,2); v_amount numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status not in('requested','under_review') then raise exception 'refund is not approvable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot approve own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and id<>v_refund.id and status in('approved','paid');
  v_cash:=greatest(0,v_invoice.confirmed_paid_amount-v_refunded);
  if v_refund.policy_mode='finance_review' then
    if p_approved_deduction is null or p_approved_deduction<0 or p_approved_deduction>=v_cash or nullif(trim(p_reason),'') is null then raise exception 'finance deduction and decision reason are required'; end if;
    v_deduction:=p_approved_deduction;
  else
    v_deduction:=v_refund.deduction_amount;
  end if;
  v_amount:=v_cash-v_deduction;
  if v_amount<=0 then raise exception 'approved deduction leaves no refundable amount'; end if;
  update public.refunds set amount=v_amount,deduction_amount=v_deduction,finance_decision_reason=coalesce(nullif(trim(p_reason),''),'Early cancellation: EGP 600 per confirmed delivered day'),status='approved',approved_by=p_actor_user_id,approved_at=now(),calculation_basis=calculation_basis||jsonb_build_object('approved_deduction',v_deduction,'approved_refund',v_amount,'approved_by',p_actor_user_id) where id=v_refund.id;
  update public.approval_requests set status='approved',decided_by=p_actor_user_id,decided_at=now(),decision_reason=coalesce(nullif(trim(p_reason),''),'Automatic early-six-day policy') where entity_type='refund' and entity_id=v_refund.id and status='pending';
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.approved','refund',v_refund.id,jsonb_build_object('invoice_id',v_refund.invoice_id,'amount',v_amount,'deduction',v_deduction,'policy_mode',v_refund.policy_mode),p_actor_user_id,'refund.approved:'||v_refund.id::text,v_refund.is_demo);
end; $$;

revoke all on function public.normalize_egypt_mobile(text) from public;
grant execute on function public.normalize_egypt_mobile(text) to authenticated;
revoke all on function public.approve_subscription_refund_policy(uuid,numeric,text,uuid) from public;
grant execute on function public.approve_subscription_refund_policy(uuid,numeric,text,uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text) language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=13,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.customers'::regclass,'public.tasks'::regclass,'public.invoices'::regclass,'public.refunds'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=85,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs'
  union all select 'subscription_operations',to_regprocedure('public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid)') is not null,'Daily operations and calculated refunds'
  union all select 'mobile_identity',to_regprocedure('public.normalize_egypt_mobile(text)') is not null,'Canonical Egyptian mobile uniqueness'
  union all select 'refund_policy_v13',to_regprocedure('public.approve_subscription_refund_policy(uuid,numeric,text,uuid)') is not null,'Six-day cancellation and Finance review policy';
$$;

insert into public.schema_versions(version,name)
values(13,'operational_usability_refund_policy');

commit;

-- Installation validation: every returned row must show passed = true.
select * from public.validate_eco_healthy_installation();

-- Restore the standard Supabase API grants after recreating the public schema.
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;
grant all on all routines in schema public to postgres, anon, authenticated, service_role;

-- Final validation: every returned row must show passed = true.
select * from public.validate_eco_healthy_installation();
