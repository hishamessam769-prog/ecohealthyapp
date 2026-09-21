begin;

create extension if not exists pgtap with schema extensions;
select plan(25);

select has_table('public', 'projects', 'projects module exists');
select has_table('public', 'tasks', 'tasks module exists');
select has_table('public', 'leads', 'leads module exists');
select has_table('public', 'customers', 'customer 360 exists');
select has_table('public', 'complaints', 'complaints module exists');
select has_table('public', 'quotations', 'quotation module exists');
select has_table('public', 'invoices', 'invoice module exists');
select has_table('public', 'payment_submissions', 'payment proof workflow exists');
select has_table('public', 'subscriptions', 'subscriptions module exists');
select has_table('public', 'revenue_entries', 'deferred revenue ledger exists');
select has_table('public', 'sales_commission_entries', 'sales commissions exist');
select has_table('public', 'doctors', 'doctor directory exists');
select has_table('public', 'doctor_sessions', 'doctor sessions exist');
select has_table('public', 'doctor_commission_entries', 'doctor accounting exists');
select has_table('public', 'notification_messages', 'provider-neutral notifications exist');
select has_table('public', 'retry_queue', 'integration retry queue exists');

select has_function('public', 'convert_lead_to_customer', array['uuid','uuid'], 'lead conversion workflow exists');
select has_function('public', 'confirm_payment_submission', array['uuid','numeric','uuid','text'], 'maker-checker finance confirmation exists');
select has_function('public', 'activate_subscription', array['uuid','uuid'], 'subscription activation workflow exists');
select has_function('public', 'assign_session_round_robin', array['uuid','uuid'], 'round-robin assignment exists');
select has_function('public', 'create_mock_calendar_event', array['uuid'], 'idempotent calendar mock exists');
select has_function('public', 'validate_eco_healthy_installation', array[]::text[], 'installation validator exists');

select ok((select relrowsecurity from pg_class where oid = 'public.tasks'::regclass), 'tasks RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.customers'::regclass), 'customers RLS is enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.doctor_sessions'::regclass), 'doctor sessions RLS is enabled');

select * from finish();
rollback;
