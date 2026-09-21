begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'admin-test@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Admin Test"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'sales-test@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Sales Test"}', now(), now());

insert into public.organizations (id, code, name, created_by)
values ('20000000-0000-0000-0000-000000000001', 'TST', 'Test Organization', '10000000-0000-0000-0000-000000000001');

insert into public.organization_memberships (organization_id, user_id, status, activated_at)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'active', now()),
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'active', now());

insert into public.user_roles (organization_id, user_id, role_id)
select '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', id
from public.roles where code = 'ceo_super_admin' and organization_id is null;

insert into public.user_roles (organization_id, user_id, role_id)
select '20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', id
from public.roles where code = 'sales_representative' and organization_id is null;

insert into public.branches (id, organization_id, code, name) values
('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'ONE', 'Branch One'),
('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'TWO', 'Branch Two');

insert into public.user_branch_access (organization_id, user_id, branch_id, access_level)
values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'view');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select ok(public.has_permission('dashboard.view', '20000000-0000-0000-0000-000000000001'), 'sales rep has explicit dashboard permission');
select ok(not public.has_permission('users.manage', '20000000-0000-0000-0000-000000000001'), 'sales rep cannot manage users');
select ok(public.can_access_branch('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'), 'assigned branch is accessible');
select ok(not public.can_access_branch('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002'), 'unassigned branch is denied');
select is((select count(*)::integer from public.branches), 1, 'RLS returns only the assigned branch');
select ok(not public.has_permission('audit.view', '20000000-0000-0000-0000-000000000001'), 'sales rep cannot inspect audit history');

select * from finish();
rollback;
