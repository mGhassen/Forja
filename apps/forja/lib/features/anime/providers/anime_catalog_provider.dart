import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';

List<AnimeCard> spotlightFromTrending(List<AnimeCard> trending) {
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

/// Live per-section futures — screen unlocks immediately; hero waits on
/// [trending] only; remaining rails start after trending settles so the
/// 3-worker AniList pool is not stolen from first paint.
class AnimeCatalogFutures {
  AnimeCatalogFutures._({
    required this.trending,
    required this.spotlight,
    required this.top10,
    required this.topAiring,
    required this.mostPopular,
    required this.mostFavorite,
    required this.topRated,
    required this.latestCompleted,
    required this.recentEpisodes,
  });

  factory AnimeCatalogFutures.start(AnimeService service) {
    final trending =
        _safeSection(service.getTrending(perPage: 20), 'trending');

    // Start remaining rails in parallel with trending so lower rows do not
    // sit empty until first paint finishes (AniList worker pool queues them).
    final topAiring = _safeSection(service.getTopAiring(), 'top airing');
    final mostPopular =
        _safeSection(service.getMostPopular(), 'most popular');
    final mostFavorite =
        _safeSection(service.getMostFavorite(), 'most favorite');
    final topRated = _safeSection(service.getTopRated(), 'top rated');
    final latestCompleted =
        _safeSection(service.getLatestCompleted(), 'latest completed');
    final recentEpisodes =
        _safeSection(service.getRecentEpisodes(), 'recent episodes');

    return AnimeCatalogFutures._(
      trending: trending,
      spotlight: trending.then(spotlightFromTrending),
      top10: trending.then((t) => t.take(10).toList()),
      topAiring: topAiring,
      mostPopular: mostPopular,
      mostFavorite: mostFavorite,
      topRated: topRated,
      latestCompleted: latestCompleted,
      recentEpisodes: recentEpisodes,
    );
  }

  final Future<List<AnimeCard>> trending;
  final Future<List<AnimeCard>> spotlight;
  final Future<List<AnimeCard>> top10;
  final Future<List<AnimeCard>> topAiring;
  final Future<List<AnimeCard>> mostPopular;
  final Future<List<AnimeCard>> mostFavorite;
  final Future<List<AnimeCard>> topRated;
  final Future<List<AnimeCard>> latestCompleted;
  final Future<List<AnimeCard>> recentEpisodes;

  /// All section lists (for settle / empty-catalog error).
  Future<List<List<AnimeCard>>> get allSections => Future.wait([
        trending,
        topAiring,
        mostPopular,
        mostFavorite,
        topRated,
        latestCompleted,
        recentEpisodes,
      ]);
}

final animeServiceProvider = Provider<AnimeService>((ref) => AnimeService());

/// Sync provider: creates in-flight futures immediately (no await gate).
final animeCatalogFuturesProvider =
    Provider.autoDispose<AnimeCatalogFutures>((ref) {
  final service = ref.watch(animeServiceProvider);
  return AnimeCatalogFutures.start(service);
});

/// Mood / genre row — loads in parallel with hub rails.
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
  // Mood row starts immediately — do not wait on hub trending.
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
