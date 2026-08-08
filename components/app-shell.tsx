"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Bell, Bike, ChefHat, ClipboardList, LayoutDashboard, LogOut, PackageOpen, ReceiptText, Salad, Users } from "lucide-react";
import { useAuthProfile } from "@/components/auth-provider";
import { createClient } from "@/lib/supabase/client";
import type { Role } from "@/lib/domain";

type Props = { title: string; subtitle: string; children: React.ReactNode };
const labels: Record<Role, string> = { admin: "Admin", sales: "Sales", cs: "Customer Service", kitchen: "Kitchen", delivery: "Delivery", accounting: "Accounting" };
const nav = [
  { href: "/", label: "الرئيسية", icon: LayoutDashboard, roles: ["admin","sales","cs","kitchen","delivery","accounting"] },
  { href: "/catalog", label: "المنتجات والمنيو", icon: PackageOpen, roles: ["admin"] },
  { href: "/orders", label: "الطلبات والمبيعات", icon: ClipboardList, roles: ["admin","sales"] },
  { href: "/clients", label: "Client 360", icon: Users, roles: ["admin","sales","cs","accounting"] },
  { href: "/subscriptions", label: "الاشتراكات", icon: Salad, roles: ["admin","cs","sales"] },
  { href: "/kitchen", label: "المطبخ", icon: ChefHat, roles: ["admin","kitchen"] },
  { href: "/delivery", label: "التوصيل", icon: Bike, roles: ["admin","delivery"] },
  { href: "/accounting", label: "الحسابات", icon: ReceiptText, roles: ["admin","accounting"] },
  { href: "/notifications", label: "التنبيهات", icon: Bell, roles: ["admin","sales","cs","kitchen","delivery","accounting"] },
] as const;

export function AppShell({ title, subtitle, children }: Props) {
  const pathname = usePathname();
  const router = useRouter();
  const { profile, role } = useAuthProfile();
  const effectiveRole = role ?? "admin";
  const visible = nav.filter((item) => effectiveRole === "admin" || (item.roles as readonly Role[]).includes(effectiveRole));

  async function logout() {
    if (process.env.NEXT_PUBLIC_SUPABASE_URL) await createClient().auth.signOut();
    router.push("/login");
    router.refresh();
  }

  return <div className="min-h-screen bg-[#f4f7f5] lg:grid lg:grid-cols-[250px_1fr]">
    <aside className="hidden min-h-screen border-l border-[#dce5df] bg-white p-5 lg:flex lg:flex-col">
      <Link href="/" className="mb-7 flex items-center gap-3"><span className="flex h-11 min-w-14 items-center justify-center rounded-md bg-[#16794a] px-2 text-sm font-black text-white">ECO</span><span><b className="block text-sm">ECO Healthy</b><small className="text-[#758078]">ERP Production</small></span></Link>
      <nav className="space-y-1">{visible.map((item) => { const Icon=item.icon; const active=item.href==="/"?pathname==="/":pathname.startsWith(item.href); return <Link key={item.href} href={item.href} className={`flex min-h-12 items-center gap-3 rounded-md px-3 text-sm font-bold ${active?"bg-[#e5f5ec] text-[#0f603a]":"text-[#56635a] hover:bg-[#f4f7f5]"}`}><Icon size={19}/>{item.label}</Link>; })}</nav>
      <div className="mt-auto border-t border-[#e4ebe6] pt-4"><p className="text-sm font-bold">{profile?.full_name ?? "ECO User"}</p><p className="mt-1 text-xs text-[#748078]">{labels[effectiveRole]}</p><button onClick={logout} className="mt-3 flex min-h-11 w-full items-center gap-2 rounded-md px-3 text-sm font-bold text-red-700 hover:bg-red-50"><LogOut size={18}/>تسجيل خروج</button></div>
    </aside>
    <div className="min-w-0 pb-20 lg:pb-0"><header className="sticky top-0 z-30 border-b border-[#dce5df] bg-white/95 px-4 py-4 backdrop-blur sm:px-6 lg:px-8"><div className="mx-auto max-w-7xl"><h1 className="text-xl font-black sm:text-2xl">{title}</h1><p className="mt-1 text-sm text-[#66736b]">{subtitle}</p></div></header><main className="mx-auto max-w-7xl px-4 py-5 sm:px-6 lg:px-8">{children}</main>
    <nav className="fixed inset-x-0 bottom-0 z-40 flex overflow-x-auto border-t border-[#dce5df] bg-white lg:hidden">{visible.map((item)=>{const Icon=item.icon;const active=item.href==="/"?pathname==="/":pathname.startsWith(item.href);return <Link key={item.href} href={item.href} className={`flex min-h-16 min-w-[82px] flex-1 flex-col items-center justify-center gap-1 px-2 text-[10px] font-bold ${active?"bg-[#eaf6ef] text-[#16794a]":"text-[#66736b]"}`}><Icon size={20}/>{item.label}</Link>})}</nav></div>
  </div>;
}
