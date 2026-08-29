import { randomUUID } from "node:crypto";
import { z } from "zod";
import { apiError, ok, parseJson } from "@/lib/api";
import { requirePermission } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

const schema = z.object({ fileName: z.string().min(1).max(180), mimeType: z.enum(["image/jpeg", "image/png", "application/pdf"]), sizeBytes: z.number().int().positive().max(10 * 1024 * 1024), sha256: z.string().regex(/^[a-f0-9]{64}$/), invoiceId: z.string().uuid() });

export async function POST(request: Request) {
  try {
    const principal = await requirePermission("payment_proofs.upload");
    const parsed = schema.safeParse(await parseJson(request));
    if (!parsed.success) throw new AppError("VALIDATION", "نوع أو حجم ملف إثبات الدفع غير مسموح.", 422, parsed.error.flatten());
    const admin = createAdminClient();
    const path = `${parsed.data.invoiceId}/${randomUUID()}-${parsed.data.fileName.replace(/[^a-zA-Z0-9._-]/g, "_")}`;
    const { data, error } = await admin.storage.from("payment-proofs").createSignedUploadUrl(path);
    if (error) throw new AppError("INTERNAL", "تعذر تجهيز رفع الملف.", 500);
    await admin.from("eco_payment_proofs").insert({ invoice_id: parsed.data.invoiceId, storage_path: path, original_name: parsed.data.fileName, mime_type: parsed.data.mimeType, size_bytes: parsed.data.sizeBytes, sha256: parsed.data.sha256, uploaded_by: principal.employeeId, status: "PENDING_UPLOAD" });
    return ok({ storagePath: path, token: data.token, signedUrl: data.signedUrl }, 201);
  } catch (cause) { return apiError(cause, { route: "payment_proof_upload" }); }
}
