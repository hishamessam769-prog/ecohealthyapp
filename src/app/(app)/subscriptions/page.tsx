import { activateSubscriptionAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "الاشتراكات والإيراد المؤجل" };
const field = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";
type Subscription = { id: string; subscription_number: number; status: string; starts_on: string; purchased_service_days: number; delivered_service_days: number; contract_value: number; deferred_balance: number; recognized_revenue: number; customers: { full_name: string } | null; invoices: { invoice_number: number } | null };
type PaidInvoice = { id: string; invoice_number: number; customers: { full_name: string } | null; invoice_lines: Array<{ package_version_id: string; description: string }> };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["subscriptions.view"]);
  const params = await searchParams;
  let subscriptions: Subscription[] = []; let paidInvoices: PaidInvoice[] = [];
  if (viewer.preview) {
    subscriptions = [{ id: "66666666-6666-4666-8666-666666666666", subscription_number: 1402, status: "active", starts_on: "2026-09-17", purchased_service_days: 30, delivered_service_days: 1, contract_value: 5700, deferred_balance: 5510, recognized_revenue: 190, customers: { full_name: "أحمد محمد" }, invoices: { invoice_number: 2088 } }];
    paidInvoices = [{ id: "33333333-3333-4333-8333-333333333333", invoice_number: 2088, customers: { full_name: "أحمد محمد" }, invoice_lines: [{ package_version_id: "11111111-1111-4111-8111-111111111111", description: "Eco 30 V3" }] }];
  } else {
    const supabase = await createClient();
    const [{ data: subscriptionRows }, { data: invoiceRows }] = await Promise.all([
      supabase.from("subscriptions").select("id,subscription_number,status,starts_on,purchased_service_days,delivered_service_days,contract_value,deferred_balance,recognized_revenue,customers(full_name),invoices(invoice_number)").order("created_at", { ascending: false }).limit(50),
      supabase.from("invoices").select("id,invoice_number,customers(full_name),invoice_lines(package_version_id,description)").eq("status", "paid").order("issued_at", { ascending: false }),
    ]);
    subscriptions = (subscriptionRows || []) as unknown as Subscription[];
    paidInvoices = (invoiceRows || []).filter((invoice) => Array.isArray(invoice.invoice_lines) && invoice.invoice_lines.length) as unknown as PaidInvoice[];
  }
  const canManage = viewer.preview || viewer.permissions.includes("subscriptions.manage");
  return <div className="space-y-7">
    <PageHeader eyebrow="Revenue control" title="الاشتراكات والإيراد المؤجل" description="التفعيل متاح فقط لفاتورة Paid، وPackage Version يجب أن يكون بندًا في الفاتورة نفسها." />
    <ActionNotice saved={params.saved} error={params.error} />
    {canManage ? <Card><CardHeader title="تفعيل Subscription من فاتورة" description="ينشئ الاشتراك، Deferred Revenue Entry، وجدول أيام الخدمة في معاملة واحدة." /><form action={activateSubscriptionAction} className="grid gap-4 p-5 md:grid-cols-3"><label className="text-sm font-bold">الفاتورة *<select name="invoiceId" required className={field}><option value="">اختر فاتورة Paid</option>{paidInvoices.map((invoice) => <option key={invoice.id} value={invoice.id}>INV-{invoice.invoice_number} · {invoice.customers?.full_name}</option>)}</select></label><label className="text-sm font-bold">Package Version من الفاتورة *<select name="packageVersionId" required className={field}><option value="">اختر البند</option>{paidInvoices.flatMap((invoice) => invoice.invoice_lines.map((line) => <option key={`${invoice.id}-${line.package_version_id}`} value={line.package_version_id}>INV-{invoice.invoice_number} · {line.description}</option>))}</select></label><label className="text-sm font-bold">تاريخ البداية *<input name="startsOn" type="date" required className={field} /></label><Button type="submit" className="md:col-span-3">تفعيل وإنشاء Deferred Revenue</Button></form></Card> : null}
    <Card><CardHeader title="الاشتراكات الفعلية" description="Deferred + Recognized يجب أن يساويا قيمة العقد بعد كل حركة." /><ResponsiveTable rows={subscriptions} getKey={(row) => row.id} emptyTitle="لا توجد اشتراكات" emptyDescription="فعّل اشتراكًا من فاتورة مدفوعة." columns={[
      { key: "number", label: "الاشتراك", primary: true, render: (row: Subscription) => `SUB-${row.subscription_number}` },
      { key: "customer", label: "العميل", render: (row: Subscription) => row.customers?.full_name || "—" },
      { key: "invoice", label: "الفاتورة", render: (row: Subscription) => `INV-${row.invoices?.invoice_number || "—"}` },
      { key: "days", label: "الأيام", render: (row: Subscription) => `${row.delivered_service_days}/${row.purchased_service_days}` },
      { key: "deferred", label: "Deferred", render: (row: Subscription) => row.deferred_balance },
      { key: "recognized", label: "Recognized", render: (row: Subscription) => row.recognized_revenue },
      { key: "status", label: "الحالة", render: (row: Subscription) => <Badge tone="success">{row.status}</Badge> },
    ]} /></Card>
  </div>;
}
