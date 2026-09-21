begin;

-- V13: operational usability, canonical Egyptian mobile identity, and the
-- approved cancellation/refund policy. No demo rows are created here.

create or replace function public.normalize_egypt_mobile(p_value text)
returns text language plpgsql immutable set search_path='' as $$
declare v_digits text;
begin
  v_digits := regexp_replace(coalesce(p_value,''), '[^0-9]', '', 'g');
  if v_digits like '0020%' then v_digits := substring(v_digits from 5); end if;
  if v_digits like '20%' and length(v_digits)=12 then v_digits := substring(v_digits from 3); end if;
  if v_digits like '1%' and length(v_digits)=10 then v_digits := '0'||v_digits; end if;
  if v_digits ~ '^01(0|1|2|5)[0-9]{8}$' then return v_digits; end if;
  return null;
end; $$;

alter table public.customers add column mobile_normalized text;

with normalized as (
  select id,public.normalize_egypt_mobile(mobile) as normalized_mobile,
    row_number() over(partition by organization_id,public.normalize_egypt_mobile(mobile) order by created_at,id) as duplicate_rank
  from public.customers where mobile is not null and public.normalize_egypt_mobile(mobile) is not null
)
update public.customers c
set mobile_normalized=case when n.duplicate_rank=1 then n.normalized_mobile else null end
from normalized n where n.id=c.id;

drop index if exists public.customers_org_mobile_uidx;
create unique index customers_org_mobile_normalized_uidx
on public.customers(organization_id,mobile_normalized) where mobile_normalized is not null;

create or replace function public.enforce_customer_mobile_identity()
returns trigger language plpgsql set search_path='' as $$
declare v_normalized text;
begin
  if nullif(trim(new.mobile),'') is null then
    new.mobile:=null; new.mobile_normalized:=null; return new;
  end if;
  v_normalized:=public.normalize_egypt_mobile(new.mobile);
  if v_normalized is null then raise exception 'valid Egyptian mobile is required (010/011/012/015 + 8 digits)'; end if;
  new.mobile:=v_normalized;
  new.mobile_normalized:=v_normalized;
  return new;
end; $$;

create trigger enforce_customer_mobile_identity
before insert or update of mobile on public.customers
for each row execute function public.enforce_customer_mobile_identity();

create or replace function public.create_customer_quotation(
  p_branch_id uuid,p_customer_name text,p_mobile text,p_package_version_id uuid,
  p_quantity numeric,p_discount_percent numeric,p_valid_until date,p_notes text,p_actor_user_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_package public.packages; v_version public.package_versions; v_customer_id uuid; v_quote_id uuid;
  v_subtotal numeric(18,2); v_discount numeric(18,2); v_limit numeric(5,2); v_mobile text;
begin
  select b.organization_id into v_org from public.branches b where b.id=p_branch_id and b.status='active';
  if v_org is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_org) or not public.can_access_branch(v_org,p_branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  v_mobile:=public.normalize_egypt_mobile(p_mobile);
  if nullif(trim(p_customer_name),'') is null or v_mobile is null or p_quantity<=0 or p_discount_percent not between 0 and 100 then raise exception 'customer name, valid unique mobile and quotation values are required'; end if;
  select pv.* into v_version from public.package_versions pv join public.packages p on p.id=pv.package_id
  where pv.id=p_package_version_id and p.organization_id=v_org and p.status='active' and pv.status='active'
    and pv.effective_from<=current_date and (pv.effective_to is null or pv.effective_to>=current_date);
  if v_version.id is null then raise exception 'package version is not available for this organization'; end if;
  select p.* into v_package from public.packages p where p.id=v_version.package_id;
  select coalesce(max(dl.maximum_percent),case when public.has_permission('catalog.manage',v_org) then 100 else 0 end) into v_limit
  from public.discount_limits dl
  where dl.organization_id=v_org and dl.effective_from<=current_date and (dl.effective_to is null or dl.effective_to>=current_date)
    and (dl.user_id=p_actor_user_id or dl.role_id in(select ur.role_id from public.user_roles ur where ur.organization_id=v_org and ur.user_id=p_actor_user_id and ur.valid_from<=now() and (ur.valid_until is null or ur.valid_until>now())));
  if p_discount_percent>coalesce(v_limit,0) then raise exception 'discount exceeds authorized limit'; end if;
  v_subtotal:=round(p_quantity*v_version.price,2); v_discount:=round(v_subtotal*p_discount_percent/100,2);
  select c.id into v_customer_id from public.customers c where c.organization_id=v_org and c.mobile_normalized=v_mobile order by c.created_at limit 1;
  if v_customer_id is null then
    insert into public.customers(organization_id,home_branch_id,full_name,mobile,status,owner_user_id,created_by)
    values(v_org,p_branch_id,trim(p_customer_name),v_mobile,'active',p_actor_user_id,p_actor_user_id) returning id into v_customer_id;
  end if;
  insert into public.quotations(organization_id,branch_id,customer_id,status,currency,subtotal,discount_amount,valid_until,notes,created_by)
  values(v_org,p_branch_id,v_customer_id,'issued',v_version.currency,v_subtotal,v_discount,p_valid_until,p_notes,p_actor_user_id) returning id into v_quote_id;
  insert into public.quotation_lines(quotation_id,package_version_id,description,quantity,unit_price,discount_percent,price_snapshot)
  values(v_quote_id,v_version.id,v_package.name,p_quantity,v_version.price,p_discount_percent,jsonb_build_object('package_id',v_package.id,'package_version_id',v_version.id,'version_number',v_version.version_number,'unit_price',v_version.price,'currency',v_version.currency));
  perform public.enqueue_domain_event(v_org,p_branch_id,'quotation.created','quotation',v_quote_id,jsonb_build_object('customer_id',v_customer_id,'package_version_id',v_version.id,'total',v_subtotal-v_discount),p_actor_user_id,'quotation.created:'||v_quote_id::text,false);
  return jsonb_build_object('customer_id',v_customer_id,'quotation_id',v_quote_id,'customer_reused',exists(select 1 from public.customers c where c.id=v_customer_id and c.created_at<now()-interval '1 second'));
end; $$;

alter table public.refunds add column policy_mode text not null default 'legacy' check(policy_mode in('legacy','early_six_day','finance_review'));
alter table public.refunds add column consumed_service_days integer not null default 0 check(consumed_service_days>=0);
alter table public.refunds add column deduction_amount numeric(18,2) not null default 0 check(deduction_amount>=0);
alter table public.refunds add column finance_decision_reason text;
alter table public.refunds add column refund_due_on date;

create or replace function public.request_calculated_subscription_refund(
  p_subscription_id uuid,p_reason_code text,p_reason_details text,p_recipient_method text,p_recipient_account_name text,p_recipient_account_reference text,p_actor_user_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_subscription public.subscriptions; v_invoice public.invoices; v_refund_id uuid; v_consumed integer; v_deduction numeric(18,2); v_amount numeric(18,2); v_refunded numeric(18,2); v_cash numeric(18,2); v_policy text;
begin
  select * into v_subscription from public.subscriptions where id=p_subscription_id for update;
  if v_subscription.id is null or v_subscription.status not in('active','frozen') then raise exception 'active or frozen subscription is required'; end if;
  select * into v_invoice from public.invoices where id=v_subscription.invoice_id for update;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  if nullif(trim(p_reason_code),'') is null then raise exception 'refund reason is required'; end if;
  if p_recipient_method not in('instapay','mobile_wallet','bank_transfer') or nullif(trim(p_recipient_account_name),'') is null or nullif(trim(p_recipient_account_reference),'') is null then raise exception 'bank, InstaPay or mobile-wallet recipient details are required'; end if;
  select count(*) into v_consumed from public.planned_service_days where subscription_id=v_subscription.id and status='confirmed_delivered';
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and status in('approved','paid');
  v_cash:=greatest(0,v_invoice.confirmed_paid_amount-v_refunded);
  if v_cash<=0 then raise exception 'no refundable confirmed cash remains'; end if;
  if current_date < v_subscription.starts_on+6 then
    v_policy:='early_six_day'; v_deduction:=v_consumed*600; v_amount:=greatest(0,v_cash-v_deduction);
  else
    v_policy:='finance_review'; v_deduction:=0; v_amount:=v_cash;
  end if;
  if v_amount<=0 then raise exception 'consumed-day deduction leaves no refundable amount'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,policy_mode,consumed_service_days,deduction_amount,refund_due_on,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.customer_id,v_subscription.invoice_id,v_subscription.id,v_amount,concat_ws(' — ',p_reason_code,nullif(trim(p_reason_details),'')),p_reason_code,'requested',p_actor_user_id,jsonb_build_object('policy_mode',v_policy,'consumed_service_days',v_consumed,'consumed_day_rate',case when v_policy='early_six_day' then 600 else null end,'confirmed_cash_available',v_cash,'finance_review_required',v_policy='finance_review'),p_recipient_method,trim(p_recipient_account_name),trim(p_recipient_account_reference),v_policy,v_consumed,v_deduction,current_date+14,v_subscription.is_demo)
  returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,v_amount,v_subscription.is_demo);
  insert into public.subscription_operation_events(organization_id,branch_id,subscription_id,event_type,details,actor_user_id,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,'refund_requested',jsonb_build_object('refund_id',v_refund_id,'amount',v_amount,'policy_mode',v_policy,'consumed_days',v_consumed,'deduction',v_deduction),p_actor_user_id,v_subscription.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'subscription_id',v_subscription.id,'amount',v_amount,'policy_mode',v_policy),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_subscription.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.approve_subscription_refund_policy(p_refund_id uuid,p_approved_deduction numeric,p_reason text,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_refunded numeric(18,2); v_cash numeric(18,2); v_deduction numeric(18,2); v_amount numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status not in('requested','under_review') then raise exception 'refund is not approvable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot approve own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  select coalesce(sum(amount),0) into v_refunded from public.refunds where invoice_id=v_invoice.id and id<>v_refund.id and status in('approved','paid');
  v_cash:=greatest(0,v_invoice.confirmed_paid_amount-v_refunded);
  if v_refund.policy_mode='finance_review' then
    if p_approved_deduction is null or p_approved_deduction<0 or p_approved_deduction>=v_cash or nullif(trim(p_reason),'') is null then raise exception 'finance deduction and decision reason are required'; end if;
    v_deduction:=p_approved_deduction;
  else
    v_deduction:=v_refund.deduction_amount;
  end if;
  v_amount:=v_cash-v_deduction;
  if v_amount<=0 then raise exception 'approved deduction leaves no refundable amount'; end if;
  update public.refunds set amount=v_amount,deduction_amount=v_deduction,finance_decision_reason=coalesce(nullif(trim(p_reason),''),'Early cancellation: EGP 600 per confirmed delivered day'),status='approved',approved_by=p_actor_user_id,approved_at=now(),calculation_basis=calculation_basis||jsonb_build_object('approved_deduction',v_deduction,'approved_refund',v_amount,'approved_by',p_actor_user_id) where id=v_refund.id;
  update public.approval_requests set status='approved',decided_by=p_actor_user_id,decided_at=now(),decision_reason=coalesce(nullif(trim(p_reason),''),'Automatic early-six-day policy') where entity_type='refund' and entity_id=v_refund.id and status='pending';
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.approved','refund',v_refund.id,jsonb_build_object('invoice_id',v_refund.invoice_id,'amount',v_amount,'deduction',v_deduction,'policy_mode',v_refund.policy_mode),p_actor_user_id,'refund.approved:'||v_refund.id::text,v_refund.is_demo);
end; $$;

revoke all on function public.normalize_egypt_mobile(text) from public;
grant execute on function public.normalize_egypt_mobile(text) to authenticated;
revoke all on function public.approve_subscription_refund_policy(uuid,numeric,text,uuid) from public;
grant execute on function public.approve_subscription_refund_policy(uuid,numeric,text,uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text) language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=13,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.customers'::regclass,'public.tasks'::regclass,'public.invoices'::regclass,'public.refunds'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=85,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs'
  union all select 'subscription_operations',to_regprocedure('public.request_calculated_subscription_refund(uuid,text,text,text,text,text,uuid)') is not null,'Daily operations and calculated refunds'
  union all select 'mobile_identity',to_regprocedure('public.normalize_egypt_mobile(text)') is not null,'Canonical Egyptian mobile uniqueness'
  union all select 'refund_policy_v13',to_regprocedure('public.approve_subscription_refund_policy(uuid,numeric,text,uuid)') is not null,'Six-day cancellation and Finance review policy';
$$;

insert into public.schema_versions(version,name)
values(13,'operational_usability_refund_policy');

commit;
