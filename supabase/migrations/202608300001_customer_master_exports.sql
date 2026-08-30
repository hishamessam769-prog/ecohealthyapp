begin;

create or replace function public.eco_create_customer(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_org uuid;
  v_customer uuid;
  v_address uuid;
  v_phone text;
  v_owner uuid;
begin
  perform public.eco_require_actor(p_actor_id,'customers.create');
  select organization_id into strict v_org from public.eco_employees where id=p_actor_id and status='ACTIVE';
  v_phone:=regexp_replace(p_payload->>'phone','[^0-9+]','','g');
  if length(v_phone)<10 then raise exception 'CUSTOMER_PHONE_INVALID'; end if;
  if nullif(p_payload->>'zone_id','') is null then raise exception 'CUSTOMER_ZONE_REQUIRED'; end if;
  v_owner:=coalesce(nullif(p_payload->>'sales_owner_id','')::uuid,p_actor_id);
  if not exists(select 1 from public.eco_employees where id=v_owner and status='ACTIVE') then raise exception 'SALES_OWNER_INVALID'; end if;

  insert into public.eco_customers(organization_id,customer_number,full_name,normalized_phone,phone_display,email,created_by)
  values(v_org,'CUS-'||lpad(nextval('public.eco_customer_number_seq')::text,7,'0'),trim(p_payload->>'full_name'),v_phone,trim(p_payload->>'phone'),nullif(trim(p_payload->>'email'),''),p_actor_id)
  returning id into v_customer;

  insert into public.eco_customer_addresses(customer_id,address_line,zone_id,latitude,longitude,map_url,delivery_window_id)
  values(
    v_customer,
    trim(p_payload->>'address_line'),
    (p_payload->>'zone_id')::uuid,
    nullif(p_payload->>'latitude','')::numeric,
    nullif(p_payload->>'longitude','')::numeric,
    nullif(trim(p_payload->>'map_url'),''),
    nullif(p_payload->>'delivery_window_id','')::uuid
  ) returning id into v_address;

  insert into public.eco_customer_assignments(customer_id,employee_id,assignment_type,effective_from,assigned_by)
  values(v_customer,v_owner,'SALES_OWNER',current_date,p_actor_id);

  if nullif(trim(p_payload->>'dietary_notes'),'') is not null then
    insert into public.eco_customer_dietary_rules(customer_id,rule_type,description,created_by)
    values(v_customer,'NOTE',trim(p_payload->>'dietary_notes'),p_actor_id);
  end if;

  insert into public.eco_customer_timeline(customer_id,event_type,entity_type,entity_id,summary,actor_id,metadata)
  values(v_customer,'CUSTOMER_CREATED','customer',v_customer,'تم إنشاء ملف العميل',p_actor_id,jsonb_build_object('address_id',v_address));
  insert into public.eco_audit_events(actor_id,action,entity_type,entity_id,source,after_redacted,event_hash)
  values(p_actor_id,'CUSTOMER_CREATED','customer',v_customer::text,'SERVER',jsonb_build_object('customer_number',(select customer_number from public.eco_customers where id=v_customer)),encode(extensions.digest(v_customer::text||clock_timestamp()::text,'sha256'),'hex'));
  return jsonb_build_object('customer_id',v_customer,'address_id',v_address);
end $$;

create or replace view public.eco_customer_directory_v with(security_invoker=false) as
select
  c.id,
  c.id customer_id,
  owner.employee_id scope_employee_id,
  c.customer_number,
  c.full_name,
  c.phone_display phone,
  c.email,
  c.status customer_status,
  address.address_line,
  z.name_ar zone_name,
  address.map_url,
  address.latitude,
  address.longitude,
  dw.name_ar delivery_window_name,
  employee.full_name sales_owner_name,
  (select count(*) from public.eco_subscriptions s where s.customer_id=c.id and s.status in('ACTIVE','PAUSED')) active_subscription_count,
  (select p.name_ar from public.eco_subscriptions s join public.eco_package_versions pv on pv.id=s.package_version_id join public.eco_packages p on p.id=pv.package_id where s.customer_id=c.id and s.status in('ACTIVE','PAUSED') order by s.created_at desc limit 1) current_plan_name,
  (select count(*) from public.eco_orders o where o.customer_id=c.id) total_orders,
  c.created_at,
  concat_ws(' ',c.customer_number,c.full_name,c.phone_display,c.email,address.address_line,z.name_ar) search_text
from public.eco_customers c
left join lateral(
  select ca.employee_id from public.eco_customer_assignments ca
  where ca.customer_id=c.id and ca.assignment_type='SALES_OWNER' and ca.effective_from<=current_date and(ca.effective_to is null or ca.effective_to>=current_date)
  order by ca.effective_from desc limit 1
) owner on true
left join public.eco_employees employee on employee.id=owner.employee_id
left join lateral(
  select a.* from public.eco_customer_addresses a where a.customer_id=c.id and a.active order by a.created_at desc limit 1
) address on true
left join public.eco_zones z on z.id=address.zone_id
left join public.eco_delivery_windows dw on dw.id=address.delivery_window_id;

create or replace view public.eco_customer_export_v with(security_invoker=false) as
select id,customer_id,scope_employee_id,customer_number,full_name,phone,email,address_line,zone_name,map_url,latitude,longitude,delivery_window_name,sales_owner_name,customer_status,current_plan_name,active_subscription_count,total_orders,created_at,search_text
from public.eco_customer_directory_v;

create or replace view public.eco_delivery_export_v with(security_invoker=false) as
select
  st.id,
  r.route_date,
  r.route_number,
  st.sequence_no,
  c.customer_number,
  c.full_name customer_name,
  c.phone_display phone,
  a.address_line,
  z.name_ar zone_name,
  w.name_ar delivery_window,
  coalesce(a.map_url,'https://maps.google.com/?q='||a.latitude||','||a.longitude) navigation_url,
  employee.full_name rider_name,
  (select count(*) from public.eco_stop_pack_units spu where spu.route_stop_id=st.id) pack_count,
  st.cod_amount,
  st.state stop_state,
  st.promised_start,
  st.promised_end,
  st.delivered_at
from public.eco_route_stops st
join public.eco_routes r on r.id=st.route_id
join public.eco_customers c on c.id=st.customer_id
join public.eco_customer_addresses a on a.id=st.address_id
join public.eco_zones z on z.id=r.zone_id
join public.eco_delivery_windows w on w.id=r.delivery_window_id
left join public.eco_riders rider on rider.id=r.rider_id
left join public.eco_employees employee on employee.id=rider.employee_id;

revoke all on public.eco_customer_directory_v,public.eco_customer_export_v,public.eco_delivery_export_v from public,anon,authenticated;
grant select on public.eco_customer_directory_v,public.eco_customer_export_v,public.eco_delivery_export_v to service_role;
revoke all on function public.eco_create_customer(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.eco_create_customer(uuid,jsonb) to service_role;

insert into public.eco_schema_migrations(version,description,checksum)
values('009_customer_master_exports','Customer master data, exact addresses and controlled Excel exports','sha256:eco-v5-009-customer-master-exports')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();

select pg_notify('pgrst','reload schema');
commit;
