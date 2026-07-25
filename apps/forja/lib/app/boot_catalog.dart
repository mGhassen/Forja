import 'package:flutter/foundation.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:rust/rust.dart';

/// Prefetch TMDB lists into [BootCache] (intro splash + profile splash).
class BootCatalog {
  BootCatalog._();

  static Future<List<Movie>> _fetch(
    String label,
    Future<List<Movie>> Function() fetch, {
    void Function(String status)? onStatus,
  }) async {
    const attempts = 3;
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      if (i > 0) {
        onStatus?.call('Retrying $label (${i + 1}/$attempts)…');
      }
      try {
        final list = await fetch();
        if (list.isNotEmpty) return list;
        lastError = 'empty results';
      } catch (e) {
        lastError = e;
        debugPrint('[Boot] ✗ TMDB $label attempt ${i + 1}/$attempts: $e');
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 350 * (i + 1)));
      }
    }
    debugPrint(
      '[Boot] ✗ TMDB $label failed after $attempts attempts: $lastError',
    );
    return const <Movie>[];
  }

  /// Fills [BootCache] with trending / popular / top rated / now playing.
  static Future<void> prefetchTmdb({
    void Function(String status)? onStatus,
  }) async {
    debugPrint('[Init] TMDB start (trending, popular, top rated, now playing)');
    final api = TmdbApi();
    final results = await Future.wait<List<Movie>>([
      _fetch('trending', api.getTrending, onStatus: onStatus),
      _fetch('popular', api.getPopular, onStatus: onStatus),
      _fetch('top rated', api.getTopRated, onStatus: onStatus),
      _fetch('now playing', api.getNowPlaying, onStatus: onStatus),
    ]);

    var trendingList = results[0];
    final popularList = results[1];
    final topRatedList = results[2];
    final nowPlayingList = results[3];

    if (trendingList.isEmpty && popularList.isNotEmpty) {
      debugPrint(
        '[Boot] TMDB trending empty after retries - using popular for hero',
      );
      trendingList = popularList;
    }

    BootCache.setTmdb(
      trendingList: trendingList,
      popularList: popularList,
      topRatedList: topRatedList,
      nowPlayingList: nowPlayingList,
    );

    debugPrint('[Init] TMDB trending: ${trendingList.length}');
    debugPrint('[Init] TMDB popular: ${popularList.length}');
    debugPrint('[Init] TMDB top rated: ${topRatedList.length}');
    debugPrint('[Init] TMDB now playing: ${nowPlayingList.length}');
  }
}
