"use client";

import { useState } from "react";
import { Printer } from "lucide-react";
import { applyServiceDayBulkAction } from "@/app/actions/commercial";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export type DailyRow = {
  id: string; service_date: string; status: string; subscription_number: number; customer_name: string; mobile: string | null;
  package_name: string; meal_plan_code: string | null; portion_multiplier: number; operations_note: string | null; meal_override: Record<string, unknown>;
  address_line: string | null; area: string | null; gps_url: string | null; delivery_notes: string | null; zone_name: string | null;
  delivery_window_start: string | null; delivery_window_end: string | null; breakfast: string | null; lunch: string | null; dinner: string | null;
  snack_1: string | null; snack_2: string | null;
};

function meals(row: DailyRow) {
  const plan = row.meal_plan_code;
  if (plan === "lunch") return [row.lunch];
  if (plan === "am") return [row.breakfast, row.lunch, row.snack_1];
  if (plan === "pm") return [row.lunch, row.dinner, row.snack_1];
  return [row.breakfast, row.lunch, row.dinner, row.snack_1, row.snack_2];
}

export function DailyOperationsTable({ rows, canOperate, canConfirm }: { rows: DailyRow[]; canOperate: boolean; canConfirm: boolean }) {
  const [selected, setSelected] = useState<string[]>([]);
  const allSelected = rows.length > 0 && selected.length === rows.length;
  return <div>
    <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border)] p-4 print:hidden">
      <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={allSelected} onChange={(event) => setSelected(event.target.checked ? rows.map((row) => row.id) : [])} />تحديد الكل ({selected.length})</label>
      <Button type="button" variant="secondary" size="sm" onClick={() => window.print()}><Printer size={16} />طباعة كشف الإنتاج والتوصيل</Button>
    </div>
    <form action={applyServiceDayBulkAction} className="print:hidden">
      {selected.map((id) => <input key={id} type="hidden" name="dayIds" value={id} />)}
      <div className="grid gap-3 border-b border-[var(--border)] bg-[var(--surface-muted)] p-4 md:grid-cols-[180px_100px_1fr_auto]">
        <select name="operation" required className="h-10 rounded-xl border border-[var(--border)] bg-white px-3 text-sm"><option value="">Bulk Action</option>{canOperate ? <><option value="skip">Skip اليوم + يوم بديل</option><option value="set_portions">تغيير عدد الحصص</option></> : null}{canConfirm ? <option value="confirm_delivered">Confirm Delivered</option> : null}</select>
        <input name="portions" type="number" min="1" max="20" defaultValue="1" aria-label="عدد الحصص" className="h-10 rounded-xl border border-[var(--border)] bg-white px-3 text-sm" />
        <input name="reason" placeholder="السبب أوتعليمات المطبخ (إلزامي للـSkip)" className="h-10 rounded-xl border border-[var(--border)] bg-white px-3 text-sm" />
        <div className="flex items-center gap-2"><label className="flex items-center gap-1 text-xs font-bold"><input name="confirm" type="checkbox" value="yes" required />تأكيد</label><Button type="submit" size="sm" disabled={!selected.length}>تنفيذ</Button></div>
      </div>
    </form>
    <div className="overflow-x-auto">
      <table className="w-full min-w-[1100px] text-sm">
        <thead className="bg-[var(--surface-muted)] text-xs text-[var(--text-muted)]"><tr><th className="p-3 print:hidden">اختيار</th><th className="p-3 text-start">المشترك</th><th className="p-3 text-start">الباقة والوجبات</th><th className="p-3 text-start">الحصص</th><th className="p-3 text-start">العنوان/Zone</th><th className="p-3 text-start">موعد التوصيل</th><th className="p-3 text-start">ملاحظات</th><th className="p-3 text-start">الحالة</th></tr></thead>
        <tbody className="divide-y divide-[var(--border)]">{rows.map((row) => <tr key={row.id} className={selected.includes(row.id) ? "bg-emerald-50/60" : ""}>
          <td className="p-3 print:hidden"><input type="checkbox" checked={selected.includes(row.id)} onChange={(event) => setSelected((current) => event.target.checked ? [...current, row.id] : current.filter((id) => id !== row.id))} /></td>
          <td className="p-3"><strong>{row.customer_name}</strong><span className="block text-xs text-[var(--text-muted)]">SUB-{row.subscription_number} · {row.mobile}</span></td>
          <td className="p-3"><strong>{row.package_name}</strong><span className="block max-w-72 text-xs leading-5 text-[var(--text-muted)]">{meals(row).filter(Boolean).join(" · ") || "المنيو غير مسجل"}</span></td>
          <td className="p-3 text-lg font-black">×{row.portion_multiplier}</td>
          <td className="p-3"><span>{row.address_line || "—"}</span><span className="block text-xs text-[var(--text-muted)]">{row.area} · {row.zone_name}</span>{row.gps_url ? <a href={row.gps_url} target="_blank" rel="noreferrer" className="text-xs text-[var(--primary)] underline print:hidden">GPS</a> : null}</td>
          <td className="p-3">{row.delivery_window_start?.slice(0, 5)}–{row.delivery_window_end?.slice(0, 5)}</td>
          <td className="max-w-64 p-3 text-xs leading-5">{[row.operations_note, row.delivery_notes, Object.keys(row.meal_override || {}).length ? JSON.stringify(row.meal_override) : null].filter(Boolean).join(" · ") || "—"}</td>
          <td className="p-3"><Badge tone={row.status === "confirmed_delivered" ? "success" : row.status === "planned" ? "info" : "warning"}>{row.status}</Badge></td>
        </tr>)}{!rows.length ? <tr><td colSpan={8} className="p-10 text-center text-[var(--text-muted)]">لا توجد توصيلات في هذا اليوم.</td></tr> : null}</tbody>
      </table>
    </div>
  </div>;
}
