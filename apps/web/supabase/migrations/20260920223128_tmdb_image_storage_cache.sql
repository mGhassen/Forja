-- TMDB gateway image cache: bytes in Storage, TTL metadata in Postgres.
-- JSON API cache remains public.tmdb_response_cache (prior migration).

create table public.tmdb_image_cache (
  cache_key text primary key,
  storage_path text not null,
  content_type text not null default 'image/jpeg',
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

comment on table public.tmdb_image_cache is
  'TMDB gateway image index — objects live in storage bucket tmdb-images.';

create index tmdb_image_cache_expires_at_idx
  on public.tmdb_image_cache (expires_at);

alter table public.tmdb_image_cache enable row level security;
-- No anon/authenticated policies — service_role only.

insert into storage.buckets (id, name, public, file_size_limit)
values (
  'tmdb-images',
  'tmdb-images',
  true,
  10485760 -- 10 MiB per poster/backdrop
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

drop policy if exists "tmdb_images_public_select" on storage.objects;
create policy "tmdb_images_public_select"
  on storage.objects
  for select
  using (bucket_id = 'tmdb-images');
-- Writes via service_role only (bypasses RLS).
