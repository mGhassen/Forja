-- Remote still has the first push of 20260726130731 (column-based helpers).
-- Backfill 20260726135428 dropped accounts.max_iptv_portals, so
-- replace_user_iptv_portals / enforce trigger fail with 42703.
-- Re-install helpers to read accounts.features.maxIptvPortals (and is_admin).
-- DROP first: CREATE OR REPLACE cannot change return type (42P13) when
-- remote still has the column-era admin_set_max_iptv_portals (integer).

drop function if exists public.iptv_portal_max_for_account(uuid);
drop function if exists public.admin_set_max_iptv_portals(uuid, integer);

create function public.iptv_portal_max_for_account(p_account_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  is_adm boolean;
  feats jsonb;
  raw text;
  cap integer;
begin
  select is_admin, features
    into is_adm, feats
  from public.accounts
  where id = p_account_id;

  if not found then
    return 5;
  end if;
  if coalesce(is_adm, false) then
    return null;
  end if;

  raw := coalesce(feats, '{}'::jsonb)->>'maxIptvPortals';
  if raw is null or raw = '' then
    return 5;
  end if;

  begin
    cap := raw::integer;
  exception when others then
    return 5;
  end;

  return greatest(1, least(cap, 500));
end;
$$;

revoke all on function public.iptv_portal_max_for_account(uuid) from public;
grant execute on function public.iptv_portal_max_for_account(uuid)
  to authenticated, service_role;

create function public.admin_set_max_iptv_portals(
  p_account_id uuid,
  p_max integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  feats jsonb;
  next_max integer := greatest(1, least(coalesce(p_max, 5), 500));
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select features into feats from public.accounts where id = p_account_id;
  if feats is null and not exists (
    select 1 from public.accounts where id = p_account_id
  ) then
    raise exception 'account not found';
  end if;

  feats := coalesce(feats, '{}'::jsonb);
  if next_max = 5 then
    feats := feats - 'maxIptvPortals';
  else
    feats := feats || jsonb_build_object('maxIptvPortals', next_max);
  end if;

  update public.accounts
  set features = feats, updated_at = now()
  where id = p_account_id;

  return feats;
end;
$$;

revoke all on function public.admin_set_max_iptv_portals(uuid, integer) from public;
grant execute on function public.admin_set_max_iptv_portals(uuid, integer)
  to authenticated, service_role;
