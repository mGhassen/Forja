import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_screen.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// In-flight opens keyed by `pluginId + item.id` — blocks stacked details from
/// double-tap / re-click while the first navigation is alive.
final Set<String> _catalogOpenInFlight = {};

/// TMDB details expect the relative `/abc.jpg` path, not the CDN URL a
/// catalog plugin ships for cards.
String catalogTmdbImagePath(String url) {
  if (url.isEmpty) return '';
  final m = RegExp(r'image\.tmdb\.org/t/p/[^/]+(/.+)$').firstMatch(url);
  return m?.group(1) ?? url;
}

bool catalogOpenUsesHubDetails(CatalogOpen open) =>
    !_openUsesFeatureDetailsRoute(open);

Future<void> _openFeatureDetails(
  BuildContext context,
  CatalogMetaItem item,
  String id,
) async {
  final tmdbId = int.tryParse(id);
  if (tmdbId == null) return;
  final mediaType = item.open?.extraString('mediaType') ??
      item.tmdbMediaType ??
      (item.type == 'tv' ? 'tv' : 'movie');
  await AppRouter.openDetails(
    context,
    movie: Movie(
      id: tmdbId,
      title: item.name,
      posterPath: catalogTmdbImagePath(item.poster),
      backdropPath: catalogTmdbImagePath(item.background),
      voteAverage: item.rating ?? 0,
      releaseDate: item.releaseInfo,
      overview: item.description,
      mediaType: mediaType == 'tv' ? 'tv' : 'movie',
    ),
  );
}

bool _openUsesFeatureDetailsRoute(CatalogOpen open) {
  final route = open.extraString('detailsRoute') ??
      open.extraString('featureRoute');
  if (route != null && route.isNotEmpty) return true;
  return open.effectiveExtract.resolveType == 'movie' ||
      open.effectiveExtract.resolveType == 'tv';
}

/// Open details from hub meta already on the shell (rail / hero / search).
Future<void> openCatalogMetaItem(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
}) async {
  final key = '$pluginId\x1f${item.id}';
  if (!_catalogOpenInFlight.add(key)) return;
  try {
    if (!context.mounted) return;
    final open = item.open;
    if (open != null) {
      if (_openUsesFeatureDetailsRoute(open)) {
        await _openFeatureDetails(context, item, open.id);
        return;
      }
      await openHubDetails(
        context,
        pluginId: pluginId,
        item: item,
      );
      return;
    }

    if (item.type == 'movie' || item.type == 'tv') {
      final id = item.open?.id ?? item.id.split(':').last;
      final tmdbId = int.tryParse(id);
      if (tmdbId == null) return;
      await _openFeatureDetails(context, item, tmdbId.toString());
    }
  } finally {
    _catalogOpenInFlight.remove(key);
  }
}
