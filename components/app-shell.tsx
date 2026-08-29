"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Bell, Bike, CalendarDays, ChefHat, CircleDollarSign, LayoutDashboard, PackageOpen, ReceiptText, Salad, ShoppingCart, Users } from "lucide-react";
import { useERP } from "@/components/erp-provider";
import type { Role } from "@/lib/erp-types";

type Props = { title: string; subtitle: string; actions?: React.ReactNode; children: React.ReactNode };
const roleLabels: Record<Role, string> = { admin: "Admin", sales: "Sales", cs: "Customer Service", kitchen: "Kitchen", delivery: "Delivery", accounting: "Accounting" };
const navigation = [
  { href: "/", label: "الرئيسية", icon: LayoutDashboard, roles: ["admin", "sales", "cs", "kitchen", "delivery", "accounting"] },
  { href: "/catalog", label: "المنتجات", icon: PackageOpen, roles: ["admin", "sales"] },
  { href: "/menu", label: "منيو الشهر", icon: CalendarDays, roles: ["admin", "kitchen", "cs"] },
  { href: "/clients", label: "العملاء", icon: Users, roles: ["admin", "sales", "cs", "accounting"] },
  { href: "/orders", label: "الطلبات", icon: ShoppingCart, roles: ["admin", "sales", "cs", "accounting"] },
  { href: "/subscriptions", label: "الاشتراكات", icon: Salad, roles: ["admin", "sales", "cs", "accounting"] },
  { href: "/kitchen", label: "المطبخ", icon: ChefHat, roles: ["admin", "kitchen"] },
  { href: "/delivery", label: "التوصيل", icon: Bike, roles: ["admin", "delivery", "accounting"] },
  { href: "/accounting", label: "الحسابات", icon: ReceiptText, roles: ["admin", "accounting"] },
  { href: "/sales", label: "المبيعات", icon: CircleDollarSign, roles: ["admin", "sales", "accounting"] },
  { href: "/notifications", label: "التنبيهات", icon: Bell, roles: ["admin", "sales", "cs", "kitchen", "delivery", "accounting"] },
] as const;

export function AppShell({ title, subtitle, actions, children }: Props) {
  const pathname = usePathname();
  const { role, setRole, notifications, demoMode, loading, error } = useERP();
  const visible = navigation.filter((item) => role === "admin" || (item.roles as readonly Role[]).includes(role));
  const unread = notifications.filter((item) => !item.read && (role === "admin" || item.role === role)).length;
  return (
    <div className="min-h-screen bg-[#f3f6f4] lg:grid lg:grid-cols-[270px_1fr]">
      <aside className="hidden min-h-screen border-l border-[#dce5df] bg-[#10291d] text-white lg:flex lg:flex-col lg:p-5">
        <Link href="/" className="mb-6 flex items-center gap-3"><span className="flex h-11 min-w-14 items-center justify-center rounded-md bg-[#1f8a58] px-2 text-sm font-black tracking-wide">ECO</span><span><b className="block">ECO Healthy</b><small className="text-[#9fc1ad]">Enterprise ERP</small></span></Link>
        <div className="mb-5 rounded-lg border border-white/10 bg-white/5 p-3"><label className="mb-2 block text-xs font-bold text-[#b8d0c2]">تجربة الصلاحيات</label><select value={role} onChange={(e) => setRole(e.target.value as Role)} className="min-h-11 w-full rounded-md border border-white/15 bg-[#183b2b] px-3 text-sm font-bold text-white">{Object.entries(roleLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
        <nav className="space-y-1 overflow-y-auto" aria-label="القائمة الرئيسية">{visible.map((item) => { const Icon = item.icon; const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href); return <Link key={item.href} href={item.href} className={`relative flex min-h-11 items-center gap-3 rounded-md px-3 text-sm font-bold transition ${active ? "bg-[#1f8a58] text-white" : "text-[#c4d7cc] hover:bg-white/10 hover:text-white"}`}><Icon size={19}/>{item.label}{item.href === "/notifications" && unread > 0 ? <span className="mr-auto rounded-full bg-[#dc3f4f] px-2 py-0.5 text-[10px]">{unread}</span> : null}</Link>; })}</nav>
        <div className="mt-auto rounded-md border border-white/10 p-3 text-xs leading-5 text-[#a9c3b4]">{demoMode ? "وضع التجربة الآمن: البيانات محفوظة على هذا الجهاز ويمكن تصفيرها." : "الوضع المباشر: البيانات متصلة بـ Supabase."}</div>
      </aside>
      <div className="min-w-0 pb-20 lg:pb-0">
        <header className="sticky top-0 z-30 border-b border-[#dce5df] bg-white/95 px-4 py-3 backdrop-blur sm:px-6 lg:px-8"><div className="mx-auto flex max-w-[1500px] items-center justify-between gap-3"><div className="min-w-0"><h1 className="truncate text-xl font-black text-[#17211b] sm:text-2xl">{title}</h1><p className="mt-0.5 truncate text-xs text-[#66736b] sm:text-sm">{subtitle}</p></div><div className="flex items-center gap-2">{actions}<Link href="/notifications" className="relative flex size-11 items-center justify-center rounded-md border border-[#dce5df] text-[#536158]"><Bell size={20}/>{unread ? <span className="absolute -left-1 -top-1 min-w-5 rounded-full bg-[#dc3f4f] px-1 text-center text-[10px] font-bold leading-5 text-white">{unread}</span> : null}</Link><select value={role} onChange={(e) => setRole(e.target.value as Role)} className="min-h-11 max-w-[135px] rounded-md border border-[#cfdad3] bg-white px-2 text-xs font-bold lg:hidden">{Object.entries(roleLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div></div></header>
        <main className="mx-auto max-w-[1500px] px-4 py-5 sm:px-6 lg:px-8">{loading ? <div className="mb-4 rounded-md border border-blue-200 bg-blue-50 p-3 text-sm font-bold text-blue-800">جاري تحميل بيانات النظام...</div> : null}{error ? <div className="mb-4 rounded-md border border-red-200 bg-red-50 p-3 text-sm font-bold text-red-800">{error}</div> : null}{children}</main>
        <nav className="fixed inset-x-0 bottom-0 z-40 flex overflow-x-auto border-t border-[#dce5df] bg-white lg:hidden">{visible.map((item) => { const Icon = item.icon; const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href); return <Link key={item.href} href={item.href} className={`relative flex min-h-16 min-w-[76px] flex-1 flex-col items-center justify-center gap-1 px-2 text-[10px] font-bold ${active ? "bg-[#e9f6ef] text-[#16794a]" : "text-[#66736b]"}`}><Icon size={20}/>{item.label}</Link>; })}</nav>
      </div>
    </div>
  );
}
