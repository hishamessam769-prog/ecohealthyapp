begin;

insert into public.permissions(code,name,module,description,is_sensitive) values
('targets.view_own','View own targets','Performance','View personal target and attainment',false),
('targets.view_team','View team targets','Performance','View team target performance',false),
('targets.manage','Manage targets','Performance','Create and revise targets',true),
('sales_commissions.view_own','View own sales commissions','Performance','View personal sales commission entries',false),
('sales_commissions.review','Review sales commissions','Performance','Review eligible sales commissions',true),
('sales_commissions.approve','Approve sales commissions','Performance','Approve commissions under maker-checker',true)
on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_own','sales_commissions.view_own') where r.code='sales_representative' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_own','targets.view_team','sales_commissions.view_own','sales_commissions.review') where r.code in('sales_manager','sales_team_leader') on conflict do nothing;
insert into public.role_permissions(role_id,permission_id)
select r.id,p.id from public.roles r join public.permissions p on p.code in('targets.view_team','targets.manage','sales_commissions.review','sales_commissions.approve') where r.code='finance_manager' on conflict do nothing;
insert into public.role_permissions(role_id,permission_id) select r.id,p.id from public.roles r cross join public.permissions p where r.code='ceo_super_admin' on conflict do nothing;

create table public.sales_targets(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id), target_type text not null check(target_type in('user','team')),
  user_id uuid references public.profiles(id), team_id uuid references public.teams(id), period_start date not null, period_end date not null,
  target_amount numeric(18,2) not null check(target_amount>=0), currency char(3) not null default 'EGP', created_by uuid references public.profiles(id), created_at timestamptz not null default now(), is_demo boolean not null default false,
  check(num_nonnulls(user_id,team_id)=1), check(period_end>=period_start)
);
create table public.sales_commission_policies(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, applies_to_role_code text, is_active boolean not null default true, created_at timestamptz not null default now(), is_demo boolean not null default false
);
create table public.sales_commission_policy_versions(
  id uuid primary key default extensions.gen_random_uuid(), policy_id uuid not null references public.sales_commission_policies(id) on delete cascade,
  version_number integer not null, method text not null check(method in('confirmed_cash_percent','fixed_per_sale','tiered')),
  value numeric(18,4) not null check(value>=0), team_leader_bonus_percent numeric(5,2) not null default 0 check(team_leader_bonus_percent between 0 and 100),
  tiers jsonb not null default '[]'::jsonb, effective_from date not null, effective_to date, created_by uuid references public.profiles(id), is_demo boolean not null default false,
  unique(policy_id,version_number), check(effective_to is null or effective_to>=effective_from)
);
create table public.sales_commission_entries(
  id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id), beneficiary_user_id uuid not null references public.profiles(id), source_transaction_id uuid references public.payment_transactions(id), refund_id uuid references public.refunds(id),
  policy_version_id uuid references public.sales_commission_policy_versions(id), entry_type text not null check(entry_type in('commission','team_leader_bonus','clawback','adjustment')),
  basis_amount numeric(18,2) not null, amount numeric(18,2) not null, status text not null default 'eligible' check(status in('estimated','eligible','under_review','approved','paid','clawback_required','reversed','disputed')),
  created_at timestamptz not null default now(), reviewed_by uuid references public.profiles(id), approved_by uuid references public.profiles(id), approved_at timestamptz, is_demo boolean not null default false,
  check(approved_by is null or approved_by<>beneficiary_user_id)
);
create unique index sales_commission_collection_uidx on public.sales_commission_entries(beneficiary_user_id,source_transaction_id,entry_type) where source_transaction_id is not null;
create unique index sales_commission_refund_uidx on public.sales_commission_entries(beneficiary_user_id,refund_id,entry_type) where refund_id is not null;

create or replace function public.create_sales_commission_from_collection()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_invoice public.invoices; v_quote public.quotations; v_version public.sales_commission_policy_versions; v_amount numeric(18,2);
begin
  if new.transaction_type<>'collection' then return new; end if;
  select i.* into v_invoice from public.invoices i join public.payment_submissions ps on ps.invoice_id=i.id where ps.id=new.submission_id;
  if v_invoice.id is null then return new; end if;
  select * into v_quote from public.quotations where id=v_invoice.quotation_id;
  if v_quote.created_by is null then return new; end if;
  select pv.* into v_version from public.sales_commission_policy_versions pv join public.sales_commission_policies p on p.id=pv.policy_id
  where p.organization_id=new.organization_id and p.is_active and current_date>=pv.effective_from and (pv.effective_to is null or current_date<=pv.effective_to)
  order by pv.effective_from desc limit 1;
  if v_version.id is null then return new; end if;
  v_amount:=case when v_version.method='fixed_per_sale' then v_version.value else round(new.amount*v_version.value/100,2) end;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,source_transaction_id,policy_version_id,entry_type,basis_amount,amount,status,is_demo)
  values(new.organization_id,new.branch_id,v_quote.created_by,new.id,v_version.id,'commission',new.amount,v_amount,'eligible',new.is_demo)
  on conflict do nothing;
  return new;
end; $$;
create trigger payment_transaction_sales_commission after insert on public.payment_transactions for each row execute function public.create_sales_commission_from_collection();

create or replace function public.pay_refund_and_clawback(p_refund_id uuid,p_actor_user_id uuid,p_proof_reference text,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_refund public.refunds; v_transaction_id uuid;
begin
  select * into v_refund from public.refunds where id=p_refund_id for update;
  if v_refund.id is null or v_refund.status<>'approved' then raise exception 'refund is not payable'; end if;
  if p_actor_user_id=v_refund.requested_by then raise exception 'maker cannot pay own refund'; end if;
  if auth.uid() is not null and not public.has_permission('refunds.approve',v_refund.organization_id) then raise exception 'refund approval permission required'; end if;
  insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,confirmed_by,idempotency_key,is_demo)
  values(v_refund.organization_id,v_refund.branch_id,v_refund.customer_id,'refund',-v_refund.amount,p_actor_user_id,p_idempotency_key,v_refund.is_demo)
  returning id into v_transaction_id;
  update public.refunds set status='paid',paid_by=p_actor_user_id,paid_at=now(),payment_proof_reference=p_proof_reference where id=v_refund.id;
  insert into public.sales_commission_entries(organization_id,branch_id,beneficiary_user_id,refund_id,entry_type,basis_amount,amount,status,is_demo)
  select ce.organization_id,ce.branch_id,ce.beneficiary_user_id,v_refund.id,'clawback',v_refund.amount,
    -least(abs(ce.amount),round(abs(ce.amount)*(v_refund.amount/nullif(ce.basis_amount,0)),2)),'clawback_required',v_refund.is_demo
  from public.sales_commission_entries ce join public.payment_transactions pt on pt.id=ce.source_transaction_id
  where pt.customer_id=v_refund.customer_id and ce.entry_type='commission' and ce.status not in('reversed')
  on conflict do nothing;
  perform public.enqueue_domain_event(v_refund.organization_id,v_refund.branch_id,'refund.paid','refund',v_refund.id,jsonb_build_object('amount',v_refund.amount),p_actor_user_id,'refund.paid:'||v_refund.id::text,v_refund.is_demo);
  return v_transaction_id;
end; $$;

create view public.sales_performance_v with(security_invoker=true) as
select t.id,t.organization_id,t.branch_id,t.target_type,t.user_id,t.team_id,t.period_start,t.period_end,t.target_amount,
  coalesce(sum(pt.amount) filter(where pt.transaction_type='collection' and pt.confirmed_at::date between t.period_start and t.period_end and (t.user_id is null or q.created_by=t.user_id)),0) as confirmed_cash,
  case when t.target_amount=0 then 0 else round(coalesce(sum(pt.amount) filter(where pt.transaction_type='collection' and pt.confirmed_at::date between t.period_start and t.period_end and (t.user_id is null or q.created_by=t.user_id)),0)/t.target_amount*100,2) end as achievement_percent
from public.sales_targets t left join public.quotations q on q.organization_id=t.organization_id left join public.invoices i on i.quotation_id=q.id
left join public.payment_submissions ps on ps.invoice_id=i.id left join public.payment_transactions pt on pt.submission_id=ps.id
group by t.id;

do $$ declare t text; begin foreach t in array array['sales_targets','sales_commission_policies','sales_commission_policy_versions','sales_commission_entries'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;
create policy targets_scope on public.sales_targets for select to authenticated using(user_id=auth.uid() or public.has_permission('targets.view_team',organization_id));
create policy targets_manage_scope on public.sales_targets for all to authenticated using(public.has_permission('targets.manage',organization_id)) with check(public.has_permission('targets.manage',organization_id));
create policy sales_policy_scope on public.sales_commission_policies for select to authenticated using(public.has_permission('sales_commissions.review',organization_id));
create policy sales_policy_versions_scope on public.sales_commission_policy_versions for select to authenticated using(exists(select 1 from public.sales_commission_policies p where p.id=policy_id and public.has_permission('sales_commissions.review',p.organization_id)));
create policy sales_commission_scope on public.sales_commission_entries for select to authenticated using(beneficiary_user_id=auth.uid() or public.has_permission('sales_commissions.review',organization_id));
create trigger audit_sales_targets after insert or update or delete on public.sales_targets for each row execute function public.audit_row_change();
create trigger audit_sales_commissions after insert or update or delete on public.sales_commission_entries for each row execute function public.audit_row_change();

insert into public.schema_versions(version,name) values(8,'targets_sales_commissions');
commit;
