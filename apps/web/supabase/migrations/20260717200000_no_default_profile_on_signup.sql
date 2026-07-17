-- New accounts get an accounts row only — no auto "Profile 1".
-- Default profile_settings are created when the user creates a profile.

create or replace function public.create_default_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts (id, email, created_at, updated_at)
  values (new.id, new.email, now(), now())
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();

  return new;
end;
$$;

-- Drop keep-one: last-profile delete is blocked in clients; do not recreate "Profile 1".
drop trigger if exists profiles_keep_one on public.profiles;

drop function if exists public.ensure_profile_after_delete();

create or replace function public.create_default_profile_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profile_settings (profile_id, account_id, payload)
  values (new.id, new.account_id, '{}'::jsonb)
  on conflict (profile_id) do nothing;
  return new;
end;
$$;

drop trigger if exists profiles_create_default_settings on public.profiles;

create trigger profiles_create_default_settings
  after insert on public.profiles
  for each row execute function public.create_default_profile_settings();
