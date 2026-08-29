begin;

do $hotfix$
declare
  v_definition text;
  v_old text := 'values(v_payment.id,v_invoice.id,least((p_payload->>''amount_received'')::numeric,v_invoice.total))';
  v_new text := 'values(v_payment.id,v_invoice.id,least((p_payload->>''amount_received'')::numeric,v_invoice.total),p_actor_id)';
begin
  select pg_get_functiondef('public.eco_confirm_payment(uuid,jsonb)'::regprocedure)
  into v_definition;

  if position(v_new in v_definition) > 0 then
    null;
  elsif position(v_old in v_definition) > 0 then
    execute replace(v_definition,v_old,v_new);
  else
    raise exception 'ECO_PAYMENT_HOTFIX_PATTERN_NOT_FOUND';
  end if;
end
$hotfix$;

insert into public.eco_schema_migrations(version,description,checksum)
values(
  '008_payment_allocation_hotfix',
  'Supply actor_id when allocating a verified payment',
  'sha256:eco-v5-008-payment-allocation-hotfix'
)
on conflict(version) do update
set description=excluded.description,
    checksum=excluded.checksum,
    applied_at=now();

select pg_notify('pgrst','reload schema');
commit;
