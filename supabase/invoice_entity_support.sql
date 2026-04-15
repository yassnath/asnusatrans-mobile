-- Invoice entity support patch
-- Jalankan file ini di Supabase SQL Editor sebagai role postgres.
-- Tujuan:
-- 1. Menyimpan tipe invoice: cv_ant / pt_ant / personal
-- 2. Menjaga invoice pengurus via RPC ikut menyimpan invoice_entity

begin;

alter table public.invoices
  add column if not exists invoice_entity text;

update public.invoices
set invoice_entity = case
  when upper(coalesce(no_invoice, '')) like 'PT.ANT%' then 'pt_ant'
  when upper(coalesce(no_invoice, '')) like 'CV.ANT%' then 'cv_ant'
  when upper(coalesce(no_invoice, '')) like 'BS%' then 'personal'
  when lower(coalesce(nama_pelanggan, '')) ~ '(^|[^a-z])(cv|pt|fa|ud|po|yayasan|bumn|bumd|perum|koperasi)([^a-z]|$)' then 'cv_ant'
  else 'personal'
end
where coalesce(trim(invoice_entity), '') = '';

alter table public.fixed_invoice_batches
  add column if not exists invoice_entity text;

update public.fixed_invoice_batches
set invoice_entity = case
  when upper(coalesce(invoice_number, '')) like 'PT.ANT%' then 'pt_ant'
  when upper(coalesce(invoice_number, '')) like 'CV.ANT%' then 'cv_ant'
  when upper(coalesce(invoice_number, '')) like 'BS%' then 'personal'
  when lower(coalesce(customer_name, '')) ~ '(^|[^a-z])(cv|pt|fa|ud|po|yayasan|bumn|bumd|perum|koperasi)([^a-z]|$)' then 'cv_ant'
  else 'personal'
end
where coalesce(trim(invoice_entity), '') = '';

create or replace function public.create_pengurus_income_invoice(
  p_payload jsonb
)
returns table (
  id uuid,
  no_invoice text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_invoice_id uuid;
  v_invoice_number text;
begin
  if v_user_id is null then
    raise exception 'Session tidak ditemukan. Silakan login ulang.';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and lower(coalesce(p.role, '')) = 'pengurus'
  ) then
    raise exception 'Hanya pengurus yang dapat menambah income.';
  end if;

  insert into public.invoices (
    no_invoice,
    invoice_entity,
    tanggal,
    tanggal_kop,
    lokasi_kop,
    nama_pelanggan,
    email,
    no_telp,
    due_date,
    lokasi_muat,
    lokasi_bongkar,
    customer_id,
    armada_id,
    armada_start_date,
    armada_end_date,
    tonase,
    harga,
    muatan,
    nama_supir,
    status,
    total_biaya,
    pph,
    total_bayar,
    diterima_oleh,
    created_by,
    order_id,
    rincian,
    submission_role,
    approval_status,
    approval_requested_at,
    approval_requested_by,
    approved_at,
    approved_by,
    edit_request_status
  )
  values (
    null,
    case lower(coalesce(trim(p_payload->>'invoice_entity'), ''))
      when 'pt_ant' then 'pt_ant'
      when 'personal' then 'personal'
      else 'cv_ant'
    end,
    coalesce(nullif(trim(p_payload->>'tanggal'), ''), current_date::text)::date,
    case when coalesce(trim(p_payload->>'tanggal_kop'), '') = '' then null else (p_payload->>'tanggal_kop')::date end,
    nullif(trim(coalesce(p_payload->>'lokasi_kop', '')), ''),
    coalesce(nullif(trim(p_payload->>'nama_pelanggan'), ''), 'Customer'),
    nullif(trim(coalesce(p_payload->>'email', '')), ''),
    nullif(trim(coalesce(p_payload->>'no_telp', '')), ''),
    case when coalesce(trim(p_payload->>'due_date'), '') = '' then null else (p_payload->>'due_date')::date end,
    nullif(trim(coalesce(p_payload->>'lokasi_muat', '')), ''),
    nullif(trim(coalesce(p_payload->>'lokasi_bongkar', '')), ''),
    case when coalesce(trim(p_payload->>'customer_id'), '') ~* '^[0-9a-f-]{36}$' then (p_payload->>'customer_id')::uuid else null end,
    case when coalesce(trim(p_payload->>'armada_id'), '') ~* '^[0-9a-f-]{36}$' then (p_payload->>'armada_id')::uuid else null end,
    case when coalesce(trim(p_payload->>'armada_start_date'), '') = '' then null else (p_payload->>'armada_start_date')::date end,
    case when coalesce(trim(p_payload->>'armada_end_date'), '') = '' then null else (p_payload->>'armada_end_date')::date end,
    case when coalesce(trim(p_payload->>'tonase'), '') = '' then null else (p_payload->>'tonase')::numeric end,
    case when coalesce(trim(p_payload->>'harga'), '') = '' then null else (p_payload->>'harga')::numeric end,
    nullif(trim(coalesce(p_payload->>'muatan', '')), ''),
    nullif(trim(coalesce(p_payload->>'nama_supir', '')), ''),
    coalesce(nullif(trim(p_payload->>'status'), ''), 'Unpaid'),
    coalesce(nullif(trim(p_payload->>'total_biaya'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'pph'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'total_bayar'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'diterima_oleh'), ''), 'Pengurus'),
    v_user_id,
    case when coalesce(trim(p_payload->>'order_id'), '') ~* '^[0-9a-f-]{36}$' then (p_payload->>'order_id')::uuid else null end,
    case
      when jsonb_typeof(coalesce(p_payload->'rincian', '[]'::jsonb)) = 'array'
        then coalesce(p_payload->'rincian', '[]'::jsonb)
      else '[]'::jsonb
    end,
    'pengurus',
    'pending',
    timezone('utc', now()),
    v_user_id,
    null,
    null,
    'none'
  )
  returning invoices.id, invoices.no_invoice
  into v_invoice_id, v_invoice_number;

  return query
  select v_invoice_id, v_invoice_number;
end;
$$;

commit;
