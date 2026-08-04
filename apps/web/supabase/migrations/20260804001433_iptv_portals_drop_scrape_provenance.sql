-- Product table: drop scrape provenance (post_id, layer).
-- Lineage stays on iptv_scrape_deep_refs / iptv_scrape_deep_ref_portals.portal_id.
-- Owns upsert_iptv_catalog_candidate (catalog scrape promote) — not user upsert_iptv_portal.

-- Platform col needed for promote (default xtream). Idempotent if RFC-051 already added it.
alter table public.iptv_portals
  add column if not exists platform text not null default 'xtream';

alter table public.iptv_portals
  drop constraint if exists iptv_portals_platform_check;

alter table public.iptv_portals
  add constraint iptv_portals_platform_check
  check (platform in ('xtream', 'm3u', 'stalker'));

-- Old signature (includes p_layer + p_post_id). Must drop before recreating —
-- Postgres overloads; leaving both would break PostgREST arg matching.
drop function if exists public.upsert_iptv_catalog_candidate(
  text, text, text, text, text, boolean, text, text, text, text, text, text[], real
);

-- Mid signatures if a partial deploy left an intermediate overload.
drop function if exists public.upsert_iptv_catalog_candidate(
  text, text, text, text, boolean, text, text, text, text, text[], real
);

drop function if exists public.upsert_iptv_catalog_candidate(
  text, text, text, text, boolean, text, text, text, text, text[], real, text
);

create function public.upsert_iptv_catalog_candidate(
  p_url text,
  p_username text,
  p_password text,
  p_source text default 'catalog',
  p_alive boolean default null,
  p_expiry text default null,
  p_max_connections text default null,
  p_timezone text default null,
  p_region_primary text default 'UNKNOWN',
  p_region_tags text[] default null,
  p_region_confidence real default null,
  p_platform text default 'xtream'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  pid uuid;
  plat text := lower(trim(coalesce(nullif(trim(p_platform), ''), 'xtream')));
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin or service role only';
  end if;

  if plat not in ('xtream', 'm3u', 'stalker') then
    raise exception 'invalid platform: %', plat;
  end if;

  insert into public.iptv_portals (
    url, username, password, source, catalog_pool, alive, expiry,
    max_connections, timezone, region_primary, region_tags, region_confidence,
    platform, last_checked_at
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    coalesce(p_source, 'catalog'),
    true,
    p_alive,
    p_expiry,
    p_max_connections,
    p_timezone,
    coalesce(nullif(trim(p_region_primary), ''), 'UNKNOWN'),
    coalesce(p_region_tags, '{}'::text[]),
    coalesce(p_region_confidence, 0),
    plat,
    case when p_alive is null then null else now() end
  )
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
    platform = excluded.platform,
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
  text, text, text, text, boolean, text, text, text, text, text[], real, text
) to authenticated, service_role;

alter table public.iptv_portals
  drop constraint if exists iptv_portals_layer_check;

alter table public.iptv_portals
  drop column if exists post_id,
  drop column if exists layer;

comment on table public.iptv_portals is
  'Canonical portal rows (app + deal pool). Scrape provenance lives on iptv_scrape_* only.';
