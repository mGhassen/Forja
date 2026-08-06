-- last_scraped_at: set only on scrape promote (p_alive is null).
-- last_checked_at / updated_at stay verify + any-write timestamps.

alter table public.iptv_portals
  add column if not exists last_scraped_at timestamptz;

comment on column public.iptv_portals.last_scraped_at is
  'Last catalog scrape upsert (alive null). Distinct from last_checked_at / updated_at.';

-- Best-effort backfill: first pool appearance ≈ scrape for historical rows.
update public.iptv_portals
set last_scraped_at = created_at
where last_scraped_at is null
  and catalog_pool is true;

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
  from_scrape boolean := p_alive is null;
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
    platform, last_checked_at, last_scraped_at
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
    case when from_scrape then null else now() end,
    case when from_scrape then now() else null end
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
    last_scraped_at = case
      when from_scrape then now()
      else public.iptv_portals.last_scraped_at
    end,
    updated_at = now()
  returning id into pid;

  return pid;
end;
$$;

grant execute on function public.upsert_iptv_catalog_candidate(
  text, text, text, text, boolean, text, text, text, text, text[], real, text
) to authenticated, service_role;
