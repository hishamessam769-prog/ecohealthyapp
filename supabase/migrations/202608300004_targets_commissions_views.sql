begin;

drop view if exists public.eco_targets_v;
create view public.eco_targets_v with(security_invoker=false) as
with company_targets as(
  select distinct on(branch_id,period_start) id,branch_id,period_start,revenue_target,quantity_target from public.eco_company_sales_targets where status='APPROVED' order by branch_id,period_start,version_number desc
), employee_targets as(
  select distinct on(employee_id,period_start) id,employee_id,period_start,revenue_target,quantity_target from public.eco_employee_sales_targets where status='APPROVED' order by employee_id,period_start,version_number desc
), sales as(
  select employee_id,period_start,sum(booked_value) booked_actual,sum(commissionable_value) filter(where lifecycle_state in('ELIGIBLE_CONFIRMED','COMMISSION_ACCRUED','COMMISSION_PAYABLE','COMMISSION_PAID')) confirmed_actual from public.eco_sales_credit_events group by employee_id,period_start
)
select ct.id,ct.period_start,'COMPANY'::text scope_type,'إجمالي الشركة'::text scope_name,ct.revenue_target,coalesce(sum(s.booked_actual),0) booked_actual,coalesce(sum(s.confirmed_actual),0) confirmed_actual,coalesce(sum(s.booked_actual),0)/greatest(extract(day from current_date),1)*extract(day from(date_trunc('month',current_date)+interval '1 month - 1 day')) forecast,coalesce(sum(s.booked_actual),0)-ct.revenue_target variance,case when coalesce(sum(s.booked_actual),0)>=ct.revenue_target then 'GREEN' when coalesce(sum(s.booked_actual),0)>=ct.revenue_target*.8 then 'AMBER' else 'RED' end rag_status
from company_targets ct left join public.eco_employees e on e.organization_id=(select organization_id from public.eco_branches where id=ct.branch_id) left join sales s on s.employee_id=e.id and s.period_start=ct.period_start group by ct.id,ct.period_start,ct.revenue_target
union all
select et.id,et.period_start,'EMPLOYEE'::text,e.full_name,et.revenue_target,coalesce(s.booked_actual,0),coalesce(s.confirmed_actual,0),coalesce(s.booked_actual,0)/greatest(extract(day from current_date),1)*extract(day from(date_trunc('month',current_date)+interval '1 month - 1 day')),coalesce(s.booked_actual,0)-et.revenue_target,case when coalesce(s.booked_actual,0)>=et.revenue_target then 'GREEN' when coalesce(s.booked_actual,0)>=et.revenue_target*.8 then 'AMBER' else 'RED' end
from employee_targets et join public.eco_employees e on e.id=et.employee_id left join sales s on s.employee_id=et.employee_id and s.period_start=et.period_start;

drop view if exists public.eco_commissions_v;
create view public.eco_commissions_v with(security_invoker=false) as
with periods as(
  select e.id employee_id,e.full_name,date_trunc('month',current_date)::date period_start from public.eco_employees e
  where e.status='ACTIVE' and exists(select 1 from public.eco_employee_role_assignments era where era.employee_id=e.id and era.role_code in('sales_agent','sales_manager') and era.approved and era.effective_from<=current_date and(era.effective_to is null or era.effective_to>=current_date))
), target as(
  select distinct on(employee_id,period_start) employee_id,period_start,revenue_target from public.eco_employee_sales_targets where status='APPROVED' order by employee_id,period_start,version_number desc
), credit as(
  select employee_id,period_start,sum(booked_value) booked_value,sum(booked_value) filter(where lifecycle_state='PAYMENT_VERIFIED_PENDING_MATURITY') pending_value,sum(commissionable_value) filter(where lifecycle_state in('ELIGIBLE_CONFIRMED','COMMISSION_ACCRUED','COMMISSION_PAYABLE','COMMISSION_PAID')) eligible_value,max(maturity_reason) filter(where lifecycle_state='PAYMENT_VERIFIED_PENDING_MATURITY') maturity_reason from public.eco_sales_credit_events group by employee_id,period_start
), accrual as(
  select employee_id,period_start,sum(accrued_amount) accrued_amount,sum(accrued_amount) filter(where status='PAYABLE') payable_amount,sum(accrued_amount) filter(where status='PAID') paid_amount from public.eco_commission_accruals group by employee_id,period_start
), reversal as(
  select ca.employee_id,ca.period_start,sum(cr.amount) clawback_amount from public.eco_commission_reversals cr join public.eco_commission_accruals ca on ca.id=cr.accrual_id group by ca.employee_id,ca.period_start
)
select p.employee_id id,p.employee_id scope_employee_id,p.period_start,p.full_name employee_name,coalesce(t.revenue_target,0) target,coalesce(c.booked_value,0) booked_value,coalesce(c.pending_value,0) pending_value,coalesce(c.eligible_value,0) eligible_value,100*coalesce(c.booked_value,0)/nullif(t.revenue_target,0) booked_achievement,100*coalesce(c.eligible_value,0)/nullif(t.revenue_target,0) confirmed_achievement,coalesce(a.accrued_amount,0) accrued_amount,coalesce(a.payable_amount,0) payable_amount,coalesce(a.paid_amount,0) paid_amount,coalesce(r.clawback_amount,0) clawback_amount,c.maturity_reason
from periods p left join target t on t.employee_id=p.employee_id and t.period_start=p.period_start left join credit c on c.employee_id=p.employee_id and c.period_start=p.period_start left join accrual a on a.employee_id=p.employee_id and a.period_start=p.period_start left join reversal r on r.employee_id=p.employee_id and r.period_start=p.period_start;

revoke all on public.eco_targets_v,public.eco_commissions_v from public,anon,authenticated;
grant select on public.eco_targets_v,public.eco_commissions_v to service_role;
insert into public.eco_schema_migrations(version,description,checksum)
values('012_targets_commissions_views','Company and employee targets with booked, pending and matured commission projections','sha256:eco-v5-012-targets-commissions-views')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();
select pg_notify('pgrst','reload schema');
commit;
