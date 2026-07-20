-- Run on EXISTING DB if migration 20260719235404 is not applied via CLI.
-- Idempotent. Fixes PostgREST 42804 on get_iptv_portals after catalog-pool columns.

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
