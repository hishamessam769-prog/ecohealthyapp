"use client";

import { CheckCircle2, ChefHat, LockKeyhole, ShieldAlert, UtensilsCrossed } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { isFinanciallyBlocked, useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { KitchenStatus } from "@/lib/erp-types";

const statusOptions: KitchenStatus[] = ["Pending", "In Prep", "Approved/Done"];
const statusLabels: Record<KitchenStatus, string> = { Pending: "Pending", "In Prep": "In Prep", "Approved/Done": "Approved / Done" };

export default function KitchenPage() {
  const { role, clients, subscriptions, fulfillmentDays, setKitchenStatus, addVipAfterCutoff } = useERP();
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowKey = tomorrow.toISOString().slice(0, 10);
  const allTomorrow = fulfillmentDays.filter((item) => item.date === tomorrowKey);
  const blocked = allTomorrow.filter((day) => {
    const sub = subscriptions.find((item) => item.id === day.subscriptionId);
    return sub ? isFinanciallyBlocked(sub) : false;
  });
  const production = allTomorrow.filter((day) => !blocked.some((blockedDay) => blockedDay.id === day.id));
  const aggregate = Object.values(production.reduce<Record<string, { key: string; meal: string; mealType: string; count: number }>>((acc, day) => {
    const key = `${day.meal}__${day.mealType}`;
    acc[key] = acc[key] ? { ...acc[key], count: acc[key].count + 1 } : { key, meal: day.meal, mealType: day.mealType, count: 1 };
    return acc;
  }, {}));
  const done = production.filter((item) => item.kitchenStatus === "Approved/Done").length;

  return (
    <AppShell title="المطبخ — قائمة بكرة" subtitle="Checklist واضح للمطبخ، ومصمم للموبايل واللمس السريع">
      <div className="mb-4 grid gap-3 sm:grid-cols-3">
        <div className="flex items-center gap-3 rounded-lg bg-[#17211b] p-4 text-white"><LockKeyhole size={26} /><div><p className="text-xs text-white/70">Production Cut-off</p><p className="font-bold">مقفول · 17:00</p></div><HelpTip text="عند 17:00 النظام يثبت تلقائيًا قائمة إنتاج الغد من الاشتراكات الفعالة." /></div>
        <div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">إجمالي وجبات مسموحة</p><p className="mt-1 text-2xl font-black">{production.length}</p></div>
        <div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">تمت الموافقة</p><p className="mt-1 text-2xl font-black text-[#16794a]">{done}/{production.length}</p></div>
      </div>

      {role === "admin" ? (
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-blue-200 bg-blue-50 p-4">
          <div><p className="font-bold text-blue-900">Admin Override بعد Cut-off</p><p className="mt-1 text-xs text-blue-800">لإضافة VIP طارئ، وسيصل تنبيه للمطبخ فورًا.</p></div>
          <div className="flex items-center gap-1"><Button onClick={addVipAfterCutoff}>إضافة VIP طارئ</Button><HelpTip text="استثناء إداري بعد الإغلاق. يضيف الوجبة للقائمة ويرسل تنبيهًا للمطبخ لتحديث الكمية." /></div>
        </div>
      ) : null}

      {blocked.length > 0 ? (
        <div className="mb-4 flex items-start gap-3 rounded-lg border border-red-200 bg-red-50 p-4 text-red-800"><ShieldAlert className="shrink-0" size={22} /><div><p className="font-bold">{blocked.length} طلب مستبعد ماليًا من الإنتاج</p><p className="mt-1 text-sm">PayOnFirstDelivery غير مؤكد. الحسابات يجب أن تؤكد الدفع أولًا.</p></div></div>
      ) : null}

      <Tabs defaultValue="aggregate">
        <TabsList className="w-full sm:w-auto"><TabsTrigger value="aggregate" className="flex-1 sm:flex-none">الكميات المجمعة</TabsTrigger><TabsTrigger value="labels" className="flex-1 sm:flex-none">ملصقات العملاء</TabsTrigger></TabsList>

        <TabsContent value="aggregate">
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {aggregate.map((item) => <Card key={item.key}><CardContent className="flex items-center gap-4 pt-5"><div className="flex size-14 shrink-0 items-center justify-center rounded-md bg-[#e5f5ec] text-[#16794a]"><ChefHat size={27} /></div><div className="min-w-0"><p className="text-3xl font-black">{item.count}×</p><p className="truncate font-bold">{item.meal}</p><Badge className="mt-2" variant={item.mealType === "LC" ? "blue" : "gray"}>{item.mealType}</Badge></div></CardContent></Card>)}
          </div>
        </TabsContent>

        <TabsContent value="labels">
          <div className="space-y-3">
            {production.map((day) => {
              const sub = subscriptions.find((item) => item.id === day.subscriptionId);
              const client = clients.find((item) => item.id === sub?.clientId);
              return (
                <Card key={day.id} className={day.kitchenStatus === "Approved/Done" ? "border-[#94cfad] bg-[#f4fbf7]" : ""}>
                  <CardContent className="pt-5">
                    <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                      <div className="flex min-w-0 items-start gap-3">
                        <div className="flex size-12 shrink-0 items-center justify-center rounded-md bg-[#eef4f0] text-[#16794a]">{day.kitchenStatus === "Approved/Done" ? <CheckCircle2 size={25} /> : <UtensilsCrossed size={24} />}</div>
                        <div><div className="flex flex-wrap items-center gap-2"><p className="text-lg font-bold">{client?.name}</p><Badge>Zone {day.zone}</Badge>{day.manualOverride ? <Badge variant="blue">VIP Override</Badge> : null}</div><p className="mt-1 font-semibold">{day.meal} · {day.mealType}</p><p className="mt-1 text-sm text-[#66736b]">Day {day.dayNumber} · {client?.dietaryNotes}</p></div>
                      </div>
                      <div className="grid grid-cols-3 gap-2 lg:min-w-[420px]">
                        {statusOptions.map((status) => <Button key={status} size="lg" variant={day.kitchenStatus === status ? "default" : "outline"} className="min-h-14 px-2 text-xs sm:text-sm" onClick={() => setKitchenStatus(day.id, status)}>{statusLabels[status]}</Button>)}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </TabsContent>
      </Tabs>
    </AppShell>
  );
}
