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
where lower(coalesce(customer_name, '')) = ''
  and pg_temp.cvant_patch_norm(lokasi_muat) = 'betoyo'
  and pg_temp.cvant_patch_norm(lokasi_bongkar) = 'muncar';

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
  (null, 'Betoyo', 'Muncar', 195.00, null, 110, true);

-- Selain Betoyo mengikuti harga T. Langon untuk tujuan yang sama.
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

delete from public.sangu_driver_rules
where pg_temp.cvant_patch_norm(tempat) in ('t langon muncar', 'betoyo muncar')
   or (
     pg_temp.cvant_patch_norm(lokasi_bongkar) = 'muncar'
     and pg_temp.cvant_patch_norm(lokasi_muat) in ('t langon', 'langon', 'betoyo')
   );

insert into public.sangu_driver_rules (
  tempat,
  lokasi_muat,
  lokasi_bongkar,
  nominal,
  is_active
)
values
  ('T. LANGON - MUNCAR', 'T. LANGON', 'MUNCAR', 3000000.00, true),
  ('BETOYO - MUNCAR', 'BETOYO', 'MUNCAR', 3100000.00, true);

-- Update invoice lama supaya harga/total di daftar invoice ikut balance.
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
      when muatan_norm like '%tolakan%'
        and muat_norm = 'muncar'
        and bongkar_norm = 'betoyo'
        then 97.50
      when muatan_norm like '%tolakan%'
        and muat_norm = 'muncar'
        and bongkar_norm in ('t langon', 'langon', 'tlangon')
        then 93.75
      when muatan_norm not like '%tolakan%'
        and muat_norm = 'betoyo'
        and bongkar_norm = 'muncar'
        then 195.00
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

-- Backfill umum: semua muatan Tolakan mengikuti setengah harga dari rule rute kebalikan.
with expanded as (
  select
    i.id,
    i.invoice_entity,
    i.nama_pelanggan,
    pg_temp.cvant_patch_norm(i.nama_pelanggan) as customer_norm,
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
), rule_candidates as (
  select
    e.*,
    r.harga_per_ton,
    r.flat_total,
    row_number() over (
      partition by e.id, e.ordinality
      order by
        route.route_order,
        case when pg_temp.cvant_patch_norm(r.customer_name) = '' then 0 else 1 end desc,
        case when pg_temp.cvant_patch_norm(r.lokasi_muat) = '' then 0 else 1 end desc,
        coalesce(r.priority, 0) desc
    ) as rn
  from expanded e
  cross join lateral (
    values
      (
        case when e.muatan_norm like '%tolakan%' then e.bongkar_norm else e.muat_norm end,
        case when e.muatan_norm like '%tolakan%' then e.muat_norm else e.bongkar_norm end,
        0
      ),
      (e.muat_norm, e.bongkar_norm, 1)
  ) as route(search_muat_norm, search_bongkar_norm, route_order)
  join public.harga_per_ton_rules r
    on coalesce(r.is_active, true)
   and pg_temp.cvant_patch_norm(r.lokasi_bongkar) = route.search_bongkar_norm
   and (
     pg_temp.cvant_patch_norm(r.lokasi_muat) = ''
     or route.search_muat_norm = ''
     or pg_temp.cvant_patch_norm(r.lokasi_muat) = route.search_muat_norm
     or (
       pg_temp.cvant_patch_norm(r.lokasi_muat) in ('selain betoyo', 'non betoyo')
       and route.search_muat_norm <> 'betoyo'
     )
   )
   and (
     pg_temp.cvant_patch_norm(r.customer_name) = ''
     or (
       e.customer_norm <> ''
       and (
         e.customer_norm like '%' || pg_temp.cvant_patch_norm(r.customer_name) || '%'
         or pg_temp.cvant_patch_norm(r.customer_name) like '%' || e.customer_norm || '%'
       )
     )
   )
  where route.search_bongkar_norm <> ''
), best_rules as (
  select *
  from rule_candidates
  where rn = 1
), rebuilt_rows as (
  select
    e.id,
    e.invoice_entity,
    e.ordinality,
    case
      when b.id is null then e.detail
      else
        (e.detail - 'subtotal' - 'total' - 'jumlah') ||
        case
          when coalesce(b.harga_per_ton, 0) > 0
            then jsonb_build_object(
              'harga',
              case
                when e.muatan_norm like '%tolakan%' then b.harga_per_ton / 2
                else b.harga_per_ton
              end
            )
          else '{}'::jsonb
        end ||
        case
          when coalesce(b.flat_total, 0) > 0
            then jsonb_build_object(
              'subtotal',
              case
                when e.muatan_norm like '%tolakan%' then b.flat_total / 2
                else b.flat_total
              end
            )
          else '{}'::jsonb
        end
    end as next_detail,
    case
      when b.id is null and e.explicit_total > 0 then e.explicit_total
      when coalesce(b.flat_total, 0) > 0 then
        case when e.muatan_norm like '%tolakan%' then b.flat_total / 2 else b.flat_total end
      else
        e.tonase_value *
        coalesce(
          case
            when coalesce(b.harga_per_ton, 0) > 0 and e.muatan_norm like '%tolakan%'
              then b.harga_per_ton / 2
            when coalesce(b.harga_per_ton, 0) > 0 then b.harga_per_ton
            else null
          end,
          e.current_harga
        )
    end as next_row_total,
    case
      when b.id is null then null
      when coalesce(b.harga_per_ton, 0) > 0 and e.muatan_norm like '%tolakan%' then b.harga_per_ton / 2
      when coalesce(b.harga_per_ton, 0) > 0 then b.harga_per_ton
      else null
    end as next_harga
  from expanded e
  left join best_rules b on b.id = e.id and b.ordinality = e.ordinality
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

-- Update auto expense sangu sopir lama untuk rute Muncar dan Tolakan yang sudah dikenal.
with expanded as (
  select
    e.id,
    detail.ordinality,
    detail.value as detail,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') as muat_norm,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar') as bongkar_norm,
    pg_temp.cvant_patch_norm(detail.value->>'muatan') as muatan_norm,
    pg_temp.cvant_patch_num(detail.value->>'jumlah') as current_jumlah
  from public.expenses e
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(coalesce(e.rincian, '[]'::jsonb)) = 'array'
        then coalesce(e.rincian, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as detail(value, ordinality)
  where lower(coalesce(e.note, '')) like 'auto_sangu:%'
     or lower(coalesce(e.keterangan, '')) like 'auto sangu sopir%'
), priced as (
  select
    *,
    case
      when muatan_norm like '%tolakan%'
        and muat_norm = 'muncar'
        and bongkar_norm = 'betoyo'
        then 1550000.00
      when muatan_norm like '%tolakan%'
        and muat_norm = 'muncar'
        and bongkar_norm in ('t langon', 'langon', 'tlangon')
        then 1500000.00
      when muatan_norm not like '%tolakan%'
        and muat_norm in ('t langon', 'langon', 'tlangon')
        and bongkar_norm = 'muncar'
        then 3000000.00
      when muatan_norm not like '%tolakan%'
        and muat_norm = 'betoyo'
        and bongkar_norm = 'muncar'
        then 3100000.00
      else null
    end as next_jumlah
  from expanded
), rebuilt_expenses as (
  select
    id,
    jsonb_agg(
      case
        when next_jumlah is null then detail
        else detail || jsonb_build_object('jumlah', next_jumlah)
      end
      order by ordinality
    ) as next_rincian,
    sum(coalesce(next_jumlah, current_jumlah)) as next_total_pengeluaran,
    max(case when next_jumlah is not null then 1 else 0 end) as changed_rows
  from priced
  group by id
)
update public.expenses e
set
  rincian = r.next_rincian,
  total_pengeluaran = r.next_total_pengeluaran,
  updated_at = timezone('utc', now())
from rebuilt_expenses r
where e.id = r.id
  and r.changed_rows > 0;

-- Backfill umum: semua auto sangu Tolakan mengikuti setengah sangu dari rule rute kebalikan.
with expanded as (
  select
    e.id,
    detail.ordinality,
    detail.value as detail,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') as muat_norm,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar') as bongkar_norm,
    pg_temp.cvant_patch_norm(detail.value->>'muatan') as muatan_norm,
    pg_temp.cvant_patch_num(detail.value->>'jumlah') as current_jumlah
  from public.expenses e
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(coalesce(e.rincian, '[]'::jsonb)) = 'array'
        then coalesce(e.rincian, '[]'::jsonb)
      else '[]'::jsonb
    end
  ) with ordinality as detail(value, ordinality)
  where lower(coalesce(e.note, '')) like 'auto_sangu:%'
     or lower(coalesce(e.keterangan, '')) like 'auto sangu sopir%'
), rule_candidates as (
  select
    e.*,
    r.nominal,
    row_number() over (
      partition by e.id, e.ordinality
      order by
        route.route_order,
        case when pg_temp.cvant_patch_norm(r.lokasi_muat) = '' then 0 else 1 end desc
    ) as rn
  from expanded e
  cross join lateral (
    values
      (
        case when e.muatan_norm like '%tolakan%' then e.bongkar_norm else e.muat_norm end,
        case when e.muatan_norm like '%tolakan%' then e.muat_norm else e.bongkar_norm end,
        0
      ),
      (e.muat_norm, e.bongkar_norm, 1)
  ) as route(search_muat_norm, search_bongkar_norm, route_order)
  join public.sangu_driver_rules r
    on coalesce(r.is_active, true)
   and pg_temp.cvant_patch_norm(r.lokasi_bongkar) = route.search_bongkar_norm
   and (
     pg_temp.cvant_patch_norm(r.lokasi_muat) = ''
     or route.search_muat_norm = ''
     or pg_temp.cvant_patch_norm(r.lokasi_muat) = route.search_muat_norm
   )
  where route.search_bongkar_norm <> ''
), best_rules as (
  select *
  from rule_candidates
  where rn = 1
), rebuilt_expenses as (
  select
    e.id,
    jsonb_agg(
      case
        when b.id is null then e.detail
        else e.detail || jsonb_build_object(
          'jumlah',
          case
            when e.muatan_norm like '%tolakan%' then b.nominal / 2
            else b.nominal
          end
        )
      end
      order by e.ordinality
    ) as next_rincian,
    sum(
      case
        when b.id is null then e.current_jumlah
        when e.muatan_norm like '%tolakan%' then b.nominal / 2
        else b.nominal
      end
    ) as next_total_pengeluaran,
    max(case when b.id is null then 0 else 1 end) as changed_rows
  from expanded e
  left join best_rules b on b.id = e.id and b.ordinality = e.ordinality
  group by e.id
)
update public.expenses e
set
  rincian = r.next_rincian,
  total_pengeluaran = r.next_total_pengeluaran,
  updated_at = timezone('utc', now())
from rebuilt_expenses r
where e.id = r.id
  and r.changed_rows > 0;

notify pgrst, 'reload schema';

commit;
