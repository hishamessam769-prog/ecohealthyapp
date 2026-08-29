begin;

create extension if not exists pgcrypto with schema extensions;
alter function public.eco_begin_idempotent(text,text,uuid,jsonb) set search_path=public,extensions,pg_temp;
alter function public.eco_bootstrap_first_admin(uuid,text,text,text) set search_path=public,extensions,pg_temp;
alter function public.eco_create_priced_invoice(uuid,jsonb) set search_path=public,extensions,pg_temp;

create or replace function public.eco_enrich_demo_data(p_actor_id uuid) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare
  v_org uuid; v_branch uuid; v_sales uuid; v_customer uuid; v_address uuid;
  v_package uuid; v_window uuid; v_zone uuid; v_bank uuid; v_meal uuid;
  v_invoice jsonb; v_payment uuid; v_invoice_id uuid; v_subscription uuid;
  v_demand uuid; v_batch uuid; v_rider_emp uuid; v_rider uuid; v_route uuid;
  v_fulfillment uuid; v_invoice_line uuid; v_ingredient uuid; v_source uuid:=gen_random_uuid();
begin
  perform public.eco_require_actor(p_actor_id,'system.demo.manage');
  select organization_id into strict v_org from public.eco_employees where id=p_actor_id;
  select id into strict v_branch from public.eco_branches where organization_id=v_org and active order by created_at limit 1;
  select id into strict v_sales from public.eco_employees where organization_id=v_org and is_demo and email='sales.demo@ecohealthy.invalid' limit 1;
  select id into strict v_package from public.eco_package_versions where status='APPROVED' order by effective_from desc limit 1;
  select id into strict v_window from public.eco_delivery_windows where branch_id=v_branch and active order by start_time limit 1;
  select id into strict v_zone from public.eco_zones where branch_id=v_branch and active order by code limit 1;
  select id into strict v_bank from public.eco_bank_accounts where branch_id=v_branch and active order by code limit 1;
  select id into strict v_meal from public.eco_meal_versions where status='APPROVED' order by effective_from desc limit 1;

  insert into public.eco_leads(branch_id,full_name,phone,email,source_code,stage,assigned_employee_id,created_by,first_contact_at,first_response_at,last_contact_at,next_action_at,notes,is_demo)
  select v_branch,x.full_name,x.phone,x.email,x.source_code,x.stage,v_sales,p_actor_id,now()-x.age,now()-x.age+interval '12 minutes',now()-interval '1 day',now()+interval '1 day',x.notes,true
  from (values
    ('سارة محمد — Demo','01090000101','sara.demo@ecohealthy.invalid','WHATSAPP','QUALIFIED',interval '4 days','تحتاج عرض باكدج Lunch'),
    ('محمود حسن — Demo','01090000102','mahmoud.demo@ecohealthy.invalid','META','PROPOSAL_SENT',interval '3 days','تم إرسال عرض السعر'),
    ('منى أحمد — Demo','01090000103','mona.demo@ecohealthy.invalid','REFERRAL','AWAITING_PAYMENT',interval '2 days','بانتظار تحويل InstaPay'),
    ('كريم علي — Demo','01090000104','karim.demo@ecohealthy.invalid','WEBSITE','NEW',interval '3 hours','Lead جديد يحتاج اتصال')
  ) as x(full_name,phone,email,source_code,stage,age,notes)
  where not exists(select 1 from public.eco_leads l where l.phone=x.phone);

  insert into public.eco_employee_sales_targets(employee_id,period_start,version_number,revenue_target,quantity_target,renewal_target,new_customer_target,status,approved_by,approved_at)
  values(v_sales,date_trunc('month',current_date)::date,1,120000,30,35000,20,'APPROVED',p_actor_id,now())
  on conflict(employee_id,period_start,version_number) do update set revenue_target=excluded.revenue_target,status='APPROVED',approved_by=p_actor_id,approved_at=now();

  insert into public.eco_customers(organization_id,customer_number,full_name,normalized_phone,phone_display,email,created_by,is_demo)
  values(v_org,'DEMO-CUS-002','دينا سامح — اشتراك نشط','01090000002','01090000002','dina.demo@ecohealthy.invalid',p_actor_id,true)
  on conflict(customer_number) do update set full_name=excluded.full_name
  returning id into v_customer;
  select id into v_address from public.eco_customer_addresses where customer_id=v_customer and is_demo limit 1;
  if v_address is null then
    insert into public.eco_customer_addresses(customer_id,address_line,zone_id,delivery_window_id,is_demo)
    values(v_customer,'مدينة نصر — عنوان اشتراك تجريبي',v_zone,v_window,true) returning id into v_address;
  end if;
  insert into public.eco_customer_assignments(customer_id,employee_id,assignment_type,effective_from,assigned_by)
  select v_customer,v_sales,'SALES_OWNER',current_date,p_actor_id
  where not exists(select 1 from public.eco_customer_assignments where customer_id=v_customer and assignment_type='SALES_OWNER' and effective_to is null);

  select i.id,p.id,s.id into v_invoice_id,v_payment,v_subscription
  from public.eco_invoices i join public.eco_orders o on o.id=i.order_id
  left join public.eco_payments p on p.invoice_id=i.id
  left join public.eco_subscriptions s on s.order_id=o.id
  where o.customer_id=v_customer order by i.created_at desc limit 1;
  if v_invoice_id is null then
    v_invoice:=public.eco_create_priced_invoice(p_actor_id,jsonb_build_object(
      'customer_id',v_customer,'order_type','SUBSCRIPTION','package_version_id',v_package,
      'start_date',current_date,'address_id',v_address,'delivery_window_id',v_window,
      'payment_method','CASH','payment_reference',null,'notes','اشتراك Demo مدفوع ومعتمد',
      'idempotency_key','demo-full-active-subscription-v1'));
    v_invoice_id:=(v_invoice->>'invoice_id')::uuid; v_payment:=(v_invoice->>'payment_id')::uuid;
    update public.eco_orders set sales_owner_id=v_sales,is_demo=true where id=(v_invoice->>'order_id')::uuid;
    update public.eco_invoices set is_demo=true where id=v_invoice_id;
    update public.eco_payments set is_demo=true where id=v_payment;
  end if;
  if not exists(select 1 from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.customer_id=v_customer) then
    v_invoice:=public.eco_confirm_payment(p_actor_id,jsonb_build_object(
      'payment_id',v_payment,'amount_received',(select total from public.eco_invoices where id=v_invoice_id),
      'currency','EGP','account_id',v_bank,'reference','DEMO-CASH-VERIFIED-001','payer','دينا سامح',
      'receipt_date',current_date,'idempotency_key','demo-full-confirm-payment-v1'));
  end if;
  select s.id into v_subscription from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.customer_id=v_customer limit 1;

  insert into public.eco_production_demand(branch_id,service_date,slot_code,meal_version_id,size_code,required_quantity,source_snapshot)
  select v_branch,current_date+1,'LUNCH',v_meal,'REGULAR',18,jsonb_build_object('demo',true,'subscriptions',12,'one_off',6)
  on conflict(branch_id,service_date,slot_code,meal_version_id,size_code) do update set required_quantity=18,source_snapshot=excluded.source_snapshot
  returning id into v_demand;
  select id into v_batch from public.eco_production_batches where idempotency_key='demo-full-batch-v1';
  if v_batch is null then
    insert into public.eco_production_batches(branch_id,service_date,status,planned_by,started_at,produced_at,qa_released_at,idempotency_key)
    values(v_branch,current_date+1,'QA_RELEASED',p_actor_id,now()-interval '2 hours',now()-interval '1 hour',now()-interval '30 minutes','demo-full-batch-v1') returning id into v_batch;
    insert into public.eco_production_batch_items(batch_id,demand_id,planned_quantity,actual_yield,waste_quantity,shortage_quantity)
    values(v_batch,v_demand,18,18,0,0);
    insert into public.eco_qa_checks(batch_id,check_type,result,temperature_c,notes,checked_by)
    values(v_batch,'FINAL_RELEASE','PASSED',4.2,'Demo QA release',p_actor_id);
  end if;

  insert into public.eco_ingredients(branch_id,code,name_ar,base_unit,min_stock)
  values(v_branch,'DEMO-CHICKEN','صدور دجاج — Demo','KG',10)
  on conflict(branch_id,code) do update set name_ar=excluded.name_ar returning id into v_ingredient;
  insert into public.eco_stock_movements(branch_id,ingredient_id,movement_type,quantity,unit_cost,source_type,source_id,idempotency_key,actor_id,notes)
  values(v_branch,v_ingredient,'RECEIPT',45,190,'demo_seed',v_source,'demo-stock-receipt-v1',p_actor_id,'رصيد مخزون تجريبي')
  on conflict(idempotency_key) do nothing;

  insert into public.eco_employees(organization_id,employee_number,full_name,email,status,is_demo)
  values(v_org,'DEMO-RIDER','أحمد — مندوب Demo','rider.demo@ecohealthy.invalid','ACTIVE',true)
  on conflict(employee_number) do update set full_name=excluded.full_name returning id into v_rider_emp;
  insert into public.eco_employee_role_assignments(employee_id,role_code,effective_from,approved,approved_by,approved_at,created_by)
  select v_rider_emp,'rider',current_date,true,p_actor_id,now(),p_actor_id
  where not exists(select 1 from public.eco_employee_role_assignments where employee_id=v_rider_emp and role_code='rider' and approved);
  insert into public.eco_riders(employee_id,vehicle_type,vehicle_plate,capacity_packs)
  values(v_rider_emp,'MOTORCYCLE','DEMO-01',40)
  on conflict(employee_id) do update set capacity_packs=40 returning id into v_rider;
  select id into v_route from public.eco_routes where idempotency_key='demo-full-route-v1';
  if v_route is null then
    insert into public.eco_routes(branch_id,route_date,zone_id,delivery_window_id,rider_id,status,assigned_at,idempotency_key,created_by)
    values(v_branch,current_date+1,v_zone,v_window,v_rider,'READY',now(),'demo-full-route-v1',p_actor_id) returning id into v_route;
    insert into public.eco_route_stops(route_id,fulfillment_group_key,customer_id,address_id,sequence_no,state,promised_start,promised_end,cod_amount,ready_at,assigned_at)
    values(v_route,'demo-stop-1',v_customer,v_address,1,'READY',(current_date+1)+time '13:00',(current_date+1)+time '15:00',0,now(),now());
  end if;

  select f.id into v_fulfillment from public.eco_fulfillments f where f.subscription_id=v_subscription order by f.service_date limit 1;
  select il.id into v_invoice_line from public.eco_invoice_lines il where il.invoice_id=v_invoice_id order by line_no limit 1;
  if v_fulfillment is not null and v_invoice_line is not null then
    insert into public.eco_revenue_schedules(invoice_line_id,fulfillment_id,allocated_consideration,recognized_amount,recognition_date,status)
    values(v_invoice_line,v_fulfillment,192.83,96.42,current_date,'PARTIALLY_RECOGNIZED')
    on conflict(invoice_line_id,fulfillment_id) do nothing;
  end if;
  insert into public.eco_notifications(employee_id,title,body,priority,entity_type,entity_id,deep_link,due_at)
  values(p_actor_id,'تم تثبيت Full Demo','أصبح لديك Leads وفاتورة Pending واشتراك نشط ومطبخ وQA ومخزون ومسار توصيل.','HIGH','subscription',v_subscription,'/',now())
  on conflict(employee_id,entity_type,entity_id,title) do nothing;
  return jsonb_build_object('installed',true,'mode','FULL_DEMO','active_subscription_id',v_subscription,'production_batch_id',v_batch,'route_id',v_route,'modules',jsonb_build_array('CRM','SALES','ACCOUNTING','SUBSCRIPTIONS','KITCHEN','QA','INVENTORY','DELIVERY'));
end $$;

revoke all on function public.eco_enrich_demo_data(uuid) from public,anon,authenticated;
grant execute on function public.eco_enrich_demo_data(uuid) to service_role;
select pg_notify('pgrst','reload schema');
commit;
