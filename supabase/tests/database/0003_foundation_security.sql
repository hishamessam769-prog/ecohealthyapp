begin;

create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '11000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'ceo-security@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"CEO Security"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '11000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'finance-security@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Finance Security"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '11000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'sales-security@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Sales Security"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '11000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'delegated-security@eco.local', 'test', now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Delegated Security"}', now(), now());

insert into public.organizations (id, code, name) values
  ('21000000-0000-0000-0000-000000000001', 'SECONE', 'Security Organization One'),
  ('21000000-0000-0000-0000-000000000002', 'SECTWO', 'Security Organization Two');

insert into public.organization_memberships (organization_id, user_id, status, activated_at) values
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'active', now()),
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', 'active', now()),
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', 'active', now()),
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000004', 'active', now());

insert into public.user_roles (organization_id, user_id, role_id)
select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', id from public.roles where code = 'ceo_super_admin' and organization_id is null;
insert into public.user_roles (organization_id, user_id, role_id)
select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', id from public.roles where code = 'finance_accountant' and organization_id is null;
insert into public.user_roles (organization_id, user_id, role_id)
select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', id from public.roles where code = 'sales_representative' and organization_id is null;

insert into public.roles (id, organization_id, code, name, is_system)
values ('41000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'delegated_role_assigner', 'Delegated Role Assigner', false);
insert into public.role_permissions (role_id, permission_id)
select '41000000-0000-0000-0000-000000000001', id from public.permissions where code in ('roles.assign', 'dashboard.view');
insert into public.user_roles (organization_id, user_id, role_id)
values ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000001');

insert into public.branches (id, organization_id, code, name) values
  ('31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'SEC1', 'Security Branch One'),
  ('31000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000001', 'SEC2', 'Security Branch Two'),
  ('31000000-0000-0000-0000-000000000003', '21000000-0000-0000-0000-000000000002', 'OTHER', 'Other Organization Branch');
insert into public.user_branch_access (organization_id, user_id, branch_id, access_level)
values ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'view');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select ok(not public.has_permission('users.view', '21000000-0000-0000-0000-000000000001'), 'sales representative cannot view admin users');
select ok(not public.has_permission('roles.view', '21000000-0000-0000-0000-000000000001'), 'sales representative cannot view admin roles');
select is((select count(*)::integer from public.branches), 1, 'branch one user sees one branch only');
select ok(public.can_access_branch('21000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001'), 'assigned branch is visible');
select ok(not public.can_access_branch('21000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000002'), 'second branch is isolated');

select throws_ok(
  $$insert into public.user_roles (organization_id, user_id, role_id)
    select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', id
    from public.roles where code = 'finance_manager' and organization_id is null$$,
  '42501', 'roles.assign is required', 'sales cannot grant itself a finance role'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$insert into public.user_roles (organization_id, user_id, role_id)
    select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000002', id
    from public.roles where code = 'sales_manager' and organization_id is null$$,
  '42501', 'roles.assign is required', 'finance cannot grant itself any role'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$insert into public.user_roles (organization_id, user_id, role_id)
    select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000004', id
    from public.roles where code = 'sales_representative' and organization_id is null$$,
  '42501', 'self role assignment is not allowed', 'delegated role assigner cannot assign itself'
);
select throws_ok(
  $$insert into public.user_roles (organization_id, user_id, role_id)
    select '21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', id
    from public.roles where code = 'ceo_super_admin' and organization_id is null$$,
  '42501', 'roles.assign_sensitive is required', 'CEO role requires sensitive assignment authority'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$insert into public.user_branch_access (organization_id, user_id, branch_id, access_level)
    values ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000003', 'view')$$,
  '23514', 'branch is not in the organization', 'cross-organization branch access is rejected'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

update public.organization_memberships
set status = 'suspended', disabled_at = now()
where organization_id = '21000000-0000-0000-0000-000000000001'
  and user_id = '11000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select ok(not public.has_permission('dashboard.view', '21000000-0000-0000-0000-000000000001'), 'suspended user loses access immediately');
select is((select count(*)::integer from public.branches), 0, 'suspended user cannot read branch data');

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
update public.organization_memberships
set status = 'active', disabled_at = null
where organization_id = '21000000-0000-0000-0000-000000000001'
  and user_id = '11000000-0000-0000-0000-000000000003';
delete from public.user_roles
where organization_id = '21000000-0000-0000-0000-000000000001'
  and user_id = '11000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select ok(not public.has_permission('dashboard.view', '21000000-0000-0000-0000-000000000001'), 'revoked role removes its permission immediately');
select is((select count(*)::integer from public.user_roles), 0, 'revoked role is no longer visible to its former holder');

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
select ok(exists(select 1 from public.audit_logs where entity_type = 'user_roles' and action = 'delete'), 'role revocation is audited');

select * from finish();
rollback;
