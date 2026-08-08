import type { LucideIcon } from "lucide-react";

type StatCardProps = {
  title: string;
  value: number;
  note: string;
  icon: LucideIcon;
  tone?: "green" | "blue" | "orange" | "gray";
};

const tones = {
  green: "bg-[#e5f5ec] text-[#16794a]",
  blue: "bg-blue-50 text-blue-700",
  orange: "bg-orange-50 text-orange-700",
  gray: "bg-slate-100 text-slate-700",
};

export function StatCard({
  title,
  value,
  note,
  icon: Icon,
  tone = "green",
}: StatCardProps) {
  return (
    <div className="border border-[#dce5df] bg-white p-5">
      <div className="mb-5 flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-[#66736b]">{title}</p>
          <p className="mt-2 text-3xl font-bold tracking-tight text-[#17211b]">
            {value.toLocaleString("ar-EG")}
          </p>
        </div>
        <div className={`flex h-11 w-11 items-center justify-center ${tones[tone]}`}>
          <Icon size={22} strokeWidth={2} aria-hidden="true" />
        </div>
      </div>
      <p className="border-t border-[#edf1ee] pt-3 text-xs leading-5 text-[#66736b]">
        {note}
      </p>
    </div>
  );
}

