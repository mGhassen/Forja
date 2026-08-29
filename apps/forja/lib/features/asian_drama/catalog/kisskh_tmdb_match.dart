import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/hub_tmdb_enrich_cache.dart';
import 'package:rust/rust.dart';

/// Best-effort KissKH title → TMDB [Movie] (keeps `id` + `mediaType`).
class KissKhTmdbMatch {
  KissKhTmdbMatch._();

  /// Prefer movie when KissKH type is Film / Hollywood; otherwise prefer TV.
  static bool preferMovie(String? kissKhType) {
    switch ((kissKhType ?? '').toLowerCase()) {
      case 'movie':
      case 'hollywood':
        return true;
      default:
        return false;
    }
  }

  /// Hub hero badge / label → KissKH type wire for [resolve].
  static String? kissKhTypeFromBadge(String? badge) {
    switch ((badge ?? '').trim().toUpperCase()) {
      case 'FILM':
      case 'MOVIE':
      case 'HOLLYWOOD':
        return 'movie';
      case 'SERIES':
      case 'TV':
      case 'TVSERIES':
        return 'tvseries';
      case 'ANIME':
        return 'anime';
      default:
        return null;
    }
  }

  /// Reuse details TMDB enrich on the browse hero (same KissKH id cache).
  static Movie? peekCachedHeroMovie(int kisskhId) {
    final key = 'asian-enrich:kisskh:$kisskhId';
    if (!HubTmdbEnrichCache.contains(key)) return null;
    final cached = HubTmdbEnrichCache.get<Object?>(key);
    if (cached == null) return null;
    try {
      final movie = (cached as dynamic).rich.movie;
      if (movie is Movie && movie.id > 0) return movie;
    } catch (_) {}
    return null;
  }

  /// Strip KissKH noise so TMDB search/scoring lines up with clean titles.
  @visibleForTesting
  static String normalizeTitle(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;
    // Trailing year: "Queen of Tears (2024)" / "[2024]"
    t = t.replaceFirst(RegExp(r'[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
    // Quality / mirror tags
    t = t.replaceAll(
      RegExp(
        r'\b(HD|FHD|UHD|4K|1080p|720p|WEB-?DL|BluRay)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    // Pipe / dash suffixes: "Title | KissKH" / "Title - Extra"
    final pipe = t.indexOf('|');
    if (pipe > 0) t = t.substring(0, pipe);
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Returns the best TMDB hit, or null when confidence is too low.
  static Future<Movie?> resolve({
    required String title,
    String? year,
    String? kissKhType,
    TmdbApi? tmdb,
    int minScore = 2,
  }) async {
    final q = normalizeTitle(title);
    if (q.isEmpty) return null;
    final wantMovie = preferMovie(kissKhType);
    final cacheKey =
        'kisskh-match:${q.toLowerCase()}|${year ?? ''}|$wantMovie|$minScore';
    if (_matchCache.containsKey(cacheKey)) {
      return _matchCache[cacheKey];
    }
    final api = tmdb ?? TmdbApi();
    try {
      final hits = await api.searchMulti(q);
      if (hits.isEmpty) {
        _matchCache[cacheKey] = null;
        return null;
      }
      Movie? best;
      var bestScore = -1;
      final wantYear = int.tryParse((year ?? '').trim()) ??
          int.tryParse(
            RegExp(r'\b(19|20)\d{2}\b').firstMatch(title)?.group(0) ?? '',
          );
      for (final h in hits) {
        var s = 0;
        final ht = normalizeTitle(h.title).toLowerCase();
        final qt = q.toLowerCase();
        if (ht == qt) {
          s += 5;
        } else if (ht.startsWith(qt) || qt.startsWith(ht)) {
          s += 2;
        } else if (ht.contains(qt) || qt.contains(ht)) {
          s += 1;
        } else {
          continue;
        }
        if (wantMovie) {
          if (h.mediaType == 'movie') {
            s += 3;
          } else if (h.mediaType == 'tv') {
            s += 1;
          }
        } else {
          if (h.mediaType == 'tv') {
            s += 3;
          } else if (h.mediaType == 'movie') {
            s += 1;
          }
        }
        if (wantYear != null && h.releaseDate.length >= 4) {
          final hy = int.tryParse(h.releaseDate.substring(0, 4));
          if (hy == wantYear) {
            s += 4;
          } else if (hy != null && (hy - wantYear).abs() <= 1) {
            s += 1;
          }
        }
        if (s > bestScore) {
          bestScore = s;
          best = h;
        }
      }
      if (best == null || bestScore < minScore) {
        _matchCache[cacheKey] = null;
        return null;
      }
      if (kDebugMode) {
        debugPrint(
          '[AsianDrama] TMDB match '
          '"$q" → id=${best.id} ${best.mediaType} score=$bestScore',
        );
      }
      if (_matchCache.length >= _matchCacheMax) _matchCache.clear();
      _matchCache[cacheKey] = best;
      return best;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AsianDrama] TMDB search failed for "$q": $e');
      }
      return null;
    }
  }

  static final Map<String, Movie?> _matchCache = {};
  static const _matchCacheMax = 256;
}
