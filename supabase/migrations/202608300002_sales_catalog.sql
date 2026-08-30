begin;

alter table public.eco_packages add column if not exists program_code text not null default 'GENERAL';
alter table public.eco_packages add column if not exists package_type_code text not null default 'LUNCH_ONLY';

create or replace function public.eco_save_catalog_price(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_branch uuid;
  v_program text:=upper(p_payload->>'program_code');
  v_type text:=upper(p_payload->>'package_type_code');
  v_code text;
  v_name text;
  v_package uuid;
  v_version uuid;
  v_version_no integer;
  v_book uuid;
  v_slot text;
begin
  perform public.eco_require_actor(p_actor_id,'catalog.manage');
  if v_program not in('WEIGHT_LOSS','MUSCLE_GAIN') then raise exception 'CATALOG_PROGRAM_INVALID'; end if;
  if v_type not in('LUNCH_ONLY','AM','BM','FULL_DAY') then raise exception 'CATALOG_PACKAGE_TYPE_INVALID'; end if;
  if (p_payload->>'service_days')::integer not in(6,12,18,24) then raise exception 'CATALOG_DAYS_INVALID'; end if;
  if upper(p_payload->>'size_code') not in('REGULAR','HERO') then raise exception 'CATALOG_SIZE_INVALID'; end if;
  if (p_payload->>'price')::numeric<=0 then raise exception 'CATALOG_PRICE_INVALID'; end if;
  select b.id into strict v_branch from public.eco_branches b join public.eco_employees e on e.organization_id=b.organization_id where e.id=p_actor_id and b.active order by b.created_at limit 1;
  v_code:=v_program||'-'||v_type;
  v_name:=case v_program when 'WEIGHT_LOSS' then 'Weight Loss' else 'Muscle Gain' end||' — '||case v_type when 'LUNCH_ONLY' then 'Lunch Only' when 'FULL_DAY' then 'Full Day' else v_type||' Package' end;
  insert into public.eco_packages(branch_id,code,name_ar,sale_category,program_code,package_type_code)
  values(v_branch,v_code,v_name,'SUBSCRIPTION',v_program,v_type)
  on conflict(branch_id,code) do update set name_ar=excluded.name_ar,program_code=excluded.program_code,package_type_code=excluded.package_type_code,active=true
  returning id into v_package;
  select pv.id into v_version from public.eco_package_versions pv where pv.package_id=v_package and pv.service_days=(p_payload->>'service_days')::integer and pv.size_code=upper(p_payload->>'size_code') and pv.status='APPROVED' order by pv.version_number desc limit 1;
  if v_version is null then
    select coalesce(max(version_number),0)+1 into v_version_no from public.eco_package_versions where package_id=v_package;
    insert into public.eco_package_versions(package_id,version_number,size_code,service_days,frequency_policy,effective_from,status,approved_by,approved_at)
    values(v_package,v_version_no,upper(p_payload->>'size_code'),(p_payload->>'service_days')::integer,'DAILY',(p_payload->>'effective_from')::date,'APPROVED',p_actor_id,now()) returning id into v_version;
    for v_slot in select unnest(case v_type when 'LUNCH_ONLY' then array['LUNCH'] when 'AM' then array['BREAKFAST','LUNCH'] when 'BM' then array['LUNCH','DINNER'] else array['BREAKFAST','LUNCH','DINNER','SNACK'] end) loop
      insert into public.eco_package_slots(package_version_id,slot_code,quantity,obligation_weight) values(v_version,v_slot,1,1) on conflict do nothing;
    end loop;
  end if;
  select id into v_book from public.eco_price_books where branch_id=v_branch and code='ECO-LIVE-PRICE' and status='APPROVED' and effective_from<=(p_payload->>'effective_from')::date and(effective_to is null or effective_to>=(p_payload->>'effective_from')::date) order by effective_from desc limit 1;
  if v_book is null then
    insert into public.eco_price_books(branch_id,code,name,effective_from,status,approved_by,approved_at) values(v_branch,'ECO-LIVE-PRICE','ECO Healthy Price List',(p_payload->>'effective_from')::date,'APPROVED',p_actor_id,now()) returning id into v_book;
  end if;
  insert into public.eco_price_book_items(price_book_id,package_version_id,unit_price,tax_rate)
  values(v_book,v_version,(p_payload->>'price')::numeric,coalesce(nullif(p_payload->>'tax_rate','')::numeric,0))
  on conflict(price_book_id,package_version_id) do update set unit_price=excluded.unit_price,tax_rate=excluded.tax_rate;
  insert into public.eco_audit_events(actor_id,action,entity_type,entity_id,source,after_redacted,event_hash)
  values(p_actor_id,'CATALOG_PRICE_SAVED','package_version',v_version::text,'SERVER',jsonb_build_object('price',p_payload->>'price','effective_from',p_payload->>'effective_from'),encode(extensions.digest(v_version::text||clock_timestamp()::text,'sha256'),'hex'));
  return jsonb_build_object('package_id',v_package,'package_version_id',v_version,'price_book_id',v_book);
end $$;

drop view if exists public.eco_catalog_v;
create view public.eco_catalog_v with(security_invoker=false) as
select pv.id,p.code package_code,p.name_ar package_name,p.program_code,p.package_type_code,pv.version_number,pv.size_code,pv.service_days,string_agg(ps.slot_code||'×'||ps.quantity,', ' order by ms.sort_order) meal_slots,pv.frequency_policy,pbi.unit_price price,pv.effective_from,pv.status,concat_ws(' ',p.code,p.name_ar,p.program_code,p.package_type_code,pv.size_code,pv.service_days) search_text
from public.eco_package_versions pv
join public.eco_packages p on p.id=pv.package_id
join public.eco_package_slots ps on ps.package_version_id=pv.id
join public.eco_meal_slots ms on ms.code=ps.slot_code
left join lateral(select pbi2.* from public.eco_price_book_items pbi2 join public.eco_price_books pb on pb.id=pbi2.price_book_id where pbi2.package_version_id=pv.id and pb.status='APPROVED' and pb.effective_from<=current_date and(pb.effective_to is null or pb.effective_to>=current_date) order by pb.effective_from desc limit 1)pbi on true
group by pv.id,p.id,pbi.unit_price;

revoke all on function public.eco_save_catalog_price(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.eco_save_catalog_price(uuid,jsonb) to service_role;
revoke all on public.eco_catalog_v from public,anon,authenticated;
grant select on public.eco_catalog_v to service_role;

insert into public.eco_schema_migrations(version,description,checksum)
values('010_sales_catalog','Editable ECO package matrix and effective price list','sha256:eco-v5-010-sales-catalog')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();
select pg_notify('pgrst','reload schema');
commit;
