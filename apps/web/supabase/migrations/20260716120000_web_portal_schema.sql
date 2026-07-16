-- user_settings, releases, release_assets, announcements + RLS + avatars bucket

create table if not exists public.user_settings (
  user_id uuid not null references auth.users (id) on delete cascade,
  domain text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, domain)
);

alter table public.user_settings enable row level security;

create policy "user_settings_own_all"
  on public.user_settings
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.releases (
  id uuid primary key default gen_random_uuid(),
  tag text not null unique,
  version text not null,
  body text,
  published_at timestamptz not null,
  html_url text,
  source text not null default 'github',
  synced_at timestamptz not null default now()
);

create table if not exists public.release_assets (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.releases (id) on delete cascade,
  platform text not null,
  name text not null,
  download_url text not null,
  size_bytes bigint,
  unique (release_id, name)
);

create index if not exists release_assets_release_id_idx
  on public.release_assets (release_id);

create index if not exists releases_published_at_idx
  on public.releases (published_at desc);

alter table public.releases enable row level security;
alter table public.release_assets enable row level security;

create policy "releases_public_select"
  on public.releases
  for select
  using (true);

create policy "release_assets_public_select"
  on public.release_assets
  for select
  using (true);

-- Writes only via service role (Edge Function / dashboard)

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  severity text not null default 'info',
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.announcements enable row level security;

create policy "announcements_public_active"
  on public.announcements
  for select
  using (
    active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

create policy "avatars_own_select"
  on storage.objects
  for select
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "avatars_own_insert"
  on storage.objects
  for insert
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "avatars_own_update"
  on storage.objects
  for update
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "avatars_own_delete"
  on storage.objects
  for delete
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
