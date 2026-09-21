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
