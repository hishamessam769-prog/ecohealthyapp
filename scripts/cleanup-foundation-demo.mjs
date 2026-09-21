import { createClient } from "@supabase/supabase-js";

if (process.env.ALLOW_DEMO_CLEANUP !== "true" || !["development", "staging"].includes(process.env.DEMO_ENVIRONMENT)) {
  throw new Error("Demo cleanup is restricted to development/staging and requires ALLOW_DEMO_CLEANUP=true.");
}
if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Supabase server credentials are required.");
}

const emails = [
  process.env.DEMO_CEO_EMAIL,
  process.env.DEMO_SALES_MANAGER_EMAIL,
  process.env.DEMO_SALES_REP_EMAIL,
  process.env.DEMO_FINANCE_EMAIL,
].filter(Boolean).map((email) => email.toLowerCase());
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const { error: organizationError } = await supabase.from("organizations").delete().eq("code", "ECO_DEMO");
if (organizationError) throw organizationError;

for (let page = 1; page <= 10; page += 1) {
  const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
  if (error) throw error;
  for (const user of data.users) {
    if (user.email && emails.includes(user.email.toLowerCase()) && user.user_metadata?.demo_account === true) {
      const { error: deleteError } = await supabase.auth.admin.deleteUser(user.id);
      if (deleteError) throw deleteError;
    }
  }
  if (data.users.length < 100) break;
}

console.log("Foundation demo tenant and marked demo users were removed.");
