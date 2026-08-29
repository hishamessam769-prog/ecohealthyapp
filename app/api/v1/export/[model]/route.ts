import { apiError } from "@/lib/api";
import { requirePrincipal } from "@/lib/auth";
import { loadReadModel } from "@/lib/read-models";

function csvCell(value: unknown) {
  const text = value == null ? "" : typeof value === "object" ? JSON.stringify(value) : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}

export async function GET(request: Request, context: { params: Promise<{ model: string }> }) {
  const { model } = await context.params;
  try {
    const principal = await requirePrincipal();
    if (!principal.permissions.includes("exports.create") && !principal.permissions.includes("*")) throw new Error("EXPORT_FORBIDDEN");
    const params = new URL(request.url).searchParams;
    params.set("pageSize", "100");
    const result = await loadReadModel(model, principal, params);
    const rows = result.rows as Record<string, unknown>[];
    const headers = rows.length ? Object.keys(rows[0] ?? {}).filter((key) => key !== "search_text") : [];
    const csv = [`\uFEFF${headers.map(csvCell).join(",")}`, ...rows.map((row) => headers.map((header) => csvCell(row[header])).join(","))].join("\r\n");
    return new Response(csv, { headers: { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": `attachment; filename="eco-${model}-${new Date().toISOString().slice(0, 10)}.csv"`, "Cache-Control": "no-store" } });
  } catch (cause) { return apiError(cause, { route: "export", model }); }
}
