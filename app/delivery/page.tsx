"use client";

import { useState } from "react";
import { Banknote, CheckCircle2, MapPin, Navigation, ShieldAlert } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { isFinanciallyBlocked, useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

const riders = ["كابتن أحمد", "كابتن سارة", "كابتن محمود"];

export default function DeliveryPage() {
  const { clients, subscriptions, fulfillmentDays, deliveries, assignRider, logCashCollection, markDelivered } = useERP();
  const [zone, setZone] = useState<number | "all">("all");
  const [collectionMethod, setCollectionMethod] = useState<Record<string, string>>({});
  const visible = deliveries.filter((item) => item.status !== "Delivered" && (zone === "all" || item.zone === zone));
  const cashTotal = visible.reduce((sum, item) => sum + (item.collectionLogged ? 0 : item.cashExpected), 0);

  return (
    <AppShell title="التوصيل" subtitle="Route بسيطة حسب Zone، والتحصيل ظاهر بوضوح للكابتن">
      <div className="mb-4 grid gap-3 sm:grid-cols-2">
        <div className="rounded-lg bg-[#17211b] p-4 text-white"><p className="text-xs text-white/70">مطلوب تحصيله الآن</p><p className="mt-1 text-3xl font-black">{cashTotal.toLocaleString("ar-EG")} ج</p></div>
        <div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">Stops المتبقية</p><p className="mt-1 text-3xl font-black">{visible.length}</p></div>
      </div>

      <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
        {["all", 1, 2, 3, 4].map((item) => <Button key={item} variant={zone === item ? "default" : "outline"} onClick={() => setZone(item as number | "all")} className="shrink-0">{item === "all" ? "كل المناطق" : `Zone ${item}`}</Button>)}
        <HelpTip text="الطلبات المعتمدة من المطبخ تتوزع حسب Zone 1–4. يمكن للكابتن التركيز على منطقته فقط." />
      </div>

      <div className="space-y-4">
        {visible.map((delivery, index) => {
          const client = clients.find((item) => item.id === delivery.clientId);
          const sub = subscriptions.find((item) => item.id === delivery.subscriptionId);
          const day = fulfillmentDays.find((item) => item.id === delivery.fulfillmentDayId);
          const blocked = sub ? isFinanciallyBlocked(sub) : false;
          const kitchenReady = day?.kitchenStatus === "Approved/Done";
          return (
            <Card key={delivery.id} className={blocked ? "border-red-200" : ""}>
              <CardContent className="pt-5">
                <div className="flex flex-col gap-4 lg:flex-row lg:justify-between">
                  <div className="flex min-w-0 gap-3">
                    <div className="flex size-12 shrink-0 items-center justify-center rounded-md bg-[#e5f5ec] font-black text-[#16794a]">{index + 1}</div>
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2"><h2 className="text-lg font-bold">{client?.name}</h2><Badge>Zone {delivery.zone}</Badge>{blocked ? <Badge variant="red">BLOCKED</Badge> : null}</div>
                      <p className="mt-1 text-sm font-semibold">{day?.meal ?? "وجبة جاهزة"} · {sub?.program}</p>
                      <p className="mt-1 text-sm text-[#66736b]">{client?.dietaryNotes}</p>
                      <a href={client?.locationUrl} target="_blank" rel="noreferrer" className="mt-3 inline-flex min-h-11 items-center gap-2 rounded-md bg-[#eef4f0] px-3 text-sm font-bold text-[#16794a]"><Navigation size={17} /> فتح الموقع</a>
                    </div>
                  </div>

                  <div className="grid gap-3 sm:grid-cols-2 lg:min-w-[500px]">
                    <div className="rounded-md border border-[#dce5df] p-3">
                      <label className="mb-2 block text-xs font-bold text-[#66736b]">الكابتن</label>
                      <select value={delivery.rider} onChange={(event) => assignRider(delivery.id, event.target.value)} className="min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm font-bold">
                        {riders.map((rider) => <option key={rider}>{rider}</option>)}
                      </select>
                    </div>
                    <div className={`rounded-md p-3 ${delivery.cashExpected > 0 ? "bg-blue-50" : "bg-[#f5f8f6]"}`}>
                      <div className="flex items-center gap-1 text-xs font-bold text-[#66736b]">التحصيل المطلوب <HelpTip text="في PayOnFirstDelivery يظهر كامل المبلغ المطلوب للكابتن في أول توصيل. تسجيل التحصيل يرسل تنبيهًا للحسابات." /></div>
                      <p className="mt-1 text-2xl font-black">{delivery.cashExpected.toLocaleString("ar-EG")} ج</p>
                      {delivery.cashExpected > 0 ? (
                        <div className="mt-2 flex gap-2">
                          <select value={collectionMethod[delivery.id] ?? "Cash"} onChange={(event) => setCollectionMethod((current) => ({ ...current, [delivery.id]: event.target.value }))} className="min-h-11 min-w-0 flex-1 rounded-md border border-blue-200 bg-white px-2 text-xs font-bold"><option>Cash</option><option>Card</option><option>InstaPay</option></select>
                          <Button onClick={() => logCashCollection(delivery.id)} disabled={delivery.collectionLogged}>{delivery.collectionLogged ? "تم التسجيل" : <><Banknote size={17} /> سجل التحصيل</>}</Button>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>

                {blocked ? <div className="mt-4 flex items-start gap-2 rounded-md bg-red-50 p-3 text-sm font-semibold text-red-800"><ShieldAlert size={19} className="shrink-0" /> متوقف حتى يؤكد Accounting الدفع.</div> : null}
                {!blocked && !kitchenReady ? <div className="mt-4 flex items-start gap-2 rounded-md bg-slate-100 p-3 text-sm font-semibold text-slate-700"><MapPin size={19} className="shrink-0" /> المطبخ لم يعتمد الوجبة بعد.</div> : null}
                <Button size="lg" className="mt-4 w-full min-h-14 text-base" disabled={blocked || !kitchenReady || delivery.status === "Delivered"} onClick={() => markDelivered(delivery.id)}><CheckCircle2 size={21} /> تم التسليم — خصم يوم من الاشتراك <HelpTip text="اضغط بعد التسليم الحقيقي فقط. سيزيد عدد الأيام المستهلكة يومًا واحدًا بشكل دائم في بيانات الـDemo." /></Button>
              </CardContent>
            </Card>
          );
        })}
        {visible.length === 0 ? <div className="rounded-lg border border-[#dce5df] bg-white p-8 text-center text-[#66736b]">لا توجد Stops متبقية في الاختيار الحالي.</div> : null}
      </div>
    </AppShell>
  );
}
