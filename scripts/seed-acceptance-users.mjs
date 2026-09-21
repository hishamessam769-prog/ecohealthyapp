import { createClient } from "@supabase/supabase-js";

if (process.env.ALLOW_DEMO_SEED !== "true" || !["development", "staging"].includes(process.env.DEMO_ENVIRONMENT)) {
  throw new Error("Acceptance users are restricted to development/staging. Set ALLOW_DEMO_SEED=true and DEMO_ENVIRONMENT=staging.");
}

const accounts = [
  { key: "salesManager", name: "Sales Manager Demo", email: process.env.DEMO_SALES_MANAGER_EMAIL, password: process.env.DEMO_SALES_MANAGER_PASSWORD, role: "sales_manager", access: "all" },
  { key: "salesRep", name: "Sales Representative Demo", email: process.env.DEMO_SALES_REP_EMAIL, password: process.env.DEMO_SALES_REP_PASSWORD, role: "sales_representative", access: "main" },
  { key: "finance", name: "Finance Accountant Demo", email: process.env.DEMO_FINANCE_EMAIL, password: process.env.DEMO_FINANCE_PASSWORD, role: "finance_accountant", access: "all" },
  { key: "operations", name: "Operations Manager Demo", email: process.env.DEMO_OPERATIONS_EMAIL, password: process.env.DEMO_OPERATIONS_PASSWORD, role: "operations_manager", access: "all" },
  { key: "taskUser", name: "Task Action User Demo", email: process.env.DEMO_TASK_USER_EMAIL, password: process.env.DEMO_TASK_USER_PASSWORD, role: "customer_service", access: "main" },
];
const required = ["NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", ...accounts.flatMap((account) => [`DEMO_${account.key === "salesManager" ? "SALES_MANAGER" : account.key === "salesRep" ? "SALES_REP" : account.key === "taskUser" ? "TASK_USER" : account.key.toUpperCase()}_EMAIL`, `DEMO_${account.key === "salesManager" ? "SALES_MANAGER" : account.key === "salesRep" ? "SALES_REP" : account.key === "taskUser" ? "TASK_USER" : account.key.toUpperCase()}_PASSWORD`])];
const missing = required.filter((name) => !process.env[name]);
if (missing.length) throw new Error(`Missing acceptance-user variables: ${missing.join(", ")}`);
for (const account of accounts) {
  if (!account.email || !account.password || account.password.length < 12 || account.password.includes("CHANGE_ME")) throw new Error(`Use a unique password of at least 12 characters for ${account.key}.`);
}

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
const { data: installation, error: installationError } = await supabase.from("system_installations").select("organization_id,installed_by").order("installed_at").limit(1).single();
if (installationError || !installation) throw installationError || new Error("Complete /setup before creating acceptance users.");
const { data: branches, error: branchError } = await supabase.from("branches").select("id,code").eq("organization_id", installation.organization_id).eq("status", "active");
if (branchError || !branches?.length) throw branchError || new Error("At least one active branch is required.");
const main = branches.find((branch) => branch.code === "MAIN") || branches[0];
const { data: roles, error: roleError } = await supabase.from("roles").select("id,code").in("code", accounts.map((account) => account.role)).is("organization_id", null);
if (roleError) throw roleError;

const existingUsers = [];
for (let page = 1; page <= 10; page += 1) {
  const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
  if (error) throw error;
  existingUsers.push(...data.users);
  if (data.users.length < 100) break;
}

for (const account of accounts) {
  const existing = existingUsers.find((user) => user.email?.toLowerCase() === account.email.toLowerCase());
  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, { password: account.password, email_confirm: true, ban_duration: "none", user_metadata: { ...existing.user_metadata, full_name: account.name, acceptance_demo_account: true } });
    if (error) throw error;
    account.userId = data.user.id;
  } else {
    const { data, error } = await supabase.auth.admin.createUser({ email: account.email, password: account.password, email_confirm: true, user_metadata: { full_name: account.name, acceptance_demo_account: true } });
    if (error || !data.user) throw error || new Error(`Unable to create ${account.key}`);
    account.userId = data.user.id;
  }
  const role = roles.find((item) => item.code === account.role);
  if (!role) throw new Error(`Missing system role ${account.role}`);
  const { error: membershipError } = await supabase.from("organization_memberships").upsert({ organization_id: installation.organization_id, user_id: account.userId, status: "active", invited_by: installation.installed_by, activated_at: new Date().toISOString(), disabled_at: null }, { onConflict: "organization_id,user_id" });
  if (membershipError) throw membershipError;
  const { error: profileError } = await supabase.from("profiles").update({ is_active: true }).eq("id", account.userId);
  if (profileError) throw profileError;
  const { error: assignmentError } = await supabase.from("user_roles").upsert({ organization_id: installation.organization_id, user_id: account.userId, role_id: role.id, assigned_by: installation.installed_by }, { onConflict: "organization_id,user_id,role_id" });
  if (assignmentError) throw assignmentError;
  const accountBranches = account.access === "all" ? branches : [main];
  for (const branch of accountBranches) {
    const { error: grantError } = await supabase.from("user_branch_access").upsert({ organization_id: installation.organization_id, user_id: account.userId, branch_id: branch.id, access_level: account.access === "all" ? "manage" : "operate", granted_by: installation.installed_by }, { onConflict: "organization_id,user_id,branch_id" });
    if (grantError) throw grantError;
  }
}

const taskUser = accounts.find((account) => account.key === "taskUser");
const salesRep = accounts.find((account) => account.key === "salesRep");
const operations = accounts.find((account) => account.key === "operations");
const finance = accounts.find((account) => account.key === "finance");
const { data: demoTasks, error: taskError } = await supabase.from("tasks").select("id,task_type").eq("organization_id", installation.organization_id).eq("is_demo", true).order("task_number");
if (taskError) throw taskError;
for (const [index, task] of (demoTasks || []).entries()) {
  const assignee = task.task_type === "refund" ? finance : task.task_type === "subscription" ? operations : index % 2 ? taskUser : salesRep;
  await supabase.from("task_assignments").update({ assignee_user_id: assignee.userId }).eq("task_id", task.id).eq("is_primary", true).is("ended_at", null);
}

console.log("Acceptance users created in the currently installed Eco Healthy organization.");
for (const account of accounts) console.log(`${account.name}: ${account.email}`);
console.log("Passwords were read from local environment variables and were not printed.");
