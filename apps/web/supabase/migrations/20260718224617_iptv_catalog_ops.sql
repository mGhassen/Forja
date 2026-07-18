-- RFC-040: IPTV catalog ops — scrape funnel, pool candidates, credits, deal RPC.
-- Shared Supabase with Forja accounts / iptv_portals / user_iptv_portals.

-- ---------------------------------------------------------------------------
-- Credits on accounts
-- ---------------------------------------------------------------------------

alter table public.accounts
  add column if not exists iptv_credits integer not null default 0
  check (iptv_credits >= 0);

comment on column public.accounts.iptv_credits is
  'Credits for dealing IPTV portals from the catalog pool (RFC-040).';

create table public.iptv_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  delta integer not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references public.accounts (id) on delete set null
);

create index iptv_credit_ledger_account_idx
  on public.iptv_credit_ledger (account_id, created_at desc);

alter table public.iptv_credit_ledger enable row level security;

create policy iptv_credit_ledger_admin_all
  on public.iptv_credit_ledger for all
  using (public.is_admin())
  with check (public.is_admin());

create policy iptv_credit_ledger_own_select
  on public.iptv_credit_ledger for select
  using (account_id = auth.uid());

grant select, insert, update, delete on table public.iptv_credit_ledger
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Scrape runs (admin / worker)
-- ---------------------------------------------------------------------------

create table public.iptv_scrape_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'ok', 'error')),
  source text not null default 'reddit',
  posts_seen integer not null default 0,
  l1_extract_count integer not null default 0,
  deep_ref_count integer not null default 0,
  l2_fetch_ok integer not null default 0,
  l2_fetch_fail integer not null default 0,
  l2_extract_count integer not null default 0,
  candidates_upserted integer not null default 0,
  alive_count integer not null default 0,
  error text,
  created_by uuid references public.accounts (id) on delete set null
);

alter table public.iptv_scrape_runs enable row level security;

create policy iptv_scrape_runs_admin_all
  on public.iptv_scrape_runs for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_scrape_runs
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- L1: Reddit posts
-- ---------------------------------------------------------------------------

create table public.iptv_scrape_posts (
  id uuid primary key default gen_random_uuid(),
  post_id text not null unique,
  subreddit text not null default '',
  title text not null default '',
  body_excerpt text not null default '',
  scraped_at timestamptz not null default now(),
  scrape_run_id uuid references public.iptv_scrape_runs (id) on delete set null,
  shape_flags jsonb not null default '{}'::jsonb,
  l1_extract_count integer not null default 0,
  deep_ref_count integer not null default 0,
  l2_extract_count integer not null default 0,
  miss boolean not null default false
);

create index iptv_scrape_posts_scraped_idx
  on public.iptv_scrape_posts (scraped_at desc);

alter table public.iptv_scrape_posts enable row level security;

create policy iptv_scrape_posts_admin_all
  on public.iptv_scrape_posts for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_scrape_posts
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- L2: base64 / paste deep refs
-- ---------------------------------------------------------------------------

create table public.iptv_scrape_deep_refs (
  id uuid primary key default gen_random_uuid(),
  post_id text not null references public.iptv_scrape_posts (post_id) on delete cascade,
  ref_type text not null check (ref_type in ('b64_url', 'b64_text', 'paste_url')),
  ref_host text not null default '',
  payload_hash text not null default '',
  fetch_ok boolean,
  extract_count integer not null default 0,
  created_at timestamptz not null default now(),
  unique (post_id, ref_type, payload_hash, ref_host)
);

create index iptv_scrape_deep_refs_post_idx
  on public.iptv_scrape_deep_refs (post_id);

alter table public.iptv_scrape_deep_refs enable row level security;

create policy iptv_scrape_deep_refs_admin_all
  on public.iptv_scrape_deep_refs for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_scrape_deep_refs
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Catalog pool candidates
-- ---------------------------------------------------------------------------

create table public.iptv_catalog_candidates (
  id uuid primary key default gen_random_uuid(),
  url text not null,
  username text not null,
  password text not null,
  source text not null default 'catalog',
  post_id text,
  layer text not null default 'l1' check (layer in ('l1', 'l2')),
  alive boolean,
  expiry text,
  max_connections text,
  timezone text,
  region_primary text not null default 'UNKNOWN',
  region_tags text[] not null default '{}',
  region_confidence real not null default 0,
  last_checked_at timestamptz,
  dealt_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index iptv_catalog_candidates_url_username_unique
  on public.iptv_catalog_candidates ((lower(trim(url))), (lower(trim(username))));

create index iptv_catalog_candidates_pool_idx
  on public.iptv_catalog_candidates (alive, region_primary, last_checked_at desc);

create trigger iptv_catalog_candidates_set_updated_at
  before update on public.iptv_catalog_candidates
  for each row execute function public.set_updated_at();

alter table public.iptv_catalog_candidates enable row level security;

create policy iptv_catalog_candidates_admin_all
  on public.iptv_catalog_candidates for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_catalog_candidates
  to authenticated, service_role;

-- Encrypt candidate passwords like iptv_portals
create or replace function public._iptv_candidates_encrypt_password_trg()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  new.password := public._iptv_encrypt_password(new.password);
  return new;
end;
$$;

drop trigger if exists iptv_catalog_candidates_encrypt_password
  on public.iptv_catalog_candidates;
create trigger iptv_catalog_candidates_encrypt_password
  before insert or update of password on public.iptv_catalog_candidates
  for each row
  execute function public._iptv_candidates_encrypt_password_trg();

-- ---------------------------------------------------------------------------
-- Admin: grant / revoke credits
-- ---------------------------------------------------------------------------

create or replace function public.admin_adjust_iptv_credits(
  p_account_id uuid,
  p_delta integer,
  p_reason text default ''
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  new_balance integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  if p_delta = 0 then
    raise exception 'delta must be non-zero';
  end if;

  update public.accounts
  set iptv_credits = iptv_credits + p_delta,
      updated_at = now()
  where id = p_account_id
  returning iptv_credits into new_balance;

  if new_balance is null then
    raise exception 'account not found';
  end if;

  insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
  values (p_account_id, p_delta, coalesce(p_reason, ''), auth.uid());

  return new_balance;
end;
$$;

grant execute on function public.admin_adjust_iptv_credits(uuid, integer, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Admin: set iptvScrape feature flag
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_iptv_scrape(
  p_account_id uuid,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  feats jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select features into feats from public.accounts where id = p_account_id;
  if feats is null then
    raise exception 'account not found';
  end if;

  if p_enabled then
    feats := coalesce(feats, '{}'::jsonb) || '{"iptvScrape": true}'::jsonb;
  else
    feats := coalesce(feats, '{}'::jsonb) - 'iptvScrape';
  end if;

  update public.accounts
  set features = feats, updated_at = now()
  where id = p_account_id;

  return feats;
end;
$$;

grant execute on function public.admin_set_iptv_scrape(uuid, boolean)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Deal: burn 1 credit → assign up to N alive candidates to active profile
-- ---------------------------------------------------------------------------

create or replace function public.deal_iptv_portals(
  p_profile_id uuid,
  p_region text default 'ANY',
  p_count integer default 5
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  n integer := greatest(1, least(coalesce(p_count, 5), 20));
  region text := upper(trim(coalesce(p_region, 'ANY')));
  bal integer;
  cand record;
  portal_id uuid;
  assigned integer := 0;
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_profile_id and account_id = actor
  ) then
    raise exception 'profile not found';
  end if;

  select iptv_credits into bal from public.accounts where id = actor for update;
  if bal is null or bal < 1 then
    raise exception 'insufficient credits';
  end if;

  update public.accounts
  set iptv_credits = iptv_credits - 1, updated_at = now()
  where id = actor;

  insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
  values (actor, -1, format('deal %s x%s', region, n), actor);

  for cand in
    select c.*
    from public.iptv_catalog_candidates c
    where c.alive is true
      and (region = 'ANY' or c.region_primary = region or region = any (c.region_tags))
      and not exists (
        select 1
        from public.iptv_portals p
        join public.user_iptv_portals u on u.portal_id = p.id
        where u.profile_id = p_profile_id
          and lower(trim(p.url)) = lower(trim(c.url))
          and lower(trim(p.username)) = lower(trim(c.username))
      )
    order by c.last_checked_at desc nulls last, c.created_at desc
    limit n
  loop
    portal_id := public.upsert_iptv_portal(
      cand.url,
      cand.username,
      public._iptv_decrypt_password(cand.password),
      coalesce(cand.source, 'catalog'),
      cand.expiry,
      cand.max_connections
    );

    insert into public.user_iptv_portals (
      account_id, profile_id, portal_id, portal_name, favorite,
      created_by, updated_by
    )
    values (actor, p_profile_id, portal_id, '', false, actor, actor)
    on conflict (profile_id, portal_id) do nothing;

    update public.iptv_catalog_candidates
    set dealt_count = dealt_count + 1, updated_at = now()
    where id = cand.id;

    assigned := assigned + 1;
    return next portal_id;
  end loop;

  if assigned = 0 then
    -- refund credit when pool empty
    update public.accounts
    set iptv_credits = iptv_credits + 1, updated_at = now()
    where id = actor;
    insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
    values (actor, 1, 'deal refund — empty pool', actor);
    raise exception 'no portals available for region %', region;
  end if;
end;
$$;

grant execute on function public.deal_iptv_portals(uuid, text, integer)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Worker: upsert candidate (service_role / admin)
-- ---------------------------------------------------------------------------

create or replace function public.upsert_iptv_catalog_candidate(
  p_url text,
  p_username text,
  p_password text,
  p_source text default 'catalog',
  p_layer text default 'l1',
  p_alive boolean default null,
  p_expiry text default null,
  p_max_connections text default null,
  p_timezone text default null,
  p_region_primary text default 'UNKNOWN',
  p_post_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  cid uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    -- allow service_role (uid null) and admins only
    raise exception 'admin or service role only';
  end if;

  insert into public.iptv_catalog_candidates (
    url, username, password, source, layer, alive, expiry,
    max_connections, timezone, region_primary, post_id, last_checked_at
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    coalesce(p_source, 'catalog'),
    coalesce(p_layer, 'l1'),
    p_alive,
    p_expiry,
    p_max_connections,
    p_timezone,
    coalesce(nullif(trim(p_region_primary), ''), 'UNKNOWN'),
    p_post_id,
    case when p_alive is null then null else now() end
  )
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_catalog_candidates.source),
    layer = excluded.layer,
    alive = coalesce(excluded.alive, public.iptv_catalog_candidates.alive),
    expiry = coalesce(excluded.expiry, public.iptv_catalog_candidates.expiry),
    max_connections = coalesce(
      excluded.max_connections,
      public.iptv_catalog_candidates.max_connections
    ),
    timezone = coalesce(excluded.timezone, public.iptv_catalog_candidates.timezone),
    region_primary = coalesce(
      nullif(excluded.region_primary, 'UNKNOWN'),
      public.iptv_catalog_candidates.region_primary
    ),
    post_id = coalesce(excluded.post_id, public.iptv_catalog_candidates.post_id),
    last_checked_at = coalesce(
      excluded.last_checked_at,
      public.iptv_catalog_candidates.last_checked_at
    ),
    updated_at = now()
  returning id into cid;

  return cid;
end;
$$;

grant execute on function public.upsert_iptv_catalog_candidate(
  text, text, text, text, text, boolean, text, text, text, text, text
) to authenticated, service_role;
