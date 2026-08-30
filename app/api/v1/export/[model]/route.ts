import { apiError } from "@/lib/api";
import { requirePrincipal } from "@/lib/auth";
import { loadReadModel } from "@/lib/read-models";

const arabicHeaders: Record<string, string> = {
  customer_number: "رقم العميل", full_name: "اسم العميل", phone: "رقم الهاتف", email: "البريد الإلكتروني",
  address_line: "العنوان بالتفصيل", zone_name: "المنطقة", map_url: "رابط اللوكيشن", latitude: "خط العرض",
  longitude: "خط الطول", delivery_window_name: "موعد التوصيل", sales_owner_name: "مسؤول المبيعات",
  customer_status: "حالة العميل", current_plan_name: "الاشتراك الحالي", active_subscription_count: "عدد الاشتراكات النشطة",
  total_orders: "إجمالي الطلبات", created_at: "تاريخ التسجيل", route_date: "تاريخ التوصيل", route_number: "رقم المسار",
  sequence_no: "ترتيب المحطة", customer_name: "اسم العميل", rider_name: "المندوب", pack_count: "عدد العبوات",
  cod_amount: "المبلغ المطلوب تحصيله", stop_state: "حالة التوصيل", navigation_url: "رابط الملاحة", delivery_window: "نافذة التوصيل",
};

function xml(value: unknown) {
  const text = value == null ? "" : typeof value === "object" ? JSON.stringify(value) : String(value);
  return text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
}

function workbook(headers: string[], rows: Record<string, unknown>[]) {
  const headerRow = headers.map((header) => `<Cell ss:StyleID="Header"><Data ss:Type="String">${xml(arabicHeaders[header] ?? header)}</Data></Cell>`).join("");
  const dataRows = rows.map((row) => `<Row>${headers.map((header) => `<Cell><Data ss:Type="String">${xml(row[header])}</Data></Cell>`).join("")}</Row>`).join("");
  return `<?xml version="1.0" encoding="UTF-8"?><?mso-application progid="Excel.Sheet"?><Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"><Styles><Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Center" ss:ReadingOrder="RightToLeft"/><Font ss:FontName="Arial" ss:Size="11"/></Style><Style ss:ID="Header"><Font ss:FontName="Arial" ss:Size="11" ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#16794A" ss:Pattern="Solid"/><Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:ReadingOrder="RightToLeft"/></Style></Styles><Worksheet ss:Name="ECO Healthy"><Table><Column ss:AutoFitWidth="1" ss:Width="120"/><Row>${headerRow}</Row>${dataRows}</Table><WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel"><DisplayRightToLeft/><FreezePanes/><FrozenNoSplit/><SplitHorizontal>1</SplitHorizontal><TopRowBottomPane>1</TopRowBottomPane><ActivePane>2</ActivePane></WorksheetOptions></Worksheet></Workbook>`;
}

export async function GET(request: Request, context: { params: Promise<{ model: string }> }) {
  const { model } = await context.params;
  try {
    const principal = await requirePrincipal();
    if (!principal.permissions.includes("exports.create") && !principal.permissions.includes("*")) throw new Error("EXPORT_FORBIDDEN");
    const source = new URL(request.url).searchParams;
    const rows: Record<string, unknown>[] = [];
    let page = 1; let total = 0;
    do {
      const params = new URLSearchParams(source); params.set("page", String(page)); params.set("pageSize", "100");
      const result = await loadReadModel(model, principal, params);
      rows.push(...result.rows as Record<string, unknown>[]); total = result.total; page += 1;
    } while (rows.length < total && rows.length < 5000);
    const hidden = new Set(["id", "customer_id", "scope_employee_id", "rider_employee_id", "search_text"]);
    const headers = rows.length ? Object.keys(rows[0] ?? {}).filter((key) => !hidden.has(key)) : [];
    return new Response(workbook(headers, rows), { headers: { "Content-Type": "application/vnd.ms-excel; charset=utf-8", "Content-Disposition": `attachment; filename="eco-${model}-${new Date().toISOString().slice(0, 10)}.xls"`, "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" } });
  } catch (cause) { return apiError(cause, { route: "export", model }); }
}
