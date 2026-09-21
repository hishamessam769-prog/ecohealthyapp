import { readFile, writeFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import { citext } from "@electric-sql/pglite/contrib/citext";
import { btree_gist } from "@electric-sql/pglite/contrib/btree_gist";
import { pgtap } from "@electric-sql/pglite/pgtap";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFile(new URL(path, new URL("..", import.meta.url)), "utf8");
const db = new PGlite({ extensions: { citext, btree_gist, pgtap } });
const resetDb = new PGlite({ extensions: { citext, btree_gist, pgtap } });

const bootstrap = `
  create schema extensions;
  create schema auth;
  create schema storage;
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
  create role supabase_admin nologin;
  create table auth.users(
    instance_id uuid,
    id uuid primary key,
    aud text,
    role text,
    email text,
    encrypted_password text,
    email_confirmed_at timestamptz,
    raw_app_meta_data jsonb not null default '{}'::jsonb,
    raw_user_meta_data jsonb not null default '{}'::jsonb
    ,created_at timestamptz not null default now()
    ,updated_at timestamptz not null default now()
  );
  create or replace function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create or replace function auth.role() returns text language sql stable as
    $$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'service_role') $$;
  create table storage.buckets(
    id text primary key,
    name text not null,
    public boolean not null default false,
    file_size_limit bigint,
    allowed_mime_types text[]
  );
  create table storage.objects(
    id uuid primary key default pg_catalog.gen_random_uuid(),
    bucket_id text not null references storage.buckets(id),
    name text not null,
    owner_id text
  );
  alter table storage.objects enable row level security;
  create or replace function storage.foldername(name text) returns text[] language sql immutable as
    $$ select string_to_array(name, '/') $$;
  create or replace function extensions.gen_random_uuid() returns uuid language sql volatile as
    $$ select pg_catalog.gen_random_uuid() $$;
`;

async function countDemoRows() {
  const tables = await db.query(`
    select table_name from information_schema.columns
    where table_schema='public' and column_name='is_demo'
    order by table_name
  `);
  let total = 0;
  for (const { table_name } of tables.rows) {
    const result = await db.query(`select count(*)::integer as count from public."${table_name}" where is_demo`);
    total += Number(result.rows[0].count);
  }
  return { tableCount: tables.rows.length, total };
}

try {
  await resetDb.exec(bootstrap);
  await resetDb.exec("create table public.legacy_erp_table(id integer); insert into public.legacy_erp_table values(1);");
  let resetInstaller = await read("outputs/00_RESET_AND_INSTALL_COMPLETE_DATABASE.sql");
  resetInstaller = resetInstaller.replace("create extension if not exists pgcrypto with schema extensions;", "-- pgcrypto provided by PostgreSQL core in the embedded test harness");
  await resetDb.exec(resetInstaller);
  const resetValidation = await resetDb.query("select * from public.validate_eco_healthy_installation() order by check_name");
  if (resetValidation.rows.some((row) => !row.passed)) {
    throw new Error(`Reset installation validation failed: ${JSON.stringify(resetValidation.rows)}`);
  }
  const legacyCheck = await resetDb.query("select to_regclass('public.legacy_erp_table') is null as removed");
  if (!legacyCheck.rows[0]?.removed) throw new Error("Reset installer did not remove the legacy public schema.");

  await db.exec(bootstrap);
  let master = await read("outputs/01_install_complete_database.sql");
  master = master.replace("create extension if not exists pgcrypto with schema extensions;", "-- pgcrypto provided by PostgreSQL core in the embedded test harness");
  await db.exec(master);
  await db.exec(`
    grant usage on schema public to authenticated;
    grant all on all tables in schema public to authenticated;
    grant usage, select on all sequences in schema public to authenticated;
  `);

  const validation = await db.query("select * from public.validate_eco_healthy_installation() order by check_name");
  if (validation.rows.some((row) => !row.passed)) {
    throw new Error(`Installation validation failed: ${JSON.stringify(validation.rows)}`);
  }

  const adminId = "11111111-1111-4111-8111-111111111111";
  await db.query(
    "insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3::jsonb)",
    [adminId, "admin.local@example.invalid", JSON.stringify({ full_name: "Local Test Admin" })],
  );
  await db.query(
    "select * from public.claim_initial_setup($1,$2,$3,$4)",
    [adminId, "Eco Healthy Local Test", "ECO_TEST", "Local Test Admin"],
  );

  let secondSetupBlocked = false;
  try {
    await db.query(
      "select * from public.claim_initial_setup($1,$2,$3,$4)",
      [adminId, "Should Fail", "FAIL_TEST", "Local Test Admin"],
    );
  } catch (error) {
    secondSetupBlocked = String(error.message).includes("already completed");
  }
  if (!secondSetupBlocked) throw new Error("Second setup attempt was not blocked.");

  await db.exec(await read("outputs/02_install_demo_data.sql"));
  await db.exec(await read("outputs/04_install_subscription_acceptance_demo.sql"));
  const operationFixture = await db.query(`
    select s.id as subscription_id,d.id as day_id,si.installed_by
    from public.subscriptions s
    join public.planned_service_days d on d.subscription_id=s.id and d.status='planned'
    cross join public.system_installations si
    where s.is_demo and s.status='active'
      and not exists(select 1 from public.refunds r where r.subscription_id=s.id)
    order by s.subscription_number,d.service_date limit 1
  `);
  const operation = operationFixture.rows[0];
  const plannedBefore = await db.query("select count(*)::integer as count from public.planned_service_days where subscription_id=$1 and status='planned'", [operation.subscription_id]);
  await db.query("select public.apply_service_day_action(array[$1::uuid],'skip',1,'Embedded acceptance test',$2)", [operation.day_id, operation.installed_by]);
  const skipCheck = await db.query("select status from public.planned_service_days where id=$1", [operation.day_id]);
  const plannedAfter = await db.query("select count(*)::integer as count from public.planned_service_days where subscription_id=$1 and status='planned'", [operation.subscription_id]);
  if (skipCheck.rows[0]?.status !== "not_delivered" || plannedAfter.rows[0]?.count !== plannedBefore.rows[0]?.count) throw new Error("Skip day did not create a replacement service day.");
  await db.query("select public.request_calculated_subscription_refund($1,'TRAVEL','Embedded acceptance test','instapay','Acceptance Customer','01000000000',$2)", [operation.subscription_id, operation.installed_by]);
  const refundCheck = await db.query("select amount,calculation_basis from public.refunds where subscription_id=$1 order by requested_at desc limit 1", [operation.subscription_id]);
  if (!refundCheck.rows[0] || Number(refundCheck.rows[0].amount) <= 0 || Number(refundCheck.rows[0].calculation_basis?.remaining_days || 0) <= 0) throw new Error("Calculated refund acceptance check failed.");
  const subscriptionOperationChecks = { skipCreatesReplacement: true, calculatedRefundUsesRemainingDays: true };
  const installedDemo = await countDemoRows();
  if (installedDemo.total < 350) throw new Error(`Demo installer created too few rows: ${installedDemo.total}`);

  await db.exec(await read("outputs/03_remove_demo_data.sql"));
  const remainingDemo = await countDemoRows();
  if (remainingDemo.total !== 0) throw new Error(`Demo cleanup left ${remainingDemo.total} rows.`);

  const counts = await db.query(`
    select
      (select count(*)::integer from public.roles where is_system) as system_roles,
      (select count(*)::integer from public.permissions) as permissions,
      (select count(*)::integer from information_schema.tables where table_schema='public') as public_tables
  `);
  const pgTapFiles = [
    "supabase/tests/database/0001_foundation_rls.sql",
    "supabase/tests/database/0002_permission_behavior.sql",
    "supabase/tests/database/0003_foundation_security.sql",
    "supabase/tests/database/0004_erp_modules.sql",
    "supabase/tests/database/0005_commercial_cycle.sql",
  ];
  await db.exec(`
    create extension if not exists pgtap with schema extensions;
    grant usage on schema extensions to authenticated;
    grant execute on all functions in schema extensions to authenticated;
    set search_path = public, extensions;
  `);
  const pgTap = [];
  for (const file of pgTapFiles) {
    const results = await db.exec(await read(file));
    const messages = results.flatMap((result) => result.rows || []).flatMap((row) => Object.values(row).map(String));
    const failures = messages.filter((message) => message.startsWith("not ok"));
    if (failures.length) throw new Error(`${file} failed: ${failures.join(" | ")}`);
    pgTap.push({ file, passed: true });
  }
  const evidence = {
    engine: "PGlite PostgreSQL WASM with Supabase auth/storage contract stubs",
    masterSqlExecutedFromEmptyDatabase: true,
    resetInstallerReplacedLegacyPublicSchema: true,
    validation: validation.rows,
    setupCreated: true,
    secondSetupBlocked,
    demoRowsInstalled: installedDemo.total,
    demoTables: installedDemo.tableCount,
    demoRowsAfterCleanup: remainingDemo.total,
    subscriptionOperationChecks,
    pgTap,
    ...counts.rows[0],
  };
  await writeFile(`${root}outputs/embedded-database-test.json`, JSON.stringify(evidence, null, 2) + "\n");
  console.log(JSON.stringify(evidence, null, 2));
} finally {
  await resetDb.close();
  await db.close();
}
