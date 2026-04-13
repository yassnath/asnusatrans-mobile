-- Pengurus role workflow patch
-- Jalankan di Supabase SQL Editor pada project production/dev yang aktif.

create extension if not exists pgcrypto;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('customer', 'admin', 'owner', 'pengurus'));

do $$
declare
  v_user_id uuid;
  v_email text := 'pengurus@cvant.local';
  v_password text := 'pengurusant';
begin
  select u.id
  into v_user_id
  from auth.users u
  where lower(coalesce(u.email, '')) = lower(v_email)
     or lower(coalesce(u.raw_user_meta_data->>'username', '')) = lower('pengurus')
     or lower(split_part(coalesce(u.email, ''), '@', 1)) = lower('pengurus')
  order by case when lower(coalesce(u.email, '')) = lower(v_email) then 0 else 1 end
  limit 1;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    )
    values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_email,
      crypt(v_password, gen_salt('bf')),
      timezone('utc', now()),
      jsonb_build_object(
        'provider', 'email',
        'providers', jsonb_build_array('email'),
        'role', 'pengurus'
      ),
      jsonb_build_object(
        'name', 'Pengurus',
        'username', 'pengurus',
        'role', 'pengurus'
      ),
      timezone('utc', now()),
      timezone('utc', now()),
      '',
      '',
      '',
      ''
    );
  else
    update auth.users
    set
      encrypted_password = crypt(v_password, gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, timezone('utc', now())),
      raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) ||
        jsonb_build_object(
          'provider', 'email',
          'providers', jsonb_build_array('email'),
          'role', 'pengurus'
        ),
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) ||
        jsonb_build_object(
          'name', 'Pengurus',
          'username', 'pengurus',
          'role', 'pengurus'
        ),
      updated_at = timezone('utc', now())
    where id = v_user_id;
  end if;

  if exists (
    select 1
    from auth.identities
    where provider = 'email'
      and provider_id = v_user_id::text
  ) then
    update auth.identities
    set
      user_id = v_user_id,
      identity_data = jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      updated_at = timezone('utc', now())
    where provider = 'email'
      and provider_id = v_user_id::text;
  else
    insert into auth.identities (
      id,
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    )
    values (
      gen_random_uuid(),
      v_user_id::text,
      v_user_id,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now())
    );
  end if;

  delete from public.profiles
  where id <> v_user_id
    and (
      lower(username) = lower('pengurus')
      or lower(email) = lower(v_email)
    );
end;
$$;

update auth.users
set
  raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) ||
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'role', 'pengurus'
    ),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) ||
    jsonb_build_object(
      'name', 'Pengurus',
      'username', 'pengurus',
      'role', 'pengurus'
    ),
  updated_at = timezone('utc', now())
where lower(coalesce(email, '')) = lower('pengurus@cvant.local')
   or lower(coalesce(raw_user_meta_data->>'username', '')) = lower('pengurus')
   or lower(split_part(coalesce(email, ''), '@', 1)) = lower('pengurus');

insert into public.profiles (
  id,
  email,
  name,
  username,
  role,
  updated_at
)
select
  u.id,
  lower(u.email),
  'Pengurus',
  'pengurus',
  'pengurus',
  timezone('utc', now())
from auth.users u
where lower(coalesce(u.email, '')) = lower('pengurus@cvant.local')
   or lower(coalesce(u.raw_user_meta_data->>'username', '')) = lower('pengurus')
   or lower(split_part(coalesce(u.email, ''), '@', 1)) = lower('pengurus')
on conflict (id) do update
set
  email = excluded.email,
  name = excluded.name,
  username = excluded.username,
  role = excluded.role,
  updated_at = timezone('utc', now());

do $$
begin
  if not exists (
    select 1
    from public.profiles
    where lower(username) = lower('pengurus')
      and role = 'pengurus'
  ) then
    raise notice 'Profile pengurus belum dibuat karena Auth user pengurus@cvant.local belum ada. Buat user Auth dulu via Authentication UI atau scripts/bootstrap_supabase_users.ps1.';
  end if;
end;
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    nullif(lower((
      select u.raw_app_meta_data->>'role'
      from auth.users u
      where u.id = auth.uid()
      limit 1
    )), ''),
    nullif(lower((
      select u.raw_user_meta_data->>'role'
      from auth.users u
      where u.id = auth.uid()
      limit 1
    )), ''),
    (select lower(p.role) from public.profiles p where p.id = auth.uid() limit 1),
    nullif(lower(auth.jwt()->'app_metadata'->>'role'), ''),
    nullif(lower(auth.jwt()->'user_metadata'->>'role'), ''),
    'customer'
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() in ('admin', 'owner');
$$;

create or replace function public.is_pengurus()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() = 'pengurus';
$$;

create or replace function public.sync_armada_statuses()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (timezone('Asia/Jakarta', now()))::date;
begin
  if not (public.is_staff() or public.is_pengurus()) then
    return;
  end if;

  with invoice_usage as (
    select
      i.armada_id,
      i.armada_end_date::date as armada_end_date,
      coalesce(i.status, '') as status
    from public.invoices i
    where i.armada_id is not null

    union all

    select
      (detail.value->>'armada_id')::uuid as armada_id,
      case
        when coalesce(detail.value->>'armada_end_date', '') ~ '^\d{4}-\d{2}-\d{2}'
          then (detail.value->>'armada_end_date')::date
        else null
      end as armada_end_date,
      coalesce(i.status, '') as status
    from public.invoices i
    cross join lateral jsonb_array_elements(
      case
        when jsonb_typeof(coalesce(i.rincian, '[]'::jsonb)) = 'array'
          then coalesce(i.rincian, '[]'::jsonb)
        else '[]'::jsonb
      end
    ) as detail(value)
    where coalesce(detail.value->>'armada_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  ),
  blocked_armadas as (
    select distinct iu.armada_id
    from invoice_usage iu
    where iu.armada_id is not null
      and lower(iu.status) not like '%cancel%'
      and lower(iu.status) not like '%reject%'
      and (
        (
          iu.armada_end_date is null
          and (
            lower(iu.status) like '%full%'
            or lower(iu.status) like '%on the way%'
            or lower(iu.status) like '%waiting%'
            or lower(iu.status) like '%unpaid%'
            or lower(iu.status) like '%paid%'
            or lower(iu.status) like '%progress%'
          )
        )
        or (
          iu.armada_end_date is not null
          and v_today < iu.armada_end_date
        )
      )
  ),
  target_status as (
    select
      a.id,
      case
        when b.armada_id is null then 'Ready'
        else 'Full'
      end as next_status
    from public.armadas a
    left join blocked_armadas b on b.armada_id = a.id
    where coalesce(a.is_active, true)
      and lower(coalesce(a.status, '')) not in (
        'inactive',
        'non active',
        'non-active'
      )
  )
  update public.armadas a
  set
    status = target_status.next_status,
    updated_at = timezone('utc', now())
  from target_status
  where a.id = target_status.id
    and lower(coalesce(a.status, '')) <> lower(target_status.next_status);
end;
$$;

alter table public.armadas
  add column if not exists kapasitas numeric(12,2) not null default 0,
  add column if not exists status text not null default 'Ready';

alter table public.invoices
  add column if not exists submission_role text not null default 'admin',
  add column if not exists approval_status text not null default 'approved',
  add column if not exists approval_requested_at timestamptz,
  add column if not exists approval_requested_by uuid references public.profiles(id) on delete set null,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references public.profiles(id) on delete set null,
  add column if not exists rejected_at timestamptz,
  add column if not exists rejected_by uuid references public.profiles(id) on delete set null,
  add column if not exists edit_request_status text not null default 'none',
  add column if not exists edit_requested_at timestamptz,
  add column if not exists edit_requested_by uuid references public.profiles(id) on delete set null,
  add column if not exists edit_resolved_at timestamptz,
  add column if not exists edit_resolved_by uuid references public.profiles(id) on delete set null;

alter table public.invoices
  alter column no_invoice drop not null;

update public.invoices
set submission_role = 'admin'
where coalesce(trim(submission_role), '') = '';

update public.invoices
set approval_status = 'approved'
where coalesce(trim(approval_status), '') = '';

update public.invoices
set edit_request_status = 'none'
where coalesce(trim(edit_request_status), '') = '';

create or replace function public.create_role_notifications(
  target_roles text[],
  p_title text,
  p_message text,
  p_kind text default 'info',
  p_source_type text default null,
  p_source_id uuid default null,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  if coalesce(array_length(target_roles, 1), 0) = 0 then
    return 0;
  end if;

  insert into public.customer_notifications (
    user_id,
    title,
    message,
    status,
    kind,
    source_type,
    source_id,
    payload,
    created_at
  )
  select
    p.id,
    coalesce(nullif(trim(p_title), ''), 'Notifikasi'),
    coalesce(nullif(trim(p_message), ''), '-'),
    'unread',
    coalesce(nullif(trim(p_kind), ''), 'info'),
    nullif(trim(p_source_type), ''),
    p_source_id,
    coalesce(p_payload, '{}'::jsonb),
    timezone('utc', now())
  from public.profiles p
  where lower(coalesce(p.role, '')) in (
    select lower(trim(role_name))
    from unnest(target_roles) as role_name
  );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'unknown',
  app_role text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists device_push_tokens_user_id_idx
  on public.device_push_tokens (user_id);
create index if not exists device_push_tokens_active_idx
  on public.device_push_tokens (is_active, last_seen_at desc);

drop trigger if exists trg_device_push_tokens_updated_at on public.device_push_tokens;
create trigger trg_device_push_tokens_updated_at
before update on public.device_push_tokens
for each row
execute function public.set_updated_at();

create or replace function public.upsert_device_push_token(
  p_token text,
  p_platform text default 'unknown',
  p_app_role text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Session tidak ditemukan. Silakan login ulang.';
  end if;

  if coalesce(trim(p_token), '') = '' then
    return;
  end if;

  insert into public.device_push_tokens (
    user_id,
    token,
    platform,
    app_role,
    is_active,
    last_seen_at,
    created_at,
    updated_at
  )
  values (
    auth.uid(),
    trim(p_token),
    lower(coalesce(nullif(trim(p_platform), ''), 'unknown')),
    lower(coalesce(nullif(trim(p_app_role), ''), public.current_role())),
    true,
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (token) do update
  set
    user_id = auth.uid(),
    platform = excluded.platform,
    app_role = excluded.app_role,
    is_active = true,
    last_seen_at = timezone('utc', now()),
    updated_at = timezone('utc', now());
end;
$$;

create or replace function public.deactivate_device_push_token(
  p_token text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  update public.device_push_tokens
  set
    is_active = false,
    updated_at = timezone('utc', now())
  where user_id = auth.uid()
    and token = trim(coalesce(p_token, ''));
end;
$$;

create or replace function public.request_pengurus_invoice_edit(
  p_invoice_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Session tidak ditemukan. Silakan login ulang.';
  end if;

  if not public.is_pengurus() then
    raise exception 'Hanya pengurus yang dapat meminta ACC edit invoice.';
  end if;

  update public.invoices
  set
    edit_request_status = 'pending',
    edit_requested_at = timezone('utc', now()),
    edit_requested_by = auth.uid(),
    edit_resolved_at = null,
    edit_resolved_by = null,
    updated_at = timezone('utc', now())
  where id = p_invoice_id
    and created_by = auth.uid();

  if not found then
    raise exception 'Invoice pengurus tidak ditemukan.';
  end if;
end;
$$;

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
  v_is_pengurus boolean := false;
  v_email text;
  v_name text;
  v_username text;
  v_customer_id uuid;
  v_armada_id uuid;
  v_order_id uuid;
  v_invoice_id uuid;
  v_invoice_number text;
begin
  if v_user_id is null then
    raise exception 'Session tidak ditemukan. Silakan login ulang.';
  end if;

  select exists (
    select 1
    from auth.users u
    where u.id = v_user_id
      and lower(
        coalesce(
          nullif(u.raw_app_meta_data->>'role', ''),
          nullif(u.raw_user_meta_data->>'role', ''),
          ''
        )
      ) = 'pengurus'
  ) or exists (
    select 1
    from public.profiles p
    where p.id = v_user_id
      and lower(coalesce(p.role, '')) = 'pengurus'
  )
  into v_is_pengurus;

  if not v_is_pengurus then
    raise exception 'Hanya pengurus yang dapat menambah income.';
  end if;

  select
    lower(coalesce(u.email, '')),
    coalesce(nullif(trim(u.raw_user_meta_data->>'name'), ''), 'Pengurus'),
    lower(
      coalesce(
        nullif(trim(u.raw_user_meta_data->>'username'), ''),
        split_part(coalesce(u.email, ''), '@', 1),
        'pengurus'
      )
    )
  into
    v_email,
    v_name,
    v_username
  from auth.users u
  where u.id = v_user_id;

  insert into public.profiles (
    id,
    email,
    name,
    username,
    avatar_url,
    role,
    updated_at
  )
  values (
    v_user_id,
    v_email,
    v_name,
    v_username,
    null,
    'pengurus',
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    email = excluded.email,
    name = excluded.name,
    username = excluded.username,
    avatar_url = null,
    role = 'pengurus',
    updated_at = timezone('utc', now());

  if coalesce(trim(p_payload->>'customer_id'), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_customer_id := (p_payload->>'customer_id')::uuid;
  end if;

  if coalesce(trim(p_payload->>'armada_id'), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_armada_id := (p_payload->>'armada_id')::uuid;
  end if;

  if coalesce(trim(p_payload->>'order_id'), '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_order_id := (p_payload->>'order_id')::uuid;
  end if;

  insert into public.invoices (
    no_invoice,
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
    coalesce(nullif(trim(p_payload->>'tanggal'), ''), current_date::text)::date,
    case
      when coalesce(trim(p_payload->>'tanggal_kop'), '') = '' then null
      else (p_payload->>'tanggal_kop')::date
    end,
    nullif(trim(coalesce(p_payload->>'lokasi_kop', '')), ''),
    coalesce(nullif(trim(p_payload->>'nama_pelanggan'), ''), 'Customer'),
    nullif(trim(coalesce(p_payload->>'email', '')), ''),
    nullif(trim(coalesce(p_payload->>'no_telp', '')), ''),
    case
      when coalesce(trim(p_payload->>'due_date'), '') = '' then null
      else (p_payload->>'due_date')::date
    end,
    nullif(trim(coalesce(p_payload->>'lokasi_muat', '')), ''),
    nullif(trim(coalesce(p_payload->>'lokasi_bongkar', '')), ''),
    v_customer_id,
    v_armada_id,
    case
      when coalesce(trim(p_payload->>'armada_start_date'), '') = '' then null
      else (p_payload->>'armada_start_date')::date
    end,
    case
      when coalesce(trim(p_payload->>'armada_end_date'), '') = '' then null
      else (p_payload->>'armada_end_date')::date
    end,
    nullif(trim(coalesce(p_payload->>'tonase', '')), '')::numeric,
    nullif(trim(coalesce(p_payload->>'harga', '')), '')::numeric,
    nullif(trim(coalesce(p_payload->>'muatan', '')), ''),
    nullif(trim(coalesce(p_payload->>'nama_supir', '')), ''),
    coalesce(nullif(trim(p_payload->>'status'), ''), 'Unpaid'),
    coalesce(nullif(trim(p_payload->>'total_biaya'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'pph'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'total_bayar'), ''), '0')::numeric,
    coalesce(nullif(trim(p_payload->>'diterima_oleh'), ''), 'Pengurus'),
    v_user_id,
    v_order_id,
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

create or replace function public.delete_pengurus_income_invoice(
  p_invoice_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted_count integer := 0;
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
    raise exception 'Hanya pengurus yang dapat menghapus income.';
  end if;

  delete from public.invoices i
  where i.id = p_invoice_id
    and i.created_by = v_user_id
    and lower(coalesce(i.submission_role, '')) = 'pengurus'
    and lower(coalesce(i.approval_status, 'pending')) <> 'approved';

  get diagnostics v_deleted_count = row_count;
  return v_deleted_count > 0;
end;
$$;

create or replace function public.get_income_form_armadas()
returns table (
  id uuid,
  nama_truk text,
  plat_nomor text,
  kapasitas numeric,
  status text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (public.is_staff() or public.is_pengurus()) then
    return;
  end if;

  perform public.sync_armada_statuses();

  return query
  select
    a.id,
    a.nama_truk,
    a.plat_nomor,
    a.kapasitas,
    a.status,
    a.is_active,
    a.created_at,
    a.updated_at
  from public.armadas a
  order by a.created_at desc;
end;
$$;

create or replace function public.get_income_form_harga_per_ton_rules()
returns table (
  id uuid,
  lokasi_muat text,
  lokasi_bongkar text,
  harga_per_ton numeric,
  is_active boolean,
  priority integer,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (public.is_staff() or public.is_pengurus()) then
    return;
  end if;

  return query
  select
    h.id,
    h.lokasi_muat,
    h.lokasi_bongkar,
    h.harga_per_ton,
    h.is_active,
    h.priority,
    h.created_at,
    h.updated_at
  from public.harga_per_ton_rules h
  where h.is_active
  order by h.priority desc, h.created_at desc;
end;
$$;

alter table public.armadas enable row level security;
alter table public.invoices enable row level security;
alter table public.expenses enable row level security;
alter table public.sangu_driver_rules enable row level security;
alter table public.harga_per_ton_rules enable row level security;
alter table public.customer_notifications enable row level security;
alter table public.device_push_tokens enable row level security;

drop policy if exists armadas_select_policy on public.armadas;
create policy armadas_select_policy
on public.armadas
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists invoices_modify_policy on public.invoices;
drop policy if exists invoices_select_policy on public.invoices;
create policy invoices_select_policy
on public.invoices
for select
to authenticated
using (
  public.is_staff()
  or (
    auth.uid() = created_by
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and lower(coalesce(p.role, '')) = 'pengurus'
    )
  )
);

drop policy if exists invoices_insert_policy on public.invoices;
create policy invoices_insert_policy
on public.invoices
for insert
to authenticated
with check (
  public.is_staff()
  or (
    auth.uid() = created_by
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and lower(coalesce(p.role, '')) = 'pengurus'
    )
    and lower(coalesce(submission_role, '')) = 'pengurus'
    and lower(coalesce(approval_status, 'pending')) = 'pending'
  )
);

drop policy if exists invoices_update_policy on public.invoices;
create policy invoices_update_policy
on public.invoices
for update
to authenticated
using (
  public.is_staff()
  or (
    auth.uid() = created_by
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and lower(coalesce(p.role, '')) = 'pengurus'
    )
    and lower(coalesce(edit_request_status, 'none')) = 'approved'
  )
)
with check (
  public.is_staff()
  or (
    auth.uid() = created_by
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and lower(coalesce(p.role, '')) = 'pengurus'
    )
    and lower(coalesce(submission_role, '')) = 'pengurus'
  )
);

drop policy if exists invoices_delete_policy on public.invoices;
create policy invoices_delete_policy
on public.invoices
for delete
to authenticated
using (
  public.is_staff()
  or (
    auth.uid() = created_by
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and lower(coalesce(p.role, '')) = 'pengurus'
    )
    and lower(coalesce(submission_role, '')) = 'pengurus'
    and lower(coalesce(approval_status, 'pending')) <> 'approved'
  )
);

drop policy if exists expenses_select_policy on public.expenses;
create policy expenses_select_policy
on public.expenses
for select
to authenticated
using (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
);

drop policy if exists expenses_insert_policy on public.expenses;
create policy expenses_insert_policy
on public.expenses
for insert
to authenticated
with check (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
);

drop policy if exists expenses_update_policy on public.expenses;
create policy expenses_update_policy
on public.expenses
for update
to authenticated
using (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
)
with check (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
);

drop policy if exists expenses_delete_policy on public.expenses;
create policy expenses_delete_policy
on public.expenses
for delete
to authenticated
using (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
);

drop policy if exists sangu_driver_rules_select_policy on public.sangu_driver_rules;
create policy sangu_driver_rules_select_policy
on public.sangu_driver_rules
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists harga_per_ton_rules_select_policy on public.harga_per_ton_rules;
create policy harga_per_ton_rules_select_policy
on public.harga_per_ton_rules
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists device_push_tokens_select_policy on public.device_push_tokens;
create policy device_push_tokens_select_policy
on public.device_push_tokens
for select
to authenticated
using (auth.uid() = user_id or public.is_staff());

drop policy if exists device_push_tokens_insert_policy on public.device_push_tokens;
create policy device_push_tokens_insert_policy
on public.device_push_tokens
for insert
to authenticated
with check (auth.uid() = user_id or public.is_staff());

drop policy if exists device_push_tokens_update_policy on public.device_push_tokens;
create policy device_push_tokens_update_policy
on public.device_push_tokens
for update
to authenticated
using (auth.uid() = user_id or public.is_staff())
with check (auth.uid() = user_id or public.is_staff());

drop policy if exists device_push_tokens_delete_policy on public.device_push_tokens;
create policy device_push_tokens_delete_policy
on public.device_push_tokens
for delete
to authenticated
using (auth.uid() = user_id or public.is_staff());

grant execute on function public.is_pengurus() to anon, authenticated;
grant execute on function public.current_role() to anon, authenticated;
grant execute on function public.is_staff() to anon, authenticated;
grant execute on function public.sync_armada_statuses() to authenticated;
grant execute on function public.get_income_form_armadas() to authenticated;
grant execute on function public.get_income_form_harga_per_ton_rules() to authenticated;
grant execute on function public.create_pengurus_income_invoice(jsonb) to authenticated;
grant execute on function public.delete_pengurus_income_invoice(uuid) to authenticated;
grant execute on function public.upsert_device_push_token(text, text, text) to authenticated;
grant execute on function public.deactivate_device_push_token(text) to authenticated;
grant select on public.armadas to authenticated;
grant select on public.harga_per_ton_rules to authenticated;
grant select, insert, update, delete on public.device_push_tokens to authenticated;
revoke all on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) from public;
grant execute on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) to authenticated;
revoke all on function public.upsert_device_push_token(text, text, text) from public;
grant execute on function public.upsert_device_push_token(text, text, text) to authenticated;
revoke all on function public.deactivate_device_push_token(text) from public;
grant execute on function public.deactivate_device_push_token(text) to authenticated;
revoke all on function public.request_pengurus_invoice_edit(uuid) from public;
grant execute on function public.request_pengurus_invoice_edit(uuid) to authenticated;

-- Harga per ton baseline updates.
update public.harga_per_ton_rules
set
  harga_per_ton = 80,
  is_active = true,
  updated_at = timezone('utc', now())
where lower(trim(lokasi_bongkar)) = 'kediri';

insert into public.harga_per_ton_rules (
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  priority,
  is_active
)
select
  null,
  'Kediri',
  80,
  0,
  true
where not exists (
  select 1
  from public.harga_per_ton_rules
  where lower(trim(lokasi_bongkar)) = 'kediri'
);

update public.harga_per_ton_rules
set
  harga_per_ton = 75,
  is_active = true,
  updated_at = timezone('utc', now())
where lower(trim(lokasi_bongkar)) = 'molindo';

insert into public.harga_per_ton_rules (
  lokasi_muat,
  lokasi_bongkar,
  harga_per_ton,
  priority,
  is_active
)
select
  null,
  'Molindo',
  75,
  0,
  true
where not exists (
  select 1
  from public.harga_per_ton_rules
  where lower(trim(lokasi_bongkar)) = 'molindo'
);
