-- Cap IPTV portals per profile via accounts.features.maxIptvPortals (default 5).
-- Lean JSON: omit key when default 5; store only when raised (1–500).
-- Admin accounts (is_admin) are unlimited. Boolean flags (iptvScrape, dealPortal) untouched.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Returns NULL when unlimited (is_admin), else configured max (default 5).
create or replace function public.iptv_portal_max_for_account(p_account_id uuid)
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

-- Slots remaining for a profile (NULL = unlimited).
create or replace function public.iptv_portal_slots_left(
  p_account_id uuid,
  p_profile_id uuid
)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cap integer;
  used integer;
begin
  cap := public.iptv_portal_max_for_account(p_account_id);
  if cap is null then
    return null;
  end if;
  select count(*)::int into used
  from public.user_iptv_portals
  where profile_id = p_profile_id;
  return greatest(0, cap - coalesce(used, 0));
end;
$$;

revoke all on function public.iptv_portal_slots_left(uuid, uuid) from public;
grant execute on function public.iptv_portal_slots_left(uuid, uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enforce on insert
-- ---------------------------------------------------------------------------

create or replace function public.enforce_max_iptv_portals_per_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cap integer;
  used integer;
begin
  -- Bulk replace RPC sets this so grandfathered inventories can rewrite.
  if current_setting('forja.iptv_portal_replace', true) = '1' then
    return new;
  end if;

  cap := public.iptv_portal_max_for_account(new.account_id);
  if cap is null then
    return new;
  end if;

  select count(*)::int into used
  from public.user_iptv_portals
  where profile_id = new.profile_id;

  if coalesce(used, 0) >= cap then
    raise exception 'Maximum of % IPTV portals per profile', cap
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists user_iptv_portals_enforce_max on public.user_iptv_portals;

create trigger user_iptv_portals_enforce_max
  before insert on public.user_iptv_portals
  for each row execute function public.enforce_max_iptv_portals_per_profile();

-- ---------------------------------------------------------------------------
-- Admin: set features.maxIptvPortals (lean — omit key when default 5)
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_max_iptv_portals(
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

-- ---------------------------------------------------------------------------
-- Deal: clamp pack size to remaining slots; fail before credit burn if full
-- ---------------------------------------------------------------------------

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
  feats jsonb;
  slots integer;
  cand_ids uuid[];
  cand_hosts text[];
  assigned_ids uuid[] := '{}';
  used_hosts text[] := '{}';
  assigned integer := 0;
  pass integer;
  i integer;
  cand_len integer;
  dealt_portal_id uuid;
  inserted integer;
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
  values (actor, -1, format('deal %s x%s', region, n), actor);

  select
    array_agg(c.id order by c.lotto),
    array_agg(c.host order by c.lotto)
  into cand_ids, cand_hosts
  from (
    select
      p.id,
      coalesce(
        nullif(
          lower(
            split_part(
              split_part(
                regexp_replace(
                  regexp_replace(trim(p.url), '^\s*https?://', '', 'i'),
                  '^[^/@]+@',
                  ''
                ),
                '/',
                1
              ),
              '?',
              1
            )
          ),
          ''
        ),
        p.id::text
      ) as host,
      (
        -ln(greatest(random(), 1e-15))
        / (
          (1.0 / (1.0 + coalesce(p.dealt_count, 0)::double precision))
          * case
              when p.last_checked_at is not null
                and p.last_checked_at >= now() - interval '7 days'
              then 1.5
              else 1.0
            end
        )
      ) as lotto
    from public.iptv_portals p
    where p.catalog_pool is true
      and p.alive is true
      and (region = 'ANY' or p.region_primary = region or region = any (p.region_tags))
      and not exists (
        select 1
        from public.user_iptv_portals u
        where u.profile_id = p_profile_id
          and u.portal_id = p.id
      )
  ) c;

  cand_len := coalesce(array_length(cand_ids, 1), 0);

  for pass in 1..2 loop
    exit when assigned >= n;
    for i in 1..cand_len loop
      exit when assigned >= n;
      if cand_ids[i] = any (assigned_ids) then
        continue;
      end if;
      if pass = 1 and cand_hosts[i] = any (used_hosts) then
        continue;
      end if;

      dealt_portal_id := cand_ids[i];

      insert into public.user_iptv_portals (
        account_id, profile_id, portal_id, portal_name, favorite,
        created_by, updated_by
      )
      values (actor, p_profile_id, dealt_portal_id, '', false, actor, actor)
      on conflict (profile_id, portal_id) do nothing;
      get diagnostics inserted = row_count;

      if inserted = 0 then
        assigned_ids := array_append(assigned_ids, dealt_portal_id);
        used_hosts := array_append(used_hosts, cand_hosts[i]);
        continue;
      end if;

      update public.iptv_portals
      set dealt_count = dealt_count + 1, updated_at = now()
      where id = dealt_portal_id;

      assigned_ids := array_append(assigned_ids, dealt_portal_id);
      used_hosts := array_append(used_hosts, cand_hosts[i]);
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
    raise exception 'no portals available for region %', region;
  end if;
end;
$$;

grant execute on function public.deal_iptv_portals(uuid, text, integer)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Admin assign: respect target account portal max (admins themselves unlimited)
-- ---------------------------------------------------------------------------

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
  slots integer;
  cap integer;
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

  slots := public.iptv_portal_slots_left(acct, p_profile_id);
  if slots is not null and slots < 1 then
    cap := public.iptv_portal_max_for_account(acct);
    raise exception 'Maximum of % IPTV portals per profile', coalesce(cap, 5)
      using errcode = 'P0001';
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

-- ---------------------------------------------------------------------------
-- Replace profile assignments (sync / web save) with grandfather over-limit
-- ---------------------------------------------------------------------------

create or replace function public.replace_user_iptv_portals(
  p_profile_id uuid,
  p_assignments jsonb
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

revoke all on function public.replace_user_iptv_portals(uuid, jsonb) from public;
grant execute on function public.replace_user_iptv_portals(uuid, jsonb)
  to authenticated, service_role;
