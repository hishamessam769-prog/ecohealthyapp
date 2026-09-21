import { readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { citext } from "@electric-sql/pglite/contrib/citext";
import { btree_gist } from "@electric-sql/pglite/contrib/btree_gist";

const root = new URL("..", import.meta.url).pathname;
const db = new PGlite({ extensions: { citext, btree_gist } });
const bootstrap = `
create schema extensions; create schema auth; create schema storage;
create role anon nologin; create role authenticated nologin; create role service_role nologin; create role supabase_admin nologin;
create table auth.users(instance_id uuid,id uuid primary key,aud text,role text,email text,encrypted_password text,email_confirmed_at timestamptz,raw_app_meta_data jsonb not null default '{}'::jsonb,raw_user_meta_data jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create or replace function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create or replace function auth.role() returns text language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'service_role')$$;
create table storage.buckets(id text primary key,name text not null,public boolean not null default false,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default pg_catalog.gen_random_uuid(),bucket_id text not null references storage.buckets(id),name text not null,owner_id text);
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$select string_to_array(name,'/')$$;
create or replace function extensions.gen_random_uuid() returns uuid language sql volatile as $$select pg_catalog.gen_random_uuid()$$;
`;

try {
  await db.exec(bootstrap);
  const migrationNames = (await readdir(join(root, "supabase", "migrations")))
    .filter((name) => /^\d{4}_.+\.sql$/.test(name) && !name.startsWith("0013_"))
    .sort();
  for (const name of migrationNames) {
    let sql = await readFile(join(root, "supabase", "migrations", name), "utf8");
    sql = sql.replace("create extension if not exists pgcrypto with schema extensions;", "-- pgcrypto provided by PostgreSQL core in the embedded test harness");
    await db.exec(sql);
  }
  const before = await db.query("select max(version)::integer as version from public.schema_versions");
  if (before.rows[0]?.version !== 12) throw new Error(`Expected V12 before upgrade, received ${before.rows[0]?.version}`);
  await db.exec(await readFile(join(root, "deliverables", "SUPABASE_UPDATE_V13.sql"), "utf8"));
  const validation = await db.query("select * from public.validate_eco_healthy_installation() order by check_name");
  if (validation.rows.some((row) => !row.passed)) throw new Error(`V13 validation failed: ${JSON.stringify(validation.rows)}`);
  const mobile = await db.query("select public.normalize_egypt_mobile('+20 101 234 5678') as canonical");
  if (mobile.rows[0]?.canonical !== "01012345678") throw new Error("Egyptian mobile normalization failed");
  const evidence = { upgradedFrom: 12, version: 13, canonicalMobile: mobile.rows[0].canonical, validation: validation.rows };
  await writeFile(join(root, "outputs", "v13-upgrade-test.json"), JSON.stringify(evidence, null, 2) + "\n");
  console.log(JSON.stringify(evidence, null, 2));
} finally {
  await db.close();
}
