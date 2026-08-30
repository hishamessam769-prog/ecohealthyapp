begin;

do $hotfix$
declare v_definition text; v_old text := 'values(v_payment.id,v_invoice.id,least((p_payload->>''amount_received'')::numeric,v_invoice.total))'; v_new text := 'values(v_payment.id,v_invoice.id,least((p_payload->>''amount_received'')::numeric,v_invoice.total),p_actor_id)';
begin
  select pg_get_functiondef('public.eco_confirm_payment(uuid,jsonb)'::regprocedure) into v_definition;
  if position(v_new in v_definition)>0 then null;
  elsif position(v_old in v_definition)>0 then execute replace(v_definition,v_old,v_new);
  else raise exception 'ECO_PAYMENT_HOTFIX_PATTERN_NOT_FOUND'; end if;
end $hotfix$;

create or replace function public.eco_seed_ten_day_demo(p_actor_id uuid) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare
  v_org uuid; v_branch uuid; v_sales uuid; v_customer uuid; v_address uuid; v_zone uuid; v_window uuid;
  v_meal uuid; v_rider uuid; v_subscription uuid; v_credit uuid; v_plan uuid; v_version uuid; v_tier uuid;
  v_demand uuid; v_batch uuid; v_route uuid; v_day date; v_i integer; v_metric record;
begin
  perform public.eco_require_actor(p_actor_id,'system.demo.manage');
  select organization_id into strict v_org from public.eco_employees where id=p_actor_id;
  select id into strict v_branch from public.eco_branches where organization_id=v_org and active order by created_at limit 1;
  select id into strict v_sales from public.eco_employees where email='sales.demo@ecohealthy.invalid';
  select id into strict v_customer from public.eco_customers where customer_number='DEMO-CUS-002';
  select id into strict v_address from public.eco_customer_addresses where customer_id=v_customer order by created_at limit 1;
  select zone_id,delivery_window_id into strict v_zone,v_window from public.eco_customer_addresses where id=v_address;
  select id into strict v_meal from public.eco_meal_versions where status='APPROVED' order by effective_from desc limit 1;
  select r.id into strict v_rider from public.eco_riders r join public.eco_employees e on e.id=r.employee_id where e.email='rider.demo@ecohealthy.invalid';
  select s.id into strict v_subscription from public.eco_subscriptions s join public.eco_orders o on o.id=s.order_id where o.customer_id=v_customer limit 1;

  insert into public.eco_commission_plans(code,name,plan_scope)
  values('DEMO-SALES-PLAN','خطة عمولة المبيعات — Demo','INDIVIDUAL')
  on conflict(code) do update set active=true returning id into v_plan;
  insert into public.eco_commission_plan_versions(commission_plan_id,version_number,effective_from,status,eligible_sales_types,eligible_payment_methods,maturity_rule,fixed_maturity_days,minimum_fulfilled_percentage,approved_by,approved_at)
  values(v_plan,1,date_trunc('month',current_date)::date,'APPROVED',array['SUBSCRIPTION','RENEWAL'],array['CASH','INSTAPAY'],'BOTH_CONDITIONS_REQUIRED',5,50,p_actor_id,now())
  on conflict(commission_plan_id,version_number) do update set status='APPROVED',approved_by=p_actor_id,approved_at=now() returning id into v_version;
  insert into public.eco_commission_tiers(plan_version_id,min_achievement_percentage,max_achievement_percentage,commission_rate_percentage)
  values(v_version,0,60,0) on conflict do nothing;
  insert into public.eco_commission_tiers(plan_version_id,min_achievement_percentage,max_achievement_percentage,commission_rate_percentage)
  values(v_version,60,85,1.5) on conflict do nothing;
  insert into public.eco_commission_tiers(plan_version_id,min_achievement_percentage,max_achievement_percentage,commission_rate_percentage)
  values(v_version,85,100,1.75) on conflict do nothing;
  insert into public.eco_commission_tiers(plan_version_id,min_achievement_percentage,max_achievement_percentage,commission_rate_percentage)
  values(v_version,100,null,2) on conflict do nothing;
  select id into v_tier from public.eco_commission_tiers where plan_version_id=v_version order by min_achievement_percentage limit 1;
  select id into v_credit from public.eco_sales_credit_events where customer_id=v_customer order by occurred_at limit 1;
  if v_credit is not null then
    update public.eco_sales_credit_events set plan_version_id=v_version where id=v_credit and plan_version_id is null;
    insert into public.eco_commission_accruals(sales_credit_event_id,employee_id,plan_version_id,tier_id,period_start,commissionable_value,rate_percentage,accrued_amount,status)
    select id,employee_id,v_version,v_tier,period_start,commissionable_value,1.5,round(commissionable_value*.015,2),'PENDING_MATURITY'
    from public.eco_sales_credit_events where id=v_credit on conflict(sales_credit_event_id) do nothing;
  end if;

  insert into public.eco_rule_scores(subject_type,subject_id,score_type,rule_version,feature_snapshot,score,top_reasons,recommended_action)
  select 'subscription',v_subscription,'CHURN_RISK','demo-v1',jsonb_build_object('remaining_days',3,'complaints',1),.72,'["متبقي 3 أيام","شكوى مفتوحة"]','اتصال تجديد خلال 24 ساعة'
  where not exists(select 1 from public.eco_rule_scores where subject_id=v_subscription and score_type='CHURN_RISK');

  for v_i in 0..9 loop
    v_day:=current_date-v_i;
    insert into public.eco_production_demand(branch_id,service_date,slot_code,meal_version_id,size_code,required_quantity,source_snapshot,locked_at)
    values(v_branch,v_day,'LUNCH',v_meal,'REGULAR',18+v_i,jsonb_build_object('demo',true,'day_index',v_i),v_day+time '17:00')
    on conflict(branch_id,service_date,slot_code,meal_version_id,size_code) do update set required_quantity=excluded.required_quantity
    returning id into v_demand;
    select id into v_batch from public.eco_production_batches where idempotency_key='demo-history-batch-'||v_day;
    if v_batch is null then
      insert into public.eco_production_batches(branch_id,service_date,status,planned_by,started_at,produced_at,qa_released_at,closed_at,idempotency_key)
      values(v_branch,v_day,'CLOSED',p_actor_id,v_day+time '06:30',v_day+time '09:30',v_day+time '10:00',v_day+time '16:00','demo-history-batch-'||v_day) returning id into v_batch;
      insert into public.eco_production_batch_items(batch_id,demand_id,planned_quantity,actual_yield,waste_quantity,shortage_quantity)
      values(v_batch,v_demand,18+v_i,17+v_i,case when v_i%3=0 then 1 else 0 end,case when v_i%4=0 then 1 else 0 end);
      insert into public.eco_qa_checks(batch_id,check_type,result,temperature_c,notes,checked_by)
      values(v_batch,'FINAL_RELEASE','PASSED',4+(v_i::numeric/10),'سجل QA تجريبي ليوم التشغيل',p_actor_id);
    end if;
    select id into v_route from public.eco_routes where idempotency_key='demo-history-route-'||v_day;
    if v_route is null then
      insert into public.eco_routes(branch_id,route_date,zone_id,delivery_window_id,rider_id,status,assigned_at,dispatched_at,closed_at,idempotency_key,created_by)
      values(v_branch,v_day,v_zone,v_window,v_rider,'CLOSED',v_day+time '11:00',v_day+time '12:20',v_day+time '16:10','demo-history-route-'||v_day,p_actor_id) returning id into v_route;
      insert into public.eco_route_stops(route_id,fulfillment_group_key,customer_id,address_id,sequence_no,state,promised_start,promised_end,cod_amount,ready_at,assigned_at,dispatched_at,arrived_at,delivered_at)
      values(v_route,'demo-history-stop-'||v_day,v_customer,v_address,1,'DELIVERED',v_day+time '13:00',v_day+time '15:00',0,v_day+time '10:30',v_day+time '11:00',v_day+time '12:20',v_day+time '13:35',v_day+time '13:42');
    end if;
    insert into public.eco_audit_events(actor_id,action,entity_type,entity_id,occurred_at,source,reason,event_hash)
    values(p_actor_id,'DEMO_DAILY_CLOSE','operating_day',v_day::text,v_day+time '18:00','DEMO','إقفال يوم تشغيل تجريبي',encode(digest('demo-audit-'||v_day,'sha256'),'hex'))
    on conflict(event_hash) do nothing;
    for v_metric in select id,metric_code,version from public.eco_metric_definitions where metric_code in('MRR','ARR','CONTRIBUTION_MARGIN','DELIVERY_SLA','RENEWAL_RATE') loop
      insert into public.eco_kpi_snapshots(branch_id,metric_definition_id,period_start,period_end,value,numerator,denominator,definition_version,certification_status,plan_value,forecast_value,calculated_at,certified_by,certified_at)
      values(v_branch,v_metric.id,v_day,v_day,
        case v_metric.metric_code when 'MRR' then 185000+v_i*2500 when 'ARR' then (185000+v_i*2500)*12 when 'CONTRIBUTION_MARGIN' then 34.5+v_i/10.0 when 'DELIVERY_SLA' then 94-v_i/5.0 else 68+v_i/3.0 end,
        case when v_metric.metric_code in('DELIVERY_SLA','RENEWAL_RATE','CONTRIBUTION_MARGIN') then 94-v_i else null end,
        case when v_metric.metric_code in('DELIVERY_SLA','RENEWAL_RATE','CONTRIBUTION_MARGIN') then 100 else null end,
        v_metric.version,'CERTIFIED',case when v_metric.metric_code='MRR' then 200000 else null end,null,v_day+time '19:00',p_actor_id,v_day+time '19:05')
      on conflict(branch_id,metric_definition_id,period_start,certification_status) do nothing;
    end loop;
  end loop;
  insert into public.eco_notifications(employee_id,title,body,priority,entity_type,entity_id,deep_link,due_at)
  values(p_actor_id,'مراجعة عمولة تحت الاستحقاق','يوجد بيع مدفوع ينتظر اكتمال 50% من الاشتراك ومرور فترة الاحتفاظ.','HIGH','subscription',v_subscription,'/commissions',now()+interval '1 day')
  on conflict(employee_id,entity_type,entity_id,title) do nothing;
  return jsonb_build_object('seeded',true,'operating_days',10,'production_days',10,'delivery_days',10,'certified_kpi_days',10,'commission_dashboard',true,'audit_days',10);
end $$;

revoke all on function public.eco_seed_ten_day_demo(uuid) from public,anon,authenticated;
grant execute on function public.eco_seed_ten_day_demo(uuid) to service_role;
select pg_notify('pgrst','reload schema');
commit;
