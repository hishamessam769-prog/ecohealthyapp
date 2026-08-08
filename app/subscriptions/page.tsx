"use client";

import { useMemo, useState } from "react";
import { CirclePause, CirclePlay, RefreshCw, XCircle } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { calculateCancellation, isFinanciallyBlocked, useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import type { MealType } from "@/lib/erp-types";

type ModalMode = "swap" | "cancel" | null;

export default function SubscriptionsPage() {
  const { clients, subscriptions, fulfillmentDays, togglePause, swapMeal, requestCancellation, cancellations } = useERP();
  const [filter, setFilter] = useState("All");
  const [selectedSubId, setSelectedSubId] = useState<string | null>(null);
  const [mode, setMode] = useState<ModalMode>(null);
  const [selectedDayId, setSelectedDayId] = useState("");
  const [meal, setMeal] = useState("");
  const [mealType, setMealType] = useState<MealType>("LC");
  const [message, setMessage] = useState("");

  const shown = useMemo(() => subscriptions.filter((item) => filter === "All" || item.status === filter), [subscriptions, filter]);
  const selectedSub = subscriptions.find((item) => item.id === selectedSubId);
  const selectedClient = clients.find((item) => item.id === selectedSub?.clientId);
  const selectedDays = fulfillmentDays.filter((item) => item.subscriptionId === selectedSubId).sort((a, b) => a.date.localeCompare(b.date));
  const cancellation = selectedSub ? calculateCancellation(selectedSub) : null;

  function openSwap(id: string) {
    const days = fulfillmentDays.filter((item) => item.subscriptionId === id);
    setSelectedSubId(id);
    setMode("swap");
    setSelectedDayId(days[0]?.id ?? "");
    setMeal(days[0]?.meal ?? "");
    setMealType(days[0]?.mealType ?? "LC");
    setMessage("");
  }

  function closeModal() {
    setMode(null);
    setSelectedSubId(null);
    setMessage("");
  }

  function handleSwap() {
    if (!selectedDayId || !meal.trim()) return;
    swapMeal(selectedDayId, meal.trim(), mealType);
    setMessage("تم تعديل يوم التنفيذ فقط. قيمة الفاتورة الأصلية لم تتغير.");
  }

  function handleCancel() {
    if (!selectedSubId) return;
    const result = requestCancellation(selectedSubId);
    setMessage(result ? "تم إرسال طلب الإلغاء للحسابات للمراجعة." : "يوجد طلب إلغاء مفتوح بالفعل لهذا الاشتراك.");
  }

  return (
    <AppShell title="الاشتراكات" subtitle="إدارة الأيام والتوقف والوجبات بدون تغيير العقد المالي">
      <div className="mb-4 flex flex-wrap gap-2">
        {["All", "Active", "Paused", "Finished", "Canceled"].map((item) => <Button key={item} size="sm" variant={filter === item ? "default" : "outline"} onClick={() => setFilter(item)}>{item === "All" ? "الكل" : item}</Button>)}
      </div>

      <div className="space-y-4">
        {shown.map((sub) => {
          const client = clients.find((item) => item.id === sub.clientId);
          const remaining = Math.max(sub.totalDays - sub.consumedDays, 0);
          const blocked = isFinanciallyBlocked(sub);
          const hasOpenCancellation = cancellations.some((item) => item.subscriptionId === sub.id && item.status !== "Transferred");
          return (
            <Card key={sub.id}>
              <CardContent className="pt-5">
                <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-bold">{client?.name}</h2>
                      <Badge variant={sub.status === "Active" ? "default" : sub.status === "Paused" ? "orange" : "gray"}>{sub.status}</Badge>
                      {blocked ? <Badge variant="red">BLOCKED</Badge> : null}
                    </div>
                    <p className="mt-1 text-sm font-semibold text-[#536158]">{sub.program} · #{sub.id.toUpperCase()}</p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {(sub.status === "Active" || sub.status === "Paused") ? (
                      <Button variant="outline" size="sm" onClick={() => togglePause(sub.id)}>{sub.status === "Paused" ? <CirclePlay size={16} /> : <CirclePause size={16} />}{sub.status === "Paused" ? "استئناف" : "إيقاف مؤقت"}<HelpTip text="الإيقاف المؤقت يوقف أيام التنفيذ المستقبلية ولا يحذف الاشتراك أو الفاتورة." /></Button>
                    ) : null}
                    {sub.status === "Active" && !blocked ? <Button variant="outline" size="sm" onClick={() => openSwap(sub.id)}><RefreshCw size={16} /> Meal Swap <HelpTip text="غيّر وجبة يوم مستقبلي فقط. التعديل يذهب لسجل التنفيذ ولا يغيّر فاتورة البيع." /></Button> : null}
                    {(sub.status === "Active" || sub.status === "Paused") ? <Button variant="destructive" size="sm" onClick={() => { setSelectedSubId(sub.id); setMode("cancel"); setMessage(""); }}><XCircle size={16} /> طلب إلغاء <HelpTip text="يحسِب المبلغ المسترد تلقائيًا ثم يرسل الطلب للحسابات. لا يتم الإلغاء النهائي قبل التحويل." /></Button> : null}
                  </div>
                </div>

                <div className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">الأيام</p><p className="mt-1 font-bold">{sub.consumedDays} مستهلك / {sub.totalDays}</p></div>
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">المتبقي</p><p className="mt-1 font-bold text-[#16794a]">{remaining} يوم</p></div>
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">التوصيل</p><p className="mt-1 font-bold">{sub.deliveryType}{sub.weeklyDay ? ` · ${sub.weeklyDay}` : ""}</p></div>
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">الدفع</p><p className="mt-1 font-bold">{sub.paymentType}</p></div>
                  <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">قيمة العقد</p><p className="mt-1 font-bold">{sub.totalPrice.toLocaleString("ar-EG")} ج</p></div>
                </div>
                {blocked ? <p className="mt-3 rounded-md bg-red-50 p-3 text-sm font-semibold text-red-800">استلم أول طلب ولم يؤكد Accounting الدفع؛ لن يدخل أي طلب جديد للمطبخ أو التوصيل.</p> : null}
                {hasOpenCancellation ? <p className="mt-3 rounded-md bg-blue-50 p-3 text-sm font-semibold text-blue-800">يوجد طلب إلغاء مفتوح بانتظار الحسابات.</p> : null}
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Dialog open={mode === "swap"} onOpenChange={(open) => !open && closeModal()}>
        <DialogContent>
          <DialogHeader><DialogTitle>Meal Swap — {selectedClient?.name}</DialogTitle><DialogDescription>اختر يومًا مستقبليًا وعدّل وجبته فقط.</DialogDescription></DialogHeader>
          {selectedDays.length > 0 ? (
            <>
              <label className="mb-2 block text-sm font-bold">يوم التنفيذ</label>
              <select value={selectedDayId} onChange={(event) => { const next = selectedDays.find((day) => day.id === event.target.value); setSelectedDayId(event.target.value); setMeal(next?.meal ?? ""); setMealType(next?.mealType ?? "LC"); }} className="min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm">
                {selectedDays.map((day) => <option key={day.id} value={day.id}>{day.date} · Day {day.dayNumber} · {day.meal}</option>)}
              </select>
              <label className="mb-2 mt-4 block text-sm font-bold">الوجبة الجديدة</label>
              <Input value={meal} onChange={(event) => setMeal(event.target.value)} />
              <label className="mb-2 mt-4 block text-sm font-bold">نوع الوجبة</label>
              <select value={mealType} onChange={(event) => setMealType(event.target.value as MealType)} className="min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm"><option>Standard</option><option>LC</option><option>High Protein</option></select>
              <Button className="mt-5 w-full" onClick={handleSwap}>حفظ التبديل</Button>
            </>
          ) : <p className="rounded-md bg-[#f5f8f6] p-4 text-sm text-[#66736b]">لا يوجد يوم تنفيذ مستقبلي متاح لهذا الاشتراك في بيانات الـDemo.</p>}
          {message ? <p className="mt-3 rounded-md bg-[#e5f5ec] p-3 text-sm font-semibold text-[#0f603a]">{message}</p> : null}
        </DialogContent>
      </Dialog>

      <Dialog open={mode === "cancel"} onOpenChange={(open) => !open && closeModal()}>
        <DialogContent>
          <DialogHeader><DialogTitle>حاسبة الإلغاء — {selectedClient?.name}</DialogTitle><DialogDescription>المعادلة تطبق آليًا قبل إرسال الطلب إلى Accounting.</DialogDescription></DialogHeader>
          {cancellation ? <div className="space-y-2 text-sm">
            <div className="flex justify-between rounded-md bg-[#f5f8f6] p-3"><span>Remaining Value</span><strong>{cancellation.remainingValue.toFixed(2)} ج</strong></div>
            <div className="flex justify-between rounded-md bg-[#f5f8f6] p-3"><span>20% من القيمة المستهلكة</span><strong>- {cancellation.consumedPenalty.toFixed(2)} ج</strong></div>
            <div className="flex justify-between rounded-md bg-[#f5f8f6] p-3"><span>30 ج × أيام التوصيل</span><strong>- {cancellation.deliveryPenalty.toFixed(2)} ج</strong></div>
            <div className="flex justify-between rounded-md bg-[#e5f5ec] p-4 text-base text-[#0f603a]"><span className="font-bold">Refund النهائي</span><strong>{cancellation.refundAmount.toFixed(2)} ج</strong></div>
          </div> : null}
          <Button className="mt-5 w-full" variant="destructive" onClick={handleCancel}>إرسال طلب الإلغاء للحسابات</Button>
          {message ? <p className="mt-3 rounded-md bg-blue-50 p-3 text-sm font-semibold text-blue-800">{message}</p> : null}
        </DialogContent>
      </Dialog>
    </AppShell>
  );
}
