import Link from "next/link";
import { ClipboardList, LayoutDashboard, Settings, Users } from "lucide-react";
import { LogoutButton } from "@/components/logout-button";

type AppShellProps = {
  active: "dashboard" | "kitchen";
  title: string;
  subtitle: string;
  children: React.ReactNode;
};

const navigation = [
  { href: "/", label: "الرئيسية", key: "dashboard", icon: LayoutDashboard },
  { href: "/kitchen", label: "طابور المطبخ", key: "kitchen", icon: ClipboardList },
];

export function AppShell({ active, title, subtitle, children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-[#f4f7f5] lg:grid lg:grid-cols-[230px_1fr]">
      <aside className="hidden border-l border-[#dce5df] bg-white lg:flex lg:min-h-screen lg:flex-col lg:p-5">
        <Link href="/" className="mb-8 flex items-center gap-3">
          <div className="flex h-11 min-w-14 items-center justify-center bg-[#16794a] px-2 text-sm font-bold tracking-wide text-white">
            ECO
          </div>
          <div>
            <p className="text-sm font-bold text-[#17211b]">ECO Healthy</p>
            <p className="text-xs text-[#768078]">ERP System</p>
          </div>
        </Link>

        <nav className="space-y-2" aria-label="القائمة الرئيسية">
          {navigation.map((item) => {
            const Icon = item.icon;
            const isActive = item.key === active;

            return (
              <Link
                key={item.key}
                href={item.href}
                className={`flex min-h-12 items-center gap-3 px-3 text-sm font-semibold transition-colors ${
                  isActive
                    ? "bg-[#e5f5ec] text-[#0f603a]"
                    : "text-[#5e6a62] hover:bg-[#f4f7f5]"
                }`}
              >
                <Icon size={20} aria-hidden="true" />
                {item.label}
              </Link>
            );
          })}

          <div className="flex min-h-12 cursor-not-allowed items-center gap-3 px-3 text-sm font-medium text-[#a2aaa5]">
            <Users size={20} aria-hidden="true" />
            العملاء
            <span className="mr-auto text-[10px]">قريباً</span>
          </div>
          <div className="flex min-h-12 cursor-not-allowed items-center gap-3 px-3 text-sm font-medium text-[#a2aaa5]">
            <Settings size={20} aria-hidden="true" />
            الإعدادات
            <span className="mr-auto text-[10px]">قريباً</span>
          </div>
        </nav>

        <div className="mt-auto pt-8">
          <LogoutButton />
        </div>
      </aside>

      <div className="min-w-0">
        <header className="border-b border-[#dce5df] bg-white px-4 py-4 sm:px-6 lg:px-8">
          <div className="mx-auto flex max-w-7xl items-center justify-between gap-4">
            <div>
              <h1 className="text-xl font-bold text-[#17211b] sm:text-2xl">{title}</h1>
              <p className="mt-1 text-sm text-[#66736b]">{subtitle}</p>
            </div>
            <div className="flex h-10 min-w-14 items-center justify-center bg-[#16794a] px-2 text-xs font-bold text-white lg:hidden">
              ECO
            </div>
          </div>
        </header>

        <main className="mx-auto max-w-7xl px-4 py-5 sm:px-6 sm:py-7 lg:px-8">
          {children}
        </main>

        <nav className="fixed inset-x-0 bottom-0 z-20 grid grid-cols-2 border-t border-[#dce5df] bg-white lg:hidden">
          {navigation.map((item) => {
            const Icon = item.icon;
            const isActive = item.key === active;

            return (
              <Link
                key={item.key}
                href={item.href}
                className={`flex min-h-16 flex-col items-center justify-center gap-1 text-xs font-semibold ${
                  isActive ? "text-[#16794a]" : "text-[#66736b]"
                }`}
              >
                <Icon size={21} aria-hidden="true" />
                {item.label}
              </Link>
            );
          })}
        </nav>
      </div>
    </div>
  );
}

