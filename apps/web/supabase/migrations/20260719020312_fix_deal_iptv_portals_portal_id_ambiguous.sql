-- Fix 42702: PL/pgSQL variable portal_id clashed with user_iptv_portals.portal_id
-- in INSERT / ON CONFLICT inside deal_iptv_portals.

create or replace function public.deal_iptv_portals(
  p_profile_id uuid,
  p_region text default 'ANY',
  p_count integer default 5
)
returns setof uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  n integer := greatest(1, least(coalesce(p_count, 5), 20));
  region text := upper(trim(coalesce(p_region, 'ANY')));
  bal integer;
  cand record;
  dealt_portal_id uuid;
  assigned integer := 0;
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_profile_id and account_id = actor
  ) then
    raise exception 'profile not found';
  end if;

  select iptv_credits into bal from public.accounts where id = actor for update;
  if bal is null or bal < 1 then
    raise exception 'insufficient credits';
  end if;

  update public.accounts
  set iptv_credits = iptv_credits - 1, updated_at = now()
  where id = actor;

  insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
  values (actor, -1, format('deal %s x%s', region, n), actor);

  for cand in
    select c.*
    from public.iptv_catalog_candidates c
    where c.alive is true
      and (region = 'ANY' or c.region_primary = region or region = any (c.region_tags))
      and not exists (
        select 1
        from public.iptv_portals p
        join public.user_iptv_portals u on u.portal_id = p.id
        where u.profile_id = p_profile_id
          and lower(trim(p.url)) = lower(trim(c.url))
          and lower(trim(p.username)) = lower(trim(c.username))
      )
    order by c.last_checked_at desc nulls last, c.created_at desc
    limit n
  loop
    dealt_portal_id := public.upsert_iptv_portal(
      cand.url,
      cand.username,
      public._iptv_decrypt_password(cand.password),
      coalesce(cand.source, 'catalog'),
      cand.expiry,
      cand.max_connections
    );

    insert into public.user_iptv_portals (
      account_id, profile_id, portal_id, portal_name, favorite,
      created_by, updated_by
    )
    values (actor, p_profile_id, dealt_portal_id, '', false, actor, actor)
    on conflict (profile_id, portal_id) do nothing;

    update public.iptv_catalog_candidates
    set dealt_count = dealt_count + 1, updated_at = now()
    where id = cand.id;

    assigned := assigned + 1;
    return next dealt_portal_id;
  end loop;

  if assigned = 0 then
    -- refund credit when pool empty
    update public.accounts
    set iptv_credits = iptv_credits + 1, updated_at = now()
    where id = actor;
    insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
    values (actor, 1, 'deal refund — empty pool', actor);
    raise exception 'no portals available for region %', region;
  end if;
end;
$$;

grant execute on function public.deal_iptv_portals(uuid, text, integer)
  to authenticated, service_role;
