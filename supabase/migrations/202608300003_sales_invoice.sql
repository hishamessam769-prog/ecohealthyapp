begin;

create table if not exists public.eco_sales_policies(
  organization_id uuid primary key references public.eco_organizations(id),
  max_sales_discount_percentage numeric(8,4) not null default 10 check(max_sales_discount_percentage between 0 and 100),
  updated_by uuid not null references public.eco_employees(id),
  updated_at timestamptz not null default now()
);
alter table public.eco_sales_policies enable row level security;
revoke all on public.eco_sales_policies from public,anon,authenticated;
grant select,insert,update on public.eco_sales_policies to service_role;

create or replace function public.eco_save_sales_policy(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_org uuid;begin
  perform public.eco_require_actor(p_actor_id,'catalog.manage');
  select organization_id into strict v_org from public.eco_employees where id=p_actor_id and status='ACTIVE';
  insert into public.eco_sales_policies(organization_id,max_sales_discount_percentage,updated_by)
  values(v_org,(p_payload->>'max_sales_discount_percentage')::numeric,p_actor_id)
  on conflict(organization_id) do update set max_sales_discount_percentage=excluded.max_sales_discount_percentage,updated_by=excluded.updated_by,updated_at=now();
  return jsonb_build_object('max_sales_discount_percentage',p_payload->>'max_sales_discount_percentage');
end $$;

create or replace function public.eco_create_sales_invoice(p_actor_id uuid,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare
  v_cached jsonb; v_key text:=p_payload->>'idempotency_key';
  v_customer public.eco_customers%rowtype; v_address public.eco_customer_addresses%rowtype;
  v_order uuid; v_line uuid; v_invoice uuid; v_payment uuid; v_branch uuid; v_package uuid; v_package_version uuid; v_price_item uuid;
  v_description text; v_sale_category text; v_currency char(3):='EGP'; v_subtotal numeric(14,2); v_discount numeric(14,2):=0;
  v_discount_percentage numeric(8,4):=coalesce(nullif(p_payload->>'discount_percentage','')::numeric,0); v_tax_rate numeric(8,4):=0;
  v_tax numeric(14,2); v_delivery numeric(14,2); v_total numeric(14,2); v_status text; v_snapshot jsonb; v_max_discount numeric(8,4); v_slot text;
begin
  perform public.eco_require_actor(p_actor_id,'orders.create');
  v_cached:=public.eco_begin_idempotent('CREATE_SALES_INVOICE',v_key,p_actor_id,p_payload); if v_cached is not null then return v_cached; end if;
  select * into strict v_customer from public.eco_customers where id=(p_payload->>'customer_id')::uuid and status='ACTIVE';
  if exists(select 1 from public.eco_employee_role_assignments era where era.employee_id=p_actor_id and era.role_code in('sales_agent','cs_agent') and era.approved and era.effective_from<=current_date and(era.effective_to is null or era.effective_to>=current_date))
     and not exists(select 1 from public.eco_customer_assignments ca where ca.customer_id=v_customer.id and ca.employee_id=p_actor_id and ca.effective_from<=current_date and(ca.effective_to is null or ca.effective_to>=current_date)) then
    raise exception 'ECO_CUSTOMER_OUT_OF_SCOPE' using errcode='42501';
  end if;
  select * into strict v_address from public.eco_customer_addresses where id=(p_payload->>'address_id')::uuid and customer_id=v_customer.id and active;
  select coalesce(sp.max_sales_discount_percentage,10) into v_max_discount from public.eco_employees e left join public.eco_sales_policies sp on sp.organization_id=e.organization_id where e.id=p_actor_id;
  if v_discount_percentage>v_max_discount then raise exception 'ECO_DISCOUNT_LIMIT_EXCEEDED: %',v_max_discount using errcode='23514'; end if;
  if v_discount_percentage>0 and nullif(p_payload->>'promotion_code','') is not null then raise exception 'ECO_ONE_DISCOUNT_METHOD_ONLY' using errcode='23514'; end if;

  if p_payload->>'pricing_mode'='CUSTOM' then
    select b.id into strict v_branch from public.eco_branches b join public.eco_employees e on e.organization_id=b.organization_id where e.id=p_actor_id and b.active order by b.created_at limit 1;
    v_description:=trim(p_payload->>'custom_description'); v_subtotal:=(p_payload->>'custom_price')::numeric; v_sale_category:=p_payload->>'order_type';
    if v_subtotal<=0 or v_description='' then raise exception 'ECO_CUSTOM_PRICE_INVALID'; end if;
    if p_payload->>'order_type' in('SUBSCRIPTION','RENEWAL','REACTIVATION') then
      insert into public.eco_packages(branch_id,code,name_ar,sale_category,active,program_code,package_type_code)
      values(v_branch,'CUSTOM-'||substr(replace(v_key,'-',''),1,22),v_description,'SUBSCRIPTION',false,'CUSTOM',coalesce(nullif(p_payload->>'custom_package_type',''),'LUNCH_ONLY')) returning id into v_package;
      insert into public.eco_package_versions(package_id,version_number,size_code,service_days,frequency_policy,effective_from,status,approved_by,approved_at)
      values(v_package,1,'REGULAR',(p_payload->>'custom_service_days')::integer,'DAILY',(p_payload->>'start_date')::date,'APPROVED',p_actor_id,now()) returning id into v_package_version;
      for v_slot in select unnest(case p_payload->>'custom_package_type' when 'AM' then array['BREAKFAST','LUNCH'] when 'BM' then array['LUNCH','DINNER'] when 'FULL_DAY' then array['BREAKFAST','LUNCH','DINNER','SNACK'] else array['LUNCH'] end) loop
        insert into public.eco_package_slots(package_version_id,slot_code,quantity,obligation_weight) values(v_package_version,v_slot,1,1);
      end loop;
    end if;
  else
    select pbi.id,pv.id,p.name_ar,p.sale_category,p.branch_id,pb.currency,pbi.unit_price,pbi.tax_rate
    into strict v_price_item,v_package_version,v_description,v_sale_category,v_branch,v_currency,v_subtotal,v_tax_rate
    from public.eco_price_book_items pbi
    join public.eco_price_books pb on pb.id=pbi.price_book_id and pb.status='APPROVED'
    join public.eco_package_versions pv on pv.id=pbi.package_version_id and pv.status='APPROVED'
    join public.eco_packages p on p.id=pv.package_id and p.active
    where pbi.package_version_id=(p_payload->>'package_version_id')::uuid and pb.effective_from<=current_date and(pb.effective_to is null or pb.effective_to>=current_date)
    order by pb.effective_from desc limit 1;
  end if;
  select default_delivery_fee into v_delivery from public.eco_zones where id=v_address.zone_id;
  if nullif(p_payload->>'promotion_code','') is not null then
    select least(case when discount_type='PERCENT' then v_subtotal*discount_value/100 else discount_value end,coalesce(max_discount,v_subtotal)) into v_discount
    from public.eco_promotions where code=p_payload->>'promotion_code' and active and approval_status='APPROVED' and starts_at<=now() and(ends_at is null or ends_at>=now());
    if v_discount is null then raise exception 'ECO_PROMOTION_INVALID'; end if;
  else v_discount:=round(v_subtotal*v_discount_percentage/100,2); end if;
  v_tax:=round((v_subtotal-v_discount)*v_tax_rate/100,2); v_total:=v_subtotal-v_discount+v_delivery+v_tax;
  v_status:=case when p_payload->>'payment_method'='CASH' then 'PENDING_PAYMENT' else 'PENDING_VERIFICATION' end;
  insert into public.eco_orders(branch_id,customer_id,order_type,status,sales_owner_id,service_start_date,address_id,delivery_window_id,notes,created_by)
  values(v_branch,v_customer.id,p_payload->>'order_type',v_status,p_actor_id,(p_payload->>'start_date')::date,v_address.id,(p_payload->>'delivery_window_id')::uuid,nullif(p_payload->>'notes',''),p_actor_id) returning id into v_order;
  insert into public.eco_order_lines(order_id,line_no,package_version_id,description,quantity,unit_price,discount_amount,tax_rate,delivery_fee,line_total,source_price_book_item_id)
  values(v_order,1,v_package_version,v_description,1,v_subtotal,v_discount,v_tax_rate,v_delivery,v_total,v_price_item) returning id into v_line;
  v_snapshot:=jsonb_build_object('order_id',v_order,'customer_id',v_customer.id,'pricing_mode',p_payload->>'pricing_mode','line',jsonb_build_object('description',v_description,'package_version_id',v_package_version,'unit_price',v_subtotal,'discount_percentage',v_discount_percentage,'discount',v_discount,'tax',v_tax,'delivery',v_delivery),'total',v_total,'created_at',now());
  insert into public.eco_invoices(branch_id,order_id,customer_id,currency,subtotal,discount_total,delivery_fees,tax_total,total,status,immutable_snapshot,snapshot_sha256)
  values(v_branch,v_order,v_customer.id,v_currency,v_subtotal,v_discount,v_delivery,v_tax,v_total,'OPEN',v_snapshot,encode(digest(v_snapshot::text,'sha256'),'hex')) returning id into v_invoice;
  insert into public.eco_invoice_lines(invoice_id,line_no,description,quantity,unit_price,discount_amount,tax_amount,line_total,performance_obligation_type,obligation_weight,source_order_line_id)
  values(v_invoice,1,v_description,1,v_subtotal,v_discount,v_tax,v_total-v_delivery,v_sale_category,1,v_line);
  insert into public.eco_payments(customer_id,invoice_id,method,declared_amount,currency,status,reference,received_at,created_by)
  values(v_customer.id,v_invoice,p_payload->>'payment_method',v_total,v_currency,v_status,nullif(p_payload->>'payment_reference',''),(p_payload->>'payment_date')::date,p_actor_id) returning id into v_payment;
  insert into public.eco_outbox_events(event_type,aggregate_type,aggregate_id,payload) values('INVOICE_CREATED','invoice',v_invoice::text,jsonb_build_object('invoice_id',v_invoice,'payment_id',v_payment,'status',v_status,'sales_owner_id',p_actor_id));
  return public.eco_finish_idempotent('CREATE_SALES_INVOICE',v_key,jsonb_build_object('order_id',v_order,'invoice_id',v_invoice,'payment_id',v_payment,'total',v_total,'status',v_status));
end $$;

drop view if exists public.eco_package_options_v;
create view public.eco_package_options_v as
select pv.id value,p.name_ar||' — '||pv.service_days||' يوم — '||pv.size_code||' — '||pbi.unit_price||' ج' label
from public.eco_package_versions pv join public.eco_packages p on p.id=pv.package_id and p.active
join lateral(select pbi2.* from public.eco_price_book_items pbi2 join public.eco_price_books pb on pb.id=pbi2.price_book_id where pbi2.package_version_id=pv.id and pb.status='APPROVED' and pb.effective_from<=current_date and(pb.effective_to is null or pb.effective_to>=current_date) order by pb.effective_from desc limit 1)pbi on true
where pv.status='APPROVED';

drop view if exists public.eco_accounting_verification_queue_v;
create view public.eco_accounting_verification_queue_v with(security_invoker=false) as
select p.id payment_id,p.id,i.id invoice_id,i.invoice_number,c.full_name customer_name,o.order_type,o.service_start_date,p.method,i.total expected_amount,p.declared_amount,p.reference,p.received_at payment_date,(select string_agg(il.description,', ' order by il.line_no) from public.eco_invoice_lines il where il.invoice_id=i.id) invoice_items,coalesce((select max(status) from public.eco_payment_proofs pp where pp.invoice_id=i.id),'MISSING') proof_status,exists(select 1 from public.eco_payments p2 where p2.id<>p.id and p2.method=p.method and p2.reference=p.reference and p2.status='VERIFIED') duplicate_reference,p.created_at
from public.eco_payments p join public.eco_invoices i on i.id=p.invoice_id join public.eco_orders o on o.id=i.order_id join public.eco_customers c on c.id=p.customer_id where p.status in('PENDING_PAYMENT','PENDING_VERIFICATION');

revoke all on function public.eco_save_sales_policy(uuid,jsonb),public.eco_create_sales_invoice(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.eco_save_sales_policy(uuid,jsonb),public.eco_create_sales_invoice(uuid,jsonb) to service_role;
revoke all on public.eco_package_options_v,public.eco_accounting_verification_queue_v from public,anon,authenticated;
grant select on public.eco_package_options_v,public.eco_accounting_verification_queue_v to service_role;

insert into public.eco_schema_migrations(version,description,checksum)
values('011_sales_invoice','Catalog or custom server-priced invoices, discount guardrails and accounting queue details','sha256:eco-v5-011-sales-invoice')
on conflict(version) do update set description=excluded.description,checksum=excluded.checksum,applied_at=now();
select pg_notify('pgrst','reload schema');
commit;
