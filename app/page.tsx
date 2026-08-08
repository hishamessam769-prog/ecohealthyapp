"use client";

import Link from "next/link";
import { AlertTriangle, Bike, ChefHat, CircleDollarSign, Salad, Users } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { useERP, isFinanciallyBlocked } from "@/components/erp-provider";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const modules = [
  { href: "/clients", label: "العملاء", description: "البيانات والشكاوى", icon: Users },
  { href: "/subscriptions", label: "الاشتراكات", description: "الأيام والتوقف وMeal Swap", icon: Salad },
  { href: "/kitchen", label: "المطبخ", description: "قائمة إنتاج الغد", icon: ChefHat },
  { href: "/delivery", label: "التوصيل", description: "Zones والتحصيل", icon: Bike },
  { href: "/accounting", label: "الحسابات", description: "الدفع والإلغاءات", icon: CircleDollarSign },
];

export default function DashboardPage() {
  const { clients, subscriptions, fulfillmentDays, deliveries, notifications } = useERP();
  const active = subscriptions.filter((item) => item.status === "Active").length;
  const blocked = subscriptions.filter(isFinanciallyBlocked).length;
  const delivered = deliveries.filter((item) => item.status === "Delivered").length;
  const unread = notifications.filter((item) => !item.read).length;

  return (
    <AppShell title="لوحة التشغيل" subtitle="صورة سريعة وواضحة عن اليوم">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {[
          ["عملاء", clients.length, "إجمالي العملاء"],
          ["اشتراكات نشطة", active, "تعمل الآن"],
          ["وجبات بكرة", fulfillmentDays.length, "في سجل التنفيذ"],
          ["تنبيهات", unread, "تحتاج متابعة"],
        ].map(([label, value, note]) => (
          <Card key={label}>
            <CardContent className="pt-5">
              <p className="text-sm font-semibold text-[#66736b]">{label}</p>
              <p className="mt-2 text-3xl font-black text-[#17211b]">{value}</p>
              <p className="mt-1 text-xs text-[#8a958e]">{note}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {blocked > 0 ? (
        <Link href="/accounting" className="mt-5 flex items-start gap-3 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800">
          <AlertTriangle className="mt-0.5 shrink-0" size={22} />
          <div><p className="font-bold">{blocked} اشتراك محظور ماليًا</p><p className="mt-1 text-sm">مطلوب تأكيد PayOnFirstDelivery قبل إنتاج أي يوم جديد.</p></div>
        </Link>
      ) : null}

      <Card className="mt-5">
        <CardHeader><CardTitle>ابدأ من هنا</CardTitle></CardHeader>
        <CardContent className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
          {modules.map(({ href, label, description, icon: Icon }) => (
            <Link key={href} href={href} className="rounded-lg border border-[#dce5df] bg-white p-4 transition-colors hover:bg-[#f5faf7]">
              <Icon size={25} className="text-[#16794a]" />
              <p className="mt-3 font-bold text-[#17211b]">{label}</p>
              <p className="mt-1 text-xs leading-5 text-[#66736b]">{description}</p>
            </Link>
          ))}
        </CardContent>
      </Card>

      <Card className="mt-5">
        <CardHeader><CardTitle>حالة التشغيل اليوم</CardTitle></CardHeader>
        <CardContent className="grid gap-3 sm:grid-cols-3">
          <div className="rounded-md bg-[#eef4f0] p-4"><p className="text-sm text-[#66736b]">توصيلات مكتملة</p><p className="mt-1 text-2xl font-bold">{delivered}/{deliveries.length}</p></div>
          <div className="rounded-md bg-[#eef4f0] p-4"><p className="text-sm text-[#66736b]">قائمة المطبخ</p><p className="mt-1 text-2xl font-bold">مقفولة</p></div>
          <div className="rounded-md bg-[#eef4f0] p-4"><p className="text-sm text-[#66736b]">موعد Cut-off</p><p className="mt-1 text-2xl font-bold">17:00</p></div>
        </CardContent>
      </Card>
    </AppShell>
  );
}
