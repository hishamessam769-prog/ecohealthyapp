import { CheckCircle2, Clock3, CookingPot, LockKeyhole } from "lucide-react";
import type { KitchenQueueRow } from "@/lib/data";

type KitchenQueueProps = {
  rows: KitchenQueueRow[];
};

const statusMap = {
  waiting: {
    label: "في الانتظار",
    className: "bg-slate-100 text-slate-700",
    icon: Clock3,
  },
  preparing: {
    label: "جاري التحضير",
    className: "bg-blue-50 text-blue-700",
    icon: CookingPot,
  },
  done: {
    label: "تم التحضير",
    className: "bg-[#e5f5ec] text-[#0f603a]",
    icon: CheckCircle2,
  },
};

function mealTypeLabel(type: string) {
  if (type === "lc") return "LC";
  if (type === "high_protein") return "High Protein";
  if (type === "standard") return "Standard";
  return type;
}

function StatusBadge({ status }: { status: KitchenQueueRow["status"] }) {
  const item = statusMap[status];
  const Icon = item.icon;

  return (
    <span className={`inline-flex min-h-8 items-center gap-1.5 px-2.5 text-xs font-bold ${item.className}`}>
      <Icon size={15} aria-hidden="true" />
      {item.label}
    </span>
  );
}

export function KitchenQueue({ rows }: KitchenQueueProps) {
  if (!rows.length) {
    return (
      <div className="border border-[#dce5df] bg-white px-5 py-14 text-center">
        <CookingPot size={34} className="mx-auto text-[#879189]" aria-hidden="true" />
        <h2 className="mt-4 text-lg font-bold text-[#253129]">لا يوجد إنتاج مسجل لبكرة</h2>
        <p className="mt-2 text-sm text-[#6d786f]">عند قفل اليوم ستظهر الوجبات هنا تلقائياً.</p>
      </div>
    );
  }

  return (
    <>
      <div className="space-y-3 lg:hidden">
        {rows.map((row, index) => (
          <article key={row.id} className="border border-[#dce5df] bg-white p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="flex min-w-0 gap-3">
                <div className="flex h-10 min-w-10 items-center justify-center bg-[#17211b] text-sm font-bold text-white">
                  {(index + 1).toLocaleString("ar-EG")}
                </div>
                <div className="min-w-0">
                  <h2 className="truncate font-bold text-[#17211b]">{row.client_name_snapshot}</h2>
                  <p className="mt-1 truncate text-xs text-[#6a756e]">{row.program_name_snapshot}</p>
                </div>
              </div>
              {row.locked ? <LockKeyhole size={18} className="shrink-0 text-[#16794a]" aria-label="مقفول" /> : null}
            </div>

            <div className="mt-4 grid grid-cols-2 gap-px bg-[#dce5df] border border-[#dce5df]">
              <div className="bg-[#f8faf9] p-3">
                <p className="text-[11px] text-[#768078]">الوجبة</p>
                <p className="mt-1 text-sm font-bold">{row.meal_name_snapshot}</p>
              </div>
              <div className="bg-[#f8faf9] p-3">
                <p className="text-[11px] text-[#768078]">النوع / الكمية</p>
                <p className="mt-1 text-sm font-bold">
                  {mealTypeLabel(row.meal_type)} · {row.quantity.toLocaleString("ar-EG")}
                </p>
              </div>
            </div>

            <div className="mt-4 flex items-center justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate text-xs font-medium text-[#59665e]">{row.area_snapshot || "بدون منطقة"}</p>
                {row.delivery_note_snapshot ? (
                  <p className="mt-1 truncate text-[11px] text-[#818a84]">{row.delivery_note_snapshot}</p>
                ) : null}
              </div>
              <StatusBadge status={row.status} />
            </div>
          </article>
        ))}
      </div>

      <div className="hidden overflow-hidden border border-[#dce5df] bg-white lg:block">
        <table className="w-full border-collapse text-right">
          <thead className="bg-[#f1f5f2] text-xs text-[#59665e]">
            <tr>
              <th className="px-4 py-4 font-bold">#</th>
              <th className="px-4 py-4 font-bold">العميل</th>
              <th className="px-4 py-4 font-bold">البرنامج</th>
              <th className="px-4 py-4 font-bold">الوجبة</th>
              <th className="px-4 py-4 font-bold">النوع</th>
              <th className="px-4 py-4 font-bold">الكمية</th>
              <th className="px-4 py-4 font-bold">المنطقة</th>
              <th className="px-4 py-4 font-bold">الحالة</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#e7ede9]">
            {rows.map((row, index) => (
              <tr key={row.id} className="hover:bg-[#fafcfb]">
                <td className="px-4 py-4 text-sm font-bold text-[#78827c]">{(index + 1).toLocaleString("ar-EG")}</td>
                <td className="px-4 py-4">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-[#17211b]">{row.client_name_snapshot}</span>
                    {row.locked ? <LockKeyhole size={14} className="text-[#16794a]" aria-label="مقفول" /> : null}
                  </div>
                  {row.delivery_note_snapshot ? (
                    <p className="mt-1 max-w-48 truncate text-xs text-[#7a857e]">{row.delivery_note_snapshot}</p>
                  ) : null}
                </td>
                <td className="px-4 py-4 text-sm text-[#4d5a52]">{row.program_name_snapshot}</td>
                <td className="px-4 py-4 text-sm font-semibold text-[#253129]">{row.meal_name_snapshot}</td>
                <td className="px-4 py-4 text-sm text-[#4d5a52]">{mealTypeLabel(row.meal_type)}</td>
                <td className="px-4 py-4 text-lg font-bold text-[#17211b]">{row.quantity.toLocaleString("ar-EG")}</td>
                <td className="px-4 py-4 text-sm text-[#4d5a52]">{row.area_snapshot || "-"}</td>
                <td className="px-4 py-4"><StatusBadge status={row.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

