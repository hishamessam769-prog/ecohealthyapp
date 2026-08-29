import { apiError } from "@/lib/api";
import { requirePermission } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

const escape = (value: unknown) => String(value ?? "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" })[char] ?? char);

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  try {
    await requirePermission("invoices.print");
    const admin = createAdminClient();
    const { data: invoice } = await admin.from("eco_invoices").select("id,invoice_number,issue_date,currency,subtotal,discount_total,tax_total,delivery_fees,total,status,customer_id").eq("id", id).single();
    if (!invoice) throw new AppError("NOT_FOUND", "الفاتورة غير موجودة.", 404);
    const [{ data: customer }, { data: lines }] = await Promise.all([
      admin.from("eco_customers").select("customer_number,full_name,phone,email").eq("id", invoice.customer_id).single(),
      admin.from("eco_invoice_lines").select("description,quantity,unit_price,discount_amount,tax_amount,line_total").eq("invoice_id", id).order("line_no"),
    ]);
    const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${escape(invoice.invoice_number)}</title><style>@page{size:A4;margin:14mm}body{font-family:Arial;color:#17211b;margin:0}.top{display:flex;justify-content:space-between;border-bottom:4px solid #16794a;padding-bottom:18px}.logo{font-size:28px;font-weight:900;color:#16794a}table{width:100%;border-collapse:collapse;margin-top:24px}th,td{border:1px solid #dce5df;padding:10px;text-align:right}th{background:#edf7f1}.totals{width:360px;margin-right:auto}.print{position:fixed;left:16px;top:16px;padding:12px 20px;background:#16794a;color:#fff;border:0}@media print{.print{display:none}}</style></head><body><button class="print" onclick="window.print()">طباعة / حفظ PDF</button><div class="top"><div><div class="logo">ECO Healthy</div><div>فاتورة ضريبية / Invoice</div></div><div><b>${escape(invoice.invoice_number)}</b><br>${escape(invoice.issue_date)}<br>${escape(invoice.status)}</div></div><h3>${escape(customer?.full_name)}</h3><p>${escape(customer?.customer_number)} — <bdi>${escape(customer?.phone)}</bdi></p><table><thead><tr><th>البيان</th><th>الكمية</th><th>السعر</th><th>الخصم</th><th>الضريبة</th><th>الإجمالي</th></tr></thead><tbody>${(lines ?? []).map((line) => `<tr><td>${escape(line.description)}</td><td>${escape(line.quantity)}</td><td>${escape(line.unit_price)}</td><td>${escape(line.discount_amount)}</td><td>${escape(line.tax_amount)}</td><td>${escape(line.line_total)}</td></tr>`).join("")}</tbody></table><table class="totals"><tr><th>قبل الخصم</th><td>${escape(invoice.subtotal)} ${escape(invoice.currency)}</td></tr><tr><th>الخصم</th><td>${escape(invoice.discount_total)}</td></tr><tr><th>التوصيل</th><td>${escape(invoice.delivery_fees)}</td></tr><tr><th>الضريبة</th><td>${escape(invoice.tax_total)}</td></tr><tr><th>الإجمالي</th><td><b>${escape(invoice.total)} ${escape(invoice.currency)}</b></td></tr></table><p style="margin-top:30px;color:#66736b">تم إنشاء هذه الفاتورة من ECO Healthy ERP. استخدم زر الطباعة لاختيار Save as PDF.</p></body></html>`;
    return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
  } catch (cause) { return apiError(cause, { route: "invoice_print", invoiceId: id }); }
}
