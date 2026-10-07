-- Pack platform allow-list from the manifest `platforms` field (RFC-120).
-- Empty array = every device. Written by admin validation, never hand-edited.
alter table public.plugin_packs
  add column if not exists platforms text[] not null default '{}';

alter table public.plugin_packs
  drop constraint if exists plugin_packs_platforms_check;

alter table public.plugin_packs
  add constraint plugin_packs_platforms_check
  check (platforms <@ array['desktop', 'phone', 'tv']::text[]);

comment on column public.plugin_packs.platforms is
  'Devices the pack runs on (desktop, phone, tv). Empty = all. From manifest platforms via admin validation.';
