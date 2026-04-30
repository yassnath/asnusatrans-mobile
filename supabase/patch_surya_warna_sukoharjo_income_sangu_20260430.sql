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

create or replace function pg_temp.cvant_patch_norm(value text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', ' ', 'g'));
$$;

delete from public.harga_per_ton_rules
where pg_temp.cvant_patch_norm(customer_name) = ''
  and pg_temp.cvant_patch_norm(lokasi_muat) in (
    'betoyo',
    't langon',
    'langon',
    'tlangon'
  )
  and pg_temp.cvant_patch_norm(lokasi_bongkar) in (
    'surya warna sukoharjo',
    'surya warna',
    'sukoharjo'
  );

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
  (null, 'Betoyo', 'Surya Warna / Sukoharjo', 170.00, null, 130, true),
  (null, 'T. Langon', 'Surya Warna / Sukoharjo', 165.00, null, 125, true);

delete from public.sangu_driver_rules
where pg_temp.cvant_patch_norm(lokasi_muat) in (
    'betoyo',
    't langon',
    'langon',
    'tlangon'
  )
  and (
    pg_temp.cvant_patch_norm(tempat) in (
      'betoyo surya warna sukoharjo',
      't langon surya warna sukoharjo',
      'langon surya warna sukoharjo'
    )
    or pg_temp.cvant_patch_norm(lokasi_bongkar) in (
      'surya warna sukoharjo',
      'surya warna',
      'sukoharjo'
    )
  );

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
values
  (
    'BETOYO - SURYA WARNA / SUKOHARJO',
    'BETOYO',
    'SURYA WARNA / SUKOHARJO',
    2550000.00,
    true
  ),
  (
    'T. LANGON - SURYA WARNA / SUKOHARJO',
    'T. LANGON',
    'SURYA WARNA / SUKOHARJO',
    2435000.00,
    true
  );

notify pgrst, 'reload schema';

commit;
