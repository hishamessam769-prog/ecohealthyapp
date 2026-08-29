-- ECO Healthy Enterprise ERP v4
-- Supabase / PostgreSQL 15+
-- Re-runnable installation. All ERP objects live in the isolated "erp" schema.
begin;

create extension if not exists pgcrypto;
create schema if not exists erp;
grant usage on schema erp to authenticated, service_role;

do $$ begin
  create type erp.employee_role as enum ('admin','sales','cs','kitchen','delivery','accounting');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.meal_slot as enum ('breakfast','lunch','dinner','snack');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.package_size as enum ('regular','hero','custom');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.order_kind as enum ('subscription','ad_hoc');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.order_status as enum ('pending_accounting','approved','rejected','canceled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.payment_method as enum ('cash','instapay','website_app','bank_transfer');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.payment_status as enum ('pending','verified','rejected','cod','refunded');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.delivery_frequency as enum ('daily','weekly');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.subscription_status as enum ('active','paused','finished','canceled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.fulfillment_status as enum ('planned','sent','in_prep','ready','delivered','canceled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.delivery_status as enum ('pending','out_for_delivery','delivered','failed');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.cancellation_status as enum ('requested','reviewed','transferred','rejected');
exception when duplicate_object then null; end $$;
do $$ begin
  create type erp.reconciliation_status as enum ('open','closed');
exception when duplicate_object then null; end $$;

create table if not exists erp.employees (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null,
  role erp.employee_role not null default 'sales',
  active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.zones (
  zone_number smallint primary key check (zone_number between 1 and 4),
  name text not null,
  default_delivery_fee numeric(12,2) not null default 0,
  active boolean not null default true
);

create table if not exists erp.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null unique,
  email text,
  zone_number smallint not null references erp.zones(zone_number),
  address text not null,
  location_url text,
  dietary_notes text not null default '',
  is_demo boolean not null default false,
  created_by uuid references erp.employees(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.client_dietary_rules (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references erp.clients(id) on delete cascade,
  rule_type text not null check (rule_type in ('exclusion','preference')),
  rule_text text not null,
  strict boolean not null default false,
  unique (client_id, rule_type, rule_text)
);

create table if not exists erp.complaints (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references erp.clients(id) on delete cascade,
  category text not null,
  details text not null,
  status text not null default 'open' check (status in ('open','resolved')),
  resolved_at timestamptz,
  created_by uuid references erp.employees(id),
  created_at timestamptz not null default now()
);

create table if not exists erp.meals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  slot erp.meal_slot not null,
  regular_cost numeric(12,2) not null default 0 check (regular_cost >= 0),
  hero_cost numeric(12,2) not null default 0 check (hero_cost >= 0),
  active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  days integer not null check (days > 0),
  price_regular numeric(12,2) not null check (price_regular >= 0),
  price_hero numeric(12,2) not null check (price_hero >= 0),
  active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.package_slots (
  package_id uuid not null references erp.packages(id) on delete cascade,
  slot erp.meal_slot not null,
  quantity smallint not null default 1 check (quantity > 0),
  primary key (package_id, slot)
);

create table if not exists erp.menu_months (
  id uuid primary key default gen_random_uuid(),
  month_start date not null unique check (month_start = date_trunc('month', month_start)::date),
  name text not null,
  locked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.menu_days (
  id uuid primary key default gen_random_uuid(),
  menu_month_id uuid not null references erp.menu_months(id) on delete cascade,
  service_date date not null,
  slot erp.meal_slot not null,
  meal_id uuid not null references erp.meals(id),
  notes text,
  unique (service_date, slot)
);

create table if not exists erp.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  kind erp.order_kind not null,
  client_id uuid not null references erp.clients(id),
  package_id uuid references erp.packages(id),
  ad_hoc_meal_id uuid references erp.meals(id),
  size erp.package_size not null,
  start_date date not null,
  delivery_date date,
  frequency erp.delivery_frequency not null default 'daily',
  weekly_day smallint check (weekly_day between 0 and 6),
  total_days integer not null default 1 check (total_days > 0),
  amount numeric(12,2) not null check (amount >= 0),
  delivery_fees numeric(12,2) not null default 0 check (delivery_fees >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  payment_method erp.payment_method not null,
  payment_status erp.payment_status not null default 'pending',
  reference_id text,
  proof_name text,
  status erp.order_status not null default 'pending_accounting',
  sales_rep_id uuid references erp.employees(id),
  notes text,
  is_demo boolean not null default false,
  created_by uuid references erp.employees(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((kind = 'subscription' and package_id is not null) or (kind = 'ad_hoc' and ad_hoc_meal_id is not null)),
  check (payment_method = 'cash' or (nullif(reference_id,'') is not null and nullif(proof_name,'') is not null))
);

create table if not exists erp.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references erp.orders(id) on delete cascade,
  client_id uuid not null references erp.clients(id),
  method erp.payment_method not null,
  amount numeric(12,2) not null check (amount >= 0),
  status erp.payment_status not null default 'pending',
  reference_id text,
  proof_name text,
  verified_at timestamptz,
  verified_by uuid references erp.employees(id),
  created_at timestamptz not null default now()
);

create unique index if not exists one_open_payment_per_order
  on erp.payments(order_id) where status in ('pending','cod','verified');

create table if not exists erp.subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscription_number text not null unique,
  order_id uuid not null unique references erp.orders(id),
  client_id uuid not null references erp.clients(id),
  package_id uuid not null references erp.packages(id),
  size erp.package_size not null,
  start_date date not null,
  frequency erp.delivery_frequency not null,
  weekly_day smallint check (weekly_day between 0 and 6),
  total_days integer not null check (total_days > 0),
  consumed_days integer not null default 0 check (consumed_days >= 0),
  status erp.subscription_status not null default 'active',
  pause_from date,
  pause_until date,
  indefinite_pause boolean not null default false,
  first_delivery_completed boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (consumed_days <= total_days)
);

create table if not exists erp.subscription_pauses (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references erp.subscriptions(id) on delete cascade,
  starts_on date not null,
  ends_on date,
  indefinite boolean not null default false,
  resumed_at timestamptz,
  created_by uuid references erp.employees(id),
  created_at timestamptz not null default now(),
  check (indefinite or ends_on is not null)
);

create table if not exists erp.fulfillment_days (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references erp.orders(id),
  subscription_id uuid references erp.subscriptions(id) on delete cascade,
  client_id uuid not null references erp.clients(id),
  service_date date not null,
  day_number integer not null default 1,
  meal_id uuid not null references erp.meals(id),
  slot erp.meal_slot not null,
  size erp.package_size not null,
  zone_number smallint not null references erp.zones(zone_number),
  status erp.fulfillment_status not null default 'planned',
  source text not null default 'monthly_menu' check (source in ('monthly_menu','meal_swap','ad_hoc')),
  manual_after_cutoff boolean not null default false,
  skipped boolean not null default false,
  skip_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists subscription_schedule_unique
  on erp.fulfillment_days(subscription_id, service_date, slot) where subscription_id is not null;

create table if not exists erp.meal_swaps (
  id uuid primary key default gen_random_uuid(),
  fulfillment_id uuid not null references erp.fulfillment_days(id) on delete cascade,
  old_meal_id uuid not null references erp.meals(id),
  new_meal_id uuid not null references erp.meals(id),
  requested_by uuid references erp.employees(id),
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists erp.production_batches (
  id uuid primary key default gen_random_uuid(),
  production_date date not null unique,
  locked_at timestamptz,
  locked_by uuid references erp.employees(id),
  status text not null default 'open' check (status in ('open','locked','completed')),
  created_at timestamptz not null default now()
);

create table if not exists erp.production_queue (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references erp.production_batches(id) on delete cascade,
  fulfillment_id uuid not null unique references erp.fulfillment_days(id) on delete cascade,
  meal_id uuid not null references erp.meals(id),
  size erp.package_size not null,
  quantity integer not null default 1 check (quantity > 0),
  status erp.fulfillment_status not null default 'sent',
  added_after_cutoff boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists erp.riders (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid unique references erp.employees(id),
  name text not null,
  phone text not null unique,
  active boolean not null default true,
  is_demo boolean not null default false
);

create table if not exists erp.rider_zone_assignments (
  id uuid primary key default gen_random_uuid(),
  service_date date not null,
  zone_number smallint not null references erp.zones(zone_number),
  rider_id uuid not null references erp.riders(id),
  assigned_by uuid references erp.employees(id),
  unique (service_date, zone_number)
);

create table if not exists erp.deliveries (
  id uuid primary key default gen_random_uuid(),
  fulfillment_id uuid not null references erp.fulfillment_days(id),
  client_id uuid not null references erp.clients(id),
  order_id uuid not null references erp.orders(id),
  service_date date not null,
  zone_number smallint not null references erp.zones(zone_number),
  rider_id uuid references erp.riders(id),
  sequence integer not null default 1,
  status erp.delivery_status not null default 'pending',
  cod_expected numeric(12,2) not null default 0 check (cod_expected >= 0),
  cash_collected numeric(12,2) not null default 0 check (cash_collected >= 0),
  collection_method erp.payment_method,
  delivered_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, service_date)
);

create table if not exists erp.cash_collections (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references erp.deliveries(id),
  rider_id uuid references erp.riders(id),
  amount numeric(12,2) not null check (amount > 0),
  method erp.payment_method not null,
  received_by_accounting boolean not null default false,
  received_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists erp.reconciliations (
  id uuid primary key default gen_random_uuid(),
  business_date date not null unique,
  expected_cash numeric(12,2) not null default 0,
  actual_cash numeric(12,2) not null default 0,
  instapay_verified numeric(12,2) not null default 0,
  status erp.reconciliation_status not null default 'open',
  closed_by uuid references erp.employees(id),
  closed_at timestamptz,
  notes text
);

create table if not exists erp.cancellations (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references erp.subscriptions(id),
  client_id uuid not null references erp.clients(id),
  order_id uuid not null references erp.orders(id),
  remaining_value numeric(12,2) not null,
  consumed_value numeric(12,2) not null,
  consumed_penalty numeric(12,2) not null,
  delivery_penalty numeric(12,2) not null,
  refund_amount numeric(12,2) not null,
  reason text not null,
  status erp.cancellation_status not null default 'requested',
  receipt_name text,
  requested_by uuid references erp.employees(id),
  reviewed_by uuid references erp.employees(id),
  transferred_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists one_open_cancellation
  on erp.cancellations(subscription_id) where status in ('requested','reviewed');

create table if not exists erp.sales_targets (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references erp.employees(id),
  target_month date not null check (target_month = date_trunc('month', target_month)::date),
  target_amount numeric(12,2) not null check (target_amount >= 0),
  unique (employee_id, target_month)
);

create table if not exists erp.notifications (
  id uuid primary key default gen_random_uuid(),
  target_role erp.employee_role not null,
  target_user_id uuid references auth.users(id),
  title text not null,
  body text not null,
  event_key text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists erp.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid,
  action text not null,
  entity_table text not null,
  entity_id text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists erp.system_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create index if not exists clients_zone_idx on erp.clients(zone_number);
create index if not exists orders_client_idx on erp.orders(client_id, created_at desc);
create index if not exists orders_gate_idx on erp.orders(status, payment_status);
create index if not exists subscriptions_client_idx on erp.subscriptions(client_id, status);
create index if not exists fulfillment_date_status_idx on erp.fulfillment_days(service_date, status);
create index if not exists fulfillment_client_date_idx on erp.fulfillment_days(client_id, service_date);
create index if not exists production_batch_idx on erp.production_queue(batch_id, status);
create index if not exists deliveries_date_zone_idx on erp.deliveries(service_date, zone_number, sequence);
create index if not exists notifications_role_unread_idx on erp.notifications(target_role, created_at desc) where read_at is null;

create or replace function erp.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['employees','clients','meals','packages','menu_months','orders','subscriptions','fulfillment_days','production_queue','deliveries']
  loop
    execute format('drop trigger if exists set_updated_at on erp.%I', t);
    execute format('create trigger set_updated_at before update on erp.%I for each row execute function erp.set_updated_at()', t);
  end loop;
end $$;

create or replace function erp.current_employee_id()
returns uuid language sql stable security definer set search_path = erp, public as $$
  select id from erp.employees where user_id = auth.uid() and active limit 1
$$;

create or replace function erp.current_role()
returns erp.employee_role language sql stable security definer set search_path = erp, public as $$
  select role from erp.employees where user_id = auth.uid() and active limit 1
$$;

create or replace function erp.require_role(variadic allowed erp.employee_role[])
returns void language plpgsql stable security definer set search_path = erp, public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not (erp.current_role() = any(allowed)) then raise exception 'Permission denied for role %', coalesce(erp.current_role()::text,'none'); end if;
end $$;

create or replace function public.eco_handle_new_user()
returns trigger language plpgsql security definer set search_path = erp, public as $$
declare assigned erp.employee_role;
begin
  assigned := case when exists(select 1 from erp.employees where user_id is not null) then 'sales'::erp.employee_role else 'admin'::erp.employee_role end;
  insert into erp.employees(user_id, display_name, role)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)), assigned)
  on conflict(user_id) do nothing;
  return new;
end $$;

drop trigger if exists eco_on_auth_user_created on auth.users;
create trigger eco_on_auth_user_created after insert on auth.users
for each row execute function public.eco_handle_new_user();

insert into erp.employees(user_id,display_name,role)
select u.id,coalesce(u.raw_user_meta_data->>'full_name',split_part(u.email,'@',1)),
  case when row_number() over(order by u.created_at)=1 and not exists(select 1 from erp.employees where user_id is not null)
    then 'admin'::erp.employee_role else 'sales'::erp.employee_role end
from auth.users u
where not exists(select 1 from erp.employees e where e.user_id=u.id)
on conflict(user_id) do nothing;

create or replace function erp.audit_row()
returns trigger language plpgsql security definer set search_path = erp, public as $$
begin
  if tg_op='DELETE' then
    insert into erp.audit_log(actor_user_id,action,entity_table,entity_id,before_data)
    values(auth.uid(),tg_op,tg_table_schema||'.'||tg_table_name,coalesce(to_jsonb(old)->>'id',''),to_jsonb(old));
    return old;
  end if;
  insert into erp.audit_log(actor_user_id,action,entity_table,entity_id,before_data,after_data)
  values(auth.uid(),tg_op,tg_table_schema||'.'||tg_table_name,coalesce(to_jsonb(new)->>'id',''),case when tg_op='UPDATE' then to_jsonb(old) end,to_jsonb(new));
  return new;
end $$;

do $$ declare t text; begin
  foreach t in array array['clients','orders','payments','subscriptions','fulfillment_days','deliveries','cancellations']
  loop
    execute format('drop trigger if exists audit_changes on erp.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on erp.%I for each row execute function erp.audit_row()', t);
  end loop;
end $$;

create or replace function erp.financially_blocked(p_order_id uuid)
returns boolean language sql stable security definer set search_path = erp, public as $$
  select coalesce((
    select s.first_delivery_completed and p.status = 'cod'
    from erp.subscriptions s join erp.payments p on p.order_id=s.order_id
    where s.order_id=p_order_id order by p.created_at desc limit 1
  ), false)
$$;

create or replace view erp.client_360_summary as
select c.id, c.name, c.phone, c.zone_number,
  coalesce(sum(p.amount) filter(where p.status='verified'),0)::numeric(12,2) total_paid,
  count(distinct o.id) total_orders,
  count(distinct cp.id) total_complaints,
  count(distinct ca.id) total_cancellations
from erp.clients c
left join erp.orders o on o.client_id=c.id
left join erp.payments p on p.client_id=c.id
left join erp.complaints cp on cp.client_id=c.id
left join erp.cancellations ca on ca.client_id=c.id
group by c.id;

create or replace view erp.kitchen_aggregated as
select f.service_date, f.meal_id, m.name meal_name, f.size, f.status, count(*) quantity
from erp.fulfillment_days f join erp.meals m on m.id=f.meal_id
where not f.skipped and f.status in ('sent','in_prep','ready')
group by f.service_date,f.meal_id,m.name,f.size,f.status;

create or replace view erp.packing_labels as
select f.id fulfillment_id,f.service_date,c.name client_name,c.zone_number,p.name package_name,
  m.name meal_name,f.slot,f.size,c.dietary_notes,
  coalesce((select string_agg(rule_text,' · ') from erp.client_dietary_rules r where r.client_id=c.id and r.rule_type='exclusion'),'') exclusions
from erp.fulfillment_days f
join erp.clients c on c.id=f.client_id
left join erp.subscriptions s on s.id=f.subscription_id
left join erp.packages p on p.id=s.package_id
join erp.meals m on m.id=f.meal_id
where not f.skipped and f.status in ('sent','in_prep','ready');

create or replace view erp.dispatch_manifest as
select d.id,d.service_date,d.zone_number,d.sequence,d.status,d.cod_expected,d.cash_collected,
  c.name client_name,c.phone,c.address,c.location_url,r.name rider_name,o.order_number
from erp.deliveries d join erp.clients c on c.id=d.client_id
join erp.orders o on o.id=d.order_id left join erp.riders r on r.id=d.rider_id;

create or replace view erp.sales_commissions as
select e.id employee_id,e.display_name,st.target_month,st.target_amount,
  coalesce(sum(o.amount) filter(where s.consumed_days::numeric/nullif(s.total_days,0) > .5),0) confirmed_revenue,
  case
    when st.target_amount=0 then 0
    when coalesce(sum(o.amount) filter(where s.consumed_days::numeric/nullif(s.total_days,0) > .5),0)/st.target_amount*100 < 80 then 0
    when coalesce(sum(o.amount) filter(where s.consumed_days::numeric/nullif(s.total_days,0) > .5),0)/st.target_amount*100 < 100 then 3
    when coalesce(sum(o.amount) filter(where s.consumed_days::numeric/nullif(s.total_days,0) > .5),0)/st.target_amount*100 < 120 then 3.5
    when coalesce(sum(o.amount) filter(where s.consumed_days::numeric/nullif(s.total_days,0) > .5),0)/st.target_amount*100 <= 150 then 4
    else 5 end commission_rate
from erp.employees e join erp.sales_targets st on st.employee_id=e.id
left join erp.orders o on o.sales_rep_id=e.id and o.status='approved'
left join erp.subscriptions s on s.order_id=o.id
where e.role='sales'
group by e.id,e.display_name,st.target_month,st.target_amount;

create or replace view erp.management_dashboard as
select
  coalesce((select sum(amount) from erp.orders where status='approved'),0) approved_revenue,
  (select count(*) from erp.subscriptions where status='active') active_subscriptions,
  (select count(*) from erp.fulfillment_days where service_date=current_date+1 and not skipped) tomorrow_kitchen_load,
  (select count(*) from erp.orders where status='pending_accounting') pending_accounting,
  coalesce((select sum((o.amount/s.total_days)*(s.total_days-s.consumed_days)) from erp.subscriptions s join erp.orders o on o.id=s.order_id where s.status in ('active','paused')),0) remaining_client_funds;

create or replace function erp.next_order_number()
returns text language sql volatile as $$
  select 'ECO-'||to_char(timezone('Africa/Cairo',now()),'YYMMDD')||'-'||lpad((coalesce(max(nullif(regexp_replace(order_number,'\D','','g'),''))::bigint,0)%10000+1)::text,4,'0') from erp.orders
$$;

create or replace function erp.generate_subscription_schedule(p_subscription_id uuid)
returns integer language plpgsql security definer set search_path=erp,public as $$
declare s erp.subscriptions%rowtype; o erp.orders%rowtype; c erp.clients%rowtype; slot_row record;
  cursor_date date; day_no integer:=1; created integer:=0; selected_meal uuid; safety integer:=0;
begin
  select * into s from erp.subscriptions where id=p_subscription_id;
  select * into o from erp.orders where id=s.order_id;
  select * into c from erp.clients where id=s.client_id;
  cursor_date:=s.start_date;
  while day_no<=s.total_days and safety<730 loop
    if (s.frequency='daily' and extract(dow from cursor_date)<>5)
       or (s.frequency='weekly' and extract(dow from cursor_date)=coalesce(s.weekly_day,6)) then
      for slot_row in select slot,quantity from erp.package_slots where package_id=s.package_id loop
        select md.meal_id into selected_meal from erp.menu_days md where md.service_date=cursor_date and md.slot=slot_row.slot;
        if selected_meal is null then select id into selected_meal from erp.meals where slot=slot_row.slot and active order by code limit 1; end if;
        if selected_meal is not null then
          insert into erp.fulfillment_days(order_id,subscription_id,client_id,service_date,day_number,meal_id,slot,size,zone_number,source)
          values(o.id,s.id,s.client_id,cursor_date,day_no,selected_meal,slot_row.slot,s.size,c.zone_number,'monthly_menu')
          on conflict do nothing;
          created:=created+1;
        end if;
      end loop;
      day_no:=day_no+1;
    end if;
    cursor_date:=cursor_date+1; safety:=safety+1;
  end loop;
  return created;
end $$;

create or replace function public.erp_create_client(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare new_id uuid; item text;
begin
  perform erp.require_role('admin','sales','cs');
  insert into erp.clients(name,phone,email,zone_number,address,location_url,dietary_notes,is_demo,created_by)
  values(p_payload->>'name',p_payload->>'phone',nullif(p_payload->>'email',''),(p_payload->>'zone')::smallint,p_payload->>'address',
    nullif(p_payload->>'locationUrl',''),coalesce(p_payload->>'dietaryNotes',''),coalesce((p_payload->>'isDemo')::boolean,false),erp.current_employee_id())
  returning id into new_id;
  for item in select jsonb_array_elements_text(coalesce(p_payload->'strictExclusions','[]'::jsonb)) loop
    insert into erp.client_dietary_rules(client_id,rule_type,rule_text,strict) values(new_id,'exclusion',item,true);
  end loop;
  for item in select jsonb_array_elements_text(coalesce(p_payload->'preferences','[]'::jsonb)) loop
    insert into erp.client_dietary_rules(client_id,rule_type,rule_text) values(new_id,'preference',item);
  end loop;
  return jsonb_build_object('id',new_id,'message','تم تسجيل العميل');
end $$;

create or replace function public.erp_add_complaint(p_client_id uuid,p_category text,p_details text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare new_id uuid; begin perform erp.require_role('admin','cs');
  insert into erp.complaints(client_id,category,details,created_by) values(p_client_id,p_category,p_details,erp.current_employee_id()) returning id into new_id;
  return jsonb_build_object('id',new_id,'message','تم تسجيل الشكوى');
end $$;

create or replace function public.erp_resolve_complaint(p_complaint_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','cs'); update erp.complaints set status='resolved',resolved_at=now() where id=p_complaint_id;
return jsonb_build_object('message','تم إغلاق الشكوى'); end $$;

create or replace function public.erp_create_meal(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare new_id uuid; begin perform erp.require_role('admin','kitchen');
insert into erp.meals(name,code,slot,regular_cost,hero_cost,active)
values(p_payload->>'name',p_payload->>'code',lower(p_payload->>'slot')::erp.meal_slot,(p_payload->>'regularCost')::numeric,(p_payload->>'heroCost')::numeric,coalesce((p_payload->>'active')::boolean,true))
returning id into new_id; return jsonb_build_object('id',new_id,'message','تمت إضافة الوجبة'); end $$;

create or replace function public.erp_create_package(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare new_id uuid; item text; begin perform erp.require_role('admin','sales');
insert into erp.packages(name,code,days,price_regular,price_hero,active)
values(p_payload->>'name',p_payload->>'code',(p_payload->>'days')::int,(p_payload->>'priceRegular')::numeric,(p_payload->>'priceHero')::numeric,coalesce((p_payload->>'active')::boolean,true))
returning id into new_id;
for item in select jsonb_array_elements_text(p_payload->'mealSlots') loop insert into erp.package_slots(package_id,slot) values(new_id,lower(item)::erp.meal_slot); end loop;
return jsonb_build_object('id',new_id,'message','تمت إضافة الباكدج'); end $$;

create or replace function public.erp_upsert_menu(p_date date,p_slot text,p_meal_id uuid,p_notes text default null)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare month_id uuid; begin perform erp.require_role('admin','kitchen');
insert into erp.menu_months(month_start,name) values(date_trunc('month',p_date)::date,to_char(p_date,'YYYY-MM'))
on conflict(month_start) do update set updated_at=now() returning id into month_id;
insert into erp.menu_days(menu_month_id,service_date,slot,meal_id,notes) values(month_id,p_date,p_slot::erp.meal_slot,p_meal_id,p_notes)
on conflict(service_date,slot) do update set meal_id=excluded.meal_id,notes=excluded.notes;
return jsonb_build_object('message','تم حفظ منيو اليوم'); end $$;

create or replace function public.erp_create_order(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare new_id uuid; payment_id uuid; number text; method erp.payment_method; kind_value erp.order_kind;
begin
  perform erp.require_role('admin','sales');
  method:=replace(replace(lower(p_payload->>'paymentMethod'),'/','_'),' ','_')::erp.payment_method;
  kind_value:=case when p_payload->>'kind'='Subscription' then 'subscription'::erp.order_kind else 'ad_hoc'::erp.order_kind end;
  if method<>'cash' and (nullif(p_payload->>'referenceId','') is null or nullif(p_payload->>'proofName','') is null) then raise exception 'Reference ID and proof are required'; end if;
  number:=erp.next_order_number();
  insert into erp.orders(order_number,kind,client_id,package_id,ad_hoc_meal_id,size,start_date,delivery_date,frequency,weekly_day,total_days,amount,delivery_fees,discount,payment_method,reference_id,proof_name,sales_rep_id,notes,is_demo,created_by)
  values(number,kind_value,(p_payload->>'clientId')::uuid,nullif(p_payload->>'packageId','')::uuid,nullif(p_payload->>'adHocMealId','')::uuid,
    lower(p_payload->>'size')::erp.package_size,(p_payload->>'startDate')::date,nullif(p_payload->>'deliveryDate','')::date,
    lower(p_payload->>'frequency')::erp.delivery_frequency,nullif(p_payload->>'weeklyDay','')::smallint,(p_payload->>'totalDays')::int,
    (p_payload->>'amount')::numeric,coalesce((p_payload->>'deliveryFees')::numeric,0),coalesce((p_payload->>'discount')::numeric,0),method,
    nullif(p_payload->>'referenceId',''),nullif(p_payload->>'proofName',''),nullif(p_payload->>'salesRepId','')::uuid,p_payload->>'notes',false,erp.current_employee_id())
  returning id into new_id;
  insert into erp.payments(order_id,client_id,method,amount,reference_id,proof_name)
  values(new_id,(p_payload->>'clientId')::uuid,method,(p_payload->>'amount')::numeric,nullif(p_payload->>'referenceId',''),nullif(p_payload->>'proofName',''))
  returning id into payment_id;
  insert into erp.notifications(target_role,title,body,event_key) values('accounting','طلب جديد ينتظر الاعتماد',number||' بقيمة '||(p_payload->>'amount')||' ج','payment_pending');
  return jsonb_build_object('id',new_id,'paymentId',payment_id,'message','تم إنشاء '||number||' وإرساله للحسابات');
end $$;

create or replace function public.erp_verify_payment(p_payment_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare p erp.payments%rowtype; o erp.orders%rowtype; c erp.clients%rowtype; sub_id uuid; meal erp.meals%rowtype; fulfillment_id uuid;
begin
  perform erp.require_role('admin','accounting');
  select * into p from erp.payments where id=p_payment_id for update; if not found then raise exception 'Payment not found'; end if;
  select * into o from erp.orders where id=p.order_id for update; select * into c from erp.clients where id=o.client_id;
  update erp.payments set status=case when method='cash' then 'cod' else 'verified' end,verified_at=now(),verified_by=erp.current_employee_id() where id=p.id;
  update erp.orders set status='approved',payment_status=case when payment_method='cash' then 'cod' else 'verified' end where id=o.id;
  if p.method<>'cash' then update erp.clients set updated_at=now() where id=o.client_id; end if;
  if o.kind='subscription' then
    insert into erp.subscriptions(subscription_number,order_id,client_id,package_id,size,start_date,frequency,weekly_day,total_days,is_demo)
    values('SUB-'||to_char(now(),'YYMMDD')||'-'||right(o.id::text,5),o.id,o.client_id,o.package_id,o.size,o.start_date,o.frequency,o.weekly_day,o.total_days,o.is_demo)
    on conflict(order_id) do update set updated_at=now() returning id into sub_id;
    perform erp.generate_subscription_schedule(sub_id);
  else
    select * into meal from erp.meals where id=o.ad_hoc_meal_id;
    insert into erp.fulfillment_days(order_id,client_id,service_date,day_number,meal_id,slot,size,zone_number,source)
    values(o.id,o.client_id,coalesce(o.delivery_date,o.start_date),1,meal.id,meal.slot,o.size,c.zone_number,'ad_hoc')
    returning id into fulfillment_id;
  end if;
  insert into erp.notifications(target_role,title,body,event_key) values('kitchen','طلب معتمد أصبح متاحًا',o.order_number||' أصبح مؤهلًا للمطبخ','order_approved');
  return jsonb_build_object('id',o.id,'message','تم اعتماد الدفع وفتح الطلب للتشغيل');
end $$;

create or replace function public.erp_reject_payment(p_payment_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare order_uuid uuid; begin perform erp.require_role('admin','accounting');
update erp.payments set status='rejected',verified_at=now(),verified_by=erp.current_employee_id() where id=p_payment_id returning order_id into order_uuid;
update erp.orders set status='rejected',payment_status='rejected' where id=order_uuid;
return jsonb_build_object('message','تم رفض الدفع'); end $$;

create or replace function public.erp_pause_subscription(p_subscription_id uuid,p_until date default null,p_indefinite boolean default false)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','cs'); if not p_indefinite and p_until is null then raise exception 'Pause end date is required'; end if;
update erp.subscriptions set status='paused',pause_from=current_date,pause_until=p_until,indefinite_pause=p_indefinite where id=p_subscription_id;
insert into erp.subscription_pauses(subscription_id,starts_on,ends_on,indefinite,created_by) values(p_subscription_id,current_date,p_until,p_indefinite,erp.current_employee_id());
return jsonb_build_object('message','تم إيقاف الاشتراك'); end $$;

create or replace function public.erp_resume_subscription(p_subscription_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','cs'); update erp.subscriptions set status='active',pause_from=null,pause_until=null,indefinite_pause=false where id=p_subscription_id;
update erp.subscription_pauses set resumed_at=now() where subscription_id=p_subscription_id and resumed_at is null;
return jsonb_build_object('message','تم استئناف الاشتراك'); end $$;

create or replace function public.erp_skip_subscription_day(p_subscription_id uuid,p_date date)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','cs'); update erp.fulfillment_days set skipped=true,skip_reason='CS skip' where subscription_id=p_subscription_id and service_date=p_date and status='planned';
return jsonb_build_object('message','تم تخطي يوم التوصيل'); end $$;

create or replace function public.erp_swap_meal(p_fulfillment_id uuid,p_meal_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare old_id uuid; begin perform erp.require_role('admin','cs');
select meal_id into old_id from erp.fulfillment_days where id=p_fulfillment_id and status='planned' for update;
if old_id is null then raise exception 'Only planned meals can be swapped'; end if;
insert into erp.meal_swaps(fulfillment_id,old_meal_id,new_meal_id,requested_by) values(p_fulfillment_id,old_id,p_meal_id,erp.current_employee_id());
update erp.fulfillment_days set meal_id=p_meal_id,source='meal_swap' where id=p_fulfillment_id;
return jsonb_build_object('message','تم تبديل الوجبة لهذا العميل فقط'); end $$;

create or replace function public.erp_send_to_kitchen(p_fulfillment_ids uuid[])
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare row_data record; batch_uuid uuid; sent_count integer:=0;
begin
  perform erp.require_role('admin','cs');
  for row_data in select f.* from erp.fulfillment_days f where f.id=any(p_fulfillment_ids) for update loop
    if row_data.skipped or row_data.status<>'planned' then continue; end if;
    if not exists(select 1 from erp.orders o where o.id=row_data.order_id and o.status='approved') then raise exception 'Gatekeeper: order % is not approved',row_data.order_id; end if;
    if row_data.subscription_id is not null and not exists(select 1 from erp.subscriptions s where s.id=row_data.subscription_id and s.status='active') then continue; end if;
    if erp.financially_blocked(row_data.order_id) then raise exception 'Gatekeeper: payment must be verified before future production'; end if;
    insert into erp.production_batches(production_date) values(row_data.service_date) on conflict(production_date) do update set production_date=excluded.production_date returning id into batch_uuid;
    update erp.fulfillment_days set status='sent' where id=row_data.id;
    insert into erp.production_queue(batch_id,fulfillment_id,meal_id,size,status,added_after_cutoff)
    values(batch_uuid,row_data.id,row_data.meal_id,row_data.size,'sent',row_data.manual_after_cutoff) on conflict(fulfillment_id) do nothing;
    sent_count:=sent_count+1;
  end loop;
  return jsonb_build_object('message','تم إرسال '||sent_count||' بند للمطبخ');
end $$;

create or replace function public.erp_add_emergency_fulfillment(p_date date,p_client_id uuid,p_meal_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare c erp.clients%rowtype; m erp.meals%rowtype; new_id uuid; batch_uuid uuid;
begin perform erp.require_role('admin','cs'); select * into c from erp.clients where id=p_client_id; select * into m from erp.meals where id=p_meal_id;
insert into erp.fulfillment_days(client_id,service_date,meal_id,slot,size,zone_number,status,source,manual_after_cutoff)
values(c.id,p_date,m.id,m.slot,'regular',c.zone_number,'sent','ad_hoc',true) returning id into new_id;
insert into erp.production_batches(production_date) values(p_date) on conflict(production_date) do update set production_date=excluded.production_date returning id into batch_uuid;
insert into erp.production_queue(batch_id,fulfillment_id,meal_id,size,status,added_after_cutoff) values(batch_uuid,new_id,m.id,'regular','sent',true);
insert into erp.notifications(target_role,title,body,event_key) values('kitchen','إضافة طارئة بعد الـCut-off',c.name||' · '||m.name,'emergency_kitchen');
return jsonb_build_object('id',new_id,'message','تمت الإضافة الطارئة وتنبيه المطبخ'); end $$;

create or replace function public.erp_set_kitchen_status(p_fulfillment_ids uuid[],p_status text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare f record; assign_rider uuid; payment_row record; cod numeric; delivery_id uuid; normalized erp.fulfillment_status;
begin perform erp.require_role('admin','kitchen'); normalized:=p_status::erp.fulfillment_status;
update erp.fulfillment_days set status=normalized where id=any(p_fulfillment_ids) and status in ('sent','in_prep','ready');
update erp.production_queue set status=normalized where fulfillment_id=any(p_fulfillment_ids);
if normalized='ready' then
  for f in select distinct on(order_id,service_date) * from erp.fulfillment_days where id=any(p_fulfillment_ids) and order_id is not null order by order_id,service_date,id loop
    select rider_id into assign_rider from erp.rider_zone_assignments where service_date=f.service_date and zone_number=f.zone_number;
    select p.status,o.amount into payment_row from erp.payments p join erp.orders o on o.id=p.order_id where p.order_id=f.order_id order by p.created_at desc limit 1;
    cod:=case when payment_row.status='cod' then payment_row.amount else 0 end;
    insert into erp.deliveries(fulfillment_id,client_id,order_id,service_date,zone_number,rider_id,sequence,cod_expected)
    values(f.id,f.client_id,f.order_id,f.service_date,f.zone_number,assign_rider,
      coalesce((select max(sequence)+1 from erp.deliveries where service_date=f.service_date and zone_number=f.zone_number),1),cod)
    on conflict(order_id,service_date) do update set fulfillment_id=excluded.fulfillment_id returning id into delivery_id;
  end loop;
end if;
return jsonb_build_object('message','تم تحديث حالة المطبخ'); end $$;

create or replace function public.erp_assign_rider(p_date date,p_zone smallint,p_rider_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','delivery');
insert into erp.rider_zone_assignments(service_date,zone_number,rider_id,assigned_by) values(p_date,p_zone,p_rider_id,erp.current_employee_id())
on conflict(service_date,zone_number) do update set rider_id=excluded.rider_id,assigned_by=excluded.assigned_by;
update erp.deliveries set rider_id=p_rider_id where service_date=p_date and zone_number=p_zone and status='pending';
return jsonb_build_object('message','تم تعيين الكابتن للمنطقة'); end $$;

create or replace function public.erp_set_delivery_status(p_delivery_id uuid,p_status text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare d erp.deliveries%rowtype; sub erp.subscriptions%rowtype; pay erp.payments%rowtype; normalized erp.delivery_status; remaining integer;
begin perform erp.require_role('admin','delivery'); normalized:=p_status::erp.delivery_status; select * into d from erp.deliveries where id=p_delivery_id for update;
select * into pay from erp.payments where order_id=d.order_id order by created_at desc limit 1;
select * into sub from erp.subscriptions where order_id=d.order_id for update;
if normalized='delivered' and sub.first_delivery_completed and pay.status='cod' then raise exception 'Gatekeeper: cash payment must be collected before future deliveries'; end if;
update erp.deliveries set status=normalized,delivered_at=case when normalized='delivered' then now() else delivered_at end where id=d.id;
if normalized='delivered' then
  update erp.fulfillment_days set status='delivered' where order_id=d.order_id and service_date=d.service_date;
  if sub.id is not null then
    update erp.subscriptions set consumed_days=least(total_days,consumed_days+1),first_delivery_completed=true,
      status=case when consumed_days+1>=total_days then 'finished' else status end where id=sub.id returning * into sub;
    remaining:=sub.total_days-sub.consumed_days;
    if remaining between 1 and 3 then insert into erp.notifications(target_role,title,body,event_key) values('sales','اشتراك قرب يخلص','باقي '||remaining||' يوم فقط للعميل','renewal_due'); end if;
    if pay.status='cod' then insert into erp.notifications(target_role,title,body,event_key) values('accounting','تم أول تسليم بدون تحصيل مؤكد','أي تشغيل مستقبلي للطلب محظور حتى التحصيل','pay_on_first_delivery'); end if;
  end if;
end if;
return jsonb_build_object('message','تم تحديث حالة التوصيل'); end $$;

create or replace function public.erp_collect_cash(p_delivery_id uuid,p_amount numeric,p_method text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare d erp.deliveries%rowtype; method_value erp.payment_method;
begin perform erp.require_role('admin','delivery'); method_value:=replace(replace(lower(p_method),'/','_'),' ','_')::erp.payment_method; select * into d from erp.deliveries where id=p_delivery_id for update;
update erp.deliveries set cash_collected=p_amount,collection_method=method_value where id=d.id;
insert into erp.cash_collections(delivery_id,rider_id,amount,method) values(d.id,d.rider_id,p_amount,method_value);
update erp.payments set status='verified',verified_at=now() where order_id=d.order_id and status='cod';
update erp.orders set payment_status='verified' where id=d.order_id;
insert into erp.notifications(target_role,title,body,event_key) values('accounting','تحصيل نقدي جديد','سجل الكابتن تحصيل '||p_amount||' ج','cash_collected');
return jsonb_build_object('message','تم تسجيل التحصيل وإرساله للحسابات'); end $$;

create or replace function public.erp_request_cancellation(p_subscription_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare s erp.subscriptions%rowtype; o erp.orders%rowtype; day_value numeric; consumed numeric; remaining numeric; consumed_penalty numeric; delivery_penalty numeric; refund numeric; new_id uuid;
begin perform erp.require_role('admin','cs'); select * into s from erp.subscriptions where id=p_subscription_id; select * into o from erp.orders where id=s.order_id;
day_value:=o.amount/s.total_days; consumed:=day_value*s.consumed_days; remaining:=day_value*(s.total_days-s.consumed_days);
consumed_penalty:=consumed*.20; delivery_penalty:=30*(select count(distinct service_date) from erp.deliveries where order_id=o.id and status='delivered');
refund:=greatest(0,remaining-consumed_penalty-delivery_penalty);
insert into erp.cancellations(subscription_id,client_id,order_id,remaining_value,consumed_value,consumed_penalty,delivery_penalty,refund_amount,reason,requested_by)
values(s.id,s.client_id,o.id,remaining,consumed,consumed_penalty,delivery_penalty,refund,p_reason,erp.current_employee_id()) returning id into new_id;
insert into erp.notifications(target_role,title,body,event_key) values('accounting','طلب إلغاء جديد','Refund '||refund||' ج يحتاج مراجعة','cancellation_requested');
return jsonb_build_object('id',new_id,'message','تم إرسال طلب الإلغاء للحسابات'); end $$;

create or replace function public.erp_review_cancellation(p_cancellation_id uuid)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','accounting'); update erp.cancellations set status='reviewed',reviewed_by=erp.current_employee_id() where id=p_cancellation_id and status='requested';
return jsonb_build_object('message','تمت مراجعة الحساب'); end $$;

create or replace function public.erp_transfer_cancellation(p_cancellation_id uuid,p_receipt_name text)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
declare c erp.cancellations%rowtype; begin perform erp.require_role('admin','accounting'); if nullif(p_receipt_name,'') is null then raise exception 'Receipt is required'; end if;
update erp.cancellations set status='transferred',receipt_name=p_receipt_name,transferred_at=now() where id=p_cancellation_id and status='reviewed' returning * into c;
update erp.subscriptions set status='canceled' where id=c.subscription_id; update erp.orders set status='canceled' where id=c.order_id;
update erp.fulfillment_days set status='canceled' where subscription_id=c.subscription_id and status in ('planned','sent');
return jsonb_build_object('message','تم التحويل وإغلاق الاشتراك'); end $$;

create or replace function public.erp_close_reconciliation(p_reconciliation_id uuid,p_actual_cash numeric)
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin perform erp.require_role('admin','accounting'); update erp.reconciliations set actual_cash=p_actual_cash,status='closed',closed_by=erp.current_employee_id(),closed_at=now() where id=p_reconciliation_id;
return jsonb_build_object('message','تم إغلاق اليوم'); end $$;

create or replace function public.erp_purge_demo_data()
returns jsonb language plpgsql security definer set search_path=erp,public as $$
begin
  perform erp.require_role('admin');
  delete from erp.cash_collections where delivery_id in (select d.id from erp.deliveries d join erp.orders o on o.id=d.order_id where o.is_demo);
  delete from erp.deliveries where order_id in (select id from erp.orders where is_demo);
  delete from erp.production_queue where fulfillment_id in (select f.id from erp.fulfillment_days f join erp.clients c on c.id=f.client_id where c.is_demo);
  delete from erp.meal_swaps where fulfillment_id in (select f.id from erp.fulfillment_days f join erp.clients c on c.id=f.client_id where c.is_demo);
  delete from erp.fulfillment_days where client_id in (select id from erp.clients where is_demo);
  delete from erp.cancellations where order_id in (select id from erp.orders where is_demo);
  delete from erp.subscription_pauses where subscription_id in (select s.id from erp.subscriptions s join erp.orders o on o.id=s.order_id where o.is_demo);
  delete from erp.subscriptions where order_id in (select id from erp.orders where is_demo);
  delete from erp.payments where order_id in (select id from erp.orders where is_demo);
  delete from erp.orders where is_demo;
  delete from erp.complaints where client_id in (select id from erp.clients where is_demo);
  delete from erp.client_dietary_rules where client_id in (select id from erp.clients where is_demo);
  delete from erp.clients where is_demo;
  delete from erp.notifications where event_key in ('payment_pending','kitchen_ready','renewal_due');
  return jsonb_build_object('message','تم حذف بيانات التجربة مع الاحتفاظ بالمنيو والباكدجات');
end $$;

create or replace function public.erp_bootstrap()
returns jsonb language plpgsql stable security definer set search_path=erp,public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return jsonb_build_object(
    'employees',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'name',display_name,'role',role::text,'active',active) order by display_name) from erp.employees where active),'[]'::jsonb),
    'clients',coalesce((select jsonb_agg(jsonb_build_object('id',c.id::text,'name',c.name,'phone',c.phone,'email',c.email,'zone',c.zone_number,'address',c.address,'locationUrl',coalesce(c.location_url,''),'dietaryNotes',c.dietary_notes,
      'strictExclusions',coalesce((select jsonb_agg(rule_text) from erp.client_dietary_rules r where r.client_id=c.id and rule_type='exclusion'),'[]'::jsonb),
      'preferences',coalesce((select jsonb_agg(rule_text) from erp.client_dietary_rules r where r.client_id=c.id and rule_type='preference'),'[]'::jsonb),
      'totalPaid',coalesce((select sum(amount) from erp.payments p where p.client_id=c.id and p.status='verified'),0),'createdAt',c.created_at::date::text,'isDemo',c.is_demo) order by c.created_at desc) from erp.clients c),'[]'::jsonb),
    'complaints',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'clientId',client_id::text,'category',category,'details',details,'status',initcap(status),'createdAt',created_at::date::text) order by created_at desc) from erp.complaints),'[]'::jsonb),
    'meals',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'name',name,'code',code,'slot',initcap(slot::text),'regularCost',regular_cost,'heroCost',hero_cost,'active',active) order by code) from erp.meals),'[]'::jsonb),
    'packages',coalesce((select jsonb_agg(jsonb_build_object('id',p.id::text,'name',p.name,'code',p.code,'days',p.days,'priceRegular',p.price_regular,'priceHero',p.price_hero,'mealSlots',coalesce((select jsonb_agg(initcap(slot::text)) from erp.package_slots ps where ps.package_id=p.id),'[]'::jsonb),'active',p.active) order by p.code) from erp.packages p),'[]'::jsonb),
    'menu',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'date',service_date::text,'slot',initcap(slot::text),'mealId',meal_id::text,'notes',notes) order by service_date,slot) from erp.menu_days),'[]'::jsonb),
    'orders',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'orderNumber',order_number,'kind',case when kind='subscription' then 'Subscription' else 'AdHoc' end,'clientId',client_id::text,'packageId',package_id::text,'size',initcap(size::text),'startDate',start_date::text,'deliveryDate',delivery_date::text,'frequency',initcap(frequency::text),'weeklyDay',weekly_day,'totalDays',total_days,'amount',amount,'deliveryFees',delivery_fees,'discount',discount,'paymentMethod',case payment_method when 'website_app' then 'Website/App' when 'bank_transfer' then 'Bank Transfer' when 'instapay' then 'InstaPay' else 'Cash' end,'paymentStatus',case payment_status when 'cod' then 'COD' else initcap(payment_status::text) end,'referenceId',reference_id,'proofName',proof_name,'status',case status when 'pending_accounting' then 'Pending Accounting' else initcap(status::text) end,'salesRepId',sales_rep_id::text,'createdAt',created_at::date::text,'adHocMealId',ad_hoc_meal_id::text,'notes',notes) order by created_at desc) from erp.orders),'[]'::jsonb),
    'subscriptions',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'subscriptionNumber',subscription_number,'orderId',order_id::text,'clientId',client_id::text,'packageId',package_id::text,'size',initcap(size::text),'startDate',start_date::text,'frequency',initcap(frequency::text),'weeklyDay',weekly_day,'totalDays',total_days,'consumedDays',consumed_days,'status',initcap(status::text),'pauseFrom',pause_from::text,'pauseUntil',pause_until::text,'indefinitePause',indefinite_pause,'firstDeliveryCompleted',first_delivery_completed,'createdAt',created_at::date::text) order by created_at desc) from erp.subscriptions),'[]'::jsonb),
    'fulfillment',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'orderId',order_id::text,'subscriptionId',subscription_id::text,'clientId',client_id::text,'date',service_date::text,'dayNumber',day_number,'mealId',meal_id::text,'slot',initcap(slot::text),'size',initcap(size::text),'zone',zone_number,'status',case status when 'in_prep' then 'In Prep' else initcap(status::text) end,'source',case source when 'monthly_menu' then 'Monthly Menu' when 'meal_swap' then 'Meal Swap' else 'Ad Hoc' end,'manualAfterCutoff',manual_after_cutoff,'skipped',skipped) order by service_date) from erp.fulfillment_days where status<>'canceled'),'[]'::jsonb),
    'riders',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'name',name,'phone',phone,'active',active) order by name) from erp.riders),'[]'::jsonb),
    'deliveries',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'fulfillmentId',fulfillment_id::text,'clientId',client_id::text,'orderId',order_id::text,'date',service_date::text,'zone',zone_number,'riderId',rider_id::text,'sequence',sequence,'status',case status when 'out_for_delivery' then 'Out for delivery' else initcap(status::text) end,'codExpected',cod_expected,'cashCollected',cash_collected,'collectionMethod',case collection_method when 'instapay' then 'InstaPay' when 'website_app' then 'Website/App' when 'bank_transfer' then 'Bank Transfer' else 'Cash' end,'deliveredAt',delivered_at::text) order by service_date,zone_number,sequence) from erp.deliveries),'[]'::jsonb),
    'payments',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'orderId',order_id::text,'clientId',client_id::text,'method',case method when 'instapay' then 'InstaPay' when 'website_app' then 'Website/App' when 'bank_transfer' then 'Bank Transfer' else 'Cash' end,'amount',amount,'status',case status when 'cod' then 'COD' else initcap(status::text) end,'referenceId',reference_id,'proofName',proof_name,'verifiedAt',verified_at::text,'verifiedBy',verified_by::text,'createdAt',created_at::date::text) order by created_at desc) from erp.payments),'[]'::jsonb),
    'cancellations',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'subscriptionId',subscription_id::text,'clientId',client_id::text,'orderId',order_id::text,'remainingValue',remaining_value,'consumedValue',consumed_value,'consumedPenalty',consumed_penalty,'deliveryPenalty',delivery_penalty,'refundAmount',refund_amount,'reason',reason,'status',initcap(status::text),'receiptName',receipt_name,'createdAt',created_at::date::text) order by created_at desc) from erp.cancellations),'[]'::jsonb),
    'notifications',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'role',target_role::text,'title',title,'body',body,'read',read_at is not null,'createdAt',created_at::text) order by created_at desc) from erp.notifications where target_user_id is null or target_user_id=auth.uid()),'[]'::jsonb),
    'salesTargets',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'employeeId',employee_id::text,'month',to_char(target_month,'YYYY-MM'),'target',target_amount)) from erp.sales_targets),'[]'::jsonb),
    'reconciliations',coalesce((select jsonb_agg(jsonb_build_object('id',id::text,'date',business_date::text,'expectedCash',expected_cash,'actualCash',actual_cash,'instapayVerified',instapay_verified,'status',initcap(status::text)) order by business_date desc) from erp.reconciliations),'[]'::jsonb)
  );
end $$;

-- RLS: direct table access remains restricted even though the frontend primarily uses audited RPCs.
do $$ declare t text; begin
  foreach t in array array['employees','zones','clients','client_dietary_rules','complaints','meals','packages','package_slots','menu_months','menu_days','orders','payments','subscriptions','subscription_pauses','fulfillment_days','meal_swaps','production_batches','production_queue','riders','rider_zone_assignments','deliveries','cash_collections','reconciliations','cancellations','sales_targets','notifications','audit_log','system_settings']
  loop execute format('alter table erp.%I enable row level security',t); end loop;
end $$;

drop policy if exists employees_read on erp.employees;
create policy employees_read on erp.employees for select to authenticated using (active);
drop policy if exists employees_admin on erp.employees;
create policy employees_admin on erp.employees for all to authenticated using (erp.current_role()='admin') with check (erp.current_role()='admin');
drop policy if exists zones_read on erp.zones;
create policy zones_read on erp.zones for select to authenticated using (true);
drop policy if exists clients_read on erp.clients;
create policy clients_read on erp.clients for select to authenticated using (erp.current_role() is not null);
drop policy if exists clients_write on erp.clients;
create policy clients_write on erp.clients for all to authenticated using (erp.current_role() in ('admin','sales','cs')) with check (erp.current_role() in ('admin','sales','cs'));

do $$ declare t text; begin
  foreach t in array array['client_dietary_rules','complaints'] loop
    execute format('drop policy if exists staff_read on erp.%I',t);
    execute format('create policy staff_read on erp.%I for select to authenticated using (erp.current_role() in (''admin'',''sales'',''cs'',''accounting''))',t);
  end loop;
  foreach t in array array['meals','packages','package_slots','menu_months','menu_days'] loop
    execute format('drop policy if exists catalog_read on erp.%I',t);
    execute format('create policy catalog_read on erp.%I for select to authenticated using (erp.current_role() is not null)',t);
  end loop;
  foreach t in array array['orders','payments','subscriptions','subscription_pauses','cancellations','sales_targets','reconciliations'] loop
    execute format('drop policy if exists finance_read on erp.%I',t);
    execute format('create policy finance_read on erp.%I for select to authenticated using (erp.current_role() in (''admin'',''sales'',''cs'',''accounting''))',t);
  end loop;
  foreach t in array array['fulfillment_days','meal_swaps'] loop
    execute format('drop policy if exists fulfillment_read on erp.%I',t);
    execute format('create policy fulfillment_read on erp.%I for select to authenticated using (erp.current_role() in (''admin'',''cs'',''kitchen'',''delivery''))',t);
  end loop;
  foreach t in array array['production_batches','production_queue'] loop
    execute format('drop policy if exists kitchen_read on erp.%I',t);
    execute format('create policy kitchen_read on erp.%I for select to authenticated using (erp.current_role() in (''admin'',''kitchen''))',t);
  end loop;
  foreach t in array array['riders','rider_zone_assignments','deliveries','cash_collections'] loop
    execute format('drop policy if exists delivery_read on erp.%I',t);
    execute format('create policy delivery_read on erp.%I for select to authenticated using (erp.current_role() in (''admin'',''delivery'',''accounting'',''cs''))',t);
  end loop;
end $$;

drop policy if exists notifications_read on erp.notifications;
create policy notifications_read on erp.notifications for select to authenticated using (erp.current_role()='admin' or target_role=erp.current_role() or target_user_id=auth.uid());
drop policy if exists audit_admin_read on erp.audit_log;
create policy audit_admin_read on erp.audit_log for select to authenticated using (erp.current_role()='admin');
drop policy if exists settings_read on erp.system_settings;
create policy settings_read on erp.system_settings for select to authenticated using (erp.current_role() is not null);

grant select on all tables in schema erp to authenticated;
grant usage, select on all sequences in schema erp to authenticated;
grant execute on all functions in schema erp to authenticated;
do $$ declare fn record; begin
  for fn in select p.oid::regprocedure::text signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'erp_%'
  loop execute 'grant execute on function '||fn.signature||' to authenticated'; end loop;
end $$;

-- Deterministic demo data. Every business record is marked is_demo where applicable.
insert into erp.zones(zone_number,name,default_delivery_fee) values
(1,'Central Cairo',30),(2,'Nasr City / New Cairo',40),(3,'New Cairo',50),(4,'Far Zones',70)
on conflict(zone_number) do update set name=excluded.name;

insert into erp.employees(id,display_name,role,is_demo) values
('10000000-0000-0000-0000-000000000001','Hisham Essam','admin',true),
('10000000-0000-0000-0000-000000000002','Dalia','sales',true),
('10000000-0000-0000-0000-000000000003','Marwa','cs',true),
('10000000-0000-0000-0000-000000000004','Samir','kitchen',true),
('10000000-0000-0000-0000-000000000005','Liza Hany','delivery',true),
('10000000-0000-0000-0000-000000000006','Nour','accounting',true)
on conflict(id) do nothing;

insert into erp.meals(id,name,code,slot,regular_cost,hero_cost,is_demo) values
('20000000-0000-0000-0000-000000000001','Grilled Chicken & Rice','L01','lunch',92,146,true),
('20000000-0000-0000-0000-000000000002','Beef Kofta & Potatoes','L02','lunch',108,174,true),
('20000000-0000-0000-0000-000000000003','Chicken Fajita Wrap','D01','dinner',74,112,true),
('20000000-0000-0000-0000-000000000004','Omelette & Toast','B01','breakfast',49,72,true),
('20000000-0000-0000-0000-000000000005','Coconut Muffin','S01','snack',31,46,true),
('20000000-0000-0000-0000-000000000006','Steak & Cooked Vegetables','L03','lunch',148,229,true),
('20000000-0000-0000-0000-000000000007','Rumi Cheese Sandwich','D02','dinner',58,83,true)
on conflict(id) do nothing;

insert into erp.packages(id,name,code,days,price_regular,price_hero,is_demo) values
('30000000-0000-0000-0000-000000000001','Package A — Lunch','PKG-A',24,4628,7380,true),
('30000000-0000-0000-0000-000000000002','Package B — Full Day','PKG-B',24,13883,18480,true),
('30000000-0000-0000-0000-000000000003','Weekly Lunch','WEEK-6',6,1999,3199,true)
on conflict(id) do nothing;

insert into erp.package_slots(package_id,slot) values
('30000000-0000-0000-0000-000000000001','lunch'),
('30000000-0000-0000-0000-000000000002','breakfast'),
('30000000-0000-0000-0000-000000000002','lunch'),
('30000000-0000-0000-0000-000000000002','dinner'),
('30000000-0000-0000-0000-000000000002','snack'),
('30000000-0000-0000-0000-000000000003','lunch')
on conflict do nothing;

insert into erp.clients(id,name,phone,email,zone_number,address,location_url,dietary_notes,is_demo) values
('40000000-0000-0000-0000-000000000001','أحمد علي','01090000001','ahmed@example.com',1,'حدائق القبة، شارع مصر والسودان','https://maps.google.com/?q=30.08,31.28','تقليل الملح',true),
('40000000-0000-0000-0000-000000000002','منة خالد','01090000002',null,2,'مدينة نصر، عباس العقاد','https://maps.google.com/?q=30.05,31.34','Low Carb',true),
('40000000-0000-0000-0000-000000000003','كريم سمير','01090000003',null,3,'التجمع الخامس، النرجس','https://maps.google.com/?q=30.01,31.44','بدون صوص',true),
('40000000-0000-0000-0000-000000000004','داليا محمد','01090000004',null,4,'الشيخ زايد، الحي السابع','https://maps.google.com/?q=30.03,30.98','عميلة Weekly',true)
on conflict(id) do nothing;

insert into erp.client_dietary_rules(client_id,rule_type,rule_text,strict) values
('40000000-0000-0000-0000-000000000001','exclusion','No fish',true),
('40000000-0000-0000-0000-000000000001','exclusion','No tuna',true),
('40000000-0000-0000-0000-000000000001','preference','Grilled chicken',false),
('40000000-0000-0000-0000-000000000002','exclusion','No raw salads',true),
('40000000-0000-0000-0000-000000000002','preference','Cooked vegetables',false),
('40000000-0000-0000-0000-000000000002','preference','Baladi bread',false)
on conflict do nothing;

insert into erp.menu_months(month_start,name)
values(date_trunc('month',current_date)::date,to_char(current_date,'YYYY-MM'))
on conflict(month_start) do nothing;

insert into erp.menu_days(menu_month_id,service_date,slot,meal_id)
select mm.id,d::date,s.slot,
  case s.slot
    when 'breakfast'::erp.meal_slot then '20000000-0000-0000-0000-000000000004'::uuid
    when 'lunch'::erp.meal_slot then case when extract(day from d)::int%3=0 then '20000000-0000-0000-0000-000000000006'::uuid when extract(day from d)::int%2=0 then '20000000-0000-0000-0000-000000000002'::uuid else '20000000-0000-0000-0000-000000000001'::uuid end
    when 'dinner'::erp.meal_slot then case when extract(day from d)::int%2=0 then '20000000-0000-0000-0000-000000000007'::uuid else '20000000-0000-0000-0000-000000000003'::uuid end
    else '20000000-0000-0000-0000-000000000005'::uuid end
from erp.menu_months mm
cross join generate_series(date_trunc('month',current_date)::date,(date_trunc('month',current_date)+interval '1 month - 1 day')::date,interval '1 day') d
cross join (values('breakfast'::erp.meal_slot),('lunch'::erp.meal_slot),('dinner'::erp.meal_slot),('snack'::erp.meal_slot)) s(slot)
where mm.month_start=date_trunc('month',current_date)::date
on conflict(service_date,slot) do nothing;

insert into erp.orders(id,order_number,kind,client_id,package_id,size,start_date,frequency,total_days,amount,payment_method,payment_status,reference_id,proof_name,status,sales_rep_id,is_demo) values
('50000000-0000-0000-0000-000000000001','ECO-DEMO-001','subscription','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','regular',current_date-10,'daily',24,4628,'instapay','verified','IP-884201','instapay-ahmed.jpg','approved','10000000-0000-0000-0000-000000000002',true),
('50000000-0000-0000-0000-000000000002','ECO-DEMO-002','subscription','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','regular',current_date-6,'daily',24,13883,'website_app','verified','WEB-99012','web-order.png','approved','10000000-0000-0000-0000-000000000002',true),
('50000000-0000-0000-0000-000000000003','ECO-DEMO-003','subscription','40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001','hero',current_date+1,'daily',24,7380,'cash','pending',null,null,'pending_accounting','10000000-0000-0000-0000-000000000002',true)
on conflict(id) do nothing;

insert into erp.payments(id,order_id,client_id,method,amount,status,reference_id,proof_name,verified_at) values
('60000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','instapay',4628,'verified','IP-884201','instapay-ahmed.jpg',now()-interval '12 days'),
('60000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','website_app',13883,'verified','WEB-99012','web-order.png',now()-interval '7 days'),
('60000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000003','cash',7380,'pending',null,null,null)
on conflict(id) do nothing;

insert into erp.subscriptions(id,subscription_number,order_id,client_id,package_id,size,start_date,frequency,total_days,consumed_days,status,first_delivery_completed,is_demo) values
('70000000-0000-0000-0000-000000000001','SUB-DEMO-001','50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','regular',current_date-10,'daily',24,9,'active',true,true),
('70000000-0000-0000-0000-000000000002','SUB-DEMO-002','50000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','regular',current_date-6,'daily',24,5,'active',true,true)
on conflict(id) do nothing;

select erp.generate_subscription_schedule('70000000-0000-0000-0000-000000000001');
select erp.generate_subscription_schedule('70000000-0000-0000-0000-000000000002');

update erp.fulfillment_days set status='sent'
where subscription_id='70000000-0000-0000-0000-000000000001' and service_date=current_date+1;
update erp.fulfillment_days set status='ready'
where subscription_id='70000000-0000-0000-0000-000000000002' and service_date=current_date+1;

insert into erp.riders(id,name,phone,is_demo) values
('80000000-0000-0000-0000-000000000001','كابتن أحمد','01011110001',true),
('80000000-0000-0000-0000-000000000002','كابتن محمود','01011110002',true),
('80000000-0000-0000-0000-000000000003','كابتن سارة','01011110003',true)
on conflict(id) do nothing;

insert into erp.production_batches(production_date) values(current_date+1) on conflict do nothing;
insert into erp.production_queue(batch_id,fulfillment_id,meal_id,size,status)
select b.id,f.id,f.meal_id,f.size,f.status from erp.production_batches b join erp.fulfillment_days f on f.service_date=b.production_date
where b.production_date=current_date+1 and f.status in ('sent','ready') on conflict(fulfillment_id) do nothing;

insert into erp.deliveries(fulfillment_id,client_id,order_id,service_date,zone_number,rider_id,sequence,status)
select (array_agg(f.id order by f.id))[1],f.client_id,f.order_id,f.service_date,f.zone_number,'80000000-0000-0000-0000-000000000002',1,'pending'
from erp.fulfillment_days f where f.order_id='50000000-0000-0000-0000-000000000002' and f.service_date=current_date+1
group by f.client_id,f.order_id,f.service_date,f.zone_number
on conflict(order_id,service_date) do nothing;

insert into erp.complaints(id,client_id,category,details,status) values
('90000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','Taste','الأرز محتاج تقليل ملح','resolved'),
('90000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002','Delivery','تأخير 30 دقيقة','open')
on conflict(id) do nothing;

insert into erp.sales_targets(id,employee_id,target_month,target_amount) values
('a0000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',date_trunc('month',current_date)::date,25000)
on conflict(id) do nothing;

insert into erp.reconciliations(id,business_date) values
('b0000000-0000-0000-0000-000000000001',current_date)
on conflict(id) do nothing;

insert into erp.notifications(id,target_role,title,body,event_key) values
('c0000000-0000-0000-0000-000000000001','accounting','دفعة تنتظر المراجعة','راجع الدفع ثم أكد كـCOD أو ارفض.','payment_pending'),
('c0000000-0000-0000-0000-000000000002','kitchen','إنتاج بكرة جاهز','توجد قائمة تحضير وكروت تعبئة للغد.','kitchen_ready'),
('c0000000-0000-0000-0000-000000000003','sales','متابعة التجديد','راجع الاشتراكات المتبقي بها 3 أيام أو أقل.','renewal_due')
on conflict(id) do nothing;

insert into erp.system_settings(key,value) values
('schema_version','"4.0.0"'::jsonb),
('company',jsonb_build_object('name','ECO Healthy','currency','EGP','timezone','Africa/Cairo')),
('cancellation_rules',jsonb_build_object('consumed_penalty_percent',20,'delivery_day_penalty',30))
on conflict(key) do update set value=excluded.value,updated_at=now();

commit;
