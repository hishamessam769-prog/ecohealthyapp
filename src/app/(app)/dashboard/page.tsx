import Link from "next/link";
import { ArrowUpLeft, Banknote, CalendarClock, CircleAlert, FolderKanban, Stethoscope, TrendingUp, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requirePermission } from "@/lib/auth/require-permission";

export const metadata = { title: "الرئيسية" };

export default async function DashboardPage() {
  const viewer = await requirePermission("dashboard.view");
  const cards = [
    { label: "Confirmed Cash", value: "362K", detail: "+12.4% هذا الشهر", icon: Banknote, href: "/finance/payments", permission: "payments.review" },
    { label: "الاشتراكات النشطة", value: "311", detail: "27 تجديد قريب", icon: Users, href: "/subscriptions", permission: "subscriptions.view" },
    { label: "المهام المتأخرة", value: "13", detail: "3 حرجة", icon: CircleAlert, href: "/tasks", permission: "tasks.view_own" },
    { label: "جلسات اليوم", value: "17", detail: "4 بانتظار الدفع", icon: CalendarClock, href: "/doctors/sessions", permission: "sessions.view_own" },
  ].filter((card) => viewer.preview || viewer.permissions.includes(card.permission));
  const apps = [
    { title: "المشروعات والمهام", description: "متابعة التنفيذ والردود والأدلة", href: "/projects", icon: FolderKanban, permission: "projects.view" },
    { title: "CRM والعملاء", description: "Leads وCustomer 360 والشكاوى", href: "/crm/leads", icon: Users, permission: "leads.view" },
    { title: "المبيعات والاشتراكات", description: "العروض والفواتير والخدمة اليومية", href: "/sales", icon: TrendingUp, permission: "catalog.view" },
    { title: "الأطباء والجلسات", description: "التقويم والحجز والمحاسبة", href: "/doctors", icon: Stethoscope, permission: "doctors.view" },
  ].filter((app) => viewer.preview || viewer.permissions.includes(app.permission));
  return <div className="space-y-7">
    <PageHeader eyebrow="Executive workspace" title={`صباح الخير، ${viewer.name.split(" ")[0]}`} description="مؤشرات قابلة للتتبع من التحصيل المؤكد والتنفيذ الفعلي، مع Drill-down إلى المعاملة أوالمهمة أوالجلسة." />
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map(({ label, value, detail, icon: Icon, href }) => <Link href={href} key={label} className="surface group rounded-2xl p-5 transition hover:-translate-y-0.5 hover:border-[var(--primary)]"><div className="flex items-start justify-between"><span className="grid size-11 place-items-center rounded-xl bg-[var(--primary-soft)] text-[var(--primary)]"><Icon size={21} /></span><ArrowUpLeft size={18} className="text-[var(--text-muted)]" /></div><strong className="mt-5 block text-3xl font-black">{value}</strong><span className="mt-1 block text-sm font-bold">{label}</span><span className="mt-2 block text-xs text-[var(--text-muted)]">{detail}</span></Link>)}</div>
    <div className="grid gap-5 xl:grid-cols-[1.25fr_0.75fr]">
      <Card><CardHeader title="مشغّل التطبيقات" description="تظهر الوحدات طبقًا للصلاحية ونطاق الفرع." /><div className="grid gap-3 p-5 sm:grid-cols-2">{apps.map(({ title, description, href, icon: Icon }) => <Link href={href} key={href} className="rounded-2xl border border-[var(--border)] p-5 transition hover:border-[var(--primary)] hover:bg-[var(--primary-soft)]/35"><Icon className="text-[var(--primary)]" /><strong className="mt-4 block">{title}</strong><span className="mt-1 block text-sm leading-6 text-[var(--text-muted)]">{description}</span></Link>)}</div></Card>
      <Card><CardHeader title="تحتاج انتباهك" description="قرارات واستثناءات حسب الأولوية." /><div className="space-y-3 p-5">{[
        ["موافقة Refund أعلى من الحد", "حرج", "danger"], ["مشروع تحسين الاحتفاظ", "At Risk", "warning"], ["5 جلسات بدون Notes", "اليوم", "info"], ["3 Tasks بانتظار Review", "مراجعة", "neutral"],
      ].map(([title, status, tone]) => <div key={title} className="flex items-center justify-between gap-3 rounded-xl bg-[var(--surface-muted)] px-4 py-3"><span className="text-sm font-bold">{title}</span><Badge tone={tone as "danger" | "warning" | "info" | "neutral"}>{status}</Badge></div>)}</div></Card>
    </div>
  </div>;
}
