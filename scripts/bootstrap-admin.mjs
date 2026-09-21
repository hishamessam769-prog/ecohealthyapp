import { createClient } from "@supabase/supabase-js";

const required = [
  "NEXT_PUBLIC_SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "BOOTSTRAP_ADMIN_EMAIL",
  "BOOTSTRAP_ADMIN_PASSWORD",
  "BOOTSTRAP_ADMIN_NAME",
  "BOOTSTRAP_ORGANIZATION_NAME",
  "BOOTSTRAP_ORGANIZATION_CODE",
];

const missing = required.filter((name) => !process.env[name]);
if (missing.length) {
  throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

const email = process.env.BOOTSTRAP_ADMIN_EMAIL.trim().toLowerCase();
const password = process.env.BOOTSTRAP_ADMIN_PASSWORD;
if (password.length < 12 || password === "CHANGE_ME_BEFORE_RUNNING") {
  throw new Error("BOOTSTRAP_ADMIN_PASSWORD must be a unique password of at least 12 characters.");
}

let user;
for (let page = 1; page <= 10 && !user; page += 1) {
  const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
  if (error) throw error;
  user = data.users.find((candidate) => candidate.email?.toLowerCase() === email);
  if (data.users.length < 100) break;
}

if (!user) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: process.env.BOOTSTRAP_ADMIN_NAME },
  });
  if (error) throw error;
  user = data.user;
}

if (!user) throw new Error("Unable to create or resolve the bootstrap user.");

const organizationCode = process.env.BOOTSTRAP_ORGANIZATION_CODE.trim().toUpperCase();
const { data: organization, error: organizationError } = await supabase
  .from("organizations")
  .upsert(
    {
      code: organizationCode,
      name: process.env.BOOTSTRAP_ORGANIZATION_NAME,
      created_by: user.id,
    },
    { onConflict: "code" },
  )
  .select("id, name")
  .single();
if (organizationError) throw organizationError;

const { data: role, error: roleError } = await supabase
  .from("roles")
  .select("id")
  .eq("code", "ceo_super_admin")
  .is("organization_id", null)
  .single();
if (roleError) throw roleError;

const { error: membershipError } = await supabase.from("organization_memberships").upsert(
  {
    organization_id: organization.id,
    user_id: user.id,
    status: "active",
    invited_by: user.id,
    activated_at: new Date().toISOString(),
  },
  { onConflict: "organization_id,user_id" },
);
if (membershipError) throw membershipError;

const { error: roleAssignmentError } = await supabase.from("user_roles").upsert(
  {
    organization_id: organization.id,
    user_id: user.id,
    role_id: role.id,
    assigned_by: user.id,
  },
  { onConflict: "organization_id,user_id,role_id" },
);
if (roleAssignmentError) throw roleAssignmentError;

const { data: branch, error: branchError } = await supabase.from("branches").upsert(
  {
    organization_id: organization.id,
    code: "MAIN",
    name: "Main Branch",
    status: "active",
    created_by: user.id,
  },
  { onConflict: "organization_id,code" },
).select("id").single();
if (branchError) throw branchError;

const { error: accessError } = await supabase.from("user_branch_access").upsert(
  {
    organization_id: organization.id,
    user_id: user.id,
    branch_id: branch.id,
    access_level: "manage",
    granted_by: user.id,
  },
  { onConflict: "organization_id,user_id,branch_id" },
);
if (accessError) throw accessError;

const settings = [
  { organization_id: organization.id, key: "organization.timezone", value: "Africa/Cairo", description: "Operational display timezone", updated_by: user.id },
  { organization_id: organization.id, key: "organization.base_currency", value: "EGP", description: "Base reporting currency", updated_by: user.id },
];
const { error: settingsError } = await supabase.from("app_settings").upsert(settings, { onConflict: "organization_id,key" });
if (settingsError) throw settingsError;

console.log(`Bootstrap complete for ${organization.name}. Admin: ${email}`);
console.log("Remove BOOTSTRAP_ADMIN_PASSWORD and SUPABASE_SERVICE_ROLE_KEY from any local command history after use.");
