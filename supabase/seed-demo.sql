-- ============================================================
-- بيانات تجريبية اختيارية فقط
-- شغّلها بعد schema.sql لو عايز تشوف الداشبورد والمطبخ ببيانات فورية.
-- ============================================================

do $$
declare
  v_client_1 uuid;
  v_client_2 uuid;
  v_order_1 uuid;
  v_order_2 uuid;
  v_sub_1 uuid;
  v_sub_2 uuid;
  v_day uuid;
  v_tomorrow date := ((now() at time zone 'Africa/Cairo')::date + 1);
begin
  insert into public.clients (full_name, phone, area, address, notes)
  values ('أحمد علي', '01000000001', 'مدينة نصر', 'شارع تجريبي 10', 'بدون بصل')
  on conflict (phone) do update set full_name = excluded.full_name
  returning id into v_client_1;

  insert into public.clients (full_name, phone, area, address, notes)
  values ('منة خالد', '01000000002', 'التجمع الخامس', 'شارع تجريبي 20', 'LC')
  on conflict (phone) do update set full_name = excluded.full_name
  returning id into v_client_2;

  insert into public.orders (
    order_number, client_id, package_name, total_days, total_price,
    payment_mode, payment_status, amount_paid, confirmed_at
  ) values (
    'DEMO-1001', v_client_1, 'Weight Loss Lunch', 24, 4800,
    'prepaid', 'paid', 4800, now()
  )
  on conflict (order_number) do update set client_id = excluded.client_id
  returning id into v_order_1;

  insert into public.orders (
    order_number, client_id, package_name, total_days, total_price,
    payment_mode, payment_status, amount_paid, confirmed_at
  ) values (
    'DEMO-1002', v_client_2, 'Full Day LC', 18, 5400,
    'pay_on_first_delivery', 'unpaid', 0, now()
  )
  on conflict (order_number) do update set client_id = excluded.client_id
  returning id into v_order_2;

  insert into public.subscriptions (
    client_id, order_id, program_name, total_days, start_date,
    status, delivery_frequency, delivery_notes
  ) values (
    v_client_1, v_order_1, 'Weight Loss Lunch', 24, v_tomorrow,
    'active', 'daily', 'قبل 3 العصر'
  )
  on conflict (order_id) do update set status = 'active'
  returning id into v_sub_1;

  insert into public.subscriptions (
    client_id, order_id, program_name, total_days, start_date,
    status, delivery_frequency, delivery_notes
  ) values (
    v_client_2, v_order_2, 'Full Day LC', 18, v_tomorrow,
    'active', 'daily', 'اتصال قبل الوصول'
  )
  on conflict (order_id) do update set status = 'active'
  returning id into v_sub_2;

  insert into public.fulfillment_days (
    subscription_id, day_number, service_date, production_date,
    meal_name, meal_type, quantity, status, locked_at
  ) values (
    v_sub_1, 1, v_tomorrow, v_tomorrow,
    'Grilled Chicken', 'standard', 1, 'locked', now()
  )
  on conflict (subscription_id, day_number) do update
    set production_date = excluded.production_date,
        service_date = excluded.service_date,
        status = 'locked',
        locked_at = now()
  returning id into v_day;

  insert into public.production_queue (
    fulfillment_day_id, subscription_id, client_id, production_date,
    client_name_snapshot, program_name_snapshot, meal_name_snapshot,
    meal_type, quantity, area_snapshot, delivery_note_snapshot
  ) values (
    v_day, v_sub_1, v_client_1, v_tomorrow,
    'أحمد علي', 'Weight Loss Lunch', 'Grilled Chicken',
    'standard', 1, 'مدينة نصر', 'قبل 3 العصر'
  ) on conflict (fulfillment_day_id) do nothing;

  insert into public.fulfillment_days (
    subscription_id, day_number, service_date, production_date,
    meal_name, meal_type, quantity, status, locked_at
  ) values (
    v_sub_2, 1, v_tomorrow, v_tomorrow,
    'LC Chicken', 'lc', 1, 'locked', now()
  )
  on conflict (subscription_id, day_number) do update
    set production_date = excluded.production_date,
        service_date = excluded.service_date,
        status = 'locked',
        locked_at = now()
  returning id into v_day;

  insert into public.production_queue (
    fulfillment_day_id, subscription_id, client_id, production_date,
    client_name_snapshot, program_name_snapshot, meal_name_snapshot,
    meal_type, quantity, area_snapshot, delivery_note_snapshot
  ) values (
    v_day, v_sub_2, v_client_2, v_tomorrow,
    'منة خالد', 'Full Day LC', 'LC Chicken',
    'lc', 1, 'التجمع الخامس', 'اتصال قبل الوصول'
  ) on conflict (fulfillment_day_id) do nothing;
end $$;

