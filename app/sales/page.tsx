"use client";

import { CircleDollarSign, LockKeyhole, TrendingUp } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { commissionRate, useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const tiers = [
  ["أقل من 80%", "0%"],
  ["80% إلى أقل من 100%", "3%"],
  ["100% إلى أقل من 120%", "3.5%"],
  ["120% إلى 150%", "4%"],
  ["أكثر من 150%", "5%"],
];

export default function SalesPage() {
  const { clients, subscriptions, salesReps } = useERP();

  return (
    <AppShell title="المبيعات والعمولات" subtitle="Target مقابل الإيراد المؤكد ونسبة العمولة تلقائيًا">
      <div className="mb-4 flex items-center gap-1 rounded-lg border border-blue-200 bg-blue-50 p-4 text-sm font-semibold text-blue-900"><LockKeyhole className="shrink-0" size={20} /> الإيراد لا يصبح Confirmed إلا بعد استهلاك العميل أكثر من 50% من أيام الاشتراك. <HelpTip text="هذا يمنع احتساب عمولة كاملة على اشتراك قد يتوقف مبكرًا. الشرط هو أكثر من النصف، وليس نصف الأيام بالضبط." /></div>

      <div className="grid gap-4 xl:grid-cols-2">
        {salesReps.map((rep) => {
          const repSubs = subscriptions.filter((sub) => sub.salesRepId === rep.id && sub.status !== "Canceled");
          const confirmed = repSubs.filter((sub) => sub.consumedDays / sub.totalDays > 0.5);
          const achieved = confirmed.reduce((sum, sub) => sum + sub.totalPrice, 0);
          const percent = rep.target > 0 ? (achieved / rep.target) * 100 : 0;
          const rate = commissionRate(percent);
          const commission = achieved * (rate / 100);
          return (
            <Card key={rep.id}>
              <CardHeader><div className="flex items-center justify-between gap-3"><div><p className="text-xs font-bold text-[#66736b]">Sales Rep</p><CardTitle className="mt-1">{rep.name}</CardTitle></div><div className="flex size-12 items-center justify-center rounded-md bg-[#e5f5ec] text-[#16794a]"><TrendingUp size={25} /></div></div></CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 gap-3">
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#66736b]">Target</p><p className="mt-1 text-lg font-black">{rep.target.toLocaleString("ar-EG")} ج</p></div>
                  <div className="rounded-md bg-[#e5f5ec] p-3"><p className="text-xs text-[#0f603a]">Confirmed Revenue</p><p className="mt-1 text-lg font-black text-[#0f603a]">{achieved.toLocaleString("ar-EG")} ج</p></div>
                </div>
                <div className="mt-4 h-3 overflow-hidden rounded-full bg-[#e7ede9]"><div className="h-full rounded-full bg-[#16794a]" style={{ width: `${Math.min(percent, 100)}%` }} /></div>
                <div className="mt-2 flex items-center justify-between text-sm"><span className="font-bold">Achievement: {percent.toFixed(1)}%</span><Badge variant={rate > 0 ? "default" : "gray"}>Commission {rate}%</Badge></div>
                <div className="mt-4 flex items-center justify-between rounded-md border border-[#dce5df] p-4"><span className="font-bold">العمولة الحالية</span><span className="text-xl font-black text-[#16794a]">{commission.toLocaleString("ar-EG", { maximumFractionDigits: 2 })} ج</span></div>
                <p className="mt-3 text-xs text-[#7b867f]">{confirmed.length} من {repSubs.length} اشتراك فتح الإيراد المؤكد.</p>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card className="mt-4">
        <CardHeader><div className="flex items-center gap-2"><CircleDollarSign className="text-[#16794a]" size={22} /><CardTitle>شرائح العمولة</CardTitle><HelpTip text="النظام يختار الشريحة تلقائيًا من نسبة تحقيق Target باستخدام الإيراد المؤكد فقط." /></div></CardHeader>
        <CardContent className="grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
          {tiers.map(([range, rate]) => <div key={range} className="rounded-md bg-[#f5f8f6] p-4 text-center"><p className="text-xs font-semibold text-[#66736b]">{range}</p><p className="mt-2 text-2xl font-black text-[#16794a]">{rate}</p></div>)}
        </CardContent>
      </Card>

      <Card className="mt-4">
        <CardHeader><CardTitle>حالة اشتراكات المبيعات</CardTitle></CardHeader>
        <CardContent className="space-y-2">
          {subscriptions.filter((sub) => sub.status !== "Canceled").map((sub) => {
            const client = clients.find((item) => item.id === sub.clientId);
            const unlocked = sub.consumedDays / sub.totalDays > 0.5;
            return <div key={sub.id} className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-[#e4ebe6] p-3 text-sm"><div><span className="font-bold">{client?.name}</span><span className="text-[#66736b]"> · {sub.program} · {sub.consumedDays}/{sub.totalDays} يوم</span></div><Badge variant={unlocked ? "default" : "gray"}>{unlocked ? `${sub.totalPrice.toLocaleString("ar-EG")} ج Confirmed` : "Locked"}</Badge></div>;
          })}
        </CardContent>
      </Card>
    </AppShell>
  );
}
