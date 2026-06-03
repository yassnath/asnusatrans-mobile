begin;

-- Rule harga / ton khusus armada input manual (Gabungan).
-- customer_name = 'Gabungan' dipakai sebagai marker internal aplikasi,
-- sehingga rule ini konsisten lintas device tanpa mengubah pricing customer biasa.

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
  add column if not exists lokasi_muat text,
  add column if not exists lokasi_bongkar text,
  add column if not exists harga_per_ton numeric(14,2) not null default 0,
  add column if not exists flat_total numeric(14,2),
  add column if not exists priority int not null default 0,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create unique index if not exists harga_per_ton_rules_route_customer_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );

with gabungan_rules (
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  priority
) as (
  values
    ('Gabungan', null::text, 'Kendal', 170::numeric, 310),
    ('Gabungan', null::text, 'Kediri', 80::numeric, 310),
    ('Gabungan', 'Betoyo', 'Bimoli', 33::numeric, 360),
    ('Gabungan', null::text, 'Semarang', 158::numeric, 310),
    ('Gabungan', null::text, 'Kedawung', 40::numeric, 310),
    ('Gabungan', null::text, 'Royal', 40::numeric, 310),
    ('Gabungan', null::text, 'Pare', 78::numeric, 310),
    ('Gabungan', null::text, 'Gempol', 50::numeric, 310),
    ('Gabungan', null::text, 'Kedamean', 41::numeric, 310),
    ('Gabungan', null::text, 'Temanggung', 230::numeric, 310),
    ('Gabungan', null::text, 'MKP', 50::numeric, 310)
)
update public.harga_per_ton_rules h
set
  harga_per_ton = r.harga_per_ton,
  flat_total = null,
  priority = r.priority,
  is_active = true,
  updated_at = timezone('utc', now())
from gabungan_rules r
where lower(btrim(coalesce(h.customer_name, ''))) = lower(btrim(r.customer_name))
  and lower(btrim(coalesce(h.lokasi_muat, ''))) = lower(btrim(coalesce(r.lokasi_muat, '')))
  and lower(btrim(h.lokasi_bongkar)) = lower(btrim(r.lokasi_bongkar));

with gabungan_rules (
  customer_name,
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  priority
) as (
  values
    ('Gabungan', null::text, 'Kendal', 170::numeric, 310),
    ('Gabungan', null::text, 'Kediri', 80::numeric, 310),
    ('Gabungan', 'Betoyo', 'Bimoli', 33::numeric, 360),
    ('Gabungan', null::text, 'Semarang', 158::numeric, 310),
    ('Gabungan', null::text, 'Kedawung', 40::numeric, 310),
    ('Gabungan', null::text, 'Royal', 40::numeric, 310),
    ('Gabungan', null::text, 'Pare', 78::numeric, 310),
    ('Gabungan', null::text, 'Gempol', 50::numeric, 310),
    ('Gabungan', null::text, 'Kedamean', 41::numeric, 310),
    ('Gabungan', null::text, 'Temanggung', 230::numeric, 310),
    ('Gabungan', null::text, 'MKP', 50::numeric, 310)
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
  r.customer_name,
  r.lokasi_muat,
  r.lokasi_bongkar,
  r.harga_per_ton,
  null,
  r.priority,
  true
from gabungan_rules r
where not exists (
  select 1
  from public.harga_per_ton_rules h
  where lower(btrim(coalesce(h.customer_name, ''))) = lower(btrim(r.customer_name))
    and lower(btrim(coalesce(h.lokasi_muat, ''))) = lower(btrim(coalesce(r.lokasi_muat, '')))
    and lower(btrim(h.lokasi_bongkar)) = lower(btrim(r.lokasi_bongkar))
);

notify pgrst, 'reload schema';

commit;

-- Cek hasil:
-- select customer_name, lokasi_muat, lokasi_bongkar, harga_per_ton, priority, is_active
-- from public.harga_per_ton_rules
-- where lower(coalesce(customer_name, '')) = 'gabungan'
-- order by priority desc, lokasi_bongkar;
