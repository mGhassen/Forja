-- Pool admin UI: denormalized url_host + paginated host/portal RPCs.
-- Avoid loading the full iptv_portals table into the browser.

create or replace function public.iptv_portal_url_host(p_url text)
returns text
language sql
immutable
parallel safe
as $$
  select nullif(
    lower((
      select
        case
          when position('@' in authority) > 0 then split_part(authority, '@', 2)
          else authority
        end
      from (
        select split_part(
          split_part(
            regexp_replace(
              trim(coalesce(p_url, '')),
              '^[a-z][a-z0-9+.-]*://',
              '',
              'i'
            ),
            '/',
            1
          ),
          '?',
          1
        ) as authority
      ) a
    )),
    ''
  );
$$;

comment on function public.iptv_portal_url_host(text) is
  'Hostname(+port) from a portal URL; mirrors admin Pool candidateHost().';

alter table public.iptv_portals
  add column if not exists url_host text;

comment on column public.iptv_portals.url_host is
  'Denormalized host from url — Pool grouping / indexes.';

update public.iptv_portals
set url_host = public.iptv_portal_url_host(url)
where url_host is distinct from public.iptv_portal_url_host(url);

create or replace function public.iptv_portals_set_url_host()
returns trigger
language plpgsql
as $$
begin
  new.url_host := public.iptv_portal_url_host(new.url);
  return new;
end;
$$;

drop trigger if exists iptv_portals_set_url_host on public.iptv_portals;
create trigger iptv_portals_set_url_host
  before insert or update of url on public.iptv_portals
  for each row
  execute function public.iptv_portals_set_url_host();

create index if not exists iptv_portals_url_host_idx
  on public.iptv_portals (url_host);

create index if not exists iptv_portals_url_host_catalog_alive_idx
  on public.iptv_portals (url_host, catalog_pool, alive);

-- ---------------------------------------------------------------------------
-- Shared portal filter (hosts + per-host portal list)
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
            coalesce(p_url_host, '') ilike '%' || btrim(p_q) || '%'
            or coalesce(p_url, '') ilike '%' || btrim(p_q) || '%'
            or coalesce(p_username, '') ilike '%' || btrim(p_q) || '%'
            or coalesce(p_region_primary, '') ilike '%' || btrim(p_q) || '%'
        end
      )
    );
$$;

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
  v_regions text[];
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

  select coalesce(
    array_agg(r order by r),
    '{}'::text[]
  )
  into v_regions
  from (
    select distinct coalesce(nullif(trim(region_primary), ''), 'UNKNOWN') as r
    from public.iptv_portals
  ) d;

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
    'regions', to_jsonb(v_regions)
  );
end;
$$;

create or replace function public.admin_iptv_pool_host_portals(
  p_host text,
  p_q text default null,
  p_inventory text default 'all',
  p_platform text default 'all',
  p_status text default 'all',
  p_region text default 'all'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_host text := lower(btrim(coalesce(p_host, '')));
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;
  if v_host = '' then
    return '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(row_to_json(x)::jsonb order by x.username asc, x.id asc),
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
      p.max_connections,
      p.region_primary,
      p.dealt_count,
      p.catalog_pool,
      p.platform,
      p.updated_at,
      p.created_at,
      p.last_scraped_at
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
  ) x;

  return v_rows;
end;
$$;

revoke all on function public.iptv_portal_url_host(text) from public;
grant execute on function public.iptv_portal_url_host(text)
  to authenticated, service_role;

revoke all on function public._admin_iptv_pool_portal_match(
  text, text, text, text, uuid, boolean, text, boolean, text, text, text, text, text
) from public;

revoke all on function public.admin_iptv_pool_hosts(
  text, text, text, text, text, text, text, integer, integer
) from public;
grant execute on function public.admin_iptv_pool_hosts(
  text, text, text, text, text, text, text, integer, integer
) to authenticated, service_role;

revoke all on function public.admin_iptv_pool_host_portals(
  text, text, text, text, text, text
) from public;
grant execute on function public.admin_iptv_pool_host_portals(
  text, text, text, text, text, text
) to authenticated, service_role;
