-- Eco Healthy ERP V12 — incremental subscription operations update + safe demo data
-- Run this ONLY after V11 is already installed (your validator previously showed Installed versions: 11).
-- This file does not delete non-demo records and contains no passwords or API keys.

begin;

-- Subscription operations acceptance layer. This migration contains structure,
-- security and transactional functions only; demo records live in a separate seed.

insert into public.permissions(code,name,module,description,is_sensitive) values
('subscriptions.operate_daily','Operate daily subscriptions','Subscriptions','Freeze, skip and adjust daily portions in branch scope',true),
('refunds.pay','Pay approved refunds','Finance','Record refund cash transfer and proof',true)
on conflict(code) do nothing;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('subscriptions.operate_daily')
where r.code in('operations_manager','customer_service') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('refunds.pay')
where r.code in('finance_manager','finance_accountant') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r cross join public.permissions p
where r.code='ceo_super_admin' on conflict do nothing;

create table public.delivery_zones(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  code text not null,
  name text not null,
  delivery_fee numeric(18,2) not null default 0 check(delivery_fee>=0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,code)
);

create table public.meal_menu_days(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cycle_name text not null default 'Standard 31-day menu',
  day_number integer not null check(day_number between 1 and 31),
  breakfast text not null,
  lunch text not null,
  dinner text not null,
  snack_1 text not null,
  snack_2 text not null,
  delivery_note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,cycle_name,day_number)
);

create table public.subscription_operation_events(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  planned_service_day_id uuid references public.planned_service_days(id) on delete set null,
  event_type text not null check(event_type in('freeze','reactivate','skip_day','extra_portions','meal_override','refund_requested','refund_paid')),
  details jsonb not null default '{}'::jsonb,
  actor_user_id uuid not null references public.profiles(id),
  occurred_at timestamptz not null default now(),
  is_demo boolean not null default false
);

alter table public.packages add column program_code text;
alter table public.packages add column meal_plan_code text;
alter table public.customer_addresses add column zone_id uuid references public.delivery_zones(id);
alter table public.customer_addresses add column gps_url text;
alter table public.customer_addresses add column delivery_contact_name text;
alter table public.customer_addresses add column delivery_contact_mobile text;
alter table public.customer_addresses add column delivery_window_start time;
alter table public.customer_addresses add column delivery_window_end time;
alter table public.customer_addresses add column delivery_time_confirmed boolean not null default false;
alter table public.subscriptions add column daily_portions integer not null default 1 check(daily_portions between 1 and 20);
alter table public.subscriptions add column operations_notes text;
alter table public.subscriptions add column meal_override jsonb not null default '{}'::jsonb;
alter table public.planned_service_days add column portion_multiplier integer not null default 1 check(portion_multiplier between 1 and 20);
alter table public.planned_service_days add column operations_note text;
alter table public.planned_service_days add column meal_override jsonb not null default '{}'::jsonb;
alter table public.refunds add column reason_code text;
alter table public.refunds add column calculation_basis jsonb not null default '{}'::jsonb;
alter table public.refunds add column recipient_method text;
alter table public.refunds add column recipient_account_name text;
alter table public.refunds add column recipient_account_reference text;

drop index if exists public.customers_org_mobile_uidx;
create unique index customers_org_mobile_uidx on public.customers(organization_id,mobile) where mobile is not null;
create index delivery_zones_scope_idx on public.delivery_zones(organization_id,branch_id,is_active,sort_order);
create index meal_menu_days_scope_idx on public.meal_menu_days(organization_id,cycle_name,day_number);
create index subscription_operation_events_idx on public.subscription_operation_events(subscription_id,occurred_at desc);

alter table public.delivery_zones enable row level security;
alter table public.meal_menu_days enable row level security;
alter table public.subscription_operation_events enable row level security;

create policy delivery_zones_select on public.delivery_zones for select to authenticated
using(public.has_permission('customers.view',organization_id) or public.has_permission('subscriptions.view',organization_id));
create policy meal_menu_days_select on public.meal_menu_days for select to authenticated
using(public.has_permission('subscriptions.view',organization_id));
create policy operation_events_select on public.subscription_operation_events for select to authenticated
using(public.has_permission('subscriptions.view',organization_id) and public.can_access_branch(organization_id,branch_id));

create trigger audit_delivery_zones after insert or update or delete on public.delivery_zones for each row execute function public.audit_row_change();
create trigger audit_meal_menu_days after insert or update or delete on public.meal_menu_days for each row execute function public.audit_row_change();
create trigger audit_subscription_operation_events after insert or update or delete on public.subscription_operation_events for each row execute function public.audit_row_change();

create or replace function public.create_customer_delivery_profile(
  p_branch_id uuid,p_full_name text,p_mobile text,p_email text,p_address_line text,p_area text,p_city text,
  p_latitude numeric,p_longitude numeric,p_gps_url text,p_zone_id uuid,p_delivery_notes text,
  p_delivery_window_start time,p_delivery_window_end time,p_delivery_contact_name text,p_delivery_contact_mobile text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_branch public.branches; v_customer_id uuid; v_zone public.delivery_zones;
begin
  select * into v_branch from public.branches where id=p_branch_id and status='active';
  if v_branch.id is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('customers.manage',v_branch.organization_id) or not public.can_access_branch(v_branch.organization_id,v_branch.id)) then raise exception 'customers.manage and branch access are required'; end if;
  if nullif(trim(p_full_name),'') is null or nullif(trim(p_mobile),'') is null then raise exception 'customer name and unique mobile are required'; end if;
  if nullif(trim(p_address_line),'') is null then raise exception 'detailed Arabic address is required'; end if;
  if p_latitude is null or p_longitude is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then raise exception 'valid GPS coordinates are required'; end if;
  if p_delivery_window_start is null or p_delivery_window_end is null or p_delivery_window_end<=p_delivery_window_start then raise exception 'confirmed delivery window is required'; end if;
  select * into v_zone from public.delivery_zones where id=p_zone_id and organization_id=v_branch.organization_id and is_active;
  if v_zone.id is null then raise exception 'delivery zone must belong to the organization'; end if;
  if exists(select 1 from public.customers c where c.organization_id=v_branch.organization_id and c.mobile=trim(p_mobile)) then raise exception 'mobile already belongs to another customer'; end if;
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,owner_user_id,created_by)
  values(v_branch.organization_id,v_branch.id,trim(p_full_name),trim(p_mobile),nullif(trim(p_email),''),'active',p_actor_user_id,p_actor_user_id)
  returning id into v_customer_id;
  insert into public.customer_addresses(customer_id,label,address_line,area,city,latitude,longitude,delivery_notes,is_primary,zone_id,gps_url,delivery_contact_name,delivery_contact_mobile,delivery_window_start,delivery_window_end,delivery_time_confirmed)
  values(v_customer_id,'العنوان الرئيسي',trim(p_address_line),nullif(trim(p_area),''),nullif(trim(p_city),''),p_latitude,p_longitude,nullif(trim(p_delivery_notes),''),true,v_zone.id,nullif(trim(p_gps_url),''),coalesce(nullif(trim(p_delivery_contact_name),''),trim(p_full_name)),coalesce(nullif(trim(p_delivery_contact_mobile),''),trim(p_mobile)),p_delivery_window_start,p_delivery_window_end,true);
  insert into public.customer_timeline(organization_id,customer_id,event_type,title,details,actor_user_id)
  values(v_branch.organization_id,v_customer_id,'customer.created','إنشاء ملف عميل بعنوان توصيل مؤكد',jsonb_build_object('branch_id',v_branch.id,'zone_id',v_zone.id,'mobile',trim(p_mobile)),p_actor_user_id);
  return v_customer_id;
exception when unique_violation then
  raise exception 'mobile already belongs to another customer';
end; $$;

create or replace function public.freeze_subscription_period(p_subscription_id uuid,p_starts_on date,p_ends_on date,p_reason text,p_actor_user_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_count integer; v_last_date date; v_is_current boolean;
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active subscription is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('subscriptions.operate_daily',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'subscriptions.operate_daily and branch access are required'; end if;
  if p_starts_on is null or p_ends_on is null or p_ends_on<p_starts_on or nullif(trim(p_reason),'') is null then raise exception 'valid freeze period and reason are required'; end if;
  select count(*) into v_count from public.planned_service_days where subscription_id=v_subscription.id and service_date between p_starts_on and p_ends_on and status='planned';
  if v_count=0 then raise exception 'no planned service days in freeze period'; end if;
  select max(service_date) into v_last_date from public.planned_service_days where subscription_id=v_subscription.id;
  update public.planned_service_days set status='frozen',operations_note=concat_ws(' · ',operations_note,'Freeze: '||trim(p_reason)) where subscription_id=v_subscription.id and service_date between p_starts_on and p_ends_on and status='planned';
  insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,is_demo)
  select v_subscription.id,v_last_date+g,'planned',v_subscription.branch_id,v_subscription.daily_portions,'Replacement after freeze',v_subscription.is_demo from generate_series(1,v_count) g;
  v_is_current:=current_date between p_starts_on and p_ends_on;
  insert into public.subscription_freezes(subscription_id,starts_on,ends_on,reason,status,approved_by,is_demo)
  values(v_subscription.id,p_starts_on,p_ends_on,trim(p_reason),'approved',p_actor_user_id,v_subscription.is_demo);
  update public.subscriptions set status=case when v_is_current then 'frozen' else status end,ends_on=v_last_date+v_count,updated_at=now() where id=v_subscription.id;
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'freeze',jsonb_build_object('starts_on',p_starts_on,'ends_on',p_ends_on,'reason',trim(p_reason),'replacement_days',v_count),p_actor_user_id,v_subscription.is_demo);
  return v_count;
end; $$;

create or replace function public.apply_service_day_action(p_day_ids uuid[],p_action text,p_portions integer,p_reason text,p_actor_user_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare v_day public.planned_service_days; v_subscription public.subscriptions; v_count integer:=0; v_replacement date;
begin
  if coalesce(array_length(p_day_ids,1),0)=0 then raise exception 'select at least one service day'; end if;
  if p_action not in('skip','set_portions','confirm_delivered') then raise exception 'unsupported daily action'; end if;
  if p_action='set_portions' and (p_portions is null or p_portions not between 1 and 20) then raise exception 'portions must be between 1 and 20'; end if;
  if p_action='skip' and nullif(trim(p_reason),'') is null then raise exception 'skip reason is required'; end if;
  for v_day in select * from public.planned_service_days where id=any(p_day_ids) order by service_date,id for update loop
    select * into v_subscription from public.subscriptions where id=v_day.subscription_id for update;
    if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission(case when p_action='confirm_delivered' then 'service.confirm_delivery' else 'subscriptions.operate_daily' end,v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'daily operation permission and branch access are required'; end if;
    if p_action='confirm_delivered' then
      perform public.confirm_service_delivery(v_day.id,p_actor_user_id);
    elsif p_action='set_portions' then
      update public.planned_service_days set portion_multiplier=p_portions,operations_note=concat_ws(' · ',operations_note,nullif(trim(p_reason),'')) where id=v_day.id;
      insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,planned_service_day_id,event_type,details,actor_user_id,is_demo)
      values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_day.id,'extra_portions',jsonb_build_object('portions',p_portions,'note',nullif(trim(p_reason),'')),p_actor_user_id,v_day.is_demo);
    else
      if v_day.status<>'planned' then raise exception 'only planned days can be skipped'; end if;
      select coalesce(max(service_date),v_day.service_date)+1 into v_replacement from public.planned_service_days where subscription_id=v_subscription.id;
      update public.planned_service_days set status='not_delivered',operations_note=concat_ws(' · ',operations_note,'Skip: '||trim(p_reason)) where id=v_day.id;
      insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,is_demo)
      values(v_subscription.id,v_replacement,'planned',v_subscription.branch_id,v_day.portion_multiplier,'Replacement after skipped day',v_day.is_demo);
      update public.subscriptions set ends_on=greatest(coalesce(ends_on,v_replacement),v_replacement),updated_at=now() where id=v_subscription.id;
      insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,planned_service_day_id,event_type,details,actor_user_id,is_demo)
      values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_day.id,'skip_day',jsonb_build_object('reason',trim(p_reason),'replacement_date',v_replacement),p_actor_user_id,v_day.is_demo);
    end if;
    v_count:=v_count+1;
  end loop;
  if v_count<>array_length(p_day_ids,1) then raise exception 'one or more service days are outside your scope'; end if;
  return v_count;
end; $$;

create or replace function public.request_calculated_subscription_refund(
  p_subscription_id uuid,p_reason_code text,p_reason_details text,p_recipient_method text,p_recipient_account_name text,p_recipient_account_reference text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_invoice public.invoices; v_refund_id uuid; v_remaining_days integer; v_daily_value numeric(18,2); v_amount numeric(18,2); v_refunded numeric(18,2);
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active or frozen subscription is required'; end if;
  select * into v_invoice from public.invoices where id=v_subscription.invoice_id for update;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  if nullif(trim(p_reason_code),'') is null then raise exception 'refund reason is required'; end if;
  if p_recipient_method not in('instapay','mobile_wallet','bank_transfer','cash') or nullif(trim(p_recipient_account_name),'') is null or nullif(trim(p_recipient_account_reference),'') is null then raise exception 'complete refund recipient details are required'; end if;
  select count(*) into v_remaining_days from public.planned_service_days where subscription_id=v_subscription.id and status in('planned','frozen','not_delivered','exception');
  v_remaining_days:=least(v_remaining_days,greatest(0,v_subscription.purchased_service_days-v_subscription.delivered_service_days));
  v_daily_value:=round(v_subscription.contract_value/nullif(v_subscription.purchased_service_days,0),2);
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and status in('approved','paid');
  v_amount:=least(round(v_daily_value*v_remaining_days,2),v_subscription.deferred_balance,greatest(0,v_invoice.confirmed_paid_amount-v_refunded));
  if v_amount<=0 then raise exception 'no refundable balance remains'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.customer_id,v_subscription.invoice_id,v_subscription.id,v_amount,concat_ws(' — ',p_reason_code,nullif(trim(p_reason_details),'')),p_reason_code,'requested',p_actor_user_id,jsonb_build_object('remaining_days',v_remaining_days,'daily_value',v_daily_value,'deferred_balance',v_subscription.deferred_balance,'confirmed_cash_available',greatest(0,v_invoice.confirmed_paid_amount-v_refunded)),p_recipient_method,trim(p_recipient_account_name),trim(p_recipient_account_reference),v_subscription.is_demo)
  returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,v_amount,v_subscription.is_demo);
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'refund_requested',jsonb_build_object('refund_id',v_refund_id,'amount',v_amount,'remaining_days',v_remaining_days,'daily_value',v_daily_value),p_actor_user_id,v_subscription.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'subscription_id',v_subscription.id,'amount',v_amount),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_subscription.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_subscription public.subscriptions; v_transaction_id uuid; v_new_deferred numeric(18,2); v_paid_before numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' or v_refund.invoice_id is null then raise exception 'approved invoice refund is required'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'refund payer must be different from requester'; end if;
  if nullif(trim(p_proof_reference),'') is null then raise exception 'refund payment proof is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.pay',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.pay and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  v_paid_before:=v_invoice.confirmed_paid_amount;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,v_invoice.currency,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.invoices set confirmed_paid_amount=greatest(0,confirmed_paid_amount-v_refund.amount),status=case when confirmed_paid_amount-v_refund.amount<=0 then 'refunded' else 'partially_paid' end,updated_at=now() where id=v_invoice.id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=trim(p_proof_reference),transaction_id=v_transaction_id where id=v_refund.id;
  insert into public.payment_allocations(organization_id,transaction_id,invoice_id,subscription_id,allocation_type,amount,allocated_by,is_demo)
  values(v_refund.organization_id,v_transaction_id,v_invoice.id,v_refund.subscription_id,'invoice',v_refund.amount,p_actor_user_id,v_refund.is_demo);
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,-least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(v_paid_before,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce join public.payment_transactions pt on pt.id=ce.source_transaction_id join public.payment_submissions ps on ps.id=pt.submission_id
  where ps.invoice_id=v_invoice.id and ce.entry_type='commission' and ce.status<>'reversed' on conflict do nothing;
  if v_refund.subscription_id is not null then
    select * into v_subscription from public.subscriptions where id=v_refund.subscription_id for update;
    v_new_deferred:=greatest(0,v_subscription.deferred_balance-least(v_refund.amount,v_subscription.deferred_balance));
    update public.subscriptions set deferred_balance=v_new_deferred,status='cancelled',ends_on=current_date,updated_at=now() where id=v_subscription.id;
    update public.planned_service_days set status='cancelled',operations_note=concat_ws(' · ',operations_note,'Cancelled after paid refund') where subscription_id=v_subscription.id and status in('planned','frozen','not_delivered','exception');
    insert into public.subscription_cancellations(subscription_id,details,requested_by,requested_at,approved_by,approved_at,status,is_demo)
    values(v_subscription.id,v_refund.reason,v_refund.requested_by,v_refund.requested_at,v_refund.approved_by,v_refund.approved_at,'completed',v_refund.is_demo);
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,refund_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,v_invoice.id,v_refund.id,'refund',-(v_subscription.deferred_balance-v_new_deferred),0,v_new_deferred,p_actor_user_id,'refund.deferred:'||v_refund.id::text,v_refund.is_demo);
    insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,'refund_paid',jsonb_build_object('refund_id',v_refund.id,'amount',v_refund.amount,'transaction_id',v_transaction_id),p_actor_user_id,v_refund.is_demo);
  end if;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('invoice_id',v_invoice.id,'transaction_id',v_transaction_id,'amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

drop view if exists public.daily_subscriber_list_v;
drop view if exists public.subscriber_operations_v;

create view public.subscriber_operations_v with(security_invoker=true) as
select s.id,s.organization_id,s.branch_id,s.subscription_number,s.status,s.starts_on,s.ends_on,s.purchased_service_days,s.delivered_service_days,
  greatest(0,s.purchased_service_days-s.delivered_service_days) as remaining_service_days,s.contract_value,s.deferred_balance,s.recognized_revenue,
  round(s.contract_value/nullif(s.purchased_service_days,0),2) as daily_value,s.daily_portions,s.operations_notes,
  c.id as customer_id,c.full_name as customer_name,c.mobile,p.name as package_name,p.program_code,p.meal_plan_code,
  a.address_line,a.area,a.city,a.latitude,a.longitude,a.gps_url,a.delivery_notes,a.delivery_window_start,a.delivery_window_end,
  z.id as zone_id,z.name as zone_name
from public.subscriptions s
join public.customers c on c.id=s.customer_id
join public.package_versions pv on pv.id=s.package_version_id
join public.packages p on p.id=pv.package_id
left join lateral(select ca.* from public.customer_addresses ca where ca.customer_id=c.id order by ca.is_primary desc,ca.id limit 1) a on true
left join public.delivery_zones z on z.id=a.zone_id;

create view public.daily_subscriber_list_v with(security_invoker=true) as
select d.id,d.service_date,d.status,d.branch_id,d.portion_multiplier,d.operations_note,d.meal_override,
  s.id as subscription_id,s.subscription_number,s.deferred_balance,s.daily_portions,c.id as customer_id,c.full_name as customer_name,c.mobile,
  p.name as package_name,p.program_code,p.meal_plan_code,a.address_line,a.area,a.gps_url,a.delivery_notes,a.delivery_window_start,a.delivery_window_end,z.name as zone_name,
  m.breakfast,m.lunch,m.dinner,m.snack_1,m.snack_2,m.delivery_note as menu_delivery_note
from public.planned_service_days d
join public.subscriptions s on s.id=d.subscription_id
join public.customers c on c.id=s.customer_id
join public.package_versions pv on pv.id=s.package_version_id
join public.packages p on p.id=pv.package_id
left join lateral(select ca.* from public.customer_addresses ca where ca.customer_id=c.id order by ca.is_primary desc,ca.id limit 1) a on true
left join public.delivery_zones z on z.id=a.zone_id
left join public.meal_menu_days m on m.organization_id=s.organization_id and m.day_number=extract(day from d.service_date)::integer and m.is_active;

revoke all on function public.create_customer_delivery_profile(uuid,text,text,text,text,text,text,numeric,numeric,text,uuid,text,time,time,text,text,uuid) from public;
revoke all on function public.freeze_subscription_period(uuid,date,date,text,uuid) from public;
revoke all on function public.apply_service_day_action(uuid[],text,integer,text,uuid) from public;
revoke all on function public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid) from public;
grant execute on function public.create_customer_delivery_profile(uuid,text,text,text,text,text,text,numeric,numeric,text,uuid,text,time,time,text,text,uuid) to authenticated;
grant execute on function public.freeze_subscription_period(uuid,date,date,text,uuid) to authenticated;
grant execute on function public.apply_service_day_action(uuid[],text,integer,text,uuid) to authenticated;
grant execute on function public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text)
language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=12,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.tasks'::regclass,'public.customers'::regclass,'public.payment_submissions'::regclass,'public.doctor_sessions'::regclass,'public.deferred_revenue_entries'::regclass,'public.delivery_zones'::regclass,'public.meal_menu_days'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=85,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs'
  union all select 'subscription_operations',to_regprocedure('public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid)') is not null,'Daily operations and calculated refunds';
$$;

insert into public.schema_versions(version,name) values(12,'subscription_operations_acceptance');
commit;

-- Eco Healthy ERP — subscription acceptance demo data.
-- Development/Staging only. Requires migration 0012 and completed /setup.
-- Every record created here is marked is_demo = true and can be removed safely.
begin;

do $$
declare
  v_org uuid; v_admin uuid; v_main uuid; v_second uuid; v_zone uuid; v_zone2 uuid;
  v_item record; v_package uuid; v_version uuid; v_customer uuid; v_invoice uuid; v_subscription uuid; v_day uuid;
  v_service_days integer; v_price numeric(18,2); v_daily numeric(18,2); v_delivered integer; v_status text; v_i integer;
  v_project uuid; v_task uuid;
begin
  select organization_id,installed_by into v_org,v_admin from public.system_installations order by installed_at limit 1;
  if v_org is null then raise exception 'Complete /setup before installing subscription demo data'; end if;
  select id into v_main from public.branches where organization_id=v_org and code='MAIN';
  if v_main is null then raise exception 'MAIN branch is required'; end if;
  select id into v_second from public.branches where organization_id=v_org and id<>v_main order by created_at limit 1;
  if v_second is null then
    insert into public.branches(organization_id,code,name,status,created_by,is_demo)
    values(v_org,'DEMO_SECOND','الفرع التجريبي الثاني','active',v_admin,true) returning id into v_second;
  end if;
  if exists(select 1 from public.packages where organization_id=v_org and code='WL-LUNCH-06') then
    raise exception 'Subscription acceptance demo already exists. Run 03_remove_demo_data.sql first.';
  end if;

  insert into public.delivery_zones(organization_id,branch_id,code,name,delivery_fee,sort_order,is_demo) values
  (v_org,v_main,'ZONE-1','Zone 1 — التجمع والرحاب',50,1,true),
  (v_org,v_main,'ZONE-2','Zone 2 — مدينة نصر ومصر الجديدة',60,2,true),
  (v_org,v_main,'ZONE-3','Zone 3 — المعادي والمقطم',70,3,true),
  (v_org,v_second,'ZONE-4','Zone 4 — الشيخ زايد وأكتوبر',80,4,true),
  (v_org,v_second,'ZONE-5','Zone 5 — الدقي والمهندسين',70,5,true),
  (v_org,v_second,'ZONE-6','Zone 6 — مناطق خاصة',100,6,true);
  select id into v_zone from public.delivery_zones where organization_id=v_org and code='ZONE-1';
  select id into v_zone2 from public.delivery_zones where organization_id=v_org and code='ZONE-4';

  insert into public.cancellation_reasons(organization_id,code,name,category,is_demo) values
  (v_org,'FOOD_QUALITY','جودة أوطعم الطعام غير مناسب','service',true),
  (v_org,'DELIVERY_TIME','وقت التوصيل غير مناسب','delivery',true),
  (v_org,'TRAVEL','العميل مسافر','personal',true),
  (v_org,'MEDICAL','سبب صحي أوتوصية طبية','medical',true),
  (v_org,'PRICE','السعر غير مناسب','commercial',true),
  (v_org,'MENU_VARIETY','تنوع المنيو غير مناسب','service',true),
  (v_org,'ADDRESS_CHANGE','تغيير السكن خارج نطاق التوصيل','delivery',true),
  (v_org,'DUPLICATE_PAYMENT','دفع مكرر','finance',true),
  (v_org,'SERVICE_PAUSE','إيقاف مؤقت بدل الإلغاء','retention',true),
  (v_org,'OTHER','سبب آخر موضح بالتفصيل','other',true)
  on conflict(organization_id,code) do update set name=excluded.name,category=excluded.category,is_active=true;

  -- Prices transcribed from the supplied Muscles Gain and Weight Loss tables.
  for v_item in select * from jsonb_to_recordset($prices$[
    {"code":"MG-LUNCH-06","name":"Muscles Gain — Lunch Meals — 6 Days","program":"muscles_gain","plan":"lunch","days":6,"meals":1,"price":2790},
    {"code":"MG-LUNCH-12","name":"Muscles Gain — Lunch Meals — 12 Days","program":"muscles_gain","plan":"lunch","days":12,"meals":1,"price":4993},
    {"code":"MG-LUNCH-18","name":"Muscles Gain — Lunch Meals — 18 Days","program":"muscles_gain","plan":"lunch","days":18,"meals":1,"price":5724},
    {"code":"MG-LUNCH-24","name":"Muscles Gain — Lunch Meals — 24 Days","program":"muscles_gain","plan":"lunch","days":24,"meals":1,"price":7128},
    {"code":"MG-AM-06","name":"Muscles Gain — AM Package — 6 Days","program":"muscles_gain","plan":"am","days":6,"meals":3,"price":3628},
    {"code":"MG-AM-12","name":"Muscles Gain — AM Package — 12 Days","program":"muscles_gain","plan":"am","days":12,"meals":3,"price":6388},
    {"code":"MG-AM-18","name":"Muscles Gain — AM Package — 18 Days","program":"muscles_gain","plan":"am","days":18,"meals":3,"price":7673},
    {"code":"MG-AM-24","name":"Muscles Gain — AM Package — 24 Days","program":"muscles_gain","plan":"am","days":24,"meals":3,"price":9600},
    {"code":"MG-PM-06","name":"Muscles Gain — PM Package — 6 Days","program":"muscles_gain","plan":"pm","days":6,"meals":3,"price":3640},
    {"code":"MG-PM-12","name":"Muscles Gain — PM Package — 12 Days","program":"muscles_gain","plan":"pm","days":12,"meals":3,"price":6551},
    {"code":"MG-PM-18","name":"Muscles Gain — PM Package — 18 Days","program":"muscles_gain","plan":"pm","days":18,"meals":3,"price":7838},
    {"code":"MG-PM-24","name":"Muscles Gain — PM Package — 24 Days","program":"muscles_gain","plan":"pm","days":24,"meals":3,"price":9783},
    {"code":"MG-FULL-06","name":"Muscles Gain — FullDay — 6 Days","program":"muscles_gain","plan":"full_day","days":6,"meals":5,"price":4478},
    {"code":"MG-FULL-12","name":"Muscles Gain — FullDay — 12 Days","program":"muscles_gain","plan":"full_day","days":12,"meals":5,"price":7946},
    {"code":"MG-FULL-18","name":"Muscles Gain — FullDay — 18 Days","program":"muscles_gain","plan":"full_day","days":18,"meals":5,"price":9787},
    {"code":"MG-FULL-24","name":"Muscles Gain — FullDay — 24 Days","program":"muscles_gain","plan":"full_day","days":24,"meals":5,"price":12255},
    {"code":"WL-LUNCH-06","name":"Weight Loss — Lunch Meals — 6 Days","program":"weight_loss","plan":"lunch","days":6,"meals":1,"price":2225},
    {"code":"WL-LUNCH-12","name":"Weight Loss — Lunch Meals — 12 Days","program":"weight_loss","plan":"lunch","days":12,"meals":1,"price":3266},
    {"code":"WL-LUNCH-18","name":"Weight Loss — Lunch Meals — 18 Days","program":"weight_loss","plan":"lunch","days":18,"meals":1,"price":4418},
    {"code":"WL-LUNCH-24","name":"Weight Loss — Lunch Meals — 24 Days","program":"weight_loss","plan":"lunch","days":24,"meals":1,"price":5305},
    {"code":"WL-AM-06","name":"Weight Loss — AM Package — 6 Days","program":"weight_loss","plan":"am","days":6,"meals":3,"price":3063},
    {"code":"WL-AM-12","name":"Weight Loss — AM Package — 12 Days","program":"weight_loss","plan":"am","days":12,"meals":3,"price":4661},
    {"code":"WL-AM-18","name":"Weight Loss — AM Package — 18 Days","program":"weight_loss","plan":"am","days":18,"meals":3,"price":6367},
    {"code":"WL-AM-24","name":"Weight Loss — AM Package — 24 Days","program":"weight_loss","plan":"am","days":24,"meals":3,"price":7777},
    {"code":"WL-PM-06","name":"Weight Loss — PM Package — 6 Days","program":"weight_loss","plan":"pm","days":6,"meals":3,"price":3075},
    {"code":"WL-PM-12","name":"Weight Loss — PM Package — 12 Days","program":"weight_loss","plan":"pm","days":12,"meals":3,"price":4824},
    {"code":"WL-PM-18","name":"Weight Loss — PM Package — 18 Days","program":"weight_loss","plan":"pm","days":18,"meals":3,"price":6531},
    {"code":"WL-PM-24","name":"Weight Loss — PM Package — 24 Days","program":"weight_loss","plan":"pm","days":24,"meals":3,"price":7960},
    {"code":"WL-FULL-06","name":"Weight Loss — FullDay — 6 Days","program":"weight_loss","plan":"full_day","days":6,"meals":5,"price":3913},
    {"code":"WL-FULL-12","name":"Weight Loss — FullDay — 12 Days","program":"weight_loss","plan":"full_day","days":12,"meals":5,"price":6219},
    {"code":"WL-FULL-18","name":"Weight Loss — FullDay — 18 Days","program":"weight_loss","plan":"full_day","days":18,"meals":5,"price":8480},
    {"code":"WL-FULL-24","name":"Weight Loss — FullDay — 24 Days","program":"weight_loss","plan":"full_day","days":24,"meals":5,"price":10432}
  ]$prices$::jsonb) as x(code text,name text,program text,plan text,days integer,meals integer,price numeric)
  loop
    insert into public.packages(organization_id,code,name,description,program_code,meal_plan_code,created_by,is_demo)
    values(v_org,v_item.code,v_item.name,'بيانات أسعار تجريبية من الجداول المعتمدة',v_item.program,v_item.plan,v_admin,true)
    returning id into v_package;
    insert into public.package_versions(package_id,version_number,effective_from,currency,price,service_days,meals_per_day,freeze_policy,cancellation_policy,status,created_by,is_demo)
    values(v_package,1,current_date,'EGP',v_item.price,v_item.days,v_item.meals,jsonb_build_object('replacement_days',true,'meal_plan',v_item.plan),jsonb_build_object('refund_basis','remaining_service_days'), 'active',v_admin,true);
  end loop;

  insert into public.meal_menu_days(organization_id,day_number,breakfast,lunch,dinner,snack_1,snack_2,delivery_note,is_demo) values
  (v_org,1,'Omelet and Cheese','Chicken Texas','Beef Burger','Chocolate Cookies','Canned Juice',null,true),
  (v_org,2,'Turkish Wrap','Chicken Burger','Texas Roll','Coconut Muffin','Nuts',null,true),
  (v_org,3,'Cheese Toast with Zaatar','Chicken Cordon Bleu','Crispy Chicken Twister','Chocolate Muffin','Fruits',null,true),
  (v_org,4,'Tuna Sandwich','Beef Stroganoff','Chicken Kofta Sandwich','Potato Muffin','Canned Juice',null,true),
  (v_org,5,'Creamy Toast','Beef Balls with Brown Sauce','BBQ Chicken Sandwich','Cinnamon Cookies','Nuts',null,true),
  (v_org,6,'Yogurt Granola','Grilled Salmon','Beef Fajita Roll','Banana Cake','Fruits',null,true),
  (v_org,7,'Boiled Eggs','Chicken Alfredo','Chicken Hawawshi','Pancakes','Canned Juice',null,true),
  (v_org,8,'Turkish Sandwich','Shish Tawook','Chicken Burger Wrap','Chocolate Cookies','Nuts',null,true),
  (v_org,9,'Egg and Arugula Sandwich','Chicken Ranch','Grilled Chicken Roll','Coconut Muffin','Fruits',null,true),
  (v_org,10,'Creamy Toast','Beef Kofta','Beef Kofta Sandwich','Chocolate Muffin','Canned Juice',null,true),
  (v_org,11,'Omelet and Cheese','Mongolian Beef','Texas Sandwich','Potato Muffin','Nuts',null,true),
  (v_org,12,'Turkish Wrap','Grilled Fish','Beef Hawawshi','Cinnamon Cookies','Fruits',null,true),
  (v_org,13,'Cheese Toast with Zaatar','Chicken Sweet and Sour','Fajita Roll','Banana Cake','Canned Juice',null,true),
  (v_org,14,'Tuna Sandwich','Chicken Balls Piccata','Chicken Burger Wrap','Pancakes','Nuts',null,true),
  (v_org,15,'Creamy Toast','Chicken Pie','Crispy Chicken Twister','Chocolate Cookies','Fruits',null,true),
  (v_org,16,'Yogurt Granola','Beef Burger','Grilled Chicken Roll','Coconut Muffin','Canned Juice',null,true),
  (v_org,17,'Boiled Eggs','Pomegranate Molasses Kofta','Beef Burger Wrap','Chocolate Muffin','Nuts',null,true),
  (v_org,18,'Turkish Wrap','Creamy Lemon Salmon','Chicken Hawawshi','Potato Muffin','Fruits',null,true),
  (v_org,19,'Egg and Arugula Sandwich','Grilled Chicken','Texas Roll','Cinnamon Cookies','Canned Juice',null,true),
  (v_org,20,'Creamy Toast','Chicken Burger','Chicken Kofta Sandwich','Banana Cake','Nuts',null,true),
  (v_org,21,'Omelet and Cheese','Mix Grill','Fajita Roll','Pancakes','Fruits',null,true),
  (v_org,22,'Tuna Sandwich','Kabab Halla','Beef Burger Sandwich','Chocolate Cookies','Canned Juice',null,true),
  (v_org,23,'Yogurt Granola','Beef Balls with Brown Sauce','Beef Hawawshi','Coconut Muffin','Nuts',null,true),
  (v_org,24,'Boiled Eggs','Green Sauce Fish','Crispy Chicken Twister','Chocolate Muffin','Fruits',null,true),
  (v_org,25,'Turkish Wrap','Smoky Grilled Chicken','Chicken Burger Wrap','Potato Muffin','Canned Juice',null,true),
  (v_org,26,'Cheese Toast with Zaatar','Grilled Chicken','Grilled Chicken Roll','Cinnamon Cookies','Nuts',null,true),
  (v_org,27,'Creamy Toast','Chicken Curry','Texas Sandwich','Banana Cake','Fruits',null,true),
  (v_org,28,'Omelet and Cheese','Beef Pie','Beef Burger Wrap','Pancakes','Canned Juice',null,true),
  (v_org,29,'Egg and Arugula Sandwich','Grilled Liver with Pesto','Fajita Roll','Chocolate Cookies','Nuts',null,true),
  (v_org,30,'Yogurt Granola','Chicken Piccata','Chicken Hawawshi','Coconut Muffin','Fruits',null,true),
  (v_org,31,'Tuna Sandwich','Grilled Fish','Chicken Burger Sandwich','Chocolate Muffin','Canned Juice','الجمعة إجازة؛ تُرسل وجبات الجمعة مع الخميس حسب سياسة التشغيل',true);

  -- Twelve realistic subscribers, each with a paid invoice, address/GPS and a different operational state.
  for v_i in 1..12 loop
    select pv.id,pv.service_days,pv.price into v_version,v_service_days,v_price
    from public.package_versions pv join public.packages p on p.id=pv.package_id
    where p.organization_id=v_org and p.is_demo and p.code in('WL-LUNCH-06','WL-AM-12','WL-PM-18','WL-FULL-24','MG-LUNCH-12','MG-AM-18','MG-PM-24','MG-FULL-06')
    order by p.code offset ((v_i-1)%8) limit 1;
    v_delivered:=least(v_service_days-1,(v_i-1)%5);
    v_daily:=round(v_price/v_service_days,2);
    v_status:=case when v_i=3 then 'frozen' when v_i=11 then 'cancelled' when v_i=12 then 'completed' else 'active' end;
    insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,owner_user_id,created_by,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,'مشترك تجريبي '||lpad(v_i::text,2,'0'),'01090000'||lpad(v_i::text,3,'0'),'subscriber'||v_i||'.demo@example.com','active',v_admin,v_admin,true)
    returning id into v_customer;
    insert into public.customer_addresses(customer_id,label,address_line,area,city,latitude,longitude,delivery_notes,is_primary,zone_id,gps_url,delivery_contact_name,delivery_contact_mobile,delivery_window_start,delivery_window_end,delivery_time_confirmed,is_demo)
    values(v_customer,'المنزل','عمارة '||v_i||'، شارع تجريبي، شقة '||(v_i+2),case when v_i in(6,7,8) then 'الشيخ زايد' else 'التجمع الخامس' end,'القاهرة',30.00+v_i/1000.0,31.20+v_i/1000.0,case when v_i%3=0 then 'الاتصال قبل الوصول وعدم إضافة صوص حار' else 'التسليم على باب الشقة' end,true,case when v_i in(6,7,8) then v_zone2 else v_zone end,'https://maps.google.com/?q='||(30.00+v_i/1000.0)||','||(31.20+v_i/1000.0),'مشترك تجريبي '||v_i,'01090000'||lpad(v_i::text,3,'0'),('10:00'::time+(v_i%4)*interval '1 hour')::time,('12:00'::time+(v_i%4)*interval '1 hour')::time,true,true);
    insert into public.invoices(organization_id,branch_id,customer_id,status,total_amount,confirmed_paid_amount,created_by,issued_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,'paid',v_price,v_price,v_admin,now()-((v_i+2)||' days')::interval,true) returning id into v_invoice;
    insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,source_snapshot,is_demo)
    select v_invoice,v_version,p.name,1,v_price,v_price,jsonb_build_object('demo',true,'package_version_id',v_version),true from public.package_versions pv join public.packages p on p.id=pv.package_id where pv.id=v_version;
    insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,confirmed_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,'collection',v_price,'EGP',v_admin,'acceptance-demo-collection-'||v_i,now()-((v_i+1)||' days')::interval,true);
    insert into public.subscriptions(organization_id,branch_id,customer_id,invoice_id,package_version_id,status,starts_on,ends_on,purchased_service_days,delivered_service_days,contract_value,deferred_balance,recognized_revenue,daily_portions,operations_notes,meal_override,activated_by,activated_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,v_invoice,v_version,v_status,current_date-v_delivered,current_date-v_delivered+v_service_days-1,v_service_days,case when v_status='completed' then v_service_days else v_delivered end,v_price,case when v_status='completed' then 0 else greatest(0,v_price-v_daily*v_delivered) end,case when v_status='completed' then v_price else least(v_price,v_daily*v_delivered) end,case when v_i=4 then 2 else 1 end,case when v_i=2 then 'بدون بصل — مراجعة المطبخ' when v_i=4 then 'حصتان اليوم للعميل وزوجته' when v_i=9 then 'حساسية مكسرات — بيانات تجريبية' else null end,case when v_i=9 then '{"exclude":["Nuts"],"replacement":"Fruits"}'::jsonb else '{}'::jsonb end,v_admin,now()-((v_i+1)||' days')::interval,true)
    returning id into v_subscription;
    if v_status<>'completed' then
      insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,meal_override,is_demo)
      select v_subscription,current_date-v_delivered+g,
        case when g<v_delivered then 'confirmed_delivered' when v_status='cancelled' then 'cancelled' when v_status='frozen' and g=v_delivered then 'frozen' else 'planned' end,
        case when v_i in(6,7,8) then v_second else v_main end,case when v_i=4 and g=v_delivered then 2 else 1 end,
        case when v_i=2 then 'بدون بصل' when v_i=4 and g=v_delivered then 'حصتان اليوم' else null end,
        case when v_i=9 then '{"exclude":["Nuts"],"replacement":"Fruits"}'::jsonb else '{}'::jsonb end,true
      from generate_series(0,v_service_days-1) g;
    end if;
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_subscription,v_invoice,'activation',v_price,0,v_price,v_admin,'acceptance-demo-activation-'||v_i,true);
    if v_i=3 then
      insert into public.subscription_freezes(subscription_id,starts_on,ends_on,reason,status,approved_by,is_demo) values(v_subscription,current_date,current_date+2,'سفر قصير — تجريبي','approved',v_admin,true);
    end if;
    if v_i=10 then
      insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,is_demo)
      values(v_org,v_main,v_customer,v_invoice,v_subscription,least(v_price-v_daily*v_delivered,v_daily*(v_service_days-v_delivered)),'وقت التوصيل غير مناسب','DELIVERY_TIME','requested',v_admin,jsonb_build_object('remaining_days',v_service_days-v_delivered,'daily_value',v_daily),'instapay','مشترك تجريبي 10','01090000010',true);
    end if;
  end loop;

  -- One pending payment proves that payment proof is not confirmed cash.
  select id into v_customer from public.customers where organization_id=v_org and mobile='01090000001';
  select pv.id,pv.price into v_version,v_price from public.package_versions pv join public.packages p on p.id=pv.package_id where p.organization_id=v_org and p.code='WL-LUNCH-06';
  insert into public.invoices(organization_id,branch_id,customer_id,status,total_amount,confirmed_paid_amount,created_by,is_demo)
  values(v_org,v_main,v_customer,'issued',v_price,0,v_admin,true) returning id into v_invoice;
  insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,is_demo) values(v_invoice,v_version,'Weight Loss — Lunch Meals — 6 Days',1,v_price,v_price,true);
  insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,payment_method,proof_reference,external_reference,status,submitted_by,is_demo)
  values(v_org,v_main,v_customer,v_invoice,v_price,'instapay','demo/payment-pending-proof.jpg','ACCEPTANCE-PENDING-001','pending',v_admin,true);

  insert into public.projects(organization_id,branch_id,name,description,owner_user_id,status,priority,is_strategic,starts_on,due_on,progress_percent,created_by,is_demo)
  values(v_org,v_main,'تشغيل الاشتراكات الصباحية — Demo','مشروع قبول تشغيلي لتوزيع مهام المبيعات والمالية والعمليات',v_admin,'active','high',true,current_date,current_date+14,45,v_admin,true)
  returning id into v_project;
  for v_i in 1..8 loop
    insert into public.tasks(organization_id,branch_id,project_id,title,detailed_description,task_type,related_entity_type,created_by,reviewer_user_id,priority,status,start_at,due_at,open_until_response,response_required,evidence_required,reviewer_approval_required,required_action,is_demo)
    values(v_org,v_main,v_project,(array['متابعة إثبات دفع مع العميل','مراجعة طلب Refund','تأكيد قائمة إنتاج اليوم','اتصال بتجديد قريب','مراجعة عنوان وGPS','اعتماد Skip اليوم','حل شكوى وقت التوصيل','تجهيز تقرير الاشتراكات'])[v_i],'مهمة تجريبية قابلة للتنفيذ والمراجعة داخل النظام',(array['customer_followup','refund','subscription','customer_followup','task','approval_request','complaint','internal_action'])[v_i],'subscription',v_admin,v_admin,case when v_i in(2,7) then 'high' else 'normal' end,case when v_i=6 then 'waiting_for_approval' when v_i=7 then 'blocked' else 'assigned' end,now(),case when v_i=8 then null else now()+(v_i||' hours')::interval end,v_i=4,true,v_i in(2,3),v_i in(2,6),case when v_i=3 then 'إرفاق كشف الإنتاج بعد التأكيد' else 'تنفيذ الإجراء وتسجيل الرد الرسمي' end,true)
    returning id into v_task;
    insert into public.task_assignments(organization_id,task_id,assignee_type,assignee_user_id,assigned_by,is_demo) values(v_org,v_task,'user',v_admin,v_admin,true);
    insert into public.task_activities(organization_id,task_id,activity_type,actor_user_id,details,is_demo) values(v_org,v_task,'assigned',v_admin,jsonb_build_object('demo',true),true);
  end loop;
end $$;

commit;

select 'Subscription acceptance demo installed: 32 price options, 31 menu days, 12 subscribers, queues and tasks.' as result;

-- Every row below must show passed = true.
select * from public.validate_eco_healthy_installation();
