-- Admin decrypt / share / edit must work for any iptv_portals row, not only
-- catalog_pool inventory (account-assigned portals are often outside the pool).

create or replace function public.admin_iptv_catalog_candidate_password(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  pw text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select public._iptv_decrypt_password(p.password)
    into pw
  from public.iptv_portals p
  where p.id = p_id;

  if not found then
    raise exception 'portal not found';
  end if;

  return coalesce(pw, '');
end;
$$;

revoke all on function public.admin_iptv_catalog_candidate_password(uuid) from public;
grant execute on function public.admin_iptv_catalog_candidate_password(uuid)
  to authenticated, service_role;
