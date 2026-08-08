"use client";

import * as React from "react";
import { createClient } from "@/lib/supabase/client";
import type { EmployeeProfile, Role } from "@/lib/domain";

type AuthContextValue = { profile: EmployeeProfile | null; role: Role | null; loading: boolean; refreshProfile: () => Promise<void> };
const AuthContext = React.createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [profile, setProfile] = React.useState<EmployeeProfile | null>(null);
  const [loading, setLoading] = React.useState(true);

  const refreshProfile = React.useCallback(async () => {
    if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) { setLoading(false); return; }
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { setProfile(null); setLoading(false); return; }
    const { data } = await supabase.from("employee_profiles").select("user_id, full_name, role, active").eq("user_id", user.id).single();
    setProfile((data as EmployeeProfile | null) ?? null);
    setLoading(false);
  }, []);

  React.useEffect(() => { void refreshProfile(); }, [refreshProfile]);
  return <AuthContext.Provider value={{ profile, role: profile?.role ?? null, loading, refreshProfile }}>{children}</AuthContext.Provider>;
}

export function useAuthProfile() {
  const value = React.useContext(AuthContext);
  if (!value) throw new Error("useAuthProfile must be used inside AuthProvider");
  return value;
}
