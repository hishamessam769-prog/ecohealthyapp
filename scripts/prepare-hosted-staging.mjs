import { mkdir, writeFile } from "node:fs/promises";
import { createClient } from "@supabase/supabase-js";

const required = [
  "NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY",
  "E2E_SALES_EMAIL", "E2E_SALES_PASSWORD", "E2E_FINANCE_EMAIL", "E2E_FINANCE_PASSWORD",
  "E2E_OPERATIONS_EMAIL", "E2E_OPERATIONS_PASSWORD",
];
for (const key of required) if (!process.env[key]) throw new Error(`${key} is required.`);
if (process.env.HOSTED_E2E_ALLOW_STAGING_SETUP !== "true") throw new Error("Set HOSTED_E2E_ALLOW_STAGING_SETUP=true only for a disposable Staging project.");

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });

async function ensureUser(email, password, name) {
  const { data: listed, error: listError } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listError) throw listError;
  let user = listed.users.find((item) => item.email?.toLowerCase() === email.toLowerCase());
  if (!user) {
    const { data, error } = await supabase.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name } });
    if (error || !data.user) throw error || new Error(`Could not create ${name}`);
    user = data.user;
  } else {
    const { data, error } = await supabase.auth.admin.updateUserById(user.id, { password, email_confirm: true, user_metadata: { ...user.user_metadata, full_name: name } });
    if (error || !data.user) throw error || new Error(`Could not update ${name}`);
    user = data.user;
  }
  return user;
}

const sales = await ensureUser(process.env.E2E_SALES_EMAIL, process.env.E2E_SALES_PASSWORD, "Staging Sales User");
const finance = await ensureUser(process.env.E2E_FINANCE_EMAIL, process.env.E2E_FINANCE_PASSWORD, "Staging Finance User");
const operations = await ensureUser(process.env.E2E_OPERATIONS_EMAIL, process.env.E2E_OPERATIONS_PASSWORD, "Staging Operations User");

let { data: organization, error: organizationError } = await supabase.from("organizations").select("id,code,name").eq("code", "E2E_STAGING").maybeSingle();
if (organizationError) throw organizationError;
if (!organization) {
  const result = await supabase.from("organizations").insert({ code: "E2E_STAGING", name: "Eco Healthy Hosted E2E Staging", created_by: sales.id }).select("id,code,name").single();
  if (result.error) throw result.error; organization = result.data;
}
let { data: branch, error: branchError } = await supabase.from("branches").select("id,code,name").eq("organization_id", organization.id).eq("code", "E2E_MAIN").maybeSingle();
if (branchError) throw branchError;
if (!branch) {
  const result = await supabase.from("branches").insert({ organization_id: organization.id, code: "E2E_MAIN", name: "Hosted E2E Main Branch", created_by: sales.id }).select("id,code,name").single();
  if (result.error) throw result.error; branch = result.data;
}

for (const user of [sales, finance, operations]) {
  const { error } = await supabase.from("organization_memberships").upsert({ organization_id: organization.id, user_id: user.id, status: "active", activated_at: new Date().toISOString() }, { onConflict: "organization_id,user_id" });
  if (error) throw error;
  const access = await supabase.from("user_branch_access").upsert({ organization_id: organization.id, user_id: user.id, branch_id: branch.id, access_level: "operate", granted_by: sales.id }, { onConflict: "organization_id,user_id,branch_id" });
  if (access.error) throw access.error;
}
const { data: roles, error: rolesError } = await supabase.from("roles").select("id,code").in("code", ["sales_representative", "sales_manager", "finance_accountant", "operations_manager"]).is("organization_id", null);
if (rolesError) throw rolesError;
const roleMap = new Map(roles.map((role) => [role.code, role.id]));
const roleAssignments = [
  [sales.id, "sales_representative"], [sales.id, "sales_manager"],
  [finance.id, "finance_accountant"], [operations.id, "operations_manager"],
];
for (const [userId, code] of roleAssignments) {
  const { error } = await supabase.from("user_roles").upsert({ organization_id: organization.id, user_id: userId, role_id: roleMap.get(code), assigned_by: sales.id }, { onConflict: "organization_id,user_id,role_id" });
  if (error) throw error;
}

let { data: packageRow, error: packageError } = await supabase.from("packages").select("id").eq("organization_id", organization.id).eq("code", "E2E_ECO30").maybeSingle();
if (packageError) throw packageError;
if (!packageRow) {
  const result = await supabase.from("packages").insert({ organization_id: organization.id, code: "E2E_ECO30", name: "Eco 30 Hosted E2E", description: "Disposable staging test package", created_by: sales.id }).select("id").single();
  if (result.error) throw result.error; packageRow = result.data;
}
let { data: version, error: versionError } = await supabase.from("package_versions").select("id").eq("package_id", packageRow.id).eq("version_number", 1).maybeSingle();
if (versionError) throw versionError;
if (!version) {
  const result = await supabase.from("package_versions").insert({ package_id: packageRow.id, version_number: 1, effective_from: new Date().toISOString().slice(0, 10), currency: "EGP", price: 6000, service_days: 30, meals_per_day: 3, status: "active", created_by: sales.id }).select("id").single();
  if (result.error) throw result.error; version = result.data;
}
const { data: discount } = await supabase.from("discount_limits").select("id").eq("organization_id", organization.id).eq("user_id", sales.id).is("effective_to", null).maybeSingle();
if (discount) {
  const result = await supabase.from("discount_limits").update({ maximum_percent: 10, approved_by: finance.id }).eq("id", discount.id);
  if (result.error) throw result.error;
} else {
  const result = await supabase.from("discount_limits").insert({ organization_id: organization.id, user_id: sales.id, maximum_percent: 10, effective_from: new Date().toISOString().slice(0, 10), approved_by: finance.id });
  if (result.error) throw result.error;
}
const today = new Date(); const periodStart = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().slice(0, 10); const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().slice(0, 10);
const { data: target } = await supabase.from("sales_targets").select("id").eq("organization_id", organization.id).eq("user_id", sales.id).eq("period_start", periodStart).maybeSingle();
if (!target) { const result = await supabase.from("sales_targets").insert({ organization_id: organization.id, branch_id: branch.id, target_type: "user", user_id: sales.id, period_start: periodStart, period_end: periodEnd, target_amount: 100000, created_by: finance.id }); if (result.error) throw result.error; }
let { data: policy } = await supabase.from("sales_commission_policies").select("id").eq("organization_id", organization.id).eq("name", "Hosted E2E confirmed cash").maybeSingle();
if (!policy) { const result = await supabase.from("sales_commission_policies").insert({ organization_id: organization.id, name: "Hosted E2E confirmed cash", applies_to_role_code: "sales_representative" }).select("id").single(); if (result.error) throw result.error; policy = result.data; }
const { data: policyVersion } = await supabase.from("sales_commission_policy_versions").select("id").eq("policy_id", policy.id).eq("version_number", 1).maybeSingle();
if (!policyVersion) { const result = await supabase.from("sales_commission_policy_versions").insert({ policy_id: policy.id, version_number: 1, method: "confirmed_cash_percent", value: 3, effective_from: periodStart, created_by: finance.id }); if (result.error) throw result.error; }

await mkdir("outputs/hosted-e2e", { recursive: true });
await writeFile("outputs/hosted-e2e/preflight.json", JSON.stringify({ preparedAt: new Date().toISOString(), supabaseUrlHost: new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).host, organizationId: organization.id, branchId: branch.id, packageVersionId: version.id, users: { sales: sales.id, finance: finance.id, operations: operations.id }, secretsWritten: false }, null, 2));
console.log("Hosted staging fixture is ready. No passwords or keys were written to disk.");
