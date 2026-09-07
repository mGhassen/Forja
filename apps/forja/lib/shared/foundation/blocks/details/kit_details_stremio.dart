import 'package:forja/shared/foundation/blocks/details/kit_details_sections.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

class KitStremioLoadResult {
  const KitStremioLoadResult({
    required this.meta,
    this.rails = const [],
  });

  final MetaItem meta;
  final List<KitDetailRailSection> rails;
}

bool hubMetaIsStremio(MetaItem item) {
  final open = item.open;
  if (open == null) return false;
  if (open.surface == 'stremio') return true;
  return open.extraString('stremioAddonBaseUrl') != null;
}

bool hubMetaUsesHomeWatchHistory(MetaItem item) {
  if (item.numericId('tmdb') == null) return false;
  final surface = item.open?.surface;
  return surface == 'tmdb' || surface == null;
}

Future<KitStremioLoadResult> loadKitStremioDetails(MetaItem seed) async {
  final open = seed.open;
  if (open == null) return KitStremioLoadResult(meta: seed);

  final baseUrl = open.extraString('stremioAddonBaseUrl') ?? '';
  final stremioId = open.extraString('stremioId') ?? open.id;
  var type = open.extraString('stremioType') ??
      (seed.type == 'tv' ? 'series' : 'movie');

  if (baseUrl.isEmpty || stremioId.isEmpty) {
    return KitStremioLoadResult(meta: seed);
  }

  try {
    final stremio = StremioService();
    final metaJson = await stremio.getMeta(
      baseUrl: baseUrl,
      type: type,
      id: stremioId,
    );

    var name = seed.name;
    var description = seed.description;
    var poster = seed.poster;
    var background = seed.background;
    final videos = <MetaVideo>[];
    final rails = <KitDetailRailSection>[];

    if (metaJson != null) {
      name = metaJson['name']?.toString().trim().isNotEmpty == true
          ? metaJson['name'].toString()
          : name;
      description = metaJson['description']?.toString().trim().isNotEmpty ==
              true
          ? metaJson['description'].toString()
          : description;
      poster = metaJson['poster']?.toString().trim().isNotEmpty == true
          ? metaJson['poster'].toString()
          : poster;
      background =
          metaJson['background']?.toString().trim().isNotEmpty == true
              ? metaJson['background'].toString()
              : (background.isNotEmpty ? background : poster);

      final rawVideos = metaJson['videos'];
      if (rawVideos is List) {
        if (type == 'collections') {
          final items = _metaItemsFromStremioVideos(
            rawVideos,
            parentOpen: open,
            addonBaseUrl: baseUrl,
          );
          if (items.isNotEmpty) {
            rails.add(
              KitDetailRailSection(
                id: 'collection',
                title: name.isNotEmpty ? name : 'Collection',
                items: items,
              ),
            );
          }
        } else if (type == 'series') {
          videos.addAll(_catalogVideosFromStremio(rawVideos));
        }
      }
    }

    final meta = MetaItem(
      id: seed.id,
      type: seed.type,
      name: name,
      poster: poster,
      background: background,
      description: description,
      rating: seed.rating,
      releaseInfo: seed.releaseInfo,
      genres: seed.genres,
      badge: seed.badge,
      status: seed.status,
      episodes: seed.episodes,
      bannerImage: seed.bannerImage,
      tmdbMediaType: seed.tmdbMediaType,
      ids: seed.ids,
      listTarget: seed.listTarget,
      open: open,
      videos: videos,
    );

    return KitStremioLoadResult(meta: meta, rails: rails);
  } catch (_) {
    return KitStremioLoadResult(meta: seed);
  }
}

List<MetaVideo> _catalogVideosFromStremio(List raw) {
  final out = <MetaVideo>[];
  for (final v in raw) {
    if (v is! Map) continue;
    final id = v['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final season = (v['season'] as num?)?.toInt() ?? 1;
    final episode = (v['episode'] as num?)?.toInt() ?? 1;
    out.add(
      MetaVideo(
        id: id,
        season: season,
        episode: episode,
        title: (v['title'] ?? 'Episode $episode').toString(),
        thumbnail: (v['thumbnail'] ?? '').toString(),
      ),
    );
  }
  out.sort((a, b) {
    final s = (a.season ?? 1).compareTo(b.season ?? 1);
    if (s != 0) return s;
    return (a.episode ?? 1).compareTo(b.episode ?? 1);
  });
  return out;
}

List<MetaItem> _metaItemsFromStremioVideos(
  List raw, {
  required MetaOpen parentOpen,
  required String addonBaseUrl,
}) {
  final addonName = parentOpen.extraString('stremioAddonName');
  final out = <MetaItem>[];
  for (final v in raw) {
    if (v is! Map) continue;
    final id = v['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    var vType = v['type']?.toString() ?? 'movie';
    if (vType.isEmpty) vType = 'movie';
    final metaType =
        vType == 'series' ? 'tv' : (vType == 'collections' ? 'collections' : 'movie');
    out.add(
      MetaItem(
        id: 'stremio:$metaType:$id',
        type: metaType,
        name: (v['title'] ?? 'Unknown').toString(),
        poster: (v['thumbnail'] ?? '').toString(),
        background: (v['thumbnail'] ?? '').toString(),
        releaseInfo: (v['released'] ?? '').toString(),
        open: MetaOpen(
          surface: 'stremio',
          id: id,
          extras: {
            'stremioId': id,
            'stremioType': vType,
            'stremioAddonBaseUrl': addonBaseUrl,
            'stremioAddonName': ?addonName,
          },
        ),
      ),
    );
  }
  return out;
}
