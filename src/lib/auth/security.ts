export type RoleAssignmentDecisionInput = {
  actorUserId: string;
  targetUserId: string;
  actorPermissions: string[];
  targetRolePermissions: string[];
  targetRoleCode: string;
};

export type SecurityDecision =
  | { allowed: true }
  | { allowed: false; reason: "missing_role_assignment" | "self_escalation" | "permission_escalation" | "sensitive_role" };

export function decideRoleAssignment(input: RoleAssignmentDecisionInput): SecurityDecision {
  const actorPermissions = new Set(input.actorPermissions);
  if (!actorPermissions.has("roles.assign")) {
    return { allowed: false, reason: "missing_role_assignment" };
  }
  if (input.actorUserId === input.targetUserId) {
    return { allowed: false, reason: "self_escalation" };
  }
  if (input.targetRolePermissions.some((permission) => !actorPermissions.has(permission))) {
    return { allowed: false, reason: "permission_escalation" };
  }
  if (input.targetRoleCode === "ceo_super_admin" && !actorPermissions.has("roles.assign_sensitive")) {
    return { allowed: false, reason: "sensitive_role" };
  }
  return { allowed: true };
}

export function canGrantPermission(actorPermissions: string[], permissionCode: string, actorHasTargetRole: boolean) {
  return actorPermissions.includes("roles.manage")
    && actorPermissions.includes(permissionCode)
    && !actorHasTargetRole;
}
