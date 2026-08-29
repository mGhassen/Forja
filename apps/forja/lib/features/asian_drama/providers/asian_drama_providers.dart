import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:forja/shared/catalog/hub_tmdb_enrich_cache.dart';
import 'package:rust/rust.dart';

final kissKhServiceProvider = Provider<KissKhService>((ref) => KissKhService());

final tmdbApiProvider = Provider<TmdbApi>((ref) => TmdbApi());

/// TMDB trending/popular Asian TV for the hub **Popular** row (not KissKH).
final asianDramaPopularTodayProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final tmdb = ref.watch(tmdbApiProvider);
  return tmdb.getPopularAsianTvToday(limit: 20);
});

/// Progressive KissKH hub feed — hero lists first, rails fill in after.
final asianDramaFeedProvider = AsyncNotifierProvider.autoDispose<
    AsianDramaFeedNotifier, KdramaHomeFeed>(AsianDramaFeedNotifier.new);

class AsianDramaFeedNotifier
    extends AutoDisposeAsyncNotifier<KdramaHomeFeed> {
  @override
  Future<KdramaHomeFeed> build() async {
    await KissKhService.ensureActiveMirrorFromSettings();
    final service = ref.watch(kissKhServiceProvider);
    final hero = await service.getHomeHero();
    unawaited(_fillRails(service, hero));
    return hero;
  }

  Future<void> _fillRails(KissKhService service, KdramaHomeFeed hero) async {
    try {
      final rails = await service.getHomeRails();
      state = AsyncData(hero.withRails(rails));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AsianDrama] home rails load failed: $e');
      }
    }
  }
}

class AsianDramaDetailsBundle {
  const AsianDramaDetailsBundle({
    required this.details,
    required this.progress,
  });

  final KdramaDetails details;
  final Map<String, dynamic>? progress;
}

/// KissKH details + watch progress for one drama id.
final asianDramaDetailsProvider = FutureProvider.autoDispose
    .family<AsianDramaDetailsBundle, int>((ref, dramaId) async {
  final service = ref.watch(kissKhServiceProvider);
  final results = await Future.wait([
    service.getDetails(dramaId),
    service.getProgress(dramaId),
  ]);
  return AsianDramaDetailsBundle(
    details: results[0] as KdramaDetails,
    progress: results[1] as Map<String, dynamic>?,
  );
});

/// Args for TMDB enrichment. Equality is **KissKH id only** so list→details
/// filling year/type does not restart the FutureProvider (and rematch).
class AsianDramaTmdbQuery {
  const AsianDramaTmdbQuery({
    required this.kisskhId,
    required this.title,
    this.year,
    this.kissKhType,
    this.tmdbId,
  });

  final int kisskhId;
  final String title;
  final String? year;
  final String? kissKhType;
  final int? tmdbId;

  @override
  bool operator ==(Object other) =>
      other is AsianDramaTmdbQuery && other.kisskhId == kisskhId;

  @override
  int get hashCode => kisskhId.hashCode;
}

/// TMDB metadata for Asian Drama details (null when no confident match).
class AsianDramaTmdbEnrichment {
  const AsianDramaTmdbEnrichment({
    required this.rich,
    this.episodeStills = const {},
    this.episodeMeta = const {},
  });

  final RichMediaDetails rich;

  /// TMDB episode_number → still_path (`/abc.jpg`).
  final Map<int, String> episodeStills;

  /// TMDB episode_number → name / overview / runtime / air_date.
  final Map<int, Map<String, dynamic>> episodeMeta;

  List<String> get imagePaths => rich.movie.screenshots;
}

/// Sync peek — details reopen must not wait on Riverpod for a cache hit.
AsianDramaTmdbEnrichment? peekAsianDramaTmdbEnrichment(AsianDramaTmdbQuery query) {
  final qKey = _asianEnrichQueryKey(query);
  if (HubTmdbEnrichCache.contains(qKey)) {
    return HubTmdbEnrichCache.get<AsianDramaTmdbEnrichment>(qKey);
  }
  final tmdbId = query.tmdbId;
  if (tmdbId != null && tmdbId > 0) {
    for (final type in [
      KissKhTmdbMatch.preferMovie(query.kissKhType) ? 'movie' : 'tv',
      KissKhTmdbMatch.preferMovie(query.kissKhType) ? 'tv' : 'movie',
    ]) {
      final idKey = _asianEnrichIdKey(tmdbId, type);
      if (HubTmdbEnrichCache.contains(idKey)) {
        return HubTmdbEnrichCache.get<AsianDramaTmdbEnrichment>(idKey);
      }
    }
  }
  return null;
}

/// True when this KissKH id was already enriched (including cached null / no match).
bool asianDramaTmdbEnrichCached(int kisskhId) =>
    HubTmdbEnrichCache.contains('asian-enrich:kisskh:$kisskhId');

/// TMDB rich details (+ season stills for TV) for a KissKH title.
///
/// Result is process-cached by **KissKH id** (stable across list→details and
/// type/year filling in) — `autoDispose` alone was dumping enrich on leave.
final asianDramaTmdbEnrichmentProvider = FutureProvider.autoDispose
    .family<AsianDramaTmdbEnrichment?, AsianDramaTmdbQuery>((ref, query) async {
  final cached = peekAsianDramaTmdbEnrichment(query);
  if (cached != null || HubTmdbEnrichCache.contains(_asianEnrichQueryKey(query))) {
    // Cached null (no match) also short-circuits.
    return cached;
  }

  final tmdb = ref.watch(tmdbApiProvider);
  final kissKhTmdbId = query.tmdbId;
  AsianDramaTmdbEnrichment? result;
  if (kissKhTmdbId != null && kissKhTmdbId > 0) {
    final preferMovie = KissKhTmdbMatch.preferMovie(query.kissKhType);
    final primary = preferMovie ? 'movie' : 'tv';
    final secondary = preferMovie ? 'tv' : 'movie';
    result = await _enrichByTmdbId(tmdb, kissKhTmdbId, primary) ??
        await _enrichByTmdbId(tmdb, kissKhTmdbId, secondary);
    if (result != null && kDebugMode) {
      debugPrint(
        '[AsianDrama] TMDB from KissKH tmdbID=$kissKhTmdbId '
        'type=${result.rich.movie.mediaType}',
      );
    }
  }
  if (result == null) {
    final match = await KissKhTmdbMatch.resolve(
      title: query.title,
      year: query.year,
      kissKhType: query.kissKhType,
      tmdb: tmdb,
    );
    if (match == null) {
      _putAsianEnrich(query, null);
      return null;
    }
    final mediaType =
        match.mediaType == 'movie' || match.mediaType == 'tv'
            ? match.mediaType
            : KissKhTmdbMatch.preferMovie(query.kissKhType)
                ? 'movie'
                : 'tv';
    result = await _enrichByTmdbId(tmdb, match.id, mediaType);
  }

  _putAsianEnrich(query, result);
  return result;
});

void _putAsianEnrich(AsianDramaTmdbQuery query, AsianDramaTmdbEnrichment? result) {
  HubTmdbEnrichCache.put(_asianEnrichQueryKey(query), result);
  if (result != null) {
    final m = result.rich.movie;
    final type = m.mediaType == 'movie' || m.mediaType == 'tv'
        ? m.mediaType
        : 'tv';
    HubTmdbEnrichCache.put(_asianEnrichIdKey(m.id, type), result);
  }
}

String _asianEnrichQueryKey(AsianDramaTmdbQuery q) =>
    'asian-enrich:kisskh:${q.kisskhId}';

String _asianEnrichIdKey(int id, String mediaType) =>
    'asian-enrich:id:$id:$mediaType';

Future<AsianDramaTmdbEnrichment?> _enrichByTmdbId(
  TmdbApi tmdb,
  int id,
  String mediaType,
) async {
  final idKey = _asianEnrichIdKey(id, mediaType);
  if (HubTmdbEnrichCache.contains(idKey)) {
    return HubTmdbEnrichCache.get<AsianDramaTmdbEnrichment>(idKey);
  }
  try {
    final rich = await tmdb.getRichDetails(id, mediaType);
    final AsianDramaTmdbEnrichment out;
    if (mediaType != 'tv') {
      out = AsianDramaTmdbEnrichment(rich: rich);
    } else {
      final season = await _loadSeasonExtras(tmdb, id);
      out = AsianDramaTmdbEnrichment(
        rich: rich,
        episodeStills: season.stills,
        episodeMeta: season.meta,
      );
    }
    HubTmdbEnrichCache.put(idKey, out);
    return out;
  } catch (e) {
    if (kDebugMode) {
      debugPrint(
        '[AsianDrama] TMDB rich details failed id=$id $mediaType: $e',
      );
    }
    return null;
  }
}

typedef _SeasonExtras = ({
  Map<int, String> stills,
  Map<int, Map<String, dynamic>> meta,
});

Future<_SeasonExtras> _loadSeasonExtras(TmdbApi tmdb, int tvId) async {
  try {
    final data = await tmdb.getTvSeasonDetails(tvId, 1);
    final eps = data['episodes'] as List? ?? const [];
    final stills = <int, String>{};
    final meta = <int, Map<String, dynamic>>{};
    for (final raw in eps) {
      if (raw is! Map) continue;
      final n = (raw['episode_number'] as num?)?.toInt();
      if (n == null || n <= 0) continue;
      final still = (raw['still_path'] as String?)?.trim() ?? '';
      if (still.isNotEmpty) stills[n] = still;
      final name = (raw['name'] as String?)?.trim() ?? '';
      final overview = (raw['overview'] as String?)?.trim() ?? '';
      final runtime = (raw['runtime'] as num?)?.toInt() ?? 0;
      final aired = (raw['air_date'] as String?)?.trim() ?? '';
      meta[n] = {
        if (name.isNotEmpty) 'name': name,
        if (overview.isNotEmpty) 'overview': overview,
        if (runtime > 0) 'runtime': runtime,
        if (aired.isNotEmpty) 'aired': aired,
      };
    }
    return (stills: stills, meta: meta);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[AsianDrama] TMDB season stills failed id=$tvId: $e');
    }
    return (stills: const <int, String>{}, meta: const <int, Map<String, dynamic>>{});
  }
}
