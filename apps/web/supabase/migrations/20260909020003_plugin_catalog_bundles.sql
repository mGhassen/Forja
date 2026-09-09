-- RFC-100: Admin plugin catalog + product bundles.
-- Pack files stay on GitHub raw; Supabase stores catalog metadata + publish flags.

create table public.plugin_packs (
  id text primary key,
  manifest_url text not null,
  kind text not null default 'providers',
  name text not null,
  description text not null default '',
  author text,
  tags text[] not null default '{}',
  accent text not null default 'brand'
    check (accent in ('brand', 'flame')),
  official boolean not null default false,
  recommended boolean not null default false,
  published boolean not null default false,
  sort_order int not null default 0,
  cached_version text,
  plugin_count int,
  last_validated_at timestamptz,
  last_validation jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.plugin_packs is
  'Published plugin pack catalog metadata. Files live at manifest_url (GitHub). RFC-100.';

create table public.plugin_bundles (
  id text primary key,
  name text not null,
  description text not null default '',
  recommended boolean not null default false,
  published boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.plugin_bundles is
  'Product bundles: ordered groups of packs for onboarding. RFC-100.';

create table public.plugin_bundle_items (
  bundle_id text not null references public.plugin_bundles (id) on delete cascade,
  pack_id text not null references public.plugin_packs (id) on delete restrict,
  sort_order int not null default 0,
  primary key (bundle_id, pack_id)
);

comment on table public.plugin_bundle_items is
  'Ordered pack membership for a product bundle. RFC-100.';

create index plugin_packs_published_sort_idx
  on public.plugin_packs (published, sort_order, id);

create index plugin_bundles_published_sort_idx
  on public.plugin_bundles (published, sort_order, id);

create index plugin_bundle_items_pack_idx
  on public.plugin_bundle_items (pack_id);

create or replace function public.plugin_catalog_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger plugin_packs_touch_updated_at
  before update on public.plugin_packs
  for each row execute function public.plugin_catalog_touch_updated_at();

create trigger plugin_bundles_touch_updated_at
  before update on public.plugin_bundles
  for each row execute function public.plugin_catalog_touch_updated_at();

alter table public.plugin_packs enable row level security;
alter table public.plugin_bundles enable row level security;
alter table public.plugin_bundle_items enable row level security;

-- Public may read published rows only.
create policy plugin_packs_select_published
  on public.plugin_packs
  for select
  to anon, authenticated
  using (published = true or public.is_admin());

create policy plugin_bundles_select_published
  on public.plugin_bundles
  for select
  to anon, authenticated
  using (published = true or public.is_admin());

create policy plugin_bundle_items_select_published
  on public.plugin_bundle_items
  for select
  to anon, authenticated
  using (
    public.is_admin()
    or exists (
      select 1
      from public.plugin_bundles b
      where b.id = plugin_bundle_items.bundle_id
        and b.published = true
    )
  );

-- Admin write.
create policy plugin_packs_admin_insert
  on public.plugin_packs
  for insert
  to authenticated
  with check (public.is_admin());

create policy plugin_packs_admin_update
  on public.plugin_packs
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy plugin_packs_admin_delete
  on public.plugin_packs
  for delete
  to authenticated
  using (public.is_admin());

create policy plugin_bundles_admin_insert
  on public.plugin_bundles
  for insert
  to authenticated
  with check (public.is_admin());

create policy plugin_bundles_admin_update
  on public.plugin_bundles
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy plugin_bundles_admin_delete
  on public.plugin_bundles
  for delete
  to authenticated
  using (public.is_admin());

create policy plugin_bundle_items_admin_insert
  on public.plugin_bundle_items
  for insert
  to authenticated
  with check (public.is_admin());

create policy plugin_bundle_items_admin_update
  on public.plugin_bundle_items
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy plugin_bundle_items_admin_delete
  on public.plugin_bundle_items
  for delete
  to authenticated
  using (public.is_admin());

-- Seed official ForjaHQ packs (GitHub raw). Published + recommended match app defaults.
insert into public.plugin_packs (
  id, manifest_url, kind, name, description, author, tags, accent,
  official, recommended, published, sort_order
) values
  (
    'providers',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/providers/manifest.json',
    'providers',
    'ForjaHQ Providers',
    'VOD, anime, and drama stream extractors plus file-host hops.',
    'ForjaHQ',
    array['anime','arabic','drama','movies','providers','tv'],
    'brand', true, true, true, 10
  ),
  (
    'catalog',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/catalog/manifest.json',
    'catalog',
    'ForjaHQ Catalog',
    'Live Sports schedule catalogs (Streamed, PPV, ESPN, …).',
    'ForjaHQ',
    array['live','sports'],
    'brand', true, true, true, 20
  ),
  (
    'live',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/live/manifest.json',
    'live',
    'ForjaHQ Live',
    'Live Sports per-site stream resolve (Forja Live).',
    'ForjaHQ',
    array['live','sports'],
    'brand', true, true, true, 30
  ),
  (
    'torrent',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/torrent/manifest.json',
    'torrent',
    'ForjaHQ Torrent',
    'Built-in torrent indexer search for movies and series.',
    'ForjaHQ',
    array['torrent'],
    'brand', true, true, true, 40
  ),
  (
    'home',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/home/manifest.json',
    'hubs',
    'ForjaHQ Home',
    'TMDB movie and TV catalog for the Home tab.',
    'ForjaHQ',
    array['home','movies','tv'],
    'brand', true, true, true, 50
  ),
  (
    'anime',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/anime/manifest.json',
    'hubs',
    'ForjaHQ Anime',
    'AniList-powered anime hub with search and details.',
    'ForjaHQ',
    array['anime'],
    'brand', true, true, true, 60
  ),
  (
    'asian-drama',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/asian_drama/manifest.json',
    'hubs',
    'ForjaHQ Asian Drama',
    'KissKH Asian drama catalog hub.',
    'ForjaHQ',
    array['asian-drama','drama'],
    'brand', true, true, true, 70
  ),
  (
    'my-list',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/my_list/manifest.json',
    'hubs',
    'ForjaHQ My List',
    'Personal watchlists: local bookmarks and Simkl sync.',
    'ForjaHQ',
    array['lists'],
    'brand', true, false, true, 80
  ),
  (
    'live-sports',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/live_sports/manifest.json',
    'hubs',
    'ForjaHQ Live Sports',
    'Live sports list with a streams panel.',
    'ForjaHQ',
    array['live','sports'],
    'brand', true, true, true, 90
  ),
  (
    'live-sports-cards',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/live_sports_cards/manifest.json',
    'hubs',
    'ForjaHQ Live Sports Cards',
    'Live sports schedule as cards with a details page.',
    'ForjaHQ',
    array['live','sports'],
    'brand', true, false, true, 100
  ),
  (
    'iptv-vod',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/iptv/vod/manifest.json',
    'iptv',
    'ForjaHQ IPTV VOD',
    'IPTV portal movie and series details with optional TMDB enrich.',
    'ForjaHQ',
    array['iptv'],
    'brand', true, false, true, 110
  ),
  (
    'arabic',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/arabic/manifest.json',
    'hubs',
    'ForjaHQ Arabic',
    'Larozaa Arabic movies and TV hub.',
    'ForjaHQ',
    array['arabic'],
    'brand', true, false, true, 120
  ),
  (
    'aflem',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/aflem/manifest.json',
    'hubs',
    'ForjaHQ Aflem',
    'Aflem Arabic series hub (Brstej upstream).',
    'ForjaHQ',
    array['aflem','arabic'],
    'brand', true, false, true, 130
  ),
  (
    'cartoon',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/cartoon/manifest.json',
    'hubs',
    'ForjaHQ Cartoon',
    'DimaToon Arabic cartoon / anime hub (كرتون).',
    'ForjaHQ',
    array['arabic','cartoon'],
    'brand', true, false, true, 140
  ),
  (
    'kids',
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins/hubs/kids/manifest.json',
    'hubs',
    'ForjaHQ Kids',
    'Dimakids Arabic kids cartoons and movies hub.',
    'ForjaHQ',
    array['arabic','kids'],
    'brand', true, false, true, 150
  )
on conflict (id) do nothing;

insert into public.plugin_bundles (
  id, name, description, recommended, published, sort_order
) values (
  'best-experience',
  'Best experience',
  'Core ForjaHQ packs for Home, hubs, providers, live sports, and torrent.',
  true,
  true,
  10
)
on conflict (id) do nothing;

insert into public.plugin_bundle_items (bundle_id, pack_id, sort_order) values
  ('best-experience', 'home', 10),
  ('best-experience', 'anime', 20),
  ('best-experience', 'asian-drama', 30),
  ('best-experience', 'providers', 40),
  ('best-experience', 'live', 50),
  ('best-experience', 'catalog', 60),
  ('best-experience', 'torrent', 70),
  ('best-experience', 'live-sports', 80)
on conflict (bundle_id, pack_id) do nothing;
