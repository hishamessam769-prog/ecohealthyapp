import Link from "next/link";
import { submitPaymentProofAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "الفواتير وإثباتات الدفع" };
const field = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";
type Invoice = { id: string; invoice_number: number; status: string; total_amount: number; confirmed_paid_amount: number; currency: string; customers: { full_name: string } | null };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["sales.invoice", "payments.review", "payments.submit"]);
  const params = await searchParams;
  let invoices: Invoice[];
  if (viewer.preview) invoices = [
    { id: "33333333-3333-4333-8333-333333333333", invoice_number: 2088, status: "paid", total_amount: 5700, confirmed_paid_amount: 5700, currency: "EGP", customers: { full_name: "أحمد محمد" } },
    { id: "44444444-4444-4444-8444-444444444444", invoice_number: 2089, status: "issued", total_amount: 8400, confirmed_paid_amount: 0, currency: "EGP", customers: { full_name: "نور خالد" } },
  ]; else {
    const supabase = await createClient();
    const { data } = await supabase.from("invoices").select("id,invoice_number,status,total_amount,confirmed_paid_amount,currency,customers(full_name)").eq("branch_id", viewer.activeBranchId!).order("issued_at", { ascending: false }).limit(50);
    invoices = (data || []) as unknown as Invoice[];
  }
  const payable = invoices.filter((invoice) => ["issued", "partially_paid"].includes(invoice.status) && invoice.confirmed_paid_amount < invoice.total_amount);
  const canSubmit = viewer.preview || viewer.permissions.includes("payments.submit");
  return <div className="space-y-7">
    <PageHeader eyebrow="Billing" title="الفواتير وإثبات الدفع" description="الفاتورة تُختار يدويًا. رفع الإثبات لا يغيّر Confirmed Cash ولا Revenue قبل Finance Confirmation." />
    <ActionNotice saved={params.saved} error={params.error} />
    {canSubmit ? <Card><CardHeader title="رفع Payment Proof" description="لا يوجد اختيار تلقائي: يجب تحديد الفاتورة المقصودة صراحةً." />
      <form action={submitPaymentProofAction} encType="multipart/form-data" className="grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-3">
        <label className="text-sm font-bold">الفاتورة *<select name="invoiceId" required defaultValue="" className={field}><option value="" disabled>اختر الفاتورة يدويًا</option>{payable.map((invoice) => <option key={invoice.id} value={invoice.id}>INV-{invoice.invoice_number} · {invoice.customers?.full_name} · المتبقي {invoice.total_amount - invoice.confirmed_paid_amount} {invoice.currency}</option>)}</select></label>
        <label className="text-sm font-bold">المبلغ المدعى *<input name="amount" type="number" min="0.01" step="0.01" required className={field} /></label>
        <label className="text-sm font-bold">طريقة الدفع *<select name="paymentMethod" required className={field}><option value="bank_transfer">تحويل بنكي</option><option value="card">بطاقة</option><option value="cash">نقدي</option><option value="wallet">محفظة</option></select></label>
        <label className="text-sm font-bold">مرجع خارجي<input name="externalReference" className={field} /></label>
        <label className="text-sm font-bold">ملف الإثبات<input name="proofFile" type="file" accept="image/png,image/jpeg,image/webp,application/pdf" className={`${field} py-2`} /></label>
        <label className="text-sm font-bold">أورابط/مسار الإثبات<input name="proofReference" placeholder="استخدمه إذا لم ترفع ملفًا" className={field} /></label>
        <Button type="submit" className="md:col-span-2 xl:col-span-3">إرسال إلى Finance كـPending</Button>
      </form></Card> : null}
    <Card><CardHeader title="سجل الفواتير" description="افتح التفاصيل للطباعة أوالحفظ PDF ومراجعة البنود والمدفوع والمتبقي." />
      <ResponsiveTable rows={invoices} getKey={(row) => row.id} emptyTitle="لا توجد فواتير" emptyDescription="حوّل عرض سعر مقبول إلى فاتورة." columns={[
        { key: "number", label: "الفاتورة", primary: true, render: (row: Invoice) => <Link className="font-black text-[var(--primary)] underline-offset-4 hover:underline" href={`/sales/invoices/${row.id}`}>INV-{row.invoice_number}</Link> },
        { key: "customer", label: "العميل", render: (row: Invoice) => row.customers?.full_name || "—" },
        { key: "total", label: "الإجمالي", render: (row: Invoice) => `${row.total_amount} ${row.currency}` },
        { key: "paid", label: "المدفوع", render: (row: Invoice) => `${row.confirmed_paid_amount} ${row.currency}` },
        { key: "remaining", label: "المتبقي", render: (row: Invoice) => `${row.total_amount - row.confirmed_paid_amount} ${row.currency}` },
        { key: "status", label: "الحالة", render: (row: Invoice) => <Badge tone={row.status === "paid" ? "success" : "warning"}>{row.status}</Badge> },
      ]} />
    </Card>
  </div>;
}
