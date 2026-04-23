begin;

delete from public.harga_per_ton_rules
where lower(coalesce(customer_name, '')) = ''
  and lower(coalesce(lokasi_muat, '')) in ('t. langon', 't langon', 'tlangon', 'langon')
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
  (null, 'T. Langon', 'Muncar', 110.00, null, 105, true);

delete from public.sangu_driver_rules
where lower(coalesce(lokasi_muat, '')) in ('t. langon', 't langon', 'tlangon', 'langon')
  and lower(coalesce(lokasi_bongkar, '')) = 'muncar';

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
values
  ('T. LANGON - MUNCAR', 'T. LANGON', 'MUNCAR', 1265000.00, true);

commit;
