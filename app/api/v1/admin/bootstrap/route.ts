import { timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { apiError, ok, parseJson } from "@/lib/api";
import { AppError } from "@/lib/errors";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { enforceRateLimit } from "@/lib/rate-limit";

const schema = z.object({ secret: z.string(), email: z.string().email(), password: z.string().min(12), fullName: z.string().min(3) });

export async function POST(request: Request) {
  try {
    await enforceRateLimit("bootstrap", request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown", 5, 3600);
    const body = schema.parse(await parseJson(request));
    const expected = serverEnv().ADMIN_BOOTSTRAP_SECRET ?? "";
    if (!expected || body.secret.length !== expected.length || !timingSafeEqual(Buffer.from(body.secret), Buffer.from(expected))) throw new AppError("FORBIDDEN", "Bootstrap secret غير صحيح.", 403);
    const admin = createAdminClient();
    const { count } = await admin.from("eco_employees").select("id", { count: "exact", head: true });
    if ((count ?? 0) > 0) throw new AppError("CONFLICT", "تم إنشاء الإدارة الأولى بالفعل.", 409);
    const { data: auth, error } = await admin.auth.admin.createUser({ email: body.email, password: body.password, email_confirm: true, user_metadata: { full_name: body.fullName } });
    if (error || !auth.user) throw new AppError("VALIDATION", error?.message ?? "تعذر إنشاء المستخدم.", 422);
    const { data, error: dbError } = await admin.rpc("eco_bootstrap_first_admin", { p_auth_user_id: auth.user.id, p_email: body.email, p_full_name: body.fullName, p_secret_fingerprint: "server-validated" });
    if (dbError) throw dbError;
    return ok(data, 201);
  } catch (cause) { return apiError(cause, { route: "admin_bootstrap" }); }
}
