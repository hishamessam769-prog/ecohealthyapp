import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { AppError } from "@/lib/errors";

export type Principal = {
  userId: string;
  employeeId: string;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
  teamIds: string[];
  mfaVerified: boolean;
};

const privilegedMfaRoles = new Set(["ceo", "system_admin", "finance_controller", "accountant"]);

export const getCurrentPrincipal = cache(async (): Promise<Principal | null> => {
  const supabase = await createClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return null;
  const admin = createAdminClient();
  const { data: employee } = await admin.from("eco_employees").select("id,full_name,email,status").eq("auth_user_id", user.id).maybeSingle();
  if (!employee || employee.status !== "ACTIVE") return null;
  const today = new Date().toISOString().slice(0, 10);
  const [{ data: assignments }, { data: teams }, assurance] = await Promise.all([
    admin.from("eco_employee_role_assignments").select("role_code").eq("employee_id", employee.id).eq("approved", true).lte("effective_from", today).or(`effective_to.is.null,effective_to.gte.${today}`),
    admin.from("eco_team_members").select("team_id").eq("employee_id", employee.id).lte("effective_from", today).or(`effective_to.is.null,effective_to.gte.${today}`),
    supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
  ]);
  const roles = [...new Set((assignments ?? []).map((row) => row.role_code))];
  if (!roles.length) return null;
  const { data: permissionRows } = await admin.from("eco_role_permissions").select("permission_code").in("role_code", roles);
  const mfaVerified = assurance.data?.currentLevel === "aal2";
  return {
    userId: user.id,
    employeeId: employee.id,
    name: employee.full_name,
    email: employee.email,
    roles,
    permissions: [...new Set((permissionRows ?? []).map((row) => row.permission_code))],
    teamIds: [...new Set((teams ?? []).map((row) => row.team_id))],
    mfaVerified,
  };
});

export async function requirePrincipal() {
  const principal = await getCurrentPrincipal();
  if (!principal) throw new AppError("UNAUTHENTICATED", "تسجيل الدخول مطلوب.", 401);
  if (principal.roles.some((role) => privilegedMfaRoles.has(role)) && !principal.mfaVerified) {
    throw new AppError("FORBIDDEN", "يجب تفعيل التحقق بخطوتين لهذا الدور.", 403, { reason: "MFA_REQUIRED" });
  }
  return principal;
}

export async function requirePermission(permission: string) {
  const principal = await requirePrincipal();
  if (!principal.permissions.includes(permission) && !principal.permissions.includes("*")) {
    throw new AppError("FORBIDDEN", "ليس لديك صلاحية لتنفيذ هذا الإجراء.", 403);
  }
  return principal;
}

export async function protectPage(permission: string) {
  try { return await requirePermission(permission); }
  catch (cause) {
    if (cause instanceof AppError && cause.code === "UNAUTHENTICATED") redirect("/login");
    if (cause instanceof AppError && cause.details && typeof cause.details === "object" && "reason" in cause.details) redirect("/security/mfa");
    redirect("/forbidden");
  }
}
