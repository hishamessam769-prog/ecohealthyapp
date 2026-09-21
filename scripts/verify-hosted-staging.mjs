import { mkdir, writeFile } from "node:fs/promises";
import { createClient } from "@supabase/supabase-js";

for (const key of ["NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]) {
  if (!process.env[key]) throw new Error(`${key} is required.`);
}
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
const [{ data: validation, error: validationError }, { data: versions, error: versionsError }] = await Promise.all([
  supabase.rpc("validate_eco_healthy_installation"),
  supabase.from("schema_versions").select("version,name,installed_at").order("version"),
]);
if (validationError) throw validationError;
if (versionsError) throw versionsError;
if (!validation?.length || validation.some((row) => !row.passed)) throw new Error(`Hosted installation validation failed: ${JSON.stringify(validation)}`);
if (versions?.length !== 11) throw new Error(`Expected 11 hosted schema versions, found ${versions?.length || 0}.`);
const evidence = { verifiedAt: new Date().toISOString(), hostedProjectHost: new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).host, validation, schemaVersions: versions, serviceRoleKeyWritten: false };
await mkdir("outputs/hosted-e2e", { recursive: true });
await writeFile("outputs/hosted-e2e/hosted-install-validation.json", JSON.stringify(evidence, null, 2));
console.log(JSON.stringify(evidence, null, 2));
