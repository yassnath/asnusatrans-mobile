begin;

create table if not exists public.fixed_invoice_batches (
  batch_id text primary key,
  invoice_ids text[] not null default '{}',
  invoice_number text not null default '',
  invoice_entity text not null default 'cv_ant',
  customer_name text not null default '',
  kop_date date,
  kop_location text,
  status text not null default 'Unpaid',
  paid_at date,
  payment_details jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.fixed_invoice_batches
  add column if not exists invoice_entity text not null default 'cv_ant',
  add column if not exists status text not null default 'Unpaid',
  add column if not exists paid_at date,
  add column if not exists payment_details jsonb not null default '[]'::jsonb,
  add column if not exists created_at timestamptz not null default timezone('utc', now()),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

update public.fixed_invoice_batches
set payment_details = '[]'::jsonb
where payment_details is null;

create index if not exists fixed_invoice_batches_created_at_idx
  on public.fixed_invoice_batches (created_at desc);

create index if not exists fixed_invoice_batches_updated_at_idx
  on public.fixed_invoice_batches (updated_at desc);

drop trigger if exists trg_fixed_invoice_batches_updated_at on public.fixed_invoice_batches;
create trigger trg_fixed_invoice_batches_updated_at
before update on public.fixed_invoice_batches
for each row
execute function public.set_updated_at();

alter table public.fixed_invoice_batches enable row level security;

drop policy if exists fixed_invoice_batches_select_policy on public.fixed_invoice_batches;
create policy fixed_invoice_batches_select_policy
on public.fixed_invoice_batches
for select
to authenticated
using (public.is_staff() or public.is_pengurus());

drop policy if exists fixed_invoice_batches_modify_policy on public.fixed_invoice_batches;
create policy fixed_invoice_batches_modify_policy
on public.fixed_invoice_batches
for all
to authenticated
using (public.is_staff() or public.is_pengurus())
with check (public.is_staff() or public.is_pengurus());

create or replace function public.get_fixed_invoice_batches()
returns setof public.fixed_invoice_batches
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.fixed_invoice_batches
  where public.is_staff() or public.is_pengurus()
  order by updated_at desc nulls last, created_at desc nulls last;
$$;

grant select, insert, update, delete on public.fixed_invoice_batches to authenticated;
grant execute on function public.get_fixed_invoice_batches() to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.fixed_invoice_batches;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

commit;
