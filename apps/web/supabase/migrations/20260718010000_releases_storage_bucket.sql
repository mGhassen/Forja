-- Public bucket for Forja release installers (DMG / EXE / AppImage / APK).
-- Uploads use the service role from CI; anonymous clients only read via public URLs.

insert into storage.buckets (id, name, public, file_size_limit)
values (
  'releases',
  'releases',
  true,
  1073741824 -- 1 GiB (desktop installers)
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

-- Public buckets serve /object/public/... without auth; keep SELECT open for
-- authenticated listing / getPublicUrl helpers.
drop policy if exists "releases_public_select" on storage.objects;
create policy "releases_public_select"
  on storage.objects
  for select
  using (bucket_id = 'releases');
