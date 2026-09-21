import { describe, expect, it } from "vitest";
import { can, type Viewer } from "@/lib/auth/viewer";

const viewer: Viewer = {
  id: "user-1",
  name: "Test User",
  email: "test@example.com",
  organizationId: "org-1",
  organizationName: "Eco Healthy",
  roleNames: ["Sales Representative"],
  permissions: ["dashboard.view", "notifications.view"],
  branches: [{ id: "branch-1", name: "Main", code: "MAIN" }],
  preview: false,
};

describe("permission checks", () => {
  it("allows an explicitly granted permission", () => {
    expect(can(viewer, "dashboard.view")).toBe(true);
  });

  it("does not infer authority from a role name", () => {
    expect(can(viewer, "payments.approve")).toBe(false);
  });

  it("denies a missing administrative permission", () => {
    expect(can(viewer, "users.manage")).toBe(false);
  });
});
