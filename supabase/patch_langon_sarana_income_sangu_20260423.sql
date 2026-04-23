begin;

delete from public.harga_per_ton_rules
where lower(coalesce(customer_name, '')) = ''
  and lower(coalesce(lokasi_muat, '')) in ('t. langon', 't langon', 'tlangon', 'langon')
  and lower(coalesce(lokasi_bongkar, '')) in ('muncar', 'sarana');

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
  (null, 'T. Langon', 'Muncar', 187.50, null, 100, true),
  (null, 'T. Langon', 'Sarana', 110.00, null, 105, true);

delete from public.sangu_driver_rules
where lower(coalesce(lokasi_muat, '')) in ('t. langon', 't langon', 'tlangon', 'langon')
  and lower(coalesce(lokasi_bongkar, '')) in ('muncar', 'sarana');

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
values
  ('T. LANGON - SARANA', 'T. LANGON', 'SARANA', 1265000.00, true);

commit;
