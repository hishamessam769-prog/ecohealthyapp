import { apiError, ok, parseJson } from "@/lib/api";
import { requirePermission } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

export async function POST(request: Request) {
  try {
    const principal = await requirePermission("payment_proofs.upload");
    const body = await parseJson(request) as { storagePath?: string };
    if (!body.storagePath) throw new AppError("VALIDATION", "مسار الملف مطلوب.", 422);
    const { data, error } = await createAdminClient().rpc("eco_complete_payment_proof", {
      p_actor_id: principal.employeeId,
      p_storage_path: body.storagePath,
    });
    if (error) throw new AppError("VALIDATION", error.message, 422);
    return ok(data);
  } catch (cause) { return apiError(cause, { route: "payment_proof_complete" }); }
}
