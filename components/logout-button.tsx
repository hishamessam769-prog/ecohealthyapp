"use client";

import { LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function LogoutButton() {
  const router = useRouter();

  async function logout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  return (
    <button
      type="button"
      onClick={logout}
      className="flex min-h-11 w-full items-center gap-3 border border-[#dce5df] bg-white px-3 text-sm font-semibold text-[#4f5e55] transition-colors hover:bg-[#f4f7f5]"
    >
      <LogOut size={18} aria-hidden="true" />
      تسجيل الخروج
    </button>
  );
}

