-- RFC-036 correction: per-profile IPTV assignments live in user_iptv_portals.
-- portal_name = user label. iptv_portals.provider_name = Xtream account name (global).
-- Strip iptv.portals from profile_settings.payload (M3U only remains under iptv).

-- ---------------------------------------------------------------------------
-- user_iptv_portals
-- ---------------------------------------------------------------------------

create table public.user_iptv_portals (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  portal_id uuid not null references public.iptv_portals (id) on delete cascade,
  portal_name text not null default '',
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.accounts (id) on delete set null,
  updated_by uuid references public.accounts (id) on delete set null,
  constraint user_iptv_portals_account_profile_fkey
    foreign key (account_id, profile_id)
    references public.profiles (account_id, id)
    on delete cascade,
  constraint user_iptv_portals_profile_portal_unique
    unique (profile_id, portal_id)
);

create index user_iptv_portals_account_idx
  on public.user_iptv_portals (account_id);

create index user_iptv_portals_portal_idx
  on public.user_iptv_portals (portal_id);

create trigger user_iptv_portals_set_updated_at
  before update on public.user_iptv_portals
  for each row execute function public.set_updated_at();

alter table public.user_iptv_portals enable row level security;

create policy user_iptv_portals_own_or_admin
  on public.user_iptv_portals for all
  using (account_id = auth.uid() or public.is_admin())
  with check (account_id = auth.uid() or public.is_admin());

grant select, insert, update, delete on table public.user_iptv_portals
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Migrate assignments out of profile_settings.payload.iptv.portals
-- ---------------------------------------------------------------------------

do $$
declare
  settings_row record;
  assignment jsonb;
  portal_uuid uuid;
  pname text;
  is_fav boolean;
begin
  for settings_row in
    select profile_id, account_id, payload
    from public.profile_settings
    where jsonb_typeof(payload -> 'iptv' -> 'portals') = 'array'
      and jsonb_array_length(payload -> 'iptv' -> 'portals') > 0
  loop
    for assignment in
      select * from jsonb_array_elements(settings_row.payload -> 'iptv' -> 'portals')
    loop
      begin
        portal_uuid := (assignment ->> 'portalId')::uuid;
      exception
        when others then
          continue;
      end;

      if not exists (
        select 1 from public.iptv_portals where id = portal_uuid
      ) then
        continue;
      end if;

      pname := coalesce(
        nullif(trim(assignment ->> 'portal_name'), ''),
        nullif(trim(assignment ->> 'label'), ''),
        ''
      );
      is_fav := coalesce((assignment ->> 'favorite')::boolean, false);

      insert into public.user_iptv_portals (
        account_id, profile_id, portal_id, portal_name, favorite,
        created_by, updated_by
      )
      values (
        settings_row.account_id,
        settings_row.profile_id,
        portal_uuid,
        pname,
        is_fav,
        settings_row.account_id,
        settings_row.account_id
      )
      on conflict (profile_id, portal_id) do update set
        portal_name = excluded.portal_name,
        favorite = excluded.favorite,
        updated_by = excluded.updated_by,
        updated_at = now();
    end loop;
  end loop;

  update public.profile_settings
  set payload = case
    when payload ? 'iptv' then
      jsonb_set(
        payload,
        '{iptv}',
        coalesce(payload -> 'iptv', '{}'::jsonb) - 'portals'
      )
    else payload
  end,
  updated_at = now()
  where payload -> 'iptv' ? 'portals';
end $$;

-- ---------------------------------------------------------------------------
-- get_iptv_portals: authorize via user_iptv_portals (not settings JSON)
-- ---------------------------------------------------------------------------

create or replace function public.get_iptv_portals(p_ids uuid[])
returns setof public.iptv_portals
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if public.is_admin() then
    return query
      select *
      from public.iptv_portals
      where id = any (p_ids);
    return;
  end if;

  return query
    select p.*
    from public.iptv_portals p
    where p.id = any (p_ids)
      and exists (
        select 1
        from public.user_iptv_portals u
        where u.account_id = auth.uid()
          and u.portal_id = p.id
      );
end;
$$;
