-- Forward-only apply for hosted DB (same body as migration 20260720021024).
-- Do not edit the migration file; re-run this script if needed.

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
