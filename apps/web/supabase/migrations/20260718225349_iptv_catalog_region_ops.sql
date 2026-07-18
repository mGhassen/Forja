-- RFC-040: extend candidate upsert with region tags + confidence.

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
  cid uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin or service role only';
  end if;

  insert into public.iptv_catalog_candidates (
    url, username, password, source, layer, alive, expiry,
    max_connections, timezone, region_primary, region_tags, region_confidence,
    post_id, last_checked_at
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
    coalesce(p_region_tags, '{}'::text[]),
    coalesce(p_region_confidence, 0),
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
    region_tags = case
      when excluded.region_tags is not null and cardinality(excluded.region_tags) > 0
        then excluded.region_tags
      else public.iptv_catalog_candidates.region_tags
    end,
    region_confidence = coalesce(
      nullif(excluded.region_confidence, 0),
      public.iptv_catalog_candidates.region_confidence
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

-- Drop old 11-arg overload if present so PostgREST resolves the new signature.
drop function if exists public.upsert_iptv_catalog_candidate(
  text, text, text, text, text, boolean, text, text, text, text, text
);

grant execute on function public.upsert_iptv_catalog_candidate(
  text, text, text, text, text, boolean, text, text, text, text, text, text[], real
) to authenticated, service_role;
