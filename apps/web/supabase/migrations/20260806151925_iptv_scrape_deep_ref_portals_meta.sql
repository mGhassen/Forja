-- Persist extract meta on junction rows so catalog promote does not need
-- fat portal arrays in Inngest step memo (stream EOF / unexpected end of JSON).

alter table public.iptv_scrape_deep_ref_portals
  add column if not exists expiry text,
  add column if not exists max_connections text,
  add column if not exists timezone text,
  add column if not exists region_primary text,
  add column if not exists region_tags text[] not null default '{}',
  add column if not exists region_confidence double precision not null default 0;

comment on column public.iptv_scrape_deep_ref_portals.expiry is
  'From note / status card; copied to iptv_portals on promote';
comment on column public.iptv_scrape_deep_ref_portals.region_primary is
  'Scrape-time region guess; copied on promote';
