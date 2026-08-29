"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { BarChart3, Bell, Bike, Boxes, BriefcaseBusiness, CalendarDays, ChefHat, CircleDollarSign, ContactRound, FileCheck2, LayoutDashboard, LogOut, Menu, PackageOpen, ReceiptText, Settings, ShieldCheck, ShoppingCart, Target, Users, X } from "lucide-react";
import { useState } from "react";
import type { Principal } from "@/lib/auth";
import { createClient } from "@/lib/supabase/client";

type Props = { principal: Principal; title: string; subtitle: string; children: React.ReactNode; actions?: React.ReactNode };
type NavItem = { href: string; label: string; icon: typeof LayoutDashboard; permission: string };

const navigation: NavItem[] = [
  { href: "/", label: "لوحة التحكم", icon: LayoutDashboard, permission: "dashboard.access" },
  { href: "/crm", label: "CRM والعملاء المحتملون", icon: ContactRound, permission: "crm.read" },
  { href: "/clients", label: "دليل المشتركين", icon: Users, permission: "subscribers.read" },
  { href: "/orders", label: "الطلبات والفواتير", icon: ShoppingCart, permission: "orders.read" },
  { href: "/subscriptions", label: "الاشتراكات والاستحقاقات", icon: PackageOpen, permission: "subscriptions.read" },
  { href: "/sales", label: "أداء المبيعات", icon: BarChart3, permission: "dashboard.sales.own" },
  { href: "/targets", label: "الأهداف والخطة", icon: Target, permission: "targets.read" },
  { href: "/commissions", label: "العمولات", icon: CircleDollarSign, permission: "commissions.read" },
  { href: "/catalog", label: "الكتالوج والتسعير", icon: BriefcaseBusiness, permission: "catalog.read" },
  { href: "/menu", label: "منيو الشهر", icon: CalendarDays, permission: "menu.read" },
  { href: "/kitchen", label: "المطبخ والجودة", icon: ChefHat, permission: "kitchen.demand.read" },
  { href: "/inventory", label: "المخزون والمشتريات", icon: Boxes, permission: "inventory.read" },
  { href: "/delivery", label: "التوصيل والمسارات", icon: Bike, permission: "delivery.access" },
  { href: "/accounting", label: "الحسابات والإقفال", icon: ReceiptText, permission: "accounting.access" },
  { href: "/investor", label: "غرفة بيانات المستثمر", icon: FileCheck2, permission: "investor.metrics.read" },
  { href: "/notifications", label: "المهام والتنبيهات", icon: Bell, permission: "notifications.read" },
  { href: "/audit", label: "التدقيق", icon: ShieldCheck, permission: "audit.read" },
  { href: "/admin", label: "إدارة النظام", icon: Settings, permission: "employees.invite" },
];

export function AppShell({ principal, title, subtitle, children, actions }: Props) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const visible = navigation.filter((item) => item.permission === "dashboard.access" || principal.permissions.includes(item.permission) || principal.permissions.includes("*"));

  async function logout() {
    await createClient().auth.signOut({ scope: "local" });
    if ("serviceWorker" in navigator) await navigator.serviceWorker.getRegistrations().then((items) => Promise.all(items.map((item) => item.unregister())));
    router.replace("/login");
    router.refresh();
  }

  const nav = <>
    <Link href="/" className="mb-6 flex items-center gap-3 px-2" onClick={() => setOpen(false)}><span className="flex h-11 min-w-14 items-center justify-center rounded-lg bg-[#1f8a58] px-2 text-sm font-black tracking-wide text-white">ECO</span><span><b className="block text-white">ECO Healthy</b><small className="text-[#9fc1ad]">Enterprise ERP</small></span></Link>
    <nav className="space-y-1 overflow-y-auto" aria-label="القائمة الرئيسية">{visible.map((item) => { const Icon = item.icon; const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href); return <Link key={item.href} href={item.href} onClick={() => setOpen(false)} className={`flex min-h-11 items-center gap-3 rounded-lg px-3 text-sm font-bold transition ${active ? "bg-[#1f8a58] text-white" : "text-[#c4d7cc] hover:bg-white/10 hover:text-white"}`}><Icon size={19} aria-hidden="true" />{item.label}</Link>; })}</nav>
    <div className="mt-auto space-y-3 border-t border-white/10 pt-4"><div className="rounded-lg bg-white/5 p-3"><b className="block text-sm text-white">{principal.name}</b><span className="mt-1 block text-xs text-[#a9c3b4]">{principal.roles.join(" • ")}</span></div><button onClick={logout} className="flex min-h-11 w-full items-center gap-2 rounded-lg px-3 text-sm font-bold text-[#ffb4b4] hover:bg-white/10"><LogOut size={18}/>تسجيل الخروج</button></div>
  </>;

  return <div className="min-h-screen bg-[#f4f7f5] lg:grid lg:grid-cols-[288px_1fr]">
    <aside className="hidden min-h-screen bg-[#10291d] p-5 lg:flex lg:flex-col">{nav}</aside>
    {open ? <div className="fixed inset-0 z-50 lg:hidden"><button aria-label="إغلاق القائمة" className="absolute inset-0 bg-black/45" onClick={() => setOpen(false)} /><aside className="relative flex h-full w-[88%] max-w-[320px] flex-col bg-[#10291d] p-5"><button onClick={() => setOpen(false)} className="absolute left-4 top-4 flex size-11 items-center justify-center text-white" aria-label="إغلاق"><X/></button>{nav}</aside></div> : null}
    <div className="min-w-0"><header className="sticky top-0 z-30 border-b border-[#dce5df] bg-white/95 px-4 py-3 backdrop-blur sm:px-6 lg:px-8"><div className="mx-auto flex max-w-[1560px] items-center justify-between gap-3"><div className="flex min-w-0 items-center gap-3"><button onClick={() => setOpen(true)} className="flex size-11 items-center justify-center rounded-lg border border-[#dce5df] lg:hidden" aria-label="فتح القائمة"><Menu/></button><div className="min-w-0"><h1 className="truncate text-xl font-black text-[#17211b] sm:text-2xl">{title}</h1><p className="mt-0.5 truncate text-xs text-[#66736b] sm:text-sm">{subtitle}</p></div></div><div className="flex items-center gap-2">{actions}<Link href="/notifications" className="flex size-11 items-center justify-center rounded-lg border border-[#dce5df] text-[#536158]" aria-label="التنبيهات"><Bell size={20}/></Link></div></div></header><main className="mx-auto max-w-[1560px] px-4 py-5 sm:px-6 lg:px-8">{children}</main></div>
  </div>;
}
