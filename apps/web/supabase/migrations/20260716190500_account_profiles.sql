-- Account-owned profiles. Profile selection is intentionally device-local.

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 40),
  color text not null default '#1ce783',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, id)
);

create unique index profiles_user_name_unique
  on public.profiles (user_id, lower(trim(name)));

create index profiles_user_created_idx
  on public.profiles (user_id, created_at);

alter table public.profiles enable row level security;

create policy "profiles_own_all"
  on public.profiles
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update, delete on table public.profiles
  to authenticated, service_role;

create or replace function public.create_default_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, name)
  values (new.id, 'Profile 1')
  on conflict do nothing;
  return new;
end;
$$;

create trigger auth_user_create_default_profile
  after insert on auth.users
  for each row execute function public.create_default_profile();

create or replace function public.ensure_profile_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from auth.users where id = old.user_id)
     and not exists (
       select 1 from public.profiles where user_id = old.user_id
     ) then
    insert into public.profiles (user_id, name) values (old.user_id, 'Profile 1');
  end if;
  return old;
end;
$$;

create trigger profiles_keep_one
  after delete on public.profiles
  for each row execute function public.ensure_profile_after_delete();

-- Existing accounts receive a profile before settings become profile-scoped.
insert into public.profiles (user_id, name)
select id, 'Profile 1'
from auth.users
where not exists (
  select 1 from public.profiles where profiles.user_id = auth.users.id
);

alter table public.user_settings
  add column profile_id uuid;

update public.user_settings settings
set profile_id = (
  select profile.id
  from public.profiles profile
  where profile.user_id = settings.user_id
  order by profile.created_at, profile.id
  limit 1
);

alter table public.user_settings
  alter column profile_id set not null;

alter table public.user_settings
  drop constraint user_settings_pkey;

alter table public.user_settings
  add constraint user_settings_profile_owner_fkey
    foreign key (user_id, profile_id)
    references public.profiles (user_id, id)
    on delete cascade,
  add primary key (profile_id, domain);

create index user_settings_user_profile_idx
  on public.user_settings (user_id, profile_id);
