"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  Bike,
  ChefHat,
  CircleDollarSign,
  LayoutDashboard,
  ReceiptText,
  Salad,
  Users,
} from "lucide-react";
import { useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import type { Role } from "@/lib/erp-types";

type AppShellProps = {
  title: string;
  subtitle: string;
  children: React.ReactNode;
};

const roleLabels: Record<Role, string> = {
  admin: "Admin",
  sales: "Sales",
  cs: "Customer Service",
  kitchen: "Kitchen",
  delivery: "Delivery",
  accounting: "Accounting",
};

const navigation = [
  { href: "/", label: "الرئيسية", icon: LayoutDashboard, roles: ["admin", "sales", "cs", "kitchen", "delivery", "accounting"] },
  { href: "/clients", label: "العملاء", icon: Users, roles: ["admin", "sales", "cs", "accounting"] },
  { href: "/subscriptions", label: "الاشتراكات", icon: Salad, roles: ["admin", "sales", "cs", "accounting"] },
  { href: "/kitchen", label: "المطبخ", icon: ChefHat, roles: ["admin", "kitchen"] },
  { href: "/delivery", label: "التوصيل", icon: Bike, roles: ["admin", "delivery"] },
  { href: "/accounting", label: "الحسابات", icon: ReceiptText, roles: ["admin", "accounting"] },
  { href: "/sales", label: "المبيعات", icon: CircleDollarSign, roles: ["admin", "sales"] },
  { href: "/notifications", label: "التنبيهات", icon: Bell, roles: ["admin", "sales", "cs", "kitchen", "delivery", "accounting"] },
] as const;

export function AppShell({ title, subtitle, children }: AppShellProps) {
  const pathname = usePathname();
  const { role, setRole, notifications } = useERP();
  const visibleNavigation = navigation.filter((item) => role === "admin" || (item.roles as readonly Role[]).includes(role));
  const unread = notifications.filter((item) => !item.read && (role === "admin" || item.role === role)).length;

  return (
    <div className="min-h-screen bg-[#f4f7f5] lg:grid lg:grid-cols-[250px_1fr]">
      <aside className="hidden border-l border-[#dce5df] bg-white lg:flex lg:min-h-screen lg:flex-col lg:p-5">
        <Link href="/" className="mb-6 flex items-center gap-3" aria-label="ECO Healthy">
          <div className="flex h-11 min-w-14 items-center justify-center rounded-md bg-[#16794a] px-2 text-sm font-bold tracking-wide text-white">ECO</div>
          <div>
            <p className="text-sm font-bold text-[#17211b]">ECO Healthy</p>
            <p className="text-xs text-[#768078]">ERP Operations</p>
          </div>
        </Link>

        <div className="mb-5 rounded-lg border border-[#dce5df] bg-[#f7faf8] p-3">
          <div className="mb-2 flex items-center gap-1 text-xs font-bold text-[#536158]">
            الدور التجريبي
            <HelpTip text="غيّر الدور لترى نفس النظام بصلاحيات وقائمة كل قسم." />
          </div>
          <select value={role} onChange={(event) => setRole(event.target.value as Role)} className="min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm font-semibold text-[#17211b] outline-none focus:border-[#16794a]">
            {Object.entries(roleLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </div>

        <nav className="space-y-1" aria-label="القائمة الرئيسية">
          {visibleNavigation.map((item) => {
            const Icon = item.icon;
            const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            return (
              <Link key={item.href} href={item.href} className={`relative flex min-h-12 items-center gap-3 rounded-md px-3 text-sm font-semibold transition-colors ${active ? "bg-[#e5f5ec] text-[#0f603a]" : "text-[#5e6a62] hover:bg-[#f4f7f5]"}`}>
                <Icon size={20} aria-hidden="true" />
                {item.label}
                {item.href === "/notifications" && unread > 0 ? <span className="mr-auto rounded-full bg-[#c63c3c] px-2 py-0.5 text-[11px] text-white">{unread}</span> : null}
              </Link>
            );
          })}
        </nav>

        <p className="mt-auto rounded-md bg-[#eef4f0] p-3 text-xs leading-5 text-[#66736b]">نسخة Demo: كل الأزرار هنا تعمل على بيانات تجريبية داخل المتصفح.</p>
      </aside>

      <div className="min-w-0 pb-20 lg:pb-0">
        <header className="sticky top-0 z-30 border-b border-[#dce5df] bg-white/95 px-4 py-3 backdrop-blur sm:px-6 lg:px-8">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-3">
            <div className="min-w-0">
              <h1 className="truncate text-xl font-bold text-[#17211b] sm:text-2xl">{title}</h1>
              <p className="mt-0.5 truncate text-xs text-[#66736b] sm:text-sm">{subtitle}</p>
            </div>
            <div className="flex items-center gap-2">
              <Link href="/notifications" className="relative flex size-11 items-center justify-center rounded-md border border-[#dce5df] bg-white text-[#536158]" aria-label="التنبيهات">
                <Bell size={20} />
                {unread > 0 ? <span className="absolute -left-1 -top-1 min-w-5 rounded-full bg-[#c63c3c] px-1 text-center text-[10px] font-bold leading-5 text-white">{unread}</span> : null}
              </Link>
              <select value={role} onChange={(event) => setRole(event.target.value as Role)} aria-label="اختيار الدور التجريبي" className="min-h-11 max-w-[145px] rounded-md border border-[#cfdad3] bg-white px-2 text-xs font-bold text-[#17211b] lg:hidden">
                {Object.entries(roleLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
              </select>
            </div>
          </div>
        </header>

        <main className="mx-auto max-w-7xl px-4 py-5 sm:px-6 sm:py-7 lg:px-8">{children}</main>

        <nav className="fixed inset-x-0 bottom-0 z-40 flex overflow-x-auto border-t border-[#dce5df] bg-white lg:hidden" aria-label="القائمة للموبايل">
          {visibleNavigation.map((item) => {
            const Icon = item.icon;
            const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
            return (
              <Link key={item.href} href={item.href} className={`relative flex min-h-16 min-w-[82px] flex-1 flex-col items-center justify-center gap-1 px-2 text-[11px] font-semibold ${active ? "bg-[#eaf6ef] text-[#16794a]" : "text-[#66736b]"}`}>
                <Icon size={21} aria-hidden="true" />
                {item.label}
                {item.href === "/notifications" && unread > 0 ? <span className="absolute left-4 top-2 size-5 rounded-full bg-[#c63c3c] text-center text-[10px] leading-5 text-white">{unread}</span> : null}
              </Link>
            );
          })}
        </nav>
      </div>
    </div>
  );
}
