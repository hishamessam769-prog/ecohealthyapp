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

export async function createCustomerQuotationAction(formData: FormData) {
  const path = "/sales";
  const viewer = await actor("sales.quote", path);
  const parsed = z.object({
    branchId: uuid,
    customerName: z.string().trim().min(2).max(160),
    mobile: z.string().trim().max(40).optional(),
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
  const supabase = await createClient();
  const { error } = await supabase.rpc("create_customer_quotation", {
    p_branch_id: parsed.data.branchId, p_customer_name: parsed.data.customerName, p_mobile: parsed.data.mobile || "",
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

export async function requestRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.request", path);
  const parsed = z.object({ invoiceId: uuid, subscriptionId: z.union([uuid, z.literal("")]), amount: z.coerce.number().positive(), reason: z.string().trim().min(3).max(500) }).safeParse({ invoiceId: formData.get("invoiceId"), subscriptionId: formData.get("subscriptionId") || "", amount: formData.get("amount"), reason: formData.get("reason") });
  if (!parsed.success) fail(path, "refund-validation");
  const supabase = await createClient();
  const { error } = await supabase.rpc("request_refund", { p_invoice_id: parsed.data.invoiceId, p_subscription_id: parsed.data.subscriptionId || null, p_amount: parsed.data.amount, p_reason: parsed.data.reason, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=refund-requested`);
}

export async function approveRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.approve", path);
  const refundId = uuid.safeParse(formData.get("refundId"));
  if (!refundId.success) fail(path, "refund");
  const supabase = await createClient();
  const { error } = await supabase.rpc("approve_refund", { p_refund_id: refundId.data, p_actor_user_id: viewer.id });
  if (error) fail(path, error.message);
  revalidatePath(path);
  redirect(`${path}?saved=refund-approved`);
}

export async function payRefundAction(formData: FormData) {
  const path = "/finance/payments";
  const viewer = await actor("refunds.approve", path);
  const parsed = z.object({ refundId: uuid, proofReference: z.string().trim().min(3).max(1000) }).safeParse({ refundId: formData.get("refundId"), proofReference: formData.get("proofReference") });
  if (!parsed.success) fail(path, "refund-proof");
  const supabase = await createClient();
  const { error } = await supabase.rpc("pay_refund_and_clawback", { p_refund_id: parsed.data.refundId, p_actor_user_id: viewer.id, p_proof_reference: parsed.data.proofReference, p_idempotency_key: `refund:${parsed.data.refundId}:${crypto.randomUUID()}` });
  if (error) fail(path, error.message);
  revalidatePath(path); revalidatePath("/sales/invoices"); revalidatePath("/performance");
  redirect(`${path}?saved=refund-paid`);
}
