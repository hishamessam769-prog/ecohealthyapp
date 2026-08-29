import { apiError, ok, parseJson } from "@/lib/api";
import { requirePrincipal } from "@/lib/auth";
import { executeCommand } from "@/lib/commands";

export const dynamic = "force-dynamic";

export async function POST(request: Request, context: { params: Promise<{ command: string }> }) {
  const { command } = await context.params;
  try {
    const principal = await requirePrincipal();
    return ok(await executeCommand(command, await parseJson(request), principal), 201);
  } catch (cause) { return apiError(cause, { route: "command", command }); }
}
