import 'package:forja/shared/foundation/lib/cover_urls.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_meta.dart';
import 'package:forja/shared/foundation/components/meta/meta_movie.dart';
import 'package:forja/shared/foundation/components/cards/kit_poster_card.dart';
import 'package:forja/shared/foundation/components/rows/kit_section.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/blocks/shell/legacy_movie_meta.dart';
import 'package:forja/shared/foundation/blocks/shell/kit_open.dart';
import 'package:forja/shared/foundation/tv/media_details_tv_scope.dart';
import 'package:forja/shared/foundation/components/media_details/media_details_recommendations_section.dart';
import 'package:forja/shared/foundation/components/media_details/media_details_cast_section.dart';
import 'package:forja/shared/foundation/components/media_details/media_details_trailers_section.dart';
import 'package:rust/rust.dart';

class KitDetailRailSection {
  const KitDetailRailSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<MetaItem> items;
}

List<KitDetailRailSection> parseKitDetailRails(Map<String, dynamic>? data) {
  final rails = data?['rails'];
  if (rails is! Map) return const [];

  final out = <KitDetailRailSection>[];
  for (final entry in rails.entries) {
    final id = entry.key.toString();
    final v = entry.value;
    var title = _defaultRailTitle(id);
    List<MetaItem> items = const [];

    if (v is List) {
      items = _itemsFromJsonList(v);
    } else if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final custom = (m['title'] ?? '').toString().trim();
      if (custom.isNotEmpty) title = custom;
      items = _itemsFromJsonList(m['items']);
    }

    if (items.isNotEmpty) {
      out.add(KitDetailRailSection(id: id, title: title, items: items));
    }
  }
  return out;
}

List<MetaItem> _itemsFromJsonList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final it in raw)
      if (it is Map)
        MetaItem.fromJson(Map<String, dynamic>.from(it)),
  ];
}

String _defaultRailTitle(String id) {
  switch (id) {
    case 'related':
      return 'Related';
    case 'recommendations':
      return 'More Like This';
    case 'characters':
      return 'Characters';
    case 'staff':
      return 'Staff';
    default:
      if (id.isEmpty) return '';
      return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }
}

List<Widget> buildKitDetailRailSections({
  required BuildContext context,
  required String pluginId,
  required List<KitDetailRailSection> rails,
  required bool tvFocus,
  int tvRowOrderBase = 0,
  VoidCallback? firstMetaFocusUp,
}) {
  if (rails.isEmpty) return const [];

  var order = tvRowOrderBase;
  final sections = <Widget>[];
  for (final rail in rails) {
    final rowOrder = order++;
    // Prefix so pack `recommendations` cannot collide with TMDB row ids.
    final rowId = 'pack:${rail.id}';
    sections.add(
      KitSection<MetaItem>(
        title: rail.title,
        items: rail.items,
        embedded: true,
        compactTop: true,
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: rowId,
        tvRowOrder: rowOrder,
        tvFocusUp: sections.isEmpty ? firstMetaFocusUp : null,
        cardBuilder: (ctx, item, index) => KitPosterCard(
          imageUrl: item.poster,
          title: item.name,
          subtitle: kitPosterSubtitle(item),
          rating: item.rating,
          badge: kitPosterBadge(item, pluginId: pluginId),
          listIndex: index,
          onTap: () => openMetaItem(
            ctx,
            pluginId: pluginId,
            item: item,
          ),
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: rowId,
        ),
      ),
    );
  }
  return sections;
}

List<Widget> buildKitTmdbDetailSections({
  required BuildContext context,
  required String pluginId,
  required RichMediaDetails? rich,
  required bool tvFocus,
  int tvRowOrderBase = 0,
  VoidCallback? firstMetaFocusUp,
  List<Movie>? recommendations,
  void Function(Movie movie)? onRecommendationTap,
  bool includeCast = true,
  bool includeCrew = true,
  bool includeTrailers = true,
  bool includeRecommendations = true,
}) {
  if (rich == null &&
      (recommendations == null || recommendations.isEmpty)) {
    return const [];
  }

  final cast = includeCast
      ? (rich?.extras.cast ?? const <Map<String, String>>[])
      : const <Map<String, String>>[];
  final crew = includeCrew
      ? _crewAsCast(rich?.extras.crew ?? const <Map<String, String>>[])
      : const <Map<String, String>>[];
  final trailers = includeTrailers
      ? (rich?.extras.trailers ?? const <MediaTrailer>[])
      : const <MediaTrailer>[];
  final recs = !includeRecommendations
      ? const <Movie>[]
      : (recommendations ?? rich?.extras.recommendations ?? const <Movie>[]);

  final showCast = cast.isNotEmpty;
  final showCrew = crew.isNotEmpty;
  final showTrailers = trailers.isNotEmpty;
  final showRecs = recs.isNotEmpty;
  if (!showCast && !showCrew && !showTrailers && !showRecs) {
    return const [];
  }

  var order = tvRowOrderBase;
  final sections = <Widget>[];
  int? castOrder;
  int? crewOrder;
  int? trailersOrder;
  int? recsOrder;

  if (showCast) castOrder = order++;
  if (showCrew) crewOrder = order++;
  if (showTrailers) trailersOrder = order++;
  if (showRecs) recsOrder = order++;

  if (showCast) {
    sections.add(
      MediaDetailsCastSection(
        cast: cast,
        title: 'Characters',
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: 'cast',
        tvRowOrder: castOrder!,
        tvFocusUp: firstMetaFocusUp,
      ),
    );
  }
  if (showCrew) {
    sections.add(
      MediaDetailsCastSection(
        cast: crew,
        title: 'Crew',
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: 'crew',
        tvRowOrder: crewOrder!,
        tvFocusUp: showCast ? null : firstMetaFocusUp,
      ),
    );
  }
  if (showTrailers) {
    sections.add(
      MediaDetailsTrailersSection(
        trailers: trailers,
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: 'trailers',
        tvRowOrder: trailersOrder!,
        tvFocusUp: (showCast || showCrew) ? null : firstMetaFocusUp,
      ),
    );
  }
  if (showRecs) {
    sections.add(
      MediaDetailsRecommendationsSection(
        movies: recs,
        onMovieTap: onRecommendationTap ??
            (movie) => openMetaItem(
                  context,
                  pluginId: pluginId,
                  item: metaItemFromMovie(movie),
                ),
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: 'recommendations',
        tvRowOrder: recsOrder!,
        tvFocusUp: (showCast || showCrew || showTrailers)
            ? null
            : firstMetaFocusUp,
      ),
    );
  }
  return sections;
}

List<Map<String, String>> _crewAsCast(List<Map<String, String>> crew) {
  return [
    for (final c in crew)
      if ((c['name'] ?? '').trim().isNotEmpty)
        {
          'name': c['name']!,
          'character': (c['job'] ?? '').trim(),
          'profilePath': (c['profilePath'] ?? '').trim(),
        },
  ];
}

final _hubTmdbRichCache = <String, RichMediaDetails>{};
final _hubTmdbBackdropCache = <String, List<String>>{};
final _hubHeroBackdropCache = <String, List<String>>{};

String _hubTmdbUiCacheKey(MetaItem meta) {
  final tmdbId = meta.numericId('tmdb');
  if (tmdbId == null) return meta.id;
  final mediaType = hubMetaTmdbMediaType(meta);
  return '$tmdbId|$mediaType';
}

String _hubHeroCacheKey(MetaItem meta) =>
    '${meta.id}|${meta.background}|${meta.bannerImage}|${meta.poster}';

List<String> _packHeroBackdropUrls(MetaItem meta) {
  final cacheKey = _hubHeroCacheKey(meta);
  final cached = _hubHeroBackdropCache[cacheKey];
  if (cached != null) return cached;

  final urls = <String>[];
  void addUrl(String raw) {
    final u = resolveCoverUrl(raw.trim());
    if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
  }

  addUrl(meta.background);
  addUrl(meta.bannerImage);
  addUrl(meta.poster);

  final out = urls.take(12).toList();
  _hubHeroBackdropCache[cacheKey] = out;
  return out;
}

/// Immediate pack / enrich URLs — use before [kitTmdbHeroBackdropUrls] resolves.
List<String> hubHeroBackdropUrls(MetaItem meta) =>
    _packHeroBackdropUrls(meta);

Future<List<String>> kitTmdbHeroBackdropUrls(MetaItem meta) async {
  final tmdbId = meta.numericId('tmdb');
  if (tmdbId == null) return _packHeroBackdropUrls(meta);

  final mediaType = hubMetaTmdbMediaType(meta);
  final cacheKey = _hubTmdbUiCacheKey(meta);
  final cached = _hubTmdbBackdropCache[cacheKey];
  if (cached != null) return cached;

  final api = TmdbApi();
  final urls = <String>[];

  void addUrl(String path) {
    if (path.isEmpty) return;
    final u = path.startsWith('http') ? path : TmdbApi.getBackdropUrl(path);
    if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
  }

  for (final raw in _packHeroBackdropUrls(meta)) {
    addUrl(raw);
  }

  try {
    final paths = await api.getBackdrops(tmdbId, mediaType: mediaType);
    for (final p in paths) {
      addUrl(p);
    }
  } catch (_) {}

  final out = urls.take(12).toList();
  _hubTmdbBackdropCache[cacheKey] = out;
  return out;
}

Future<RichMediaDetails?> kitLoadTmdbRich(MetaItem meta) async {
  final tmdbId = meta.numericId('tmdb');
  if (tmdbId == null) return null;

  final mediaType = hubMetaTmdbMediaType(meta);
  final cacheKey = _hubTmdbUiCacheKey(meta);
  final cached = _hubTmdbRichCache[cacheKey];
  if (cached != null) return cached;

  try {
    final rich = await TmdbApi().getRichDetails(tmdbId, mediaType);
    _hubTmdbRichCache[cacheKey] = rich;
    return rich;
  } catch (_) {
    return null;
  }
}

String? hubTmdbLogoUrl(RichMediaDetails? rich) {
  if (rich == null) return null;
  final path = rich.movie.logoPath.trim();
  if (path.isEmpty) return null;
  return path.startsWith('http') ? path : TmdbApi.getImageUrl(path);
}

String? hubMetaLogoUrl(MetaItem meta) {
  final u = resolveCoverUrl(meta.logo.trim());
  return u.isEmpty ? null : u;
}
