-- Hot-apply: same body as migrations/20260912103200_deal_iptv_portals_simple_lotto.sql
-- Run in Studio SQL when you cannot migrate yet.

-- Deal lotto: whole catalog pool, weight by host, no alive/region filter.
-- Pass 1 = one portal per host; pass 2 fills if thin.

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
  bal integer;
  feats jsonb;
  slots integer;
  host_list text[];
  host_len integer;
  pass integer;
  i integer;
  dealt_host text;
  dealt_portal_id uuid;
  inserted integer;
  assigned integer := 0;
  assigned_ids uuid[] := '{}';
begin
  -- p_region: kept for RPC compat; not used.
  if actor is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_profile_id and account_id = actor
  ) then
    raise exception 'profile not found';
  end if;

  select features, iptv_credits into feats, bal
  from public.accounts
  where id = actor
  for update;

  if feats is null then
    raise exception 'account not found';
  end if;

  if coalesce(feats, '{}'::jsonb)->>'dealPortal' is distinct from 'true' then
    raise exception 'deal portal not enabled';
  end if;

  slots := public.iptv_portal_slots_left(actor, p_profile_id);
  if slots is not null then
    if slots < 1 then
      raise exception 'Maximum of % IPTV portals per profile',
        public.iptv_portal_max_for_account(actor)
        using errcode = 'P0001';
    end if;
    n := least(n, slots);
  end if;

  if bal is null or bal < 1 then
    raise exception 'insufficient credits';
  end if;

  update public.accounts
  set iptv_credits = iptv_credits - 1, updated_at = now()
  where id = actor;

  insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
  values (actor, -1, format('deal x%s', n), actor);

  -- Lotto hosts that still have ≥1 unassigned pool portal for this profile.
  -- Weight = inverse sum(dealt_count) for that host across the catalog pool.
  select array_agg(x.host order by x.lotto)
  into host_list
  from (
    select
      h.host,
      (
        -ln(greatest(random(), 1e-15))
        / (1.0 / (1.0 + h.host_dealt))
      ) as lotto
    from (
      select
        coalesce(
          nullif(trim(p.url_host), ''),
          public.iptv_portal_url_host(p.url),
          p.id::text
        ) as host,
        sum(coalesce(p.dealt_count, 0))::double precision as host_dealt
      from public.iptv_portals p
      where p.catalog_pool is true
      group by 1
    ) h
    where exists (
      select 1
      from public.iptv_portals e
      where e.catalog_pool is true
        and coalesce(
          nullif(trim(e.url_host), ''),
          public.iptv_portal_url_host(e.url),
          e.id::text
        ) = h.host
        and not exists (
          select 1
          from public.user_iptv_portals u
          where u.profile_id = p_profile_id
            and u.portal_id = e.id
        )
    )
  ) x;

  host_len := coalesce(array_length(host_list, 1), 0);

  for pass in 1..2 loop
    exit when assigned >= n;
    for i in 1..host_len loop
      exit when assigned >= n;
      dealt_host := host_list[i];
      dealt_portal_id := null;

      select e.id
      into dealt_portal_id
      from public.iptv_portals e
      where e.catalog_pool is true
        and coalesce(
          nullif(trim(e.url_host), ''),
          public.iptv_portal_url_host(e.url),
          e.id::text
        ) = dealt_host
        and not (e.id = any (assigned_ids))
        and not exists (
          select 1
          from public.user_iptv_portals u
          where u.profile_id = p_profile_id
            and u.portal_id = e.id
        )
      order by random()
      limit 1;

      if dealt_portal_id is null then
        continue;
      end if;

      insert into public.user_iptv_portals (
        account_id, profile_id, portal_id, portal_name, favorite,
        created_by, updated_by
      )
      values (actor, p_profile_id, dealt_portal_id, '', false, actor, actor)
      on conflict (profile_id, portal_id) do nothing;
      get diagnostics inserted = row_count;

      assigned_ids := array_append(assigned_ids, dealt_portal_id);

      if inserted = 0 then
        continue;
      end if;

      update public.iptv_portals
      set dealt_count = dealt_count + 1, updated_at = now()
      where id = dealt_portal_id;

      assigned := assigned + 1;
      return next dealt_portal_id;
    end loop;
  end loop;

  if assigned = 0 then
    update public.accounts
    set iptv_credits = iptv_credits + 1, updated_at = now()
    where id = actor;
    insert into public.iptv_credit_ledger (account_id, delta, reason, created_by)
    values (actor, 1, 'deal refund — empty pool', actor);
    raise exception 'no portals available';
  end if;
end;
$$;

grant execute on function public.deal_iptv_portals(uuid, text, integer)
  to authenticated, service_role;
