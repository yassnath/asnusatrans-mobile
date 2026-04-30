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

alter table public.harga_per_ton_rules
  drop constraint if exists harga_per_ton_rules_route_lower_unique;

drop index if exists harga_per_ton_rules_route_lower_unique;

create unique index if not exists harga_per_ton_rules_route_customer_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );

create or replace function pg_temp.cvant_patch_norm(value text)
returns text
language sql
immutable
as $$
  select btrim(regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', ' ', 'g'));
$$;

create or replace function pg_temp.cvant_patch_num(value text)
returns numeric
language plpgsql
immutable
as $$
declare
  cleaned text;
  dot_count int;
begin
  cleaned := regexp_replace(coalesce(value, ''), '[^0-9,.-]', '', 'g');
  if cleaned is null or btrim(cleaned) = '' then
    return 0;
  end if;

  if position(',' in cleaned) > 0 then
    cleaned := replace(replace(cleaned, '.', ''), ',', '.');
  else
    dot_count := length(cleaned) - length(replace(cleaned, '.', ''));
    if dot_count > 1 then
      cleaned := replace(cleaned, '.', '');
    end if;
  end if;

  return coalesce(nullif(cleaned, ''), '0')::numeric;
exception
  when others then
    return 0;
end;
$$;

delete from public.harga_per_ton_rules
where pg_temp.cvant_patch_norm(lokasi_bongkar) = 'batang'
  and pg_temp.cvant_patch_norm(lokasi_muat) in (
    '',
    't langon',
    'langon',
    'tlangon',
    'selain betoyo',
    'non betoyo'
  )
  and (
    pg_temp.cvant_patch_norm(customer_name) = ''
    or pg_temp.cvant_patch_norm(customer_name) like '%bornava%'
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
  (null, null, 'Batang', 235.00, null, 120, true),
  ('Bornava', null, 'Batang', 225.00, null, 220, true);

-- Update invoice lama di daftar invoice/fix invoice source supaya nilai Batang konsisten.
with expanded as (
  select
    i.id,
    i.invoice_entity,
    i.nama_pelanggan,
    detail.ordinality,
    detail.value as detail,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') as muat_norm,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar') as bongkar_norm,
    pg_temp.cvant_patch_norm(detail.value->>'muatan') as muatan_norm,
    pg_temp.cvant_patch_num(detail.value->>'tonase') as tonase_value,
    pg_temp.cvant_patch_num(detail.value->>'harga') as current_harga,
    pg_temp.cvant_patch_num(coalesce(
      detail.value->>'subtotal',
      detail.value->>'total',
      detail.value->>'jumlah'
    )) as explicit_total
  from public.invoices i
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(coalesce(i.rincian, '[]'::jsonb)) = 'array'
        then coalesce(i.rincian, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as detail(value, ordinality)
), priced as (
  select
    *,
    case
      when muatan_norm like '%tolakan%'
        and muat_norm = 'batang'
        and bongkar_norm in ('t langon', 'langon', 'tlangon')
        then case
          when pg_temp.cvant_patch_norm(nama_pelanggan) like '%bornava%' then 112.50
          else 117.50
        end
      when muatan_norm not like '%tolakan%'
        and muat_norm <> 'betoyo'
        and bongkar_norm = 'batang'
        then case
          when pg_temp.cvant_patch_norm(nama_pelanggan) like '%bornava%' then 225.00
          else 235.00
        end
      else null
    end as next_harga
  from expanded
), rebuilt_rows as (
  select
    id,
    invoice_entity,
    ordinality,
    case
      when next_harga is null then detail
      else
        (detail - 'subtotal' - 'total' - 'jumlah') ||
        jsonb_build_object('harga', next_harga)
    end as next_detail,
    case
      when next_harga is null and explicit_total > 0 then explicit_total
      else tonase_value * coalesce(next_harga, current_harga)
    end as next_row_total,
    next_harga
  from priced
), rebuilt_invoices as (
  select
    id,
    jsonb_agg(next_detail order by ordinality) as next_rincian,
    sum(next_row_total) as next_total_biaya,
    max(case when next_harga is not null then 1 else 0 end) as changed_rows,
    (array_agg((next_detail->>'harga') order by ordinality))[1] as first_harga
  from rebuilt_rows
  group by id
), invoice_updates as (
  select
    i.id,
    r.next_rincian,
    r.next_total_biaya,
    pg_temp.cvant_patch_num(r.first_harga) as first_harga,
    case
      when lower(coalesce(i.invoice_entity, '')) in ('cv_ant', 'pt_ant')
        or coalesce(i.pph, 0) > 0
        then floor(r.next_total_biaya * 0.02)
      else 0
    end as next_pph
  from public.invoices i
  join rebuilt_invoices r on r.id = i.id
  where r.changed_rows > 0
)
update public.invoices i
set
  rincian = u.next_rincian,
  harga = nullif(u.first_harga, 0),
  total_biaya = u.next_total_biaya,
  pph = u.next_pph,
  total_bayar = greatest(0, u.next_total_biaya - u.next_pph),
  updated_at = timezone('utc', now())
from invoice_updates u
where i.id = u.id;

do $$
begin
  if to_regclass('public.fixed_invoice_batches') is not null then
    update public.fixed_invoice_batches fib
    set updated_at = timezone('utc', now())
    where exists (
      select 1
      from unnest(fib.invoice_ids) as batch_invoice_id(invoice_id)
      join public.invoices i on i.id::text = batch_invoice_id.invoice_id
      cross join lateral jsonb_array_elements(
        case
          when jsonb_typeof(coalesce(i.rincian, '[]'::jsonb)) = 'array'
            then coalesce(i.rincian, '[]'::jsonb)
          else '[]'::jsonb
        end
      ) as detail(value)
      where (
        pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar') = 'batang'
        and pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') <> 'betoyo'
      )
      or (
        pg_temp.cvant_patch_norm(detail.value->>'muatan') like '%tolakan%'
        and pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') = 'batang'
        and pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar')
          in ('t langon', 'langon', 'tlangon')
      )
    );
  end if;
end $$;

notify pgrst, 'reload schema';

commit;
