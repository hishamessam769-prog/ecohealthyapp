"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { hasSupabaseBrowserConfig } from "@/lib/supabase/config";

const loginSchema = z.object({
  email: z.email(),
  password: z.string().min(8),
});

export async function loginAction(formData: FormData) {
  if (!hasSupabaseBrowserConfig()) redirect("/login?error=configuration");
  const result = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  if (!result.success) redirect("/login?error=validation");

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword(result.data);
  if (error || !data.user) redirect("/login?error=credentials");
  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase.from("profiles").select("is_active").eq("id", data.user.id).maybeSingle(),
    supabase.from("organization_memberships").select("id").eq("user_id", data.user.id).eq("status", "active").limit(1),
  ]);
  if (!profile?.is_active || !memberships?.length) {
    await supabase.auth.signOut();
    redirect("/login?error=credentials");
  }
  redirect("/dashboard");
}

export async function logoutAction() {
  if (hasSupabaseBrowserConfig()) {
    const supabase = await createClient();
    await supabase.auth.signOut();
  }
  redirect("/login");
}
