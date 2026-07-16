alter table public.profiles
  add column avatar_key text not null default 'forge'
  check (
    avatar_key in ('forge', 'flame', 'orbit', 'pixel', 'night', 'mint')
  );
