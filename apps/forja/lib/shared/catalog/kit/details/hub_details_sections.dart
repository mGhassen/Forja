import 'package:forja/shared/catalog/hub_cover_urls.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/rows/hub_catalog_section.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_legacy_movie_meta.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/media_details/media_details_recommendations_section.dart';
import 'package:forja/shared/widgets/media_details_cast_section.dart';
import 'package:forja/shared/widgets/media_details_trailers_section.dart';
import 'package:rust/rust.dart';

class HubDetailRailSection {
  const HubDetailRailSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<CatalogMetaItem> items;
}

List<HubDetailRailSection> parseHubDetailRails(Map<String, dynamic>? data) {
  final rails = data?['rails'];
  if (rails is! Map) return const [];

  final out = <HubDetailRailSection>[];
  for (final entry in rails.entries) {
    final id = entry.key.toString();
    final v = entry.value;
    var title = _defaultRailTitle(id);
    List<CatalogMetaItem> items = const [];

    if (v is List) {
      items = _itemsFromJsonList(v);
    } else if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final custom = (m['title'] ?? '').toString().trim();
      if (custom.isNotEmpty) title = custom;
      items = _itemsFromJsonList(m['items']);
    }

    if (items.isNotEmpty) {
      out.add(HubDetailRailSection(id: id, title: title, items: items));
    }
  }
  return out;
}

List<CatalogMetaItem> _itemsFromJsonList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final it in raw)
      if (it is Map)
        CatalogMetaItem.fromJson(Map<String, dynamic>.from(it)),
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

List<Widget> buildHubDetailRailSections({
  required BuildContext context,
  required String pluginId,
  required List<HubDetailRailSection> rails,
  required bool tvFocus,
  VoidCallback? firstMetaFocusUp,
}) {
  if (rails.isEmpty) return const [];

  var order = 0;
  final sections = <Widget>[];
  for (final rail in rails) {
    final rowOrder = order++;
    sections.add(
      HubCatalogSection<CatalogMetaItem>(
        title: rail.title,
        items: rail.items,
        embedded: true,
        compactTop: true,
        tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
        tvRowId: rail.id,
        tvRowOrder: rowOrder,
        tvFocusUp: sections.isEmpty ? firstMetaFocusUp : null,
        cardBuilder: (ctx, item, index) => HubPosterCard(
          imageUrl: item.poster,
          title: item.name,
          subtitle: hubPosterCardSubtitle(item),
          rating: item.rating,
          badge: item.badge,
          onTap: () => openCatalogMetaItem(
            ctx,
            pluginId: pluginId,
            item: item,
          ),
          tvTabId: tvFocus ? MediaDetailsTv.tabId : null,
          tvRowId: rail.id,
        ),
      ),
    );
  }
  return sections;
}

List<Widget> buildHubTmdbDetailSections({
  required BuildContext context,
  required String pluginId,
  required RichMediaDetails? rich,
  required bool tvFocus,
  VoidCallback? firstMetaFocusUp,
}) {
  if (rich == null) return const [];

  final cast = rich.extras.cast;
  final crew = _crewAsCast(rich.extras.crew);
  final trailers = rich.extras.trailers;
  final recommendations = rich.extras.recommendations;

  final showCast = cast.isNotEmpty;
  final showCrew = crew.isNotEmpty;
  final showTrailers = trailers.isNotEmpty;
  final showRecs = recommendations.isNotEmpty;
  if (!showCast && !showCrew && !showTrailers && !showRecs) {
    return const [];
  }

  var order = 0;
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
        movies: recommendations,
        onMovieTap: (movie) => openCatalogMetaItem(
          context,
          pluginId: pluginId,
          item: catalogMetaFromMovie(movie),
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

String _hubTmdbUiCacheKey(CatalogMetaItem meta) {
  final tmdbId = meta.numericId('tmdb');
  if (tmdbId == null) return meta.id;
  final mediaType = hubMetaTmdbMediaType(meta);
  return '$tmdbId|$mediaType';
}

String _hubHeroCacheKey(CatalogMetaItem meta) =>
    '${meta.id}|${meta.background}|${meta.bannerImage}';

List<String> _packHeroBackdropUrls(CatalogMetaItem meta) {
  final cacheKey = _hubHeroCacheKey(meta);
  final cached = _hubHeroBackdropCache[cacheKey];
  if (cached != null) return cached;

  final urls = <String>[];
  void addUrl(String raw) {
    final u = resolveHubCoverUrl(raw.trim());
    if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
  }

  addUrl(meta.background);
  addUrl(meta.bannerImage);
  addUrl(meta.poster);

  final out = urls.take(12).toList();
  _hubHeroBackdropCache[cacheKey] = out;
  return out;
}

/// Immediate pack / enrich URLs — use before [hubTmdbHeroBackdropUrls] resolves.
List<String> hubHeroBackdropUrls(CatalogMetaItem meta) =>
    _packHeroBackdropUrls(meta);

Future<List<String>> hubTmdbHeroBackdropUrls(CatalogMetaItem meta) async {
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

Future<RichMediaDetails?> hubLoadTmdbRich(CatalogMetaItem meta) async {
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

String? hubMetaLogoUrl(CatalogMetaItem meta) => null;
