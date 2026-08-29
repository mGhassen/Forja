import 'package:flutter/material.dart';
import 'package:forja/features/anime/anime_details_screen.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/asian_drama/asian_drama_details_screen.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// TMDB details expect the relative `/abc.jpg` path, not the CDN URL a
/// catalog plugin ships for cards.
String catalogTmdbImagePath(String url) {
  if (url.isEmpty) return '';
  final m = RegExp(r'image\.tmdb\.org/t/p/[^/]+(/.+)$').firstMatch(url);
  return m?.group(1) ?? url;
}

Future<CatalogMetaItem> enrichCatalogMeta({
  required String pluginId,
  required CatalogMetaItem item,
}) async {
  final envelope = await CatalogRuntime.instance.run(
    pluginId: pluginId,
    action: 'details',
    params: {'id': item.id},
  );
  if (!envelope.ok) return item;
  final raw = envelope.data?['meta'];
  if (raw is! Map) return item;
  return CatalogMetaItem.fromJson(Map<String, dynamic>.from(raw));
}

Future<void> openCatalogMetaItem(
  BuildContext context, {
  required String pluginId,
  required CatalogMetaItem item,
  bool enrich = true,
}) async {
  final enriched =
      enrich ? await enrichCatalogMeta(pluginId: pluginId, item: item) : item;
  if (!context.mounted) return;
  switch (enriched.type) {
    case 'anime':
      final anilistId = enriched.numericId('anilist');
      if (anilistId == null) return;
      await openAnimeDetails(
        context,
        AnimeCard(
          id: anilistId,
          titleRomaji: enriched.name,
          titleEnglish: enriched.name,
          titleNative: '',
          coverExtraLarge: enriched.poster.isEmpty ? null : enriched.poster,
          bannerImage:
              enriched.background.isEmpty ? null : enriched.background,
          description:
              enriched.description.isEmpty ? null : enriched.description,
          averageScore: enriched.rating == null
              ? null
              : (enriched.rating! * 10).round(),
          genres: enriched.genres,
          tmdbId: enriched.numericId('tmdb'),
          idMal: enriched.numericId('mal'),
        ),
      );
      return;
    case 'drama':
      final kisskhId = enriched.numericId('kisskh');
      if (kisskhId == null) return;
      await openAsianDramaDetails(
        context,
        KdramaCard(
          id: kisskhId,
          title: enriched.name,
          cover: enriched.poster,
          year: enriched.releaseInfo.isEmpty ? null : enriched.releaseInfo,
          tmdbId: enriched.numericId('tmdb'),
          description: enriched.description,
        ),
      );
      return;
    default:
      final tmdbId = enriched.numericId('tmdb');
      if (tmdbId == null) return;
      await AppRouter.openDetails(
        context,
        movie: Movie(
          id: tmdbId,
          title: enriched.name,
          posterPath: catalogTmdbImagePath(enriched.poster),
          backdropPath: catalogTmdbImagePath(enriched.background),
          voteAverage: enriched.rating ?? 0,
          releaseDate: enriched.releaseInfo,
          overview: enriched.description,
          mediaType: enriched.type == 'tv' ? 'tv' : 'movie',
        ),
      );
  }
}
