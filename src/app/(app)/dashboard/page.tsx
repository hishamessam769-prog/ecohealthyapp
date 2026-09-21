import Link from "next/link";
import { ArrowUpLeft, Banknote, CalendarClock, CircleAlert, FolderKanban, Stethoscope, TrendingUp, Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requirePermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "الرئيسية" };

export default async function DashboardPage() {
  const viewer = await requirePermission("dashboard.view");
  let confirmedCash = 0; let activeSubscriptions = 0; let joinedSubscriptions = 0; let overdueTasks = 0; let todaySessions = 0; let pendingRefunds = 0; let atRiskProjects = 0; let pendingNotes = 0;
  if (!viewer.preview) {
    const supabase = await createClient();
    const currentTime = new Date();
    const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Cairo" }).format(currentTime);
    const monthAgoDate = new Date(currentTime);
    monthAgoDate.setUTCDate(monthAgoDate.getUTCDate() - 30);
    const monthAgo = monthAgoDate.toISOString();
    const [cashResult, activeResult, joinedResult, taskResult, sessionResult, refundResult, projectResult, notesResult] = await Promise.all([
      viewer.permissions.includes("payments.review") ? supabase.from("payment_transactions").select("amount").eq("branch_id", viewer.activeBranchId!).in("transaction_type", ["collection", "refund", "reversal"]) : Promise.resolve({ data: [] }),
      viewer.permissions.includes("subscriptions.view") ? supabase.from("subscriptions").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).eq("status", "active") : Promise.resolve({ count: 0 }),
      viewer.permissions.includes("subscriptions.view") ? supabase.from("subscriptions").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).gte("created_at", monthAgo) : Promise.resolve({ count: 0 }),
      viewer.permissions.some((permission) => permission.startsWith("tasks.view_")) ? supabase.from("tasks").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).lt("due_at", new Date().toISOString()).not("status", "in", "(completed,cancelled)") : Promise.resolve({ count: 0 }),
      viewer.permissions.includes("sessions.view_own") || viewer.permissions.includes("sessions.view_team") ? supabase.from("doctor_sessions").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).gte("scheduled_start", `${today}T00:00:00+02:00`).lt("scheduled_start", `${today}T23:59:59+02:00`) : Promise.resolve({ count: 0 }),
      viewer.permissions.includes("refunds.approve") ? supabase.from("refunds").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).in("status", ["requested", "under_review"]) : Promise.resolve({ count: 0 }),
      viewer.permissions.includes("projects.view") ? supabase.from("projects").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).eq("status", "at_risk") : Promise.resolve({ count: 0 }),
      viewer.permissions.includes("sessions.view_own") || viewer.permissions.includes("sessions.view_team") ? supabase.from("doctor_sessions").select("id", { count: "exact", head: true }).eq("branch_id", viewer.activeBranchId!).eq("status", "completed_pending_notes") : Promise.resolve({ count: 0 }),
    ]);
    confirmedCash = ((cashResult as { data?: Array<{ amount: number }> }).data || []).reduce((sum, row) => sum + Number(row.amount), 0);
    activeSubscriptions = activeResult.count || 0; joinedSubscriptions = joinedResult.count || 0; overdueTasks = taskResult.count || 0; todaySessions = sessionResult.count || 0; pendingRefunds = refundResult.count || 0; atRiskProjects = projectResult.count || 0; pendingNotes = notesResult.count || 0;
  }
  const cards = [
    { label: "Confirmed Cash", value: viewer.preview ? "362K" : `${confirmedCash.toLocaleString("en-US")} EGP`, detail: "من الحركات المالية المؤكدة فقط", icon: Banknote, href: "/finance/payments", permission: "payments.review" },
    { label: "الاشتراكات النشطة", value: viewer.preview ? "311" : String(activeSubscriptions), detail: `${joinedSubscriptions} انضموا آخر 30 يوم`, icon: Users, href: "/subscriptions", permission: "subscriptions.view" },
    { label: "المهام المتأخرة", value: viewer.preview ? "13" : String(overdueTasks), detail: "حسب الصلاحية ونطاق الفرع", icon: CircleAlert, href: "/tasks", permission: "tasks.view_own" },
    { label: "جلسات اليوم", value: viewer.preview ? "17" : String(todaySessions), detail: "حسب نطاق المستخدم", icon: CalendarClock, href: "/doctors/sessions", permission: "sessions.view_own" },
  ].filter((card) => viewer.preview || viewer.permissions.includes(card.permission));
  const apps = [
    { title: "المشروعات والمهام", description: "متابعة التنفيذ والردود والأدلة", href: "/projects", icon: FolderKanban, permission: "projects.view" },
    { title: "CRM والعملاء", description: "Leads وCustomer 360 والشكاوى", href: "/crm/leads", icon: Users, permission: "leads.view" },
    { title: "المبيعات والاشتراكات", description: "العروض والفواتير والخدمة اليومية", href: "/sales", icon: TrendingUp, permission: "catalog.view" },
    { title: "الأطباء والجلسات", description: "التقويم والحجز والمحاسبة", href: "/doctors", icon: Stethoscope, permission: "doctors.view" },
  ].filter((app) => viewer.preview || viewer.permissions.includes(app.permission));
  const attentionItems: Array<[string, string, "danger" | "warning" | "info" | "neutral"]> = [];
  if (viewer.preview) {
    attentionItems.push(["موافقة Refund أعلى من الحد", "حرج", "danger"], ["مشروع تحسين الاحتفاظ", "At Risk", "warning"], ["5 جلسات بدون Notes", "اليوم", "info"], ["3 Tasks بانتظار Review", "مراجعة", "neutral"]);
  } else {
    if (pendingRefunds) attentionItems.push([`${pendingRefunds} طلب Refund بانتظار Finance`, "مراجعة", "danger"]);
    if (atRiskProjects) attentionItems.push([`${atRiskProjects} مشروع معرض للخطر`, "At Risk", "warning"]);
    if (pendingNotes) attentionItems.push([`${pendingNotes} جلسة بانتظار Notes`, "اليوم", "info"]);
    if (overdueTasks) attentionItems.push([`${overdueTasks} مهمة متأخرة`, "متأخر", "neutral"]);
  }
  return <div className="space-y-7">
    <PageHeader eyebrow="Executive workspace" title={`صباح الخير، ${viewer.name.split(" ")[0]}`} description="مؤشرات قابلة للتتبع من التحصيل المؤكد والتنفيذ الفعلي، مع Drill-down إلى المعاملة أوالمهمة أوالجلسة." />
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map(({ label, value, detail, icon: Icon, href }) => <Link href={href} key={label} className="surface group rounded-2xl p-5 transition hover:-translate-y-0.5 hover:border-[var(--primary)]"><div className="flex items-start justify-between"><span className="grid size-11 place-items-center rounded-xl bg-[var(--primary-soft)] text-[var(--primary)]"><Icon size={21} /></span><ArrowUpLeft size={18} className="text-[var(--text-muted)]" /></div><strong className="mt-5 block text-3xl font-black">{value}</strong><span className="mt-1 block text-sm font-bold">{label}</span><span className="mt-2 block text-xs text-[var(--text-muted)]">{detail}</span></Link>)}</div>
    <div className="grid gap-5 xl:grid-cols-[1.25fr_0.75fr]">
      <Card><CardHeader title="مشغّل التطبيقات" description="تظهر الوحدات طبقًا للصلاحية ونطاق الفرع." /><div className="grid gap-3 p-5 sm:grid-cols-2">{apps.map(({ title, description, href, icon: Icon }) => <Link href={href} key={href} className="rounded-2xl border border-[var(--border)] p-5 transition hover:border-[var(--primary)] hover:bg-[var(--primary-soft)]/35"><Icon className="text-[var(--primary)]" /><strong className="mt-4 block">{title}</strong><span className="mt-1 block text-sm leading-6 text-[var(--text-muted)]">{description}</span></Link>)}</div></Card>
      <Card><CardHeader title="تحتاج انتباهك" description="قرارات واستثناءات فعلية من قاعدة البيانات للفرع المختار." /><div className="space-y-3 p-5">{attentionItems.map(([title, status, tone]) => <div key={title} className="flex items-center justify-between gap-3 rounded-xl bg-[var(--surface-muted)] px-4 py-3"><span className="text-sm font-bold">{title}</span><Badge tone={tone}>{status}</Badge></div>)}{!attentionItems.length ? <p className="text-sm text-[var(--text-muted)]">لا توجد استثناءات تحتاج تدخلًا الآن.</p> : null}</div></Card>
    </div>
  </div>;
}
