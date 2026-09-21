import { createClient } from "@supabase/supabase-js";

if (process.env.ALLOW_DEMO_SEED !== "true" || !["development", "staging"].includes(process.env.DEMO_ENVIRONMENT)) {
  throw new Error("Demo seed is restricted to development/staging. Set ALLOW_DEMO_SEED=true and DEMO_ENVIRONMENT=staging explicitly.");
}

const required = [
  "NEXT_PUBLIC_SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DEMO_CEO_EMAIL",
  "DEMO_CEO_PASSWORD",
  "DEMO_SALES_MANAGER_EMAIL",
  "DEMO_SALES_MANAGER_PASSWORD",
  "DEMO_SALES_REP_EMAIL",
  "DEMO_SALES_REP_PASSWORD",
  "DEMO_FINANCE_EMAIL",
  "DEMO_FINANCE_PASSWORD",
  "DEMO_OPERATIONS_EMAIL",
  "DEMO_OPERATIONS_PASSWORD",
  "DEMO_TASK_USER_EMAIL",
  "DEMO_TASK_USER_PASSWORD",
];
const missing = required.filter((name) => !process.env[name]);
if (missing.length) throw new Error(`Missing demo variables: ${missing.join(", ")}`);

const accounts = [
  { key: "ceo", name: "CEO Admin Demo", email: process.env.DEMO_CEO_EMAIL, password: process.env.DEMO_CEO_PASSWORD, role: "ceo_super_admin" },
  { key: "salesManager", name: "Sales Manager Demo", email: process.env.DEMO_SALES_MANAGER_EMAIL, password: process.env.DEMO_SALES_MANAGER_PASSWORD, role: "sales_manager" },
  { key: "salesRep", name: "Sales Representative Demo", email: process.env.DEMO_SALES_REP_EMAIL, password: process.env.DEMO_SALES_REP_PASSWORD, role: "sales_representative" },
  { key: "finance", name: "Finance Accountant Demo", email: process.env.DEMO_FINANCE_EMAIL, password: process.env.DEMO_FINANCE_PASSWORD, role: "finance_accountant" },
  { key: "operations", name: "Operations Manager Demo", email: process.env.DEMO_OPERATIONS_EMAIL, password: process.env.DEMO_OPERATIONS_PASSWORD, role: "operations_manager" },
  { key: "taskUser", name: "Task Action User Demo", email: process.env.DEMO_TASK_USER_EMAIL, password: process.env.DEMO_TASK_USER_PASSWORD, role: "customer_service" },
];

for (const account of accounts) {
  if (account.password.length < 12 || account.password.includes("CHANGE_ME")) {
    throw new Error(`Use a unique password of at least 12 characters for ${account.key}.`);
  }
}

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

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
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      password: account.password,
      email_confirm: true,
      ban_duration: "none",
      user_metadata: { full_name: account.name, demo_account: true },
    });
    if (error) throw error;
    account.userId = data.user.id;
  } else {
    const { data, error } = await supabase.auth.admin.createUser({
      email: account.email,
      password: account.password,
      email_confirm: true,
      user_metadata: { full_name: account.name, demo_account: true },
    });
    if (error || !data.user) throw error || new Error(`Unable to create ${account.key}`);
    account.userId = data.user.id;
  }
}

const ceo = accounts.find((account) => account.key === "ceo");
const { data: organization, error: organizationError } = await supabase.from("organizations").upsert({
  code: "ECO_DEMO",
  name: "Eco Healthy Demo",
  created_by: ceo.userId,
}, { onConflict: "code" }).select("id").single();
if (organizationError) throw organizationError;

const { data: roles, error: rolesError } = await supabase.from("roles").select("id, code").in("code", accounts.map((account) => account.role)).is("organization_id", null);
if (rolesError) throw rolesError;

for (const account of accounts) {
  const role = roles.find((item) => item.code === account.role);
  if (!role) throw new Error(`Missing system role ${account.role}`);
  const { error: membershipError } = await supabase.from("organization_memberships").upsert({
    organization_id: organization.id,
    user_id: account.userId,
    status: "active",
    invited_by: ceo.userId,
    activated_at: new Date().toISOString(),
    disabled_at: null,
  }, { onConflict: "organization_id,user_id" });
  if (membershipError) throw membershipError;
  const { error: profileError } = await supabase.from("profiles").update({ is_active: true }).eq("id", account.userId);
  if (profileError) throw profileError;
  const { error: roleError } = await supabase.from("user_roles").upsert({
    organization_id: organization.id,
    user_id: account.userId,
    role_id: role.id,
    assigned_by: ceo.userId,
  }, { onConflict: "organization_id,user_id,role_id" });
  if (roleError) throw roleError;
}

const { data: branches, error: branchError } = await supabase.from("branches").upsert([
  { organization_id: organization.id, code: "MAIN", name: "الفرع الرئيسي", status: "active", created_by: ceo.userId },
  { organization_id: organization.id, code: "SECOND", name: "الفرع الثاني", status: "active", created_by: ceo.userId },
], { onConflict: "organization_id,code" }).select("id, code");
if (branchError) throw branchError;

const main = branches.find((branch) => branch.code === "MAIN");
const second = branches.find((branch) => branch.code === "SECOND");
const branchGrants = [
  ["ceo", main, "manage"], ["ceo", second, "manage"],
  ["salesManager", main, "manage"], ["salesManager", second, "manage"],
  ["salesRep", main, "operate"],
  ["finance", second, "operate"],
  ["finance", main, "operate"],
  ["operations", main, "manage"], ["operations", second, "manage"],
  ["taskUser", main, "operate"],
];
for (const [key, branch, accessLevel] of branchGrants) {
  const account = accounts.find((item) => item.key === key);
  const { error } = await supabase.from("user_branch_access").upsert({
    organization_id: organization.id,
    user_id: account.userId,
    branch_id: branch.id,
    access_level: accessLevel,
    granted_by: ceo.userId,
  }, { onConflict: "organization_id,user_id,branch_id" });
  if (error) throw error;
}

console.log("Foundation demo seed completed for the isolated ECO_DEMO tenant.");
for (const account of accounts) console.log(`${account.name}: ${account.email}`);
console.log("Passwords were read from environment variables and were not printed.");
