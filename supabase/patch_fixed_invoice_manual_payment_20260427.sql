begin;

alter table public.fixed_invoice_batches
  add column if not exists manual_paid_amount numeric(14,2) not null default 0,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

update public.fixed_invoice_batches
set manual_paid_amount = 0
where manual_paid_amount is null;

drop trigger if exists trg_fixed_invoice_batches_updated_at on public.fixed_invoice_batches;
create trigger trg_fixed_invoice_batches_updated_at
before update on public.fixed_invoice_batches
for each row
execute function public.set_updated_at();

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

notify pgrst, 'reload schema';

commit;
