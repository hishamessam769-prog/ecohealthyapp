begin;

create extension if not exists pgtap with schema extensions;
select plan(35);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000001','authenticated','authenticated','sales-cycle@eco.local','test',now(),'{}','{"full_name":"Sales Cycle"}',now(),now()),
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000002','authenticated','authenticated','finance-cycle@eco.local','test',now(),'{}','{"full_name":"Finance Cycle"}',now(),now()),
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000003','authenticated','authenticated','operations-cycle@eco.local','test',now(),'{}','{"full_name":"Operations Cycle"}',now(),now());

insert into public.organizations(id,code,name) values
('22000000-0000-0000-0000-000000000001','CYCLE','Commercial Cycle Test'),
('22000000-0000-0000-0000-000000000002','OTHER','Other Scope Test');
insert into public.branches(id,organization_id,code,name) values
('32000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','MAIN','Main Branch'),
('32000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','SECOND','Second Branch'),
('32000000-0000-0000-0000-000000000003','22000000-0000-0000-0000-000000000002','OTHER','Other Organization Branch');
insert into public.organization_memberships(organization_id,user_id,status,activated_at) values
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','active',now()),
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002','active',now()),
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','active',now());
insert into public.user_roles(organization_id,user_id,role_id)
select '22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001',id from public.roles where code in('sales_representative','sales_manager');
insert into public.user_roles(organization_id,user_id,role_id)
select '22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002',id from public.roles where code='finance_accountant';
insert into public.user_roles(organization_id,user_id,role_id)
select '22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003',id from public.roles where code='operations_manager';
insert into public.user_branch_access(organization_id,user_id,branch_id,access_level) values
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','operate'),
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002','32000000-0000-0000-0000-000000000001','operate'),
('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000003','32000000-0000-0000-0000-000000000001','operate');

insert into public.packages(id,organization_id,code,name,created_by) values('42000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','ECO30','Eco 30','12000000-0000-0000-0000-000000000001');
insert into public.package_versions(id,package_id,version_number,effective_from,currency,price,service_days,meals_per_day,status,created_by)
values('43000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001',1,current_date,'EGP',6000,30,3,'active','12000000-0000-0000-0000-000000000001');
insert into public.discount_limits(organization_id,user_id,maximum_percent,effective_from)
values('22000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001',10,current_date);
insert into public.sales_targets(id,organization_id,branch_id,target_type,user_id,period_start,period_end,target_amount,created_by)
values('44000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','user','12000000-0000-0000-0000-000000000001',current_date-1,current_date+30,10000,'12000000-0000-0000-0000-000000000001');
insert into public.sales_commission_policies(id,organization_id,name,applies_to_role_code) values('45000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','Cycle policy','sales_representative');
insert into public.sales_commission_policy_versions(policy_id,version_number,method,value,effective_from,created_by)
values('45000000-0000-0000-0000-000000000001',1,'confirmed_cash_percent',3,current_date-1,'12000000-0000-0000-0000-000000000002');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select lives_ok($$select public.create_customer_quotation('32000000-0000-0000-0000-000000000001','Hosted Cycle Customer','01000000000','43000000-0000-0000-0000-000000000001',1,5,current_date+7,'Cycle test','12000000-0000-0000-0000-000000000001')$$,'customer and quotation are created transactionally');
select is((select count(*)::integer from public.customers where full_name='Hosted Cycle Customer'),1,'customer is created');
select is((select status from public.quotations where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'issued','quotation starts issued');
select lives_ok($$select public.accept_quotation((select id from public.quotations where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'12000000-0000-0000-0000-000000000001')$$,'quotation accepts from the UI actor');
select lives_ok($$select public.convert_quotation_to_invoice((select id from public.quotations where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'12000000-0000-0000-0000-000000000001')$$,'accepted quotation converts to invoice');
select is((select total_amount from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),5700::numeric,'invoice keeps discounted quotation total');
select lives_ok($$select public.submit_payment_proof((select id from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),3000,'bank_transfer','cycle/proof-one.png','CYCLE-ONE','12000000-0000-0000-0000-000000000001')$$,'explicit invoice payment proof is submitted');
select is((select status from public.payment_submissions where external_reference='CYCLE-ONE'),'pending','payment proof remains pending');

reset role;
select is((select count(*)::integer from public.payment_transactions where organization_id='22000000-0000-0000-0000-000000000001'),0,'pending proof creates no confirmed cash transaction');
set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select throws_ok($$select public.confirm_payment_submission((select id from public.payment_submissions where external_reference='CYCLE-ONE'),2000,'12000000-0000-0000-0000-000000000001','cycle-maker')$$,'P0001','maker cannot confirm own payment','payment maker cannot confirm');

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.confirm_payment_submission((select id from public.payment_submissions where external_reference='CYCLE-ONE'),2000,'12000000-0000-0000-0000-000000000002','cycle-confirm-one')$$,'different finance user confirms partial payment');
reset role;
select is((select count(*)::integer from public.payment_transactions where idempotency_key='cycle-confirm-one'),1,'payment transaction is created');
select is((select count(*)::integer from public.payment_allocations pa join public.payment_transactions pt on pt.id=pa.transaction_id where pt.idempotency_key='cycle-confirm-one'),1,'payment allocation is created');
select is((select status from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'partially_paid','invoice becomes partially paid');
select is((select count(*)::integer from public.sales_target_actuals where payment_transaction_id=(select id from public.payment_transactions where idempotency_key='cycle-confirm-one')),1,'sales target actual is created from confirmed cash');
select is((select count(*)::integer from public.sales_commission_entries where source_transaction_id=(select id from public.payment_transactions where idempotency_key='cycle-confirm-one')),1,'sales commission is created from confirmed cash');

select throws_ok($$insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,payment_method,proof_reference,submitted_by)
values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000002',(select customer_id from public.invoices where organization_id='22000000-0000-0000-0000-000000000001'),(select id from public.invoices where organization_id='22000000-0000-0000-0000-000000000001'),100,'cash','wrong-branch','12000000-0000-0000-0000-000000000001')$$,'23503',null,'payment cannot reference an invoice from another branch');
insert into public.customers(id,organization_id,home_branch_id,full_name,status,created_by) values('46000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','Other Customer','active','12000000-0000-0000-0000-000000000001');
select throws_ok($$insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,payment_method,proof_reference,submitted_by)
values('22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000001',(select id from public.invoices where organization_id='22000000-0000-0000-0000-000000000001'),100,'cash','wrong-customer','12000000-0000-0000-0000-000000000001')$$,'23503',null,'payment cannot reference an invoice from another customer');
insert into public.customers(id,organization_id,home_branch_id,full_name,status,created_by) values('46000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000002','32000000-0000-0000-0000-000000000003','Other Organization Customer','active','12000000-0000-0000-0000-000000000001');
select throws_ok($$insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,payment_method,proof_reference,submitted_by)
values('22000000-0000-0000-0000-000000000002','32000000-0000-0000-0000-000000000003','46000000-0000-0000-0000-000000000002',(select id from public.invoices where organization_id='22000000-0000-0000-0000-000000000001'),100,'cash','wrong-org','12000000-0000-0000-0000-000000000001')$$,'23503',null,'payment cannot reference an invoice from another organization');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.submit_payment_proof((select id from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),3700,'bank_transfer','cycle/proof-two.png','CYCLE-TWO','12000000-0000-0000-0000-000000000001')$$,'remaining invoice balance proof is submitted');
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.confirm_payment_submission((select id from public.payment_submissions where external_reference='CYCLE-TWO'),3700,'12000000-0000-0000-0000-000000000002','cycle-confirm-two')$$,'finance confirms remaining balance');
reset role;
select is((select status from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'paid','invoice becomes paid');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.create_activate_subscription_from_invoice((select id from public.invoices where customer_id=(select id from public.customers where full_name='Hosted Cycle Customer')),'43000000-0000-0000-0000-000000000001',current_date,'12000000-0000-0000-0000-000000000003')$$,'operations activates subscription from matching paid invoice');
reset role;
select is((select count(*)::integer from public.deferred_revenue_entries where entry_type='activation' and organization_id='22000000-0000-0000-0000-000000000001'),1,'activation creates deferred revenue entry');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.confirm_service_delivery((select id from public.planned_service_days where subscription_id=(select id from public.subscriptions where organization_id='22000000-0000-0000-0000-000000000001') order by service_date limit 1),'12000000-0000-0000-0000-000000000003')$$,'operations confirms delivered day');
reset role;
select is((select status from public.planned_service_days where subscription_id=(select id from public.subscriptions where organization_id='22000000-0000-0000-0000-000000000001') order by service_date limit 1),'confirmed_delivered','service day leaves pending state after confirmation');
select is((select count(*)::integer from public.revenue_entries where organization_id='22000000-0000-0000-0000-000000000001'),1,'delivery creates revenue entry');
select ok((select deferred_balance<contract_value from public.subscriptions where organization_id='22000000-0000-0000-0000-000000000001'),'delivery reduces deferred revenue');

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.request_refund((select invoice_id from public.subscriptions where organization_id='22000000-0000-0000-0000-000000000001'),(select id from public.subscriptions where organization_id='22000000-0000-0000-0000-000000000001'),500,'Customer cancellation','12000000-0000-0000-0000-000000000001')$$,'sales requests governed refund');
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select lives_ok($$select public.approve_refund((select id from public.refunds where organization_id='22000000-0000-0000-0000-000000000001'),'12000000-0000-0000-0000-000000000002')$$,'different finance user approves refund');
select lives_ok($$select public.pay_refund_and_clawback((select id from public.refunds where organization_id='22000000-0000-0000-0000-000000000001'),'12000000-0000-0000-0000-000000000002','refund-proof','cycle-refund')$$,'approved refund creates cash reversal');
reset role;
select is((select amount from public.payment_transactions where idempotency_key='cycle-refund'),-500::numeric,'refund transaction reverses confirmed cash');
select ok((select count(*)>0 from public.sales_commission_entries where entry_type='clawback' and organization_id='22000000-0000-0000-0000-000000000001'),'refund creates commission clawback');
select ok((select count(*)>=8 from public.domain_events where organization_id='22000000-0000-0000-0000-000000000001'),'commercial timeline records every major step');
select ok((select count(*)>0 from public.audit_logs where organization_id='22000000-0000-0000-0000-000000000001' and entity_type in('invoices','payment_transactions','subscriptions','refunds')),'audit log records commercial mutations');

select * from finish();
rollback;
