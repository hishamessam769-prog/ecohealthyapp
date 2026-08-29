import { timingSafeEqual } from "node:crypto";
import { apiError, ok } from "@/lib/api";
import { AppError } from "@/lib/errors";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";

const allowedJobs = new Set(["renewals", "auto-resume", "notifications", "commission-maturity", "kpi-snapshots", "outbox"]);

export async function POST(request: Request, context: { params: Promise<{ job: string }> }) {
  const { job } = await context.params;
  try {
    if (!allowedJobs.has(job)) throw new AppError("NOT_FOUND", "المهمة غير موجودة.", 404);
    const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    const expected = serverEnv().CRON_SECRET ?? "";
    if (!expected || supplied.length !== expected.length || !timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))) throw new AppError("FORBIDDEN", "مفتاح المهمة غير صحيح.", 403);
    const { data, error } = await createAdminClient().rpc("eco_run_background_job", { p_job_name: job, p_run_key: `${job}:${new Date().toISOString().slice(0, 13)}` });
    if (error) throw error;
    return ok(data);
  } catch (cause) { return apiError(cause, { route: "job", job }); }
}
