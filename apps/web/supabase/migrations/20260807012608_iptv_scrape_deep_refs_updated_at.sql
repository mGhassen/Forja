-- Track last scrape touch on deep refs (upsert reuses post_id+payload_hash;
-- created_at stays first-seen and misleads the admin When column).

alter table public.iptv_scrape_deep_refs
  add column if not exists updated_at timestamptz not null default now();

update public.iptv_scrape_deep_refs d
set updated_at = coalesce(r.started_at, d.created_at)
from public.iptv_scrape_runs r
where r.id = d.scrape_run_id;

create index if not exists iptv_scrape_deep_refs_updated_idx
  on public.iptv_scrape_deep_refs (updated_at desc);

comment on column public.iptv_scrape_deep_refs.updated_at is
  'Last collect/process upsert; created_at remains first insert.';
