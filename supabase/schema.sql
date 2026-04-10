-- Jalankan file ini di Supabase SQL Editor (schema public)
-- Idempotent: aman dijalankan ulang

create extension if not exists pgcrypto;

-- ======================
-- 1) PROFILES + AUTH
-- ======================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null default '',
  username text not null unique,
  avatar_url text,
  phone text,
  gender text,
  birth_date date,
  address text,
  city text,
  company text,
  role text not null default 'customer' check (role in ('customer', 'admin', 'owner', 'pengurus')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  alter table public.profiles
    drop constraint if exists profiles_role_check;
  alter table public.profiles
    add constraint profiles_role_check
    check (role in ('customer', 'admin', 'owner', 'pengurus'));
exception
  when duplicate_object then null;
end;
$$;

create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));

create unique index if not exists profiles_email_lower_unique
  on public.profiles (lower(email));

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_role text;
  v_birth_date date;
begin
  v_username := lower(
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'username'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    )
  );

  if v_username is null or v_username = '' then
    v_username := 'user_' || substr(new.id::text, 1, 8);
  end if;

  if exists(select 1 from public.profiles p where lower(p.username) = lower(v_username) and p.id <> new.id) then
    v_username := v_username || '_' || substr(new.id::text, 1, 6);
  end if;

  -- Security hardening:
  -- Semua user yang daftar dari aplikasi selalu masuk sebagai customer.
  -- Role admin/owner hanya boleh ditetapkan oleh proses bootstrap/admin server-side.
  v_role := 'customer';

  begin
    if nullif(trim(new.raw_user_meta_data->>'birth_date'), '') is not null then
      v_birth_date := (new.raw_user_meta_data->>'birth_date')::date;
    else
      v_birth_date := null;
    end if;
  exception
    when others then
      v_birth_date := null;
  end;

  insert into public.profiles (
    id,
    email,
    name,
    username,
    phone,
    gender,
    birth_date,
    address,
    city,
    company,
    role
  )
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), 'User'),
    lower(v_username),
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    nullif(trim(new.raw_user_meta_data->>'gender'), ''),
    v_birth_date,
    nullif(trim(new.raw_user_meta_data->>'address'), ''),
    nullif(trim(new.raw_user_meta_data->>'city'), ''),
    nullif(trim(new.raw_user_meta_data->>'company'), ''),
    v_role
  )
  on conflict (id) do update
  set
    email = excluded.email,
    name = excluded.name,
    username = excluded.username,
    phone = excluded.phone,
    gender = excluded.gender,
    birth_date = excluded.birth_date,
    address = excluded.address,
    city = excluded.city,
    company = excluded.company,
    role = excluded.role,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_auth_user_created();

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.role from public.profiles p where p.id = auth.uid() limit 1),
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

create or replace function public.get_email_for_login(login_input text)
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    nullif(lower(u.email), ''),
    nullif(lower(p.email), '')
  )
  from public.profiles p
  left join auth.users u on u.id = p.id
  where lower(p.username) = lower(trim(login_input))
  limit 1;
$$;

update public.profiles p
set
  email = lower(u.email),
  updated_at = timezone('utc', now())
from auth.users u
where p.id = u.id
  and lower(coalesce(p.email, '')) <> lower(coalesce(u.email, ''));

do $$
declare
  v_user_id uuid;
  v_email text := 'pengurus@cvant.local';
  v_password text := 'pengurusant';
begin
  select u.id
  into v_user_id
  from auth.users u
  where lower(u.email) = lower(v_email)
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
      '{"provider":"email","providers":["email"]}'::jsonb,
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
      raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
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
    'Pengurus',
    'pengurus',
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
    role = excluded.role,
    updated_at = timezone('utc', now());
end;
$$;

-- ======================
-- 2) MASTER DATA
-- ======================

create table if not exists public.armadas (
  id uuid primary key default gen_random_uuid(),
  nama_truk text not null,
  plat_nomor text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists armadas_nama_idx on public.armadas (nama_truk);
create index if not exists armadas_plat_lower_idx on public.armadas (lower(plat_nomor));

drop trigger if exists trg_armadas_updated_at on public.armadas;
create trigger trg_armadas_updated_at
before update on public.armadas
for each row
execute function public.set_updated_at();

-- ======================
-- 3) TRANSACTIONAL DATA
-- ======================

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  no_invoice text not null unique,
  tanggal date not null default current_date,
  nama_pelanggan text not null,
  customer_id uuid references public.profiles(id) on delete set null,
  armada_id uuid references public.armadas(id) on delete set null,
  status text not null default 'Waiting',
  total_biaya numeric(14,2) not null default 0,
  pph numeric(14,2) not null default 0,
  total_bayar numeric(14,2) not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists invoices_tanggal_idx on public.invoices (tanggal desc);
create index if not exists invoices_customer_id_idx on public.invoices (customer_id);
create index if not exists invoices_armada_id_idx on public.invoices (armada_id);

drop trigger if exists trg_invoices_updated_at on public.invoices;
create trigger trg_invoices_updated_at
before update on public.invoices
for each row
execute function public.set_updated_at();

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  armada_id uuid references public.armadas(id) on delete set null,
  description text,
  qty numeric(12,2) not null default 1,
  unit_price numeric(14,2) not null default 0,
  subtotal numeric(14,2) not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists invoice_items_invoice_id_idx on public.invoice_items (invoice_id);
create index if not exists invoice_items_armada_id_idx on public.invoice_items (armada_id);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  no_expense text not null unique,
  tanggal date not null default current_date,
  total_pengeluaran numeric(14,2) not null default 0,
  status text not null default 'Recorded',
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists expenses_tanggal_idx on public.expenses (tanggal desc);

drop trigger if exists trg_expenses_updated_at on public.expenses;
create trigger trg_expenses_updated_at
before update on public.expenses
for each row
execute function public.set_updated_at();

-- Rule sangu sopir per tujuan/rute (tempat).
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

create unique index if not exists sangu_driver_rules_tempat_lower_unique
  on public.sangu_driver_rules (lower(tempat));
create index if not exists sangu_driver_rules_lokasi_bongkar_lower_idx
  on public.sangu_driver_rules (lower(lokasi_bongkar));

drop trigger if exists trg_sangu_driver_rules_updated_at on public.sangu_driver_rules;
create trigger trg_sangu_driver_rules_updated_at
before update on public.sangu_driver_rules
for each row
execute function public.set_updated_at();

-- Rule harga per ton berdasarkan lokasi bongkar (opsional lokasi muat).
create table if not exists public.harga_per_ton_rules (
  id uuid primary key default gen_random_uuid(),
  lokasi_muat text,
  lokasi_bongkar text not null,
  harga_per_ton numeric(14,2) not null default 0,
  priority int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists harga_per_ton_rules_route_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );
create index if not exists harga_per_ton_rules_bongkar_lower_idx
  on public.harga_per_ton_rules (lower(lokasi_bongkar));
create index if not exists harga_per_ton_rules_priority_idx
  on public.harga_per_ton_rules (priority desc, created_at desc);

drop trigger if exists trg_harga_per_ton_rules_updated_at on public.harga_per_ton_rules;
create trigger trg_harga_per_ton_rules_updated_at
before update on public.harga_per_ton_rules
for each row
execute function public.set_updated_at();

create table if not exists public.fixed_invoice_batches (
  batch_id text primary key,
  invoice_ids text[] not null default '{}',
  invoice_number text not null default '',
  customer_name text not null default '',
  kop_date date,
  kop_location text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists fixed_invoice_batches_created_at_idx
  on public.fixed_invoice_batches (created_at desc);

drop trigger if exists trg_fixed_invoice_batches_updated_at on public.fixed_invoice_batches;
create trigger trg_fixed_invoice_batches_updated_at
before update on public.fixed_invoice_batches
for each row
execute function public.set_updated_at();

create table if not exists public.customer_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  pickup text not null default '-',
  destination text not null default '-',
  pickup_date date,
  service text not null default '-',
  total numeric(14,2) not null default 0,
  status text not null default 'Pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists customer_orders_customer_id_idx on public.customer_orders (customer_id);
create index if not exists customer_orders_created_at_idx on public.customer_orders (created_at desc);

create table if not exists public.customer_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  status text not null default 'unread',
  kind text not null default 'info',
  source_type text,
  source_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists customer_notifications_user_id_idx
  on public.customer_notifications (user_id);
create index if not exists customer_notifications_created_at_idx
  on public.customer_notifications (created_at desc);

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

-- Backward-compat columns for parity with legacy web features.
alter table public.armadas
  add column if not exists kapasitas numeric(12,2) not null default 0,
  add column if not exists status text not null default 'Ready';

alter table public.invoices
  add column if not exists email text,
  add column if not exists no_telp text,
  add column if not exists tanggal_kop date,
  add column if not exists lokasi_kop text,
  add column if not exists nama_supir text,
  add column if not exists due_date date,
  add column if not exists lokasi_muat text,
  add column if not exists lokasi_bongkar text,
  add column if not exists muatan text,
  add column if not exists armada_start_date date,
  add column if not exists armada_end_date date,
  add column if not exists tonase numeric(12,2),
  add column if not exists harga numeric(12,2),
  add column if not exists diterima_oleh text default 'Admin',
  add column if not exists rincian jsonb default '[]'::jsonb,
  add column if not exists order_id uuid,
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

update public.invoices
set submission_role = 'admin'
where coalesce(trim(submission_role), '') = '';

update public.invoices
set approval_status = 'approved'
where coalesce(trim(approval_status), '') = '';

update public.invoices
set edit_request_status = 'none'
where coalesce(trim(edit_request_status), '') = '';

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invoices'
      and column_name = 'muat_apa'
  ) then
    execute $q$
      update public.invoices
      set muatan = coalesce(nullif(trim(muatan), ''), nullif(trim(muat_apa), ''))
      where coalesce(trim(muatan), '') = '';
    $q$;
  end if;
end;
$$;

alter table public.invoices
  drop column if exists muat_apa;

create index if not exists invoices_order_id_idx on public.invoices (order_id);

alter table public.expenses
  add column if not exists kategori text,
  add column if not exists keterangan text,
  add column if not exists nama_supir text,
  add column if not exists dicatat_oleh text,
  add column if not exists rincian jsonb default '[]'::jsonb;

alter table public.customer_orders
  add column if not exists pickup_time text default '00:00',
  add column if not exists fleet text default '-',
  add column if not exists cargo text,
  add column if not exists weight numeric(10,2),
  add column if not exists distance numeric(10,2),
  add column if not exists notes text,
  add column if not exists insurance boolean not null default false,
  add column if not exists estimate numeric(14,2) not null default 0,
  add column if not exists insurance_fee numeric(14,2) not null default 0,
  add column if not exists payment_method text,
  add column if not exists paid_at timestamptz;

alter table public.profiles
  add column if not exists avatar_url text;

drop trigger if exists trg_customer_orders_updated_at on public.customer_orders;
create trigger trg_customer_orders_updated_at
before update on public.customer_orders
for each row
execute function public.set_updated_at();

-- ======================
-- 4) RLS POLICIES
-- ======================

alter table public.profiles enable row level security;
alter table public.armadas enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.expenses enable row level security;
alter table public.sangu_driver_rules enable row level security;
alter table public.harga_per_ton_rules enable row level security;
alter table public.fixed_invoice_batches enable row level security;
alter table public.customer_orders enable row level security;
alter table public.customer_notifications enable row level security;

-- profiles
drop policy if exists profiles_select_policy on public.profiles;
create policy profiles_select_policy
on public.profiles
for select
to authenticated
using (auth.uid() = id or public.is_staff());

drop policy if exists profiles_insert_policy on public.profiles;
create policy profiles_insert_policy
on public.profiles
for insert
to authenticated
with check (
  (auth.uid() = id and role = 'customer')
  or public.is_staff()
);

drop policy if exists profiles_update_policy on public.profiles;
create policy profiles_update_policy
on public.profiles
for update
to authenticated
using (auth.uid() = id or public.is_staff())
with check (
  (
    auth.uid() = id
    and role = coalesce((select p.role from public.profiles p where p.id = auth.uid()), 'customer')
  )
  or public.is_staff()
);

-- armadas
drop policy if exists armadas_select_policy on public.armadas;
create policy armadas_select_policy
on public.armadas
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists armadas_modify_policy on public.armadas;
create policy armadas_modify_policy
on public.armadas
for all
to authenticated
using (public.is_staff())
with check (public.is_staff());

-- invoices
drop policy if exists invoices_select_policy on public.invoices;
create policy invoices_select_policy
on public.invoices
for select
to authenticated
using (
  public.is_staff()
  or (public.is_pengurus() and auth.uid() = created_by)
);

drop policy if exists invoices_insert_policy on public.invoices;
create policy invoices_insert_policy
on public.invoices
for insert
to authenticated
with check (
  public.is_staff()
  or (
    public.is_pengurus()
    and auth.uid() = created_by
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
    public.is_pengurus()
    and auth.uid() = created_by
    and lower(coalesce(edit_request_status, 'none')) = 'approved'
  )
)
with check (
  public.is_staff()
  or (
    public.is_pengurus()
    and auth.uid() = created_by
    and lower(coalesce(submission_role, '')) = 'pengurus'
  )
);

drop policy if exists invoices_delete_policy on public.invoices;
create policy invoices_delete_policy
on public.invoices
for delete
to authenticated
using (public.is_staff());

-- invoice_items
drop policy if exists invoice_items_select_policy on public.invoice_items;
create policy invoice_items_select_policy
on public.invoice_items
for select
to authenticated
using (public.is_staff());

drop policy if exists invoice_items_modify_policy on public.invoice_items;
create policy invoice_items_modify_policy
on public.invoice_items
for all
to authenticated
using (public.is_staff())
with check (public.is_staff());

-- expenses
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

-- sangu_driver_rules
drop policy if exists sangu_driver_rules_select_policy on public.sangu_driver_rules;
create policy sangu_driver_rules_select_policy
on public.sangu_driver_rules
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists sangu_driver_rules_modify_policy on public.sangu_driver_rules;
create policy sangu_driver_rules_modify_policy
on public.sangu_driver_rules
for all
to authenticated
using (public.is_staff())
with check (public.is_staff());

-- harga_per_ton_rules
drop policy if exists harga_per_ton_rules_select_policy on public.harga_per_ton_rules;
create policy harga_per_ton_rules_select_policy
on public.harga_per_ton_rules
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists harga_per_ton_rules_modify_policy on public.harga_per_ton_rules;
create policy harga_per_ton_rules_modify_policy
on public.harga_per_ton_rules
for all
to authenticated
using (public.is_staff())
with check (public.is_staff());

-- fixed_invoice_batches
drop policy if exists fixed_invoice_batches_select_policy on public.fixed_invoice_batches;
create policy fixed_invoice_batches_select_policy
on public.fixed_invoice_batches
for select
to authenticated
using (public.is_staff());

drop policy if exists fixed_invoice_batches_modify_policy on public.fixed_invoice_batches;
create policy fixed_invoice_batches_modify_policy
on public.fixed_invoice_batches
for all
to authenticated
using (public.is_staff())
with check (public.is_staff());

-- customer_orders
drop policy if exists customer_orders_select_policy on public.customer_orders;
create policy customer_orders_select_policy
on public.customer_orders
for select
to authenticated
using (auth.uid() = customer_id or public.is_staff());

drop policy if exists customer_orders_insert_policy on public.customer_orders;
create policy customer_orders_insert_policy
on public.customer_orders
for insert
to authenticated
with check (auth.uid() = customer_id or public.is_staff());

drop policy if exists customer_orders_update_policy on public.customer_orders;
create policy customer_orders_update_policy
on public.customer_orders
for update
to authenticated
using (auth.uid() = customer_id or public.is_staff())
with check (auth.uid() = customer_id or public.is_staff());

drop policy if exists customer_orders_delete_policy on public.customer_orders;
create policy customer_orders_delete_policy
on public.customer_orders
for delete
to authenticated
using (public.is_staff());

-- customer_notifications
drop policy if exists customer_notifications_select_policy on public.customer_notifications;
create policy customer_notifications_select_policy
on public.customer_notifications
for select
to authenticated
using (auth.uid() = user_id or public.is_staff());

drop policy if exists customer_notifications_insert_policy on public.customer_notifications;
create policy customer_notifications_insert_policy
on public.customer_notifications
for insert
to authenticated
with check (public.is_staff());

drop policy if exists customer_notifications_update_policy on public.customer_notifications;
create policy customer_notifications_update_policy
on public.customer_notifications
for update
to authenticated
using (auth.uid() = user_id or public.is_staff())
with check (auth.uid() = user_id or public.is_staff());

-- ======================
-- 5) GRANTS
-- ======================

grant usage on schema public to anon, authenticated;

grant execute on function public.current_role() to anon, authenticated;
grant execute on function public.is_staff() to anon, authenticated;
grant execute on function public.is_pengurus() to anon, authenticated;
grant execute on function public.sync_armada_statuses() to authenticated;
grant execute on function public.get_email_for_login(text) to anon, authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.armadas to authenticated;
grant select, insert, update, delete on public.invoices to authenticated;
grant select, insert, update, delete on public.invoice_items to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant select, insert, update, delete on public.sangu_driver_rules to authenticated;
grant select, insert, update, delete on public.harga_per_ton_rules to authenticated;
grant select, insert, update, delete on public.fixed_invoice_batches to authenticated;
grant select, insert, update, delete on public.customer_orders to authenticated;
grant select, insert, update, delete on public.customer_notifications to authenticated;

revoke all on function public.get_email_for_login(text) from public;
grant execute on function public.get_email_for_login(text) to anon, authenticated;
revoke all on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) from public;
grant execute on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) to authenticated;
revoke all on function public.request_pengurus_invoice_edit(uuid) from public;
grant execute on function public.request_pengurus_invoice_edit(uuid) to authenticated;
