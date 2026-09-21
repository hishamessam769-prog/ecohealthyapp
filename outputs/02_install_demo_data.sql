-- Eco Healthy ERP - Development/Staging demo data only.
-- Requires completed /setup flow. Every inserted row is marked is_demo = true.
begin;

do $$
declare
  v_org uuid; v_admin uuid; v_main uuid; v_second uuid;
  v_sales_staff uuid; v_finance_staff uuid;
  v_lead uuid; v_customer uuid; v_customer2 uuid; v_category uuid;
  v_package uuid; v_package_version uuid; v_quote uuid; v_invoice uuid; v_submission uuid; v_transaction uuid; v_subscription uuid;
  v_project uuid; v_task uuid;
  v_spec_nutrition uuid; v_spec_medical uuid; v_service_initial uuid; v_service_followup uuid; v_service_review uuid;
  v_service_version uuid; v_doctor1 uuid; v_doctor2 uuid; v_doctor3 uuid; v_session_paid uuid; v_session_completed uuid;
  v_doctor_policy uuid; v_doctor_policy_version uuid; v_sales_policy uuid;
begin
  select organization_id,installed_by into v_org,v_admin from public.system_installations order by installed_at limit 1;
  if v_org is null then raise exception 'Complete /setup before installing demo data'; end if;
  if exists(select 1 from public.customers where organization_id=v_org and is_demo) then raise exception 'Demo data already exists. Run 03_remove_demo_data.sql first.'; end if;

  select id into v_main from public.branches where organization_id=v_org and code='MAIN';
  insert into public.branches(organization_id,code,name,status,created_by,is_demo)
  values(v_org,'DEMO2','الفرع التجريبي الثاني','active',v_admin,true) returning id into v_second;

  insert into public.staff_directory(organization_id,branch_id,employee_code,display_name,role_label,is_demo)
  values(v_org,v_main,'DEMO-SALES-01','مندوب مبيعات تجريبي','Sales Representative',true) returning id into v_sales_staff;
  insert into public.staff_directory(organization_id,branch_id,employee_code,display_name,role_label,is_demo)
  values(v_org,v_second,'DEMO-FIN-01','محاسب تجريبي','Finance Accountant',true) returning id into v_finance_staff;

  insert into public.leads(organization_id,branch_id,full_name,mobile,email,source,status,temperature,assigned_user_id,assigned_staff_id,next_followup_at,created_by,is_demo)
  values(v_org,v_main,'عميل محتمل تجريبي','01000000001','lead.demo@example.com','Instagram','qualified','hot',v_admin,v_sales_staff,now()+interval '1 day',v_admin,true)
  returning id into v_lead;

  insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,source_lead_id,owner_user_id,created_by,is_demo)
  values(v_org,v_main,'أحمد تجريبي','01000000002','customer.demo@example.com','active',v_lead,v_admin,v_admin,true) returning id into v_customer;
  update public.leads set status='converted',converted_customer_id=v_customer where id=v_lead;
  insert into public.customers(organization_id,home_branch_id,full_name,mobile,email,status,owner_user_id,created_by,is_demo)
  values(v_org,v_second,'منى تجريبية','01000000003','customer2.demo@example.com','active',v_admin,v_admin,true) returning id into v_customer2;
  insert into public.customer_addresses(customer_id,label,address_line,area,city,is_primary,is_demo)
  values(v_customer,'المنزل','عنوان تجريبي - شارع 10','التجمع','القاهرة',true,true);
  insert into public.customer_preferences(customer_id,preference_type,value,visibility,created_by,is_demo) values
  (v_customer,'like','وجبات نباتية','all_staff',v_admin,true),(v_customer,'dislike','طعام حار','operations',v_admin,true);
  insert into public.customer_allergies(customer_id,allergen,severity,notes,verified_by,verified_at,is_demo)
  values(v_customer,'Peanuts','severe','بيانات تجريبية فقط',v_admin,now(),true);
  insert into public.customer_timeline(organization_id,customer_id,event_type,title,related_type,related_id,actor_user_id,is_demo)
  values(v_org,v_customer,'lead.converted','تحويل العميل المحتمل','lead',v_lead,v_admin,true);

  insert into public.complaint_categories(organization_id,code,name,default_sla_hours,is_demo)
  values(v_org,'DEMO_QUALITY','جودة الخدمة - تجريبي',24,true) returning id into v_category;
  insert into public.complaints(organization_id,branch_id,customer_id,category_id,reason,details,severity,status,owner_user_id,due_at,created_by,is_demo)
  values(v_org,v_main,v_customer,v_category,'تأخر الرد','شكوى تجريبية لا تخص عميلًا حقيقيًا','normal','investigating',v_admin,now()+interval '12 hours',v_admin,true);
  insert into public.cancellation_reasons(organization_id,code,name,category,is_demo)
  values(v_org,'DEMO_PRICE','السعر - تجريبي','commercial',true);

  insert into public.packages(organization_id,code,name,description,created_by,is_demo)
  values(v_org,'DEMO_ECO30','Eco 30 Demo','باقة تجريبية لمدة 30 يومًا',v_admin,true) returning id into v_package;
  insert into public.package_versions(package_id,version_number,effective_from,currency,price,service_days,meals_per_day,status,created_by,is_demo)
  values(v_package,1,current_date,'EGP',6000,30,3,'active',v_admin,true) returning id into v_package_version;
  insert into public.quotations(organization_id,branch_id,customer_id,status,currency,subtotal,discount_amount,valid_until,created_by,is_demo)
  values(v_org,v_main,v_customer,'accepted','EGP',6000,300,current_date+7,v_admin,true) returning id into v_quote;
  insert into public.quotation_lines(quotation_id,package_version_id,description,quantity,unit_price,discount_percent,price_snapshot,is_demo)
  values(v_quote,v_package_version,'Eco 30 Demo',1,6000,5,jsonb_build_object('package_version_id',v_package_version,'price',6000),true);
  insert into public.invoices(organization_id,branch_id,customer_id,quotation_id,status,total_amount,confirmed_paid_amount,created_by,is_demo)
  values(v_org,v_main,v_customer,v_quote,'paid',5700,5700,v_admin,true) returning id into v_invoice;
  insert into public.invoice_lines(invoice_id,package_version_id,description,quantity,unit_price,line_total,source_snapshot,is_demo)
  values(v_invoice,v_package_version,'Eco 30 Demo',1,5700,5700,jsonb_build_object('quotation_id',v_quote),true);
  insert into public.payment_submissions(organization_id,branch_id,customer_id,invoice_id,claimed_amount,currency,payment_method,proof_reference,external_reference,status,submitted_by,reviewed_by,reviewed_at,confirmed_amount,is_demo)
  values(v_org,v_main,v_customer,v_invoice,5700,'EGP','bank_transfer','demo/payment-proof.png','DEMO-PAY-001','confirmed',v_admin,null,now(),5700,true) returning id into v_submission;

  insert into public.sales_commission_policies(organization_id,name,applies_to_role_code,is_demo)
  values(v_org,'Demo confirmed cash policy','sales_representative',true) returning id into v_sales_policy;
  insert into public.sales_commission_policy_versions(policy_id,version_number,method,value,effective_from,created_by,is_demo)
  values(v_sales_policy,1,'confirmed_cash_percent',3,current_date,v_admin,true);
  insert into public.payment_transactions(organization_id,branch_id,customer_id,submission_id,transaction_type,amount,currency,confirmed_by,idempotency_key,is_demo)
  values(v_org,v_main,v_customer,v_submission,'collection',5700,'EGP',v_admin,'demo-collection-001',true) returning id into v_transaction;
  insert into public.payment_allocations(organization_id,transaction_id,invoice_id,allocation_type,amount,allocated_by,is_demo)
  values(v_org,v_transaction,v_invoice,'invoice',5700,v_admin,true);

  insert into public.subscriptions(organization_id,branch_id,customer_id,invoice_id,package_version_id,status,starts_on,ends_on,purchased_service_days,delivered_service_days,contract_value,deferred_balance,recognized_revenue,activated_by,activated_at,is_demo)
  values(v_org,v_main,v_customer,v_invoice,v_package_version,'active',current_date,current_date+29,30,1,5700,5510,190,v_admin,now(),true) returning id into v_subscription;
  insert into public.planned_service_days(subscription_id,service_date,status,branch_id,is_demo)
  select v_subscription,current_date+g,'planned',v_main,true from generate_series(0,6) g;
  update public.planned_service_days set status='confirmed_delivered' where subscription_id=v_subscription and service_date=current_date;
  insert into public.service_delivery_confirmations(planned_service_day_id,subscription_id,status,confirmed_by,is_demo)
  select id,v_subscription,'confirmed_delivered',v_admin,true from public.planned_service_days where subscription_id=v_subscription and service_date=current_date;
  insert into public.revenue_entries(organization_id,subscription_id,delivery_confirmation_id,entry_type,amount,entry_date,created_by,idempotency_key,is_demo)
  select v_org,v_subscription,id,'recognition',190,current_date,v_admin,'demo-revenue-001',true from public.service_delivery_confirmations where subscription_id=v_subscription;
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  values(v_org,v_main,v_subscription,v_invoice,'activation',5700,0,5700,v_admin,'demo-deferred-activation',true);
  insert into public.deferred_revenue_entries(organization_id,branch_id,subscription_id,invoice_id,delivery_confirmation_id,entry_type,deferred_delta,recognized_delta,balance_after,created_by,idempotency_key,is_demo)
  select v_org,v_main,v_subscription,v_invoice,id,'recognition',-190,190,5510,v_admin,'demo-deferred-recognition',true from public.service_delivery_confirmations where subscription_id=v_subscription;

  insert into public.projects(organization_id,branch_id,name,description,owner_user_id,status,priority,is_strategic,starts_on,due_on,progress_percent,created_by,is_demo)
  values(v_org,v_main,'مشروع إطلاق تجريبي','مشروع لاختبار المهام والمتابعات',v_admin,'active','high',true,current_date,current_date+30,35,v_admin,true) returning id into v_project;
  insert into public.tasks(organization_id,branch_id,project_id,title,detailed_description,task_type,related_entity_type,related_entity_id,created_by,reviewer_user_id,priority,status,start_at,due_at,open_until_response,response_required,evidence_required,reviewer_approval_required,required_action,is_demo)
  values(v_org,v_main,v_project,'متابعة العميل بعد العرض','اتصال رسمي وتسجيل الرد','customer_followup','customer',v_customer,v_admin,v_admin,'high','assigned',now(),now()+interval '1 day',true,true,true,true,'تسجيل رد العميل وإرفاق دليل',true) returning id into v_task;
  insert into public.task_assignments(organization_id,task_id,assignee_type,assignee_user_id,assigned_by,is_demo)
  values(v_org,v_task,'user',v_admin,v_admin,true);
  insert into public.task_followups(task_id,contact_method,contact_at,contact_outcome,customer_response,next_action,next_followup_at,customer_interest,created_by,is_demo)
  values(v_task,'phone',now(),'answered','مهتم ويطلب متابعة','إرسال تفاصيل الباقة',now()+interval '1 day','high',v_admin,true);

  insert into public.specialties(organization_id,code,name,is_demo) values(v_org,'DEMO_NUTRITION','Nutrition - Demo',true) returning id into v_spec_nutrition;
  insert into public.specialties(organization_id,code,name,is_demo) values(v_org,'DEMO_MEDICAL','Medical Review - Demo',true) returning id into v_spec_medical;
  insert into public.doctors(organization_id,full_name,mobile,email,qualifications,languages,consultation_types,online_enabled,onsite_enabled,standard_session_price,status,maximum_sessions_per_day,break_minutes,rating,is_demo)
  values(v_org,'د. سارة تجريبية','01010000001','doctor1.demo@example.com','Clinical Nutritionist',array['Arabic','English'],array['Initial','Follow-up'],true,true,700,'active',8,15,4.8,true) returning id into v_doctor1;
  insert into public.doctors(organization_id,full_name,mobile,email,qualifications,languages,consultation_types,online_enabled,onsite_enabled,standard_session_price,status,maximum_sessions_per_day,break_minutes,rating,is_demo)
  values(v_org,'د. عمر تجريبي','01010000002','doctor2.demo@example.com','Medical Reviewer',array['Arabic'],array['Medical Review'],true,true,800,'active',6,20,4.6,true) returning id into v_doctor2;
  insert into public.doctors(organization_id,full_name,mobile,email,qualifications,languages,consultation_types,online_enabled,onsite_enabled,standard_session_price,status,maximum_sessions_per_day,break_minutes,rating,is_demo)
  values(v_org,'د. ليلى تجريبية','01010000003','doctor3.demo@example.com','Nutrition Specialist',array['Arabic','English'],array['Premium'],true,false,900,'active',5,15,4.9,true) returning id into v_doctor3;
  insert into public.doctor_specialties(doctor_id,specialty_id,is_primary,is_demo) values(v_doctor1,v_spec_nutrition,true,true),(v_doctor2,v_spec_medical,true,true),(v_doctor3,v_spec_nutrition,true,true);
  insert into public.doctor_branches(doctor_id,branch_id,online_allowed,onsite_allowed,is_demo) values(v_doctor1,v_main,true,true,true),(v_doctor2,v_main,true,true,true),(v_doctor3,v_second,true,false,true);
  insert into public.doctor_services(organization_id,code,name,specialty_id,is_demo) values(v_org,'DEMO_INITIAL','Initial Consultation',v_spec_nutrition,true) returning id into v_service_initial;
  insert into public.doctor_services(organization_id,code,name,specialty_id,is_demo) values(v_org,'DEMO_FOLLOWUP','Follow-up Consultation',v_spec_nutrition,true) returning id into v_service_followup;
  insert into public.doctor_services(organization_id,code,name,specialty_id,is_demo) values(v_org,'DEMO_REVIEW','Medical Review',v_spec_medical,true) returning id into v_service_review;
  insert into public.doctor_service_versions(service_id,version_number,duration_minutes,customer_price,commission_type,commission_value,branch_id,delivery_mode,requires_prepayment,active_from,is_demo)
  values(v_service_initial,1,45,700,'fixed',250,v_main,'both',true,current_date,true) returning id into v_service_version;
  insert into public.doctor_service_versions(service_id,version_number,duration_minutes,customer_price,commission_type,commission_value,branch_id,delivery_mode,requires_prepayment,active_from,is_demo)
  values(v_service_followup,1,30,500,'percent_net',30,v_main,'online',true,current_date,true),(v_service_review,1,60,800,'fixed',300,v_main,'both',true,current_date,true);
  insert into public.doctor_availability_rules(doctor_id,branch_id,day_of_week,start_time,end_time,session_duration_minutes,break_minutes,delivery_mode,maximum_daily_sessions,minimum_notice_minutes,effective_from,is_demo)
  values(v_doctor1,v_main,extract(dow from current_date+1)::integer,'09:00','17:00',45,15,'both',8,120,current_date,true),
        (v_doctor2,v_main,extract(dow from current_date+1)::integer,'10:00','16:00',60,20,'both',6,120,current_date,true),
        (v_doctor3,v_second,extract(dow from current_date+1)::integer,'12:00','18:00',45,15,'online',5,120,current_date,true);
  insert into public.doctor_slots(doctor_id,branch_id,starts_at,ends_at,delivery_mode,status,is_demo)
  select case when g%3=0 then v_doctor3 when g%2=0 then v_doctor2 else v_doctor1 end,
    case when g%3=0 then v_second else v_main end,
    date_trunc('day',now()+interval '1 day')+interval '9 hours'+g*interval '30 minutes',
    date_trunc('day',now()+interval '1 day')+interval '9 hours'+g*interval '30 minutes'+interval '30 minutes',
    case when g%3=0 then 'online' else 'onsite' end,'available',true from generate_series(0,19) g;

  insert into public.doctor_sessions(organization_id,branch_id,customer_id,doctor_id,service_version_id,invoice_id,payment_transaction_id,delivery_mode,status,scheduled_start,scheduled_end,brief_reason,created_by,is_demo)
  values(v_org,v_main,v_customer,v_doctor1,v_service_version,v_invoice,v_transaction,'online','scheduled',date_trunc('day',now()+interval '2 days')+interval '10 hours',date_trunc('day',now()+interval '2 days')+interval '10 hours 45 minutes','Demo paid booking',v_admin,true) returning id into v_session_paid;
  insert into public.doctor_sessions(organization_id,branch_id,customer_id,doctor_id,service_version_id,invoice_id,payment_transaction_id,delivery_mode,status,scheduled_start,scheduled_end,brief_reason,created_by,completed_at,is_demo)
  values(v_org,v_main,v_customer2,v_doctor2,v_service_version,v_invoice,v_transaction,'onsite','completed',date_trunc('day',now()-interval '1 day')+interval '12 hours',date_trunc('day',now()-interval '1 day')+interval '12 hours 45 minutes','Demo completed session',v_admin,now()-interval '1 day',true) returning id into v_session_completed;
  insert into public.doctor_sessions(organization_id,branch_id,customer_id,doctor_id,service_version_id,delivery_mode,status,scheduled_start,scheduled_end,brief_reason,created_by,is_demo) values
  (v_org,v_main,v_customer,v_doctor1,v_service_version,'onsite','customer_cancelled',date_trunc('day',now()-interval '2 days')+interval '14 hours',date_trunc('day',now()-interval '2 days')+interval '14 hours 45 minutes','Demo cancelled',v_admin,true),
  (v_org,v_main,v_customer2,v_doctor2,v_service_version,'online','no_show',date_trunc('day',now()-interval '3 days')+interval '15 hours',date_trunc('day',now()-interval '3 days')+interval '15 hours 45 minutes','Demo no-show',v_admin,true);
  insert into public.session_notes(session_id,doctor_id,attendance,start_time,end_time,outcome,customer_goals,clinical_note,customer_visible_summary,sales_recommendation,followup_required,completed_at,is_demo)
  values(v_session_completed,v_doctor2,'attended',now()-interval '1 day 45 minutes',now()-interval '1 day','Completed successfully','Improve nutrition','Restricted demo clinical note','جلسة ناجحة','Recommend Eco 30 Demo',true,now()-interval '1 day',true);
  insert into public.doctor_recommendations(organization_id,session_id,doctor_id,customer_id,package_version_id,attribution_expires_at,sales_user_id,customer_decision,confirmed_payment_transaction_id,commission_status,is_demo)
  values(v_org,v_session_completed,v_doctor2,v_customer2,v_package_version,now()+interval '30 days',v_admin,'accepted',v_transaction,'eligible',true);
  insert into public.session_feedback(session_id,session_rating,doctor_rating,booking_experience,punctuality,helpfulness,recommendation_score,comment,consent_to_share,is_demo)
  values(v_session_completed,5,5,4,5,5,9,'تجربة تجريبية ممتازة',true,true);

  insert into public.doctor_commission_policies(organization_id,doctor_id,service_id,name,is_demo)
  values(v_org,v_doctor2,v_service_initial,'Demo fixed session commission',true) returning id into v_doctor_policy;
  insert into public.doctor_commission_policy_versions(policy_id,version_number,method,value,effective_from,notes_required,is_demo)
  values(v_doctor_policy,1,'fixed_session',250,current_date-30,true,true) returning id into v_doctor_policy_version;
  insert into public.doctor_commission_entries(organization_id,doctor_id,session_id,policy_version_id,entry_type,basis_amount,amount,status,reviewed_by,approved_by,is_demo)
  values(v_org,v_doctor2,v_session_completed,v_doctor_policy_version,'session',800,250,'approved',v_admin,null,true);
  insert into public.doctor_statements(organization_id,doctor_id,period_start,period_end,gross_eligible,adjustments,clawbacks,paid_amount,outstanding_amount,status,is_demo)
  values(v_org,v_doctor2,date_trunc('month',current_date)::date,(date_trunc('month',current_date)+interval '1 month'-interval '1 day')::date,250,0,0,0,250,'under_review',true);

  insert into public.integration_accounts(organization_id,provider,display_name,status,configuration,is_demo) values
  (v_org,'mock','Mock Calendar/Meet','connected','{"mode":"mock"}'::jsonb,true),
  (v_org,'email','Mock Email','connected','{"mode":"mock"}'::jsonb,true),
  (v_org,'whatsapp','Mock WhatsApp','connected','{"mode":"mock"}'::jsonb,true);
  perform public.create_mock_calendar_event(v_session_paid);
  insert into public.notification_messages(organization_id,branch_id,recipient_user_id,channel,related_type,related_id,subject,body,status,idempotency_key,is_demo)
  values(v_org,v_main,v_admin,'in_app','task',v_task,'مهمة جديدة','تم إسناد متابعة عميل تجريبية','delivered','demo-task-notification',true),
        (v_org,v_main,v_admin,'email','doctor_session',v_session_paid,'Booking Confirmed','Mock email - no external message was sent','queued','demo-session-email',true);
end $$;

commit;

select 'Demo data installed. All records created by this file have is_demo = true.' as result;
