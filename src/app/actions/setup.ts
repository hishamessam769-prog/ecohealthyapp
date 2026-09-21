"use server";

import { timingSafeEqual } from "node:crypto";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const schema = z.object({
  companyName: z.string().trim().min(2).max(120),
  companyCode: z.string().trim().min(2).max(20).regex(/^[A-Za-z0-9_]+$/),
  adminName: z.string().trim().min(2).max(120),
  adminEmail: z.email(),
  adminPassword: z.string().min(12).max(128),
  setupSecret: z.string().min(12).max(256),
});

function secretMatches(value: string) {
  const expected = process.env.SETUP_SECRET;
  if (!expected || expected.length < 12) return false;
  const actualBuffer = Buffer.from(value);
  const expectedBuffer = Buffer.from(expected);
  return actualBuffer.length === expectedBuffer.length && timingSafeEqual(actualBuffer, expectedBuffer);
}

export async function firstTimeSetupAction(formData: FormData) {
  const parsed = schema.safeParse({
    companyName: formData.get("companyName"),
    companyCode: formData.get("companyCode"),
    adminName: formData.get("adminName"),
    adminEmail: formData.get("adminEmail"),
    adminPassword: formData.get("adminPassword"),
    setupSecret: formData.get("setupSecret"),
  });
  if (!parsed.success || !secretMatches(parsed.data.setupSecret)) redirect("/setup?error=validation");

  const admin = createAdminClient();
  const { data: existing } = await admin.from("system_installations").select("id").limit(1);
  if (existing?.length) redirect("/login?setup=completed");

  const { data: authData, error: authError } = await admin.auth.admin.createUser({
    email: parsed.data.adminEmail.toLowerCase(),
    password: parsed.data.adminPassword,
    email_confirm: true,
    user_metadata: { full_name: parsed.data.adminName },
  });
  if (authError || !authData.user) redirect("/setup?error=account");

  const { error: claimError } = await admin.rpc("claim_initial_setup", {
    p_user_id: authData.user.id,
    p_company_name: parsed.data.companyName,
    p_company_code: parsed.data.companyCode.toUpperCase(),
    p_admin_name: parsed.data.adminName,
  });
  if (claimError) {
    await admin.auth.admin.deleteUser(authData.user.id);
    redirect("/setup?error=claim");
  }

  const supabase = await createClient();
  await supabase.auth.signInWithPassword({ email: parsed.data.adminEmail, password: parsed.data.adminPassword });
  redirect("/dashboard?setup=1");
}
