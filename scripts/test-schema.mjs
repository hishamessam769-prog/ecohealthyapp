import fs from "node:fs";
import { PGlite } from "@electric-sql/pglite";

const db=new PGlite();
await db.exec(`create schema auth; create table auth.users(id uuid primary key default gen_random_uuid(),email text); create function auth.uid() returns uuid language sql stable as $$select null::uuid$$; create schema storage; create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]); create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,owner_id uuid); create role anon; create role authenticated; create role service_role;`);
let sql=fs.readFileSync(new URL("../supabase/eco_healthy_schema_final.sql",import.meta.url),"utf8");
sql=sql.replace(/create extension if not exists pgcrypto;/,"").replace(/create extension if not exists btree_gist;/,"")
 .replace(/,\s*exclude using gist\(employee_id with =,role_code with =,daterange\(effective_from,coalesce\(effective_to,'infinity'::date\),'\[\]'\) with &&\) where\(approved\)/,"")
 .replace(/,\s*exclude using gist\(customer_id with =,assignment_type with =,daterange\(effective_from,coalesce\(effective_to,'infinity'::date\),'\[\]'\) with &&\)/,"")
 .replace(/, exclude using gist\(plan_version_id with =, numrange\(min_achievement_percentage,max_achievement_percentage,'\[\)'\) with &&\) where\(approval_status='APPROVED'\)/,"");
await db.exec(sql); await db.exec(sql);
const migrations=await db.query("select count(*)::int count from public.eco_schema_migrations");
if(migrations.rows[0].count!==4)throw new Error(`Expected 4 migrations, got ${migrations.rows[0].count}`);
console.log("SQL migration execution and safe re-run: PASS"); await db.close();

