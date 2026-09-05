/// Official ForjaHQ pack install targets for onboarding.
///
/// Public Community Packs `catalog.json` does not expose install URLs.
/// These match `apps/web/src/lib/generated/plugin-pack-sources.ts`.
class OfficialForjaHqPack {
  const OfficialForjaHqPack({
    required this.id,
    required this.name,
    required this.manifestUrl,
  });

  final String id;
  final String name;
  final String manifestUrl;
}

const _kPacksBase =
    'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins';

/// Full official set (best-experience bundle).
const kOfficialForjaHqPacks = <OfficialForjaHqPack>[
  OfficialForjaHqPack(
    id: 'providers',
    name: 'ForjaHQ Providers',
    manifestUrl: '$_kPacksBase/providers/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'catalog',
    name: 'ForjaHQ Catalog',
    manifestUrl: '$_kPacksBase/catalog/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'live',
    name: 'ForjaHQ Live',
    manifestUrl: '$_kPacksBase/live/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'torrent',
    name: 'ForjaHQ Torrent',
    manifestUrl: '$_kPacksBase/torrent/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'home',
    name: 'ForjaHQ Home',
    manifestUrl: '$_kPacksBase/hubs/home/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'anime',
    name: 'ForjaHQ Anime',
    manifestUrl: '$_kPacksBase/hubs/anime/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'asian-drama',
    name: 'ForjaHQ Asian Drama',
    manifestUrl: '$_kPacksBase/hubs/asian_drama/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'my-list',
    name: 'ForjaHQ My List',
    manifestUrl: '$_kPacksBase/hubs/my_list/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'live-sports',
    name: 'ForjaHQ Live Sports',
    manifestUrl: '$_kPacksBase/hubs/live_sports/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'iptv-vod',
    name: 'ForjaHQ IPTV VOD',
    manifestUrl: '$_kPacksBase/iptv/vod/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'arabic',
    name: 'ForjaHQ Arabic',
    manifestUrl: '$_kPacksBase/hubs/arabic/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'aflem',
    name: 'ForjaHQ Aflem',
    manifestUrl: '$_kPacksBase/hubs/aflem/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'cartoon',
    name: 'ForjaHQ Cartoon',
    manifestUrl: '$_kPacksBase/hubs/cartoon/manifest.json',
  ),
  OfficialForjaHqPack(
    id: 'kids',
    name: 'ForjaHQ Kids',
    manifestUrl: '$_kPacksBase/hubs/kids/manifest.json',
  ),
];

const kCommunityPacksUrl = 'https://www.forjahq.xyz/plugins';
const kPluginCatalogUrl = 'https://www.forjahq.xyz/plugins/catalog.json';
