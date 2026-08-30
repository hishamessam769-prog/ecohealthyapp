import { createHash, randomUUID } from "node:crypto";
import { z } from "zod";
import type { Principal } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";
import { createCustomerSchema, createInvoiceSchema, createLeadSchema, deliveryEventSchema, subscriptionChangeSchema, verifyPaymentSchema } from "@/lib/validators";

type CommandDefinition = { permission: string; schema: z.ZodType; execute: (payload: Record<string, unknown>, principal: Principal) => Promise<unknown> };

async function rpc(name: string, args: Record<string, unknown>) {
  const { data, error } = await createAdminClient().rpc(name, args);
  if (error) throw new AppError(error.code === "23505" ? "CONFLICT" : "VALIDATION", error.message, error.code === "23505" ? 409 : 422, { databaseCode: error.code });
  return data;
}

const genericIdempotency = z.object({ idempotency_key: z.string().min(8).max(120) }).passthrough();

export const commands: Record<string, CommandDefinition> = {
  create_lead: {
    permission: "crm.lead.create", schema: createLeadSchema,
    execute: async (payload, principal) => {
      const data = createLeadSchema.parse(payload);
      const { data: row, error } = await createAdminClient().from("eco_leads").insert({ ...data, assigned_employee_id: principal.employeeId, created_by: principal.employeeId }).select("id,lead_number").single();
      if (error) throw new AppError("VALIDATION", error.message, 422);
      return row;
    },
  },
  create_customer: {
    permission: "customers.create", schema: createCustomerSchema,
    execute: async (payload, principal) => rpc("eco_create_customer", { p_actor_id: principal.employeeId, p_payload: createCustomerSchema.parse(payload) }),
  },
  create_invoice: {
    permission: "orders.create", schema: createInvoiceSchema,
    execute: async (payload, principal) => rpc("eco_create_sales_invoice", { p_actor_id: principal.employeeId, p_payload: createInvoiceSchema.parse(payload) }),
  },
  verify_payment: {
    permission: "payments.verify", schema: verifyPaymentSchema,
    execute: async (payload, principal) => rpc("eco_confirm_payment", { p_actor_id: principal.employeeId, p_payload: verifyPaymentSchema.parse(payload) }),
  },
  reject_payment: {
    permission: "payments.verify", schema: genericIdempotency.extend({ payment_id: z.string().uuid(), reason: z.string().min(3).max(1000) }),
    execute: async (payload, principal) => rpc("eco_reject_payment", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  preview_subscription_change: {
    permission: "subscriptions.change.preview", schema: subscriptionChangeSchema,
    execute: async (payload, principal) => rpc("eco_preview_subscription_change", { p_actor_id: principal.employeeId, p_payload: subscriptionChangeSchema.parse(payload) }),
  },
  commit_subscription_change: {
    permission: "subscriptions.change.commit", schema: subscriptionChangeSchema,
    execute: async (payload, principal) => rpc("eco_commit_subscription_change", { p_actor_id: principal.employeeId, p_payload: subscriptionChangeSchema.parse(payload) }),
  },
  request_cancellation: {
    permission: "subscriptions.change.preview", schema: genericIdempotency.extend({ subscription_id: z.string().uuid(), reason: z.string().min(3).max(1000) }),
    execute: async (payload, principal) => rpc("eco_request_cancellation", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  review_cancellation: {
    permission: "payments.verify", schema: genericIdempotency.extend({ cancellation_id: z.string().uuid(), approved: z.enum(["true", "false"]).transform((value) => value === "true"), review_note: z.string().max(1000).optional() }),
    execute: async (payload, principal) => rpc("eco_review_cancellation", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  create_production_batch: {
    permission: "kitchen.batch.create", schema: genericIdempotency.extend({ service_date: z.string().date(), demand_ids: z.array(z.string().uuid()).min(1) }),
    execute: async (payload, principal) => rpc("eco_create_production_batch", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  release_qa: {
    permission: "kitchen.qa.release", schema: genericIdempotency.extend({ batch_id: z.string().uuid(), result: z.enum(["PASSED", "FAILED"]), temperature_c: z.coerce.number().min(-20).max(120), notes: z.string().max(1000).optional() }),
    execute: async (payload, principal) => rpc("eco_release_batch_qa", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  create_route: {
    permission: "routes.manage", schema: genericIdempotency.extend({ route_date: z.string().date(), zone_id: z.string().uuid(), delivery_window_id: z.string().uuid(), rider_employee_id: z.string().uuid().optional() }),
    execute: async (payload, principal) => rpc("eco_create_route", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  dispatch_route: {
    permission: "routes.manage", schema: genericIdempotency.extend({ route_id: z.string().uuid() }),
    execute: async (payload, principal) => rpc("eco_dispatch_route", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  delivery_event: {
    permission: "route.own.update", schema: deliveryEventSchema,
    execute: async (payload, principal) => rpc("eco_record_delivery_event", { p_actor_id: principal.employeeId, p_payload: deliveryEventSchema.parse(payload) }),
  },
  declare_cash: {
    permission: "cash.rider.declare", schema: genericIdempotency.extend({ route_id: z.string().uuid(), amount: z.union([z.string(), z.number()]).transform(String), notes: z.string().max(1000).optional() }),
    execute: async (payload, principal) => rpc("eco_declare_rider_cash", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  receive_cash: {
    permission: "cash.accounting.receive", schema: genericIdempotency.extend({ handover_id: z.string().uuid(), amount_received: z.union([z.string(), z.number()]).transform(String), difference_reason: z.string().max(1000).optional() }),
    execute: async (payload, principal) => rpc("eco_receive_cash_handover", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  save_target: {
    permission: "targets.manage", schema: genericIdempotency.extend({ scope_type: z.enum(["COMPANY", "TEAM", "EMPLOYEE"]), scope_id: z.string().uuid().optional().or(z.literal("")), period_start: z.string().date(), revenue_target: z.union([z.string(), z.number()]).transform(String), quantity_target: z.preprocess((value) => value === "" ? undefined : value, z.coerce.number().int().nonnegative().optional()), status: z.enum(["DRAFT", "APPROVED"]).default("DRAFT") }),
    execute: async (payload, principal) => rpc("eco_save_sales_target", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  save_catalog_price: {
    permission: "catalog.manage",
    schema: genericIdempotency.extend({ program_code: z.enum(["WEIGHT_LOSS", "MUSCLE_GAIN"]), package_type_code: z.enum(["LUNCH_ONLY", "AM", "BM", "FULL_DAY"]), service_days: z.coerce.number().int().refine((value) => [6, 12, 18, 24].includes(value)), size_code: z.enum(["REGULAR", "HERO"]), price: z.union([z.string(), z.number()]).transform(String), tax_rate: z.coerce.number().min(0).max(100).default(0), effective_from: z.string().date() }),
    execute: async (payload, principal) => rpc("eco_save_catalog_price", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  save_sales_policy: {
    permission: "catalog.manage",
    schema: genericIdempotency.extend({ max_sales_discount_percentage: z.coerce.number().min(0).max(100) }),
    execute: async (payload, principal) => rpc("eco_save_sales_policy", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  save_commission_plan: {
    permission: "commissions.manage", schema: genericIdempotency.extend({ plan_name: z.string().min(3), sale_type: z.string(), effective_from: z.string().date(), effective_to: z.preprocess((value) => value === "" ? undefined : value, z.string().date().optional()), maturity_rule: z.string(), fixed_maturity_days: z.coerce.number().int().nonnegative(), minimum_fulfilled_percentage: z.coerce.number().min(0).max(100), month_end_minimum_hold_days: z.coerce.number().int().nonnegative(), manager_gate_percentage: z.preprocess((value) => value === "" ? undefined : value, z.coerce.number().min(0).max(100).optional()), tiers: z.array(z.object({ min_percentage: z.coerce.number().min(0), max_percentage: z.coerce.number().positive().optional(), rate_percentage: z.coerce.number().min(0).max(100), fixed_bonus: z.coerce.number().nonnegative().default(0) })).min(1) }),
    execute: async (payload, principal) => rpc("eco_save_commission_plan", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  save_menu_day: {
    permission: "menu.manage", schema: genericIdempotency.extend({ service_date: z.string().date(), slot_code: z.string(), meal_version_id: z.string().uuid(), quantity: z.coerce.number().positive().default(1) }),
    execute: async (payload, principal) => rpc("eco_save_menu_day", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  receive_inventory: {
    permission: "inventory.receive", schema: genericIdempotency.extend({ purchase_order_id: z.string().uuid(), supplier_reference: z.string().min(2), lines: z.array(z.object({ ingredient_id: z.string().uuid(), quantity: z.union([z.string(), z.number()]).transform(String), unit_cost: z.union([z.string(), z.number()]).transform(String), lot_number: z.string(), expiry_date: z.string().date() })).min(1) }),
    execute: async (payload, principal) => rpc("eco_receive_inventory", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  mark_notification_read: {
    permission: "notifications.read", schema: z.object({ notification_id: z.string().uuid() }),
    execute: async (payload, principal) => rpc("eco_mark_notification_read", { p_actor_id: principal.employeeId, p_notification_id: payload.notification_id }),
  },
  add_notification_comment: {
    permission: "notifications.read", schema: z.object({ notification_id: z.string().uuid(), body: z.string().min(1).max(2000) }),
    execute: async (payload, principal) => rpc("eco_add_notification_comment", { p_actor_id: principal.employeeId, p_payload: payload }),
  },
  purge_demo_data: {
    permission: "system.demo.manage", schema: z.object({ confirmation: z.literal("PURGE_DEMO"), idempotency_key: z.string().min(8) }),
    execute: async (payload, principal) => rpc("eco_purge_demo_data", { p_actor_id: principal.employeeId, p_idempotency_key: payload.idempotency_key }),
  },
  install_demo_data: {
    permission: "system.demo.manage", schema: z.object({ confirmation: z.literal("INSTALL_DEMO") }),
    execute: async (_payload, principal) => {
      const base = await rpc("eco_install_demo_data", { p_actor_id: principal.employeeId });
      const full = await rpc("eco_enrich_demo_data", { p_actor_id: principal.employeeId });
      const history = await rpc("eco_seed_ten_day_demo", { p_actor_id: principal.employeeId });
      return { base, full, history };
    },
  },
};

export async function executeCommand(name: string, raw: unknown, principal: Principal) {
  const command = commands[name];
  if (!command) throw new AppError("NOT_FOUND", "الأمر غير موجود.", 404);
  if (!principal.permissions.includes(command.permission) && !principal.permissions.includes("*")) throw new AppError("FORBIDDEN", "ليس لديك صلاحية لتنفيذ هذا الأمر.", 403);
  const parsed = command.schema.safeParse(raw);
  if (!parsed.success) throw new AppError("VALIDATION", "راجع البيانات المطلوبة.", 422, parsed.error.flatten());
  return command.execute(parsed.data as Record<string, unknown>, principal);
}

export function webhookDigest(rawBody: string, secret: string) {
  return createHash("sha256").update(`${secret}.${rawBody}`).digest("hex");
}

export function commandIdempotencyKey(prefix: string) {
  return `${prefix}-${randomUUID()}`;
}
