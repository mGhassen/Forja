/// Official ForjaHQ pack install targets for onboarding.
///
/// Public Community Packs `catalog.json` does not expose install URLs.
/// These match `apps/web/src/lib/generated/plugin-pack-sources.ts`.
class OfficialForjaHqPack {
  const OfficialForjaHqPack({
    required this.id,
    required this.name,
    required this.manifestUrl,
    this.description,
    this.tags = const [],
    this.kind,
    this.recommended = false,
  });

  final String id;
  final String name;
  final String manifestUrl;

  /// Short human blurb (same text as pack `manifest.json` / catalog).
  final String? description;

  /// Topic tags from the public catalog (`anime`, `live`, …).
  final List<String> tags;

  /// Catalog kind (`hubs`, `providers`, `live`, …).
  final String? kind;

  /// Soft CTA — show Recommended badge on Official packs picker / web catalog.
  final bool recommended;
}

/// Core ForjaHQ packs surfaced with a Recommended badge.
const kOfficialRecommendedPackIds = <String>{
  'home',
  'anime',
  'asian-drama',
  'providers',
  'live',
  'catalog',
  'torrent',
  'arabic',
};

const _kPacksBase =
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins';

/// Full official set (best-experience bundle).
const kOfficialForjaHqPacks = <OfficialForjaHqPack>[
  OfficialForjaHqPack(
    id: 'providers',
    name: 'ForjaHQ Providers',
    kind: 'providers',
    tags: ['anime', 'arabic', 'drama', 'movies', 'providers', 'tv'],
    recommended: true,
    description:
        'VOD, anime, and drama stream extractors plus file-host hops.',
    manifestUrl: '$_kPacksBase/providers/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'catalog',
    name: 'ForjaHQ Catalog',
    kind: 'catalog',
    tags: ['live', 'sports'],
    recommended: true,
    description: 'Live Matches schedule catalogs (Streamed, PPV, ESPN, …).',
    manifestUrl: '$_kPacksBase/catalog/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'live',
    name: 'ForjaHQ Live',
    kind: 'live',
    tags: ['live', 'sports'],
    recommended: true,
    description: 'Live Matches per-site stream resolve (Forja Live).',
    manifestUrl: '$_kPacksBase/live/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'torrent',
    name: 'ForjaHQ Torrent',
    kind: 'torrent',
    tags: ['torrent'],
    recommended: true,
    description: 'Built-in torrent indexer search for movies and series.',
    manifestUrl: '$_kPacksBase/torrent/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'home',
    name: 'ForjaHQ Home',
    kind: 'hubs',
    tags: ['home', 'movies', 'tv'],
    recommended: true,
    description: 'TMDB movie and TV catalog for the Home tab.',
    manifestUrl: '$_kPacksBase/hubs/home/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'anime',
    name: 'ForjaHQ Anime',
    kind: 'hubs',
    tags: ['anime'],
    recommended: true,
    description: 'AniList-powered anime hub with search and details.',
    manifestUrl: '$_kPacksBase/hubs/anime/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'asian-drama',
    name: 'ForjaHQ Asian Drama',
    kind: 'hubs',
    tags: ['asian-drama', 'drama'],
    recommended: true,
    description: 'KissKH Asian drama catalog hub.',
    manifestUrl: '$_kPacksBase/hubs/asian_drama/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'my-list',
    name: 'ForjaHQ My List',
    kind: 'hubs',
    tags: ['lists'],
    description: 'Personal watchlists: local bookmarks and Simkl sync.',
    manifestUrl: '$_kPacksBase/hubs/my_list/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'live-sports',
    name: 'ForjaHQ Live Sports',
    kind: 'hubs',
    tags: ['live', 'sports'],
    description:
        'Live sports hub — schedule browse and stream resolve via host live kit.',
    manifestUrl: '$_kPacksBase/hubs/live_sports/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'iptv-vod',
    name: 'ForjaHQ IPTV VOD',
    kind: 'iptv',
    tags: ['iptv'],
    description:
        'IPTV portal movie and series details with optional TMDB enrich.',
    manifestUrl: '$_kPacksBase/iptv/vod/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'arabic',
    name: 'ForjaHQ Arabic',
    kind: 'hubs',
    tags: ['arabic'],
    recommended: true,
    description:
        'Arabic hub — Larozaa only (Brstej / كرتون are separate packs).',
    manifestUrl: '$_kPacksBase/hubs/arabic/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'aflem',
    name: 'ForjaHQ Aflem',
    kind: 'hubs',
    tags: ['aflem', 'arabic'],
    description: 'Aflem Arabic series hub (Brstej upstream).',
    manifestUrl: '$_kPacksBase/hubs/aflem/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'cartoon',
    name: 'ForjaHQ Cartoon',
    kind: 'hubs',
    tags: ['arabic', 'cartoon'],
    description: 'DimaToon Arabic cartoon / anime hub (كرتون).',
    manifestUrl: '$_kPacksBase/hubs/cartoon/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'kids',
    name: 'ForjaHQ Kids',
    kind: 'hubs',
    tags: ['arabic', 'kids'],
    description: 'Dimakids Arabic kids cartoons and movies hub.',
    manifestUrl: '$_kPacksBase/hubs/kids/manifest.json',
  ),
];

const kCommunityPacksUrl = 'https://www.forjahq.xyz/plugins';
const kPluginCatalogUrl = 'https://www.forjahq.xyz/plugins/catalog.json';
