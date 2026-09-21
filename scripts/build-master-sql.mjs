import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const migrationsDir = join(root, "supabase", "migrations");
const output = join(root, "outputs", "01_install_complete_database.sql");
const resetOutput = join(root, "outputs", "00_RESET_AND_INSTALL_COMPLETE_DATABASE.sql");
const incrementalOutput = join(root, "deliverables", "SUPABASE_UPDATE_V12_AND_DEMO.sql");
const migrations = (await readdir(migrationsDir))
  .filter((name) => /^\d{4}_.+\.sql$/.test(name))
  .sort();

if (migrations.length !== 12) {
  throw new Error(`Expected 12 numbered migrations, found ${migrations.length}.`);
}

const parts = [
  "-- Eco Healthy ERP — complete database installer",
  "-- Generated from the numbered migrations. Run once in a new Supabase SQL Editor.",
  "-- Contains no passwords, tokens, API keys, or demo data.",
  "",
];

for (const migration of migrations) {
  parts.push(`-- ============================================================================`);
  parts.push(`-- ${migration}`);
  parts.push(`-- ============================================================================`);
  parts.push((await readFile(join(migrationsDir, migration), "utf8")).trim());
  parts.push("");
}

parts.push("-- Installation validation: every returned row must show passed = true.");
parts.push("select * from public.validate_eco_healthy_installation();");
parts.push("");

const masterSql = parts.join("\n");
await writeFile(output, masterSql, "utf8");

const resetPreamble = `-- Eco Healthy ERP — destructive reset and complete installer
-- WARNING: This permanently deletes every object and row in the public schema.
-- Use only on the dedicated Supabase project whose old ERP database must be replaced.
-- Supabase Auth users and stored file objects are intentionally not deleted.
-- Delete obsolete Auth users from Authentication > Users before /setup if reusing an email.

begin;
drop policy if exists erp_attachments_read on storage.objects;
drop policy if exists erp_attachments_insert on storage.objects;
drop policy if exists erp_attachments_delete on storage.objects;
drop schema if exists public cascade;
create schema public authorization postgres;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant create on schema public to postgres, service_role;
alter default privileges for role postgres in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on functions to postgres, anon, authenticated, service_role;
commit;

`;

const resetPostamble = `
-- Restore the standard Supabase API grants after recreating the public schema.
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;
grant all on all routines in schema public to postgres, anon, authenticated, service_role;

-- Final validation: every returned row must show passed = true.
select * from public.validate_eco_healthy_installation();
`;

await writeFile(resetOutput, resetPreamble + masterSql + resetPostamble, "utf8");
await mkdir(join(root, "deliverables"), { recursive: true });
const migration12 = await readFile(join(migrationsDir, "0012_subscription_operations_acceptance.sql"), "utf8");
const acceptanceDemo = await readFile(join(root, "outputs", "04_install_subscription_acceptance_demo.sql"), "utf8");
await writeFile(incrementalOutput, [
  "-- Eco Healthy ERP V12 — incremental subscription operations update + safe demo data",
  "-- Run this ONLY after V11 is already installed (your validator previously showed Installed versions: 11).",
  "-- This file does not delete non-demo records and contains no passwords or API keys.",
  "",
  migration12.trim(),
  "",
  acceptanceDemo.trim(),
  "",
  "-- Every row below must show passed = true.",
  "select * from public.validate_eco_healthy_installation();",
  "",
].join("\n"), "utf8");
console.log(`Wrote ${output} from ${migrations.length} migrations.`);
console.log(`Wrote ${resetOutput} for an approved destructive replacement install.`);
console.log(`Wrote ${incrementalOutput} for the current V11 staging database.`);
