import { ActionNotice } from "@/components/ui/action-notice";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";
import { DailyOperationsTable, type DailyRow } from "./daily-operations-table";

export const metadata = { title: "عمليات المشتركين" };
export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string; date?: string }> }) {
  const viewer = await requireAnyPermission(["subscriptions.view", "service.confirm_delivery"]);
  const params = await searchParams;
  const selectedDate = /^\d{4}-\d{2}-\d{2}$/.test(params.date || "") ? params.date! : new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Cairo" }).format(new Date());
  let days: DailyRow[] = [];
  if (!viewer.preview) {
    const supabase = await createClient();
    const { data, error } = await supabase.from("daily_subscriber_list_v").select("*").eq("service_date", selectedDate).order("zone_name").order("delivery_window_start").limit(250);
    if (error) throw new Error(`Daily subscriber list failed: ${error.message}`);
    days = (data || []) as DailyRow[];
  }
  const canConfirm = !viewer.preview && viewer.permissions.includes("service.confirm_delivery");
  const canOperate = !viewer.preview && viewer.permissions.includes("subscriptions.operate_daily");
  const planned = days.filter((day) => day.status === "planned");
  const portions = planned.reduce((sum, day) => sum + day.portion_multiplier, 0);
  const production = planned.reduce<Record<string, number>>((summary, row) => {
    const add = (meal: string | null) => { if (meal) summary[meal] = (summary[meal] || 0) + row.portion_multiplier; };
    if (row.meal_plan_code === "lunch") add(row.lunch);
    else if (row.meal_plan_code === "am") { add(row.breakfast); add(row.lunch); add(row.snack_1); }
    else if (row.meal_plan_code === "pm") { add(row.lunch); add(row.dinner); add(row.snack_1); }
    else { add(row.breakfast); add(row.lunch); add(row.dinner); add(row.snack_1); add(row.snack_2); }
    return summary;
  }, {});
  return <div className="space-y-7">
    <PageHeader eyebrow="Daily operations" title="عمليات المشتركين والإنتاج اليومي" description="اختيار جماعي، Skip مع يوم بديل، حصص إضافية، كشف مطبخ وتوصيل، ثم Confirm Delivered المحاسبي." />
    <ActionNotice saved={params.saved} error={params.error} />
    <Card className="print:hidden"><form method="get" className="flex flex-wrap items-end gap-3 p-4"><label className="text-sm font-bold">يوم التشغيل<input name="date" type="date" defaultValue={selectedDate} className="mt-2 h-10 rounded-xl border border-[var(--border)] bg-white px-3" /></label><button className="h-10 rounded-xl bg-[var(--primary)] px-4 text-sm font-bold text-white">عرض اليوم</button></form></Card>
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"><Card className="p-5"><span className="text-sm text-[var(--text-muted)]">مشتركو اليوم</span><strong className="mt-2 block text-3xl">{days.length}</strong></Card><Card className="p-5"><span className="text-sm text-[var(--text-muted)]">Planned</span><strong className="mt-2 block text-3xl">{planned.length}</strong></Card><Card className="p-5"><span className="text-sm text-[var(--text-muted)]">إجمالي الحصص</span><strong className="mt-2 block text-3xl">{portions}</strong></Card><Card className="p-5"><span className="text-sm text-[var(--text-muted)]">Zones</span><strong className="mt-2 block text-3xl">{new Set(days.map((day) => day.zone_name).filter(Boolean)).size}</strong></Card></div>
    <Card><CardHeader title={`ملخص إنتاج ${selectedDate}`} description="محسوب آليًا من نوع النظام وعدد الحصص، قبل الاستثناءات المكتوبة في الملاحظات." /><div className="grid gap-2 p-5 sm:grid-cols-2 lg:grid-cols-4">{Object.entries(production).sort((a, b) => b[1] - a[1]).map(([meal, count]) => <div key={meal} className="rounded-xl bg-[var(--surface-muted)] px-4 py-3"><strong className="block">{meal}</strong><span className="text-sm text-[var(--text-muted)]">{count} حصة</span></div>)}{!Object.keys(production).length ? <p className="text-sm text-[var(--text-muted)]">لا يوجد إنتاج مخطط لهذا اليوم.</p> : null}</div></Card>
    <Card><CardHeader title="كشف التوصيل والتأكيد" description="لا يدخل أي يوم Revenue إلا بعد Confirm Delivered؛ Skip ينشئ يومًا بديلًا في نهاية الاشتراك." /><DailyOperationsTable rows={days} canOperate={canOperate} canConfirm={canConfirm} /></Card>
  </div>;
}
