import 'package:rust/rust.dart';

/// Idle / contextual recommendation titles for hub host search helpers column.
class HostSearchHelpers {
  HostSearchHelpers._();

  /// Large title pool for empty-state helpers (UI takes ≤16 after recent).
  static Future<List<String>> trendingTitles({TmdbApi? api}) async {
    final tmdb = api ?? TmdbApi();
    try {
      final lists = await Future.wait([
        tmdb.getTrending(),
        tmdb.getTrendingTv(),
        tmdb.getPopular(),
        tmdb.getPopularTv(),
        tmdb.getNowPlaying(),
        tmdb.getOnTheAir(),
        tmdb.getTopRated(),
      ]);

      final queues = [
        for (final list in lists) List<Movie>.from(list),
      ];
      final titles = <String>[];
      final seen = <String>{};
      const poolCap = 64;
      var madeProgress = true;
      while (madeProgress && titles.length < poolCap) {
        madeProgress = false;
        for (final queue in queues) {
          while (queue.isNotEmpty) {
            final item = queue.removeAt(0);
            final title = item.title.trim();
            if (title.isEmpty) continue;
            if (!seen.add(title.toLowerCase())) continue;
            titles.add(title);
            madeProgress = true;
            break;
          }
          if (titles.length >= poolCap) break;
        }
      }
      return titles;
    } catch (_) {
      return const [];
    }
  }

  /// Titles related to [seed], never overlapping [exclude] result cards.
  static Future<List<String>> contextualTitles(
    Movie seed, {
    Set<String> exclude = const {},
    TmdbApi? api,
  }) async {
    final tmdb = api ?? TmdbApi();
    try {
      final contextual = await tmdb.contextualSearchTitles(
        seed,
        exclude: exclude,
      );
      if (contextual.isNotEmpty) return contextual;
    } catch (_) {}
    return trendingTitles(api: tmdb);
  }
}
