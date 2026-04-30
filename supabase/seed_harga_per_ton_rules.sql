-- Seed harga / ton dari file hargaperkilo.xlsx
-- Aman dijalankan berulang (idempotent untuk route + customer yang sama).
begin;

create table if not exists public.harga_per_ton_rules (
  id uuid primary key default gen_random_uuid(),
  customer_name text,
  lokasi_muat text,
  lokasi_bongkar text not null,
  harga_per_ton numeric(14,2) not null default 0,
  flat_total numeric(14,2),
  priority int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.harga_per_ton_rules
  add column if not exists customer_name text,
  add column if not exists flat_total numeric(14,2);

drop index if exists harga_per_ton_rules_route_lower_unique;
create unique index if not exists harga_per_ton_rules_route_customer_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );

with incoming(
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
) as (
  values
    (null, null, 'Purwosari', 80.00, null, 100, true),
    (null, null, 'Safelock', 50.00, null, 100, true),
    (null, null, 'Muncar', 187.50, null, 100, true),
    (null, null, 'Sarana', 110.00, null, 105, true),
    (null, null, 'Tanggulangin', 55.00, null, 100, true),
    (null, null, 'Pare', 80.00, null, 100, true),
    (null, null, 'Singosari', 85.00, null, 100, true),
    (null, null, 'Batang', 235.00, null, 100, true),
    ('Bornava', null, 'Batang', 225.00, null, 220, true),
    ('Giono', 'Nganjuk', 'Driyo', 0.00, 1600000.00, 250, true),
    ('Hasan', 'T. Langon', 'T. Langon', 0.00, 200000.00, 260, true),
    ('Unergi', null, 'Royal', 43.00, null, 210, true),
    (null, null, 'Tuban', 90.00, null, 100, true),
    (null, null, 'Probolinggo', 90.00, null, 100, true),
    (null, null, 'Mojoagung', 80.00, null, 100, true),
    (null, null, 'Behaestex', 65.00, null, 100, true),
    (null, null, 'Romo', 15.00, null, 100, true),
    (null, null, 'Tongas', 80.00, null, 100, true),
    (null, null, 'Kediri', 85.00, null, 100, true),
    (null, null, 'Sudali', 58.00, null, 100, true),
    (null, null, 'MKP', 50.00, null, 100, true),
    (null, null, 'Kendal', 175.00, null, 100, true),
    (null, null, 'SGM', 43.00, null, 100, true),
    (null, null, 'Bricon', 55.00, null, 100, true),
    (null, null, 'Lawang', 80.00, null, 100, true),
    (null, null, 'Sentong', 20.00, null, 100, true),
    (null, null, 'Kletek', 43.00, null, 100, true),
    (null, null, 'Bululawang', 110.00, null, 100, true),
    (null, null, 'Dorang', 35.00, null, 100, true),
    (null, null, 'Mojokerto', 60.00, null, 100, true),
    (null, null, 'Molindo', 72.00, null, 100, true),
    (null, null, 'Gema', 80.00, null, 100, true),
    (null, null, 'Gempol', 55.00, null, 100, true),
    (null, null, 'Bumindo', 55.00, null, 120, true),
    (null, null, 'Temanggung', 165.00, null, 120, true),
    (null, null, 'Danliris', 155.00, null, 120, true),
    (null, 'T. Langon', 'Surya Warna / Sukoharjo', 165.00, null, 125, true),
    (null, null, 'Sragen', 145.00, null, 100, true),
    (null, null, 'KIG', 43.00, null, 100, true),
    (null, null, 'TIM', 187.50, null, 100, true),
    (null, null, 'Semarang', 165.00, null, 100, true),
    (null, null, 'KSI', 240.00, null, 100, true),
    (null, 'Betoyo', 'Probolinggo', 95.00, null, 100, true),
    (null, 'Betoyo', 'Tongas', 88.00, null, 100, true),
    (null, 'Betoyo', 'Mojoagung', 87.00, null, 100, true),
    (null, 'Betoyo', 'Muncar', 195.00, null, 110, true),
    (null, 'Betoyo', 'Surya Warna / Sukoharjo', 170.00, null, 130, true),
    (null, 'Betoyo', 'T. Langon', 90.00, null, 100, true),
    (null, 'Betoyo', 'Blitar', 125.00, null, 100, true)
), normalized as (
  select
    nullif(trim(customer_name), '') as customer_name,
    nullif(trim(lokasi_muat), '') as lokasi_muat,
    trim(lokasi_bongkar) as lokasi_bongkar,
    harga_per_ton,
    flat_total,
    priority,
    is_active
  from incoming
)
delete from public.harga_per_ton_rules t
using normalized n
where lower(coalesce(t.customer_name, '')) = lower(coalesce(n.customer_name, ''))
  and lower(coalesce(t.lokasi_muat, '')) = lower(coalesce(n.lokasi_muat, ''))
  and lower(t.lokasi_bongkar) = lower(n.lokasi_bongkar);

with incoming(
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
) as (
  values
    (null, null, 'Purwosari', 80.00, null, 100, true),
    (null, null, 'Safelock', 50.00, null, 100, true),
    (null, null, 'Muncar', 187.50, null, 100, true),
    (null, null, 'Sarana', 110.00, null, 105, true),
    (null, null, 'Tanggulangin', 55.00, null, 100, true),
    (null, null, 'Pare', 80.00, null, 100, true),
    (null, null, 'Singosari', 85.00, null, 100, true),
    (null, null, 'Batang', 235.00, null, 100, true),
    ('Bornava', null, 'Batang', 225.00, null, 220, true),
    ('Giono', 'Nganjuk', 'Driyo', 0.00, 1600000.00, 250, true),
    ('Hasan', 'T. Langon', 'T. Langon', 0.00, 200000.00, 260, true),
    ('Unergi', null, 'Royal', 43.00, null, 210, true),
    (null, null, 'Tuban', 90.00, null, 100, true),
    (null, null, 'Probolinggo', 90.00, null, 100, true),
    (null, null, 'Mojoagung', 80.00, null, 100, true),
    (null, null, 'Behaestex', 65.00, null, 100, true),
    (null, null, 'Romo', 15.00, null, 100, true),
    (null, null, 'Tongas', 80.00, null, 100, true),
    (null, null, 'Kediri', 85.00, null, 100, true),
    (null, null, 'Sudali', 58.00, null, 100, true),
    (null, null, 'MKP', 50.00, null, 100, true),
    (null, null, 'Kendal', 175.00, null, 100, true),
    (null, null, 'SGM', 43.00, null, 100, true),
    (null, null, 'Bricon', 55.00, null, 100, true),
    (null, null, 'Lawang', 80.00, null, 100, true),
    (null, null, 'Sentong', 20.00, null, 100, true),
    (null, null, 'Kletek', 43.00, null, 100, true),
    (null, null, 'Bululawang', 110.00, null, 100, true),
    (null, null, 'Dorang', 35.00, null, 100, true),
    (null, null, 'Mojokerto', 60.00, null, 100, true),
    (null, null, 'Molindo', 72.00, null, 100, true),
    (null, null, 'Gema', 80.00, null, 100, true),
    (null, null, 'Gempol', 55.00, null, 100, true),
    (null, null, 'Bumindo', 55.00, null, 120, true),
    (null, null, 'Temanggung', 165.00, null, 120, true),
    (null, null, 'Danliris', 155.00, null, 120, true),
    (null, 'T. Langon', 'Surya Warna / Sukoharjo', 165.00, null, 125, true),
    (null, null, 'Sragen', 145.00, null, 100, true),
    (null, null, 'KIG', 43.00, null, 100, true),
    (null, null, 'TIM', 187.50, null, 100, true),
    (null, null, 'Semarang', 165.00, null, 100, true),
    (null, null, 'KSI', 240.00, null, 100, true),
    (null, 'Betoyo', 'Probolinggo', 95.00, null, 100, true),
    (null, 'Betoyo', 'Tongas', 88.00, null, 100, true),
    (null, 'Betoyo', 'Mojoagung', 87.00, null, 100, true),
    (null, 'Betoyo', 'Muncar', 195.00, null, 110, true),
    (null, 'Betoyo', 'Surya Warna / Sukoharjo', 170.00, null, 130, true),
    (null, 'Betoyo', 'T. Langon', 90.00, null, 100, true),
    (null, 'Betoyo', 'Blitar', 125.00, null, 100, true)
), normalized as (
  select
    nullif(trim(customer_name), '') as customer_name,
    nullif(trim(lokasi_muat), '') as lokasi_muat,
    trim(lokasi_bongkar) as lokasi_bongkar,
    harga_per_ton,
    flat_total,
    priority,
    is_active
  from incoming
)
insert into public.harga_per_ton_rules (
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
)
select
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
from normalized;

delete from public.harga_per_ton_rules
where lower(coalesce(lokasi_muat, '')) in ('selain betoyo', 'non betoyo');

insert into public.harga_per_ton_rules (
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  priority,
  is_active
)
select
  customer_name,
  'Selain Betoyo',
  lokasi_bongkar,
  harga_per_ton,
  flat_total,
  greatest(coalesce(priority, 0) - 5, 0),
  true
from (
  select distinct on (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_bongkar, ''))
  )
    customer_name,
    lokasi_bongkar,
    harga_per_ton,
    flat_total,
    priority,
    updated_at
  from public.harga_per_ton_rules
  where coalesce(is_active, true)
    and lower(coalesce(lokasi_muat, '')) in ('t. langon', 't langon', 'tlangon', 'langon')
    and trim(coalesce(lokasi_bongkar, '')) <> ''
  order by
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_bongkar, '')),
    coalesce(priority, 0) desc,
    updated_at desc nulls last
) source_rules;

commit;
