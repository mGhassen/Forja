-- Run once on EXISTING hosted/local DB (Supabase SQL editor).
-- Same outcome as migration 20260719190903_iptv_unify_portals_catalog_pool.sql
-- Safe-ish to re-run: IF EXISTS / IF NOT EXISTS / DROP IF EXISTS.

-- ---------------------------------------------------------------------------
-- scrape_posts: id-only (drop Reddit text + unused funnel cols)
-- ---------------------------------------------------------------------------

drop table if exists public.iptv_scrape_deep_refs;

alter table public.iptv_scrape_posts
  drop column if exists title,
  drop column if exists body_excerpt,
  drop column if exists shape_flags,
  drop column if exists l1_extract_count,
  drop column if exists deep_ref_count,
  drop column if exists l2_extract_count,
  drop column if exists miss;

-- ---------------------------------------------------------------------------
-- iptv_portals: catalog pool fields
-- ---------------------------------------------------------------------------

alter table public.iptv_portals
  add column if not exists catalog_pool boolean not null default false,
  add column if not exists alive boolean,
  add column if not exists timezone text,
  add column if not exists region_primary text not null default 'UNKNOWN',
  add column if not exists region_tags text[] not null default '{}',
  add column if not exists region_confidence real not null default 0,
  add column if not exists last_checked_at timestamptz,
  add column if not exists dealt_count integer not null default 0,
  add column if not exists post_id text,
  add column if not exists layer text not null default 'l1';

alter table public.iptv_portals
  drop constraint if exists iptv_portals_layer_check;

alter table public.iptv_portals
  add constraint iptv_portals_layer_check
  check (layer in ('l1', 'l2'));

create index if not exists iptv_portals_catalog_pool_idx
  on public.iptv_portals (catalog_pool, alive, region_primary, last_checked_at desc)
  where catalog_pool is true;

-- ---------------------------------------------------------------------------
-- Copy existing candidates → portals (only if candidates table still exists)
-- ---------------------------------------------------------------------------

do $$
begin
  if to_regclass('public.iptv_catalog_candidates') is null then
    raise notice 'iptv_catalog_candidates already gone — skip data copy';
    return;
  end if;

  -- Passwords already ciphertext — do not re-encrypt on copy.
  alter table public.iptv_portals disable trigger iptv_portals_encrypt_password;

  insert into public.iptv_portals (
    url, username, password, source,
    catalog_pool, alive, expiry, max_connections, timezone,
    region_primary, region_tags, region_confidence,
    last_checked_at, dealt_count, post_id, layer,
    created_at, updated_at
  )
  select
    c.url,
    c.username,
    c.password,
    c.source,
    true,
    c.alive,
    c.expiry,
    c.max_connections,
    c.timezone,
    coalesce(nullif(trim(c.region_primary), ''), 'UNKNOWN'),
    coalesce(c.region_tags, '{}'::text[]),
    coalesce(c.region_confidence, 0),
    c.last_checked_at,
    coalesce(c.dealt_count, 0),
    c.post_id,
    coalesce(c.layer, 'l1'),
    c.created_at,
    c.updated_at
  from public.iptv_catalog_candidates c
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_portals.source),
    catalog_pool = true,
    alive = coalesce(excluded.alive, public.iptv_portals.alive),
    expiry = coalesce(excluded.expiry, public.iptv_portals.expiry),
    max_connections = coalesce(
      excluded.max_connections,
      public.iptv_portals.max_connections
    ),
    timezone = coalesce(excluded.timezone, public.iptv_portals.timezone),
    region_primary = coalesce(
      nullif(excluded.region_primary, 'UNKNOWN'),
      public.iptv_portals.region_primary
    ),
    region_tags = case
      when excluded.region_tags is not null and cardinality(excluded.region_tags) > 0
        then excluded.region_tags
      else public.iptv_portals.region_tags
    end,
    region_confidence = coalesce(
      nullif(excluded.region_confidence, 0),
      public.iptv_portals.region_confidence
    ),
    last_checked_at = coalesce(
      excluded.last_checked_at,
      public.iptv_portals.last_checked_at
    ),
    dealt_count = greatest(
      public.iptv_portals.dealt_count,
      excluded.dealt_count
    ),
    post_id = coalesce(excluded.post_id, public.iptv_portals.post_id),
    layer = excluded.layer,
    updated_at = now();

  alter table public.iptv_portals enable trigger iptv_portals_encrypt_password;
end $$;

-- ---------------------------------------------------------------------------
-- RPCs
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
  p_post_id text default null,
  p_region_tags text[] default null,
  p_region_confidence real default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin or service role only';
  end if;

  insert into public.iptv_portals (
    url, username, password, source, catalog_pool, layer, alive, expiry,
    max_connections, timezone, region_primary, region_tags, region_confidence,
    post_id, last_checked_at
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    coalesce(p_source, 'catalog'),
    true,
    coalesce(p_layer, 'l1'),
    p_alive,
    p_expiry,
    p_max_connections,
    p_timezone,
    coalesce(nullif(trim(p_region_primary), ''), 'UNKNOWN'),
    coalesce(p_region_tags, '{}'::text[]),
    coalesce(p_region_confidence, 0),
    p_post_id,
    case when p_alive is null then null else now() end
  )
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_portals.source),
    catalog_pool = true,
    layer = excluded.layer,
    alive = coalesce(excluded.alive, public.iptv_portals.alive),
    expiry = coalesce(excluded.expiry, public.iptv_portals.expiry),
    max_connections = coalesce(
      excluded.max_connections,
      public.iptv_portals.max_connections
    ),
    timezone = coalesce(excluded.timezone, public.iptv_portals.timezone),
    region_primary = coalesce(
      nullif(excluded.region_primary, 'UNKNOWN'),
      public.iptv_portals.region_primary
    ),
    region_tags = case
      when excluded.region_tags is not null and cardinality(excluded.region_tags) > 0
        then excluded.region_tags
      else public.iptv_portals.region_tags
    end,
    region_confidence = coalesce(
      nullif(excluded.region_confidence, 0),
      public.iptv_portals.region_confidence
    ),
    post_id = coalesce(excluded.post_id, public.iptv_portals.post_id),
    last_checked_at = coalesce(
      excluded.last_checked_at,
      public.iptv_portals.last_checked_at
    ),
    updated_at = now()
  returning id into pid;

  return pid;
end;
$$;

grant execute on function public.upsert_iptv_catalog_candidate(
  text, text, text, text, text, boolean, text, text, text, text, text, text[], real
) to authenticated, service_role;

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
  dealt_portal_id uuid;
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
    select p.*
    from public.iptv_portals p
    where p.catalog_pool is true
      and p.alive is true
      and (region = 'ANY' or p.region_primary = region or region = any (p.region_tags))
      and not exists (
        select 1
        from public.user_iptv_portals u
        where u.profile_id = p_profile_id
          and u.portal_id = p.id
      )
    order by p.last_checked_at desc nulls last, p.created_at desc
    limit n
  loop
    dealt_portal_id := cand.id;

    insert into public.user_iptv_portals (
      account_id, profile_id, portal_id, portal_name, favorite,
      created_by, updated_by
    )
    values (actor, p_profile_id, dealt_portal_id, '', false, actor, actor)
    on conflict (profile_id, portal_id) do nothing;

    update public.iptv_portals
    set dealt_count = dealt_count + 1, updated_at = now()
    where id = cand.id;

    assigned := assigned + 1;
    return next dealt_portal_id;
  end loop;

  if assigned = 0 then
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

create or replace function public.admin_iptv_catalog_candidate_password(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  pw text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select public._iptv_decrypt_password(p.password)
    into pw
  from public.iptv_portals p
  where p.id = p_id;

  if not found then
    raise exception 'portal not found';
  end if;

  return coalesce(pw, '');
end;
$$;

revoke all on function public.admin_iptv_catalog_candidate_password(uuid) from public;
grant execute on function public.admin_iptv_catalog_candidate_password(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Drop old candidates table
-- ---------------------------------------------------------------------------

drop table if exists public.iptv_catalog_candidates cascade;
