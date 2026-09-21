import "server-only";

import { cache } from "react";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { hasSupabaseBrowserConfig, isPreviewMode } from "@/lib/supabase/config";

export type ViewerBranch = { id: string; name: string; code: string };
export type Viewer = {
  id: string;
  name: string;
  email: string;
  organizationId: string;
  organizationName: string;
  roleNames: string[];
  permissions: string[];
  branches: ViewerBranch[];
  activeBranchId: string | null;
  preview: boolean;
};

function one<T>(value: T | T[] | null): T | null {
  return Array.isArray(value) ? value[0] ?? null : value;
}

const previewViewer: Viewer = {
  id: "preview-user",
  name: "مسؤول النظام",
  email: "admin@preview.local",
  organizationId: "preview-organization",
  organizationName: "Eco Healthy",
  roleNames: ["CEO / Super Admin"],
  permissions: [
    "dashboard.view",
    "users.view",
    "users.manage",
    "roles.view",
    "roles.manage",
    "roles.assign",
    "roles.assign_sensitive",
    "users.suspend",
    "permissions.view",
    "branches.view",
    "branches.manage",
    "audit.view",
    "settings.view",
    "settings.manage",
    "notifications.view",
    "approvals.view",
    "projects.view",
    "projects.manage",
    "tasks.view",
    "tasks.create",
    "tasks.assign",
    "tasks.view_own",
    "tasks.view_team",
    "tasks.view_all",
    "leads.view",
    "leads.manage",
    "customers.view",
    "customers.manage",
    "catalog.view",
    "sales.quote",
    "sales.invoice",
    "payments.submit",
    "payments.review",
    "payments.confirm",
    "refunds.request",
    "refunds.approve",
    "subscriptions.view",
    "subscriptions.manage",
    "service.confirm_delivery",
    "revenue.view",
    "complaints.view",
    "complaints.manage",
    "targets.view_own",
    "targets.view_team",
    "doctors.view",
    "doctors.manage",
    "doctors.manage_availability",
    "sessions.create",
    "sessions.view_own",
    "sessions.view_team",
    "doctor_commissions.view_own",
    "doctor_commissions.review",
  ],
  branches: [
    { id: "preview-main", name: "الفرع الرئيسي", code: "MAIN" },
    { id: "preview-second", name: "فرع التجمع", code: "NCA" },
  ],
  activeBranchId: "preview-main",
  preview: true,
};

export const getViewer = cache(async (): Promise<Viewer | null> => {
  if (isPreviewMode()) return previewViewer;
  if (!hasSupabaseBrowserConfig()) return null;

  const supabase = await createClient();
  const { data: authData } = await supabase.auth.getUser();
  const user = authData.user;
  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, is_active")
    .eq("id", user.id)
    .maybeSingle();

  const { data: memberships } = await supabase
    .from("organization_memberships")
    .select("organization_id, organizations(name)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1);

  const membership = memberships?.[0] as
    | { organization_id: string; organizations: { name: string } | null }
    | undefined;
  if (!membership) return null;

  const organizationId = membership.organization_id;
  const [{ data: permissionRows }, { data: roleRows }, { data: branchRows }] = await Promise.all([
    supabase.rpc("my_permission_codes", { p_organization_id: organizationId }),
    supabase
      .from("user_roles")
      .select("roles(name, is_active)")
      .eq("user_id", user.id)
      .eq("organization_id", organizationId),
    supabase
      .from("branches")
      .select("id, name, code")
      .eq("organization_id", organizationId)
      .eq("status", "active")
      .order("name"),
  ]);

  if (!profile?.is_active) return null;

  const branches = (branchRows || []) as ViewerBranch[];
  const cookieBranchId = (await cookies()).get("eco_active_branch")?.value;
  const preferredBranch = branches.find((branch) => branch.id === cookieBranchId)
    || branches.find((branch) => branch.code.toUpperCase() === "MAIN")
    || branches[0]
    || null;

  return {
    id: user.id,
    name: profile?.full_name || user.email || "User",
    email: user.email || "",
    organizationId,
    organizationName: one(membership.organizations)?.name || "Eco Healthy",
    permissions: (permissionRows || []).map((row: { permission_code: string }) => row.permission_code),
    roleNames: (roleRows || [])
      .map((row) => {
        const role = one(row.roles);
        return role?.is_active ? role.name : null;
      })
      .filter((name): name is string => Boolean(name)),
    branches,
    activeBranchId: preferredBranch?.id || null,
    preview: false,
  };
});

export function can(viewer: Viewer, permission: string) {
  return viewer.permissions.includes(permission);
}
