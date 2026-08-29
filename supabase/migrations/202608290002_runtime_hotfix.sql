begin;

create extension if not exists pgcrypto with schema extensions;

alter function public.eco_begin_idempotent(text,text,uuid,jsonb)
  set search_path = public, extensions, pg_temp;

alter function public.eco_bootstrap_first_admin(uuid,text,text,text)
  set search_path = public, extensions, pg_temp;

alter function public.eco_create_priced_invoice(uuid,jsonb)
  set search_path = public, extensions, pg_temp;

insert into public.eco_schema_migrations(version,description,checksum)
values(
  '006_runtime_hotfix',
  'Fix pgcrypto resolution used by bootstrap, demo installation and invoice idempotency',
  'sha256:eco-v5-006-runtime-hotfix'
)
on conflict(version) do update
set description = excluded.description,
    checksum = excluded.checksum,
    applied_at = now();

select pg_notify('pgrst','reload schema');

commit;
