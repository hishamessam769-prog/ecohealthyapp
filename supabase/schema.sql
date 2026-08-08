-- ============================================================
-- ECO Healthy ERP MVP - Supabase Schema
-- شغّل الملف بالكامل مرة واحدة داخل Supabase SQL Editor
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- الأنواع ----------

do $$ begin
  create type public.employee_role as enum (
    'admin', 'sales', 'cs', 'kitchen', 'delivery', 'accounting'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.subscription_status as enum (
    'scheduled', 'active', 'paused', 'completed', 'canceled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.payment_mode as enum ('prepaid', 'pay_on_first_delivery');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.payment_status as enum ('unpaid', 'partial', 'paid', 'refunded');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.fulfillment_status as enum (
    'planned', 'locked', 'in_production', 'ready',
    'dispatched', 'delivered', 'failed', 'skipped', 'canceled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.queue_status as enum ('waiting', 'preparing', 'done');
exception when duplicate_object then null;
end $$;

-- ---------- الموظفون والصلاحيات ----------

create table if not exists public.employee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.employee_role not null default 'cs',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_employee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.employee_profiles (user_id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_employee();

create or replace function public.current_employee_role()
returns public.employee_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.employee_profiles
  where user_id = auth.uid() and active = true
  limit 1;
$$;

-- ---------- العملاء ----------

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null unique,
  area text,
  address text,
  map_url text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- الأوردر المالي ----------
-- هذا الجدول يمثل العقد المالي ولا يتغير عند تغيير وجبة في يوم معين.

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  client_id uuid not null references public.clients(id) on delete restrict,
  sales_user_id uuid references auth.users(id) on delete set null,
  package_name text not null,
  total_days integer not null check (total_days > 0),
  total_price numeric(12,2) not null check (total_price >= 0),
  payment_mode public.payment_mode not null default 'prepaid',
  payment_status public.payment_status not null default 'unpaid',
  amount_paid numeric(12,2) not null default 0 check (amount_paid >= 0),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- الاشتراكات ----------

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  order_id uuid not null unique references public.orders(id) on delete restrict,
  program_name text not null,
  total_days integer not null check (total_days > 0),
  start_date date not null,
  status public.subscription_status not null default 'active',
  delivery_frequency text not null default 'daily'
    check (delivery_frequency in ('daily', 'weekly', 'custom')),
  weekly_delivery_day smallint check (weekly_delivery_day between 0 and 6),
  delivery_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- دفتر التنفيذ اليومي ----------
-- هذا الجدول منفصل تماماً عن الأوردر المالي.

create table if not exists public.fulfillment_days (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  day_number integer not null check (day_number > 0),
  service_date date not null,
  production_date date not null,
  meal_name text not null,
  meal_type text not null default 'standard'
    check (meal_type in ('standard', 'lc', 'high_protein', 'other')),
  quantity integer not null default 1 check (quantity > 0),
  status public.fulfillment_status not null default 'planned',
  locked_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subscription_id, day_number)
);

-- ---------- طابور المطبخ ----------
-- يحتفظ Snapshot حتى لا تتغير قائمة المطبخ بعد القفل بصمت.

create table if not exists public.production_queue (
  id uuid primary key default gen_random_uuid(),
  fulfillment_day_id uuid not null unique references public.fulfillment_days(id) on delete restrict,
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  production_date date not null,
  client_name_snapshot text not null,
  program_name_snapshot text not null,
  meal_name_snapshot text not null,
  meal_type text not null,
  quantity integer not null default 1 check (quantity > 0),
  area_snapshot text,
  delivery_note_snapshot text,
  status public.queue_status not null default 'waiting',
  locked boolean not null default true,
  source text not null default 'automatic'
    check (source in ('automatic', 'vip_override')),
  created_at timestamptz not null default now()
);

-- ---------- سجل تغيير الوجبات ----------

create table if not exists public.meal_swaps (
  id uuid primary key default gen_random_uuid(),
  fulfillment_day_id uuid not null references public.fulfillment_days(id) on delete cascade,
  old_meal_name text not null,
  old_meal_type text not null,
  new_meal_name text not null,
  new_meal_type text not null,
  reason text,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- الإيقاف المؤقت ----------

create table if not exists public.subscription_pauses (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  pause_from date not null,
  pause_until date,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (pause_until is null or pause_until >= pause_from)
);

-- ---------- View رصيد الاشتراك ----------

drop view if exists public.subscription_balances;
create view public.subscription_balances
with (security_invoker = true)
as
select
  s.id as subscription_id,
  s.client_id,
  s.program_name,
  s.status,
  s.total_days,
  count(f.id) filter (where f.consumed_at is not null) :: integer as consumed_days,
  greatest(
    s.total_days - count(f.id) filter (where f.consumed_at is not null),
    0
  ) :: integer as remaining_days
from public.subscriptions s
left join public.fulfillment_days f on f.subscription_id = s.id
group by s.id;

-- ---------- Function قفل طابور المطبخ ----------
-- يستعملها Admin لاحقاً من Cron عند 17:00.

create or replace function public.lock_kitchen_queue(p_production_date date)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  if public.current_employee_role() is distinct from 'admin'::public.employee_role then
    raise exception 'Admin only';
  end if;

  insert into public.production_queue (
    fulfillment_day_id,
    subscription_id,
    client_id,
    production_date,
    client_name_snapshot,
    program_name_snapshot,
    meal_name_snapshot,
    meal_type,
    quantity,
    area_snapshot,
    delivery_note_snapshot
  )
  select
    f.id,
    s.id,
    c.id,
    f.production_date,
    c.full_name,
    s.program_name,
    f.meal_name,
    f.meal_type,
    f.quantity,
    c.area,
    s.delivery_notes
  from public.fulfillment_days f
  join public.subscriptions s on s.id = f.subscription_id
  join public.clients c on c.id = s.client_id
  where f.production_date = p_production_date
    and f.status = 'planned'
    and s.status = 'active'
  on conflict (fulfillment_day_id) do nothing;

  get diagnostics inserted_count = row_count;

  update public.fulfillment_days
  set status = 'locked',
      locked_at = coalesce(locked_at, now()),
      updated_at = now()
  where production_date = p_production_date
    and status = 'planned'
    and exists (
      select 1
      from public.production_queue q
      where q.fulfillment_day_id = fulfillment_days.id
    );

  return inserted_count;
end;
$$;

revoke all on function public.lock_kitchen_queue(date) from public;
revoke all on function public.lock_kitchen_queue(date) from anon;
grant execute on function public.lock_kitchen_queue(date) to authenticated;

-- ---------- updated_at ----------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists clients_set_updated_at on public.clients;
create trigger clients_set_updated_at
before update on public.clients
for each row execute procedure public.set_updated_at();

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute procedure public.set_updated_at();

drop trigger if exists fulfillment_set_updated_at on public.fulfillment_days;
create trigger fulfillment_set_updated_at
before update on public.fulfillment_days
for each row execute procedure public.set_updated_at();

-- ---------- Indexes ----------

create index if not exists idx_subscriptions_client_status
  on public.subscriptions (client_id, status);

create index if not exists idx_fulfillment_production_status
  on public.fulfillment_days (production_date, status);

create index if not exists idx_queue_date_status
  on public.production_queue (production_date, status);

create index if not exists idx_queue_client
  on public.production_queue (client_id);

-- ============================================================
-- Row Level Security
-- كل البيانات لا تظهر إلا بعد تسجيل الدخول.
-- ============================================================

alter table public.employee_profiles enable row level security;
alter table public.clients enable row level security;
alter table public.orders enable row level security;
alter table public.subscriptions enable row level security;
alter table public.fulfillment_days enable row level security;
alter table public.production_queue enable row level security;
alter table public.meal_swaps enable row level security;
alter table public.subscription_pauses enable row level security;

drop policy if exists "profile_read_own" on public.employee_profiles;
create policy "profile_read_own"
on public.employee_profiles for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "clients_read" on public.clients;
create policy "clients_read"
on public.clients for select
to authenticated
using (true);

drop policy if exists "clients_ops_write" on public.clients;
create policy "clients_ops_write"
on public.clients for all
to authenticated
using (public.current_employee_role() in ('admin','sales','cs'))
with check (public.current_employee_role() in ('admin','sales','cs'));

drop policy if exists "orders_read" on public.orders;
create policy "orders_read"
on public.orders for select
to authenticated
using (true);

drop policy if exists "orders_sales_write" on public.orders;
create policy "orders_sales_write"
on public.orders for all
to authenticated
using (public.current_employee_role() in ('admin','sales'))
with check (public.current_employee_role() in ('admin','sales'));

drop policy if exists "subscriptions_read" on public.subscriptions;
create policy "subscriptions_read"
on public.subscriptions for select
to authenticated
using (true);

drop policy if exists "subscriptions_ops_write" on public.subscriptions;
create policy "subscriptions_ops_write"
on public.subscriptions for all
to authenticated
using (public.current_employee_role() in ('admin','sales','cs'))
with check (public.current_employee_role() in ('admin','sales','cs'));

drop policy if exists "fulfillment_read" on public.fulfillment_days;
create policy "fulfillment_read"
on public.fulfillment_days for select
to authenticated
using (true);

drop policy if exists "fulfillment_cs_write" on public.fulfillment_days;
create policy "fulfillment_cs_write"
on public.fulfillment_days for all
to authenticated
using (public.current_employee_role() in ('admin','cs'))
with check (public.current_employee_role() in ('admin','cs'));

drop policy if exists "kitchen_queue_read" on public.production_queue;
create policy "kitchen_queue_read"
on public.production_queue for select
to authenticated
using (true);

drop policy if exists "kitchen_queue_admin_write" on public.production_queue;
create policy "kitchen_queue_admin_write"
on public.production_queue for all
to authenticated
using (public.current_employee_role() = 'admin')
with check (public.current_employee_role() = 'admin');

drop policy if exists "meal_swaps_read" on public.meal_swaps;
create policy "meal_swaps_read"
on public.meal_swaps for select
to authenticated
using (true);

drop policy if exists "meal_swaps_cs_write" on public.meal_swaps;
create policy "meal_swaps_cs_write"
on public.meal_swaps for insert
to authenticated
with check (public.current_employee_role() in ('admin','cs'));

drop policy if exists "pauses_read" on public.subscription_pauses;
create policy "pauses_read"
on public.subscription_pauses for select
to authenticated
using (true);

drop policy if exists "pauses_cs_write" on public.subscription_pauses;
create policy "pauses_cs_write"
on public.subscription_pauses for all
to authenticated
using (public.current_employee_role() in ('admin','cs'))
with check (public.current_employee_role() in ('admin','cs'));

-- لا يحتاج العميل في الواجهة أي Service Role Key.
-- استخدم فقط NEXT_PUBLIC_SUPABASE_URL و NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.
