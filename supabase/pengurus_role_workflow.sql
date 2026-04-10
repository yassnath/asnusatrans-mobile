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
end;
$$;

update auth.users
set
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) ||
    jsonb_build_object(
      'name', 'Pengurus',
      'username', 'pengurus',
      'role', 'pengurus'
    ),
  updated_at = timezone('utc', now())
where lower(email) = lower('pengurus@cvant.local');

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
where lower(u.email) = lower('pengurus@cvant.local')
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

alter table public.armadas enable row level security;
alter table public.invoices enable row level security;
alter table public.expenses enable row level security;
alter table public.sangu_driver_rules enable row level security;
alter table public.harga_per_ton_rules enable row level security;
alter table public.customer_notifications enable row level security;

drop policy if exists armadas_select_policy on public.armadas;
create policy armadas_select_policy
on public.armadas
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

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

grant execute on function public.is_pengurus() to anon, authenticated;
grant execute on function public.current_role() to anon, authenticated;
grant execute on function public.is_staff() to anon, authenticated;
grant execute on function public.sync_armada_statuses() to authenticated;
grant select on public.armadas to authenticated;
grant select on public.harga_per_ton_rules to authenticated;
revoke all on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) from public;
grant execute on function public.create_role_notifications(text[], text, text, text, text, uuid, jsonb) to authenticated;
revoke all on function public.request_pengurus_invoice_edit(uuid) from public;
grant execute on function public.request_pengurus_invoice_edit(uuid) to authenticated;
