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

Future<void> _openTmdb(BuildContext context, CatalogMetaItem item, String id) async {
  final tmdbId = int.tryParse(id) ?? item.numericId('tmdb');
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

/// Open details from hub meta already on the shell (rail / hero / search).
///
/// Hub surfaces use pack-driven [HubDetailsScreen]. Only `tmdb` opens the TMDB
/// feature details route. Never branches on pack/scraper id keys.
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
      switch (open.surface) {
        case 'anime':
        case 'drama':
        case 'arabic':
          await openHubDetails(
            context,
            pluginId: pluginId,
            item: item,
          );
          return;
        case 'tmdb':
          await _openTmdb(context, item, open.id);
          return;
      }
    }

    // Host-only fallback: movie/tv + tmdb id scheme (not a pack name).
    if (item.type == 'movie' || item.type == 'tv') {
      final tmdbId = item.numericId('tmdb');
      if (tmdbId == null) return;
      await _openTmdb(context, item, tmdbId.toString());
    }
  } finally {
    _catalogOpenInFlight.remove(key);
  }
}
