import 'package:flutter/material.dart';
import 'package:forja/features/anime/anime_details_screen.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/arabic/arabic_details_screen.dart';
import 'package:forja/features/asian_drama/asian_drama_details_screen.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
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
/// Dispatches only on pack-declared [CatalogOpen.surface] (host feature routes).
/// Never branches on pack/scraper id keys. Re-entry for the same plugin+id is
/// ignored until the route pops.
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
          final id = open.idInt;
          if (id == null) return;
          await openAnimeDetails(
            context,
            AnimeCard(
              id: id,
              titleRomaji: item.name,
              titleEnglish: item.name,
              titleNative: '',
              coverExtraLarge: item.poster.isEmpty ? null : item.poster,
              bannerImage: item.background.isEmpty ? null : item.background,
              description: item.description.isEmpty ? null : item.description,
              averageScore: item.rating == null
                  ? null
                  : (item.rating! * 10).round(),
              genres: item.genres,
              tmdbId: item.numericId('tmdb'),
              idMal: int.tryParse(open.extraString('mal') ?? ''),
            ),
          );
          return;
        case 'drama':
          final id = open.idInt;
          if (id == null) return;
          await openAsianDramaDetails(
            context,
            KdramaCard(
              id: id,
              title: item.name,
              cover: item.poster,
              year: item.releaseInfo.isEmpty ? null : item.releaseInfo,
              tmdbId: item.numericId('tmdb'),
              description: item.description,
            ),
          );
          return;
        case 'arabic':
          await openArabicDetails(
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
