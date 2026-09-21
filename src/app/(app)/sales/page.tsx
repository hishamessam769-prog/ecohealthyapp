import { acceptQuotationAction, convertQuotationAction, createCustomerQuotationAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "المبيعات وعروض الأسعار" };
const field = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";
type Quote = { id: string; quotation_number: number; status: string; subtotal: number; discount_amount: number; total_amount: number; valid_until: string | null; customers: { full_name: string } | null };
type Version = { id: string; version_number: number; price: number; currency: string; service_days: number; packages: { name: string } | null };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["catalog.view", "sales.quote"]);
  const params = await searchParams;
  let quotes: Quote[] = [];
  let versions: Version[] = [];
  if (viewer.preview) {
    versions = [{ id: "11111111-1111-4111-8111-111111111111", version_number: 3, price: 6000, currency: "EGP", service_days: 30, packages: { name: "Eco 30" } }];
    quotes = [{ id: "22222222-2222-4222-8222-222222222222", quotation_number: 1042, status: "issued", subtotal: 6000, discount_amount: 300, total_amount: 5700, valid_until: "2026-09-24", customers: { full_name: "أحمد محمد" } }];
  } else {
    const supabase = await createClient();
    const [{ data: quoteRows }, { data: versionRows }] = await Promise.all([
      supabase.from("quotations").select("id,quotation_number,status,subtotal,discount_amount,total_amount,valid_until,customers(full_name)").order("created_at", { ascending: false }).limit(30),
      supabase.from("package_versions").select("id,version_number,price,currency,service_days,packages(name)").eq("status", "active").order("effective_from", { ascending: false }),
    ]);
    quotes = (quoteRows || []) as unknown as Quote[];
    versions = (versionRows || []) as unknown as Version[];
  }
  const canQuote = viewer.preview || viewer.permissions.includes("sales.quote");
  const canInvoice = viewer.preview || viewer.permissions.includes("sales.invoice");
  return <div className="space-y-7">
    <PageHeader eyebrow="Sales execution" title="العميل → عرض السعر → الفاتورة" description="اختر نسخة سعر محددة؛ الخصم والصلاحية والبنود تحفظ Snapshot تاريخيًا." />
    <ActionNotice saved={params.saved} error={params.error} />
    {canQuote ? <Card><CardHeader title="عميل وعرض سعر جديد" description="ينشئ Customer ثم Quotation ببند Package Version المختار داخل معاملة واحدة." />
      <form action={createCustomerQuotationAction} className="grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-4">
        <label className="text-sm font-bold">الفرع *<select name="branchId" required className={field}>{viewer.branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}</select></label>
        <label className="text-sm font-bold">اسم العميل *<input name="customerName" required className={field} /></label>
        <label className="text-sm font-bold">الهاتف<input name="mobile" className={field} /></label>
        <label className="text-sm font-bold">Package Version *<select name="packageVersionId" required className={field}><option value="">اختر النسخة</option>{versions.map((version) => <option key={version.id} value={version.id}>{version.packages?.name} · V{version.version_number} · {version.price} {version.currency}</option>)}</select></label>
        <label className="text-sm font-bold">الكمية *<input name="quantity" type="number" min="0.01" step="0.01" defaultValue="1" required className={field} /></label>
        <label className="text-sm font-bold">الخصم %<input name="discountPercent" type="number" min="0" max="100" step="0.01" defaultValue="0" className={field} /></label>
        <label className="text-sm font-bold">صالح حتى *<input name="validUntil" type="date" required className={field} /></label>
        <label className="text-sm font-bold">ملاحظات<input name="notes" className={field} /></label>
        <Button type="submit" className="md:col-span-2 xl:col-span-4">إنشاء العميل وعرض السعر</Button>
      </form></Card> : null}
    <Card><CardHeader title="عروض الأسعار" description="Accept منفصل عن Convert لضمان انتقال الحالة الواضح وتسجيل الـTimeline." />
      <ResponsiveTable rows={quotes} getKey={(row) => row.id} emptyTitle="لا توجد عروض" emptyDescription="أنشئ أول عميل وعرض سعر من النموذج أعلاه." columns={[
        { key: "number", label: "العرض", primary: true, render: (row: Quote) => `Q-${row.quotation_number}` },
        { key: "customer", label: "العميل", render: (row: Quote) => row.customers?.full_name || "—" },
        { key: "amount", label: "قبل/خصم/إجمالي", render: (row: Quote) => `${row.subtotal} − ${row.discount_amount} = ${row.total_amount}` },
        { key: "valid", label: "الصلاحية", render: (row: Quote) => row.valid_until || "—" },
        { key: "status", label: "الحالة", render: (row: Quote) => <Badge tone="info">{row.status}</Badge> },
        { key: "actions", label: "الإجراء", render: (row: Quote) => <div className="flex flex-wrap gap-2">{row.status === "issued" && canQuote ? <form action={acceptQuotationAction}><input type="hidden" name="quotationId" value={row.id} /><Button type="submit" size="sm" variant="secondary">Accept</Button></form> : null}{row.status === "accepted" && canInvoice ? <form action={convertQuotationAction}><input type="hidden" name="quotationId" value={row.id} /><Button type="submit" size="sm">Convert to Invoice</Button></form> : null}</div> },
      ]} />
    </Card>
  </div>;
}
