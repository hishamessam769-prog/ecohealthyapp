begin;

insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='refunds.request'
where r.code in('sales_manager','customer_service','finance_accountant')
on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code='customers.view'
where r.code in('finance_manager','finance_accountant','operations_manager')
on conflict do nothing;

-- The operational sales cycle is server-governed. Every public RPC below derives
-- organization, branch and customer from the selected record instead of trusting
-- browser-supplied scope fields.

alter table public.planned_service_days drop constraint if exists planned_service_days_status_check;
alter table public.planned_service_days add constraint planned_service_days_status_check
  check(status in('planned','frozen','cancelled','not_delivered','exception','delivered_pending_confirmation','confirmed_delivered'));

alter table public.invoices add constraint invoices_scope_identity_unique
  unique(id,organization_id,branch_id,customer_id);
alter table public.payment_submissions alter column invoice_id set not null;
alter table public.payment_submissions add constraint payment_submission_invoice_scope_fk
  foreign key(invoice_id,organization_id,branch_id,customer_id)
  references public.invoices(id,organization_id,branch_id,customer_id);
create unique index invoices_one_per_quotation_uidx on public.invoices(quotation_id) where quotation_id is not null;
create unique index subscriptions_invoice_package_uidx on public.subscriptions(invoice_id,package_version_id);

alter table public.refunds add column invoice_id uuid references public.invoices(id);
alter table public.refunds add column transaction_id uuid references public.payment_transactions(id);

drop policy if exists invoices_scope on public.invoices;
drop policy if exists invoices_insert on public.invoices;
create policy invoices_scope on public.invoices for select to authenticated using(
  (public.has_permission('sales.invoice',organization_id) or public.has_permission('payments.review',organization_id)
   or public.has_permission('subscriptions.manage',organization_id) or public.has_permission('refunds.request',organization_id))
  and public.can_access_branch(organization_id,branch_id)
);
drop policy if exists invoice_lines_scope on public.invoice_lines;
drop policy if exists invoice_lines_manage on public.invoice_lines;
create policy invoice_lines_scope on public.invoice_lines for select to authenticated using(exists(
  select 1 from public.invoices i where i.id=invoice_id
));
drop policy if exists quotations_scope on public.quotations;
create policy quotations_select_scope on public.quotations for select to authenticated using(
  public.has_permission('sales.quote',organization_id) and public.can_access_branch(organization_id,branch_id)
);
drop policy if exists payment_submissions_insert on public.payment_submissions;
drop policy if exists subscriptions_manage on public.subscriptions;
drop policy if exists refunds_insert on public.refunds;

create table public.sales_target_actuals(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  target_id uuid not null references public.sales_targets(id) on delete cascade,
  payment_transaction_id uuid not null references public.payment_transactions(id),
  salesperson_user_id uuid not null references public.profiles(id),
  amount numeric(18,2) not null check(amount>0),
  occurred_on date not null,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(target_id,payment_transaction_id)
);

create table public.deferred_revenue_entries(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id),
  delivery_confirmation_id uuid references public.service_delivery_confirmations(id),
  refund_id uuid references public.refunds(id),
  entry_type text not null check(entry_type in('activation','recognition','refund','reversal','adjustment')),
  deferred_delta numeric(18,2) not null,
  recognized_delta numeric(18,2) not null default 0,
  balance_after numeric(18,2) not null check(balance_after>=0),
  created_by uuid not null references public.profiles(id),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  unique(organization_id,idempotency_key)
);

create index sales_target_actuals_scope_idx on public.sales_target_actuals(organization_id,branch_id,occurred_on);
create index deferred_revenue_entries_subscription_idx on public.deferred_revenue_entries(subscription_id,created_at);

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path='' set row_security=off as $$
declare old_json jsonb:=case when tg_op in('UPDATE','DELETE') then to_jsonb(old) else null end;
  new_json jsonb:=case when tg_op in('INSERT','UPDATE') then to_jsonb(new) else null end;
  source_json jsonb:=coalesce(new_json,old_json,'{}'::jsonb); v_org_id uuid; v_entity_id uuid; v_actor uuid;
  v_is_demo boolean:=coalesce((source_json->>'is_demo')::boolean,false); v_subscription_id uuid;
begin
  v_org_id:=case when tg_table_name='organizations' then nullif(source_json->>'id','')::uuid else nullif(source_json->>'organization_id','')::uuid end;
  if v_org_id is null and nullif(source_json->>'subscription_id','') is not null then
    v_subscription_id:=nullif(source_json->>'subscription_id','')::uuid;
    select s.organization_id into v_org_id from public.subscriptions s where s.id=v_subscription_id;
  end if;
  v_entity_id:=nullif(source_json->>'id','')::uuid;
  v_actor:=coalesce(auth.uid(),nullif(source_json->>'updated_by','')::uuid,nullif(source_json->>'created_by','')::uuid,
    nullif(source_json->>'submitted_by','')::uuid,nullif(source_json->>'reviewed_by','')::uuid,nullif(source_json->>'confirmed_by','')::uuid,
    nullif(source_json->>'allocated_by','')::uuid,nullif(source_json->>'activated_by','')::uuid,nullif(source_json->>'requested_by','')::uuid,
    nullif(source_json->>'approved_by','')::uuid,nullif(source_json->>'paid_by','')::uuid,nullif(source_json->>'assigned_by','')::uuid,
    nullif(source_json->>'granted_by','')::uuid,nullif(source_json->>'invited_by','')::uuid);
  insert into public.audit_logs(organization_id,actor_user_id,action,entity_type,entity_id,old_values,new_values,request_id,is_demo)
  values(v_org_id,v_actor,lower(tg_op),tg_table_name,v_entity_id,old_json,new_json,nullif(current_setting('request.headers',true),'')::jsonb->>'x-request-id',v_is_demo);
  if tg_op='DELETE' then return old; end if; return new;
end; $$;

create trigger audit_payment_allocations after insert or update or delete on public.payment_allocations for each row execute function public.audit_row_change();
create trigger audit_planned_service_days after insert or update or delete on public.planned_service_days for each row execute function public.audit_row_change();
create trigger audit_revenue_entries after insert or update or delete on public.revenue_entries for each row execute function public.audit_row_change();
create trigger audit_target_actuals after insert or update or delete on public.sales_target_actuals for each row execute function public.audit_row_change();
create trigger audit_deferred_revenue after insert or update or delete on public.deferred_revenue_entries for each row execute function public.audit_row_change();

create or replace function public.capture_sales_target_actual()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_salesperson uuid; v_invoice_id uuid;
begin
  if new.transaction_type<>'collection' or new.amount<=0 or new.submission_id is null then return new; end if;
  select i.id,q.created_by into v_invoice_id,v_salesperson
  from public.payment_submissions ps
  join public.invoices i on i.id=ps.invoice_id
  join public.quotations q on q.id=i.quotation_id
  where ps.id=new.submission_id;
  if v_salesperson is null then return new; end if;
  insert into public.sales_target_actuals(organization_id,branch_id,target_id,payment_transaction_id,salesperson_user_id,amount,occurred_on,is_demo)
  select new.organization_id,new.branch_id,t.id,new.id,v_salesperson,new.amount,new.confirmed_at::date,new.is_demo
  from public.sales_targets t
  where t.organization_id=new.organization_id
    and (t.branch_id is null or t.branch_id=new.branch_id)
    and new.confirmed_at::date between t.period_start and t.period_end
    and ((t.target_type='user' and t.user_id=v_salesperson) or
      (t.target_type='team' and exists(select 1 from public.team_members tm where tm.team_id=t.team_id and tm.user_id=v_salesperson and tm.joined_at<=new.confirmed_at::date and (tm.left_at is null or tm.left_at>=new.confirmed_at::date))))
  on conflict(target_id,payment_transaction_id) do nothing;
  return new;
end; $$;
create trigger payment_transaction_target_actual after insert on public.payment_transactions
for each row execute function public.capture_sales_target_actual();

create or replace function public.create_customer_quotation(
  p_branch_id uuid,p_customer_name text,p_mobile text,p_package_version_id uuid,
  p_quantity numeric,p_discount_percent numeric,p_valid_until date,p_notes text,p_actor_user_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_package public.packages; v_version public.package_versions; v_customer_id uuid; v_quote_id uuid;
  v_subtotal numeric(18,2); v_discount numeric(18,2); v_limit numeric(5,2);
begin
  select b.organization_id into v_org from public.branches b where b.id=p_branch_id and b.status='active';
  if v_org is null then raise exception 'active branch is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_org) or not public.can_access_branch(v_org,p_branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  if nullif(trim(p_customer_name),'') is null or p_quantity<=0 or p_discount_percent not between 0 and 100 then raise exception 'invalid quotation input'; end if;
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
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,status,owner_user_id,created_by)
  values(v_org,p_branch_id,trim(p_customer_name),nullif(trim(p_mobile),''),'active',p_actor_user_id,p_actor_user_id) returning id into v_customer_id;
  insert into public.quotations(organization_id,branch_id,customer_id,status,currency,subtotal,discount_amount,valid_until,notes,created_by)
  values(v_org,p_branch_id,v_customer_id,'issued',v_version.currency,v_subtotal,v_discount,p_valid_until,p_notes,p_actor_user_id) returning id into v_quote_id;
  insert into public.quotation_lines(quotation_id,package_version_id,description,quantity,unit_price,discount_percent,price_snapshot)
  values(v_quote_id,v_version.id,v_package.name,p_quantity,v_version.price,p_discount_percent,jsonb_build_object('package_id',v_package.id,'package_version_id',v_version.id,'version_number',v_version.version_number,'unit_price',v_version.price,'currency',v_version.currency));
  perform public.enqueue_domain_event(v_org,p_branch_id,'quotation.created','quotation',v_quote_id,jsonb_build_object('customer_id',v_customer_id,'package_version_id',v_version.id,'total',v_subtotal-v_discount),p_actor_user_id,'quotation.created:'||v_quote_id::text,false);
  return jsonb_build_object('customer_id',v_customer_id,'quotation_id',v_quote_id);
end; $$;

create or replace function public.accept_quotation(p_quotation_id uuid,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_quote public.quotations;
begin
  select * into v_quote from public.quotations where id=p_quotation_id for update;
  if v_quote.id is null or v_quote.status<>'issued' then raise exception 'issued quotation is required'; end if;
  if v_quote.valid_until is not null and v_quote.valid_until<current_date then raise exception 'quotation is expired'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.quote',v_quote.organization_id) or not public.can_access_branch(v_quote.organization_id,v_quote.branch_id)) then raise exception 'sales.quote and branch access are required'; end if;
  update public.quotations set status='accepted',accepted_at=now(),updated_at=now() where id=v_quote.id;
  perform public.enqueue_domain_event(v_quote.organization_id,v_quote.branch_id,'quotation.accepted','quotation',v_quote.id,'{}'::jsonb,p_actor_user_id,'quotation.accepted:'||v_quote.id::text,v_quote.is_demo);
end; $$;

create or replace function public.convert_quotation_to_invoice(p_quotation_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_quote public.quotations; v_invoice_id uuid;
begin
  select * into v_quote from public.quotations where id=p_quotation_id for update;
  if v_quote.id is null or v_quote.status<>'accepted' then raise exception 'accepted quotation is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('sales.invoice',v_quote.organization_id) or not public.can_access_branch(v_quote.organization_id,v_quote.branch_id)) then raise exception 'sales.invoice and branch access are required'; end if;
  insert into public.invoices(organization_id,branch_id,customer_id,quotation_id,status,currency,total_amount,due_at,created_by,is_demo)
  values(v_quote.organization_id,v_quote.branch_id,v_quote.customer_id,v_quote.id,'issued',v_quote.currency,v_quote.total_amount,now()+interval '7 days',p_actor_user_id,v_quote.is_demo)
  returning id into v_invoice_id;
  insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,source_snapshot,is_demo)
  select v_invoice_id,ql.package_version_id,ql.description,ql.quantity,ql.unit_price,ql.line_total,
    ql.price_snapshot||jsonb_build_object('quotation_line_id',ql.id,'quotation_id',v_quote.id),ql.is_demo
  from public.quotation_lines ql where ql.quotation_id=v_quote.id;
  update public.quotations set status='converted',updated_at=now() where id=v_quote.id;
  perform public.enqueue_domain_event(v_quote.organization_id,v_quote.branch_id,'invoice.created','invoice',v_invoice_id,jsonb_build_object('quotation_id',v_quote.id,'customer_id',v_quote.customer_id,'total',v_quote.total_amount),p_actor_user_id,'invoice.created:'||v_invoice_id::text,v_quote.is_demo);
  return v_invoice_id;
end; $$;

create or replace function public.submit_payment_proof(
  p_invoice_id uuid,p_claimed_amount numeric,p_payment_method text,p_proof_reference text,p_external_reference text,p_actor_user_id uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_submission_id uuid; v_remaining numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null or v_invoice.status not in('issued','partially_paid') then raise exception 'payable invoice is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.submit',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'payments.submit and branch access are required'; end if;
  v_remaining:=v_invoice.total_amount-v_invoice.confirmed_paid_amount;
  if p_claimed_amount<=0 or p_claimed_amount>v_remaining then raise exception 'claimed amount exceeds invoice remaining balance'; end if;
  if nullif(trim(p_proof_reference),'') is null then raise exception 'payment proof is required'; end if;
  insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,currency,payment_method,proof_reference,external_reference,status,submitted_by,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,p_claimed_amount,v_invoice.currency,p_payment_method,p_proof_reference,nullif(trim(p_external_reference),''),'pending',p_actor_user_id,v_invoice.is_demo)
  returning id into v_submission_id;
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'payment_proof.submitted','payment_submission',v_submission_id,jsonb_build_object('invoice_id',v_invoice.id,'amount',p_claimed_amount),p_actor_user_id,'payment_proof.submitted:'||v_submission_id::text,v_invoice.is_demo);
  return v_submission_id;
end; $$;

create or replace function public.confirm_payment_submission(p_submission_id uuid,p_confirmed_amount numeric,p_actor_user_id uuid,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_submission public.payment_submissions; v_transaction_id uuid; v_invoice public.invoices; v_remaining numeric(18,2);
begin
  select * into v_submission from public.payment_submissions where id=p_submission_id for update;
  if v_submission.id is null or v_submission.status not in('pending','under_review') then raise exception 'payment submission is not confirmable'; end if;
  if v_submission.invoice_id is null then raise exception 'payment submission must reference an invoice'; end if;
  if p_actor_user_id=v_submission.submitted_by then raise exception 'maker cannot confirm own payment'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.confirm',v_submission.organization_id) or not public.can_access_branch(v_submission.organization_id,v_submission.branch_id)) then raise exception 'payments.confirm and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_submission.invoice_id for update;
  if v_invoice.id is null or v_invoice.organization_id<>v_submission.organization_id or v_invoice.branch_id<>v_submission.branch_id or v_invoice.customer_id<>v_submission.customer_id then raise exception 'invoice scope mismatch'; end if;
  v_remaining:=v_invoice.total_amount-v_invoice.confirmed_paid_amount;
  if p_confirmed_amount<=0 or p_confirmed_amount>v_submission.claimed_amount or p_confirmed_amount>v_remaining then raise exception 'invalid confirmed amount'; end if;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,submission_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_submission.organization_id,v_submission.branch_id,v_submission.customer_id,v_submission.id,'collection',p_confirmed_amount,v_submission.currency,p_actor_user_id,p_idempotency_key,v_submission.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.payment_submissions set status=case when p_confirmed_amount=claimed_amount then 'confirmed' else 'partially_confirmed' end,
    confirmed_amount=p_confirmed_amount,reviewed_by=p_actor_user_id,reviewed_at=now(),rejection_reason=null where id=v_submission.id;
  update public.invoices set confirmed_paid_amount=confirmed_paid_amount+p_confirmed_amount,
    status=case when confirmed_paid_amount+p_confirmed_amount>=total_amount then 'paid' else 'partially_paid' end,updated_at=now() where id=v_invoice.id;
  insert into public.payment_allocations(organization_id,transaction_id,invoice_id,allocation_type,amount,allocated_by,is_demo)
  values(v_submission.organization_id,v_transaction_id,v_invoice.id,'invoice',p_confirmed_amount,p_actor_user_id,v_submission.is_demo);
  perform public.enqueue_domain_event(v_submission.organization_id,v_submission.branch_id,'payment.confirmed','payment_transaction',v_transaction_id,jsonb_build_object('submission_id',v_submission.id,'invoice_id',v_invoice.id,'amount',p_confirmed_amount),p_actor_user_id,'payment.confirmed:'||v_transaction_id::text,v_submission.is_demo);
  return v_transaction_id;
end; $$;

create or replace function public.reject_payment_submission(p_submission_id uuid,p_reason text,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_submission public.payment_submissions;
begin
  select * into v_submission from public.payment_submissions where id=p_submission_id for update;
  if v_submission.id is null or v_submission.status not in('pending','under_review') then raise exception 'payment submission is not reviewable'; end if;
  if p_actor_user_id=v_submission.submitted_by then raise exception 'maker cannot reject own payment'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'rejection reason is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('payments.review',v_submission.organization_id) or not public.can_access_branch(v_submission.organization_id,v_submission.branch_id)) then raise exception 'payments.review and branch access are required'; end if;
  update public.payment_submissions set status='rejected',rejection_reason=trim(p_reason),reviewed_by=p_actor_user_id,reviewed_at=now() where id=v_submission.id;
  perform public.enqueue_domain_event(v_submission.organization_id,v_submission.branch_id,'payment.rejected','payment_submission',v_submission.id,jsonb_build_object('invoice_id',v_submission.invoice_id,'reason',trim(p_reason)),p_actor_user_id,'payment.rejected:'||v_submission.id::text,v_submission.is_demo);
end; $$;

create or replace function public.create_activate_subscription_from_invoice(p_invoice_id uuid,p_package_version_id uuid,p_starts_on date,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_version public.package_versions; v_subscription_id uuid; v_contract numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null or v_invoice.status<>'paid' or v_invoice.confirmed_paid_amount<>v_invoice.total_amount then raise exception 'fully paid invoice is required'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('subscriptions.manage',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'subscriptions.manage and branch access are required'; end if;
  select pv.* into v_version from public.package_versions pv where pv.id=p_package_version_id
    and exists(select 1 from public.invoice_lines il where il.invoice_id=v_invoice.id and il.package_version_id=pv.id);
  if v_version.id is null then raise exception 'package version must belong to the selected invoice'; end if;
  select sum(il.line_total) into v_contract from public.invoice_lines il where il.invoice_id=v_invoice.id and il.package_version_id=v_version.id;
  insert into public.subscriptions(organization_id,branch_id,customer_id,invoice_id,package_version_id,status,starts_on,ends_on,purchased_service_days,contract_value,deferred_balance,recognized_revenue,activated_by,activated_at,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,v_version.id,'active',p_starts_on,p_starts_on+v_version.service_days-1,v_version.service_days,v_contract,v_contract,0,p_actor_user_id,now(),v_invoice.is_demo)
  returning id into v_subscription_id;
  insert into public.planned_service_days(subscription_id,service_date,status,branch_id,is_demo)
  select v_subscription_id,p_starts_on+g,'planned',v_invoice.branch_id,v_invoice.is_demo from generate_series(0,v_version.service_days-1) g;
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_subscription_id,v_invoice.id,'activation',v_contract,0,v_contract,p_actor_user_id,'subscription.activation:'||v_subscription_id::text,v_invoice.is_demo);
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'subscription.activated','subscription',v_subscription_id,jsonb_build_object('invoice_id',v_invoice.id,'deferred_revenue',v_contract),p_actor_user_id,'subscription.activated:'||v_subscription_id::text,v_invoice.is_demo);
  return v_subscription_id;
end; $$;

create or replace function public.confirm_service_delivery(p_planned_day_id uuid,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_day public.planned_service_days; v_subscription public.subscriptions; v_confirmation_id uuid; v_amount numeric(18,2); v_balance numeric(18,2);
begin
  select * into v_day from public.planned_service_days where id=p_planned_day_id for update;
  if v_day.id is null then raise exception 'planned service day is required'; end if;
  select * into v_subscription from public.subscriptions where id=v_day.subscription_id for update;
  if v_day.status not in('planned','delivered_pending_confirmation') or v_subscription.status<>'active' then raise exception 'service day is not deliverable'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('service.confirm_delivery',v_subscription.organization_id) or not public.can_access_branch(v_subscription.organization_id,v_subscription.branch_id)) then raise exception 'service.confirm_delivery and branch access are required'; end if;
  v_amount:=least(v_subscription.deferred_balance,round(v_subscription.contract_value/v_subscription.purchased_service_days,2));
  if v_amount<=0 then raise exception 'no deferred revenue remains'; end if;
  insert into public.service_delivery_confirmations(planned_service_day_id,subscription_id,status,confirmed_by,is_demo)
  values(v_day.id,v_subscription.id,'confirmed_delivered',p_actor_user_id,v_day.is_demo) returning id into v_confirmation_id;
  insert into public.revenue_entries(organization_id,subscription_id,delivery_confirmation_id,entry_type,amount,entry_date,created_by,idempotency_key,is_demo)
  values(v_subscription.organization_id,v_subscription.id,v_confirmation_id,'recognition',v_amount,v_day.service_date,p_actor_user_id,'delivery:'||v_day.id::text,v_day.is_demo);
  v_balance:=greatest(0,v_subscription.deferred_balance-v_amount);
  update public.planned_service_days set status='confirmed_delivered' where id=v_day.id;
  update public.subscriptions set delivered_service_days=delivered_service_days+1,recognized_revenue=recognized_revenue+v_amount,deferred_balance=v_balance,updated_at=now() where id=v_subscription.id;
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,delivery_confirmation_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  values(v_subscription.organization_id,v_subscription.branch_id,v_subscription.id,v_subscription.invoice_id,v_confirmation_id,'recognition',-v_amount,v_amount,v_balance,p_actor_user_id,'delivery.recognition:'||v_day.id::text,v_day.is_demo);
  perform public.enqueue_domain_event(v_subscription.organization_id,v_subscription.branch_id,'service_day.confirmed_delivered','planned_service_day',v_day.id,jsonb_build_object('subscription_id',v_subscription.id,'recognized_revenue',v_amount,'deferred_balance',v_balance),p_actor_user_id,'service_day.confirmed:'||v_day.id::text,v_day.is_demo);
  return v_confirmation_id;
end; $$;

create or replace function public.request_refund(p_invoice_id uuid,p_subscription_id uuid,p_amount numeric,p_reason text,p_actor_user_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_refund_id uuid; v_refunded numeric(18,2);
begin
  select * into v_invoice from public.invoices where id=p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice is required'; end if;
  if p_subscription_id is not null and not exists(select 1 from public.subscriptions s where s.id=p_subscription_id and s.invoice_id=v_invoice.id) then raise exception 'subscription does not belong to invoice'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.request',v_invoice.organization_id) or not public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'refunds.request and branch access are required'; end if;
  select coalesce(sum(r.amount),0) into v_refunded from public.refunds r where r.invoice_id=v_invoice.id and r.status in('approved','paid');
  if p_amount<=0 or p_amount>v_invoice.confirmed_paid_amount-v_refunded then raise exception 'refund exceeds refundable confirmed cash'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'refund reason is required'; end if;
  insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,status,requested_by,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,v_invoice.customer_id,v_invoice.id,p_subscription_id,p_amount,trim(p_reason),'requested',p_actor_user_id,v_invoice.is_demo) returning id into v_refund_id;
  insert into public.approval_requests(organization_id,branch_id,entity_type,entity_id,approval_type,requested_by,threshold_amount,is_demo)
  values(v_invoice.organization_id,v_invoice.branch_id,'refund',v_refund_id,'refund',p_actor_user_id,p_amount,v_invoice.is_demo);
  perform public.enqueue_domain_event(v_invoice.organization_id,v_invoice.branch_id,'refund.requested','refund',v_refund_id,jsonb_build_object('invoice_id',v_invoice.id,'amount',p_amount),p_actor_user_id,'refund.requested:'||v_refund_id::text,v_invoice.is_demo);
  return v_refund_id;
end; $$;

create or replace function public.approve_refund(p_refund_id uuid,p_actor_user_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds;
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status not in('requested','under_review') then raise exception 'refund is not approvable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot approve own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  update public.refunds set status='approved',approved_by=p_actor_user_id,approved_at=now() where id=v_refund.id;
  update public.approval_requests set status='approved',decided_by=p_actor_user_id,decided_at=now() where entity_type='refund' and entity_id=v_refund.id and status='pending';
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.approved','refund',v_refund.id,jsonb_build_object('invoice_id',v_refund.invoice_id,'amount',v_refund.amount),p_actor_user_id,'refund.approved:'||v_refund.id::text,v_refund.is_demo);
end; $$;

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_invoice public.invoices; v_subscription public.subscriptions; v_transaction_id uuid; v_new_deferred numeric(18,2);
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' or v_refund.invoice_id is null then raise exception 'approved invoice refund is required'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot pay own refund'; end if;
  if auth.uid() is not null and (p_actor_user_id<>auth.uid() or not public.has_permission('refunds.approve',v_refund.organization_id) or not public.can_access_branch(v_refund.organization_id,v_refund.branch_id)) then raise exception 'refunds.approve and branch access are required'; end if;
  select * into v_invoice from public.invoices where id=v_refund.invoice_id for update;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,v_invoice.currency,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  on conflict(organization_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key returning id into v_transaction_id;
  update public.invoices set confirmed_paid_amount=greatest(0,confirmed_paid_amount-v_refund.amount),
    status=case when confirmed_paid_amount-v_refund.amount<=0 then 'issued' when confirmed_paid_amount-v_refund.amount<total_amount then 'partially_paid' else status end,updated_at=now() where id=v_invoice.id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=p_proof_reference,transaction_id=v_transaction_id where id=v_refund.id;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,
    -least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(v_invoice.confirmed_paid_amount,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce
  join public.payment_transactions pt on pt.id=ce.source_transaction_id
  join public.payment_submissions ps on ps.id=pt.submission_id
  where ps.invoice_id=v_invoice.id and ce.entry_type='commission' and ce.status<>'reversed'
  on conflict do nothing;
  if v_refund.subscription_id is not null then
    select * into v_subscription from public.subscriptions where id=v_refund.subscription_id for update;
    v_new_deferred:=greatest(0,v_subscription.deferred_balance-least(v_refund.amount,v_subscription.deferred_balance));
    update public.subscriptions set deferred_balance=v_new_deferred,updated_at=now() where id=v_subscription.id;
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,refund_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_refund.organization_id,v_refund.branch_id,v_subscription.id,v_invoice.id,v_refund.id,'refund',-(v_subscription.deferred_balance-v_new_deferred),0,v_new_deferred,p_actor_user_id,'refund.deferred:'||v_refund.id::text,v_refund.is_demo);
  end if;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('invoice_id',v_invoice.id,'transaction_id',v_transaction_id,'amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

create view public.confirmed_cash_v with(security_invoker=true) as
select pt.organization_id,pt.branch_id,pt.customer_id,sum(pt.amount) as net_confirmed_cash,min(pt.confirmed_at) as first_transaction_at,max(pt.confirmed_at) as last_transaction_at
from public.payment_transactions pt where pt.transaction_type in('collection','refund','reversal') group by pt.organization_id,pt.branch_id,pt.customer_id;

create or replace function public.invoice_timeline(p_invoice_id uuid)
returns table(event_type text,aggregate_type text,aggregate_id uuid,payload jsonb,occurred_at timestamptz,actor_user_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices where id=p_invoice_id;
  if v_invoice.id is null then return; end if;
  if auth.uid() is not null and not ((public.has_permission('sales.invoice',v_invoice.organization_id) or public.has_permission('payments.review',v_invoice.organization_id) or public.has_permission('subscriptions.view',v_invoice.organization_id)) and public.can_access_branch(v_invoice.organization_id,v_invoice.branch_id)) then raise exception 'invoice access is required'; end if;
  return query
  select de.event_type,de.aggregate_type,de.aggregate_id,de.payload,de.occurred_at,de.actor_user_id
  from public.domain_events de
  where de.organization_id=v_invoice.organization_id and (
    (de.aggregate_type='invoice' and de.aggregate_id=v_invoice.id) or
    (de.aggregate_type='quotation' and de.aggregate_id=v_invoice.quotation_id) or
    de.payload->>'invoice_id'=v_invoice.id::text or
    (de.aggregate_type='payment_submission' and exists(select 1 from public.payment_submissions ps where ps.id=de.aggregate_id and ps.invoice_id=v_invoice.id)) or
    (de.aggregate_type='payment_transaction' and exists(select 1 from public.payment_transactions pt join public.payment_submissions ps on ps.id=pt.submission_id where pt.id=de.aggregate_id and ps.invoice_id=v_invoice.id)) or
    (de.aggregate_type='subscription' and exists(select 1 from public.subscriptions s where s.id=de.aggregate_id and s.invoice_id=v_invoice.id)) or
    (de.aggregate_type='refund' and exists(select 1 from public.refunds r where r.id=de.aggregate_id and r.invoice_id=v_invoice.id))
  ) order by de.occurred_at;
end; $$;

alter table public.sales_target_actuals enable row level security;
alter table public.deferred_revenue_entries enable row level security;
create policy sales_target_actuals_scope on public.sales_target_actuals for select to authenticated
using(public.has_permission('targets.view_team',organization_id) or salesperson_user_id=auth.uid());
create policy deferred_revenue_scope on public.deferred_revenue_entries for select to authenticated
using(public.has_permission('revenue.view',organization_id) and public.can_access_branch(organization_id,branch_id));

revoke all on function public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid) from public;
revoke all on function public.accept_quotation(uuid,uuid) from public;
revoke all on function public.convert_quotation_to_invoice(uuid,uuid) from public;
revoke all on function public.submit_payment_proof(uuid,numeric,text,text,text,uuid) from public;
revoke all on function public.confirm_payment_submission(uuid,numeric,uuid,text) from public;
revoke all on function public.reject_payment_submission(uuid,text,uuid) from public;
revoke all on function public.create_activate_subscription_from_invoice(uuid,uuid,date,uuid) from public;
revoke all on function public.confirm_service_delivery(uuid,uuid) from public;
revoke all on function public.request_refund(uuid,uuid,numeric,text,uuid) from public;
revoke all on function public.approve_refund(uuid,uuid) from public;
revoke all on function public.pay_refund_and_clawback(uuid,uuid,text,text) from public;
revoke all on function public.invoice_timeline(uuid) from public;
grant execute on function public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid) to authenticated;
grant execute on function public.accept_quotation(uuid,uuid) to authenticated;
grant execute on function public.convert_quotation_to_invoice(uuid,uuid) to authenticated;
grant execute on function public.submit_payment_proof(uuid,numeric,text,text,text,uuid) to authenticated;
grant execute on function public.confirm_payment_submission(uuid,numeric,uuid,text) to authenticated;
grant execute on function public.reject_payment_submission(uuid,text,uuid) to authenticated;
grant execute on function public.create_activate_subscription_from_invoice(uuid,uuid,date,uuid) to authenticated;
grant execute on function public.confirm_service_delivery(uuid,uuid) to authenticated;
grant execute on function public.request_refund(uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.approve_refund(uuid,uuid) to authenticated;
grant execute on function public.pay_refund_and_clawback(uuid,uuid,text,text) to authenticated;
grant execute on function public.invoice_timeline(uuid) to authenticated;

create or replace function public.validate_eco_healthy_installation()
returns table(check_name text,passed boolean,details text)
language sql stable security definer set search_path='' as $$
  select 'schema_versions',count(*)>=11,'Installed versions: '||count(*) from public.schema_versions
  union all select 'rls_core',bool_and(c.relrowsecurity),'Core RLS tables checked' from pg_catalog.pg_class c where c.oid in('public.profiles'::regclass,'public.tasks'::regclass,'public.customers'::regclass,'public.payment_submissions'::regclass,'public.doctor_sessions'::regclass,'public.deferred_revenue_entries'::regclass)
  union all select 'system_roles',count(*)>=15,'System roles: '||count(*) from public.roles where is_system
  union all select 'permission_catalog',count(*)>=70,'Permissions: '||count(*) from public.permissions
  union all select 'storage_bucket',exists(select 1 from storage.buckets where id='erp-attachments' and not public),'Private attachment bucket'
  union all select 'commercial_cycle',to_regprocedure('public.create_customer_quotation(uuid,text,text,uuid,numeric,numeric,date,text,uuid)') is not null,'Transactional hosted commercial RPCs';
$$;

insert into public.schema_versions(version,name) values(11,'hosted_commercial_cycle');
commit;
