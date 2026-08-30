begin;

create or replace function public.eco_create_route(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_cached jsonb;v_key text:=p_payload->>'idempotency_key';v_route uuid;v_rider uuid;v_stop uuid;v_sequence integer:=0;v_cod numeric;v_group record;v_count integer:=0;begin
  perform public.eco_require_actor(p_actor_id,'routes.manage');
  v_cached:=public.eco_begin_idempotent('CREATE_ROUTE',v_key,p_actor_id,p_payload);if v_cached is not null then return v_cached;end if;
  if nullif(p_payload->>'rider_employee_id','') is not null then select id into v_rider from public.eco_riders where employee_id=(p_payload->>'rider_employee_id')::uuid and active;end if;
  insert into public.eco_routes(branch_id,route_date,zone_id,delivery_window_id,rider_id,status,assigned_at,idempotency_key,created_by)
  select branch_id,(p_payload->>'route_date')::date,(p_payload->>'zone_id')::uuid,(p_payload->>'delivery_window_id')::uuid,v_rider,case when v_rider is null then 'PLANNED' else 'ASSIGNED' end,case when v_rider is null then null else now() end,v_key,p_actor_id from public.eco_zones where id=(p_payload->>'zone_id')::uuid returning id into v_route;
  for v_group in
    select f.customer_id,f.address_id,min(f.created_at) first_created
    from public.eco_fulfillments f join public.eco_customer_addresses a on a.id=f.address_id
    where f.delivery_date=(p_payload->>'route_date')::date and a.zone_id=(p_payload->>'zone_id')::uuid and f.delivery_window_id=(p_payload->>'delivery_window_id')::uuid and f.status in('QA_RELEASED','PACKED','READY_FOR_DISPATCH')
      and exists(select 1 from public.eco_pack_units pu where pu.fulfillment_id=f.id and pu.status in('PLANNED','PACKED','READY'))
      and not exists(select 1 from public.eco_stop_pack_units spu join public.eco_pack_units pu on pu.id=spu.pack_unit_id where pu.fulfillment_id=f.id)
    group by f.customer_id,f.address_id order by first_created
  loop
    v_sequence:=v_sequence+1;
    select coalesce(sum(greatest(i.total-coalesce((select sum(pa.amount) from public.eco_payment_allocations pa where pa.invoice_id=i.id),0),0)),0) into v_cod
    from public.eco_invoices i join public.eco_orders o on o.id=i.order_id
    where o.id in(select distinct f.order_id from public.eco_fulfillments f where f.customer_id=v_group.customer_id and f.address_id=v_group.address_id and f.delivery_date=(p_payload->>'route_date')::date)
      and exists(select 1 from public.eco_payments p where p.invoice_id=i.id and p.method='CASH' and p.status in('PENDING_PAYMENT','PENDING_VERIFICATION'));
    insert into public.eco_route_stops(route_id,fulfillment_group_key,customer_id,address_id,sequence_no,state,cod_amount,assigned_at)
    values(v_route,(p_payload->>'route_date')||':'||v_group.customer_id||':'||v_group.address_id,v_group.customer_id,v_group.address_id,v_sequence,case when v_rider is null then 'PLANNED' else 'ASSIGNED' end,v_cod,case when v_rider is null then null else now() end) returning id into v_stop;
    insert into public.eco_stop_pack_units(route_stop_id,pack_unit_id)
    select v_stop,pu.id from public.eco_pack_units pu join public.eco_fulfillments f on f.id=pu.fulfillment_id
    where f.customer_id=v_group.customer_id and f.address_id=v_group.address_id and f.delivery_date=(p_payload->>'route_date')::date and f.delivery_window_id=(p_payload->>'delivery_window_id')::uuid and pu.status in('PLANNED','PACKED','READY') on conflict do nothing;
    update public.eco_fulfillments set status='READY_FOR_DISPATCH' where customer_id=v_group.customer_id and address_id=v_group.address_id and delivery_date=(p_payload->>'route_date')::date and delivery_window_id=(p_payload->>'delivery_window_id')::uuid and status in('QA_RELEASED','PACKED');
    v_count:=v_count+1;
  end loop;
  return public.eco_finish_idempotent('CREATE_ROUTE',v_key,jsonb_build_object('route_id',v_route,'stop_count',v_count,'rider_assigned',v_rider is not null));
end $$;

create or replace function public.eco_dispatch_route(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_route uuid:=(p_payload->>'route_id')::uuid;v_count integer;begin
  perform public.eco_require_actor(p_actor_id,'routes.manage');
  update public.eco_routes set status='DISPATCHED',dispatched_at=coalesce(dispatched_at,now()) where id=v_route and rider_id is not null and status in('ASSIGNED','READY');
  if not found then raise exception 'ECO_ROUTE_NOT_READY_TO_DISPATCH'; end if;
  update public.eco_route_stops set state='DISPATCHED',dispatched_at=coalesce(dispatched_at,now()) where route_id=v_route and state in('PLANNED','ASSIGNED','READY');
  get diagnostics v_count=row_count;
  insert into public.eco_outbox_events(event_type,aggregate_type,aggregate_id,payload) values('ROUTE_DISPATCHED','route',v_route::text,jsonb_build_object('route_id',v_route,'stop_count',v_count));
  return jsonb_build_object('route_id',v_route,'stop_count',v_count,'status','DISPATCHED');
end $$;

drop view if exists public.eco_rider_today_route_v;
create view public.eco_rider_today_route_v with(security_invoker=false) as
select st.id,rd.employee_id rider_employee_id,r.id route_id,st.sequence_no,c.full_name customer_name,c.phone_display phone,a.address_line,w.name_ar delivery_window,(select count(*) from public.eco_stop_pack_units where route_stop_id=st.id) pack_count,st.cod_amount,st.state,coalesce(a.map_url,'https://maps.google.com/?q='||a.latitude||','||a.longitude) navigation_url
from public.eco_route_stops st join public.eco_routes r on r.id=st.route_id join public.eco_riders rd on rd.id=r.rider_id join public.eco_customers c on c.id=st.customer_id join public.eco_customer_addresses a on a.id=st.address_id join public.eco_delivery_windows w on w.id=r.delivery_window_id where r.route_date=current_date and r.status in('DISPATCHED','IN_PROGRESS','CLOSED');

revoke all on function public.eco_create_route(uuid,jsonb),public.eco_dispatch_route(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.eco_create_route(uuid,jsonb),public.eco_dispatch_route(uuid,jsonb) to service_role;
revoke all on public.eco_rider_today_route_v from public,anon,authenticated;
grant select on public.eco_rider_today_route_v to service_role;
insert into public.eco_schema_migrations(version,description,checksum)
values('014_delivery_workflow','Automatic stop creation, COD calculation, dispatch and rider-safe route details','sha256:eco-v5-014-delivery-workflow')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();
select pg_notify('pgrst','reload schema');
commit;
