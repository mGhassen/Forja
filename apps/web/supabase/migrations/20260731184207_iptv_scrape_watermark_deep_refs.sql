-- Restore scrape deep refs + unparsed retry queue; run funnel unparsed_count;
-- backfill empty subreddit for IPTV_ZONENEW-only catalog scrape.

alter table public.iptv_scrape_runs
  add column if not exists unparsed_count integer not null default 0;

-- ---------------------------------------------------------------------------
-- L2: base64 / paste deep refs (restored; keep payload for extract misses)
-- ---------------------------------------------------------------------------

create table if not exists public.iptv_scrape_deep_refs (
  id uuid primary key default gen_random_uuid(),
  post_id text not null references public.iptv_scrape_posts (post_id) on delete cascade,
  scrape_run_id uuid references public.iptv_scrape_runs (id) on delete set null,
  ref_type text not null check (ref_type in ('b64_url', 'b64_text', 'paste_url')),
  ref_host text not null default '',
  payload_hash text not null default '',
  raw_ref text not null default '',
  payload_text text,
  fetch_ok boolean,
  extract_count integer not null default 0,
  needs_recheck boolean not null default false,
  created_at timestamptz not null default now(),
  unique (post_id, ref_type, payload_hash, ref_host)
);

create index if not exists iptv_scrape_deep_refs_post_idx
  on public.iptv_scrape_deep_refs (post_id);

create index if not exists iptv_scrape_deep_refs_recheck_idx
  on public.iptv_scrape_deep_refs (needs_recheck)
  where needs_recheck is true;

alter table public.iptv_scrape_deep_refs enable row level security;

drop policy if exists iptv_scrape_deep_refs_admin_all on public.iptv_scrape_deep_refs;

create policy iptv_scrape_deep_refs_admin_all
  on public.iptv_scrape_deep_refs for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_scrape_deep_refs
  to authenticated, service_role;

-- Catalog scrape only uses r/IPTV_ZONENEW today.
update public.iptv_scrape_posts
set subreddit = 'IPTV_ZONENEW'
where trim(coalesce(subreddit, '')) = '';
