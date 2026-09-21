"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { getViewer } from "@/lib/auth/viewer";
import { createClient } from "@/lib/supabase/server";

const uuid = z.string().uuid();

async function actor(permission: string, returnPath: string) {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  if (!viewer.permissions.includes(permission)) redirect(`${returnPath}?error=permission`);
  if (viewer.preview) redirect(`${returnPath}?saved=preview`);
  return viewer;
}

function fail(path: string, code: string): never {
  redirect(`${path}?error=${encodeURIComponent(code)}`);
}

function normalizeEgyptMobile(value: string) {
  let digits = value.replace(/\D/g, "");
  if (digits.startsWith("0020")) digits = digits.slice(4);
  if (digits.startsWith("20") && digits.length === 12) digits = digits.slice(2);
  if (digits.startsWith("1") && digits.length === 10) digits = `0${digits}`;
  return /^01(?:0|1|2|5)\d{8}$/.test(digits) ? digits : null;
}

export async function createCustomerDeliveryProfileAction(formData: FormData) {
  const path = "/crm/customers";
  const viewer = await actor("customers.manage", path);
  const parsed = z.object({
    branchId: uuid, fullName: z.string().trim().min(2).max(160), mobile: z.string().trim().min(8).max(40),
    email: z.union([z.string().trim().email(), z.literal("")]), addressLine: z.string().trim().min(8).max(500),
    area: z.string().trim().min(2).max(120), city: z.string().trim().min(2).max(120), latitude: z.coerce.number().min(-90).max(90),
    longitude: z.coerce.number().min(-180).max(180), gpsUrl: z.string().trim().url().max(1000), zoneId: uuid,
    deliveryNotes: z.string().trim().max(1000).optional(), deliveryWindowStart: z.string().regex(/^\d{2}:\d{2}$/),
    deliveryWindowEnd: z.string().regex(/^\d{2}:\d{2}$/), deliveryContactName: z.string().trim().max(160).optional(),
    deliveryContactMobile: z.string().trim().max(40).optional(), confirmed: z.literal("yes"),
  }).safeParse({
    branchId: formData.get("branchId"), fullName: formData.get("fullName"), mobile: formData.get("mobile"), email: formData.get("email") || "",
    addressLine: formData.get("addressLine"), area: formData.get("area"), city: formData.get("city"), latitude: formData.get("latitude"),
    longitude: formData.get("longitude"), gpsUrl: formData.get("gpsUrl"), zoneId: formData.get("zoneId"), deliveryNotes: formData.get("deliveryNotes"),
    deliveryWindowStart: formData.get("deliveryWindowStart"), deliveryWindowEnd: formData.get("deliveryWindowEnd"),
    deliveryContactName: formData.get("deliveryContactName"), deliveryContactMobile: formData.get("deliveryContactMobile"), confirmed: formData.get("confirmed"),
  });
  if (!parsed.success) fail(path, "customer-delivery-validation");
  const mobile = normalizeEgyptMobile(parsed.data.mobile);
  const deliveryContactMobile = parsed.data.deliveryContactMobile ? normalizeEgyptMobile(parsed.data.deliveryContactMobile) : mobile;
  if (!mobile || !deliveryContactMobile) fail(path, "egypt-mobile-invalid");
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_customer_delivery_profile", {
    p_branch_id: parsed.data.branchId, p_full_name: parsed.data.fullName, p_mobile: mobile, p_email: parsed.data.email,
    p_address_line: parsed.data.addressLine, p_area: parsed.data.area, p_city: parsed.data.city, p_latitude: parsed.data.latitude,
    p_longitude: parsed.data.longitude, p_gps_url: parsed.data.gpsUrl, p_zone_id: parsed.data.zoneId, p_delivery_notes: parsed.data.deliveryNotes || "",
    p_delivery_window_start: parsed.data.deliveryWindowStart, p_delivery_window_end: parsed.data.deliveryWindowEnd,
    p_delivery_contact_name: parsed.data.deliveryContactName || parsed.data.fullName,
    p_delivery_contact_mobile: deliveryContactMobile, p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=customer-created`);
}

export async function createCustomerQuotationAction(formData: FormData) {
  const path = "/sales";
  const viewer = await actor("sales.quote", path);
  const parsed = z.object({
    branchId: uuid,
    customerName: z.string().trim().min(2).max(160),
    mobile: z.string().trim().min(10).max(40),
    packageVersionId: uuid,
    quantity: z.coerce.number().positive().max(999),
    discountPercent: z.coerce.number().min(0).max(100),
    validUntil: z.coerce.date(),
    notes: z.string().trim().max(1000).optional(),
  }).safeParse({
    branchId: formData.get("branchId"), customerName: formData.get("customerName"), mobile: formData.get("mobile"),
    packageVersionId: formData.get("packageVersionId"), quantity: formData.get("quantity"),
    discountPercent: formData.get("discountPercent"), validUntil: formData.get("validUntil"), notes: formData.get("notes"),
  });
  if (!parsed.success) fail(path, "validation");
  const mobile = normalizeEgyptMobile(parsed.data.mobile);
  if (!mobile) fail(path, "egypt-mobile-invalid");
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_customer_quotation", {
    p_branch_id: parsed.data.branchId, p_customer_name: parsed.data.customerName, p_mobile: mobile,
    p_package_version_id: parsed.data.packageVersionId, p_quantity: parsed.data.quantity,
    p_discount_percent: parsed.data.discountPercent, p_valid_until: parsed.data.validUntil.toISOString().slice(0, 10),
    p_notes: parsed.data.notes || "", p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=quotation`);
}

export async function acceptQuotationAction(formData: FormData) {
  const path = "/sales";
  const viewer = await actor("sales.quote", path);
  const quotationId = uuid.safeParse(formData.get("quotationId"));
  if (!quotationId.success) fail(path, "quotation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("accept_quotation", { p_quotation_id: quotationId.data, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=accepted`);
}

export async function convertQuotationAction(formData: FormData) {
  const path = "/sales";
  const viewer = await actor("sales.invoice", path);
  const quotationId = uuid.safeParse(formData.get("quotationId"));
  if (!quotationId.success) fail(path, "quotation");
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("convert_quotation_to_invoice", { p_quotation_id: quotationId.data, p_actor_user_id: viewer.id });
  if (error || !data) fail(path, error?.message || "invoice");
  revalidatePath(path);
  redirect(`/sales/invoices/${data}`);
}

export async function submitPaymentProofAction(formData: FormData) {
  const path = "/sales/invoices";
  const viewer = await actor("payments.submit", path);
  const parsed = z.object({
    invoiceId: uuid,
    amount: z.coerce.number().positive(),
    paymentMethod: z.string().trim().min(2).max(80),
    externalReference: z.string().trim().max(160).optional(),
    proofReference: z.string().trim().max(1000).optional(),
  }).safeParse({
    invoiceId: formData.get("invoiceId"), amount: formData.get("amount"), paymentMethod: formData.get("paymentMethod"),
    externalReference: formData.get("externalReference"), proofReference: formData.get("proofReference"),
  });
  if (!parsed.success) fail(path, "validation");
  const supabase = await createClient();
  const proof = formData.get("proofFile");
  let storagePath = parsed.data.proofReference || "";
  if (proof instanceof File && proof.size > 0) {
    if (proof.size > 20 * 1024 * 1024) fail(path, "proof-too-large");
    const safeName = proof.name.replace(/[^a-zA-Z0-9._-]/g, "-").slice(-100);
    storagePath = `${viewer.organizationId}/payment-proofs/${viewer.id}/${crypto.randomUUID()}-${safeName}`;
    const { error: uploadError } = await supabase.storage.from("erp-attachments").upload(storagePath, proof, { contentType: proof.type || "application/octet-stream", upsert: false });
    if (uploadError) fail(path, uploadError.message);
  }
  if (!storagePath) fail(path, "proof-required");
  const { error } = await supabase.rpc("submit_payment_proof", {
    p_invoice_id: parsed.data.invoiceId, p_claimed_amount: parsed.data.amount,
    p_payment_method: parsed.data.paymentMethod, p_proof_reference: storagePath,
    p_external_reference: parsed.data.externalReference || "", p_actor_user_id: viewer.id,
  });
  if (error) {
    if (proof instanceof File && proof.size > 0) await supabase.storage.from("erp-attachments").remove([storagePath]);
    fail(path, error.message);
  }
  revalidatePath(path);
  revalidatePath("/finance/payments");
  redirect(`${path}?saved=payment-pending`);
}

export async function confirmPaymentAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("payments.confirm", path);
  const parsed = z.object({ submissionId: uuid, amount: z.coerce.number().positive(), fullAmount: z.coerce.number().positive(), mode: z.enum(["partial", "full"]).default("partial") }).safeParse({ submissionId: formData.get("submissionId"), amount: formData.get("amount"), fullAmount: formData.get("fullAmount"), mode: formData.get("mode") || "partial" });
  if (!parsed.success) fail(path, "validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("confirm_payment_submission", {
    p_submission_id: parsed.data.submissionId, p_confirmed_amount: parsed.data.mode === "full" ? parsed.data.fullAmount : parsed.data.amount,
    p_actor_user_id: viewer.id, p_idempotency_key: `finance:${parsed.data.submissionId}:${crypto.randomUUID()}`,
  });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/sales/invoices"); revalidatePath("/performance");
  redirect(`${path}?saved=confirmed`);
}

export async function rejectPaymentAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("payments.review", path);
  const parsed = z.object({ submissionId: uuid, reason: z.string().trim().min(3).max(500) }).safeParse({ submissionId: formData.get("submissionId"), reason: formData.get("reason") });
  if (!parsed.success) fail(path, "reason-required");
  const supabase = await createClient();
  const { error } = await supabase.rpc("reject_payment_submission", { p_submission_id: parsed.data.submissionId, p_reason: parsed.data.reason, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=rejected`);
}

export async function activateSubscriptionAction(formData: FormData) {
  const path = "/subscriptions";
  const viewer = await actor("subscriptions.manage", path);
  const parsed = z.object({ invoiceId: uuid, packageVersionId: uuid, startsOn: z.coerce.date() }).safeParse({ invoiceId: formData.get("invoiceId"), packageVersionId: formData.get("packageVersionId"), startsOn: formData.get("startsOn") });
  if (!parsed.success) fail(path, "validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_activate_subscription_from_invoice", {
    p_invoice_id: parsed.data.invoiceId, p_package_version_id: parsed.data.packageVersionId,
    p_starts_on: parsed.data.startsOn.toISOString().slice(0, 10), p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/operations/subscribers");
  redirect(`${path}?saved=activated`);
}

export async function confirmDeliveryAction(formData: FormData) {
  const path = "/operations/subscribers";
  const viewer = await actor("service.confirm_delivery", path);
  const dayId = uuid.safeParse(formData.get("dayId"));
  if (!dayId.success) fail(path, "day");
  const supabase = await createClient();
  const { error } = await supabase.rpc("confirm_service_delivery", { p_planned_day_id: dayId.data, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/subscriptions");
  redirect(`${path}?saved=delivered`);
}

export async function freezeSubscriptionAction(formData: FormData) {
  const path = "/subscriptions";
  const viewer = await actor("subscriptions.operate_daily", path);
  const parsed = z.object({ subscriptionId: uuid, startsOn: z.coerce.date(), endsOn: z.coerce.date(), reason: z.string().trim().min(3).max(500), confirm: z.literal("yes") }).safeParse({
    subscriptionId: formData.get("subscriptionId"), startsOn: formData.get("startsOn"), endsOn: formData.get("endsOn"), reason: formData.get("reason"), confirm: formData.get("confirm"),
  });
  if (!parsed.success || parsed.data.endsOn < parsed.data.startsOn) fail(path, "freeze-validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("freeze_subscription_period", {
    p_subscription_id: parsed.data.subscriptionId, p_starts_on: parsed.data.startsOn.toISOString().slice(0, 10),
    p_ends_on: parsed.data.endsOn.toISOString().slice(0, 10), p_reason: parsed.data.reason, p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/operations/subscribers");
  redirect(`${path}?saved=frozen`);
}

export async function applyServiceDayBulkAction(formData: FormData) {
  const path = "/operations/subscribers";
  const operation = z.enum(["skip", "set_portions", "confirm_delivered"]).safeParse(formData.get("operation"));
  if (!operation.success) fail(path, "operation");
  const permission = operation.data === "confirm_delivered" ? "service.confirm_delivery" : "subscriptions.operate_daily";
  const viewer = await actor(permission, path);
  const parsed = z.object({ dayIds: z.array(uuid).min(1).max(100), portions: z.coerce.number().int().min(1).max(20).default(1), reason: z.string().trim().max(500).optional(), confirm: z.literal("yes") }).safeParse({
    dayIds: formData.getAll("dayIds"), portions: formData.get("portions") || 1, reason: formData.get("reason"), confirm: formData.get("confirm"),
  });
  if (!parsed.success || (operation.data === "skip" && !parsed.data.reason)) fail(path, "daily-action-validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("apply_service_day_action", { p_day_ids: parsed.data.dayIds, p_action: operation.data, p_portions: parsed.data.portions, p_reason: parsed.data.reason || "", p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/subscriptions");
  redirect(`${path}?saved=${operation.data}`);
}

export async function requestCalculatedRefundAction(formData: FormData) {
  const path = "/subscriptions";
  const viewer = await actor("refunds.request", path);
  const parsed = z.object({
    subscriptionId: uuid, reasonCode: z.string().trim().min(2).max(80), reasonDetails: z.string().trim().max(500).optional(),
    recipientMethod: z.enum(["instapay", "mobile_wallet", "bank_transfer"]), recipientAccountName: z.string().trim().min(2).max(160),
    recipientAccountReference: z.string().trim().min(3).max(160), confirm: z.literal("yes"),
  }).safeParse({
    subscriptionId: formData.get("subscriptionId"), reasonCode: formData.get("reasonCode"), reasonDetails: formData.get("reasonDetails"),
    recipientMethod: formData.get("recipientMethod"), recipientAccountName: formData.get("recipientAccountName"),
    recipientAccountReference: formData.get("recipientAccountReference"), confirm: formData.get("confirm"),
  });
  if (!parsed.success) fail(path, "refund-validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("request_calculated_subscription_refund", {
    p_subscription_id: parsed.data.subscriptionId, p_reason_code: parsed.data.reasonCode, p_reason_details: parsed.data.reasonDetails || "",
    p_recipient_method: parsed.data.recipientMethod, p_recipient_account_name: parsed.data.recipientAccountName,
    p_recipient_account_reference: parsed.data.recipientAccountReference, p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/finance/payments");
  redirect(`${path}?saved=refund-requested`);
}

export async function requestRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.request", path);
  const parsed = z.object({ invoiceId: uuid, subscriptionId: z.union([uuid, z.literal("")]), amount: z.coerce.number().positive(), reason: z.string().trim().min(3).max(500) }).safeParse({ invoiceId: formData.get("invoiceId"), subscriptionId: formData.get("subscriptionId") || "", amount: formData.get("amount"), reason: formData.get("reason") });
  if (!parsed.success) fail(path, "refund-validation");
  if (parsed.data.subscriptionId) fail(path, "use-subscription-refund-policy");
  const supabase = await createClient();
  const { error } = await supabase.rpc("request_refund", { p_invoice_id: parsed.data.invoiceId, p_subscription_id: parsed.data.subscriptionId || null, p_amount: parsed.data.amount, p_reason: parsed.data.reason, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=refund-requested`);
}

export async function approveRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.approve", path);
  const parsed = z.object({
    refundId: uuid,
    approvedDeduction: z.coerce.number().min(0),
    decisionReason: z.string().trim().max(500).optional(),
    confirm: z.string().optional(),
  }).safeParse({
    refundId: formData.get("refundId"), approvedDeduction: formData.get("approvedDeduction") || 0,
    decisionReason: formData.get("decisionReason"), confirm: formData.get("confirm"),
  });
  if (!parsed.success) fail(path, "refund-approval-validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("approve_subscription_refund_policy", {
    p_refund_id: parsed.data.refundId, p_approved_deduction: parsed.data.approvedDeduction,
    p_reason: parsed.data.decisionReason || "", p_actor_user_id: viewer.id,
  });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=refund-approved`);
}

export async function payRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.pay", path);
  const parsed = z.object({ refundId: uuid, proofReference: z.string().trim().min(3).max(1000), confirm: z.literal("yes") }).safeParse({ refundId: formData.get("refundId"), proofReference: formData.get("proofReference"), confirm: formData.get("confirm") });
  if (!parsed.success) fail(path, "refund-proof");
  const supabase = await createClient();
  const { error } = await supabase.rpc("pay_refund_and_clawback", { p_refund_id: parsed.data.refundId, p_actor_user_id: viewer.id, p_proof_reference: parsed.data.proofReference, p_idempotency_key: `refund:${parsed.data.refundId}:${crypto.randomUUID()}` });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/sales/invoices"); revalidatePath("/performance");
  redirect(`${path}?saved=refund-paid`);
}
