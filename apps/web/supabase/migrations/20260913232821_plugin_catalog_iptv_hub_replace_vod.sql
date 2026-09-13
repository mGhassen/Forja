-- Replace catalog IPTV VOD-only pack with the full IPTV hub
-- (nav + live + portal VOD details) from forja-packs.

delete from public.plugin_bundle_items
where pack_id = 'iptv-vod';

delete from public.plugin_packs
where id = 'iptv-vod';

insert into public.plugin_packs (
  id, manifest_url, kind, name, description, author, tags, accent,
  official, recommended, published, sort_order
) values (
  'iptv',
  'https://raw.githubusercontent.com/mGhassen/forja-packs/main/hubs/iptv/manifest.json',
  'hubs',
  'ForjaHQ IPTV',
  'IPTV portals, live channels, and portal movie/series details.',
  'ForjaHQ',
  array['iptv', 'live'],
  'brand',
  true,
  false,
  true,
  110
)
on conflict (id) do update set
  manifest_url = excluded.manifest_url,
  kind = excluded.kind,
  name = excluded.name,
  description = excluded.description,
  author = excluded.author,
  tags = excluded.tags,
  accent = excluded.accent,
  official = excluded.official,
  recommended = excluded.recommended,
  published = excluded.published,
  sort_order = excluded.sort_order;
