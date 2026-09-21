import { ArrowUpLeft, CheckCircle2, CircleDot, Plus, Sparkles } from "lucide-react";
import { erpWorkflowAction } from "@/app/actions/erp";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import type { ModuleRow } from "@/lib/erp/modules";

type Props = {
  view: {
    eyebrow: string; title: string; description: string;
    columns: { key: string; label: string }[]; rows: ModuleRow[];
    kpis: { label: string; value: string; tone: "green" | "amber" | "blue" | "red" }[];
    workflow?: string;
  };
  canAct: boolean;
};

const toneClass = { green: "bg-emerald-50 text-emerald-700", amber: "bg-amber-50 text-amber-700", blue: "bg-sky-50 text-sky-700", red: "bg-red-50 text-red-700" };
const field = "h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";

export function ModuleScreen({ view, canAct }: Props) {
  return <div className="space-y-7">
    <PageHeader eyebrow={view.eyebrow} title={view.title} description={view.description} action={view.workflow && canAct ? <a href="#quick-action" className="inline-flex h-11 items-center gap-2 rounded-xl bg-[var(--primary)] px-4 text-sm font-bold text-white"><Plus size={17} />إجراء جديد</a> : undefined} />
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{view.kpis.map((kpi) => <Card key={kpi.label} className="p-5"><div className="flex items-center justify-between"><span className={`rounded-xl px-3 py-1 text-xs font-black ${toneClass[kpi.tone]}`}>{kpi.label}</span><ArrowUpLeft size={17} className="text-[var(--text-muted)]" /></div><strong className="mt-5 block text-3xl font-black">{kpi.value}</strong><div className="mt-3 h-1.5 overflow-hidden rounded-full bg-[var(--surface-muted)]"><div className="h-full w-2/3 rounded-full bg-[var(--primary)]" /></div></Card>)}</div>
    <div className="grid gap-5 xl:grid-cols-[1.45fr_0.55fr]">
      <Card><CardHeader title="السجلات الحالية" description="يمكن فتح أي سجل للوصول إلى Timeline والمرفقات والأثر الكامل." /><ResponsiveTable rows={view.rows} getKey={(row) => JSON.stringify(row)} emptyTitle="لا توجد سجلات" emptyDescription="استخدم الإجراء الجديد لإنشاء أول سجل." columns={view.columns.map((column, index) => ({ key: column.key, label: column.label, primary: index === 0, render: (row: ModuleRow) => column.key === "status" ? <Badge tone="info">{row[column.key]}</Badge> : String(row[column.key] ?? "—") }))} /></Card>
      <Card><CardHeader title="مسار العمل" description="كل انتقال حالة مسجل في Timeline وAudit Log." /><div className="space-y-4 p-5">{["إنشاء وتحقق", "إسناد أو مراجعة", "تنفيذ ومتابعة", "اعتماد وإغلاق"].map((step, index) => <div key={step} className="flex items-center gap-3"><span className={`grid size-9 place-items-center rounded-xl ${index < 2 ? "bg-[var(--primary-soft)] text-[var(--primary)]" : "bg-[var(--surface-muted)] text-[var(--text-muted)]"}`}>{index < 2 ? <CheckCircle2 size={18} /> : <CircleDot size={18} />}</span><div><strong className="block text-sm">{step}</strong><span className="text-xs text-[var(--text-muted)]">المرحلة {index + 1}</span></div></div>)}</div></Card>
    </div>
    {view.workflow && canAct ? <div id="quick-action"><Card><CardHeader title="إجراء تشغيلي سريع" description="يحفظ في قاعدة البيانات الفعلية ويُطبق الصلاحيات. في وضع المعاينة يظهر النموذج فقط." /><form action={erpWorkflowAction} className="grid gap-4 p-5 sm:grid-cols-2 xl:grid-cols-4"><input type="hidden" name="workflow" value={view.workflow} /><label className="text-sm font-bold">العنوان أوالاسم *<input name="title" required className={`mt-2 ${field}`} /></label><label className="text-sm font-bold">التفاصيل<input name="details" className={`mt-2 ${field}`} /></label><label className="text-sm font-bold">الموعد أوالقيمة<input name="value" className={`mt-2 ${field}`} /></label><label className="text-sm font-bold">الأولوية<select name="priority" className={`mt-2 ${field}`}><option value="normal">عادي</option><option value="high">مرتفع</option><option value="critical">حرج</option></select></label><Button type="submit" className="sm:col-span-2 xl:col-span-4"><Sparkles size={17} />حفظ وتشغيل المسار</Button></form></Card></div> : null}
  </div>;
}
