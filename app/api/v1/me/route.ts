import { apiError, ok } from "@/lib/api";
import { requirePrincipal } from "@/lib/auth";

export const dynamic = "force-dynamic";

export async function GET() {
  try { return ok(await requirePrincipal()); }
  catch (cause) { return apiError(cause, { route: "me" }); }
}
