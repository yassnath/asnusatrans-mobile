begin;

delete from public.harga_per_ton_rules
where lower(coalesce(customer_name, '')) = ''
  and lower(coalesce(lokasi_muat, '')) = 'betoyo'
  and lower(coalesce(lokasi_bongkar, '')) = 'muncar';

insert into public.harga_per_ton_rules (
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
)
values
  (null, 'Betoyo', 'Muncar', 193.00, null, 110, true);

commit;
