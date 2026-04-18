begin;

update public.sangu_driver_rules
set
  lokasi_muat = 'BATANG',
  lokasi_bongkar = 'T. LANGON',
  nominal = 3400000.00,
  is_active = true,
  updated_at = now()
where lower(tempat) = lower('BATANG - T. LANGON');

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
select
  'BATANG - T. LANGON',
  'BATANG',
  'T. LANGON',
  3400000.00,
  true
where not exists (
  select 1
  from public.sangu_driver_rules
  where lower(tempat) = lower('BATANG - T. LANGON')
);

commit;
