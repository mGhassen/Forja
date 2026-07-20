-- Forward-only apply for hosted DB (same body as migration 20260720114544).
-- Do not edit the migration file; re-run this script if needed.

create or replace function public.admin_set_deal_portal(
  p_account_id uuid,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  feats jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_admin() then
    raise exception 'admin only';
  end if;

  select features into feats from public.accounts where id = p_account_id;
  if feats is null then
    raise exception 'account not found';
  end if;

  if p_enabled then
    feats := coalesce(feats, '{}'::jsonb) || '{"dealPortal": true}'::jsonb;
  else
    feats := coalesce(feats, '{}'::jsonb) - 'dealPortal';
  end if;

  update public.accounts
  set features = feats, updated_at = now()
  where id = p_account_id;

  return feats;
end;
$$;

grant execute on function public.admin_set_deal_portal(uuid, boolean)
  to authenticated, service_role;

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
