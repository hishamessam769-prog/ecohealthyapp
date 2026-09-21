import { createClient } from "@supabase/supabase-js";

if (process.env.ALLOW_DEMO_CLEANUP !== "true" || !["development", "staging"].includes(process.env.DEMO_ENVIRONMENT)) {
  throw new Error("Acceptance-user cleanup is restricted to development/staging and requires ALLOW_DEMO_CLEANUP=true.");
}
if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) throw new Error("Supabase server credentials are required.");

const emails = [process.env.DEMO_SALES_MANAGER_EMAIL,process.env.DEMO_SALES_REP_EMAIL,process.env.DEMO_FINANCE_EMAIL,process.env.DEMO_OPERATIONS_EMAIL,process.env.DEMO_TASK_USER_EMAIL].filter(Boolean).map((email) => email.toLowerCase());
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
const users = [];
for (let page=1; page<=10; page+=1) {
  const { data,error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
  if (error) throw error;
  users.push(...data.users.filter((user) => user.email && emails.includes(user.email.toLowerCase()) && user.user_metadata?.acceptance_demo_account === true));
  if (data.users.length<100) break;
}
const ids = users.map((user) => user.id);
if (ids.length) {
  await supabase.from("task_assignments").delete().in("assignee_user_id", ids).eq("is_demo", true);
  for (const user of users) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) throw error;
  }
}
console.log(`Removed ${users.length} marked acceptance demo users. Production users were not targeted.`);
