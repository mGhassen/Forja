-- Paginated portals-per-host for Pool expand (lazy load).
-- Drop old overload so PostgREST is not ambiguous.

drop function if exists public.admin_iptv_pool_host_portals(
  text, text, text, text, text, text
);

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

  -- Stable order: created_at (not updated_at). jsonb_agg must ORDER BY or
  -- edits reshuffle rows (heap order looks like "last modified").
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

revoke all on function public.admin_iptv_pool_host_portals(
  text, text, text, text, text, text, integer, integer
) from public;
grant execute on function public.admin_iptv_pool_host_portals(
  text, text, text, text, text, text, integer, integer
) to authenticated, service_role;
