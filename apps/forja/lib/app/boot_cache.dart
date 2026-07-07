import 'package:api/api/tmdb_api.dart';
import 'package:api/models/movie.dart';
import 'package:flutter/foundation.dart';

/// TMDB data prefetched during / after splash for fast first paint.
class BootCache {
  BootCache._();

  static List<Movie>? trending;
  static List<Movie>? popular;
  static List<Movie>? topRated;
  static List<Movie>? nowPlaying;

  static List<Map<String, dynamic>>? movieGenres;
  static List<Map<String, dynamic>>? tvGenres;
  static List<Movie>? discoverMoviesPage1;

  static void setTmdb({
    required List<Movie> trendingList,
    required List<Movie> popularList,
    required List<Movie> topRatedList,
    required List<Movie> nowPlayingList,
  }) {
    trending = trendingList;
    popular = popularList;
    topRated = topRatedList;
    nowPlaying = nowPlayingList;
  }

  /// Warms Discover's default Movies page-1 + genre lists after splash.
  static Future<void> prefetchDiscover() async {
    if (movieGenres != null &&
        tvGenres != null &&
        discoverMoviesPage1 != null) {
      return;
    }

    final api = TmdbApi();
    try {
      final results = await Future.wait([
        movieGenres != null
            ? Future.value(movieGenres!)
            : api.getMovieGenres(),
        tvGenres != null ? Future.value(tvGenres!) : api.getTvGenres(),
        discoverMoviesPage1 != null
            ? Future.value(discoverMoviesPage1!)
            : api.discoverMovies(page: 1),
      ]);
      movieGenres = results[0] as List<Map<String, dynamic>>;
      tvGenres = results[1] as List<Map<String, dynamic>>;
      discoverMoviesPage1 = results[2] as List<Movie>;
      if (kDebugMode) {
        debugPrint(
          '[BootCache] Discover prefetch OK '
          '(${discoverMoviesPage1!.length} movies)',
        );
      }
    } catch (e) {
      debugPrint('[BootCache] Discover prefetch failed: $e');
    }
  }

  static void clear() {
    trending = null;
    popular = null;
    topRated = null;
    nowPlaying = null;
    movieGenres = null;
    tvGenres = null;
    discoverMoviesPage1 = null;
  }
}
