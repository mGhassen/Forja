-- Issue 118 round 2: cloud is master for IPTV assignments.
-- Client guards can race / fail-open (count=0 when profile not ready) and
-- still call replace_user_iptv_portals with a thin local list. Refuse shrink
-- on the server unless the caller explicitly opts in (intentional delete /
-- clear-all).

drop function if exists public.replace_user_iptv_portals(uuid, jsonb);

create or replace function public.replace_user_iptv_portals(
  p_profile_id uuid,
  p_assignments jsonb,
  p_allow_shrink boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  acct uuid;
  cap integer;
  prev_count integer;
  next_count integer;
  allowed integer;
  elem jsonb;
  pid uuid;
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  select account_id into acct
  from public.profiles
  where id = p_profile_id and account_id = actor;
  if acct is null then
    raise exception 'profile not found';
  end if;

  if p_assignments is null or jsonb_typeof(p_assignments) is distinct from 'array' then
    raise exception 'assignments must be a json array';
  end if;

  select count(*)::int into prev_count
  from public.user_iptv_portals
  where profile_id = p_profile_id;

  next_count := coalesce(jsonb_array_length(p_assignments), 0);

  -- Cloud master: thin / partial local inventory must never delete assignments.
  if not coalesce(p_allow_shrink, false) and next_count < coalesce(prev_count, 0) then
    raise exception
      'refusing IPTV assignment shrink (% → %) — cloud is master',
      prev_count, next_count
      using errcode = 'P0001';
  end if;

  cap := public.iptv_portal_max_for_account(acct);
  if cap is not null then
    allowed := greatest(cap, coalesce(prev_count, 0));
    if next_count > allowed then
      raise exception 'Maximum of % IPTV portals per profile', cap
        using errcode = 'P0001';
    end if;
  end if;

  perform set_config('forja.iptv_portal_replace', '1', true);

  delete from public.user_iptv_portals
  where profile_id = p_profile_id
    and account_id = acct;

  for elem in
    select value from jsonb_array_elements(p_assignments)
  loop
    begin
      pid := (elem->>'portal_id')::uuid;
    exception when others then
      raise exception 'invalid portal_id in assignments';
    end;
    if pid is null then
      continue;
    end if;

    insert into public.user_iptv_portals (
      account_id, profile_id, portal_id, portal_name, favorite,
      created_by, updated_by
    )
    values (
      acct,
      p_profile_id,
      pid,
      coalesce(elem->>'portal_name', ''),
      coalesce((elem->>'favorite')::boolean, false),
      actor,
      actor
    )
    on conflict (profile_id, portal_id) do nothing;
  end loop;
end;
$$;

revoke all on function public.replace_user_iptv_portals(uuid, jsonb, boolean)
  from public;
grant execute on function public.replace_user_iptv_portals(uuid, jsonb, boolean)
  to authenticated, service_role;
