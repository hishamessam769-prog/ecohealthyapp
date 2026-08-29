import { apiError, ok } from "@/lib/api";
import { requirePrincipal } from "@/lib/auth";
import { loadReadModel } from "@/lib/read-models";

export const dynamic = "force-dynamic";

export async function GET(request: Request, context: { params: Promise<{ model: string }> }) {
  const { model } = await context.params;
  try {
    const principal = await requirePrincipal();
    return ok(await loadReadModel(model, principal, new URL(request.url).searchParams));
  } catch (cause) { return apiError(cause, { route: "read_model", model }); }
}
