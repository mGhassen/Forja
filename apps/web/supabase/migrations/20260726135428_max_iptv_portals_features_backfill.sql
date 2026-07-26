-- Fix: drop mistaken accounts.max_iptv_portals column (if present) and
-- migrate over-limit inventories into accounts.features.maxIptvPortals.
-- Merges into features JSON — never clears iptvScrape / dealPortal / other keys.

-- ---------------------------------------------------------------------------
-- 1) If the bad column exists, copy its raised values into features first
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'accounts'
      and column_name = 'max_iptv_portals'
  ) then
    update public.accounts a
    set
      features = case
        when a.max_iptv_portals is null or a.max_iptv_portals <= 5 then
          coalesce(a.features, '{}'::jsonb) - 'maxIptvPortals'
        else
          coalesce(a.features, '{}'::jsonb)
            || jsonb_build_object(
              'maxIptvPortals',
              least(greatest(a.max_iptv_portals, 1), 500)
            )
      end,
      updated_at = now()
    where coalesce(a.is_admin, false) is not true
      and a.max_iptv_portals is not null
      and a.max_iptv_portals > 5
      and (
        coalesce(a.features, '{}'::jsonb)->>'maxIptvPortals' is null
        or (coalesce(a.features, '{}'::jsonb)->>'maxIptvPortals')::int
             < a.max_iptv_portals
      );

    alter table public.accounts drop column max_iptv_portals;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Backfill from live inventory: peak portals per profile → features
-- ---------------------------------------------------------------------------
-- Accounts already over the default 5 get features.maxIptvPortals = peak.
-- Does not lower an existing higher features.maxIptvPortals.
-- Admins skipped (unlimited via is_admin).
-- Other feature keys preserved.

with per_account as (
  select
    account_id,
    max(cnt)::int as peak
  from (
    select
      account_id,
      profile_id,
      count(*)::int as cnt
    from public.user_iptv_portals
    group by account_id, profile_id
  ) x
  group by account_id
  having max(cnt) > 5
)
update public.accounts a
set
  features = coalesce(a.features, '{}'::jsonb)
    || jsonb_build_object(
      'maxIptvPortals',
      least(
        500,
        greatest(
          p.peak,
          case
            when coalesce(a.features, '{}'::jsonb)->>'maxIptvPortals'
                 ~ '^[0-9]+$'
            then (coalesce(a.features, '{}'::jsonb)->>'maxIptvPortals')::int
            else 0
          end
        )
      )
    ),
  updated_at = now()
from per_account p
where a.id = p.account_id
  and coalesce(a.is_admin, false) is not true;
