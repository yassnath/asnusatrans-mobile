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
  add column if not exists lokasi_muat text,
  add column if not exists flat_total numeric(14,2),
  add column if not exists priority int not null default 0,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

drop index if exists harga_per_ton_rules_route_lower_unique;
create unique index if not exists harga_per_ton_rules_route_customer_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );

create table if not exists public.sangu_driver_rules (
  id uuid primary key default gen_random_uuid(),
  tempat text not null,
  lokasi_muat text,
  lokasi_bongkar text not null,
  nominal numeric(14,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.sangu_driver_rules
  add column if not exists lokasi_muat text,
  add column if not exists lokasi_bongkar text,
  add column if not exists nominal numeric(14,2) not null default 0,
  add column if not exists is_active boolean not null default true,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

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
