-- Local seed after `supabase db reset`.
-- Auth users + `user_settings` sample rows are created by
-- `scripts/create-forja-test-users.js` (Admin Auth API — cannot insert auth.users from SQL).

insert into public.announcements (title, body, severity, active)
select
  'Welcome to Forja',
  'Local Supabase is running. Sign in as user@forja.local / password123 to try remote settings.',
  'info',
  true
where not exists (
  select 1 from public.announcements where title = 'Welcome to Forja'
);

-- Sample release mirror row so download fallback has something if GitHub is down.
insert into public.releases (
  id,
  tag,
  version,
  body,
  published_at,
  html_url,
  source
)
select
  '00000000-0000-4000-8000-000000000001',
  'v0.0.0-local',
  '0.0.0-local',
  'Local seed release — not a real download. Use GitHub Releases for actual builds.',
  now() - interval '1 day',
  'https://github.com/mghassen/Forja/releases',
  'seed'
where not exists (
  select 1 from public.releases where tag = 'v0.0.0-local'
);

insert into public.release_assets (
  id,
  release_id,
  platform,
  name,
  download_url,
  size_bytes
)
select
  '00000000-0000-4000-8000-000000000011',
  '00000000-0000-4000-8000-000000000001',
  'windows',
  'Forja-0.0.0-local-windows.exe',
  'https://github.com/mghassen/Forja/releases',
  0
where not exists (
  select 1
  from public.release_assets
  where id = '00000000-0000-4000-8000-000000000011'
);

insert into public.release_assets (
  id,
  release_id,
  platform,
  name,
  download_url,
  size_bytes
)
select
  '00000000-0000-4000-8000-000000000012',
  '00000000-0000-4000-8000-000000000001',
  'macos',
  'Forja-0.0.0-local-macos.dmg',
  'https://github.com/mghassen/Forja/releases',
  0
where not exists (
  select 1
  from public.release_assets
  where id = '00000000-0000-4000-8000-000000000012'
);
