"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import {
  AppWindow,
  Bell,
  Banknote,
  BarChart3,
  Building2,
  CalendarDays,
  ChevronDown,
  ClipboardCheck,
  FileClock,
  FolderKanban,
  Gauge,
  HeartPulse,
  KeyRound,
  Languages,
  Leaf,
  Menu,
  MessageSquareWarning,
  PanelRightClose,
  Search,
  Settings,
  ShieldCheck,
  ShoppingBag,
  Stethoscope,
  ListTodo,
  ReceiptText,
  Repeat2,
  UserRoundSearch,
  UserSquare2,
  Video,
  WalletCards,
  UserCog,
  Users,
  X,
} from "lucide-react";
import { useLocale } from "@/components/providers/locale-provider";
import { cn, initials } from "@/lib/utils";
import type { Viewer } from "@/lib/auth/viewer";
import { logoutAction } from "@/app/actions/auth";
import { setActiveBranchAction } from "@/app/actions/preferences";

const navItems = [
  { href: "/dashboard", key: "dashboard", icon: Gauge, permission: "dashboard.view" },
  { href: "/projects", key: "projects", icon: FolderKanban, permission: "projects.view" },
  { href: "/tasks", key: "tasks", icon: ListTodo, permission: "tasks.view_own" },
  { href: "/crm/leads", key: "leads", icon: UserRoundSearch, permission: "leads.view" },
  { href: "/crm/customers", key: "customers", icon: UserSquare2, permission: "customers.view" },
  { href: "/sales", key: "sales", icon: ShoppingBag, permission: "catalog.view" },
  { href: "/sales/invoices", key: "invoices", icon: ReceiptText, permission: "sales.invoice" },
  { href: "/finance/payments", key: "finance", icon: Banknote, permission: "payments.review" },
  { href: "/subscriptions", key: "subscriptions", icon: Repeat2, permission: "subscriptions.view" },
  { href: "/operations/subscribers", key: "operations", icon: HeartPulse, permission: "subscriptions.view" },
  { href: "/complaints", key: "complaints", icon: MessageSquareWarning, permission: "complaints.view" },
  { href: "/performance", key: "performance", icon: BarChart3, permission: "targets.view_own" },
  { href: "/doctors", key: "doctors", icon: Stethoscope, permission: "doctors.view" },
  { href: "/doctors/calendar", key: "doctorCalendar", icon: CalendarDays, permission: "doctors.view" },
  { href: "/doctors/sessions", key: "sessions", icon: Video, permission: "sessions.view_own" },
  { href: "/doctors/accounting", key: "doctorAccounting", icon: WalletCards, permission: "doctor_commissions.view_own" },
  { href: "/notifications", key: "notificationCenter", icon: Bell, permission: "notifications.view" },
  { href: "/admin/users", key: "users", icon: Users, permission: "users.view" },
  { href: "/admin/roles", key: "roles", icon: UserCog, permission: "roles.view" },
  { href: "/admin/permissions", key: "permissions", icon: KeyRound, permission: "permissions.view" },
  { href: "/admin/branch-access", key: "branchAccess", icon: Building2, permission: "branches.view" },
  { href: "/admin/audit-log", key: "audit", icon: FileClock, permission: "audit.view" },
  { href: "/settings", key: "settings", icon: Settings, permission: "settings.view" },
] as const;

export function AppShell({ viewer, children }: { viewer: Viewer; children: React.ReactNode }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [navigating, setNavigating] = useState(false);
  const { locale, setLocale, dictionary } = useLocale();
  const visibleItems = navItems.filter((item) => viewer.permissions.includes(item.permission));
  useEffect(() => {
    const reset = window.setTimeout(() => setNavigating(false), 0);
    return () => window.clearTimeout(reset);
  }, [pathname]);

  const sidebar = (
    <aside className={cn("flex h-full flex-col border-e border-white/10 bg-[var(--primary)] text-white transition-[width] duration-200", collapsed ? "w-[84px]" : "w-[270px]")}>
      <div className="flex h-[76px] items-center gap-3 border-b border-white/10 px-5">
        <Link href="/dashboard" className="flex min-w-0 flex-1 items-center gap-3">
          <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-white/12"><Leaf size={24} /></span>
          {!collapsed ? <span className="min-w-0"><strong className="block truncate">Eco Healthy</strong><small className="text-white/55">Enterprise ERP</small></span> : null}
        </Link>
        <button aria-label="Collapse sidebar" onClick={() => setCollapsed((value) => !value)} className="hidden rounded-lg p-2 text-white/60 hover:bg-white/10 hover:text-white lg:block"><PanelRightClose className={cn("transition-transform", collapsed && "rotate-180")} size={19} /></button>
      </div>

      <nav className="scrollbar-thin flex-1 space-y-1 overflow-y-auto p-3" aria-label="Main navigation">
        {visibleItems.map((item) => {
          const active = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(item.href));
          const Icon = item.icon;
          return (
            <Link key={item.href} href={item.href} title={collapsed ? dictionary.nav[item.key] : undefined} onClick={() => { setMobileOpen(false); if (!active) setNavigating(true); }} className={cn("flex h-12 items-center gap-3 rounded-xl px-3 text-sm font-bold transition", active ? "bg-white text-[var(--primary)] shadow-lg" : "text-white/70 hover:bg-white/10 hover:text-white", collapsed && "justify-center px-0")}>
              <Icon size={20} />
              {!collapsed ? <span>{dictionary.nav[item.key]}</span> : null}
            </Link>
          );
        })}
      </nav>

      <div className="border-t border-white/10 p-3">
        <div className={cn("rounded-xl bg-black/10 p-3", collapsed && "grid place-items-center p-2")}>
          <div className="flex items-center gap-3">
            <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-[#b5d77d] text-xs font-black text-[#173e31]">{initials(viewer.name)}</span>
            {!collapsed ? <div className="min-w-0"><strong className="block truncate text-sm">{viewer.name}</strong><span className="block truncate text-xs text-white/50">{viewer.roleNames[0] || "User"}</span></div> : null}
          </div>
          {!collapsed ? <form action={logoutAction} className="mt-3"><button className="w-full rounded-lg border border-white/10 py-2 text-xs font-bold text-white/65 hover:bg-white/10 hover:text-white">{dictionary.common.signOut}</button></form> : null}
        </div>
      </div>
    </aside>
  );

  return (
    <div className="min-h-screen lg:flex">
      <div className="fixed inset-y-0 start-0 z-40 hidden lg:block">{sidebar}</div>
      {mobileOpen ? <div className="fixed inset-0 z-50 lg:hidden"><button aria-label="Close menu" className="absolute inset-0 bg-black/45 backdrop-blur-sm" onClick={() => setMobileOpen(false)} /><div className="absolute inset-y-0 start-0">{sidebar}<button aria-label="Close menu" onClick={() => setMobileOpen(false)} className="absolute end-3 top-4 rounded-lg bg-white/10 p-2"><X size={20} /></button></div></div> : null}

      <div className={cn("min-w-0 flex-1 transition-[margin] duration-200", collapsed ? "lg:ms-[84px]" : "lg:ms-[270px]")}>
        <header className="sticky top-0 z-30 flex h-[76px] items-center gap-3 border-b border-[var(--border)] bg-white/88 px-4 backdrop-blur-xl sm:px-6">
          <button className="grid size-10 place-items-center rounded-xl hover:bg-[var(--surface-muted)] lg:hidden" onClick={() => setMobileOpen(true)} aria-label="Open menu"><Menu size={22} /></button>
          <Link href="/dashboard" className="hidden size-10 place-items-center rounded-xl bg-[var(--primary-soft)] text-[var(--primary)] sm:grid" aria-label="App launcher"><AppWindow size={20} /></Link>
          <div className="relative hidden max-w-xl flex-1 md:block">
            <Search className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)]" size={18} />
            <input aria-label={dictionary.common.search} placeholder={dictionary.common.search} className="h-11 w-full rounded-xl border border-transparent bg-[var(--surface-muted)] ps-10 pe-4 text-sm outline-none focus:border-[var(--border)] focus:bg-white" />
          </div>
          <div className="ms-auto flex items-center gap-1 sm:gap-2">
            <form action={setActiveBranchAction} className="hidden sm:block">
              <input type="hidden" name="returnPath" value={pathname} />
              <select name="branchId" aria-label="Branch" defaultValue={viewer.activeBranchId || ""} onChange={(event) => { setNavigating(true); event.currentTarget.form?.requestSubmit(); }} className="h-10 max-w-44 rounded-xl border border-[var(--border)] bg-white px-3 text-xs font-bold">
                {viewer.branches.length ? viewer.branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>) : <option value="">كل الفروع</option>}
              </select>
            </form>
            <button title={dictionary.common.approvals} className="relative grid size-10 place-items-center rounded-xl hover:bg-[var(--surface-muted)]"><ClipboardCheck size={20} /><span className="absolute end-1 top-1 grid size-4 place-items-center rounded-full bg-[var(--primary)] text-[9px] font-black text-white">0</span></button>
            <button title={dictionary.common.notifications} className="relative grid size-10 place-items-center rounded-xl hover:bg-[var(--surface-muted)]"><Bell size={20} /><span className="absolute end-1 top-1 grid size-4 place-items-center rounded-full bg-amber-500 text-[9px] font-black text-white">0</span></button>
            <button onClick={() => setLocale(locale === "ar" ? "en" : "ar")} className="flex h-10 items-center gap-2 rounded-xl px-2 text-xs font-black hover:bg-[var(--surface-muted)]" aria-label="Change language"><Languages size={19} /><span>{locale === "ar" ? "EN" : "ع"}</span></button>
            <button className="hidden h-10 items-center gap-2 rounded-xl px-2 hover:bg-[var(--surface-muted)] xl:flex"><span className="grid size-8 place-items-center rounded-lg bg-[var(--primary)] text-xs font-black text-white">{initials(viewer.name)}</span><ChevronDown size={15} /></button>
          </div>
        </header>

        {viewer.preview ? <div className="flex items-center justify-center gap-2 border-b border-amber-200 bg-amber-50 px-4 py-2 text-center text-xs font-bold text-amber-800"><ShieldCheck size={15} />{dictionary.preview} — لا توجد بيانات إنتاجية</div> : null}
        {navigating ? <div className="fixed inset-x-0 top-0 z-[100] h-1 overflow-hidden bg-emerald-100"><div className="h-full w-2/3 animate-pulse bg-[var(--primary)]" /></div> : null}
        <main aria-busy={navigating} className={cn("mx-auto w-full max-w-[1500px] p-4 pb-24 transition-opacity sm:p-6 lg:p-8", navigating && "opacity-60")}>{children}</main>

        <nav className="fixed inset-x-3 bottom-3 z-30 flex justify-around rounded-2xl border border-[var(--border)] bg-white/95 p-2 shadow-2xl backdrop-blur lg:hidden" aria-label="Mobile navigation">
          {visibleItems.slice(0, 4).map((item) => { const Icon = item.icon; const active = pathname.startsWith(item.href); return <Link key={item.href} href={item.href} className={cn("flex min-w-16 flex-col items-center gap-1 rounded-xl px-2 py-2 text-[10px] font-bold", active ? "bg-[var(--primary-soft)] text-[var(--primary)]" : "text-[var(--text-muted)]")}><Icon size={19} /><span>{dictionary.nav[item.key]}</span></Link>; })}
        </nav>
      </div>
    </div>
  );
}
