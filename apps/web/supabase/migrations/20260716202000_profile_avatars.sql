alter table public.profiles
  add column avatar_key text not null default 'forge'
  check (
    avatar_key in ('forge', 'flame', 'orbit', 'pixel', 'night', 'mint')
  );

-- The original delete trigger called the auth-user insert function, which reads
-- NEW.id and cannot run for DELETE events. Point it at the delete guard.
drop trigger if exists profiles_keep_one on public.profiles;

create trigger profiles_keep_one
  after delete on public.profiles
  for each row execute function public.ensure_profile_after_delete();
