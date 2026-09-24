import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/details/details_meta.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/details/pack_detail_meta.dart';
import 'package:rust/rust.dart';

class KitStremioLoadResult {
  const KitStremioLoadResult({
    required this.meta,
    this.rails = const [],
  });

  final MetaItem meta;
  final List<KitDetailRailSection> rails;
}

/// Stremio protocol type for `/meta` and `/stream` (not UI type).
String stremioApiType(String? raw, {String seedType = 'movie'}) {
  final t = (raw ?? '').trim().toLowerCase();
  if (t == 'tv' || t == 'series') return 'series';
  if (t == 'collections' || t == 'collection') return 'collections';
  if (t == 'movie' || t == 'channel' || t == 'anime' || t == 'other') return t;
  // seed.type may be a host surface (stremio) — do not treat as series.
  if (seedType == 'tv' || seedType == 'series') return 'series';
  if (seedType == 'anime') return 'anime';
  if (seedType == 'movie') return 'movie';
  return 'movie';
}

String stremioUiType(String apiType) {
  if (apiType == 'series') return 'tv';
  if (apiType == 'collections') return 'collections';
  if (apiType == 'anime') return 'anime';
  return 'movie';
}

String stremioPanelKind(String uiType) {
  if (uiType == 'tv' || uiType == 'series') return 'tv';
  if (uiType == 'anime') return 'anime';
  return 'movie';
}

bool _metaHasId(Map<String, dynamic>? meta) {
  if (meta == null) return false;
  final id = meta['id']?.toString().trim() ?? '';
  return id.isNotEmpty;
}

bool _metaHasVideos(Map<String, dynamic>? meta) {
  final videos = meta?['videos'];
  return videos is List && videos.isNotEmpty;
}

/// Prefer the richer of two `/meta` payloads (id required).
Map<String, dynamic>? _preferRicherMeta(
  Map<String, dynamic>? a,
  Map<String, dynamic>? b,
) {
  if (!_metaHasId(a)) return _metaHasId(b) ? b : null;
  if (!_metaHasId(b)) return a;
  final aVideos = _metaHasVideos(a);
  final bVideos = _metaHasVideos(b);
  if (aVideos != bVideos) return aVideos ? a : b;
  final aDesc = (a!['description']?.toString().trim() ?? '').isNotEmpty;
  final bDesc = (b!['description']?.toString().trim() ?? '').isNotEmpty;
  if (aDesc != bDesc) return aDesc ? a : b;
  return a;
}

Future<KitStremioLoadResult> loadKitStremioDetails(MetaItem seed) async {
  final open = seed.open;
  if (open == null) return KitStremioLoadResult(meta: seed);

  final baseUrl = open.extraString('stremioAddonBaseUrl') ?? '';
  final stremioId = open.extraString('stremioId') ?? open.id;
  final apiType = stremioApiType(
    open.extraString('stremioType'),
    seedType: seed.type,
  );

  if (baseUrl.isEmpty || stremioId.isEmpty) {
    return KitStremioLoadResult(meta: seed);
  }

  try {
    final stremio = StremioService();
    var metaJson = await stremio.getMeta(
      baseUrl: baseUrl,
      type: apiType,
      id: stremioId,
    );
    // Wrong catalog type (movie listed as series, or empty Cinemeta {}) —
    // try the other type and keep whichever payload is richer.
    if (apiType == 'series' || apiType == 'movie') {
      final alt = apiType == 'series' ? 'movie' : 'series';
      final needsAlt = !_metaHasId(metaJson) ||
          (apiType == 'series' && !_metaHasVideos(metaJson));
      if (needsAlt) {
        final altJson = await stremio.getMeta(
          baseUrl: baseUrl,
          type: alt,
          id: stremioId,
        );
        metaJson = _preferRicherMeta(metaJson, altJson);
      }
    }
    if (!_metaHasId(metaJson)) {
      metaJson = await stremio.getMetaFromAny(
        type: apiType,
        id: stremioId,
      );
      if (!_metaHasId(metaJson) &&
          (apiType == 'series' || apiType == 'movie')) {
        final alt = apiType == 'series' ? 'movie' : 'series';
        metaJson = await stremio.getMetaFromAny(
          type: alt,
          id: stremioId,
        );
      }
    }

    var name = seed.name;
    var description = seed.description;
    var poster = seed.poster;
    var background = seed.background;
    var logo = seed.logo;
    var rating = seed.rating;
    var releaseInfo = seed.releaseInfo;
    var genres = List<String>.from(seed.genres);
    var status = seed.status;
    var resolvedApiType = apiType;
    final ids = Map<String, dynamic>.from(seed.ids);
    final videos = <MetaVideo>[];
    final rails = <KitDetailRailSection>[];
    final cast = <Map<String, String>>[];
    final crew = <Map<String, String>>[];
    final trailers = <Map<String, dynamic>>[];
    final facts = <String, dynamic>{};

    if (metaJson != null && _metaHasId(metaJson)) {
      final metaTypeRaw = metaJson['type']?.toString();
      if (metaTypeRaw != null && metaTypeRaw.trim().isNotEmpty) {
        resolvedApiType = stremioApiType(metaTypeRaw, seedType: seed.type);
      }

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
      final logoRaw = metaJson['logo']?.toString().trim() ?? '';
      if (logoRaw.isNotEmpty) logo = logoRaw;

      final imdbRating = double.tryParse(
        metaJson['imdbRating']?.toString() ?? '',
      );
      if (imdbRating != null) rating = imdbRating;

      final releaseRaw = metaJson['releaseInfo']?.toString().trim() ?? '';
      if (releaseRaw.isNotEmpty) {
        releaseInfo =
            releaseRaw.length >= 4 ? releaseRaw.substring(0, 4) : releaseRaw;
      }

      final genresRaw = metaJson['genres'];
      if (genresRaw is List && genresRaw.isNotEmpty) {
        genres = genresRaw
            .map((g) => g.toString().trim())
            .where((g) => g.isNotEmpty)
            .toList();
      }

      final statusRaw = metaJson['status']?.toString().trim() ?? '';
      if (statusRaw.isNotEmpty) status = statusRaw;

      final imdbFromMeta = metaJson['imdb_id']?.toString().trim() ??
          metaJson['imdbId']?.toString().trim() ??
          '';
      if (imdbFromMeta.startsWith('tt')) {
        ids['imdb'] = imdbFromMeta;
      } else if (stremioId.startsWith('tt')) {
        ids['imdb'] = stremioId;
      }
      final tmdbFromMeta = metaJson['moviedb_id'] ?? metaJson['tmdb_id'];
      if (tmdbFromMeta != null) {
        final tmdbStr = tmdbFromMeta.toString().trim();
        if (tmdbStr.isNotEmpty) ids['tmdb'] = tmdbStr;
      }

      final castRaw = metaJson['cast'];
      if (castRaw is List) {
        for (final c in castRaw) {
          final n = c?.toString().trim() ?? '';
          if (n.isEmpty) continue;
          cast.add({'name': n, 'character': ''});
        }
      }

      final directorRaw = metaJson['director'];
      if (directorRaw is List) {
        for (final d in directorRaw) {
          final n = d?.toString().trim() ?? '';
          if (n.isEmpty) continue;
          crew.add({'name': n, 'job': 'Director'});
        }
      } else {
        final n = directorRaw?.toString().trim() ?? '';
        if (n.isNotEmpty) crew.add({'name': n, 'job': 'Director'});
      }

      final writerRaw = metaJson['writer'];
      if (writerRaw is List) {
        for (final w in writerRaw) {
          final n = w?.toString().trim() ?? '';
          if (n.isEmpty) continue;
          crew.add({'name': n, 'job': 'Writer'});
        }
      }

      final trailersRaw = metaJson['trailers'];
      if (trailersRaw is List) {
        for (final t in trailersRaw) {
          if (t is! Map) continue;
          final key = (t['source'] ?? t['ytId'] ?? t['id'] ?? '').toString();
          if (key.isEmpty) continue;
          trailers.add({
            'key': key,
            'name': (t['name'] ?? 'Trailer').toString(),
            'type': (t['type'] ?? 'Trailer').toString(),
            'site': (t['site'] ?? 'YouTube').toString(),
          });
        }
      }

      final runtimeRaw = metaJson['runtime']?.toString().trim() ?? '';
      if (runtimeRaw.isNotEmpty) {
        final mins = int.tryParse(runtimeRaw.replaceAll(RegExp(r'[^0-9]'), ''));
        if (mins != null && mins > 0) facts['runtimeMinutes'] = mins;
      }
      final country = metaJson['country']?.toString().trim() ?? '';
      if (country.isNotEmpty) facts['originCountries'] = [country];
      final language = metaJson['language']?.toString().trim() ?? '';
      if (language.isNotEmpty) facts['originalLanguage'] = language;
      if (releaseInfo.isNotEmpty) facts['releaseDate'] = releaseInfo;
      facts['mediaType'] = stremioUiType(resolvedApiType);

      final rawVideos = metaJson['videos'];
      if (rawVideos is List) {
        if (resolvedApiType == 'collections') {
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
        } else if (resolvedApiType == 'series' || resolvedApiType == 'anime') {
          videos.addAll(_catalogVideosFromStremio(rawVideos));
          if (videos.isNotEmpty) {
            facts['episodeCount'] = videos.length;
            facts['seasonCount'] = hubSeasonNumbers(videos).length;
          }
        }
      }
    }

    final uiType = stremioUiType(resolvedApiType);
    final panelKind = stremioPanelKind(uiType);
    final openExtras = Map<String, dynamic>.from(open.extras);
    openExtras['stremioType'] = resolvedApiType;
    openExtras['stremioId'] = stremioId;
    openExtras['stremioAddonBaseUrl'] = baseUrl;
    openExtras['mediaType'] = uiType;
    openExtras.putIfAbsent('preferredSourcesKind', () => 'stremio');

    final meta = MetaItem(
      id: seed.id,
      type: uiType,
      name: name,
      poster: poster,
      background: background,
      logo: logo,
      description: description,
      rating: rating,
      releaseInfo: releaseInfo,
      genres: genres,
      badge: seed.badge,
      status: status,
      episodes: videos.isNotEmpty ? videos.length : seed.episodes,
      bannerImage: seed.bannerImage,
      tmdbMediaType: uiType == 'tv' ? 'tv' : (uiType == 'movie' ? 'movie' : null),
      ids: ids,
      listTarget: seed.listTarget,
      open: MetaOpen(
        surface: open.surface,
        id: open.id,
        extract: MetaOpenExtract(
          resolveType: panelKind,
          panelCategory: panelKind,
          ctx: {
            ...?open.extract?.ctx,
            if (stremioId.isNotEmpty) 'openId': stremioId,
          },
        ),
        extras: openExtras,
      ),
      videos: videos,
      cast: cast.isNotEmpty ? cast : seed.cast,
      crew: crew.isNotEmpty ? crew : seed.crew,
      trailers: trailers.isNotEmpty ? trailers : seed.trailers,
      facts: facts.isNotEmpty ? facts : seed.facts,
    );

    return KitStremioLoadResult(meta: meta, rails: rails);
  } catch (e, st) {
    debugPrint('[loadKitStremioDetails] $e\n$st');
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
    final released = v['released']?.toString().trim() ?? '';
    final airDate = released.length >= 10
        ? released.substring(0, 10)
        : (v['air_date']?.toString().trim() ?? '');
    out.add(
      MetaVideo(
        id: id,
        season: season,
        episode: episode,
        title: (v['title'] ?? 'Episode $episode').toString(),
        thumbnail: (v['thumbnail'] ?? '').toString(),
        airDate: airDate,
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
    final apiType = stremioApiType(vType);
    final metaType = stremioUiType(apiType);
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
          extract: MetaOpenExtract(
            resolveType: stremioPanelKind(metaType),
            panelCategory: stremioPanelKind(metaType),
            ctx: {if (id.isNotEmpty) 'openId': id},
          ),
          extras: {
            'stremioId': id,
            'stremioType': apiType,
            'stremioAddonBaseUrl': addonBaseUrl,
            'stremioAddonName': ?addonName,
            'mediaType': metaType,
            'preferredSourcesKind': 'stremio',
          },
        ),
      ),
    );
  }
  return out;
}
