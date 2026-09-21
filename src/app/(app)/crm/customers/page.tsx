import { MapPin, Phone, Truck } from "lucide-react";
import { createCustomerDeliveryProfileAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "العملاء وعناوين التوصيل" };
const field = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";
type Zone = { id: string; name: string; branch_id: string | null };
type Customer = { id: string; customer_number: number; full_name: string; mobile: string | null; status: string; created_at: string; customer_addresses: Array<{ address_line: string; area: string | null; city: string | null; gps_url: string | null; delivery_window_start: string | null; delivery_window_end: string | null; delivery_time_confirmed: boolean; delivery_zones: { name: string } | null }> };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["customers.view"]);
  const params = await searchParams;
  let zones: Zone[] = []; let customers: Customer[] = [];
  if (!viewer.preview) {
    const supabase = await createClient();
    const [zoneResult, customerResult] = await Promise.all([
      supabase.from("delivery_zones").select("id,name,branch_id").eq("is_active", true).order("sort_order"),
      supabase.from("customers").select("id,customer_number,full_name,mobile,status,created_at,customer_addresses(address_line,area,city,gps_url,delivery_window_start,delivery_window_end,delivery_time_confirmed,delivery_zones(name))").order("created_at", { ascending: false }).limit(100),
    ]);
    if (zoneResult.error) throw new Error(`Delivery zones load failed: ${zoneResult.error.message}`);
    if (customerResult.error) throw new Error(`Customers load failed: ${customerResult.error.message}`);
    zones = (zoneResult.data || []) as Zone[];
    customers = (customerResult.data || []) as unknown as Customer[];
  }
  const canManage = !viewer.preview && viewer.permissions.includes("customers.manage");
  return <div className="space-y-7">
    <PageHeader eyebrow="Customer delivery profile" title="العملاء وعناوين التوصيل" description="رقم الهاتف فريد، والعنوان التفصيلي وGPS والـZone وموعد التوصيل المؤكد مطلوبة قبل بدء اشتراك جديد." />
    <ActionNotice saved={params.saved} error={params.error} />
    {canManage ? <Card><CardHeader title="إضافة عميل جاهز للاشتراك" description="تُحفظ معلومات التوصيل مرة واحدة ويمكن استخدامها في الاشتراكات التالية." /><form action={createCustomerDeliveryProfileAction} className="grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-4">
      <label className="text-sm font-bold">الاسم الكامل *<input name="fullName" required minLength={2} className={field} /></label>
      <label className="text-sm font-bold">الموبايل الفريد *<input name="mobile" required minLength={8} inputMode="tel" className={field} /></label>
      <label className="text-sm font-bold">البريد الإلكتروني<input name="email" type="email" className={field} /></label>
      <label className="text-sm font-bold">الفرع *<select name="branchId" required className={field}><option value="">اختر</option>{viewer.branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}</select></label>
      <label className="text-sm font-bold md:col-span-2">العنوان التفصيلي بالعربي *<input name="addressLine" required minLength={8} className={field} /></label>
      <label className="text-sm font-bold">المنطقة *<input name="area" required className={field} /></label>
      <label className="text-sm font-bold">المدينة *<input name="city" required defaultValue="القاهرة" className={field} /></label>
      <label className="text-sm font-bold">Zone *<select name="zoneId" required className={field}><option value="">اختر</option>{zones.map((zone) => <option key={zone.id} value={zone.id}>{zone.name}</option>)}</select></label>
      <label className="text-sm font-bold">Latitude *<input name="latitude" required type="number" step="0.0000001" className={field} /></label>
      <label className="text-sm font-bold">Longitude *<input name="longitude" required type="number" step="0.0000001" className={field} /></label>
      <label className="text-sm font-bold">Google Maps / GPS URL *<input name="gpsUrl" required type="url" placeholder="https://maps.google.com/..." className={field} /></label>
      <label className="text-sm font-bold">من الساعة *<input name="deliveryWindowStart" required type="time" className={field} /></label>
      <label className="text-sm font-bold">إلى الساعة *<input name="deliveryWindowEnd" required type="time" className={field} /></label>
      <label className="text-sm font-bold">اسم مستلم الطلب<input name="deliveryContactName" className={field} /></label>
      <label className="text-sm font-bold">هاتف مستلم الطلب<input name="deliveryContactMobile" inputMode="tel" className={field} /></label>
      <label className="text-sm font-bold xl:col-span-3">تعليمات التوصيل<input name="deliveryNotes" placeholder="الدور، علامة مميزة، الاتصال قبل الوصول…" className={field} /></label>
      <label className="flex items-center gap-2 text-sm font-bold xl:col-span-4"><input type="checkbox" name="confirmed" value="yes" required />تم تأكيد العنوان وGPS وموعد التوصيل مع العميل.</label>
      <Button type="submit" className="xl:col-span-4"><Truck size={18} />حفظ ملف العميل</Button>
    </form></Card> : null}
    <Card><CardHeader title="دليل العملاء" description={`${customers.length} عميل — بيانات التوصيل ظاهرة للمخولين فقط`} /><ResponsiveTable rows={customers} getKey={(row) => row.id} emptyTitle="لا يوجد عملاء" emptyDescription="أضف أول عميل من النموذج أعلاه." columns={[
      { key: "customer", label: "العميل", primary: true, render: (row: Customer) => <div><strong>CUS-{row.customer_number} · {row.full_name}</strong><span className="mt-1 flex items-center gap-1 text-xs font-normal text-[var(--text-muted)]"><Phone size={12} />{row.mobile || "—"}</span></div> },
      { key: "address", label: "العنوان", render: (row: Customer) => { const address = row.customer_addresses?.[0]; return address ? <div><span>{address.address_line}</span><span className="block text-xs text-[var(--text-muted)]">{address.area} · {address.delivery_zones?.name}</span></div> : "—"; } },
      { key: "window", label: "موعد التوصيل", render: (row: Customer) => { const address = row.customer_addresses?.[0]; return address?.delivery_time_confirmed ? `${address.delivery_window_start?.slice(0, 5)}–${address.delivery_window_end?.slice(0, 5)}` : "غير مؤكد"; } },
      { key: "gps", label: "GPS", render: (row: Customer) => row.customer_addresses?.[0]?.gps_url ? <a href={row.customer_addresses[0].gps_url!} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[var(--primary)] underline"><MapPin size={14} />فتح الخريطة</a> : "—" },
      { key: "status", label: "الحالة", render: (row: Customer) => <Badge tone={row.status === "active" ? "success" : "warning"}>{row.status}</Badge> },
    ]} /></Card>
  </div>;
}
