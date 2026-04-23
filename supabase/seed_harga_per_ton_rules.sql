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
    (null, 'T. Langon', 'Purwosari', 80.00, null, 100, true),
    (null, 'T. Langon', 'Safelock', 50.00, null, 100, true),
    (null, 'T. Langon', 'Muncar', 187.50, null, 100, true),
    (null, 'T. Langon', 'Tanggulangin', 55.00, null, 100, true),
    (null, 'T. Langon', 'Pare', 80.00, null, 100, true),
    (null, 'T. Langon', 'Singosari', 85.00, null, 100, true),
    (null, null, 'Batang', 235.00, null, 100, true),
    ('PT Bornava Indobara Mandiri', null, 'Batang', 225.00, null, 200, true),
    ('Giono', 'Nganjuk', 'Driyo', 0.00, 1600000.00, 250, true),
    ('Hasan', 'T. Langon', 'T. Langon', 0.00, 200000.00, 260, true),
    (null, 'T. Langon', 'Tuban', 90.00, null, 100, true),
    (null, 'T. Langon', 'Probolinggo', 90.00, null, 100, true),
    (null, 'T. Langon', 'Mojoagung', 80.00, null, 100, true),
    (null, 'T. Langon', 'Behaestex', 65.00, null, 100, true),
    (null, 'T. Langon', 'Romo', 15.00, null, 100, true),
    (null, 'T. Langon', 'Tongas', 80.00, null, 100, true),
    (null, 'T. Langon', 'Kediri', 85.00, null, 100, true),
    (null, 'T. Langon', 'Sudali', 58.00, null, 100, true),
    (null, 'T. Langon', 'MKP', 50.00, null, 100, true),
    (null, 'T. Langon', 'Kendal', 175.00, null, 100, true),
    (null, 'T. Langon', 'SGM', 43.00, null, 100, true),
    (null, 'T. Langon', 'Bricon', 55.00, null, 100, true),
    (null, 'T. Langon', 'Lawang', 80.00, null, 100, true),
    (null, 'T. Langon', 'Sentong', 20.00, null, 100, true),
    (null, 'T. Langon', 'Kletek', 43.00, null, 100, true),
    (null, 'T. Langon', 'Bululawang', 110.00, null, 100, true),
    (null, 'T. Langon', 'Dorang', 35.00, null, 100, true),
    (null, 'T. Langon', 'Mojokerto', 60.00, null, 100, true),
    (null, 'T. Langon', 'Molindo', 72.00, null, 100, true),
    (null, 'T. Langon', 'Gema', 80.00, null, 100, true),
    (null, null, 'Gempol', 55.00, null, 100, true),
    (null, 'T. Langon', 'Sragen', 145.00, null, 100, true),
    (null, 'T. Langon', 'KIG', 43.00, null, 100, true),
    (null, 'T. Langon', 'TIM', 187.50, null, 100, true),
    (null, 'T. Langon', 'Semarang', 165.00, null, 100, true),
    (null, null, 'KSI', 240.00, null, 100, true),
    (null, 'Betoyo', 'Probolinggo', 95.00, null, 100, true),
    (null, 'Betoyo', 'Tongas', 88.00, null, 100, true),
    (null, 'Betoyo', 'Mojoagung', 87.00, null, 100, true),
    (null, 'Betoyo', 'Muncar', 193.00, null, 110, true),
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
    (null, 'T. Langon', 'Purwosari', 80.00, null, 100, true),
    (null, 'T. Langon', 'Safelock', 50.00, null, 100, true),
    (null, 'T. Langon', 'Muncar', 187.50, null, 100, true),
    (null, 'T. Langon', 'Tanggulangin', 55.00, null, 100, true),
    (null, 'T. Langon', 'Pare', 80.00, null, 100, true),
    (null, 'T. Langon', 'Singosari', 85.00, null, 100, true),
    (null, null, 'Batang', 235.00, null, 100, true),
    ('PT Bornava Indobara Mandiri', null, 'Batang', 225.00, null, 200, true),
    ('Giono', 'Nganjuk', 'Driyo', 0.00, 1600000.00, 250, true),
    ('Hasan', 'T. Langon', 'T. Langon', 0.00, 200000.00, 260, true),
    (null, 'T. Langon', 'Tuban', 90.00, null, 100, true),
    (null, 'T. Langon', 'Probolinggo', 90.00, null, 100, true),
    (null, 'T. Langon', 'Mojoagung', 80.00, null, 100, true),
    (null, 'T. Langon', 'Behaestex', 65.00, null, 100, true),
    (null, 'T. Langon', 'Romo', 15.00, null, 100, true),
    (null, 'T. Langon', 'Tongas', 80.00, null, 100, true),
    (null, 'T. Langon', 'Kediri', 85.00, null, 100, true),
    (null, 'T. Langon', 'Sudali', 58.00, null, 100, true),
    (null, 'T. Langon', 'MKP', 50.00, null, 100, true),
    (null, 'T. Langon', 'Kendal', 175.00, null, 100, true),
    (null, 'T. Langon', 'SGM', 43.00, null, 100, true),
    (null, 'T. Langon', 'Bricon', 55.00, null, 100, true),
    (null, 'T. Langon', 'Lawang', 80.00, null, 100, true),
    (null, 'T. Langon', 'Sentong', 20.00, null, 100, true),
    (null, 'T. Langon', 'Kletek', 43.00, null, 100, true),
    (null, 'T. Langon', 'Bululawang', 110.00, null, 100, true),
    (null, 'T. Langon', 'Dorang', 35.00, null, 100, true),
    (null, 'T. Langon', 'Mojokerto', 60.00, null, 100, true),
    (null, 'T. Langon', 'Molindo', 72.00, null, 100, true),
    (null, 'T. Langon', 'Gema', 80.00, null, 100, true),
    (null, null, 'Gempol', 55.00, null, 100, true),
    (null, 'T. Langon', 'Sragen', 145.00, null, 100, true),
    (null, 'T. Langon', 'KIG', 43.00, null, 100, true),
    (null, 'T. Langon', 'TIM', 187.50, null, 100, true),
    (null, 'T. Langon', 'Semarang', 165.00, null, 100, true),
    (null, null, 'KSI', 240.00, null, 100, true),
    (null, 'Betoyo', 'Probolinggo', 95.00, null, 100, true),
    (null, 'Betoyo', 'Tongas', 88.00, null, 100, true),
    (null, 'Betoyo', 'Mojoagung', 87.00, null, 100, true),
    (null, 'Betoyo', 'Muncar', 193.00, null, 110, true),
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

commit;
