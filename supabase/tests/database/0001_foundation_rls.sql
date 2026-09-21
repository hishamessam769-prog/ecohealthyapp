begin;

create extension if not exists pgtap with schema extensions;
select plan(30);

select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'organizations', 'organizations exists');
select has_table('public', 'organization_memberships', 'organization_memberships exists');
select has_table('public', 'branches', 'branches exists');
select has_table('public', 'roles', 'roles exists');
select has_table('public', 'permissions', 'permissions exists');
select has_table('public', 'role_permissions', 'role_permissions exists');
select has_table('public', 'user_roles', 'user_roles exists');
select has_table('public', 'user_branch_access', 'user_branch_access exists');
select has_table('public', 'audit_logs', 'audit_logs exists');

select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'RLS enabled: profiles');
select ok((select relrowsecurity from pg_class where oid = 'public.organizations'::regclass), 'RLS enabled: organizations');
select ok((select relrowsecurity from pg_class where oid = 'public.organization_memberships'::regclass), 'RLS enabled: memberships');
select ok((select relrowsecurity from pg_class where oid = 'public.branches'::regclass), 'RLS enabled: branches');
select ok((select relrowsecurity from pg_class where oid = 'public.roles'::regclass), 'RLS enabled: roles');
select ok((select relrowsecurity from pg_class where oid = 'public.permissions'::regclass), 'RLS enabled: permissions');
select ok((select relrowsecurity from pg_class where oid = 'public.role_permissions'::regclass), 'RLS enabled: role_permissions');
select ok((select relrowsecurity from pg_class where oid = 'public.user_roles'::regclass), 'RLS enabled: user_roles');
select ok((select relrowsecurity from pg_class where oid = 'public.user_branch_access'::regclass), 'RLS enabled: branch access');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_logs'::regclass), 'RLS enabled: audit_logs');

select has_function('public', 'has_permission', array['text', 'uuid'], 'permission helper exists');
select has_function('public', 'can_access_branch', array['uuid', 'uuid'], 'branch helper exists');
select has_function('public', 'my_permission_codes', array['uuid'], 'permission list helper exists');

select policies_are('public', 'audit_logs', array['audit_logs_select_authorized'], 'audit has select-only RLS policy');
select policies_are('public', 'permissions', array['permissions_select_authorized'], 'permission catalog is restricted');

select ok(exists(select 1 from pg_trigger where tgrelid = 'public.audit_logs'::regclass and tgname = 'audit_logs_no_update_or_delete'), 'audit mutation blocker exists');
select ok(exists(select 1 from pg_trigger where tgrelid = 'public.user_roles'::regclass and tgname = 'audit_user_roles'), 'role assignments are audited');
select ok(exists(select 1 from pg_trigger where tgrelid = 'public.user_branch_access'::regclass and tgname = 'audit_branch_access'), 'branch access is audited');

select is((select count(*)::integer from public.roles where is_system), 15, 'all fifteen system roles are seeded');
select ok((select count(*) >= 20 from public.permissions), 'foundation permission catalog is seeded');

select * from finish();
rollback;
