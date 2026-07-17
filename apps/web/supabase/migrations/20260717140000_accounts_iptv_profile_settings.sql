-- RFC-036: accounts hub, global iptv_portals, single profile_settings payload.
-- Drops releases / release_assets / announcements / user_settings.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- accounts
-- ---------------------------------------------------------------------------

create table public.accounts (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid
);

alter table public.accounts
  add constraint accounts_created_by_fkey
    foreign key (created_by) references public.accounts (id) on delete set null,
  add constraint accounts_updated_by_fkey
    foreign key (updated_by) references public.accounts (id) on delete set null;

create index accounts_email_idx on public.accounts (lower(email));
create index accounts_is_admin_idx on public.accounts (is_admin) where is_admin;

insert into public.accounts (id, email, created_at, updated_at)
select
  u.id,
  u.email,
  coalesce(u.created_at, now()),
  now()
from auth.users u
on conflict (id) do nothing;

create trigger accounts_set_updated_at
  before update on public.accounts
  for each row execute function public.set_updated_at();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.accounts
    where id = auth.uid()
      and is_admin = true
  );
$$;

alter table public.accounts enable row level security;

create policy accounts_select_own_or_admin
  on public.accounts for select
  using (id = auth.uid() or public.is_admin());

create policy accounts_update_own_or_admin
  on public.accounts for update
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

grant select, update on table public.accounts to authenticated, service_role;
grant all on table public.accounts to service_role;

-- ---------------------------------------------------------------------------
-- profiles: user_id → account_id + audit
-- ---------------------------------------------------------------------------

-- Detach settings FK that references (user_id, id)
alter table public.user_settings
  drop constraint if exists user_settings_profile_owner_fkey;

alter table public.profiles
  add column if not exists account_id uuid,
  add column if not exists created_by uuid,
  add column if not exists updated_by uuid;

update public.profiles
set account_id = user_id
where account_id is null;

alter table public.profiles
  alter column account_id set not null;

alter table public.profiles
  drop constraint if exists profiles_user_id_fkey;

alter table public.profiles
  drop constraint if exists profiles_user_id_id_key;

drop index if exists profiles_user_name_unique;
drop index if exists profiles_user_created_idx;

drop policy if exists profiles_own_all on public.profiles;

alter table public.profiles drop column if exists user_id;

alter table public.profiles
  add constraint profiles_account_id_fkey
    foreign key (account_id) references public.accounts (id) on delete cascade;

alter table public.profiles
  add constraint profiles_account_id_id_key unique (account_id, id);

alter table public.profiles
  add constraint profiles_created_by_fkey
    foreign key (created_by) references public.accounts (id) on delete set null,
  add constraint profiles_updated_by_fkey
    foreign key (updated_by) references public.accounts (id) on delete set null;

create unique index profiles_account_name_unique
  on public.profiles (account_id, lower(trim(name)));

create index profiles_account_created_idx
  on public.profiles (account_id, created_at);

create policy profiles_own_or_admin
  on public.profiles for all
  using (account_id = auth.uid() or public.is_admin())
  with check (account_id = auth.uid() or public.is_admin());

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- iptv_portals
-- ---------------------------------------------------------------------------

create table public.iptv_portals (
  id uuid primary key default gen_random_uuid(),
  url text not null,
  username text not null,
  password text not null,
  source text,
  provider_name text,
  expiry text,
  max_connections text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.accounts (id) on delete set null,
  updated_by uuid references public.accounts (id) on delete set null
);

create unique index iptv_portals_url_username_unique
  on public.iptv_portals ((lower(trim(url))), (lower(trim(username))));

create trigger iptv_portals_set_updated_at
  before update on public.iptv_portals
  for each row execute function public.set_updated_at();

alter table public.iptv_portals enable row level security;

create policy iptv_portals_admin_all
  on public.iptv_portals for all
  using (public.is_admin())
  with check (public.is_admin());

grant select, insert, update, delete on table public.iptv_portals
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- profile_settings
-- ---------------------------------------------------------------------------

create table public.profile_settings (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  account_id uuid not null references public.accounts (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.accounts (id) on delete set null,
  updated_by uuid references public.accounts (id) on delete set null,
  constraint profile_settings_account_profile_fkey
    foreign key (account_id, profile_id)
    references public.profiles (account_id, id)
    on delete cascade
);

create index profile_settings_account_idx
  on public.profile_settings (account_id);

create trigger profile_settings_set_updated_at
  before update on public.profile_settings
  for each row execute function public.set_updated_at();

alter table public.profile_settings enable row level security;

create policy profile_settings_own_or_admin
  on public.profile_settings for all
  using (account_id = auth.uid() or public.is_admin())
  with check (account_id = auth.uid() or public.is_admin());

grant select, insert, update, delete on table public.profile_settings
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Signup / keep-one triggers
-- ---------------------------------------------------------------------------

create or replace function public.create_default_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_profile_id uuid;
begin
  insert into public.accounts (id, email, created_at, updated_at)
  values (new.id, new.email, now(), now())
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();

  select id into new_profile_id
  from public.profiles
  where account_id = new.id
  order by created_at, id
  limit 1;

  if new_profile_id is null then
    insert into public.profiles (account_id, name)
    values (new.id, 'Profile 1')
    returning id into new_profile_id;
  end if;

  insert into public.profile_settings (profile_id, account_id, payload)
  values (new_profile_id, new.id, '{}'::jsonb)
  on conflict (profile_id) do nothing;

  return new;
end;
$$;

create or replace function public.ensure_profile_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_profile_id uuid;
begin
  if exists (select 1 from public.accounts where id = old.account_id)
     and not exists (
       select 1 from public.profiles where account_id = old.account_id
     ) then
    insert into public.profiles (account_id, name)
    values (old.account_id, 'Profile 1')
    returning id into new_profile_id;

    insert into public.profile_settings (profile_id, account_id, payload)
    values (new_profile_id, old.account_id, '{}'::jsonb)
    on conflict (profile_id) do nothing;
  end if;
  return old;
end;
$$;

-- ---------------------------------------------------------------------------
-- Migrate user_settings → profile_settings (+ extract iptv portals)
-- ---------------------------------------------------------------------------

create or replace function public._migrate_upsert_iptv_portal(
  p_url text,
  p_username text,
  p_password text,
  p_source text,
  p_provider_name text,
  p_expiry text,
  p_max_connections text,
  p_actor uuid
)
returns uuid
language plpgsql
as $$
declare
  portal_id uuid;
begin
  insert into public.iptv_portals (
    url, username, password, source, provider_name, expiry, max_connections,
    created_by, updated_by
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    p_source,
    p_provider_name,
    p_expiry,
    p_max_connections,
    p_actor,
    p_actor
  )
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_portals.source),
    provider_name = coalesce(excluded.provider_name, public.iptv_portals.provider_name),
    expiry = coalesce(excluded.expiry, public.iptv_portals.expiry),
    max_connections = coalesce(excluded.max_connections, public.iptv_portals.max_connections),
    updated_by = excluded.updated_by,
    updated_at = now()
  returning id into portal_id;

  if portal_id is null then
    select id into portal_id
    from public.iptv_portals
    where lower(trim(url)) = lower(trim(p_url))
      and lower(trim(username)) = lower(trim(p_username));
  end if;

  return portal_id;
end;
$$;

do $$
declare
  settings_row record;
  portal jsonb;
  portals jsonb;
  portal_id uuid;
  portal_url text;
  portal_user text;
  portal_pass text;
  portal_label text;
  merged jsonb;
  iptv_domain jsonb;
  prefs jsonb;
  providers jsonb;
  stremio jsonb;
  fav_keys jsonb;
  m3u jsonb;
  assignments jsonb;
  fav_key text;
  is_fav boolean;
  portal_key text;
begin
  for settings_row in
    select distinct us.profile_id, p.account_id
    from public.user_settings us
    join public.profiles p on p.id = us.profile_id
  loop
    select payload into prefs
    from public.user_settings
    where profile_id = settings_row.profile_id and domain = 'preferences'
    limit 1;

    select payload into providers
    from public.user_settings
    where profile_id = settings_row.profile_id and domain = 'providers'
    limit 1;

    select payload into stremio
    from public.user_settings
    where profile_id = settings_row.profile_id and domain = 'stremio'
    limit 1;

    select payload into iptv_domain
    from public.user_settings
    where profile_id = settings_row.profile_id and domain = 'iptv'
    limit 1;

    assignments := '[]'::jsonb;
    fav_keys := coalesce(iptv_domain -> 'favoriteKeys', '[]'::jsonb);
    -- Metadata-only M3U (no channels[]); drop file playlists without sourceUrl.
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', pl ->> 'id',
          'name', pl ->> 'name',
          'sourceUrl', pl ->> 'sourceUrl',
          'addedAt', pl -> 'addedAt',
          'updatedAt', pl -> 'updatedAt'
        )
      ),
      '[]'::jsonb
    )
    into m3u
    from jsonb_array_elements(coalesce(iptv_domain -> 'm3uPlaylists', '[]'::jsonb)) pl
    where nullif(trim(pl ->> 'sourceUrl'), '') is not null;
    portals := coalesce(iptv_domain -> 'portals', '[]'::jsonb);

    for portal in select * from jsonb_array_elements(portals)
    loop
      portal_url := nullif(trim(portal ->> 'url'), '');
      portal_user := nullif(trim(portal ->> 'username'), '');
      portal_pass := coalesce(portal ->> 'password', '');
      if portal_url is null or portal_user is null then
        continue;
      end if;

      portal_label := coalesce(
        nullif(trim(portal ->> 'label'), ''),
        nullif(trim(portal ->> 'name'), ''),
        portal_user
      );

      portal_id := public._migrate_upsert_iptv_portal(
        portal_url,
        portal_user,
        portal_pass,
        portal ->> 'source',
        nullif(trim(portal ->> 'name'), ''),
        portal ->> 'expiry',
        portal ->> 'max',
        settings_row.account_id
      );

      portal_key := lower(portal_url || '|' || portal_user || '|' || portal_pass);
      is_fav := false;
      if jsonb_typeof(fav_keys) = 'array' then
        for fav_key in select jsonb_array_elements_text(fav_keys)
        loop
          if lower(fav_key) = portal_key
             or lower(fav_key) like lower(portal_url || '|' || portal_user || '|%') then
            is_fav := true;
            exit;
          end if;
        end loop;
      end if;

      assignments := assignments || jsonb_build_array(
        case
          when is_fav then
            jsonb_build_object(
              'portalId', portal_id,
              'label', portal_label,
              'favorite', true
            )
          else
            jsonb_build_object(
              'portalId', portal_id,
              'label', portal_label
            )
        end
      );
    end loop;

    merged := jsonb_strip_nulls(jsonb_build_object(
      'playback', nullif(coalesce(prefs, '{}'::jsonb), '{}'::jsonb),
      'connectedServices', nullif(
        jsonb_strip_nulls(jsonb_build_object(
          'providers', providers,
          'stremio', stremio
        )),
        '{}'::jsonb
      ),
      'navigation', null,
      'iptv', jsonb_build_object(
        'portals', assignments,
        'm3uPlaylists', m3u
      )
    ));

    insert into public.profile_settings (profile_id, account_id, payload, created_by, updated_by)
    values (
      settings_row.profile_id,
      settings_row.account_id,
      merged,
      settings_row.account_id,
      settings_row.account_id
    )
    on conflict (profile_id) do update
      set payload = excluded.payload,
          updated_at = now(),
          updated_by = excluded.updated_by;
  end loop;

  insert into public.profile_settings (profile_id, account_id, payload)
  select p.id, p.account_id, '{}'::jsonb
  from public.profiles p
  where not exists (
    select 1 from public.profile_settings s where s.profile_id = p.id
  );
end $$;

drop function if exists public._migrate_upsert_iptv_portal(
  text, text, text, text, text, text, text, uuid
);

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

create or replace function public.upsert_iptv_portal(
  p_url text,
  p_username text,
  p_password text,
  p_source text default null,
  p_provider_name text default null,
  p_expiry text default null,
  p_max_connections text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  portal_id uuid;
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'not authenticated';
  end if;

  insert into public.iptv_portals (
    url, username, password, source, provider_name, expiry, max_connections,
    created_by, updated_by
  )
  values (
    trim(p_url),
    trim(p_username),
    coalesce(p_password, ''),
    p_source,
    p_provider_name,
    p_expiry,
    p_max_connections,
    actor,
    actor
  )
  on conflict ((lower(trim(url))), (lower(trim(username))))
  do update set
    password = excluded.password,
    source = coalesce(excluded.source, public.iptv_portals.source),
    provider_name = coalesce(excluded.provider_name, public.iptv_portals.provider_name),
    expiry = coalesce(excluded.expiry, public.iptv_portals.expiry),
    max_connections = coalesce(excluded.max_connections, public.iptv_portals.max_connections),
    updated_by = actor,
    updated_at = now()
  returning id into portal_id;

  if portal_id is null then
    select id into portal_id
    from public.iptv_portals
    where lower(trim(url)) = lower(trim(p_url))
      and lower(trim(username)) = lower(trim(p_username));
  end if;

  return portal_id;
end;
$$;

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
        from public.profile_settings s
        where s.account_id = auth.uid()
          and exists (
            select 1
            from jsonb_array_elements(coalesce(s.payload -> 'iptv' -> 'portals', '[]'::jsonb)) elem
            where (elem ->> 'portalId')::uuid = p.id
          )
      );
end;
$$;

grant execute on function public.upsert_iptv_portal(text, text, text, text, text, text, text)
  to authenticated, service_role;
grant execute on function public.get_iptv_portals(uuid[])
  to authenticated, service_role;
grant execute on function public.is_admin()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Drop legacy tables
-- ---------------------------------------------------------------------------

drop table if exists public.release_assets cascade;
drop table if exists public.releases cascade;
drop table if exists public.announcements cascade;
drop table if exists public.user_settings cascade;
