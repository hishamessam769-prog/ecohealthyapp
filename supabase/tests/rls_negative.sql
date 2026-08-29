-- Run with Supabase CLI after loading fixture users and pgTAP.
begin;
set local role authenticated;
select plan(4);
select is((select count(*) from public.eco_customers where id='00000000-0000-0000-0000-000000000002'),0::bigint,'sales cannot read another owner customer');
select is((select count(*) from public.eco_payments),0::bigint,'kitchen/sales cannot enumerate finance');
select is((select count(*) from public.eco_route_stops where route_id='00000000-0000-0000-0000-000000000099'),0::bigint,'rider cannot read another route');
select is((select count(*) from public.eco_customer_dietary_rules),0::bigint,'investor cannot read dietary PII');
select * from finish();
rollback;

