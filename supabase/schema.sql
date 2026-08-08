-- ECO Healthy ERP — Supabase / PostgreSQL schema
-- Run on a NEW Supabase project from SQL Editor.

create extension if not exists pgcrypto;

-- ============================================================
-- Types
-- ============================================================

create type public.employee_role as enum ('admin','sales','cs','kitchen','delivery','accounting');
create type public.subscription_status as enum ('active','paused','finished','canceled');
create type public.delivery_frequency as enum ('daily','weekly');
create type public.payment_mode as enum ('prepaid','pay_on_first_delivery');
create type public.order_status as enum ('draft','confirmed','canceled','refunded');
create type public.meal_type as enum ('standard','lc','high_protein');
create type public.fulfillment_status as enum ('planned','locked','in_prep','ready','dispatched','delivered','failed','canceled');
create type public.kitchen_status as enum ('pending','in_prep','approved_done');
create type public.delivery_status as enum ('pending','out_for_delivery','delivered','failed');
create type public.collection_method as enum ('cash','card','instapay');
create type public.payment_status as enum ('pending','verified','rejected','refunded');
create type public.cancellation_status as enum ('requested','reviewed','approved','transferred','rejected');
create type public.notification_kind as enum ('kitchen','accounting','sales','system');

-- ============================================================
-- Auth / RBAC
-- ============================================================

create table public.employee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.employee_role not null default 'cs',
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_employee()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.employee_profiles (user_id, full_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'full_name',''), new.email, 'موظف'))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

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
  select p.role from public.employee_profiles p
  where p.user_id = auth.uid() and p.active = true
  limit 1;
$$;

create or replace function public.has_role(variadic allowed public.employee_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_employee_role() = any(allowed), false);
$$;

-- ============================================================
-- CRM
-- ============================================================

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) > 1),
  phone text not null unique,
  delivery_zone smallint not null check (delivery_zone between 1 and 4),
  location_url text,
  address_text text,
  dietary_notes text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.client_issues (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  note text not null check (length(trim(note)) > 0),
  image_url text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Menu, recipes and packages
-- ============================================================

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  meal_type public.meal_type not null default 'standard',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name, meal_type)
);

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  unit text not null check (unit in ('g','kg','ml','l','piece')),
  active boolean not null default true
);

create table public.meal_ingredients (
  meal_id uuid not null references public.meals(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  primary key (meal_id, ingredient_id)
);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  number_of_days integer not null check (number_of_days > 0),
  price numeric(12,2) not null check (price >= 0),
  default_meal_id uuid not null references public.meals(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Financial contract (orders) — intentionally separated from fulfillment
-- ============================================================

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  client_id uuid not null references public.clients(id) on delete restrict,
  package_id uuid not null references public.packages(id) on delete restrict,
  sales_user_id uuid references auth.users(id) on delete set null,
  total_days integer not null check (total_days > 0),
  subtotal numeric(12,2) not null check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total_price numeric(12,2) not null check (total_price >= 0),
  payment_mode public.payment_mode not null,
  status public.order_status not null default 'draft',
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (total_price = greatest(subtotal - discount, 0))
);

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  method public.collection_method not null,
  status public.payment_status not null default 'pending',
  reference text,
  collected_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  collected_at timestamptz not null default now(),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Subscription and decoupled fulfillment ledger
-- ============================================================

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  order_id uuid not null unique references public.orders(id) on delete restrict,
  package_id uuid not null references public.packages(id) on delete restrict,
  status public.subscription_status not null default 'active',
  start_date date not null,
  delivery_frequency public.delivery_frequency not null default 'daily',
  weekly_delivery_day smallint check (weekly_delivery_day between 1 and 7),
  total_days integer not null check (total_days > 0),
  consumed_days integer not null default 0 check (consumed_days >= 0),
  remaining_days integer generated always as (greatest(total_days - consumed_days, 0)) stored,
  first_delivery_completed boolean not null default false,
  payment_verified boolean not null default false,
  delivery_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (consumed_days <= total_days),
  check ((delivery_frequency = 'weekly' and weekly_delivery_day is not null) or (delivery_frequency = 'daily' and weekly_delivery_day is null))
);

create table public.subscription_pauses (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  pause_from date not null,
  pause_until date,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  resumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (pause_until is null or pause_until >= pause_from)
);

create table public.kitchen_batches (
  id uuid primary key default gen_random_uuid(),
  production_date date not null unique,
  cutoff_at timestamptz not null,
  locked_at timestamptz not null default now(),
  source text not null default 'automatic' check (source in ('automatic','manual')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.fulfillment_days (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  kitchen_batch_id uuid references public.kitchen_batches(id) on delete set null,
  day_number integer not null check (day_number > 0),
  service_date date not null,
  original_meal_id uuid not null references public.meals(id) on delete restrict,
  current_meal_id uuid not null references public.meals(id) on delete restrict,
  meal_type public.meal_type not null,
  quantity integer not null default 1 check (quantity > 0),
  status public.fulfillment_status not null default 'planned',
  locked_at timestamptz,
  manual_override boolean not null default false,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subscription_id, day_number),
  unique (subscription_id, service_date)
);

create table public.meal_swaps (
  id uuid primary key default gen_random_uuid(),
  fulfillment_day_id uuid not null references public.fulfillment_days(id) on delete restrict,
  old_meal_id uuid not null references public.meals(id) on delete restrict,
  new_meal_id uuid not null references public.meals(id) on delete restrict,
  old_meal_type public.meal_type not null,
  new_meal_type public.meal_type not null,
  reason text,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);

create table public.production_queue (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.kitchen_batches(id) on delete restrict,
  fulfillment_day_id uuid not null unique references public.fulfillment_days(id) on delete restrict,
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  production_date date not null,
  client_name_snapshot text not null,
  meal_name_snapshot text not null,
  meal_type public.meal_type not null,
  quantity integer not null default 1 check (quantity > 0),
  delivery_zone smallint not null check (delivery_zone between 1 and 4),
  dietary_notes_snapshot text,
  status public.kitchen_status not null default 'pending',
  source text not null default 'automatic' check (source in ('automatic','admin_override')),
  approved_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- Delivery and cash collection
-- ============================================================

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  fulfillment_day_id uuid not null unique references public.fulfillment_days(id) on delete restrict,
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  delivery_date date not null,
  zone smallint not null check (zone between 1 and 4),
  rider_user_id uuid references auth.users(id) on delete set null,
  status public.delivery_status not null default 'pending',
  cash_expected numeric(12,2) not null default 0 check (cash_expected >= 0),
  collection_method public.collection_method,
  amount_collected numeric(12,2) not null default 0 check (amount_collected >= 0),
  collection_logged_at timestamptz,
  delivered_at timestamptz,
  failed_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- Cancellation / refund workflow
-- ============================================================

create table public.cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  remaining_value numeric(12,2) not null check (remaining_value >= 0),
  consumed_value numeric(12,2) not null check (consumed_value >= 0),
  consumed_penalty numeric(12,2) not null check (consumed_penalty >= 0),
  delivery_penalty numeric(12,2) not null check (delivery_penalty >= 0),
  refund_amount numeric(12,2) not null check (refund_amount >= 0),
  status public.cancellation_status not null default 'requested',
  receipt_url text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  transferred_at timestamptz,
  notes text
);

create unique index one_open_cancellation_per_subscription
on public.cancellation_requests(subscription_id)
where status in ('requested','reviewed','approved');

-- ============================================================
-- Sales / targets
-- ============================================================

create table public.sales_targets (
  id uuid primary key default gen_random_uuid(),
  sales_user_id uuid not null references auth.users(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  target_amount numeric(12,2) not null check (target_amount > 0),
  created_at timestamptz not null default now(),
  unique (sales_user_id, period_start, period_end),
  check (period_end >= period_start)
);

-- ============================================================
-- Notifications / push / event outbox / audit
-- ============================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  target_role public.employee_role,
  target_user_id uuid references auth.users(id) on delete cascade,
  kind public.notification_kind not null default 'system',
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (target_role is not null or target_user_id is not null)
);

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth_key text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  unique (user_id, endpoint)
);

create table public.event_outbox (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid,
  payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.system_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.system_settings(key, value)
values
  ('kitchen_cutoff', '{"timezone":"Africa/Cairo","hour":17,"minute":0}'::jsonb),
  ('cancellation_rules', '{"consumed_penalty_percent":20,"delivery_day_fee_egp":30}'::jsonb)
on conflict (key) do nothing;

-- ============================================================
-- Views
-- ============================================================

create view public.subscription_financial_status
with (security_invoker = true)
as
select
  s.id as subscription_id,
  s.client_id,
  s.status,
  s.total_days,
  s.consumed_days,
  s.remaining_days,
  o.payment_mode,
  s.first_delivery_completed,
  s.payment_verified,
  (o.payment_mode = 'pay_on_first_delivery' and s.first_delivery_completed and not s.payment_verified) as financially_blocked
from public.subscriptions s
join public.orders o on o.id = s.order_id;

create view public.kitchen_explosion_report
with (security_invoker = true)
as
select
  q.production_date,
  i.id as ingredient_id,
  i.name as ingredient_name,
  i.unit,
  sum(mi.quantity * q.quantity) as required_quantity
from public.production_queue q
join public.fulfillment_days f on f.id = q.fulfillment_day_id
join public.meal_ingredients mi on mi.meal_id = f.current_meal_id
join public.ingredients i on i.id = mi.ingredient_id
group by q.production_date, i.id, i.name, i.unit;

create view public.sales_commission_progress
with (security_invoker = true)
as
with revenue as (
  select
    t.id as target_id,
    t.sales_user_id,
    t.period_start,
    t.period_end,
    t.target_amount,
    coalesce(sum(o.total_price) filter (
      where o.confirmed_at::date between t.period_start and t.period_end
        and s.status <> 'canceled'
        and s.consumed_days::numeric / nullif(s.total_days, 0) > 0.50
    ), 0)::numeric(12,2) as confirmed_revenue
  from public.sales_targets t
  left join public.orders o on o.sales_user_id = t.sales_user_id
  left join public.subscriptions s on s.order_id = o.id
  group by t.id, t.sales_user_id, t.period_start, t.period_end, t.target_amount
), calc as (
  select *, case when target_amount > 0 then confirmed_revenue / target_amount * 100 else 0 end as achievement_percent
  from revenue
)
select *,
  case
    when achievement_percent < 80 then 0
    when achievement_percent < 100 then 3
    when achievement_percent < 120 then 3.5
    when achievement_percent <= 150 then 4
    else 5
  end::numeric(4,2) as commission_rate,
  (confirmed_revenue * (case
    when achievement_percent < 80 then 0
    when achievement_percent < 100 then 3
    when achievement_percent < 120 then 3.5
    when achievement_percent <= 150 then 4
    else 5
  end) / 100)::numeric(12,2) as commission_amount
from calc;

-- ============================================================
-- Common update timestamp
-- ============================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger employee_profiles_updated_at before update on public.employee_profiles for each row execute procedure public.set_updated_at();
create trigger clients_updated_at before update on public.clients for each row execute procedure public.set_updated_at();
create trigger orders_updated_at before update on public.orders for each row execute procedure public.set_updated_at();
create trigger subscriptions_updated_at before update on public.subscriptions for each row execute procedure public.set_updated_at();
create trigger fulfillment_updated_at before update on public.fulfillment_days for each row execute procedure public.set_updated_at();
create trigger production_queue_updated_at before update on public.production_queue for each row execute procedure public.set_updated_at();
create trigger deliveries_updated_at before update on public.deliveries for each row execute procedure public.set_updated_at();

-- ============================================================
-- Business rules and automation functions
-- ============================================================

-- Confirmed financial contracts cannot be silently rewritten by a meal swap.
create or replace function public.protect_confirmed_order_financials()
returns trigger language plpgsql as $$
begin
  if old.status = 'confirmed' and (
    new.package_id is distinct from old.package_id or
    new.total_days is distinct from old.total_days or
    new.subtotal is distinct from old.subtotal or
    new.discount is distinct from old.discount or
    new.total_price is distinct from old.total_price or
    new.payment_mode is distinct from old.payment_mode
  ) then
    raise exception 'Confirmed financial contract is immutable';
  end if;
  return new;
end;
$$;

create trigger protect_confirmed_order
before update on public.orders
for each row execute procedure public.protect_confirmed_order_financials();

-- Meal swaps write an audit row and never touch public.orders.
create or replace function public.swap_fulfillment_meal(
  p_fulfillment_day_id uuid,
  p_new_meal_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  f public.fulfillment_days;
  m public.meals;
begin
  if not public.has_role('admin','cs') then raise exception 'Not allowed'; end if;
  select * into f from public.fulfillment_days where id = p_fulfillment_day_id for update;
  if not found then raise exception 'Fulfillment day not found'; end if;
  if f.service_date <= current_date then raise exception 'Only future days can be swapped'; end if;
  if f.locked_at is not null and not public.has_role('admin') then raise exception 'Kitchen list is already locked'; end if;
  select * into m from public.meals where id = p_new_meal_id and active = true;
  if not found then raise exception 'Meal not found'; end if;

  insert into public.meal_swaps(fulfillment_day_id, old_meal_id, new_meal_id, old_meal_type, new_meal_type, reason, changed_by)
  values (f.id, f.current_meal_id, m.id, f.meal_type, m.meal_type, p_reason, auth.uid());

  update public.fulfillment_days
  set current_meal_id = m.id, meal_type = m.meal_type
  where id = f.id;
end;
$$;

-- Automated 17:00 job target. Schedule this function daily from Supabase Cron.
create or replace function public.run_kitchen_cutoff(p_production_date date default (timezone('Africa/Cairo', now())::date + 1))
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch uuid;
begin
  insert into public.kitchen_batches(production_date, cutoff_at, source, created_by)
  values (p_production_date, now(), 'automatic', auth.uid())
  on conflict (production_date) do update set production_date = excluded.production_date
  returning id into v_batch;

  insert into public.fulfillment_days(
    subscription_id, kitchen_batch_id, day_number, service_date,
    original_meal_id, current_meal_id, meal_type, status, locked_at
  )
  select
    s.id, v_batch, s.consumed_days + 1, p_production_date,
    p.default_meal_id, p.default_meal_id, m.meal_type, 'locked', now()
  from public.subscriptions s
  join public.orders o on o.id = s.order_id
  join public.packages p on p.id = s.package_id
  join public.meals m on m.id = p.default_meal_id
  where s.status = 'active'
    and s.start_date <= p_production_date
    and s.remaining_days > 0
    and (s.delivery_frequency = 'daily' or extract(isodow from p_production_date)::int = s.weekly_delivery_day)
    and not exists (
      select 1 from public.subscription_pauses sp
      where sp.subscription_id = s.id
        and p_production_date >= sp.pause_from
        and p_production_date <= coalesce(sp.pause_until, 'infinity'::date)
    )
    and not (o.payment_mode = 'pay_on_first_delivery' and s.first_delivery_completed and not s.payment_verified)
  on conflict do nothing;

  update public.fulfillment_days
  set kitchen_batch_id = v_batch, status = case when status = 'planned' then 'locked' else status end, locked_at = coalesce(locked_at, now())
  where service_date = p_production_date and consumed_at is null;

  insert into public.production_queue(
    batch_id, fulfillment_day_id, subscription_id, client_id, production_date,
    client_name_snapshot, meal_name_snapshot, meal_type, quantity,
    delivery_zone, dietary_notes_snapshot, source
  )
  select
    v_batch, f.id, s.id, c.id, p_production_date,
    c.full_name, m.name, f.meal_type, f.quantity,
    c.delivery_zone, c.dietary_notes, case when f.manual_override then 'admin_override' else 'automatic' end
  from public.fulfillment_days f
  join public.subscriptions s on s.id = f.subscription_id
  join public.orders o on o.id = s.order_id
  join public.clients c on c.id = s.client_id
  join public.meals m on m.id = f.current_meal_id
  where f.service_date = p_production_date
    and s.status = 'active'
    and not (o.payment_mode = 'pay_on_first_delivery' and s.first_delivery_completed and not s.payment_verified)
  on conflict (fulfillment_day_id) do nothing;

  insert into public.event_outbox(event_type, aggregate_type, aggregate_id, payload)
  values ('kitchen.cutoff.locked','kitchen_batch',v_batch,jsonb_build_object('production_date',p_production_date));

  return v_batch;
end;
$$;

revoke all on function public.run_kitchen_cutoff(date) from public, anon, authenticated;
grant execute on function public.run_kitchen_cutoff(date) to service_role;

-- Approved kitchen items automatically become delivery jobs by zone.
create or replace function public.queue_delivery_after_kitchen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders;
  v_sub public.subscriptions;
  v_cash numeric(12,2) := 0;
begin
  if new.status = 'approved_done' and old.status is distinct from 'approved_done' then
    select * into v_sub from public.subscriptions where id = new.subscription_id;
    select * into v_order from public.orders where id = v_sub.order_id;

    if v_order.payment_mode = 'pay_on_first_delivery' and v_sub.first_delivery_completed and not v_sub.payment_verified then
      raise exception 'Subscription is financially blocked';
    end if;

    if v_order.payment_mode = 'pay_on_first_delivery' and not v_sub.first_delivery_completed then
      select greatest(v_order.total_price - coalesce(sum(pt.amount) filter (where pt.status = 'verified'), 0), 0)
      into v_cash
      from public.payment_transactions pt
      where pt.order_id = v_order.id;
    end if;

    update public.fulfillment_days set status = 'ready' where id = new.fulfillment_day_id;

    insert into public.deliveries(fulfillment_day_id, subscription_id, client_id, delivery_date, zone, cash_expected)
    values (new.fulfillment_day_id, new.subscription_id, new.client_id, new.production_date, new.delivery_zone, coalesce(v_cash, v_order.total_price))
    on conflict (fulfillment_day_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger production_to_delivery
after update of status on public.production_queue
for each row execute procedure public.queue_delivery_after_kitchen();

-- Rider cash collection instantly creates an Accounting alert.
create or replace function public.notify_cash_collection()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_order_id uuid;
begin
  if new.collection_logged_at is not null and old.collection_logged_at is null and new.amount_collected > 0 then
    select full_name into v_name from public.clients where id = new.client_id;
    select order_id into v_order_id from public.subscriptions where id = new.subscription_id;
    insert into public.payment_transactions(order_id, amount, method, status, reference, collected_by, collected_at)
    values (v_order_id, new.amount_collected, coalesce(new.collection_method, 'cash'), 'pending', 'Delivery ' || new.id::text, auth.uid(), new.collection_logged_at);
    insert into public.notifications(target_role, kind, title, body, entity_type, entity_id)
    values ('accounting','accounting','تحصيل جديد من الكابتن',format('%s — تم تسجيل تحصيل %s ج',v_name,new.amount_collected),'delivery',new.id);
    insert into public.event_outbox(event_type, aggregate_type, aggregate_id, payload)
    values ('delivery.cash_collected','delivery',new.id,jsonb_build_object('amount',new.amount_collected,'method',new.collection_method));
  end if;
  return new;
end;
$$;

create trigger delivery_cash_notification
after update of collection_logged_at on public.deliveries
for each row execute procedure public.notify_cash_collection();

-- Delivery completion deducts exactly one subscription day once and creates alerts.
create or replace function public.complete_delivery_day()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.subscriptions;
  v_order public.orders;
  v_client public.clients;
  v_remaining integer;
begin
  if new.status = 'delivered' and old.status is distinct from 'delivered' then
    select * into v_sub from public.subscriptions where id = new.subscription_id for update;
    select * into v_order from public.orders where id = v_sub.order_id;
    select * into v_client from public.clients where id = v_sub.client_id;

    if v_order.payment_mode = 'pay_on_first_delivery' and v_sub.first_delivery_completed and not v_sub.payment_verified then
      raise exception 'Payment must be verified before another delivery';
    end if;

    update public.fulfillment_days
    set status = 'delivered', consumed_at = coalesce(consumed_at, now())
    where id = new.fulfillment_day_id and consumed_at is null;

    update public.subscriptions
    set consumed_days = least(consumed_days + 1, total_days),
        first_delivery_completed = true,
        status = case when consumed_days + 1 >= total_days then 'finished' else status end
    where id = v_sub.id
    returning remaining_days into v_remaining;

    new.delivered_at := coalesce(new.delivered_at, now());

    if v_remaining between 1 and 3 then
      insert into public.notifications(target_role, kind, title, body, entity_type, entity_id)
      values ('sales','sales','اشتراك قرب يخلص',format('%s باقي له %s يوم',v_client.full_name,v_remaining),'subscription',v_sub.id);
    end if;

    if v_order.payment_mode = 'pay_on_first_delivery' and not v_sub.payment_verified then
      insert into public.notifications(target_role, kind, title, body, entity_type, entity_id)
      values ('accounting','accounting','مطلوب تأكيد PayOnFirstDelivery',format('%s استلم أول توصيل؛ الطلبات التالية محظورة حتى تأكيد الدفع',v_client.full_name),'subscription',v_sub.id);
    end if;

    insert into public.event_outbox(event_type, aggregate_type, aggregate_id, payload)
    values ('delivery.completed','subscription',v_sub.id,jsonb_build_object('delivery_id',new.id,'remaining_days',v_remaining));
  end if;
  return new;
end;
$$;

create trigger delivery_completion
before update of status on public.deliveries
for each row execute procedure public.complete_delivery_day();

-- Emergency Admin addition after Cut-off alerts Kitchen immediately.
create or replace function public.notify_kitchen_override()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source = 'admin_override' then
    insert into public.notifications(target_role, kind, title, body, entity_type, entity_id)
    values ('kitchen','kitchen','إضافة طارئة بعد Cut-off',format('%s — %s × %s',new.client_name_snapshot,new.quantity,new.meal_name_snapshot),'production_queue',new.id);
    insert into public.event_outbox(event_type, aggregate_type, aggregate_id, payload)
    values ('kitchen.admin_override','production_queue',new.id,jsonb_build_object('production_date',new.production_date));
  end if;
  return new;
end;
$$;

create trigger kitchen_override_notification
after insert on public.production_queue
for each row execute procedure public.notify_kitchen_override();

-- Verifying a payment opens the financial gate.
create or replace function public.verify_order_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'verified' and old.status is distinct from 'verified' then
    update public.subscriptions set payment_verified = true where order_id = new.order_id;
    new.verified_at := coalesce(new.verified_at, now());
    new.verified_by := coalesce(new.verified_by, auth.uid());
  end if;
  return new;
end;
$$;

create trigger payment_verification_gate
before update of status on public.payment_transactions
for each row execute procedure public.verify_order_payment();

-- Accounting transfer finalizes the cancellation and freezes the subscription.
create or replace function public.finalize_cancellation_transfer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_order_id uuid;
begin
  if new.status = 'transferred' and old.status is distinct from 'transferred' then
    if nullif(trim(coalesce(new.receipt_url,'')), '') is null then
      raise exception 'Receipt URL is required before transfer confirmation';
    end if;
    new.transferred_at := coalesce(new.transferred_at, now());
    new.reviewed_by := coalesce(new.reviewed_by, auth.uid());
    select order_id into v_order_id from public.subscriptions where id = new.subscription_id;
    update public.subscriptions set status = 'canceled' where id = new.subscription_id;
    update public.orders set status = 'refunded' where id = v_order_id;
    insert into public.event_outbox(event_type, aggregate_type, aggregate_id, payload)
    values ('cancellation.refund_transferred','cancellation_request',new.id,jsonb_build_object('refund_amount',new.refund_amount,'receipt_url',new.receipt_url));
  end if;
  return new;
end;
$$;

create trigger cancellation_transfer_finalized
before update of status on public.cancellation_requests
for each row execute procedure public.finalize_cancellation_transfer();

-- Cancellation formula snapshot: remaining - 20% consumed - 30 EGP per delivered day.
create or replace function public.request_subscription_cancellation(p_subscription_id uuid, p_notes text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.subscriptions;
  o public.orders;
  v_price_per_day numeric;
  v_consumed numeric;
  v_remaining numeric;
  v_consumed_penalty numeric;
  v_delivery_penalty numeric;
  v_refund numeric;
  v_id uuid;
begin
  if not public.has_role('admin','cs') then raise exception 'Not allowed'; end if;
  select * into s from public.subscriptions where id = p_subscription_id;
  if not found or s.status not in ('active','paused') then raise exception 'Subscription cannot be canceled'; end if;
  select * into o from public.orders where id = s.order_id;
  v_price_per_day := o.total_price / s.total_days;
  v_consumed := round(v_price_per_day * s.consumed_days, 2);
  v_remaining := round(v_price_per_day * s.remaining_days, 2);
  v_consumed_penalty := round(v_consumed * 0.20, 2);
  select count(*) * 30 into v_delivery_penalty from public.deliveries where subscription_id = s.id and status = 'delivered';
  v_refund := greatest(v_remaining - v_consumed_penalty - v_delivery_penalty, 0);

  insert into public.cancellation_requests(subscription_id, client_id, requested_by, remaining_value, consumed_value, consumed_penalty, delivery_penalty, refund_amount, notes)
  values (s.id, s.client_id, auth.uid(), v_remaining, v_consumed, v_consumed_penalty, v_delivery_penalty, v_refund, p_notes)
  returning id into v_id;

  insert into public.notifications(target_role, kind, title, body, entity_type, entity_id)
  values ('accounting','accounting','طلب إلغاء جديد',format('Refund محسوب: %s ج',v_refund),'cancellation_request',v_id);
  return v_id;
end;
$$;

-- ============================================================
-- Indexes
-- ============================================================

create index idx_clients_zone on public.clients(delivery_zone) where active = true;
create index idx_client_issues_client_time on public.client_issues(client_id, created_at desc);
create index idx_orders_client_status on public.orders(client_id, status);
create index idx_subscriptions_client_status on public.subscriptions(client_id, status);
create index idx_subscriptions_status_remaining on public.subscriptions(status, remaining_days);
create index idx_fulfillment_service_status on public.fulfillment_days(service_date, status);
create index idx_queue_date_status on public.production_queue(production_date, status);
create index idx_deliveries_date_zone_status on public.deliveries(delivery_date, zone, status);
create index idx_payments_order_status on public.payment_transactions(order_id, status);
create index idx_notifications_role_unread on public.notifications(target_role, created_at desc) where read_at is null;
create index idx_outbox_unprocessed on public.event_outbox(created_at) where processed_at is null;

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.employee_profiles enable row level security;
alter table public.clients enable row level security;
alter table public.client_issues enable row level security;
alter table public.meals enable row level security;
alter table public.ingredients enable row level security;
alter table public.meal_ingredients enable row level security;
alter table public.packages enable row level security;
alter table public.orders enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_pauses enable row level security;
alter table public.kitchen_batches enable row level security;
alter table public.fulfillment_days enable row level security;
alter table public.meal_swaps enable row level security;
alter table public.production_queue enable row level security;
alter table public.deliveries enable row level security;
alter table public.cancellation_requests enable row level security;
alter table public.sales_targets enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.event_outbox enable row level security;
alter table public.audit_log enable row level security;
alter table public.system_settings enable row level security;

-- Employee profiles: authenticated staff may identify coworkers; only Admin changes roles.
create policy employee_profiles_read on public.employee_profiles for select to authenticated using (active = true or user_id = auth.uid() or public.has_role('admin'));
create policy employee_profiles_admin_write on public.employee_profiles for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));

-- CRM
create policy clients_read on public.clients for select to authenticated using (public.has_role('admin','sales','cs','kitchen','delivery','accounting'));
create policy clients_write on public.clients for insert to authenticated with check (public.has_role('admin','sales','cs'));
create policy clients_update on public.clients for update to authenticated using (public.has_role('admin','sales','cs')) with check (public.has_role('admin','sales','cs'));
create policy clients_delete on public.clients for delete to authenticated using (public.has_role('admin'));
create policy issues_read on public.client_issues for select to authenticated using (public.has_role('admin','sales','cs'));
create policy issues_write on public.client_issues for insert to authenticated with check (public.has_role('admin','cs'));
create policy issues_update on public.client_issues for update to authenticated using (public.has_role('admin','cs')) with check (public.has_role('admin','cs'));
create policy issues_delete on public.client_issues for delete to authenticated using (public.has_role('admin'));

-- Catalog / recipes
create policy meals_read on public.meals for select to authenticated using (true);
create policy meals_write on public.meals for all to authenticated using (public.has_role('admin','kitchen')) with check (public.has_role('admin','kitchen'));
create policy ingredients_read on public.ingredients for select to authenticated using (public.has_role('admin','kitchen'));
create policy ingredients_write on public.ingredients for all to authenticated using (public.has_role('admin','kitchen')) with check (public.has_role('admin','kitchen'));
create policy meal_ingredients_read on public.meal_ingredients for select to authenticated using (public.has_role('admin','kitchen'));
create policy meal_ingredients_write on public.meal_ingredients for all to authenticated using (public.has_role('admin','kitchen')) with check (public.has_role('admin','kitchen'));
create policy packages_read on public.packages for select to authenticated using (true);
create policy packages_write on public.packages for all to authenticated using (public.has_role('admin','sales')) with check (public.has_role('admin','sales'));

-- Financial contract
create policy orders_read on public.orders for select to authenticated using (public.has_role('admin','sales','cs','accounting'));
create policy orders_insert on public.orders for insert to authenticated with check (public.has_role('admin','sales'));
create policy orders_update on public.orders for update to authenticated using (public.has_role('admin','sales','accounting')) with check (public.has_role('admin','sales','accounting'));
create policy orders_delete on public.orders for delete to authenticated using (public.has_role('admin') and status = 'draft');
create policy payments_read on public.payment_transactions for select to authenticated using (public.has_role('admin','sales','accounting','delivery'));
create policy payments_insert on public.payment_transactions for insert to authenticated with check (
  public.has_role('admin','accounting')
  or (public.has_role('delivery') and status = 'pending' and collected_by = auth.uid())
);
create policy payments_update on public.payment_transactions for update to authenticated using (public.has_role('admin','accounting')) with check (public.has_role('admin','accounting'));

-- Subscription / fulfillment
create policy subscriptions_read on public.subscriptions for select to authenticated using (true);
create policy subscriptions_insert on public.subscriptions for insert to authenticated with check (public.has_role('admin','sales'));
create policy subscriptions_update on public.subscriptions for update to authenticated using (public.has_role('admin','sales','cs','accounting')) with check (public.has_role('admin','sales','cs','accounting'));
create policy subscriptions_delete on public.subscriptions for delete to authenticated using (public.has_role('admin'));
create policy pauses_read on public.subscription_pauses for select to authenticated using (public.has_role('admin','sales','cs','accounting'));
create policy pauses_write on public.subscription_pauses for insert to authenticated with check (public.has_role('admin','cs'));
create policy pauses_update on public.subscription_pauses for update to authenticated using (public.has_role('admin','cs')) with check (public.has_role('admin','cs'));
create policy pauses_delete on public.subscription_pauses for delete to authenticated using (public.has_role('admin','cs'));
create policy batches_read on public.kitchen_batches for select to authenticated using (public.has_role('admin','kitchen'));
create policy batches_admin on public.kitchen_batches for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));
create policy fulfillment_read on public.fulfillment_days for select to authenticated using (true);
create policy fulfillment_insert on public.fulfillment_days for insert to authenticated with check (public.has_role('admin','cs'));
create policy fulfillment_update on public.fulfillment_days for update to authenticated using (public.has_role('admin','cs','kitchen','delivery')) with check (public.has_role('admin','cs','kitchen','delivery'));
create policy swaps_read on public.meal_swaps for select to authenticated using (public.has_role('admin','sales','cs','kitchen','accounting'));
create policy swaps_insert on public.meal_swaps for insert to authenticated with check (public.has_role('admin','cs'));
create policy queue_read on public.production_queue for select to authenticated using (public.has_role('admin','kitchen'));
create policy queue_update on public.production_queue for update to authenticated using (public.has_role('admin','kitchen')) with check (public.has_role('admin','kitchen'));
create policy queue_admin_insert on public.production_queue for insert to authenticated with check (public.has_role('admin'));

-- Delivery
create policy deliveries_read on public.deliveries for select to authenticated using (public.has_role('admin','delivery','accounting','cs'));
create policy deliveries_insert on public.deliveries for insert to authenticated with check (public.has_role('admin','delivery'));
create policy deliveries_update on public.deliveries for update to authenticated using (public.has_role('admin','delivery','accounting')) with check (public.has_role('admin','delivery','accounting'));

-- Cancellations
create policy cancellations_read on public.cancellation_requests for select to authenticated using (public.has_role('admin','cs','accounting'));
create policy cancellations_insert on public.cancellation_requests for insert to authenticated with check (public.has_role('admin','cs'));
create policy cancellations_update on public.cancellation_requests for update to authenticated using (public.has_role('admin','accounting')) with check (public.has_role('admin','accounting'));

-- Sales
create policy sales_targets_read on public.sales_targets for select to authenticated using (public.has_role('admin','accounting') or (public.has_role('sales') and sales_user_id = auth.uid()));
create policy sales_targets_write on public.sales_targets for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));

-- Notifications / device push
create policy notifications_read on public.notifications for select to authenticated using (public.has_role('admin') or target_user_id = auth.uid() or target_role = public.current_employee_role());
create policy notifications_mark_read on public.notifications for update to authenticated using (public.has_role('admin') or target_user_id = auth.uid() or target_role = public.current_employee_role()) with check (public.has_role('admin') or target_user_id = auth.uid() or target_role = public.current_employee_role());
create policy notifications_admin_insert on public.notifications for insert to authenticated with check (public.has_role('admin'));
create policy push_own_read on public.push_subscriptions for select to authenticated using (user_id = auth.uid());
create policy push_own_insert on public.push_subscriptions for insert to authenticated with check (user_id = auth.uid());
create policy push_own_update on public.push_subscriptions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy push_own_delete on public.push_subscriptions for delete to authenticated using (user_id = auth.uid());

-- Internal events / audit / settings
create policy outbox_admin_read on public.event_outbox for select to authenticated using (public.has_role('admin'));
create policy audit_admin_read on public.audit_log for select to authenticated using (public.has_role('admin'));
create policy audit_staff_insert on public.audit_log for insert to authenticated with check (actor_user_id = auth.uid());
create policy settings_read on public.system_settings for select to authenticated using (true);
create policy settings_admin_write on public.system_settings for all to authenticated using (public.has_role('admin')) with check (public.has_role('admin'));

-- ============================================================
-- Grants for invoker views / RPCs
-- ============================================================

grant select on public.subscription_financial_status to authenticated;
grant select on public.kitchen_explosion_report to authenticated;
grant select on public.sales_commission_progress to authenticated;
grant execute on function public.swap_fulfillment_meal(uuid,uuid,text) to authenticated;
grant execute on function public.request_subscription_cancellation(uuid,text) to authenticated;
revoke execute on function public.request_subscription_cancellation(uuid,text) from anon;

-- Reference data only; no fake customer PII is inserted into Supabase.
insert into public.meals(name, meal_type) values
  ('Grilled Chicken','standard'),
  ('LC Chicken','lc'),
  ('High Protein Chicken','high_protein')
on conflict (name, meal_type) do nothing;

insert into public.packages(name, number_of_days, price, default_meal_id)
select '6 Days Starter', 6, 1800, id from public.meals where name = 'Grilled Chicken' and meal_type = 'standard'
on conflict (name) do nothing;
insert into public.packages(name, number_of_days, price, default_meal_id)
select '12 Days Healthy', 12, 3600, id from public.meals where name = 'Grilled Chicken' and meal_type = 'standard'
on conflict (name) do nothing;
insert into public.packages(name, number_of_days, price, default_meal_id)
select '18 Days LC', 18, 5400, id from public.meals where name = 'LC Chicken' and meal_type = 'lc'
on conflict (name) do nothing;
insert into public.packages(name, number_of_days, price, default_meal_id)
select '24 Days High Protein', 24, 7200, id from public.meals where name = 'High Protein Chicken' and meal_type = 'high_protein'
on conflict (name) do nothing;
