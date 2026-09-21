"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { getViewer } from "@/lib/auth/viewer";
import { createAdminClient } from "@/lib/supabase/admin";

const schema = z.object({
  workflow: z.enum(["project", "task", "lead", "customer", "complaint", "payment", "session", "notification"]),
  title: z.string().trim().min(2).max(160),
  details: z.string().trim().max(1000).optional(),
  value: z.string().trim().max(120).optional(),
  priority: z.enum(["normal", "high", "critical"]).default("normal"),
});

const routes = {
  project: "/projects", task: "/tasks", lead: "/crm/leads", customer: "/crm/customers",
  complaint: "/complaints", payment: "/finance/payments", session: "/doctors/sessions", notification: "/notifications",
};
const permissions = {
  project: "projects.manage", task: "tasks.create", lead: "leads.manage", customer: "customers.manage",
  complaint: "complaints.manage", payment: "payments.submit", session: "sessions.create", notification: "notifications.view",
};

export async function erpWorkflowAction(formData: FormData) {
  const parsed = schema.safeParse({ workflow: formData.get("workflow"), title: formData.get("title"), details: formData.get("details"), value: formData.get("value"), priority: formData.get("priority") });
  if (!parsed.success) redirect("/dashboard?error=validation");
  const path = routes[parsed.data.workflow];
  const viewer = await getViewer();
  if (!viewer || !viewer.permissions.includes(permissions[parsed.data.workflow])) redirect(`${path}?error=permission`);
  if (viewer.preview) redirect(`${path}?saved=preview`);

  const admin = createAdminClient();
  const branchId = viewer.activeBranchId;
  if (!branchId && !["notification"].includes(parsed.data.workflow)) redirect(`${path}?error=branch`);
  const common = { organization_id: viewer.organizationId, branch_id: branchId, is_demo: false };
  let error: { message: string } | null = null;

  if (parsed.data.workflow === "project") {
    ({ error } = await admin.from("projects").insert({ ...common, name: parsed.data.title, description: parsed.data.details || null, owner_user_id: viewer.id, status: "active", priority: parsed.data.priority, created_by: viewer.id }));
  } else if (parsed.data.workflow === "task") {
    const dueAt = parsed.data.value ? new Date(parsed.data.value) : null;
    const taskResult = await admin.from("tasks").insert({ ...common, title: parsed.data.title, detailed_description: parsed.data.details || null, task_type: dueAt && !Number.isNaN(dueAt.getTime()) ? "task" : "open_task", status: "assigned", priority: parsed.data.priority, due_at: dueAt && !Number.isNaN(dueAt.getTime()) ? dueAt.toISOString() : null, open_until_response: !dueAt, response_required: true, created_by: viewer.id }).select("id").single();
    error = taskResult.error;
    if (!error && taskResult.data) ({ error } = await admin.from("task_assignments").insert({ organization_id: viewer.organizationId, task_id: taskResult.data.id, assignee_type: "user", assignee_user_id: viewer.id, assigned_by: viewer.id }));
  } else if (parsed.data.workflow === "lead") {
    ({ error } = await admin.from("leads").insert({ ...common, full_name: parsed.data.title, mobile: parsed.data.value || null, source: parsed.data.details || "Manual", status: "new", assigned_user_id: viewer.id, created_by: viewer.id }));
  } else if (parsed.data.workflow === "customer") {
    ({ error } = await admin.from("customers").insert({ organization_id: viewer.organizationId, home_branch_id: branchId, full_name: parsed.data.title, mobile: parsed.data.value || null, status: "active", owner_user_id: viewer.id, created_by: viewer.id }));
  } else if (parsed.data.workflow === "complaint") {
    const [{ data: customer }, { data: category }] = await Promise.all([
      admin.from("customers").select("id").eq("organization_id", viewer.organizationId).limit(1).maybeSingle(),
      admin.from("complaint_categories").select("id").eq("organization_id", viewer.organizationId).limit(1).maybeSingle(),
    ]);
    if (!customer) redirect(`${path}?error=customer`);
    ({ error } = await admin.from("complaints").insert({ ...common, customer_id: customer.id, category_id: category?.id || null, reason: parsed.data.title, details: parsed.data.details || null, severity: parsed.data.priority, status: "open", owner_user_id: viewer.id, due_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), created_by: viewer.id }));
  } else if (parsed.data.workflow === "payment") {
    const { data: invoice } = await admin.from("invoices").select("id, customer_id, total_amount, currency").eq("organization_id", viewer.organizationId).in("status", ["issued", "partially_paid"]).limit(1).maybeSingle();
    if (!invoice) redirect(`${path}?error=invoice`);
    const amount = Number(parsed.data.value || invoice.total_amount);
    if (!Number.isFinite(amount) || amount <= 0) redirect(`${path}?error=amount`);
    ({ error } = await admin.from("payment_submissions").insert({ ...common, customer_id: invoice.customer_id, invoice_id: invoice.id, claimed_amount: amount, currency: invoice.currency, payment_method: "manual", proof_reference: parsed.data.details || `manual-${Date.now()}`, status: "pending", submitted_by: viewer.id }));
  } else if (parsed.data.workflow === "session") {
    const [{ data: customer }, { data: serviceVersion }] = await Promise.all([
      admin.from("customers").select("id").eq("organization_id", viewer.organizationId).limit(1).maybeSingle(),
      admin.from("doctor_service_versions").select("id, duration_minutes").eq("status", "active").limit(1).maybeSingle(),
    ]);
    if (!customer || !serviceVersion) redirect(`${path}?error=prerequisite`);
    const start = parsed.data.value ? new Date(parsed.data.value) : new Date(Date.now() + 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime())) redirect(`${path}?error=date`);
    const end = new Date(start.getTime() + serviceVersion.duration_minutes * 60 * 1000);
    const sessionResult = await admin.from("doctor_sessions").insert({ ...common, customer_id: customer.id, service_version_id: serviceVersion.id, delivery_mode: "online", status: "requested", scheduled_start: start.toISOString(), scheduled_end: end.toISOString(), brief_reason: parsed.data.details || parsed.data.title, created_by: viewer.id }).select("id").single();
    error = sessionResult.error;
    if (!error && sessionResult.data) await admin.rpc("assign_session_round_robin", { p_session_id: sessionResult.data.id, p_actor_user_id: viewer.id });
  } else {
    ({ error } = await admin.from("notification_messages").insert({ organization_id: viewer.organizationId, branch_id: branchId || null, recipient_user_id: viewer.id, channel: "in_app", subject: parsed.data.title, body: parsed.data.details || parsed.data.title, status: "queued", idempotency_key: `manual:${viewer.id}:${Date.now()}` }));
  }

  if (error) redirect(`${path}?error=save`);
  revalidatePath(path);
  redirect(`${path}?saved=1`);
}
