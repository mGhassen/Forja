-- Scrape-sourced expires text for Pool cards (esp. Stalker notes).
-- Distinct from verify get_profile expiry; Check status must not wipe note.

alter table public.iptv_portals
  add column if not exists note text;

alter table public.iptv_scrape_deep_ref_portals
  add column if not exists note text;

comment on column public.iptv_portals.note is
  'Scrape note expires (Stalker paste). Shown on Admin Pool cards; not overwritten by Check status.';
comment on column public.iptv_scrape_deep_ref_portals.note is
  'Scrape note expires for this hit; copied to iptv_portals.note on promote.';

-- Rows that already have scrape expiry → seed note.
update public.iptv_portals
set note = expiry
where note is null
  and platform = 'stalker'
  and expiry is not null
  and btrim(expiry) <> ''
  and lower(btrim(expiry)) <> 'unknown';

update public.iptv_scrape_deep_ref_portals
set note = expiry
where note is null
  and platform = 'stalker'
  and expiry is not null
  and btrim(expiry) <> ''
  and lower(btrim(expiry)) <> 'unknown';

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
  p_platform text default 'xtream',
  p_note text default null
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
    platform, note, last_checked_at, last_scraped_at
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
    nullif(btrim(coalesce(p_note, '')), ''),
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
    note = coalesce(excluded.note, public.iptv_portals.note),
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
  text, text, text, text, boolean, text, text, text, text, text[], real, text, text
) to authenticated, service_role;

create or replace function public.admin_iptv_pool_host_portals(
  p_host text,
  p_q text default null,
  p_inventory text default 'all',
  p_platform text default 'all',
  p_status text default 'all',
  p_region text default 'all',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_host text := lower(btrim(coalesce(p_host, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_total bigint := 0;
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  if v_host = '' then
    return jsonb_build_object('portals', '[]'::jsonb, 'total', 0);
  end if;

  select count(*)
  into v_total
  from public.iptv_portals p
  where coalesce(nullif(p.url_host, ''), '(unknown)') = v_host
    and public._admin_iptv_pool_portal_match(
      p.url_host,
      p.url,
      p.username,
      p.region_primary,
      p.id,
      p.catalog_pool,
      p.platform,
      p.alive,
      p_q,
      p_inventory,
      p_platform,
      p_status,
      p_region
    );

  select coalesce(
    jsonb_agg(
      row_to_json(x)::jsonb
      order by x.created_at desc, x.id asc
    ),
    '[]'::jsonb
  )
  into v_rows
  from (
    select
      p.id,
      p.url,
      p.username,
      p.alive,
      p.expiry,
      p.note,
      p.max_connections,
      p.region_primary,
      p.dealt_count,
      p.catalog_pool,
      p.platform,
      p.updated_at,
      p.created_at,
      p.last_scraped_at,
      (
        select j.deep_ref_id
        from public.iptv_scrape_deep_ref_portals j
        where j.portal_id = p.id
        order by j.created_at desc
        limit 1
      ) as deep_ref_id
    from public.iptv_portals p
    where coalesce(nullif(p.url_host, ''), '(unknown)') = v_host
      and public._admin_iptv_pool_portal_match(
        p.url_host,
        p.url,
        p.username,
        p.region_primary,
        p.id,
        p.catalog_pool,
        p.platform,
        p.alive,
        p_q,
        p_inventory,
        p_platform,
        p_status,
        p_region
      )
    order by p.created_at desc, p.id asc
    limit v_limit
    offset v_offset
  ) x;

  return jsonb_build_object(
    'portals', v_rows,
    'total', v_total
  );
end;
$$;
