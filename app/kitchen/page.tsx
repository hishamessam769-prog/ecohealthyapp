import Link from "next/link";
import { LockKeyhole, RefreshCw } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { KitchenQueue } from "@/components/kitchen-queue";
import { cairoDate, getKitchenQueue } from "@/lib/data";

export const dynamic = "force-dynamic";

function formatArabicDate(dateValue: string) {
  return new Intl.DateTimeFormat("ar-EG", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "Africa/Cairo",
  }).format(new Date(`${dateValue}T12:00:00Z`));
}

export default async function KitchenPage() {
  const rows = await getKitchenQueue();
  const productionDate = cairoDate(1);

  const waiting = rows.filter((row) => row.status === "waiting").length;
  const preparing = rows.filter((row) => row.status === "preparing").length;
  const done = rows.filter((row) => row.status === "done").length;

  return (
    <AppShell
      active="kitchen"
      title="طابور المطبخ"
      subtitle="قائمة إنتاج بكرة — بسيطة ومقفولة للعرض"
    >
      <section className="mb-4 border-r-4 border-[#16794a] bg-[#e5f5ec] px-4 py-4 sm:flex sm:items-center sm:justify-between sm:gap-4">
        <div className="flex items-start gap-3">
          <LockKeyhole size={21} className="mt-0.5 shrink-0 text-[#0f603a]" aria-hidden="true" />
          <div>
            <p className="font-bold text-[#10462f]">قائمة الإنتاج المقفولة</p>
            <p className="mt-1 text-sm text-[#37604a]">{formatArabicDate(productionDate)}</p>
          </div>
        </div>
        <Link
          href="/kitchen"
          className="mt-3 inline-flex min-h-11 items-center justify-center gap-2 border border-[#b8dac6] bg-white px-4 text-sm font-bold text-[#0f603a] hover:bg-[#f7fbf8] sm:mt-0"
        >
          <RefreshCw size={17} aria-hidden="true" />
          تحديث
        </Link>
      </section>

      <section className="mb-4 grid grid-cols-3 gap-2 sm:gap-3">
        <div className="border border-[#dce5df] bg-white p-3 sm:p-4">
          <p className="text-[11px] font-medium text-[#738078] sm:text-xs">انتظار</p>
          <p className="mt-1 text-xl font-bold text-[#17211b] sm:text-2xl">{waiting.toLocaleString("ar-EG")}</p>
        </div>
        <div className="border border-[#dce5df] bg-white p-3 sm:p-4">
          <p className="text-[11px] font-medium text-[#738078] sm:text-xs">تحضير</p>
          <p className="mt-1 text-xl font-bold text-blue-700 sm:text-2xl">{preparing.toLocaleString("ar-EG")}</p>
        </div>
        <div className="border border-[#dce5df] bg-white p-3 sm:p-4">
          <p className="text-[11px] font-medium text-[#738078] sm:text-xs">تم</p>
          <p className="mt-1 text-xl font-bold text-[#16794a] sm:text-2xl">{done.toLocaleString("ar-EG")}</p>
        </div>
      </section>

      <KitchenQueue rows={rows} />
      <div className="h-20 lg:hidden" />
    </AppShell>
  );
}

