import { createHash } from "node:crypto";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

export async function enforceRateLimit(scope: string, identifier: string, limit: number, windowSeconds: number) {
  const key=createHash("sha256").update(`${scope}:${identifier}`).digest("hex");
  const { data,error }=await createAdminClient().rpc("eco_take_rate_limit",{p_bucket_key:key,p_limit:limit,p_window_seconds:windowSeconds});
  if(error)throw new AppError("INTERNAL","تعذر تطبيق حماية معدل الطلبات.",500);
  if(!data)throw new AppError("RATE_LIMITED","طلبات كثيرة؛ حاول لاحقًا.",429);
}
