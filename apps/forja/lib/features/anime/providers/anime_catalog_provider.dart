import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';

/// Loaded anime hub catalog rows (primary tab fetch).
class AnimeCatalogBundle {
  const AnimeCatalogBundle({
    required this.spotlight,
    required this.trending,
    required this.topAiring,
    required this.mostPopular,
    required this.mostFavorite,
    required this.topRated,
    required this.latestCompleted,
    required this.top10,
    required this.recentEpisodes,
  });

  final List<AnimeCard> spotlight;
  final List<AnimeCard> trending;
  final List<AnimeCard> topAiring;
  final List<AnimeCard> mostPopular;
  final List<AnimeCard> mostFavorite;
  final List<AnimeCard> topRated;
  final List<AnimeCard> latestCompleted;
  final List<AnimeCard> top10;
  final List<AnimeCard> recentEpisodes;

  bool get hasCatalog => [
        spotlight,
        trending,
        topAiring,
        mostPopular,
        mostFavorite,
        topRated,
        latestCompleted,
        top10,
        recentEpisodes,
      ].any((section) => section.isNotEmpty);
}

List<AnimeCard> _spotlightFromTrending(List<AnimeCard> trending) {
  final filtered = trending.where((a) {
    final s = (a.status ?? '').toUpperCase();
    return s.isEmpty || s == 'RELEASING' || s == 'FINISHED';
  }).take(10).toList();
  if (filtered.isNotEmpty) return filtered;
  return trending.take(10).toList();
}

Future<List<AnimeCard>> _safeSection(
  Future<List<AnimeCard>> future,
  String name,
) async {
  try {
    return await future;
  } catch (e) {
    debugPrint('[AnimeCatalog] $name load failed: $e');
    return const [];
  }
}

Future<AnimeCatalogBundle> _loadAnimeCatalog(AnimeService service) async {
  final trendingBase =
      _safeSection(service.getTrending(perPage: 20), 'trending');
  final spotlight = await trendingBase.then(_spotlightFromTrending);
  final trending = await trendingBase;
  final top10 = trending.take(10).toList();

  final topAiring =
      await _safeSection(service.getTopAiring(), 'top airing');
  final mostPopular =
      await _safeSection(service.getMostPopular(), 'most popular');
  final mostFavorite =
      await _safeSection(service.getMostFavorite(), 'most favorite');
  final topRated = await _safeSection(service.getTopRated(), 'top rated');
  final latestCompleted =
      await _safeSection(service.getLatestCompleted(), 'latest completed');
  final recentEpisodes =
      await _safeSection(service.getRecentEpisodes(), 'recent episodes');

  var enrichedSpotlight = spotlight;
  if (spotlight.isNotEmpty) {
    try {
      final head = spotlight.take(5).toList();
      final enrichedHead = await service.attachTmdbBackdrops(head);
      final byId = {for (final c in enrichedHead) c.id: c};
      enrichedSpotlight = [
        for (final c in spotlight) byId[c.id] ?? c,
      ];
    } catch (e) {
      debugPrint('[AnimeCatalog] spotlight TMDB enrich failed: $e');
    }
  }

  return AnimeCatalogBundle(
    spotlight: enrichedSpotlight,
    trending: trending,
    topAiring: topAiring,
    mostPopular: mostPopular,
    mostFavorite: mostFavorite,
    topRated: topRated,
    latestCompleted: latestCompleted,
    top10: top10,
    recentEpisodes: recentEpisodes,
  );
}

final animeServiceProvider = Provider<AnimeService>((ref) => AnimeService());

final animeCatalogProvider =
    FutureProvider.autoDispose<AnimeCatalogBundle>((ref) async {
  final service = ref.watch(animeServiceProvider);
  return _loadAnimeCatalog(service);
});

/// Mood / genre row (screen-scoped family).
final animeMoodCatalogProvider = FutureProvider.autoDispose
    .family<List<AnimeCard>, String>((ref, moodId) async {
  const moods = <({String id, String? genre})>[
    (id: 'shonen', genre: 'Action'),
    (id: 'romance', genre: 'Romance'),
    (id: 'comedy', genre: 'Comedy'),
    (id: 'mystery', genre: 'Mystery'),
    (id: 'thriller', genre: 'Thriller'),
    (id: 'fantasy', genre: 'Fantasy'),
    (id: 'sliceLife', genre: 'Slice of Life'),
    (id: 'scifi', genre: 'Sci-Fi'),
    (id: 'sports', genre: 'Sports'),
    (id: 'horror', genre: 'Horror'),
  ];
  final mood = moods.firstWhere(
    (m) => m.id == moodId,
    orElse: () => moods.first,
  );
  final service = ref.watch(animeServiceProvider);
  try {
    return await service.browse(
      genre: mood.genre,
      sort: 'TRENDING_DESC',
      perPage: 20,
    );
  } catch (e) {
    debugPrint('[AnimeCatalog] mood load failed: $e');
    return const [];
  }
});
