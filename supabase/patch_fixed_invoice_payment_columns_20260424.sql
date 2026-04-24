begin;

alter table public.fixed_invoice_batches
  add column if not exists status text not null default 'Unpaid',
  add column if not exists paid_at date,
  add column if not exists payment_details jsonb not null default '[]'::jsonb,
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

update public.fixed_invoice_batches
set payment_details = '[]'::jsonb
where payment_details is null;

create index if not exists fixed_invoice_batches_updated_at_idx
  on public.fixed_invoice_batches (updated_at desc);

drop trigger if exists trg_fixed_invoice_batches_updated_at on public.fixed_invoice_batches;
create trigger trg_fixed_invoice_batches_updated_at
before update on public.fixed_invoice_batches
for each row
execute function public.set_updated_at();

notify pgrst, 'reload schema';

commit;
