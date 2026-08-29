"use client";
import Link from "next/link";
import { AlertTriangle, Bike, ChefHat, CircleDollarSign, RotateCcw, ShoppingCart, Trash2, Users } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { useERP } from "@/components/erp-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { money } from "@/lib/files";

const steps = [
  { href: "/clients", title: "1. سجل العميل", note: "بياناته والعنوان والمحاذير", icon: Users },
  { href: "/orders", title: "2. أنشئ الطلب", note: "اشتراك أو طلب مرة واحدة", icon: ShoppingCart },
  { href: "/accounting", title: "3. اعتماد الحسابات", note: "بوابة الدفع الإجبارية", icon: CircleDollarSign },
  { href: "/kitchen", title: "4. جهز المطبخ", note: "تجميع وكروت تعبئة", icon: ChefHat },
  { href: "/delivery", title: "5. سلم وحصّل", note: "Zones وكباتن وCOD", icon: Bike },
];

export default function DashboardPage() {
  const erp = useERP();
  const approvedRevenue = erp.orders.filter((x) => x.status === "Approved").reduce((s, x) => s + x.amount, 0);
  const active = erp.subscriptions.filter((x) => x.status === "Active").length;
  const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
  const kitchenLoad = erp.fulfillment.filter((x) => x.date === tomorrow && !x.skipped).length;
  const pending = erp.orders.filter((x) => x.status === "Pending Accounting").length;
  const blocked = erp.subscriptions.filter((sub) => { const payment = erp.payments.find((p) => p.orderId === sub.orderId); return sub.firstDeliveryCompleted && payment?.status === "COD"; }).length;
  return <AppShell title="لوحة الإدارة" subtitle="كل ما يحتاج قرارًا الآن في مكان واحد" actions={erp.demoMode ? <Button size="sm" variant="outline" onClick={erp.resetDemo}><RotateCcw size={16}/>إعادة بيانات التجربة</Button> : null}>
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">{[
      ["الإيراد المعتمد", money(approvedRevenue), "بعد Gatekeeper"], ["اشتراكات نشطة", active, "تعمل الآن"], ["حِمل مطبخ الغد", kitchenLoad, "وجبة/صنف"], ["في انتظار الحسابات", pending, "لا تدخل التشغيل"],
    ].map(([label, value, note]) => <Card key={label}><CardContent className="pt-5"><p className="text-sm font-bold text-[#66736b]">{label}</p><p className="mt-2 text-3xl font-black">{value}</p><p className="mt-1 text-xs text-[#8a958e]">{note}</p></CardContent></Card>)}</div>
    {blocked > 0 ? <Link href="/accounting" className="mt-4 flex items-start gap-3 rounded-lg border border-red-200 bg-red-50 p-4 text-red-900"><AlertTriangle className="shrink-0"/><div><b>{blocked} اشتراك متوقف ماليًا</b><p className="mt-1 text-sm">تم أول تسليم ولم يتم تأكيد التحصيل. الأيام التالية ممنوعة من المطبخ والتوصيل.</p></div></Link> : null}
    <Card className="mt-5"><CardHeader><CardTitle>جرّب الدورة كاملة</CardTitle></CardHeader><CardContent className="grid gap-3 md:grid-cols-2 xl:grid-cols-5">{steps.map(({ href, title, note, icon: Icon }) => <Link key={href} href={href} className="rounded-lg border border-[#dce5df] bg-white p-4 transition hover:border-[#68a984] hover:bg-[#f6fbf8]"><Icon className="text-[#16794a]"/><b className="mt-3 block">{title}</b><span className="mt-1 block text-xs leading-5 text-[#66736b]">{note}</span></Link>)}</CardContent></Card>
    <div className="mt-5 grid gap-4 xl:grid-cols-[1.2fr_.8fr]"><Card><CardHeader><CardTitle>تشغيل اليوم</CardTitle></CardHeader><CardContent className="grid gap-3 sm:grid-cols-3"><div className="rounded-md bg-[#eef4f0] p-4"><small>توصيلات اليوم</small><b className="mt-2 block text-2xl">{erp.deliveries.filter((x) => x.date === new Date().toISOString().slice(0,10)).length}</b></div><div className="rounded-md bg-[#eef4f0] p-4"><small>شكاوى مفتوحة</small><b className="mt-2 block text-2xl">{erp.complaints.filter((x) => x.status === "Open").length}</b></div><div className="rounded-md bg-[#eef4f0] p-4"><small>تنبيهات جديدة</small><b className="mt-2 block text-2xl">{erp.notifications.filter((x) => !x.read).length}</b></div></CardContent></Card><Card><CardHeader><CardTitle>بيانات التجربة</CardTitle></CardHeader><CardContent><p className="text-sm leading-6 text-[#66736b]">تقدر تضيف وتعدل وتعمل اعتماد وتحضير وتسليم وفاتورة وExcel. عند الانتهاء احذف سجلات التجربة فقط.</p><Button className="mt-4" variant="destructive" onClick={erp.purgeDemo} disabled={!erp.demoMode}><Trash2 size={17}/>حذف بيانات التجربة</Button></CardContent></Card></div>
  </AppShell>;
}
