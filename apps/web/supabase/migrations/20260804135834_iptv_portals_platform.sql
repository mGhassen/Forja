-- RFC-051: product portals carry platform (xtream | m3u | stalker).
-- Do not touch scrape provenance / upsert_iptv_catalog_candidate here.

alter table public.iptv_portals
  add column if not exists platform text not null default 'xtream';

alter table public.iptv_portals
  drop constraint if exists iptv_portals_platform_check;

alter table public.iptv_portals
  add constraint iptv_portals_platform_check
  check (platform in ('xtream', 'm3u', 'stalker'));

comment on column public.iptv_portals.platform is
  'Portal protocol: xtream | m3u | stalker';

-- upsert_iptv_portal: add p_platform (default xtream).
drop function if exists public.upsert_iptv_portal(
  text, text, text, text, text, text
);

create or replace function public.upsert_iptv_portal(
  p_url text,
  p_username text,
  p_password text,
  p_source text default null,
  p_expiry text default null,
  p_max_connections text default null,
  p_platform text default 'xtream'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  portal_id uuid;
  actor uuid := auth.uid();
  plat text := lower(trim(coalesce(nullif(trim(p_platform), ''), 'xtream')));
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  if plat not in ('xtream', 'm3u', 'stalker') then
    raise exception 'invalid platform: %', plat;
  end if;

  insert into public.iptv_portals (
    url, username, password, source, expiry, max_connections, platform,
    created_by, updated_by
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    p_source,
    p_expiry,
    p_max_connections,
    plat,
    actor,
    actor
  )
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_portals.source),
    expiry = coalesce(excluded.expiry, public.iptv_portals.expiry),
    max_connections = coalesce(
      excluded.max_connections,
      public.iptv_portals.max_connections
    ),
    platform = excluded.platform,
    updated_by = actor,
    updated_at = now()
  returning id into portal_id;

  if portal_id is null then
    select id into portal_id
    from public.iptv_portals
    where lower(trim(url)) = lower(trim(p_url))
      and lower(trim(username)) = lower(trim(p_username));
  end if;

  return portal_id;
end;
$$;

grant execute on function public.upsert_iptv_portal(
  text, text, text, text, text, text, text
) to authenticated, service_role;

-- get_iptv_portals: include platform.
drop function if exists public.get_iptv_portals(uuid[]);

create function public.get_iptv_portals(p_ids uuid[])
returns table (
  id uuid,
  url text,
  username text,
  password text,
  source text,
  expiry text,
  max_connections text,
  platform text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by uuid,
  updated_by uuid
)
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if public.is_admin() then
    return query
      select
        p.id,
        p.url,
        p.username,
        public._iptv_decrypt_password(p.password),
        p.source,
        p.expiry,
        p.max_connections,
        p.platform,
        p.created_at,
        p.updated_at,
        p.created_by,
        p.updated_by
      from public.iptv_portals p
      where p.id = any (p_ids);
    return;
  end if;

  return query
    select
      p.id,
      p.url,
      p.username,
      public._iptv_decrypt_password(p.password),
      p.source,
      p.expiry,
      p.max_connections,
      p.platform,
      p.created_at,
      p.updated_at,
      p.created_by,
      p.updated_by
    from public.iptv_portals p
    where p.id = any (p_ids)
      and exists (
        select 1
        from public.user_iptv_portals u
        where u.account_id = auth.uid()
          and u.portal_id = p.id
      );
end;
$$;

grant execute on function public.get_iptv_portals(uuid[])
  to authenticated, service_role;
