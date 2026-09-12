-- Admin Pool + Deep refs load perf:
-- - regions RPC (hosts no longer full-scans distinct regions)
-- - pool filter indexes + junction (portal_id, created_at) for deep_ref lateral
-- - host search prefers url_host equality/prefix (indexable)
-- - paginated deep_refs list RPC (no nested portal payload)

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists iptv_portals_platform_idx
  on public.iptv_portals (platform);

create index if not exists iptv_portals_alive_idx
  on public.iptv_portals (alive);

create index if not exists iptv_portals_region_primary_idx
  on public.iptv_portals (region_primary);

create index if not exists iptv_scrape_deep_ref_portals_portal_created_idx
  on public.iptv_scrape_deep_ref_portals (portal_id, created_at desc)
  where portal_id is not null;

create index if not exists iptv_scrape_deep_ref_portals_was_existing_idx
  on public.iptv_scrape_deep_ref_portals (deep_ref_id)
  where was_existing is true;

create index if not exists iptv_scrape_deep_refs_extract_count_idx
  on public.iptv_scrape_deep_refs (extract_count)
  where extract_count > 0;

-- ---------------------------------------------------------------------------
-- Pool match: prefer host equality / prefix before %ilike%
-- ---------------------------------------------------------------------------

create or replace function public._admin_iptv_pool_portal_match(
  p_url_host text,
  p_url text,
  p_username text,
  p_region_primary text,
  p_id uuid,
  p_catalog_pool boolean,
  p_platform text,
  p_alive boolean,
  p_q text,
  p_inventory text,
  p_platform_filter text,
  p_status text,
  p_region text
)
returns boolean
language sql
immutable
parallel safe
as $$
  select
    (
      p_inventory is null
      or p_inventory = 'all'
      or (p_inventory = 'pool' and p_catalog_pool is true)
      or (p_inventory = 'nonpool' and coalesce(p_catalog_pool, false) is not true)
    )
    and (
      p_platform_filter is null
      or p_platform_filter = 'all'
      or p_platform = p_platform_filter
    )
    and (
      p_status is null
      or p_status = 'all'
      or (p_status = 'alive' and p_alive is true)
      or (p_status = 'dead' and p_alive is false)
      or (p_status = 'unchecked' and p_alive is null)
    )
    and (
      p_region is null
      or p_region = 'all'
      or coalesce(nullif(trim(p_region_primary), ''), 'UNKNOWN') = p_region
    )
    and (
      p_q is null
      or btrim(p_q) = ''
      or (
        case
          when btrim(p_q) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          then p_id = btrim(p_q)::uuid
          else
            lower(coalesce(p_url_host, '')) = lower(btrim(p_q))
            or lower(coalesce(p_url_host, '')) like lower(btrim(p_q)) || '%'
            or coalesce(p_url, '') ilike '%' || btrim(p_q) || '%'
            or coalesce(p_username, '') ilike '%' || btrim(p_q) || '%'
            or coalesce(p_region_primary, '') ilike '%' || btrim(p_q) || '%'
        end
      )
    );
$$;

-- ---------------------------------------------------------------------------
-- Regions (once) — not bundled into every hosts page call
-- ---------------------------------------------------------------------------

create or replace function public.admin_iptv_pool_regions()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_regions text[];
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select coalesce(array_agg(r order by r), '{}'::text[])
  into v_regions
  from (
    select distinct coalesce(nullif(trim(region_primary), ''), 'UNKNOWN') as r
    from public.iptv_portals
  ) d;

  return to_jsonb(v_regions);
end;
$$;

revoke all on function public.admin_iptv_pool_regions() from public;
grant execute on function public.admin_iptv_pool_regions()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Hosts: drop per-call distinct regions scan (compat key → [])
-- ---------------------------------------------------------------------------

create or replace function public.admin_iptv_pool_hosts(
  p_q text default null,
  p_inventory text default 'all',
  p_platform text default 'all',
  p_status text default 'all',
  p_region text default 'all',
  p_sort text default 'accounts',
  p_dir text default 'desc',
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
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_sort text := lower(coalesce(nullif(btrim(p_sort), ''), 'accounts'));
  v_dir text := case
    when lower(coalesce(p_dir, 'desc')) = 'asc' then 'asc'
    else 'desc'
  end;
  v_hosts jsonb;
  v_host_count bigint;
  v_portal_count bigint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  if v_sort not in ('host', 'accounts', 'alive', 'scraped') then
    v_sort := 'accounts';
  end if;

  with filtered as (
    select
      p.url_host,
      p.alive,
      coalesce(p.last_scraped_at, p.created_at) as scraped_at
    from public.iptv_portals p
    where public._admin_iptv_pool_portal_match(
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
  ),
  grouped as (
    select
      coalesce(nullif(f.url_host, ''), '(unknown)') as host,
      count(*)::int as accounts,
      count(*) filter (where f.alive is true)::int as alive,
      max(f.scraped_at) as last_scraped_at
    from filtered f
    group by 1
  ),
  counted as (
    select
      (select count(*) from grouped) as host_count,
      (select coalesce(sum(accounts), 0) from grouped) as portal_count
  ),
  ordered as (
    select
      g.*,
      row_number() over (
        order by
          case when v_sort = 'host' and v_dir = 'asc' then g.host end asc nulls last,
          case when v_sort = 'host' and v_dir = 'desc' then g.host end desc nulls last,
          case when v_sort = 'accounts' and v_dir = 'asc' then g.accounts end asc nulls last,
          case when v_sort = 'accounts' and v_dir = 'desc' then g.accounts end desc nulls last,
          case when v_sort = 'alive' and v_dir = 'asc' then g.alive end asc nulls last,
          case when v_sort = 'alive' and v_dir = 'desc' then g.alive end desc nulls last,
          case when v_sort = 'scraped' and v_dir = 'asc' then g.last_scraped_at end asc nulls last,
          case when v_sort = 'scraped' and v_dir = 'desc' then g.last_scraped_at end desc nulls last,
          g.host asc
      ) as rn
    from grouped g
  )
  select
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'host', o.host,
            'accounts', o.accounts,
            'alive', o.alive,
            'last_scraped_at', o.last_scraped_at
          )
          order by o.rn
        )
        from ordered o
        where o.rn > v_offset
          and o.rn <= v_offset + v_limit
      ),
      '[]'::jsonb
    ),
    c.host_count,
    c.portal_count
  into v_hosts, v_host_count, v_portal_count
  from counted c;

  return jsonb_build_object(
    'hosts', v_hosts,
    'host_count', v_host_count,
    'portal_count', v_portal_count,
    'regions', '[]'::jsonb
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Deep refs list (paged, no nested portals)
-- ---------------------------------------------------------------------------

create or replace function public.admin_iptv_deep_refs_list(
  p_q text default null,
  p_status text default 'all',
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
  v_limit int := greatest(1, least(coalesce(p_limit, 50), 100));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_status text := lower(coalesce(nullif(btrim(p_status), ''), 'all'));
  v_q text := nullif(btrim(coalesce(p_q, '')), '');
  v_q_lower text := lower(coalesce(v_q, ''));
  v_rows jsonb;
  v_total bigint := 0;
  v_stats_total bigint := 0;
  v_stats_recheck bigint := 0;
  v_stats_paste bigint := 0;
  v_stats_hits bigint := 0;
  v_stats_not_promoted bigint := 0;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  if v_status not in ('all', 'recheck', 'ok', 'has_portals', 'existing_only') then
    v_status := 'all';
  end if;

  select
    count(*),
    count(*) filter (where d.needs_recheck),
    count(*) filter (where nullif(btrim(d.paste_url), '') is not null),
    coalesce(sum(d.extract_count), 0)
  into v_stats_total, v_stats_recheck, v_stats_paste, v_stats_hits
  from public.iptv_scrape_deep_refs d;

  select count(*)
  into v_stats_not_promoted
  from public.iptv_scrape_deep_ref_portals j
  where j.portal_id is null;

  with matched as (
    select d.id
    from public.iptv_scrape_deep_refs d
    where (
      case v_status
        when 'recheck' then d.needs_recheck
        when 'ok' then not d.needs_recheck
        when 'has_portals' then d.extract_count > 0
        when 'existing_only' then exists (
          select 1
          from public.iptv_scrape_deep_ref_portals j
          where j.deep_ref_id = d.id
            and j.was_existing is true
        )
        else true
      end
    )
    and (
      v_q is null
      or (
        v_q ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and d.id = v_q::uuid
      )
      or lower(d.post_id) like '%' || v_q_lower || '%'
      or lower(d.paste_url) like '%' || v_q_lower || '%'
      or lower(d.ref_host) like '%' || v_q_lower || '%'
      or lower(d.base64) like '%' || v_q_lower || '%'
      or exists (
        select 1
        from public.iptv_scrape_deep_ref_portals j
        where j.deep_ref_id = d.id
          and (
            lower(j.url) like '%' || v_q_lower || '%'
            or lower(j.username) like '%' || v_q_lower || '%'
            or lower(coalesce(j.portal_id::text, '')) = v_q_lower
            or lower(j.platform) like '%' || v_q_lower || '%'
          )
      )
    )
  ),
  counted as (
    select count(*) as total from matched
  ),
  page as (
    select d.*
    from public.iptv_scrape_deep_refs d
    inner join matched m on m.id = d.id
    order by coalesce(d.updated_at, d.created_at) desc, d.id desc
    limit v_limit
    offset v_offset
  )
  select
    c.total,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', p.id,
            'post_id', p.post_id,
            'scrape_run_id', p.scrape_run_id,
            'base64', p.base64,
            'paste_url', p.paste_url,
            'ref_host', p.ref_host,
            'payload_hash', p.payload_hash,
            'fetch_ok', p.fetch_ok,
            'extract_count', p.extract_count,
            'needs_recheck', p.needs_recheck,
            'created_at', p.created_at,
            'updated_at', p.updated_at,
            'run_started_at', (
              select r.started_at
              from public.iptv_scrape_runs r
              where r.id = p.scrape_run_id
            )
          )
          order by coalesce(p.updated_at, p.created_at) desc, p.id desc
        )
        from page p
      ),
      '[]'::jsonb
    )
  into v_total, v_rows
  from counted c;

  return jsonb_build_object(
    'rows', v_rows,
    'total', v_total,
    'stats', jsonb_build_object(
      'total', v_stats_total,
      'recheck', v_stats_recheck,
      'with_paste', v_stats_paste,
      'portal_hits', v_stats_hits,
      'not_promoted', v_stats_not_promoted
    )
  );
end;
$$;

revoke all on function public.admin_iptv_deep_refs_list(
  text, text, integer, integer
) from public;
grant execute on function public.admin_iptv_deep_refs_list(
  text, text, integer, integer
) to authenticated, service_role;
