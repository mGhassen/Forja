import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/home/because_you_watched_section.dart';
import 'package:forja/shared/catalog/bestsimilar_scraper.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Host-owned **Because you watched ___** — same BestSimilar path as old Home.
class CatalogHostBecause extends StatefulWidget {
  const CatalogHostBecause({super.key});

  @override
  State<CatalogHostBecause> createState() => _CatalogHostBecauseState();
}

class _CatalogHostBecauseState extends State<CatalogHostBecause> {
  final _api = TmdbApi();
  Map<String, dynamic>? _seed;
  Future<List<Movie>>? _future;
  List<Movie>? _pool;
  int _poolSize = 0;
  int _workGen = 0;

  @override
  void initState() {
    super.initState();
    _pickSeed(WatchHistoryService().current);
  }

  Object? _seedKey(Map<String, dynamic>? seed) {
    if (seed == null) return null;
    return seed['uniqueId'] ?? seed['tmdbId'];
  }

  String _seedMediaType(Map<String, dynamic> seed) {
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    return mediaType == 'tv' || mediaType == 'series' ? 'tv' : 'movie';
  }

  Map<String, dynamic>? _pickOpposite(
    List<Map<String, dynamic>> pool,
    Map<String, dynamic> primary,
  ) {
    final want = _seedMediaType(primary) == 'tv' ? 'movie' : 'tv';
    final candidates =
        pool.where((s) => _seedMediaType(s) == want).toList();
    if (candidates.isEmpty) return null;
    return candidates[math.Random().nextInt(candidates.length)];
  }

  List<Movie> _interleave(List<Movie> a, List<Movie> b) {
    final out = <Movie>[];
    final seen = <String>{};
    void add(Movie m) {
      final key = '${m.mediaType}:${m.id}';
      if (seen.add(key)) out.add(m);
    }

    final maxLen = math.max(a.length, b.length);
    for (var i = 0; i < maxLen; i++) {
      if (i < a.length) add(a[i]);
      if (i < b.length) add(b[i]);
    }
    return out;
  }

  bool _pickSeed(List<Map<String, dynamic>> history) {
    final pool = inProgressPoolByShow(history);
    if (pool.isEmpty) return false;

    var candidates = pool;
    final currentKey = _seedKey(_seed);
    if (currentKey != null && pool.length > 1) {
      final others =
          pool.where((s) => _seedKey(s) != currentKey).toList();
      if (others.isNotEmpty) candidates = others;
    }

    final seed = candidates[math.Random().nextInt(candidates.length)];
    final secondary = _pickOpposite(pool, seed);
    final workGen = ++_workGen;
    setState(() {
      _seed = seed;
      _pool = null;
      _poolSize = pool.length;
      _future = _loadMixed(seed, secondary, workGen).then((movies) {
        if (mounted && workGen == _workGen) {
          setState(() => _pool = movies);
        }
        return movies;
      });
    });
    return true;
  }

  Future<List<Movie>> _loadMixed(
    Map<String, dynamic> primary,
    Map<String, dynamic>? secondary,
    int workGen,
  ) async {
    if (secondary == null) return _loadRecs(primary, workGen);
    final results = await Future.wait([
      _loadRecs(primary, workGen),
      _loadRecs(secondary, workGen),
    ]);
    if (!mounted || workGen != _workGen) return const [];
    return _interleave(results[0], results[1]);
  }

  Future<List<Movie>> _loadRecs(
    Map<String, dynamic> seed,
    int workGen,
  ) async {
    final title = (seed['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return const [];
    final mediaType = (seed['mediaType'] as String?) ??
        (seed['season'] != null ? 'tv' : 'movie');
    final isTv = mediaType == 'tv' || mediaType == 'series';
    final wantType = isTv ? 'tv' : 'movie';

    try {
      final hits = await BestSimilarScraper.autocomplete(title);
      if (!mounted || workGen != _workGen) return const [];
      if (hits.isEmpty) return const [];

      final lowerTitle = title.toLowerCase();
      BSAutocompleteHit? hit;
      for (final h in hits) {
        if (h.isTv == isTv && h.title.toLowerCase() == lowerTitle) {
          hit = h;
          break;
        }
      }
      hit ??= hits.firstWhere(
        (h) => h.title.toLowerCase() == lowerTitle,
        orElse: () => hits.first,
      );

      final details =
          await BestSimilarScraper.fetchDetails(id: hit.id, slug: hit.slug);
      if (!mounted || workGen != _workGen) return const [];
      if (details == null || details.similar.isEmpty) return const [];

      final lookups = details.similar.map((it) async {
        if (workGen != _workGen) return null;
        try {
          final searchHits = await _api.searchMulti(it.title);
          if (workGen != _workGen) return null;
          if (searchHits.isEmpty) return null;
          Movie? best;
          var bestScore = -1;
          for (final h in searchHits) {
            var s = 0;
            final ht = h.title.toLowerCase();
            final it2 = it.title.toLowerCase();
            if (ht == it2) {
              s += 5;
            } else if (ht.startsWith(it2) || it2.startsWith(ht)) {
              s += 2;
            }
            if (h.mediaType == wantType) s += 3;
            if (it.year != null && h.releaseDate.length >= 4) {
              final hy = int.tryParse(h.releaseDate.substring(0, 4));
              if (hy == it.year) {
                s += 4;
              } else if (hy != null && (hy - it.year!).abs() <= 1) {
                s += 1;
              }
            }
            if (h.posterPath.isNotEmpty) s += 1;
            if (s > bestScore) {
              bestScore = s;
              best = h;
            }
          }
          if (best == null || bestScore < 2 || best.posterPath.isEmpty) {
            return null;
          }
          return MapEntry(it.similarityPercent ?? -1, best);
        } catch (_) {
          return null;
        }
      });
      final resolved = await Future.wait(lookups);
      if (!mounted || workGen != _workGen) return const [];

      final ranked = resolved.whereType<MapEntry<int, Movie>>().toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      final out = <Movie>[];
      final seen = <String>{};
      for (final e in ranked) {
        final key = '${e.value.mediaType}:${e.value.id}';
        if (!seen.add(key)) continue;
        out.add(e.value);
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('[CatalogHostBecause] failed: $e');
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    final future = _future;
    if (seed == null || future == null) return const SizedBox.shrink();
    final title = (seed['title'] as String?) ?? '';
    final poster = (seed['posterPath'] as String?) ?? '';
    return HomeBecauseYouWatchedSection(
      seedTitle: title,
      seedPosterPath: poster,
      future: _pool != null ? Future<List<Movie>>.value(_pool!) : future,
      onMovieTap: (m) => AppRouter.openDetails(context, movie: m),
      onShuffle: _poolSize > 1
          ? () => _pickSeed(WatchHistoryService().current)
          : null,
    );
  }
}
