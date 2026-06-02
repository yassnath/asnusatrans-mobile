begin;

-- Felix tolakan 28-05-2026 harus mengikuti subtotal manual user.
-- Patch ini membenahi parent total dan detail supaya invoice list,
-- preview, edit income, laporan, dan print membaca Rp 500.000.

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

with targets as (
  select
    i.id,
    i.invoice_entity,
    i.no_invoice,
    i.rincian,
    case
      when jsonb_typeof(coalesce(i.rincian, '[]'::jsonb)) = 'array'
        and jsonb_array_length(coalesce(i.rincian, '[]'::jsonb)) > 0
        then coalesce(i.rincian, '[]'::jsonb)
      else jsonb_build_array(
        jsonb_build_object(
          'lokasi_muat', i.lokasi_muat,
          'lokasi_bongkar', i.lokasi_bongkar,
          'muatan', i.muatan,
          'nama_supir', i.nama_supir,
          'armada_id', i.armada_id,
          'armada_start_date', i.armada_start_date,
          'armada_end_date', i.armada_end_date,
          'tonase', i.tonase,
          'harga', i.harga,
          'subtotal', i.total_biaya
        )
      )
    end as detail_array
  from public.invoices i
  where pg_temp.cvant_patch_norm(i.nama_pelanggan) like '%felix%'
), expanded as (
  select
    t.id,
    t.invoice_entity,
    t.no_invoice,
    detail.ordinality,
    detail.value as detail,
    pg_temp.cvant_patch_norm(detail.value->>'muatan') as muatan_norm,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_muat') as muat_norm,
    pg_temp.cvant_patch_norm(detail.value->>'lokasi_bongkar') as bongkar_norm,
    pg_temp.cvant_patch_norm(coalesce(
      detail.value->>'armada_start_date',
      detail.value->>'tanggal',
      ''
    )) as date_norm,
    pg_temp.cvant_patch_num(coalesce(
      detail.value->>'manual_subtotal',
      detail.value->>'subtotal_manual',
      detail.value->>'subtotal',
      detail.value->>'total',
      detail.value->>'jumlah'
    )) as detail_total
  from targets t
  cross join lateral jsonb_array_elements(t.detail_array)
    with ordinality as detail(value, ordinality)
), rebuilt as (
  select
    id,
    max(invoice_entity) as invoice_entity,
    max(no_invoice) as no_invoice,
    jsonb_agg(
      case
        when muatan_norm like '%tolakan%'
          and muat_norm = 'aspal'
          and bongkar_norm in ('t langon', 'langon', 'tlangon')
          and date_norm in (
            '2026 05 28',
            '28 05 2026',
            '28 mei 2026',
            '28 may 2026'
          )
          then (detail - 'total' - 'jumlah' - 'total_biaya') ||
            jsonb_build_object(
              'manual_subtotal', 500000.00,
              'subtotal', 500000.00,
              'subtotal_auto', false
            )
        else detail
      end
      order by ordinality
    ) as next_rincian,
    sum(
      case
        when muatan_norm like '%tolakan%'
          and muat_norm = 'aspal'
          and bongkar_norm in ('t langon', 'langon', 'tlangon')
          and date_norm in (
            '2026 05 28',
            '28 05 2026',
            '28 mei 2026',
            '28 may 2026'
          )
          then 500000.00
        when detail_total > 0 then detail_total
        else 0
      end
    ) as next_total_biaya,
    max(
      case
        when muatan_norm like '%tolakan%'
          and muat_norm = 'aspal'
          and bongkar_norm in ('t langon', 'langon', 'tlangon')
          and date_norm in (
            '2026 05 28',
            '28 05 2026',
            '28 mei 2026',
            '28 may 2026'
          )
          then 1
        else 0
      end
    ) as changed_rows
  from expanded
  group by id
), updates as (
  select
    r.id,
    r.next_rincian,
    r.next_total_biaya,
    case
      when lower(coalesce(r.invoice_entity, '')) in (
          'cv_ant',
          'pt_ant',
          'cv ant',
          'pt ant'
        )
        or upper(coalesce(r.no_invoice, '')) like 'CV.ANT%'
        or upper(coalesce(r.no_invoice, '')) like 'CVANT%'
        or upper(coalesce(r.no_invoice, '')) like 'PT.ANT%'
        or upper(coalesce(r.no_invoice, '')) like 'PTANT%'
        then round(r.next_total_biaya * 0.02)
      else 0
    end as next_pph
  from rebuilt r
  where r.changed_rows > 0
    and r.next_total_biaya > 0
)
update public.invoices i
set
  rincian = u.next_rincian,
  total_biaya = u.next_total_biaya,
  pph = u.next_pph,
  total_bayar = greatest(0, u.next_total_biaya - u.next_pph),
  updated_at = timezone('utc', now())
from updates u
where i.id = u.id;

notify pgrst, 'reload schema';

commit;
