import { notFound } from "next/navigation";
import { PrintInvoiceButton } from "@/components/erp/print-invoice-button";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

type Line = { id: string; description: string; quantity: number; unit_price: number; line_total: number };
type Timeline = { event_type: string; aggregate_type: string; occurred_at: string; payload: Record<string, unknown> };
type Invoice = { id: string; invoice_number: number; status: string; currency: string; total_amount: number; confirmed_paid_amount: number; issued_at: string; due_at: string | null; customers: { full_name: string; mobile: string | null } | null; quotations: { quotation_number: number; subtotal: number; discount_amount: number } | null };

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const viewer = await requireAnyPermission(["sales.invoice", "payments.review", "subscriptions.view"]);
  const { id } = await params;
  let invoice: Invoice | null; let lines: Line[]; let timeline: Timeline[];
  if (viewer.preview) {
    invoice = { id, invoice_number: 2088, status: "partially_paid", currency: "EGP", total_amount: 5700, confirmed_paid_amount: 3000, issued_at: new Date().toISOString(), due_at: null, customers: { full_name: "أحمد محمد", mobile: "0100••••102" }, quotations: { quotation_number: 1042, subtotal: 6000, discount_amount: 300 } };
    lines = [{ id: "line-1", description: "Eco 30 · Version 3", quantity: 1, unit_price: 6000, line_total: 5700 }];
    timeline = [{ event_type: "invoice.created", aggregate_type: "invoice", occurred_at: new Date().toISOString(), payload: { total: 5700 } }, { event_type: "payment.confirmed", aggregate_type: "payment_transaction", occurred_at: new Date().toISOString(), payload: { amount: 3000 } }];
  } else {
    const supabase = await createClient();
    const [{ data: invoiceRow }, { data: lineRows }, { data: timelineRows }] = await Promise.all([
      supabase.from("invoices").select("id,invoice_number,status,currency,total_amount,confirmed_paid_amount,issued_at,due_at,customers(full_name,mobile),quotations(quotation_number,subtotal,discount_amount)").eq("id", id).maybeSingle(),
      supabase.from("invoice_lines").select("id,description,quantity,unit_price,line_total").eq("invoice_id", id).order("id"),
      supabase.rpc("invoice_timeline", { p_invoice_id: id }),
    ]);
    invoice = invoiceRow as unknown as Invoice | null;
    lines = (lineRows || []) as Line[];
    timeline = (timelineRows || []) as Timeline[];
  }
  if (!invoice) notFound();
  const subtotal = invoice.quotations?.subtotal ?? lines.reduce((sum, line) => sum + line.quantity * line.unit_price, 0);
  const discount = invoice.quotations?.discount_amount ?? Math.max(0, subtotal - invoice.total_amount);
  const remaining = invoice.total_amount - invoice.confirmed_paid_amount;
  return <div className="space-y-7 invoice-print-root">
    <div className="print:hidden"><PageHeader eyebrow="Invoice detail" title={`فاتورة INV-${invoice.invoice_number}`} description="تفاصيل مالية قابلة للطباعة أوالحفظ PDF من المتصفح." action={<PrintInvoiceButton />} /></div>
    <Card className="print:border-0 print:shadow-none">
      <div className="flex flex-wrap items-start justify-between gap-6 border-b border-[var(--border)] p-6">
        <div><p className="text-xs font-black uppercase tracking-[0.18em] text-[var(--primary)]">Eco Healthy ERP</p><h1 className="mt-2 text-3xl font-black">فاتورة INV-{invoice.invoice_number}</h1><p className="mt-2 text-sm text-[var(--text-muted)]">تاريخ الإصدار: {new Date(invoice.issued_at).toLocaleString("ar-EG")}</p></div>
        <div className="text-end"><Badge tone={invoice.status === "paid" ? "success" : "warning"}>{invoice.status}</Badge><p className="mt-3 font-black">{invoice.customers?.full_name}</p><p className="text-sm text-[var(--text-muted)]">{invoice.customers?.mobile || "—"}</p></div>
      </div>
      <ResponsiveTable rows={lines} getKey={(row) => row.id} emptyTitle="لا توجد بنود" emptyDescription="الفاتورة غير مكتملة." columns={[
        { key: "description", label: "البند", primary: true, render: (row: Line) => row.description },
        { key: "quantity", label: "الكمية", render: (row: Line) => row.quantity },
        { key: "unit", label: "سعر الوحدة", render: (row: Line) => `${row.unit_price} ${invoice.currency}` },
        { key: "total", label: "الإجمالي", render: (row: Line) => `${row.line_total} ${invoice.currency}` },
      ]} />
      <div className="ms-auto grid max-w-md gap-2 p-6 text-sm">
        <div className="flex justify-between"><span>قبل الخصم</span><strong>{subtotal} {invoice.currency}</strong></div>
        <div className="flex justify-between"><span>الخصم</span><strong>{discount} {invoice.currency}</strong></div>
        <div className="flex justify-between border-t pt-2 text-base"><span>الإجمالي</span><strong>{invoice.total_amount} {invoice.currency}</strong></div>
        <div className="flex justify-between text-emerald-700"><span>المدفوع المؤكد</span><strong>{invoice.confirmed_paid_amount} {invoice.currency}</strong></div>
        <div className="flex justify-between text-red-700"><span>المتبقي</span><strong>{remaining} {invoice.currency}</strong></div>
      </div>
    </Card>
    <Card className="print:hidden"><CardHeader title="Timeline" description="الأحداث الصادرة من معاملات قاعدة البيانات، بترتيبها الزمني." />
      <div className="divide-y divide-[var(--border)]">{timeline.length ? timeline.map((event, index) => <div key={`${event.event_type}-${index}`} className="flex flex-wrap items-center justify-between gap-3 p-5"><div><strong className="block">{event.event_type}</strong><span className="text-xs text-[var(--text-muted)]">{event.aggregate_type}</span></div><time className="text-sm text-[var(--text-muted)]">{new Date(event.occurred_at).toLocaleString("ar-EG")}</time></div>) : <p className="p-5 text-sm text-[var(--text-muted)]">لا توجد أحداث بعد.</p>}</div>
    </Card>
  </div>;
}
