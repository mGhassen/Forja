-- RFC-036 correction: display names are per-profile on user_iptv_portals.portal_name only.
-- Drop iptv_portals.provider_name (never a user label; not needed on the global row).

alter table public.iptv_portals
  drop column if exists provider_name;

drop function if exists public.upsert_iptv_portal(
  text, text, text, text, text, text, text
);

create or replace function public.upsert_iptv_portal(
  p_url text,
  p_username text,
  p_password text,
  p_source text default null,
  p_expiry text default null,
  p_max_connections text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  portal_id uuid;
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  insert into public.iptv_portals (
    url, username, password, source, expiry, max_connections,
    created_by, updated_by
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    p_source,
    p_expiry,
    p_max_connections,
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

grant execute on function public.upsert_iptv_portal(text, text, text, text, text, text)
  to authenticated, service_role;
