import Link from "next/link";
import {
  AlertCircle,
  ArrowLeft,
  ClipboardList,
  Clock3,
  Users,
  Utensils,
} from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { StatCard } from "@/components/stat-card";
import { cairoDate, getDashboardStats } from "@/lib/data";

export const dynamic = "force-dynamic";

function formatArabicDate(dateValue: string) {
  return new Intl.DateTimeFormat("ar-EG", {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: "Africa/Cairo",
  }).format(new Date(`${dateValue}T12:00:00Z`));
}

export default async function DashboardPage() {
  const stats = await getDashboardStats();
  const tomorrow = cairoDate(1);

  return (
    <AppShell
      active="dashboard"
      title="الرئيسية"
      subtitle="نظرة سريعة على تشغيل ECO Healthy"
    >
      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="إجمالي العملاء"
          value={stats.clients}
          note="العملاء المسجلون على النظام"
          icon={Users}
          tone="gray"
        />
        <StatCard
          title="اشتراكات فعالة"
          value={stats.activeSubscriptions}
          note="اشتراكات حالتها Active الآن"
          icon={Utensils}
          tone="green"
        />
        <StatCard
          title="إنتاج بكرة"
          value={stats.kitchenTomorrow}
          note={formatArabicDate(tomorrow)}
          icon={ClipboardList}
          tone="blue"
        />
        <StatCard
          title="قربت تخلص"
          value={stats.endingSoon}
          note="3 أيام أو أقل متبقية"
          icon={Clock3}
          tone="orange"
        />
      </section>

      <section className="mt-6 grid gap-4 lg:grid-cols-[1.4fr_1fr]">
        <div className="border border-[#dce5df] bg-white p-5 sm:p-6">
          <div className="mb-6 flex items-center justify-between gap-4">
            <div>
              <p className="text-xs font-bold text-[#16794a]">التشغيل القادم</p>
              <h2 className="mt-1 text-lg font-bold text-[#17211b]">طابور مطبخ بكرة</h2>
            </div>
            <div className="bg-[#e5f5ec] px-3 py-2 text-xs font-bold text-[#0f603a]">
              {stats.kitchenTomorrow.toLocaleString("ar-EG")} بند
            </div>
          </div>

          <div className="border border-[#dce5df] bg-[#f8faf9] p-4 sm:flex sm:items-center sm:justify-between sm:gap-5">
            <div className="flex gap-3">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center bg-white text-[#16794a]">
                <ClipboardList size={21} aria-hidden="true" />
              </div>
              <div>
                <p className="font-bold text-[#223028]">{formatArabicDate(tomorrow)}</p>
                <p className="mt-1 text-sm leading-6 text-[#66736b]">
                  افتح القائمة المقفولة للمطبخ وشوف العملاء والوجبات والكميات.
                </p>
              </div>
            </div>

            <Link
              href="/kitchen"
              className="mt-4 flex min-h-11 items-center justify-center gap-2 bg-[#16794a] px-4 text-sm font-bold text-white hover:bg-[#0f603a] sm:mt-0"
            >
              فتح الطابور
              <ArrowLeft size={18} aria-hidden="true" />
            </Link>
          </div>
        </div>

        <div className="border border-[#dce5df] bg-white p-5 sm:p-6">
          <div className="mb-5 flex items-center gap-3">
            <AlertCircle size={21} className="text-[#b76b13]" aria-hidden="true" />
            <h2 className="text-lg font-bold text-[#17211b]">محتاج متابعة</h2>
          </div>

          <div className="space-y-3">
            <div className="flex items-center justify-between border-b border-[#edf1ee] pb-3 text-sm">
              <span className="text-[#59665e]">اشتراكات قربت تخلص</span>
              <strong className="text-[#17211b]">{stats.endingSoon.toLocaleString("ar-EG")}</strong>
            </div>
            <div className="flex items-center justify-between border-b border-[#edf1ee] pb-3 text-sm">
              <span className="text-[#59665e]">إنتاج بكرة</span>
              <strong className="text-[#17211b]">{stats.kitchenTomorrow.toLocaleString("ar-EG")}</strong>
            </div>
            <p className="pt-1 text-xs leading-6 text-[#7b867f]">
              هنضيف تنبيهات الدفع والتوصيل والإلغاء في المرحلة التالية بدون تغيير الهيكل الأساسي.
            </p>
          </div>
        </div>
      </section>

      <div className="h-20 lg:hidden" />
    </AppShell>
  );
}

