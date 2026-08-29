"use client";
import { useMemo, useState } from "react";
import { CalendarDays, Save } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { useERP } from "@/components/erp-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import type { MealSlot } from "@/lib/erp-types";

const slots: MealSlot[] = ["Breakfast", "Lunch", "Dinner", "Snack"];
const slotLabels: Record<MealSlot, string> = { Breakfast: "الفطار", Lunch: "الغداء", Dinner: "العشاء", Snack: "السناك" };
export default function MenuPage() {
  const erp = useERP(); const [month, setMonth] = useState(new Date().toISOString().slice(0, 7)); const [message, setMessage] = useState("");
  const days = useMemo(() => { const [y, m] = month.split("-").map(Number); const count = new Date(y, m, 0).getDate(); return Array.from({ length: count }, (_, i) => `${month}-${String(i + 1).padStart(2, "0")}`); }, [month]);
  async function change(date: string, slot: MealSlot, mealId: string) { const result = await erp.upsertMenu(date, slot, mealId); setMessage(result.message); }
  return <AppShell title="منيو الشهر" subtitle="حدد وجبة كل يوم؛ الاشتراكات الجديدة تقرأ الجدول تلقائيًا" actions={<div className="flex items-center gap-2"><CalendarDays size={18}/><input type="month" value={month} onChange={(e) => setMonth(e.target.value)} className="field min-h-11"/></div>}>
    <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-blue-200 bg-blue-50 p-4 text-sm text-blue-900"><p><b>طريقة الاستخدام:</b> اختر الوجبة في كل خانة. الحفظ تلقائي، وأي Meal Swap لاحق يغيّر العميل المحدد فقط.</p>{message ? <span className="inline-flex items-center gap-1 font-bold text-[#0f603a]"><Save size={16}/>{message}</span> : null}</div>
    <Card><CardContent className="p-0"><div className="overflow-x-auto"><table className="w-full min-w-[920px] text-sm"><thead className="sticky top-[69px] z-10 bg-[#e8f1eb] text-right"><tr><th className="p-3">اليوم</th>{slots.map((slot) => <th key={slot} className="p-3">{slotLabels[slot]}</th>)}</tr></thead><tbody>{days.map((date) => { const d = new Date(`${date}T12:00:00`); const friday = d.getDay() === 5; return <tr key={date} className={`border-t ${friday ? "bg-slate-100 text-slate-500" : "bg-white"}`}><td className="p-3"><b>{d.toLocaleDateString("ar-EG", { weekday: "long", day: "numeric" })}</b>{friday ? <small className="mr-2">إجازة</small> : null}</td>{slots.map((slot) => { const current = erp.menu.find((x) => x.date === date && x.slot === slot)?.mealId ?? ""; const meals = erp.meals.filter((x) => x.slot === slot && x.active); return <td key={slot} className="p-2"><select value={current} onChange={(e) => change(date, slot, e.target.value)} disabled={friday} className="field min-h-10 w-full"><option value="">اختر</option>{meals.map((meal) => <option key={meal.id} value={meal.id}>{meal.name}</option>)}</select></td>; })}</tr>; })}</tbody></table></div></CardContent></Card>
  </AppShell>;
}
