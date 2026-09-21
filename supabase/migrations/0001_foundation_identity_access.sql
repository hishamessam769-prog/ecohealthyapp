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
