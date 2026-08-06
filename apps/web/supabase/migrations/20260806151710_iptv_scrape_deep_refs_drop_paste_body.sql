-- Deep refs store paste_url only. Paste body is fetched on demand (scrape process + admin UI).

alter table public.iptv_scrape_deep_refs
  drop column if exists paste_body;

comment on column public.iptv_scrape_deep_refs.paste_url is
  'Paste host URL (e.g. paste.sh). Body is never persisted — fetch when processing or viewing.';
