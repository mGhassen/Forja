import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/home/providers/home_feed_providers.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:rust/rust.dart';

/// Resolves TMDB entries in parallel batches of 5, dropping lookups that fail.
Future<List<Movie>> _resolveTmdbEntries(
  TmdbApi api,
  List<({int tmdbId, String type})> entries,
) async {
  final movies = <Movie>[];
  for (var i = 0; i < entries.length; i += 5) {
    final batch = entries.skip(i).take(5);
    final results = await Future.wait(
      batch.map((e) async {
        try {
          return e.type == 'tv'
              ? await api.getTvDetails(e.tmdbId)
              : await api.getMovieDetails(e.tmdbId);
        } catch (_) {
          return null;
        }
      }),
    );
    movies.addAll(results.whereType<Movie>());
  }
  return movies;
}

/// Trakt "Recommended for You" rail (movies + shows merged, TMDB-resolved).
final homeTraktRecommendationsProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final trakt = TraktService();
  if (!await trakt.isLoggedIn()) return const [];
  final movieRecs = await trakt.getRecommendations('movies');
  final showRecs = await trakt.getRecommendations('shows');
  final all = [...movieRecs, ...showRecs];
  final entries = all
      .take(20)
      .map((rec) {
        final item = rec['movie'] ?? rec['show'];
        if (item == null) return null;
        final ids = item['ids'] as Map<String, dynamic>?;
        final tmdbId = ids?['tmdb'] as int?;
        if (tmdbId == null) return null;
        final type = rec.containsKey('show') ? 'tv' : 'movie';
        return (tmdbId: tmdbId, type: type);
      })
      .whereType<({int tmdbId, String type})>()
      .toList();
  return _resolveTmdbEntries(ref.read(tmdbApiProvider), entries);
});

/// Trakt calendar shows (next 14 days) → TMDB-resolved.
final homeTraktUpcomingShowsProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final trakt = TraktService();
  if (!await trakt.isLoggedIn()) return const [];
  final api = ref.read(tmdbApiProvider);
  final shows = await trakt.getCalendarShows(days: 14);
  final movies = <Movie>[];
  for (final entry in shows.take(20)) {
    final show = entry['show'] as Map<String, dynamic>? ?? {};
    final tmdbId = (show['ids'] as Map<String, dynamic>?)?['tmdb'] as int?;
    if (tmdbId == null) continue;
    try {
      movies.add(await api.getTvDetails(tmdbId));
    } catch (_) {}
  }
  return movies;
});

/// Trakt calendar movies (next 30 days) → TMDB-resolved.
final homeTraktUpcomingMoviesProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final trakt = TraktService();
  if (!await trakt.isLoggedIn()) return const [];
  final api = ref.read(tmdbApiProvider);
  final entries = await trakt.getCalendarMovies(days: 30);
  final movies = <Movie>[];
  for (final entry in entries.take(20)) {
    final movie = entry['movie'] as Map<String, dynamic>? ?? {};
    final tmdbId = (movie['ids'] as Map<String, dynamic>?)?['tmdb'] as int?;
    if (tmdbId == null) continue;
    try {
      movies.add(await api.getMovieDetails(tmdbId));
    } catch (_) {}
  }
  return movies;
});
