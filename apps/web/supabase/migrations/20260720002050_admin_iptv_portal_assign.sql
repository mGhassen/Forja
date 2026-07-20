-- Admin assign / unassign portals onto a profile (ops; optional credit burn).

create or replace function public.admin_assign_iptv_portal(
  p_profile_id uuid,
  p_portal_id uuid,
  p_burn_credit boolean default false,
  p_bump_dealt boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  acct uuid;
  bal integer;
  assignment_id uuid;
  inserted integer;
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select account_id into acct
  from public.profiles
  where id = p_profile_id;
  if acct is null then
    raise exception 'profile not found';
  end if;

  if not exists (select 1 from public.iptv_portals where id = p_portal_id) then
    raise exception 'portal not found';
  end if;

  if exists (
    select 1
    from public.user_iptv_portals
    where profile_id = p_profile_id
      and portal_id = p_portal_id
  ) then
    raise exception 'portal already assigned to this profile';
  end if;

  if p_burn_credit then
    select iptv_credits into bal from public.accounts where id = acct for update;
    if bal is null or bal < 1 then
      raise exception 'insufficient credits';
    end if;
    update public.accounts
    set iptv_credits = iptv_credits - 1, updated_at = now()
    where id = acct;
    insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
    values (acct, -1, 'admin assign portal', actor);
  end if;

  insert into public.user_iptv_portals (
    account_id, profile_id, portal_id, portal_name, favorite,
    created_by, updated_by
  )
  values (acct, p_profile_id, p_portal_id, '', false, actor, actor)
  on conflict (profile_id, portal_id) do nothing
  returning id into assignment_id;
  get diagnostics inserted = row_count;

  if inserted = 0 or assignment_id is null then
    if p_burn_credit then
      update public.accounts
      set iptv_credits = iptv_credits + 1, updated_at = now()
      where id = acct;
      insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
      values (acct, 1, 'admin assign refund — conflict', actor);
    end if;
    raise exception 'portal already assigned to this profile';
  end if;

  if p_bump_dealt then
    update public.iptv_portals
    set dealt_count = dealt_count + 1, updated_at = now()
    where id = p_portal_id;
  end if;

  return assignment_id;
end;
$$;

revoke all on function public.admin_assign_iptv_portal(uuid, uuid, boolean, boolean)
  from public;
grant execute on function public.admin_assign_iptv_portal(uuid, uuid, boolean, boolean)
  to authenticated, service_role;

create or replace function public.admin_unassign_iptv_portal(
  p_assignment_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  deleted integer;
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  delete from public.user_iptv_portals
  where id = p_assignment_id;
  get diagnostics deleted = row_count;

  if deleted = 0 then
    raise exception 'assignment not found';
  end if;
end;
$$;

revoke all on function public.admin_unassign_iptv_portal(uuid) from public;
grant execute on function public.admin_unassign_iptv_portal(uuid)
  to authenticated, service_role;
