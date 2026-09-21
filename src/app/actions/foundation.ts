"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";
import { getViewer, type Viewer } from "@/lib/auth/viewer";
import { canGrantPermission, decideRoleAssignment } from "@/lib/auth/security";

const codeSchema = z.string().trim().min(2).max(50).regex(/^[a-z0-9_]+$/);
const confirmedSchema = z.literal("yes");

type AdminClient = ReturnType<typeof createAdminClient>;
type RoleAuthority = {
  id: string;
  code: string;
  is_system: boolean;
  is_active: boolean;
  organization_id: string | null;
  permissions: string[];
};

async function authorized(permission: string) {
  const viewer = await getViewer();
  if (!viewer || viewer.preview || !viewer.permissions.includes(permission)) throw new Error("Not authorized");
  return viewer;
}

function fail(path: string): never {
  redirect(`${path}?error=1`);
}

async function getRoleAuthority(admin: AdminClient, roleId: string): Promise<RoleAuthority | null> {
  const [{ data: role }, { data: permissionRows }] = await Promise.all([
    admin.from("roles").select("id, code, is_system, is_active, organization_id").eq("id", roleId).maybeSingle(),
    admin.from("role_permissions").select("permissions(code)").eq("role_id", roleId),
  ]);
  if (!role) return null;
  const permissions = (permissionRows || []).flatMap((row) => {
    const permission = Array.isArray(row.permissions) ? row.permissions[0] : row.permissions;
    return permission?.code ? [permission.code] : [];
  });
  return { ...role, permissions };
}

async function assertRoleAssignment(
  admin: AdminClient,
  viewer: Viewer,
  targetUserId: string,
  roleId: string,
  options: { requireMembership?: boolean; requireActiveRole?: boolean } = {},
) {
  const { requireMembership = true, requireActiveRole = true } = options;
  const [role, membershipResult] = await Promise.all([
    getRoleAuthority(admin, roleId),
    requireMembership
      ? admin.from("organization_memberships").select("id").eq("organization_id", viewer.organizationId).eq("user_id", targetUserId).maybeSingle()
      : Promise.resolve({ data: { id: "new-user" } }),
  ]);
  if (!role || !membershipResult.data || (requireActiveRole && !role.is_active)) return false;
  if (role.organization_id && role.organization_id !== viewer.organizationId) return false;
  return decideRoleAssignment({
    actorUserId: viewer.id,
    targetUserId,
    actorPermissions: viewer.permissions,
    targetRolePermissions: role.permissions,
    targetRoleCode: role.code,
  }).allowed;
}

async function targetHasSensitiveRole(admin: AdminClient, organizationId: string, userId: string) {
  const { data } = await admin
    .from("user_roles")
    .select("roles(code)")
    .eq("organization_id", organizationId)
    .eq("user_id", userId);
  return (data || []).some((row) => {
    const role = Array.isArray(row.roles) ? row.roles[0] : row.roles;
    return role?.code === "ceo_super_admin";
  });
}

export async function inviteUserAction(formData: FormData) {
  const viewer = await authorized("users.manage");
  const schema = z.object({
    email: z.email(),
    fullName: z.string().trim().min(2).max(120),
    roleId: z.uuid().optional().or(z.literal("")),
  });
  const parsed = schema.safeParse({ email: formData.get("email"), fullName: formData.get("fullName"), roleId: formData.get("roleId") });
  if (!parsed.success) fail("/admin/users");

  const admin = createAdminClient();
  if (parsed.data.roleId) {
    const canAssign = await assertRoleAssignment(admin, viewer, "new-invited-user", parsed.data.roleId, { requireMembership: false });
    if (!canAssign) fail("/admin/users");
  }

  const { data, error } = await admin.auth.admin.inviteUserByEmail(parsed.data.email, { data: { full_name: parsed.data.fullName } });
  if (error || !data.user) fail("/admin/users");

  const { error: membershipError } = await admin.from("organization_memberships").upsert({
    organization_id: viewer.organizationId,
    user_id: data.user.id,
    status: "active",
    invited_by: viewer.id,
    activated_at: new Date().toISOString(),
  });
  if (membershipError) fail("/admin/users");
  if (parsed.data.roleId) {
    const { error: roleError } = await admin.from("user_roles").insert({ organization_id: viewer.organizationId, user_id: data.user.id, role_id: parsed.data.roleId, assigned_by: viewer.id });
    if (roleError) fail("/admin/users");
  }
  revalidatePath("/admin/users");
  redirect("/admin/users?saved=1");
}

export async function createRoleAction(formData: FormData) {
  const viewer = await authorized("roles.manage");
  const schema = z.object({ code: codeSchema, name: z.string().trim().min(2).max(80), description: z.string().trim().max(240).optional() });
  const parsed = schema.safeParse({ code: formData.get("code"), name: formData.get("name"), description: formData.get("description") });
  if (!parsed.success) fail("/admin/roles");
  const admin = createAdminClient();
  const { error } = await admin.from("roles").insert({ organization_id: viewer.organizationId, code: parsed.data.code, name: parsed.data.name, description: parsed.data.description || null, is_system: false, created_by: viewer.id });
  if (error) fail("/admin/roles");
  revalidatePath("/admin/roles");
  redirect("/admin/roles?saved=1");
}

export async function assignUserRoleAction(formData: FormData) {
  const viewer = await authorized("roles.assign");
  const parsed = z.object({ userId: z.uuid(), roleId: z.uuid() }).safeParse({ userId: formData.get("userId"), roleId: formData.get("roleId") });
  if (!parsed.success) fail("/admin/users");
  const admin = createAdminClient();
  if (!await assertRoleAssignment(admin, viewer, parsed.data.userId, parsed.data.roleId)) fail("/admin/users");
  const { error } = await admin.from("user_roles").upsert({ organization_id: viewer.organizationId, user_id: parsed.data.userId, role_id: parsed.data.roleId, assigned_by: viewer.id }, { onConflict: "organization_id,user_id,role_id" });
  if (error) fail("/admin/users");
  revalidatePath("/admin/users");
  redirect("/admin/users?saved=1");
}

export async function revokeUserRoleAction(formData: FormData) {
  const viewer = await authorized("roles.assign");
  const parsed = z.object({ assignmentId: z.uuid(), confirm: confirmedSchema }).safeParse({ assignmentId: formData.get("assignmentId"), confirm: formData.get("confirm") });
  if (!parsed.success) fail("/admin/users");
  const admin = createAdminClient();
  const { data: assignment } = await admin.from("user_roles").select("id, user_id, role_id").eq("id", parsed.data.assignmentId).eq("organization_id", viewer.organizationId).maybeSingle();
  if (!assignment || !await assertRoleAssignment(admin, viewer, assignment.user_id, assignment.role_id, { requireActiveRole: false })) fail("/admin/users");
  const { error } = await admin.from("user_roles").delete().eq("id", assignment.id).eq("organization_id", viewer.organizationId);
  if (error) fail("/admin/users");
  revalidatePath("/admin/users");
  redirect("/admin/users?saved=1");
}

export async function grantRolePermissionAction(formData: FormData) {
  const viewer = await authorized("roles.manage");
  const parsed = z.object({ roleId: z.uuid(), permissionId: z.uuid() }).safeParse({ roleId: formData.get("roleId"), permissionId: formData.get("permissionId") });
  if (!parsed.success) fail("/admin/roles");
  const admin = createAdminClient();
  const [role, permissionResult, actorRoleResult] = await Promise.all([
    getRoleAuthority(admin, parsed.data.roleId),
    admin.from("permissions").select("id, code").eq("id", parsed.data.permissionId).maybeSingle(),
    admin.from("user_roles").select("id").eq("organization_id", viewer.organizationId).eq("user_id", viewer.id).eq("role_id", parsed.data.roleId).maybeSingle(),
  ]);
  const permission = permissionResult.data;
  if (!role || role.is_system || role.organization_id !== viewer.organizationId || !role.is_active || !permission) fail("/admin/roles");
  if (!canGrantPermission(viewer.permissions, permission.code, Boolean(actorRoleResult.data))) fail("/admin/roles");
  const { error } = await admin.from("role_permissions").upsert({ role_id: role.id, permission_id: permission.id, granted_by: viewer.id }, { onConflict: "role_id,permission_id" });
  if (error) fail("/admin/roles");
  revalidatePath("/admin/roles");
  redirect("/admin/roles?saved=1");
}

export async function removeRolePermissionAction(formData: FormData) {
  const viewer = await authorized("roles.manage");
  const parsed = z.object({ mapping: z.string().regex(/^[0-9a-f-]{36}:[0-9a-f-]{36}$/i), confirm: confirmedSchema }).safeParse({ mapping: formData.get("mapping"), confirm: formData.get("confirm") });
  if (!parsed.success) fail("/admin/roles");
  const [roleId, permissionId] = parsed.data.mapping.split(":");
  const admin = createAdminClient();
  const role = await getRoleAuthority(admin, roleId);
  if (!role || role.is_system || role.organization_id !== viewer.organizationId) fail("/admin/roles");
  const { error, count } = await admin.from("role_permissions").delete({ count: "exact" }).eq("role_id", role.id).eq("permission_id", permissionId);
  if (error || count !== 1) fail("/admin/roles");
  revalidatePath("/admin/roles");
  redirect("/admin/roles?saved=1");
}

export async function deactivateCustomRoleAction(formData: FormData) {
  const viewer = await authorized("roles.manage");
  const parsed = z.object({ roleId: z.uuid(), confirm: confirmedSchema }).safeParse({ roleId: formData.get("roleId"), confirm: formData.get("confirm") });
  if (!parsed.success) fail("/admin/roles");
  const admin = createAdminClient();
  const role = await getRoleAuthority(admin, parsed.data.roleId);
  if (!role || role.is_system || role.organization_id !== viewer.organizationId || !role.is_active) fail("/admin/roles");
  const { error } = await admin.from("roles").update({ is_active: false }).eq("id", role.id).eq("organization_id", viewer.organizationId).eq("is_system", false);
  if (error) fail("/admin/roles");
  revalidatePath("/admin/roles");
  revalidatePath("/admin/users");
  redirect("/admin/roles?saved=1");
}

export async function createBranchAction(formData: FormData) {
  const viewer = await authorized("branches.manage");
  const schema = z.object({ code: z.string().trim().min(2).max(20).regex(/^[A-Za-z0-9_]+$/), name: z.string().trim().min(2).max(100) });
  const parsed = schema.safeParse({ code: formData.get("code"), name: formData.get("name") });
  if (!parsed.success) fail("/admin/branch-access");
  const admin = createAdminClient();
  const { error } = await admin.from("branches").insert({ organization_id: viewer.organizationId, code: parsed.data.code.toUpperCase(), name: parsed.data.name, status: "active", created_by: viewer.id });
  if (error) fail("/admin/branch-access");
  revalidatePath("/admin/branch-access");
  redirect("/admin/branch-access?saved=1");
}

export async function assignBranchAccessAction(formData: FormData) {
  const viewer = await authorized("branches.manage");
  const schema = z.object({ userId: z.uuid(), branchId: z.uuid(), accessLevel: z.enum(["view", "operate", "manage"]) });
  const parsed = schema.safeParse({ userId: formData.get("userId"), branchId: formData.get("branchId"), accessLevel: formData.get("accessLevel") });
  if (!parsed.success) fail("/admin/branch-access");
  const admin = createAdminClient();
  const [{ data: membership }, { data: branch }] = await Promise.all([
    admin.from("organization_memberships").select("id").eq("organization_id", viewer.organizationId).eq("user_id", parsed.data.userId).maybeSingle(),
    admin.from("branches").select("id").eq("organization_id", viewer.organizationId).eq("id", parsed.data.branchId).maybeSingle(),
  ]);
  if (!membership || !branch) fail("/admin/branch-access");
  const { error } = await admin.from("user_branch_access").upsert({ organization_id: viewer.organizationId, user_id: parsed.data.userId, branch_id: parsed.data.branchId, access_level: parsed.data.accessLevel, granted_by: viewer.id }, { onConflict: "organization_id,user_id,branch_id" });
  if (error) fail("/admin/branch-access");
  revalidatePath("/admin/branch-access");
  redirect("/admin/branch-access?saved=1");
}

export async function revokeBranchAccessAction(formData: FormData) {
  const viewer = await authorized("branches.manage");
  const parsed = z.object({ accessId: z.uuid(), confirm: confirmedSchema }).safeParse({ accessId: formData.get("accessId"), confirm: formData.get("confirm") });
  if (!parsed.success) fail("/admin/branch-access");
  const admin = createAdminClient();
  const { error, count } = await admin.from("user_branch_access").delete({ count: "exact" }).eq("id", parsed.data.accessId).eq("organization_id", viewer.organizationId);
  if (error || count !== 1) fail("/admin/branch-access");
  revalidatePath("/admin/branch-access");
  redirect("/admin/branch-access?saved=1");
}

export async function setUserSuspensionAction(formData: FormData) {
  const viewer = await authorized("users.suspend");
  const parsed = z.object({ userId: z.uuid(), operation: z.enum(["suspend", "reactivate"]), confirm: confirmedSchema }).safeParse({ userId: formData.get("userId"), operation: formData.get("operation"), confirm: formData.get("confirm") });
  if (!parsed.success || parsed.data.userId === viewer.id) fail("/admin/users");
  const admin = createAdminClient();
  const { data: membership } = await admin.from("organization_memberships").select("id, status").eq("organization_id", viewer.organizationId).eq("user_id", parsed.data.userId).maybeSingle();
  if (!membership) fail("/admin/users");
  if (await targetHasSensitiveRole(admin, viewer.organizationId, parsed.data.userId) && !viewer.permissions.includes("roles.assign_sensitive")) fail("/admin/users");

  const suspend = parsed.data.operation === "suspend";
  const { error: authError } = await admin.auth.admin.updateUserById(parsed.data.userId, { ban_duration: suspend ? "876000h" : "none" });
  if (authError) fail("/admin/users");
  const { error: membershipError } = await admin.from("organization_memberships").update({
    status: suspend ? "suspended" : "active",
    disabled_at: suspend ? new Date().toISOString() : null,
    activated_at: suspend ? undefined : new Date().toISOString(),
  }).eq("id", membership.id).eq("organization_id", viewer.organizationId);
  if (membershipError) {
    await admin.auth.admin.updateUserById(parsed.data.userId, { ban_duration: suspend ? "none" : "876000h" });
    fail("/admin/users");
  }
  const { error: profileError } = await admin.from("profiles").update({ is_active: !suspend }).eq("id", parsed.data.userId);
  if (profileError) fail("/admin/users");
  revalidatePath("/admin/users");
  redirect("/admin/users?saved=1");
}

export async function saveSettingAction(formData: FormData) {
  const viewer = await authorized("settings.manage");
  const schema = z.object({ key: z.enum(["organization.timezone", "organization.base_currency"]), value: z.string().trim().min(2).max(80) });
  const parsed = schema.safeParse({ key: formData.get("key"), value: formData.get("value") });
  if (!parsed.success) fail("/settings");
  const admin = createAdminClient();
  const { error } = await admin.from("app_settings").upsert({ organization_id: viewer.organizationId, key: parsed.data.key, value: parsed.data.value, updated_by: viewer.id }, { onConflict: "organization_id,key" });
  if (error) fail("/settings");
  revalidatePath("/settings");
  redirect("/settings?saved=1");
}
