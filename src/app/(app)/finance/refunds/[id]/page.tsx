import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { PrintButton } from "@/components/ui/print-button";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";
import { formatDateTime } from "@/lib/utils";

export const metadata = { title: "طلب استرداد" };
type RefundDetail = {
  id: string; amount: number; reason: string; reason_code: string | null; status: string; requested_at: string; approved_at: string | null; paid_at: string | null;
  recipient_method: string | null; recipient_account_name: string | null; recipient_account_reference: string | null; payment_proof_reference: string | null;
  calculation_basis: { remaining_days?: number; daily_value?: number; deferred_balance?: number; confirmed_cash_available?: number };
  customers: { customer_number: number; full_name: string; mobile: string | null } | null;
  invoices: { invoice_number: number; total_amount: number; confirmed_paid_amount: number } | null;
  subscriptions: { subscription_number: number; purchased_service_days: number; delivered_service_days: number; deferred_balance: number; package_versions: { packages: { name: string } | null } | null } | null;
  requester: { full_name: string } | null; approver: { full_name: string } | null; payer: { full_name: string } | null;
};

export default async function RefundDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const viewer = await requireAnyPermission(["refunds.request", "refunds.approve", "refunds.pay"]);
  const { id } = await params;
  if (viewer.preview) notFound();
  const supabase = await createClient();
  const { data, error } = await supabase.from("refunds").select("id,amount,reason,reason_code,status,requested_at,approved_at,paid_at,recipient_method,recipient_account_name,recipient_account_reference,payment_proof_reference,calculation_basis,customers(customer_number,full_name,mobile),invoices(invoice_number,total_amount,confirmed_paid_amount),subscriptions(subscription_number,purchased_service_days,delivered_service_days,deferred_balance,package_versions(packages(name))),requester:profiles!refunds_requested_by_fkey(full_name),approver:profiles!refunds_approved_by_fkey(full_name),payer:profiles!refunds_paid_by_fkey(full_name)").eq("id", id).maybeSingle();
  if (error) throw new Error(`Refund detail failed: ${error.message}`);
  if (!data) notFound();
  const refund = data as unknown as RefundDetail;
  return <div className="space-y-7">
    <div className="print:hidden"><PageHeader eyebrow="Refund approval document" title={`طلب استرداد · ${refund.customers?.full_name}`} description="نسخة قابلة للطباعة أوالحفظ PDF قبل الاعتماد وبعد الدفع." /></div>
    <Card className="overflow-hidden print:border-0 print:shadow-none">
      <div className="flex flex-wrap items-start justify-between gap-4 border-b border-[var(--border)] p-6"><div><span className="text-xs font-black uppercase tracking-[0.25em] text-[var(--primary)]">Eco Healthy ERP</span><h1 className="mt-2 text-2xl font-black">طلب استرداد مالي</h1><p className="mt-1 text-sm text-[var(--text-muted)]">REF-{refund.id.slice(0, 8).toUpperCase()}</p></div><div className="flex items-center gap-3 print:hidden"><Badge tone={refund.status === "paid" ? "success" : "warning"}>{refund.status}</Badge><PrintButton /></div></div>
      <div className="grid gap-5 p-6 md:grid-cols-2">
        <section className="rounded-2xl bg-[var(--surface-muted)] p-5"><h2 className="font-extrabold">بيانات العميل</h2><dl className="mt-4 grid grid-cols-2 gap-3 text-sm"><dt className="text-[var(--text-muted)]">العميل</dt><dd className="font-bold">CUS-{refund.customers?.customer_number} · {refund.customers?.full_name}</dd><dt className="text-[var(--text-muted)]">الهاتف</dt><dd className="font-bold">{refund.customers?.mobile}</dd><dt className="text-[var(--text-muted)]">الفاتورة</dt><dd className="font-bold">INV-{refund.invoices?.invoice_number}</dd><dt className="text-[var(--text-muted)]">الاشتراك</dt><dd className="font-bold">SUB-{refund.subscriptions?.subscription_number}</dd><dt className="text-[var(--text-muted)]">الباقة</dt><dd className="font-bold">{refund.subscriptions?.package_versions?.packages?.name}</dd></dl></section>
        <section className="rounded-2xl bg-[var(--surface-muted)] p-5"><h2 className="font-extrabold">حساب الاسترداد</h2><dl className="mt-4 grid grid-cols-2 gap-3 text-sm"><dt className="text-[var(--text-muted)]">الأيام المتبقية</dt><dd className="font-bold">{refund.calculation_basis?.remaining_days ?? "—"}</dd><dt className="text-[var(--text-muted)]">قيمة اليوم</dt><dd className="font-bold">{refund.calculation_basis?.daily_value ?? "—"} EGP</dd><dt className="text-[var(--text-muted)]">Deferred المتاح</dt><dd className="font-bold">{refund.calculation_basis?.deferred_balance ?? "—"} EGP</dd><dt className="text-[var(--text-muted)]">Confirmed Cash المتاح</dt><dd className="font-bold">{refund.calculation_basis?.confirmed_cash_available ?? "—"} EGP</dd><dt className="text-[var(--text-muted)]">قيمة الاسترداد النهائية</dt><dd className="text-xl font-black text-red-700">{Number(refund.amount).toLocaleString("en-US")} EGP</dd></dl></section>
        <section className="rounded-2xl border border-[var(--border)] p-5"><h2 className="font-extrabold">السبب وبيانات التحويل</h2><p className="mt-3 text-sm leading-7">{refund.reason}</p><dl className="mt-4 grid grid-cols-2 gap-3 text-sm"><dt className="text-[var(--text-muted)]">الطريقة</dt><dd className="font-bold">{refund.recipient_method}</dd><dt className="text-[var(--text-muted)]">اسم الحساب</dt><dd className="font-bold">{refund.recipient_account_name}</dd><dt className="text-[var(--text-muted)]">الرقم/الحساب</dt><dd className="font-bold">{refund.recipient_account_reference}</dd><dt className="text-[var(--text-muted)]">إثبات الدفع</dt><dd className="font-bold">{refund.payment_proof_reference || "لم يتم الدفع بعد"}</dd></dl></section>
        <section className="rounded-2xl border border-[var(--border)] p-5"><h2 className="font-extrabold">مسار الاعتماد</h2><dl className="mt-4 grid grid-cols-2 gap-3 text-sm"><dt className="text-[var(--text-muted)]">طلب بواسطة</dt><dd className="font-bold">{refund.requester?.full_name || "—"}</dd><dt className="text-[var(--text-muted)]">وقت الطلب</dt><dd className="font-bold">{formatDateTime(refund.requested_at, "ar")}</dd><dt className="text-[var(--text-muted)]">اعتمد بواسطة</dt><dd className="font-bold">{refund.approver?.full_name || "بانتظار الاعتماد"}</dd><dt className="text-[var(--text-muted)]">وقت الاعتماد</dt><dd className="font-bold">{refund.approved_at ? formatDateTime(refund.approved_at, "ar") : "—"}</dd><dt className="text-[var(--text-muted)]">دفع بواسطة</dt><dd className="font-bold">{refund.payer?.full_name || "بانتظار الدفع"}</dd><dt className="text-[var(--text-muted)]">وقت الدفع</dt><dd className="font-bold">{refund.paid_at ? formatDateTime(refund.paid_at, "ar") : "—"}</dd></dl></section>
      </div>
      <div className="border-t border-[var(--border)] p-5 text-xs leading-6 text-[var(--text-muted)]">هذا المستند صادر من Eco Healthy ERP. لا يُعد تحويلًا ماليًا مكتملًا إلا إذا كانت الحالة Paid ويوجد مرجع إثبات دفع.</div>
    </Card>
  </div>;
}
