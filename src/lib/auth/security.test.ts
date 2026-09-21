import { describe, expect, it } from "vitest";
import { canGrantPermission, decideRoleAssignment } from "@/lib/auth/security";

const adminPermissions = ["roles.assign", "roles.assign_sensitive", "roles.manage", "users.view"];

describe("role assignment security", () => {
  it("requires roles.assign even when the actor can manage users", () => {
    expect(decideRoleAssignment({
      actorUserId: "actor",
      targetUserId: "target",
      actorPermissions: ["users.manage"],
      targetRolePermissions: [],
      targetRoleCode: "sales_representative",
    })).toEqual({ allowed: false, reason: "missing_role_assignment" });
  });

  it("prevents a user from assigning a role to themselves", () => {
    expect(decideRoleAssignment({
      actorUserId: "actor",
      targetUserId: "actor",
      actorPermissions: adminPermissions,
      targetRolePermissions: ["users.view"],
      targetRoleCode: "sales_manager",
    })).toEqual({ allowed: false, reason: "self_escalation" });
  });

  it("prevents assigning permissions the actor does not possess", () => {
    expect(decideRoleAssignment({
      actorUserId: "actor",
      targetUserId: "target",
      actorPermissions: ["roles.assign"],
      targetRolePermissions: ["finance.period_close"],
      targetRoleCode: "finance_manager",
    })).toEqual({ allowed: false, reason: "permission_escalation" });
  });

  it("requires the sensitive permission for CEO/Super Admin", () => {
    expect(decideRoleAssignment({
      actorUserId: "actor",
      targetUserId: "target",
      actorPermissions: ["roles.assign", "dashboard.view"],
      targetRolePermissions: ["dashboard.view"],
      targetRoleCode: "ceo_super_admin",
    })).toEqual({ allowed: false, reason: "sensitive_role" });
  });

  it("allows a governed assignment within the actor authority", () => {
    expect(decideRoleAssignment({
      actorUserId: "actor",
      targetUserId: "target",
      actorPermissions: adminPermissions,
      targetRolePermissions: ["users.view"],
      targetRoleCode: "sales_manager",
    })).toEqual({ allowed: true });
  });
});

describe("custom role permission security", () => {
  it("blocks adding a permission through a role already held by the actor", () => {
    expect(canGrantPermission(["roles.manage", "users.view"], "users.view", true)).toBe(false);
  });

  it("blocks a permission that the actor does not possess", () => {
    expect(canGrantPermission(["roles.manage"], "audit.view", false)).toBe(false);
  });

  it("allows granting an owned permission to an unrelated custom role", () => {
    expect(canGrantPermission(["roles.manage", "users.view"], "users.view", false)).toBe(true);
  });
});
