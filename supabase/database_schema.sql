-- ECO HEALTHY ERP — PRODUCTION SUPABASE SCHEMA
-- PostgreSQL / Supabase. Run on a clean project after the ECO clean reset.

create extension if not exists pgcrypto;

do $$ begin create type public.employee_role as enum ('admin','sales','cs','kitchen','delivery','accounting'); exception when duplicate_object then null; end $$;
do $$ begin create type public.order_type as enum ('subscription','adhoc'); exception when duplicate_object then null; end $$;
do $$ begin create type public.order_status as enum ('pending_accounting','confirmed','rejected','canceled','refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type public.subscription_status as enum ('pending_payment','active','paused','finished','canceled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.delivery_frequency as enum ('daily','weekly'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_method as enum ('cash','instapay','website_app'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_status as enum ('pending','verified','rejected','refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type public.meal_type as enum ('standard','lc','high_protein'); exception when duplicate_object then null; end $$;
do $$ begin create type public.menu_status as enum ('draft','published','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type public.fulfillment_status as enum ('planned','queued','in_prep','ready','delivered','failed','canceled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.kitchen_status as enum ('pending','in_prep','approved_done'); exception when duplicate_object then null; end $$;
do $$ begin create type public.delivery_status as enum ('pending','out_for_delivery','delivered','failed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.cancellation_status as enum ('requested','reviewed','approved','transferred','rejected'); exception when duplicate_object then null; end $$;

-- ============================================================
-- Identity / RBAC
-- ============================================================

create table if not exists public.employee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.employee_role not null default 'cs',
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_employee()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.employee_profiles(user_id,full_name)
  values(new.id,coalesce(nullif(new.raw_user_meta_data->>'full_name',''),new.email,'ECO User'))
  on conflict(user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_employee();

create or replace function public.current_employee_role()
returns public.employee_role language sql stable security definer set search_path=public as $$
  select role from public.employee_profiles where user_id=auth.uid() and active=true limit 1
$$;

create or replace function public.has_role(variadic roles public.employee_role[])
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_employee_role()=any(roles),false)
$$;

-- ============================================================
-- CRM / Client 360
-- ============================================================

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check(length(trim(full_name))>1),
  phone text not null unique,
  delivery_zone smallint not null check(delivery_zone between 1 and 4),
  location_url text,
  address_text text,
  dietary_notes text,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.client_issues (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  category text not null default 'complaint' check(category in ('complaint','note','request')),
  note text not null check(length(trim(note))>0),
  image_url text,
  resolved boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Product Catalog + Monthly Menu Planner
-- ============================================================

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  meal_type public.meal_type not null default 'standard',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(name,meal_type)
);

create table if not exists public.packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  size_name text not null default 'Regular',
  number_of_days integer not null check(number_of_days>0),
  price numeric(12,2) not null check(price>=0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(name,size_name)
);

create table if not exists public.menu_months (
  id uuid primary key default gen_random_uuid(),
  month_start date not null unique,
  name text not null,
  status public.menu_status not null default 'draft',
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check(extract(day from month_start)=1)
);

create table if not exists public.menu_calendar_items (
  id uuid primary key default gen_random_uuid(),
  menu_month_id uuid not null references public.menu_months(id) on delete cascade,
  service_date date not null,
  package_id uuid not null references public.packages(id) on delete cascade,
  meal_id uuid not null references public.meals(id) on delete restrict,
  quantity integer not null default 1 check(quantity>0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(menu_month_id,service_date,package_id,meal_id)
);

-- ============================================================
-- Orders / Payments / Subscriptions
-- ============================================================

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  client_id uuid not null references public.clients(id) on delete restrict,
  order_type public.order_type not null,
  sales_user_id uuid references auth.users(id) on delete set null,
  total_price numeric(12,2) not null check(total_price>=0),
  payment_method public.payment_method not null,
  payment_reference text,
  payment_proof_path text,
  status public.order_status not null default 'pending_accounting',
  accounting_verified_by uuid references auth.users(id) on delete set null,
  accounting_verified_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  meal_id uuid not null references public.meals(id) on delete restrict,
  service_date date not null,
  quantity integer not null default 1 check(quantity>0),
  unit_price numeric(12,2) not null check(unit_price>=0),
  line_total numeric(12,2) generated always as (quantity*unit_price) stored,
  notes text
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  amount numeric(12,2) not null check(amount>0),
  method public.payment_method not null,
  status public.payment_status not null default 'pending',
  reference text,
  proof_path text,
  source text not null default 'sales' check(source in ('sales','rider','accounting','refund')),
  collected_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  collected_at timestamptz not null default now(),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  order_id uuid not null unique references public.orders(id) on delete restrict,
  package_id uuid not null references public.packages(id) on delete restrict,
  status public.subscription_status not null default 'pending_payment',
  start_date date not null,
  delivery_frequency public.delivery_frequency not null default 'daily',
  weekly_delivery_day smallint check(weekly_delivery_day between 1 and 7),
  total_days integer not null check(total_days>0),
  consumed_days integer not null default 0 check(consumed_days>=0),
  remaining_days integer generated always as (greatest(total_days-consumed_days,0)) stored,
  pause_until date,
  custom_price numeric(12,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(consumed_days<=total_days),
  check((delivery_frequency='weekly' and weekly_delivery_day is not null) or (delivery_frequency='daily' and weekly_delivery_day is null))
);

create table if not exists public.subscription_pauses (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  pause_from date not null,
  pause_until date,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  resumed_at timestamptz,
  created_at timestamptz not null default now(),
  check(pause_until is null or pause_until>=pause_from)
);

create table if not exists public.subscription_menu_overrides (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  service_date date not null,
  meal_id uuid not null references public.meals(id) on delete restrict,
  quantity integer not null default 1 check(quantity>0),
  custom_price_delta numeric(12,2) not null default 0,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(subscription_id,service_date,meal_id)
);

-- ============================================================
-- Fulfillment / Kitchen / Delivery
-- ============================================================

create table if not exists public.fulfillment_days (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  subscription_day_number integer,
  service_date date not null,
  original_meal_id uuid not null references public.meals(id) on delete restrict,
  current_meal_id uuid not null references public.meals(id) on delete restrict,
  meal_type public.meal_type not null,
  quantity integer not null default 1 check(quantity>0),
  source text not null check(source in ('calendar','custom_override','adhoc','admin_override')),
  status public.fulfillment_status not null default 'planned',
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id,service_date,current_meal_id,source)
);

create table if not exists public.meal_swap_audit (
  id uuid primary key default gen_random_uuid(),
  fulfillment_day_id uuid not null references public.fulfillment_days(id) on delete restrict,
  old_meal_id uuid not null references public.meals(id) on delete restrict,
  new_meal_id uuid not null references public.meals(id) on delete restrict,
  price_delta numeric(12,2) not null default 0,
  reason text,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);

create table if not exists public.kitchen_batches (
  id uuid primary key default gen_random_uuid(),
  production_date date not null unique,
  locked_at timestamptz not null default now(),
  source text not null default 'manual_bulk' check(source in ('manual_bulk','automatic_cutoff')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.production_queue (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid references public.kitchen_batches(id) on delete set null,
  fulfillment_day_id uuid not null unique references public.fulfillment_days(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  production_date date not null,
  client_name_snapshot text not null,
  meal_name_snapshot text not null,
  meal_type public.meal_type not null,
  quantity integer not null check(quantity>0),
  delivery_zone smallint not null check(delivery_zone between 1 and 4),
  dietary_notes_snapshot text,
  status public.kitchen_status not null default 'pending',
  source text not null check(source in ('calendar','custom_override','adhoc','admin_override')),
  approved_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  delivery_date date not null,
  zone smallint not null check(zone between 1 and 4),
  rider_user_id uuid references auth.users(id) on delete set null,
  status public.delivery_status not null default 'pending',
  cash_expected numeric(12,2) not null default 0 check(cash_expected>=0),
  amount_collected numeric(12,2) not null default 0 check(amount_collected>=0),
  collection_method public.payment_method,
  collection_logged_at timestamptz,
  delivered_at timestamptz,
  failed_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id,delivery_date)
);

create table if not exists public.delivery_items (
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  fulfillment_day_id uuid not null unique references public.fulfillment_days(id) on delete restrict,
  primary key(delivery_id,fulfillment_day_id)
);

-- ============================================================
-- Cancellations / Notifications / Audit
-- ============================================================

create table if not exists public.cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  requested_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  remaining_value numeric(12,2) not null,
  consumed_value numeric(12,2) not null,
  consumed_penalty numeric(12,2) not null,
  delivery_penalty numeric(12,2) not null,
  refund_amount numeric(12,2) not null,
  status public.cancellation_status not null default 'requested',
  receipt_url text,
  notes text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  transferred_at timestamptz
);

create unique index if not exists one_open_cancellation on public.cancellation_requests(subscription_id) where status in ('requested','reviewed','approved');

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  target_role public.employee_role,
  target_user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check(target_role is not null or target_user_id is not null)
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Views: Client 360, Kitchen, Accounting
-- ============================================================

create or replace view public.client_360_summary with(security_invoker=true) as
select c.*,
  coalesce((select sum(p.amount) from public.payments p join public.orders o on o.id=p.order_id where o.client_id=c.id and p.status='verified'),0)::numeric(12,2) as total_verified_paid,
  greatest(coalesce((select sum(o.total_price) from public.orders o where o.client_id=c.id and o.status in ('confirmed','pending_accounting')),0)-coalesce((select sum(p.amount) from public.payments p join public.orders o2 on o2.id=p.order_id where o2.client_id=c.id and p.status='verified'),0),0)::numeric(12,2) as remaining_balance,
  (select count(*) from public.orders o where o.client_id=c.id)::integer as total_orders,
  (select count(*) from public.client_issues i where i.client_id=c.id and i.category='complaint')::integer as total_complaints,
  (select count(*) from public.cancellation_requests cr where cr.client_id=c.id)::integer as total_cancellations
from public.clients c;

create or replace view public.kitchen_aggregate with(security_invoker=true) as
select production_date,meal_name_snapshot,meal_type,sum(quantity)::integer as total_quantity,
  count(*)::integer as client_lines
from public.production_queue
where status<>'approved_done'
group by production_date,meal_name_snapshot,meal_type;

create or replace view public.daily_cash_closing with(security_invoker=true) as
select delivery_date,
  sum(cash_expected)::numeric(12,2) as expected_cash,
  sum(amount_collected)::numeric(12,2) as actual_collected,
  (sum(cash_expected)-sum(amount_collected))::numeric(12,2) as variance
from public.deliveries group by delivery_date;

create or replace view public.system_financial_summary with(security_invoker=true) as
with paid as (select coalesce(sum(amount),0) v from public.payments where status='verified'),
delivered_sub as (
  select coalesce(sum((o.total_price/nullif(s.total_days,0))*s.consumed_days),0) v
  from public.subscriptions s join public.orders o on o.id=s.order_id where o.status in ('confirmed','refunded')
), delivered_adhoc as (
  select coalesce(sum(o.total_price),0) v from public.orders o
  where o.order_type='adhoc' and exists(select 1 from public.deliveries d where d.order_id=o.id and d.status='delivered')
)
select paid.v::numeric(12,2) as verified_client_funds,
  (delivered_sub.v+delivered_adhoc.v)::numeric(12,2) as delivered_value,
  greatest(paid.v-(delivered_sub.v+delivered_adhoc.v),0)::numeric(12,2) as remaining_client_funds
from paid,delivered_sub,delivered_adhoc;

create or replace view public.delivery_history with(security_invoker=true) as
select d.id,d.client_id,d.subscription_id,d.order_id,d.delivery_date,d.delivered_at,d.zone,d.status,
  (select max(f.subscription_day_number) from public.delivery_items di join public.fulfillment_days f on f.id=di.fulfillment_day_id where di.delivery_id=d.id) as delivered_day_number,
  o.order_number,c.full_name as client_name
from public.deliveries d
join public.orders o on o.id=d.order_id
join public.clients c on c.id=d.client_id
left join public.subscriptions s on s.id=d.subscription_id;

-- ============================================================
-- Business RPCs
-- ============================================================

create or replace function public.new_order_number()
returns text language sql volatile as $$
  select 'ECO-'||to_char(timezone('Africa/Cairo',now()),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6))
$$;

create or replace function public.create_sales_order(
  p_client_id uuid,
  p_order_type public.order_type,
  p_package_id uuid default null,
  p_start_date date default null,
  p_delivery_frequency public.delivery_frequency default 'daily',
  p_weekly_delivery_day smallint default null,
  p_payment_method public.payment_method default 'cash',
  p_payment_reference text default null,
  p_payment_proof_path text default null,
  p_adhoc_items jsonb default '[]'::jsonb
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_order uuid; v_package public.packages; v_total numeric(12,2); item jsonb;
begin
  if not public.has_role('admin','sales') then raise exception 'Sales or Admin only'; end if;
  if not exists(select 1 from public.clients where id=p_client_id and active=true) then raise exception 'Client not found'; end if;
  if p_payment_method in ('instapay','website_app') and (nullif(trim(coalesce(p_payment_reference,'')),'') is null or nullif(trim(coalesce(p_payment_proof_path,'')),'') is null) then raise exception 'Payment reference and proof are required'; end if;

  if p_order_type='subscription' then
    if p_package_id is null or p_start_date is null then raise exception 'Package and start date are required'; end if;
    select * into v_package from public.packages where id=p_package_id and active=true;
    if not found then raise exception 'Package not found'; end if;
    v_total:=v_package.price;
  else
    select coalesce(sum(((e.item->>'quantity')::integer)*((e.item->>'unit_price')::numeric)),0)
    into v_total from jsonb_array_elements(p_adhoc_items) as e(item);
    if v_total<=0 then raise exception 'Ad-hoc order requires priced items'; end if;
  end if;

  insert into public.orders(order_number,client_id,order_type,sales_user_id,total_price,payment_method,payment_reference,payment_proof_path)
  values(public.new_order_number(),p_client_id,p_order_type,auth.uid(),v_total,p_payment_method,p_payment_reference,p_payment_proof_path)
  returning id into v_order;

  if p_payment_method<>'cash' then
    insert into public.payments(order_id,amount,method,status,reference,proof_path,source,collected_by)
    values(v_order,v_total,p_payment_method,'pending',p_payment_reference,p_payment_proof_path,'sales',auth.uid());
  end if;

  if p_order_type='subscription' then
    insert into public.subscriptions(client_id,order_id,package_id,start_date,delivery_frequency,weekly_delivery_day,total_days)
    values(p_client_id,v_order,v_package.id,p_start_date,p_delivery_frequency,case when p_delivery_frequency='weekly' then p_weekly_delivery_day else null end,v_package.number_of_days);
  else
    for item in select e.item from jsonb_array_elements(p_adhoc_items) as e(item) loop
      insert into public.order_items(order_id,meal_id,service_date,quantity,unit_price,notes)
      values(v_order,(item->>'meal_id')::uuid,(item->>'service_date')::date,(item->>'quantity')::integer,(item->>'unit_price')::numeric,item->>'notes');
    end loop;
  end if;

  insert into public.notifications(target_role,title,body,entity_type,entity_id)
  values('accounting','طلب جديد بانتظار الاعتماد','Order '||(select order_number from public.orders where id=v_order)||' يحتاج مراجعة الدفع','order',v_order);
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details) values(auth.uid(),'order.created','order',v_order,jsonb_build_object('type',p_order_type,'total',v_total));
  return v_order;
end $$;

revoke all on function public.create_sales_order(uuid,public.order_type,uuid,date,public.delivery_frequency,smallint,public.payment_method,text,text,jsonb) from public,anon;
grant execute on function public.create_sales_order(uuid,public.order_type,uuid,date,public.delivery_frequency,smallint,public.payment_method,text,text,jsonb) to authenticated;

create or replace function public.accounting_confirm_order(p_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare o public.orders; it record; f_id uuid; m public.meals; c public.clients;
begin
  if not public.has_role('admin','accounting') then raise exception 'Accounting only'; end if;
  select * into o from public.orders where id=p_order_id for update;
  if not found or o.status<>'pending_accounting' then raise exception 'Order is not pending'; end if;
  if o.payment_method in ('instapay','website_app') and (o.payment_reference is null or o.payment_proof_path is null) then raise exception 'Payment proof missing'; end if;
  update public.orders set status='confirmed',accounting_verified_by=auth.uid(),accounting_verified_at=now() where id=o.id;
  if o.payment_method in ('instapay','website_app') then update public.payments set status='verified',verified_by=auth.uid(),verified_at=now() where order_id=o.id and status='pending'; end if;
  update public.subscriptions set status='active' where order_id=o.id and status='pending_payment';

  if o.order_type='adhoc' then
    select * into c from public.clients where id=o.client_id;
    for it in select oi.*,me.meal_type,me.name meal_name from public.order_items oi join public.meals me on me.id=oi.meal_id where oi.order_id=o.id loop
      insert into public.fulfillment_days(order_id,client_id,service_date,original_meal_id,current_meal_id,meal_type,quantity,source,status)
      values(o.id,o.client_id,it.service_date,it.meal_id,it.meal_id,it.meal_type,it.quantity,'adhoc','queued')
      on conflict do nothing returning id into f_id;
      if f_id is not null then
        insert into public.production_queue(fulfillment_day_id,order_id,client_id,production_date,client_name_snapshot,meal_name_snapshot,meal_type,quantity,delivery_zone,dietary_notes_snapshot,source)
        values(f_id,o.id,o.client_id,it.service_date,c.full_name,it.meal_name,it.meal_type,it.quantity,c.delivery_zone,c.dietary_notes,'adhoc') on conflict do nothing;
      end if;
    end loop;
  end if;
  insert into public.audit_log(actor_user_id,action,entity_type,entity_id) values(auth.uid(),'order.accounting_confirmed','order',o.id);
end $$;

revoke all on function public.accounting_confirm_order(uuid) from public,anon;
grant execute on function public.accounting_confirm_order(uuid) to authenticated;

create or replace function public.pause_subscription(p_subscription_id uuid,p_pause_until date default null,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.has_role('admin','cs') then raise exception 'CS or Admin only'; end if;
  if p_pause_until is not null and p_pause_until<current_date then raise exception 'End date cannot be in the past'; end if;
  update public.subscriptions set status='paused',pause_until=p_pause_until where id=p_subscription_id and status='active';
  if not found then raise exception 'Active subscription not found'; end if;
  insert into public.subscription_pauses(subscription_id,pause_from,pause_until,reason,created_by) values(p_subscription_id,current_date,p_pause_until,p_reason,auth.uid());
end $$;

create or replace function public.resume_subscription(p_subscription_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.has_role('admin','cs') then raise exception 'CS or Admin only'; end if;
  update public.subscriptions set status='active',pause_until=null where id=p_subscription_id and status='paused';
  update public.subscription_pauses set resumed_at=now() where subscription_id=p_subscription_id and resumed_at is null;
end $$;

revoke all on function public.pause_subscription(uuid,date,text) from public,anon;
revoke all on function public.resume_subscription(uuid) from public,anon;
grant execute on function public.pause_subscription(uuid,date,text) to authenticated;
grant execute on function public.resume_subscription(uuid) to authenticated;

create or replace function public.bulk_send_to_kitchen(p_subscription_ids uuid[],p_service_date date)
returns integer language plpgsql security definer set search_path=public as $$
declare s record; x record; c public.clients; b uuid; f_id uuid; count_inserted integer:=0; override_count integer;
begin
  if auth.uid() is not null and not public.has_role('admin','cs','kitchen') then raise exception 'Not allowed'; end if;
  update public.subscriptions set status='active',pause_until=null where status='paused' and pause_until is not null and pause_until<p_service_date;
  update public.subscription_pauses set resumed_at=coalesce(resumed_at,now()) where resumed_at is null and pause_until is not null and pause_until<p_service_date;
  insert into public.kitchen_batches(production_date,source,created_by) values(p_service_date,'manual_bulk',auth.uid())
  on conflict(production_date) do update set production_date=excluded.production_date returning id into b;

  for s in
    select sub.*,o.status order_status from public.subscriptions sub join public.orders o on o.id=sub.order_id
    where sub.id=any(p_subscription_ids) and sub.status='active' and o.status='confirmed' and sub.start_date<=p_service_date and sub.remaining_days>0
      and (sub.delivery_frequency='daily' or sub.weekly_delivery_day=extract(isodow from p_service_date)::int)
      and not exists(select 1 from public.subscription_pauses sp where sp.subscription_id=sub.id and sp.resumed_at is null and p_service_date>=sp.pause_from and (sp.pause_until is null or p_service_date<=sp.pause_until))
  loop
    select * into c from public.clients where id=s.client_id;
    select count(*) into override_count from public.subscription_menu_overrides smo where smo.subscription_id=s.id and smo.service_date=p_service_date;
    if override_count>0 then
      for x in select smo.meal_id,smo.quantity,me.name meal_name,me.meal_type from public.subscription_menu_overrides smo join public.meals me on me.id=smo.meal_id where smo.subscription_id=s.id and smo.service_date=p_service_date loop
        f_id:=null;
        insert into public.fulfillment_days(order_id,subscription_id,client_id,subscription_day_number,service_date,original_meal_id,current_meal_id,meal_type,quantity,source,status)
        values(s.order_id,s.id,s.client_id,s.consumed_days+1,p_service_date,x.meal_id,x.meal_id,x.meal_type,x.quantity,'custom_override','queued') on conflict do nothing returning id into f_id;
        if f_id is not null then insert into public.production_queue(batch_id,fulfillment_day_id,order_id,subscription_id,client_id,production_date,client_name_snapshot,meal_name_snapshot,meal_type,quantity,delivery_zone,dietary_notes_snapshot,source) values(b,f_id,s.order_id,s.id,s.client_id,p_service_date,c.full_name,x.meal_name,x.meal_type,x.quantity,c.delivery_zone,c.dietary_notes,'custom_override'); count_inserted:=count_inserted+1; end if;
      end loop;
    else
      if not exists(select 1 from public.menu_calendar_items mci join public.menu_months mm on mm.id=mci.menu_month_id where mci.package_id=s.package_id and mci.service_date=p_service_date and mm.status='published') then raise exception 'Published menu is missing for subscription % on %',s.id,p_service_date; end if;
      for x in select mci.meal_id,mci.quantity,me.name meal_name,me.meal_type from public.menu_calendar_items mci join public.menu_months mm on mm.id=mci.menu_month_id join public.meals me on me.id=mci.meal_id where mci.package_id=s.package_id and mci.service_date=p_service_date and mm.status='published' loop
        f_id:=null;
        insert into public.fulfillment_days(order_id,subscription_id,client_id,subscription_day_number,service_date,original_meal_id,current_meal_id,meal_type,quantity,source,status)
        values(s.order_id,s.id,s.client_id,s.consumed_days+1,p_service_date,x.meal_id,x.meal_id,x.meal_type,x.quantity,'calendar','queued') on conflict do nothing returning id into f_id;
        if f_id is not null then insert into public.production_queue(batch_id,fulfillment_day_id,order_id,subscription_id,client_id,production_date,client_name_snapshot,meal_name_snapshot,meal_type,quantity,delivery_zone,dietary_notes_snapshot,source) values(b,f_id,s.order_id,s.id,s.client_id,p_service_date,c.full_name,x.meal_name,x.meal_type,x.quantity,c.delivery_zone,c.dietary_notes,'calendar'); count_inserted:=count_inserted+1; end if;
      end loop;
    end if;
  end loop;
  return count_inserted;
end $$;

revoke all on function public.bulk_send_to_kitchen(uuid[],date) from public,anon;
grant execute on function public.bulk_send_to_kitchen(uuid[],date) to authenticated,service_role;

create or replace function public.run_kitchen_cutoff(p_service_date date default (timezone('Africa/Cairo',now())::date+1))
returns integer language plpgsql security definer set search_path=public as $$
declare ids uuid[];
begin
  select array_agg(s.id) into ids from public.subscriptions s join public.orders o on o.id=s.order_id
  where (s.status='active' or (s.status='paused' and s.pause_until is not null and s.pause_until<p_service_date)) and o.status='confirmed';
  if ids is null then return 0; end if;
  perform public.bulk_send_to_kitchen(ids,p_service_date);
  update public.kitchen_batches set source='automatic_cutoff' where production_date=p_service_date;
  return (select count(*)::integer from public.production_queue where production_date=p_service_date);
end $$;

revoke all on function public.run_kitchen_cutoff(date) from public,anon,authenticated;
grant execute on function public.run_kitchen_cutoff(date) to service_role;

create or replace function public.set_kitchen_status(p_queue_id uuid,p_status public.kitchen_status)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.has_role('admin','kitchen') then raise exception 'Kitchen only'; end if;
  update public.production_queue set status=p_status,approved_at=case when p_status='approved_done' then now() else null end,updated_by=auth.uid() where id=p_queue_id;
end $$;

revoke all on function public.set_kitchen_status(uuid,public.kitchen_status) from public,anon;
grant execute on function public.set_kitchen_status(uuid,public.kitchen_status) to authenticated;

create or replace function public.create_delivery_after_approval()
returns trigger language plpgsql security definer set search_path=public as $$
declare d_id uuid; c public.clients; cash_due numeric(12,2); o public.orders;
begin
  if new.status='approved_done' and old.status is distinct from 'approved_done' then
    select * into c from public.clients where id=new.client_id;
    select * into o from public.orders where id=new.order_id;
    cash_due:=0;
    if o.payment_method='cash' then select greatest(o.total_price-coalesce(sum(p.amount) filter(where p.status in ('pending','verified') and p.source='rider'),0),0) into cash_due from public.payments p where p.order_id=o.id; end if;
    insert into public.deliveries(order_id,subscription_id,client_id,delivery_date,zone,cash_expected)
    values(new.order_id,new.subscription_id,new.client_id,new.production_date,new.delivery_zone,coalesce(cash_due,0))
    on conflict(order_id,delivery_date) do update set cash_expected=greatest(public.deliveries.cash_expected,excluded.cash_expected)
    returning id into d_id;
    insert into public.delivery_items(delivery_id,fulfillment_day_id) values(d_id,new.fulfillment_day_id) on conflict do nothing;
    update public.fulfillment_days set status='ready' where id=new.fulfillment_day_id;
  end if;
  return new;
end $$;

drop trigger if exists kitchen_to_delivery on public.production_queue;
create trigger kitchen_to_delivery after update of status on public.production_queue for each row execute procedure public.create_delivery_after_approval();

create or replace function public.record_delivery_collection(p_delivery_id uuid,p_amount numeric,p_method public.payment_method default 'cash')
returns void language plpgsql security definer set search_path=public as $$
declare d public.deliveries;
begin
  if not public.has_role('admin','delivery') then raise exception 'Delivery only'; end if;
  select * into d from public.deliveries where id=p_delivery_id for update;
  if not found or p_amount<0 then raise exception 'Invalid delivery'; end if;
  update public.deliveries set amount_collected=p_amount,collection_method=p_method,collection_logged_at=now() where id=d.id;
  if p_amount>0 then insert into public.payments(order_id,amount,method,status,source,collected_by,collected_at) values(d.order_id,p_amount,p_method,'pending','rider',auth.uid(),now()); end if;
  insert into public.notifications(target_role,title,body,entity_type,entity_id) values('accounting','تحصيل Rider جديد','تم تسجيل تحصيل '||p_amount||' ج ويحتاج إقفال يومي','delivery',d.id);
end $$;

create or replace function public.complete_delivery(p_delivery_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare d public.deliveries; s public.subscriptions; new_remaining integer;
begin
  if not public.has_role('admin','delivery') then raise exception 'Delivery only'; end if;
  select * into d from public.deliveries where id=p_delivery_id for update;
  if not found or d.status='delivered' then return; end if;
  update public.deliveries set status='delivered',delivered_at=now() where id=d.id;
  update public.fulfillment_days f set status='delivered',consumed_at=now() where exists(select 1 from public.delivery_items di where di.delivery_id=d.id and di.fulfillment_day_id=f.id);
  if d.subscription_id is not null then
    select * into s from public.subscriptions where id=d.subscription_id for update;
    update public.subscriptions set consumed_days=least(consumed_days+1,total_days),status=case when consumed_days+1>=total_days then 'finished' else status end where id=s.id returning remaining_days into new_remaining;
    if new_remaining between 1 and 3 then insert into public.notifications(target_role,title,body,entity_type,entity_id) values('sales','اشتراك قرب يخلص','باقي '||new_remaining||' يوم على الاشتراك','subscription',s.id); end if;
  end if;
end $$;

revoke all on function public.record_delivery_collection(uuid,numeric,public.payment_method) from public,anon;
revoke all on function public.complete_delivery(uuid) from public,anon;
grant execute on function public.record_delivery_collection(uuid,numeric,public.payment_method) to authenticated;
grant execute on function public.complete_delivery(uuid) to authenticated;

create or replace function public.verify_cash_payment(p_payment_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.has_role('admin','accounting') then raise exception 'Accounting only'; end if;
  update public.payments set status='verified',verified_by=auth.uid(),verified_at=now() where id=p_payment_id and status='pending';
end $$;
revoke all on function public.verify_cash_payment(uuid) from public,anon;
grant execute on function public.verify_cash_payment(uuid) to authenticated;

create or replace function public.request_cancellation(p_subscription_id uuid,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare s public.subscriptions; o public.orders; per_day numeric; consumed numeric; remaining numeric; cp numeric; dp numeric; refund numeric; cid uuid;
begin
  if not public.has_role('admin','cs') then raise exception 'CS only'; end if;
  select * into s from public.subscriptions where id=p_subscription_id and status in ('active','paused'); if not found then raise exception 'Subscription unavailable'; end if;
  select * into o from public.orders where id=s.order_id; per_day:=o.total_price/s.total_days; consumed:=round(per_day*s.consumed_days,2); remaining:=round(per_day*s.remaining_days,2); cp:=round(consumed*.20,2);
  select count(*)*30 into dp from public.deliveries where subscription_id=s.id and status='delivered'; refund:=greatest(remaining-cp-dp,0);
  insert into public.cancellation_requests(subscription_id,client_id,requested_by,remaining_value,consumed_value,consumed_penalty,delivery_penalty,refund_amount,notes) values(s.id,s.client_id,auth.uid(),remaining,consumed,cp,dp,refund,p_notes) returning id into cid;
  insert into public.notifications(target_role,title,body,entity_type,entity_id) values('accounting','طلب إلغاء جديد','Refund محسوب '||refund||' ج','cancellation',cid);
  return cid;
end $$;

create or replace function public.finalize_cancellation(p_cancellation_id uuid,p_receipt_url text)
returns void language plpgsql security definer set search_path=public as $$
declare cr public.cancellation_requests; oid uuid;
begin
  if not public.has_role('admin','accounting') then raise exception 'Accounting only'; end if;
  if nullif(trim(coalesce(p_receipt_url,'')),'') is null then raise exception 'Receipt URL required'; end if;
  select * into cr from public.cancellation_requests where id=p_cancellation_id for update; if not found then raise exception 'Cancellation not found'; end if;
  update public.cancellation_requests set status='transferred',receipt_url=p_receipt_url,reviewed_by=auth.uid(),reviewed_at=coalesce(reviewed_at,now()),transferred_at=now() where id=cr.id;
  select order_id into oid from public.subscriptions where id=cr.subscription_id;
  update public.subscriptions set status='canceled' where id=cr.subscription_id;
  update public.orders set status='refunded' where id=oid;
  if cr.refund_amount>0 then
    insert into public.payments(order_id,amount,method,status,reference,source,verified_by,verified_at)
    values(oid,cr.refund_amount,'website_app','refunded',p_receipt_url,'refund',auth.uid(),now());
  end if;
end $$;

revoke all on function public.request_cancellation(uuid,text) from public,anon;
revoke all on function public.finalize_cancellation(uuid,text) from public,anon;
grant execute on function public.request_cancellation(uuid,text) to authenticated;
grant execute on function public.finalize_cancellation(uuid,text) to authenticated;

-- ============================================================
-- updated_at + indexes
-- ============================================================

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists clients_updated_at on public.clients; create trigger clients_updated_at before update on public.clients for each row execute procedure public.set_updated_at();
drop trigger if exists packages_updated_at on public.packages; create trigger packages_updated_at before update on public.packages for each row execute procedure public.set_updated_at();
drop trigger if exists orders_updated_at on public.orders; create trigger orders_updated_at before update on public.orders for each row execute procedure public.set_updated_at();
drop trigger if exists subscriptions_updated_at on public.subscriptions; create trigger subscriptions_updated_at before update on public.subscriptions for each row execute procedure public.set_updated_at();
drop trigger if exists fulfillment_updated_at on public.fulfillment_days; create trigger fulfillment_updated_at before update on public.fulfillment_days for each row execute procedure public.set_updated_at();
drop trigger if exists queue_updated_at on public.production_queue; create trigger queue_updated_at before update on public.production_queue for each row execute procedure public.set_updated_at();
drop trigger if exists delivery_updated_at on public.deliveries; create trigger delivery_updated_at before update on public.deliveries for each row execute procedure public.set_updated_at();

create index if not exists idx_clients_zone on public.clients(delivery_zone) where active=true;
create index if not exists idx_issues_client on public.client_issues(client_id,created_at desc);
create index if not exists idx_menu_date_package on public.menu_calendar_items(service_date,package_id);
create index if not exists idx_orders_status on public.orders(status,created_at desc);
create index if not exists idx_orders_client on public.orders(client_id,created_at desc);
create index if not exists idx_payments_order_status on public.payments(order_id,status);
create index if not exists idx_subscriptions_active on public.subscriptions(status,remaining_days);
create index if not exists idx_fulfillment_date on public.fulfillment_days(service_date,status);
create index if not exists idx_queue_date_status on public.production_queue(production_date,status);
create index if not exists idx_delivery_date_zone on public.deliveries(delivery_date,zone,status);

-- ============================================================
-- RLS
-- ============================================================

alter table public.employee_profiles enable row level security;
alter table public.clients enable row level security;
alter table public.client_issues enable row level security;
alter table public.meals enable row level security;
alter table public.packages enable row level security;
alter table public.menu_months enable row level security;
alter table public.menu_calendar_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.subscription_pauses enable row level security;
alter table public.subscription_menu_overrides enable row level security;
alter table public.fulfillment_days enable row level security;
alter table public.meal_swap_audit enable row level security;
alter table public.kitchen_batches enable row level security;
alter table public.production_queue enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_items enable row level security;
alter table public.cancellation_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log enable row level security;

create policy profiles_read on public.employee_profiles for select to authenticated using(active=true or user_id=auth.uid() or public.has_role('admin'));
create policy profiles_admin on public.employee_profiles for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));

create policy clients_read on public.clients for select to authenticated using(true);
create policy clients_insert on public.clients for insert to authenticated with check(public.has_role('admin','sales','cs'));
create policy clients_update on public.clients for update to authenticated using(public.has_role('admin','sales','cs')) with check(public.has_role('admin','sales','cs'));
create policy clients_delete on public.clients for delete to authenticated using(public.has_role('admin'));
create policy issues_read on public.client_issues for select to authenticated using(public.has_role('admin','sales','cs'));
create policy issues_insert on public.client_issues for insert to authenticated with check(public.has_role('admin','cs'));
create policy issues_update on public.client_issues for update to authenticated using(public.has_role('admin','cs')) with check(public.has_role('admin','cs'));

create policy meals_read on public.meals for select to authenticated using(true);
create policy meals_admin on public.meals for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy packages_read on public.packages for select to authenticated using(true);
create policy packages_admin on public.packages for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy menu_months_read on public.menu_months for select to authenticated using(true);
create policy menu_months_admin on public.menu_months for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy menu_items_read on public.menu_calendar_items for select to authenticated using(true);
create policy menu_items_admin on public.menu_calendar_items for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));

create policy orders_read on public.orders for select to authenticated using(public.has_role('admin','sales','cs','accounting'));
create policy orders_sales_insert on public.orders for insert to authenticated with check(public.has_role('admin','sales'));
create policy orders_accounting_update on public.orders for update to authenticated using(public.has_role('admin','accounting')) with check(public.has_role('admin','accounting'));
create policy order_items_read on public.order_items for select to authenticated using(public.has_role('admin','sales','cs','accounting','kitchen','delivery'));
create policy order_items_sales on public.order_items for insert to authenticated with check(public.has_role('admin','sales'));
create policy payments_read on public.payments for select to authenticated using(public.has_role('admin','sales','cs','accounting','delivery'));
create policy payments_accounting on public.payments for update to authenticated using(public.has_role('admin','accounting')) with check(public.has_role('admin','accounting'));

create policy subscriptions_read on public.subscriptions for select to authenticated using(true);
create policy subscriptions_ops on public.subscriptions for update to authenticated using(public.has_role('admin','cs','accounting')) with check(public.has_role('admin','cs','accounting'));
create policy pauses_read on public.subscription_pauses for select to authenticated using(public.has_role('admin','sales','cs','accounting'));
create policy pauses_ops on public.subscription_pauses for all to authenticated using(public.has_role('admin','cs')) with check(public.has_role('admin','cs'));
create policy overrides_read on public.subscription_menu_overrides for select to authenticated using(public.has_role('admin','cs','kitchen'));
create policy overrides_ops on public.subscription_menu_overrides for all to authenticated using(public.has_role('admin','cs')) with check(public.has_role('admin','cs'));

create policy fulfillment_read on public.fulfillment_days for select to authenticated using(public.has_role('admin','cs','kitchen','delivery'));
create policy fulfillment_ops on public.fulfillment_days for update to authenticated using(public.has_role('admin','cs','kitchen','delivery')) with check(public.has_role('admin','cs','kitchen','delivery'));
create policy swaps_read on public.meal_swap_audit for select to authenticated using(public.has_role('admin','cs','kitchen'));
create policy swaps_insert on public.meal_swap_audit for insert to authenticated with check(public.has_role('admin','cs'));
create policy batches_read on public.kitchen_batches for select to authenticated using(public.has_role('admin','kitchen','cs'));
create policy queue_read on public.production_queue for select to authenticated using(public.has_role('admin','kitchen','cs'));
create policy queue_update on public.production_queue for update to authenticated using(public.has_role('admin','kitchen')) with check(public.has_role('admin','kitchen'));

create policy deliveries_read on public.deliveries for select to authenticated using(public.has_role('admin','sales','delivery','accounting','cs'));
create policy delivery_items_read on public.delivery_items for select to authenticated using(public.has_role('admin','delivery','kitchen','accounting'));
create policy cancellations_read on public.cancellation_requests for select to authenticated using(public.has_role('admin','cs','accounting'));
create policy cancellations_ops on public.cancellation_requests for update to authenticated using(public.has_role('admin','accounting')) with check(public.has_role('admin','accounting'));
create policy notifications_read on public.notifications for select to authenticated using(public.has_role('admin') or target_user_id=auth.uid() or target_role=public.current_employee_role());
create policy notifications_update on public.notifications for update to authenticated using(public.has_role('admin') or target_user_id=auth.uid() or target_role=public.current_employee_role()) with check(public.has_role('admin') or target_user_id=auth.uid() or target_role=public.current_employee_role());
create policy audit_admin_read on public.audit_log for select to authenticated using(public.has_role('admin'));

grant select on public.client_360_summary,public.kitchen_aggregate,public.daily_cash_closing,public.system_financial_summary,public.delivery_history to authenticated;

-- ============================================================
-- Private payment proof bucket + RLS
-- ============================================================

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('payment-proofs','payment-proofs',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760;

create policy payment_proofs_insert on storage.objects for insert to authenticated with check(bucket_id='payment-proofs' and public.has_role('admin','sales','accounting'));
create policy payment_proofs_read on storage.objects for select to authenticated using(bucket_id='payment-proofs' and public.has_role('admin','sales','accounting'));

-- ============================================================
-- Safe reference data. Admin can edit everything from Catalog UI.
-- ============================================================

insert into public.meals(name,meal_type) values
('Grilled Chicken','standard'),('Steak','standard'),('LC Chicken','lc'),('Chicken Burger','standard'),('High Protein Chicken','high_protein')
on conflict(name,meal_type) do nothing;

insert into public.packages(name,size_name,number_of_days,price) values
('Package A','Regular',6,1800),('Package B','Regular',12,3600),('Lunch Only','Regular',18,5400),('Full Day','Regular',24,7200),('Full Day','Hero',24,9600)
on conflict(name,size_name) do nothing;
