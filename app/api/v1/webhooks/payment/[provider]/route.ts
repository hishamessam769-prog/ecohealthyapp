import { createHmac, timingSafeEqual } from "node:crypto";
import { apiError, ok } from "@/lib/api";
import { AppError } from "@/lib/errors";
import { serverEnv } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { enforceRateLimit } from "@/lib/rate-limit";

export async function POST(request: Request, context: { params: Promise<{ provider: string }> }) {
  const { provider } = await context.params;
  try {
    await enforceRateLimit(`webhook:${provider}`, request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown", 600, 60);
    const raw = await request.text();
    const signature = request.headers.get("x-eco-signature") ?? "";
    const secret = serverEnv().PAYMENT_WEBHOOK_SECRET;
    if (!secret) throw new AppError("CONFIG", "Webhook secret غير مضبوط.", 503);
    const expected = createHmac("sha256", secret).update(raw).digest("hex");
    if (signature.length !== expected.length || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) throw new AppError("FORBIDDEN", "توقيع Webhook غير صحيح.", 403);
    const event = JSON.parse(raw) as { id?: string; created_at?: string; type?: string; data?: unknown };
    if (!event.id) throw new AppError("VALIDATION", "Webhook event id مطلوب.", 422);
    const admin = createAdminClient();
    const { error } = await admin.from("eco_payment_gateway_events").insert({ provider, provider_event_id: event.id, event_type: event.type ?? "UNKNOWN", provider_created_at: event.created_at ?? null, payload: event, signature_verified: true });
    if (error && error.code !== "23505") throw error;
    if (!error) await admin.from("eco_outbox_events").insert({ event_type: "PAYMENT_GATEWAY_EVENT_RECEIVED", aggregate_type: "gateway_event", aggregate_id: event.id, payload: { provider, event_id: event.id } });
    return ok({ accepted: true, duplicate: error?.code === "23505" });
  } catch (cause) { return apiError(cause, { route: "payment_webhook", provider }); }
}
