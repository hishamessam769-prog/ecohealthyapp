begin;

drop view if exists public.eco_operations_dashboard_v;
create view public.eco_operations_dashboard_v with(security_invoker=false) as
select
  b.id,
  (select count(*) from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and s.status in('ACTIVE','PAUSED')) active_members,
  (select count(*) from public.eco_customers c where c.organization_id=b.organization_id and c.created_at>=date_trunc('month',current_date)) new_customers,
  (select count(*) from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and s.status='CANCELED' and s.canceled_at>=date_trunc('month',current_date)) churn_count,
  100.0*(select count(*) from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and s.status='CANCELED' and s.canceled_at>=date_trunc('month',current_date))/nullif((select count(*) from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and s.activated_at<date_trunc('month',current_date)),0) churn_ratio,
  100.0*(select count(*) from public.eco_renewal_opportunities ro join public.eco_subscriptions s on s.id=ro.subscription_id join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and ro.status='RENEWED' and ro.due_date>=date_trunc('month',current_date)::date)/nullif((select count(*) from public.eco_renewal_opportunities ro join public.eco_subscriptions s on s.id=ro.subscription_id join public.eco_orders o on o.id=s.order_id where o.branch_id=b.id and ro.due_date>=date_trunc('month',current_date)::date),0) renewal_rate,
  (select coalesce(avg(customer_total),0) from(select i.customer_id,sum(pa.amount) customer_total from public.eco_payment_allocations pa join public.eco_invoices i on i.id=pa.invoice_id where i.branch_id=b.id group by i.customer_id)x) average_ltv,
  (select coalesce(sum(rs.deferred_amount),0) from public.eco_revenue_schedules rs join public.eco_invoice_lines il on il.id=rs.invoice_line_id join public.eco_invoices i on i.id=il.invoice_id where i.branch_id=b.id) remaining_subscriber_funds,
  (select coalesce(sum(pa.amount),0) from public.eco_payment_allocations pa join public.eco_invoices i on i.id=pa.invoice_id where i.branch_id=b.id and pa.allocated_at>=date_trunc('month',current_date)) month_sales,
  (select coalesce(sum(cp.amount),0) from public.eco_commission_payables cp join public.eco_employees e on e.id=cp.employee_id where e.organization_id=b.organization_id and cp.status='OPEN') commission_liability,
  (select coalesce(sum(required_quantity),0) from public.eco_production_demand d where d.branch_id=b.id and d.service_date=current_date+1) production_demand,
  (select least(100,100.0*coalesce(sum(required_quantity),0)/nullif(500,0)) from public.eco_production_demand d where d.branch_id=b.id and d.service_date=current_date+1) kitchen_utilization,
  (select 100.0*count(*) filter(where st.delivered_at<=st.promised_end)/nullif(count(*) filter(where st.state='DELIVERED'),0) from public.eco_route_stops st join public.eco_routes r on r.id=st.route_id where r.branch_id=b.id and r.route_date=current_date) delivery_sla,
  (select count(*) from public.eco_planning_exceptions where status='OPEN') open_exceptions,
  now() freshness
from public.eco_branches b where b.active;

revoke all on public.eco_operations_dashboard_v from public,anon,authenticated;
grant select on public.eco_operations_dashboard_v to service_role;
insert into public.eco_schema_migrations(version,description,checksum)
values('013_coo_dashboard','Live COO subscriber, retention, LTV, sales, commission and operations dashboard','sha256:eco-v5-013-coo-dashboard')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();
select pg_notify('pgrst','reload schema');
commit;
