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

create or replace function pg_temp.cvant_patch_norm(value text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', ' ', 'g'));
$$;

-- Rule khusus ini dibaca aplikasi sebagai: semua lokasi muat selain Betoyo.
delete from public.harga_per_ton_rules
where pg_temp.cvant_patch_norm(lokasi_muat) in ('selain betoyo', 'non betoyo');

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
    pg_temp.cvant_patch_norm(customer_name),
    pg_temp.cvant_patch_norm(lokasi_bongkar)
  )
    customer_name,
    lokasi_bongkar,
    harga_per_ton,
    flat_total,
    priority,
    updated_at
  from public.harga_per_ton_rules
  where coalesce(is_active, true)
    and pg_temp.cvant_patch_norm(lokasi_muat) in ('t langon', 'langon', 'tlangon')
    and pg_temp.cvant_patch_norm(lokasi_bongkar) <> ''
  order by
    pg_temp.cvant_patch_norm(customer_name),
    pg_temp.cvant_patch_norm(lokasi_bongkar),
    coalesce(priority, 0) desc,
    updated_at desc nulls last
) source_rules;

notify pgrst, 'reload schema';

commit;
