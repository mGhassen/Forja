import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/anime_hub_filters.dart';
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

  factory AnimeCatalogFutures.start(
    AnimeService service, {
    String? genre,
    String? format,
    bool excludeMovies = false,
  }) {
    final hubFiltered = format != null ||
        excludeMovies ||
        (genre != null && genre.isNotEmpty);

    // Under Films/Series/Categories, TRENDING_DESC ≈ SCORE_DESC for small
    // pools — skip Trending (UI hides it) and drive hero/top10 from Top Rated.
    final topRated = _safeSection(
      service.getTopRated(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'top rated',
    );
    final trending = hubFiltered
        ? Future<List<AnimeCard>>.value(const [])
        : _safeSection(
            service.getTrending(
              perPage: 20,
              genre: genre,
              format: format,
              excludeMovies: excludeMovies,
            ),
            'trending',
          );

    final topAiring = _safeSection(
      service.getTopAiring(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'top airing',
    );
    final mostPopular = _safeSection(
      service.getMostPopular(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'most popular',
    );
    final mostFavorite = _safeSection(
      service.getMostFavorite(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'most favorite',
    );
    final latestCompleted = _safeSection(
      service.getLatestCompleted(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'latest completed',
    );
    final recentEpisodes = _safeSection(
      service.getRecentEpisodes(
        genre: genre,
        format: format,
        excludeMovies: excludeMovies,
      ),
      'recent episodes',
    );

    final heroSource = hubFiltered ? topRated : trending;

    return AnimeCatalogFutures._(
      trending: trending,
      spotlight: heroSource.then(spotlightFromTrending),
      top10: heroSource.then((t) => t.take(10).toList()),
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
/// Rebuilds when Anime top-menu Films / Series / Categories change.
final animeCatalogFuturesProvider =
    Provider.autoDispose<AnimeCatalogFutures>((ref) {
  ref.watch(shellAnimeCategoryProvider);
  ref.watch(shellAnimeGenreIdProvider);
  final filters = animeHubListFilters();
  final service = ref.watch(animeServiceProvider);
  return AnimeCatalogFutures.start(
    service,
    genre: filters.genre,
    format: filters.format,
    excludeMovies: filters.excludeMovies,
  );
});

/// Mood / genre row — loads in parallel with hub rails.
final animeMoodCatalogProvider = FutureProvider.autoDispose
    .family<List<AnimeCard>, String>((ref, moodId) async {
  ref.watch(shellAnimeCategoryProvider);
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
  final hub = animeHubListFilters();
  // Mood picks its own genre; still honor Films / Series from the top menu.
  final service = ref.watch(animeServiceProvider);
  try {
    return await service.browse(
      genre: mood.genre,
      sort: 'TRENDING_DESC',
      perPage: 20,
      format: hub.format,
      excludeMovies: hub.excludeMovies,
    );
  } catch (e) {
    debugPrint('[AnimeCatalog] mood load failed: $e');
    return const [];
  }
});
