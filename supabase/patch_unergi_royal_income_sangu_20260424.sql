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

delete from public.harga_per_ton_rules
where lower(coalesce(customer_name, '')) = 'unergi'
  and lower(coalesce(lokasi_muat, '')) = ''
  and lower(coalesce(lokasi_bongkar, '')) = 'royal';

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
  ('Unergi', null, 'Royal', 43.00, null, 210, true);

update public.sangu_driver_rules
set
  tempat = 'ROYAL',
  lokasi_muat = null,
  lokasi_bongkar = 'ROYAL',
  nominal = 520000.00,
  is_active = true,
  updated_at = timezone('utc', now())
where lower(coalesce(tempat, '')) = 'royal'
   or (
     lower(coalesce(lokasi_bongkar, '')) = 'royal'
     and lower(coalesce(lokasi_muat, '')) = ''
   );

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
select
  'ROYAL',
  null,
  'ROYAL',
  520000.00,
  true
where not exists (
  select 1
  from public.sangu_driver_rules
  where lower(coalesce(tempat, '')) = 'royal'
     or (
       lower(coalesce(lokasi_bongkar, '')) = 'royal'
       and lower(coalesce(lokasi_muat, '')) = ''
     )
);

notify pgrst, 'reload schema';

commit;
