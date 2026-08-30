import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/hub_tmdb_enrich_cache.dart';
import 'package:rust/rust.dart';

/// AniList title → TMDB match for hub hero enrich (same scorer as [AnimeService]).
class AnimeTmdbMatch {
  AnimeTmdbMatch._();

  static bool isMovieFormat(String? badge) {
    final f = (badge ?? '').trim().toUpperCase().replaceAll(' ', '_');
    return f == 'MOVIE';
  }

  /// Strip year tags and season/part/cour suffixes before TMDB search.
  static String normalizeTitle(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;
    t = t.replaceFirst(RegExp(r'[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
    t = t.replaceAll(
      RegExp(
        r'\b(HD|FHD|UHD|4K|1080p|720p|WEB-?DL|BluRay)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    final pipe = t.indexOf('|');
    if (pipe > 0) t = t.substring(0, pipe);
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(
      RegExp(r'\s+(?:season|part|cour)\s*\d+\b.*$', caseSensitive: false),
      '',
    );
    return t.trim();
  }

  static String enrichCacheKey(String title, int? year, bool isMovie) =>
      'anime-enrich:${title.trim()}|${year ?? ''}|$isMovie';

  static RichMediaDetails? peekCachedRich({
    required String title,
    int? year,
    required bool isMovie,
  }) {
    final key = enrichCacheKey(title, year, isMovie);
    if (!HubTmdbEnrichCache.contains(key)) return null;
    return HubTmdbEnrichCache.get<RichMediaDetails>(key);
  }

  static Movie? peekCachedMovie({
    required String title,
    int? year,
    required bool isMovie,
  }) =>
      peekCachedRich(title: title, year: year, isMovie: isMovie)?.movie;

  static Future<Movie?> resolve({
    required String title,
    int? year,
    required bool isMovie,
    TmdbApi? tmdb,
  }) async {
    final q = normalizeTitle(title);
    if (q.isEmpty) return null;
    final cached = peekCachedMovie(title: title, year: year, isMovie: isMovie);
    if (cached != null && cached.id > 0) return cached;

    final api = tmdb ?? TmdbApi();
    try {
      var results = isMovie
          ? await api.searchMovies(q)
          : await api.searchTvShows(q);
      if (results.isEmpty) {
        results = isMovie
            ? await api.searchTvShows(q)
            : await api.searchMovies(q);
      }
      return _pick(results, year);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnimeTmdbMatch] TMDB search failed for "$q": $e');
      }
      return null;
    }
  }

  static Movie? _pick(List<Movie> results, int? seasonYear) {
    Movie? withBackdrop(Iterable<Movie> list) {
      for (final m in list) {
        if (m.backdropPath.isNotEmpty) return m;
      }
      return list.isEmpty ? null : list.first;
    }

    int? yearOf(Movie m) {
      if (m.releaseDate.length < 4) return null;
      return int.tryParse(m.releaseDate.substring(0, 4));
    }

    if (seasonYear != null) {
      final exact = withBackdrop(
        results.where((m) => yearOf(m) == seasonYear),
      );
      if (exact != null) return exact;
      final near = withBackdrop(
        results.where((m) {
          final y = yearOf(m);
          return y != null && (y - seasonYear).abs() <= 1;
        }),
      );
      if (near != null) return near;
    }
    return withBackdrop(results);
  }
}
