begin;

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

create index if not exists customer_notifications_finance_period_idx
  on public.customer_notifications (
    user_id,
    source_type,
    ((payload->>'notification_type')),
    ((payload->>'period_start'))
  )
  where source_type = 'scheduled_finance_reminder';

alter table public.customer_notifications enable row level security;

drop policy if exists customer_notifications_select_policy
  on public.customer_notifications;
create policy customer_notifications_select_policy
on public.customer_notifications
for select
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.role, '')) in ('admin', 'owner')
  )
);

drop policy if exists customer_notifications_insert_policy
  on public.customer_notifications;
create policy customer_notifications_insert_policy
on public.customer_notifications
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.role, '')) in ('admin', 'owner')
  )
);

drop policy if exists customer_notifications_update_policy
  on public.customer_notifications;
create policy customer_notifications_update_policy
on public.customer_notifications
for update
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.role, '')) in ('admin', 'owner')
  )
)
with check (
  auth.uid() = user_id
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and lower(coalesce(p.role, '')) in ('admin', 'owner')
  )
);

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

revoke all on function public.create_role_notifications(
  text[],
  text,
  text,
  text,
  text,
  uuid,
  jsonb
) from public;

grant select, insert, update, delete on public.customer_notifications
  to authenticated;

grant execute on function public.create_role_notifications(
  text[],
  text,
  text,
  text,
  text,
  uuid,
  jsonb
) to authenticated;

notify pgrst, 'reload schema';

commit;
