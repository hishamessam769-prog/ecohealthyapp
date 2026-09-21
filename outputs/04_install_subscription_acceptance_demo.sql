-- Eco Healthy ERP — subscription acceptance demo data.
-- Development/Staging only. Requires migration 0012 and completed /setup.
-- Every record created here is marked is_demo = true and can be removed safely.
begin;

do $$
declare
  v_org uuid; v_admin uuid; v_main uuid; v_second uuid; v_zone uuid; v_zone2 uuid;
  v_item record; v_package uuid; v_version uuid; v_customer uuid; v_invoice uuid; v_subscription uuid; v_day uuid;
  v_service_days integer; v_price numeric(18,2); v_daily numeric(18,2); v_delivered integer; v_status text; v_i integer;
  v_project uuid; v_task uuid;
begin
  select organization_id,installed_by into v_org,v_admin from public.system_installations order by installed_at limit 1;
  if v_org is null then raise exception 'Complete /setup before installing subscription demo data'; end if;
  select id into v_main from public.branches where organization_id=v_org and code='MAIN';
  if v_main is null then raise exception 'MAIN branch is required'; end if;
  select id into v_second from public.branches where organization_id=v_org and id<>v_main order by created_at limit 1;
  if v_second is null then
    insert into public.branches(organization_id,code,name,status,created_by,is_demo)
    values(v_org,'DEMO_SECOND','الفرع التجريبي الثاني','active',v_admin,true) returning id into v_second;
  end if;
  if exists(select 1 from public.packages where organization_id=v_org and code='WL-LUNCH-06') then
    raise exception 'Subscription acceptance demo already exists. Run 03_remove_demo_data.sql first.';
  end if;

  insert into public.delivery_zones(organization_id,branch_id,code,name,delivery_fee,sort_order,is_demo) values
  (v_org,v_main,'ZONE-1','Zone 1 — التجمع والرحاب',50,1,true),
  (v_org,v_main,'ZONE-2','Zone 2 — مدينة نصر ومصر الجديدة',60,2,true),
  (v_org,v_main,'ZONE-3','Zone 3 — المعادي والمقطم',70,3,true),
  (v_org,v_second,'ZONE-4','Zone 4 — الشيخ زايد وأكتوبر',80,4,true),
  (v_org,v_second,'ZONE-5','Zone 5 — الدقي والمهندسين',70,5,true),
  (v_org,v_second,'ZONE-6','Zone 6 — مناطق خاصة',100,6,true);
  select id into v_zone from public.delivery_zones where organization_id=v_org and code='ZONE-1';
  select id into v_zone2 from public.delivery_zones where organization_id=v_org and code='ZONE-4';

  insert into public.cancellation_reasons(organization_id,code,name,category,is_demo) values
  (v_org,'FOOD_QUALITY','جودة أوطعم الطعام غير مناسب','service',true),
  (v_org,'DELIVERY_TIME','وقت التوصيل غير مناسب','delivery',true),
  (v_org,'TRAVEL','العميل مسافر','personal',true),
  (v_org,'MEDICAL','سبب صحي أوتوصية طبية','medical',true),
  (v_org,'PRICE','السعر غير مناسب','commercial',true),
  (v_org,'MENU_VARIETY','تنوع المنيو غير مناسب','service',true),
  (v_org,'ADDRESS_CHANGE','تغيير السكن خارج نطاق التوصيل','delivery',true),
  (v_org,'DUPLICATE_PAYMENT','دفع مكرر','finance',true),
  (v_org,'SERVICE_PAUSE','إيقاف مؤقت بدل الإلغاء','retention',true),
  (v_org,'OTHER','سبب آخر موضح بالتفصيل','other',true)
  on conflict(organization_id,code) do update set name=excluded.name,category=excluded.category,is_active=true;

  -- Prices transcribed from the supplied Muscles Gain and Weight Loss tables.
  for v_item in select * from jsonb_to_recordset($prices$[
    {"code":"MG-LUNCH-06","name":"Muscles Gain — Lunch Meals — 6 Days","program":"muscles_gain","plan":"lunch","days":6,"meals":1,"price":2790},
    {"code":"MG-LUNCH-12","name":"Muscles Gain — Lunch Meals — 12 Days","program":"muscles_gain","plan":"lunch","days":12,"meals":1,"price":4993},
    {"code":"MG-LUNCH-18","name":"Muscles Gain — Lunch Meals — 18 Days","program":"muscles_gain","plan":"lunch","days":18,"meals":1,"price":5724},
    {"code":"MG-LUNCH-24","name":"Muscles Gain — Lunch Meals — 24 Days","program":"muscles_gain","plan":"lunch","days":24,"meals":1,"price":7128},
    {"code":"MG-AM-06","name":"Muscles Gain — AM Package — 6 Days","program":"muscles_gain","plan":"am","days":6,"meals":3,"price":3628},
    {"code":"MG-AM-12","name":"Muscles Gain — AM Package — 12 Days","program":"muscles_gain","plan":"am","days":12,"meals":3,"price":6388},
    {"code":"MG-AM-18","name":"Muscles Gain — AM Package — 18 Days","program":"muscles_gain","plan":"am","days":18,"meals":3,"price":7673},
    {"code":"MG-AM-24","name":"Muscles Gain — AM Package — 24 Days","program":"muscles_gain","plan":"am","days":24,"meals":3,"price":9600},
    {"code":"MG-PM-06","name":"Muscles Gain — PM Package — 6 Days","program":"muscles_gain","plan":"pm","days":6,"meals":3,"price":3640},
    {"code":"MG-PM-12","name":"Muscles Gain — PM Package — 12 Days","program":"muscles_gain","plan":"pm","days":12,"meals":3,"price":6551},
    {"code":"MG-PM-18","name":"Muscles Gain — PM Package — 18 Days","program":"muscles_gain","plan":"pm","days":18,"meals":3,"price":7838},
    {"code":"MG-PM-24","name":"Muscles Gain — PM Package — 24 Days","program":"muscles_gain","plan":"pm","days":24,"meals":3,"price":9783},
    {"code":"MG-FULL-06","name":"Muscles Gain — FullDay — 6 Days","program":"muscles_gain","plan":"full_day","days":6,"meals":5,"price":4478},
    {"code":"MG-FULL-12","name":"Muscles Gain — FullDay — 12 Days","program":"muscles_gain","plan":"full_day","days":12,"meals":5,"price":7946},
    {"code":"MG-FULL-18","name":"Muscles Gain — FullDay — 18 Days","program":"muscles_gain","plan":"full_day","days":18,"meals":5,"price":9787},
    {"code":"MG-FULL-24","name":"Muscles Gain — FullDay — 24 Days","program":"muscles_gain","plan":"full_day","days":24,"meals":5,"price":12255},
    {"code":"WL-LUNCH-06","name":"Weight Loss — Lunch Meals — 6 Days","program":"weight_loss","plan":"lunch","days":6,"meals":1,"price":2225},
    {"code":"WL-LUNCH-12","name":"Weight Loss — Lunch Meals — 12 Days","program":"weight_loss","plan":"lunch","days":12,"meals":1,"price":3266},
    {"code":"WL-LUNCH-18","name":"Weight Loss — Lunch Meals — 18 Days","program":"weight_loss","plan":"lunch","days":18,"meals":1,"price":4418},
    {"code":"WL-LUNCH-24","name":"Weight Loss — Lunch Meals — 24 Days","program":"weight_loss","plan":"lunch","days":24,"meals":1,"price":5305},
    {"code":"WL-AM-06","name":"Weight Loss — AM Package — 6 Days","program":"weight_loss","plan":"am","days":6,"meals":3,"price":3063},
    {"code":"WL-AM-12","name":"Weight Loss — AM Package — 12 Days","program":"weight_loss","plan":"am","days":12,"meals":3,"price":4661},
    {"code":"WL-AM-18","name":"Weight Loss — AM Package — 18 Days","program":"weight_loss","plan":"am","days":18,"meals":3,"price":6367},
    {"code":"WL-AM-24","name":"Weight Loss — AM Package — 24 Days","program":"weight_loss","plan":"am","days":24,"meals":3,"price":7777},
    {"code":"WL-PM-06","name":"Weight Loss — PM Package — 6 Days","program":"weight_loss","plan":"pm","days":6,"meals":3,"price":3075},
    {"code":"WL-PM-12","name":"Weight Loss — PM Package — 12 Days","program":"weight_loss","plan":"pm","days":12,"meals":3,"price":4824},
    {"code":"WL-PM-18","name":"Weight Loss — PM Package — 18 Days","program":"weight_loss","plan":"pm","days":18,"meals":3,"price":6531},
    {"code":"WL-PM-24","name":"Weight Loss — PM Package — 24 Days","program":"weight_loss","plan":"pm","days":24,"meals":3,"price":7960},
    {"code":"WL-FULL-06","name":"Weight Loss — FullDay — 6 Days","program":"weight_loss","plan":"full_day","days":6,"meals":5,"price":3913},
    {"code":"WL-FULL-12","name":"Weight Loss — FullDay — 12 Days","program":"weight_loss","plan":"full_day","days":12,"meals":5,"price":6219},
    {"code":"WL-FULL-18","name":"Weight Loss — FullDay — 18 Days","program":"weight_loss","plan":"full_day","days":18,"meals":5,"price":8480},
    {"code":"WL-FULL-24","name":"Weight Loss — FullDay — 24 Days","program":"weight_loss","plan":"full_day","days":24,"meals":5,"price":10432}
  ]$prices$::jsonb) as x(code text,name text,program text,plan text,days integer,meals integer,price numeric)
  loop
    insert into public.packages(organization_id,code,name,description,program_code,meal_plan_code,created_by,is_demo)
    values(v_org,v_item.code,v_item.name,'بيانات أسعار تجريبية من الجداول المعتمدة',v_item.program,v_item.plan,v_admin,true)
    returning id into v_package;
    insert into public.package_versions(package_id,version_number,effective_from,currency,price,service_days,meals_per_day,freeze_policy,cancellation_policy,status,created_by,is_demo)
    values(v_package,1,current_date,'EGP',v_item.price,v_item.days,v_item.meals,jsonb_build_object('replacement_days',true,'meal_plan',v_item.plan),jsonb_build_object('refund_basis','remaining_service_days'), 'active',v_admin,true);
  end loop;

  insert into public.meal_menu_days(organization_id,day_number,breakfast,lunch,dinner,snack_1,snack_2,delivery_note,is_demo) values
  (v_org,1,'Omelet and Cheese','Chicken Texas','Beef Burger','Chocolate Cookies','Canned Juice',null,true),
  (v_org,2,'Turkish Wrap','Chicken Burger','Texas Roll','Coconut Muffin','Nuts',null,true),
  (v_org,3,'Cheese Toast with Zaatar','Chicken Cordon Bleu','Crispy Chicken Twister','Chocolate Muffin','Fruits',null,true),
  (v_org,4,'Tuna Sandwich','Beef Stroganoff','Chicken Kofta Sandwich','Potato Muffin','Canned Juice',null,true),
  (v_org,5,'Creamy Toast','Beef Balls with Brown Sauce','BBQ Chicken Sandwich','Cinnamon Cookies','Nuts',null,true),
  (v_org,6,'Yogurt Granola','Grilled Salmon','Beef Fajita Roll','Banana Cake','Fruits',null,true),
  (v_org,7,'Boiled Eggs','Chicken Alfredo','Chicken Hawawshi','Pancakes','Canned Juice',null,true),
  (v_org,8,'Turkish Sandwich','Shish Tawook','Chicken Burger Wrap','Chocolate Cookies','Nuts',null,true),
  (v_org,9,'Egg and Arugula Sandwich','Chicken Ranch','Grilled Chicken Roll','Coconut Muffin','Fruits',null,true),
  (v_org,10,'Creamy Toast','Beef Kofta','Beef Kofta Sandwich','Chocolate Muffin','Canned Juice',null,true),
  (v_org,11,'Omelet and Cheese','Mongolian Beef','Texas Sandwich','Potato Muffin','Nuts',null,true),
  (v_org,12,'Turkish Wrap','Grilled Fish','Beef Hawawshi','Cinnamon Cookies','Fruits',null,true),
  (v_org,13,'Cheese Toast with Zaatar','Chicken Sweet and Sour','Fajita Roll','Banana Cake','Canned Juice',null,true),
  (v_org,14,'Tuna Sandwich','Chicken Balls Piccata','Chicken Burger Wrap','Pancakes','Nuts',null,true),
  (v_org,15,'Creamy Toast','Chicken Pie','Crispy Chicken Twister','Chocolate Cookies','Fruits',null,true),
  (v_org,16,'Yogurt Granola','Beef Burger','Grilled Chicken Roll','Coconut Muffin','Canned Juice',null,true),
  (v_org,17,'Boiled Eggs','Pomegranate Molasses Kofta','Beef Burger Wrap','Chocolate Muffin','Nuts',null,true),
  (v_org,18,'Turkish Wrap','Creamy Lemon Salmon','Chicken Hawawshi','Potato Muffin','Fruits',null,true),
  (v_org,19,'Egg and Arugula Sandwich','Grilled Chicken','Texas Roll','Cinnamon Cookies','Canned Juice',null,true),
  (v_org,20,'Creamy Toast','Chicken Burger','Chicken Kofta Sandwich','Banana Cake','Nuts',null,true),
  (v_org,21,'Omelet and Cheese','Mix Grill','Fajita Roll','Pancakes','Fruits',null,true),
  (v_org,22,'Tuna Sandwich','Kabab Halla','Beef Burger Sandwich','Chocolate Cookies','Canned Juice',null,true),
  (v_org,23,'Yogurt Granola','Beef Balls with Brown Sauce','Beef Hawawshi','Coconut Muffin','Nuts',null,true),
  (v_org,24,'Boiled Eggs','Green Sauce Fish','Crispy Chicken Twister','Chocolate Muffin','Fruits',null,true),
  (v_org,25,'Turkish Wrap','Smoky Grilled Chicken','Chicken Burger Wrap','Potato Muffin','Canned Juice',null,true),
  (v_org,26,'Cheese Toast with Zaatar','Grilled Chicken','Grilled Chicken Roll','Cinnamon Cookies','Nuts',null,true),
  (v_org,27,'Creamy Toast','Chicken Curry','Texas Sandwich','Banana Cake','Fruits',null,true),
  (v_org,28,'Omelet and Cheese','Beef Pie','Beef Burger Wrap','Pancakes','Canned Juice',null,true),
  (v_org,29,'Egg and Arugula Sandwich','Grilled Liver with Pesto','Fajita Roll','Chocolate Cookies','Nuts',null,true),
  (v_org,30,'Yogurt Granola','Chicken Piccata','Chicken Hawawshi','Coconut Muffin','Fruits',null,true),
  (v_org,31,'Tuna Sandwich','Grilled Fish','Chicken Burger Sandwich','Chocolate Muffin','Canned Juice','الجمعة إجازة؛ تُرسل وجبات الجمعة مع الخميس حسب سياسة التشغيل',true);

  -- Twelve realistic subscribers, each with a paid invoice, address/GPS and a different operational state.
  for v_i in 1..12 loop
    select pv.id,pv.service_days,pv.price into v_version,v_service_days,v_price
    from public.package_versions pv join public.packages p on p.id=pv.package_id
    where p.organization_id=v_org and p.is_demo and p.code in('WL-LUNCH-06','WL-AM-12','WL-PM-18','WL-FULL-24','MG-LUNCH-12','MG-AM-18','MG-PM-24','MG-FULL-06')
    order by p.code offset ((v_i-1)%8) limit 1;
    v_delivered:=least(v_service_days-1,(v_i-1)%5);
    v_daily:=round(v_price/v_service_days,2);
    v_status:=case when v_i=3 then 'frozen' when v_i=11 then 'cancelled' when v_i=12 then 'completed' else 'active' end;
    insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,owner_user_id,created_by,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,'مشترك تجريبي '||lpad(v_i::text,2,'0'),'01090000'||lpad(v_i::text,3,'0'),'subscriber'||v_i||'.demo@example.com','active',v_admin,v_admin,true)
    returning id into v_customer;
    insert into public.customer_addresses(customer_id,label,address_line,area,city,latitude,longitude,delivery_notes,is_primary,zone_id,gps_url,delivery_contact_name,delivery_contact_mobile,delivery_window_start,delivery_window_end,delivery_time_confirmed,is_demo)
    values(v_customer,'المنزل','عمارة '||v_i||'، شارع تجريبي، شقة '||(v_i+2),case when v_i in(6,7,8) then 'الشيخ زايد' else 'التجمع الخامس' end,'القاهرة',30.00+v_i/1000.0,31.20+v_i/1000.0,case when v_i%3=0 then 'الاتصال قبل الوصول وعدم إضافة صوص حار' else 'التسليم على باب الشقة' end,true,case when v_i in(6,7,8) then v_zone2 else v_zone end,'https://maps.google.com/?q='||(30.00+v_i/1000.0)||','||(31.20+v_i/1000.0),'مشترك تجريبي '||v_i,'01090000'||lpad(v_i::text,3,'0'),('10:00'::time+(v_i%4)*interval '1 hour')::time,('12:00'::time+(v_i%4)*interval '1 hour')::time,true,true);
    insert into public.invoices(organization_id,branch_id,customer_id,status,total_amount,confirmed_paid_amount,created_by,issued_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,'paid',v_price,v_price,v_admin,now()-((v_i+2)||' days')::interval,true) returning id into v_invoice;
    insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,source_snapshot,is_demo)
    select v_invoice,v_version,p.name,1,v_price,v_price,jsonb_build_object('demo',true,'package_version_id',v_version),true from public.package_versions pv join public.packages p on p.id=pv.package_id where pv.id=v_version;
    insert into public.payment_transactions(organization_id,branch_id,customer_id,transaction_type,amount,currency,confirmed_by,idempotency_key,confirmed_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,'collection',v_price,'EGP',v_admin,'acceptance-demo-collection-'||v_i,now()-((v_i+1)||' days')::interval,true);
    insert into public.subscriptions(organization_id,branch_id,customer_id,invoice_id,package_version_id,status,starts_on,ends_on,purchased_service_days,delivered_service_days,contract_value,deferred_balance,recognized_revenue,daily_portions,operations_notes,meal_override,activated_by,activated_at,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_customer,v_invoice,v_version,v_status,current_date-v_delivered,current_date-v_delivered+v_service_days-1,v_service_days,case when v_status='completed' then v_service_days else v_delivered end,v_price,case when v_status='completed' then 0 else greatest(0,v_price-v_daily*v_delivered) end,case when v_status='completed' then v_price else least(v_price,v_daily*v_delivered) end,case when v_i=4 then 2 else 1 end,case when v_i=2 then 'بدون بصل — مراجعة المطبخ' when v_i=4 then 'حصتان اليوم للعميل وزوجته' when v_i=9 then 'حساسية مكسرات — بيانات تجريبية' else null end,case when v_i=9 then '{"exclude":["Nuts"],"replacement":"Fruits"}'::jsonb else '{}'::jsonb end,v_admin,now()-((v_i+1)||' days')::interval,true)
    returning id into v_subscription;
    if v_status<>'completed' then
      insert into public.planned_service_days(subscription_id,service_date,status,branch_id,portion_multiplier,operations_note,meal_override,is_demo)
      select v_subscription,current_date-v_delivered+g,
        case when g<v_delivered then 'confirmed_delivered' when v_status='cancelled' then 'cancelled' when v_status='frozen' and g=v_delivered then 'frozen' else 'planned' end,
        case when v_i in(6,7,8) then v_second else v_main end,case when v_i=4 and g=v_delivered then 2 else 1 end,
        case when v_i=2 then 'بدون بصل' when v_i=4 and g=v_delivered then 'حصتان اليوم' else null end,
        case when v_i=9 then '{"exclude":["Nuts"],"replacement":"Fruits"}'::jsonb else '{}'::jsonb end,true
      from generate_series(0,v_service_days-1) g;
    end if;
    insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
    values(v_org,case when v_i in(6,7,8) then v_second else v_main end,v_subscription,v_invoice,'activation',v_price,0,v_price,v_admin,'acceptance-demo-activation-'||v_i,true);
    if v_i=3 then
      insert into public.subscription_freezes(subscription_id,starts_on,ends_on,reason,status,approved_by,is_demo) values(v_subscription,current_date,current_date+2,'سفر قصير — تجريبي','approved',v_admin,true);
    end if;
    if v_i=10 then
      insert into public.refunds(organization_id,branch_id,customer_id,invoice_id,subscription_id,amount,reason,reason_code,status,requested_by,calculation_basis,recipient_method,recipient_account_name,recipient_account_reference,is_demo)
      values(v_org,v_main,v_customer,v_invoice,v_subscription,least(v_price-v_daily*v_delivered,v_daily*(v_service_days-v_delivered)),'وقت التوصيل غير مناسب','DELIVERY_TIME','requested',v_admin,jsonb_build_object('remaining_days',v_service_days-v_delivered,'daily_value',v_daily),'instapay','مشترك تجريبي 10','01090000010',true);
    end if;
  end loop;

  -- One pending payment proves that payment proof is not confirmed cash.
  select id into v_customer from public.customers where organization_id=v_org and mobile='01090000001';
  select pv.id,pv.price into v_version,v_price from public.package_versions pv join public.packages p on p.id=pv.package_id where p.organization_id=v_org and p.code='WL-LUNCH-06';
  insert into public.invoices(organization_id,branch_id,customer_id,status,total_amount,confirmed_paid_amount,created_by,is_demo)
  values(v_org,v_main,v_customer,'issued',v_price,0,v_admin,true) returning id into v_invoice;
  insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,is_demo) values(v_invoice,v_version,'Weight Loss — Lunch Meals — 6 Days',1,v_price,v_price,true);
  insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,payment_method,proof_reference,external_reference,status,submitted_by,is_demo)
  values(v_org,v_main,v_customer,v_invoice,v_price,'instapay','demo/payment-pending-proof.jpg','ACCEPTANCE-PENDING-001','pending',v_admin,true);

  insert into public.projects(organization_id,branch_id,name,description,owner_user_id,status,priority,is_strategic,starts_on,due_on,progress_percent,created_by,is_demo)
  values(v_org,v_main,'تشغيل الاشتراكات الصباحية — Demo','مشروع قبول تشغيلي لتوزيع مهام المبيعات والمالية والعمليات',v_admin,'active','high',true,current_date,current_date+14,45,v_admin,true)
  returning id into v_project;
  for v_i in 1..8 loop
    insert into public.tasks(organization_id,branch_id,project_id,title,detailed_description,task_type,related_entity_type,created_by,reviewer_user_id,priority,status,start_at,due_at,open_until_response,response_required,evidence_required,reviewer_approval_required,required_action,is_demo)
    values(v_org,v_main,v_project,(array['متابعة إثبات دفع مع العميل','مراجعة طلب Refund','تأكيد قائمة إنتاج اليوم','اتصال بتجديد قريب','مراجعة عنوان وGPS','اعتماد Skip اليوم','حل شكوى وقت التوصيل','تجهيز تقرير الاشتراكات'])[v_i],'مهمة تجريبية قابلة للتنفيذ والمراجعة داخل النظام',(array['customer_followup','refund','subscription','customer_followup','task','approval_request','complaint','internal_action'])[v_i],'subscription',v_admin,v_admin,case when v_i in(2,7) then 'high' else 'normal' end,case when v_i=6 then 'waiting_for_approval' when v_i=7 then 'blocked' else 'assigned' end,now(),case when v_i=8 then null else now()+(v_i||' hours')::interval end,v_i=4,true,v_i in(2,3),v_i in(2,6),case when v_i=3 then 'إرفاق كشف الإنتاج بعد التأكيد' else 'تنفيذ الإجراء وتسجيل الرد الرسمي' end,true)
    returning id into v_task;
    insert into public.task_assignments(organization_id,task_id,assignee_type,assignee_user_id,assigned_by,is_demo) values(v_org,v_task,'user',v_admin,v_admin,true);
    insert into public.task_activities(organization_id,task_id,activity_type,actor_user_id,details,is_demo) values(v_org,v_task,'assigned',v_admin,jsonb_build_object('demo',true),true);
  end loop;
end $$;

commit;

select 'Subscription acceptance demo installed: 32 price options, 31 menu days, 12 subscribers, queues and tasks.' as result;
