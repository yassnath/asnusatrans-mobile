begin;

alter table public.harga_per_ton_rules
  add column if not exists customer_name text,
  add column if not exists flat_total numeric(14,2);

drop index if exists harga_per_ton_rules_route_lower_unique;
create unique index if not exists harga_per_ton_rules_route_customer_lower_unique
  on public.harga_per_ton_rules (
    lower(coalesce(customer_name, '')),
    lower(coalesce(lokasi_muat, '')),
    lower(lokasi_bongkar)
  );

create index if not exists harga_per_ton_rules_customer_lower_idx
  on public.harga_per_ton_rules (lower(coalesce(customer_name, '')));

delete from public.harga_per_ton_rules
where lower(coalesce(customer_name, '')) in ('', 'pt bornava indobara mandiri', 'giono')
  and lower(coalesce(lokasi_bongkar, '')) in ('batang', 'nganjuk driyo');

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
  (null, null, 'Batang', 235.00, null, 100, true),
  ('PT Bornava Indobara Mandiri', null, 'Batang', 225.00, null, 200, true),
  ('Giono', null, 'Nganjuk Driyo', 0.00, 1600000.00, 250, true);

commit;
