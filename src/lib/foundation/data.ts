import "server-only";

import { createClient } from "@/lib/supabase/server";
import type { Viewer } from "@/lib/auth/viewer";

export type FoundationUser = {
  id: string;
  name: string;
  email: string;
  status: string;
  roles: string[];
  createdAt: string | null;
};

export type FoundationRole = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  system: boolean;
  active: boolean;
};

export type FoundationPermission = {
  id: string;
  code: string;
  name: string;
  module: string;
  description: string | null;
};

export type BranchAccess = {
  id: string;
  userName: string;
  branchName: string;
  accessLevel: string;
  validUntil: string | null;
};

export type UserRoleAssignment = {
  id: string;
  userId: string;
  userName: string;
  roleId: string;
  roleName: string;
  roleCode: string;
};

export type CustomRolePermission = {
  roleId: string;
  roleName: string;
  permissionId: string;
  permissionCode: string;
};

export type AuditEntry = {
  id: string;
  action: string;
  entityType: string;
  actorName: string;
  reason: string | null;
  createdAt: string;
};

const previewRoles: FoundationRole[] = [
  { id: "preview-role-1", code: "ceo_super_admin", name: "CEO / Super Admin", description: "Full governed access across the organization", system: true, active: true },
  { id: "preview-role-2", code: "finance_manager", name: "Finance Manager", description: "Finance review and controlled approvals", system: true, active: true },
  { id: "preview-role-3", code: "sales_manager", name: "Sales Manager", description: "Sales team and commercial workflow", system: true, active: true },
  { id: "preview-role-4", code: "project_manager", name: "Project Manager", description: "Projects and tasks within assigned scope", system: true, active: true },
];

const previewPermissions: FoundationPermission[] = [
  { id: "p1", code: "users.manage", name: "Manage users", module: "Identity", description: "Invite users and manage account state" },
  { id: "p2", code: "roles.manage", name: "Manage roles", module: "Identity", description: "Create roles and assign permissions" },
  { id: "p3", code: "branches.manage", name: "Manage branches", module: "Organization", description: "Create branches and control access" },
  { id: "p4", code: "audit.view", name: "View audit log", module: "Governance", description: "Inspect sensitive activity history" },
];

function one<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

export async function getFoundationUsers(viewer: Viewer): Promise<FoundationUser[]> {
  if (viewer.preview) return [{ id: viewer.id, name: viewer.name, email: viewer.email, status: "active", roles: viewer.roleNames, createdAt: new Date().toISOString() }];
  const supabase = await createClient();
  const [{ data }, { data: roleData }] = await Promise.all([
    supabase
      .from("organization_memberships")
      .select("user_id, status, created_at, profiles(full_name, email)")
      .eq("organization_id", viewer.organizationId)
      .order("created_at", { ascending: false }),
    supabase
      .from("user_roles")
      .select("user_id, roles!inner(name, is_active)")
      .eq("organization_id", viewer.organizationId),
  ]);
  const roleMap = new Map<string, string[]>();
  (roleData || []).forEach((row) => {
    const role = one(row.roles);
    const roleName = role?.name;
    if (!roleName || !role.is_active) return;
    roleMap.set(row.user_id, [...(roleMap.get(row.user_id) || []), roleName]);
  });
  return (data || []).map((row) => ({
    id: row.user_id,
    name: one(row.profiles)?.full_name || "—",
    email: one(row.profiles)?.email || "—",
    status: row.status,
    roles: roleMap.get(row.user_id) || [],
    createdAt: row.created_at,
  }));
}

export async function getRoles(viewer: Viewer): Promise<FoundationRole[]> {
  if (viewer.preview) return previewRoles;
  const supabase = await createClient();
  const { data } = await supabase
    .from("roles")
    .select("id, code, name, description, is_system, is_active")
    .or(`organization_id.is.null,organization_id.eq.${viewer.organizationId}`)
    .order("is_system", { ascending: false })
    .order("name");
  return (data || []).map((row) => ({ id: row.id, code: row.code, name: row.name, description: row.description, system: row.is_system, active: row.is_active }));
}

export async function getUserRoleAssignments(viewer: Viewer): Promise<UserRoleAssignment[]> {
  if (viewer.preview) return [];
  const supabase = await createClient();
  const { data } = await supabase
    .from("user_roles")
    .select("id, user_id, role_id, profiles(full_name), roles(name, code)")
    .eq("organization_id", viewer.organizationId)
    .order("assigned_at", { ascending: false });
  return (data || []).map((row) => ({
    id: row.id,
    userId: row.user_id,
    userName: one(row.profiles)?.full_name || "—",
    roleId: row.role_id,
    roleName: one(row.roles)?.name || "—",
    roleCode: one(row.roles)?.code || "—",
  }));
}

export async function getCustomRolePermissions(viewer: Viewer): Promise<CustomRolePermission[]> {
  if (viewer.preview) return [];
  const supabase = await createClient();
  const { data } = await supabase
    .from("role_permissions")
    .select("role_id, permission_id, roles!inner(name, organization_id, is_system), permissions(code)")
    .eq("roles.organization_id", viewer.organizationId)
    .eq("roles.is_system", false)
    .order("granted_at", { ascending: false });
  return (data || []).map((row) => ({
    roleId: row.role_id,
    roleName: one(row.roles)?.name || "—",
    permissionId: row.permission_id,
    permissionCode: one(row.permissions)?.code || "—",
  }));
}

export async function getPermissions(viewer: Viewer): Promise<FoundationPermission[]> {
  if (viewer.preview) return previewPermissions;
  const supabase = await createClient();
  const { data } = await supabase.from("permissions").select("id, code, name, module, description").order("module").order("code");
  return (data || []) as FoundationPermission[];
}

export async function getBranchAccess(viewer: Viewer): Promise<BranchAccess[]> {
  if (viewer.preview) return viewer.branches.map((branch, index) => ({ id: branch.id, userName: viewer.name, branchName: branch.name, accessLevel: index === 0 ? "manage" : "view", validUntil: null }));
  const supabase = await createClient();
  const { data } = await supabase
    .from("user_branch_access")
    .select("id, access_level, valid_until, profiles(full_name), branches(name)")
    .eq("organization_id", viewer.organizationId)
    .order("created_at", { ascending: false });
  return (data || []).map((row) => ({
    id: row.id,
    userName: one(row.profiles)?.full_name || "—",
    branchName: one(row.branches)?.name || "—",
    accessLevel: row.access_level,
    validUntil: row.valid_until,
  }));
}

export async function getAuditEntries(viewer: Viewer): Promise<AuditEntry[]> {
  if (viewer.preview) return [];
  const supabase = await createClient();
  const { data } = await supabase
    .from("audit_logs")
    .select("id, action, entity_type, reason, created_at, actor:profiles!audit_logs_actor_user_id_fkey(full_name)")
    .eq("organization_id", viewer.organizationId)
    .order("created_at", { ascending: false })
    .limit(100);
  return (data || []).map((row) => ({
    id: row.id,
    action: row.action,
    entityType: row.entity_type,
    reason: row.reason,
    createdAt: row.created_at,
    actorName: one(row.actor)?.full_name || "System",
  }));
}

export async function getSettings(viewer: Viewer) {
  if (viewer.preview) return [{ key: "organization.timezone", value: "Africa/Cairo", description: "Operational display timezone" }, { key: "organization.base_currency", value: "EGP", description: "Base reporting currency" }];
  const supabase = await createClient();
  const { data } = await supabase.from("app_settings").select("key, value, description").eq("organization_id", viewer.organizationId).order("key");
  return (data || []).map((row) => ({ key: row.key, value: typeof row.value === "string" ? row.value : JSON.stringify(row.value), description: row.description }));
}
