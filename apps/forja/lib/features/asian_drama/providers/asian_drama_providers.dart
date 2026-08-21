import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:rust/rust.dart';

final kissKhServiceProvider = Provider<KissKhService>((ref) => KissKhService());

final tmdbApiProvider = Provider<TmdbApi>((ref) => TmdbApi());

/// Primary KissKH hub feed load.
final asianDramaFeedProvider =
    FutureProvider.autoDispose<KdramaHomeFeed>((ref) async {
  await KissKhService.ensureActiveMirrorFromSettings();
  final service = ref.watch(kissKhServiceProvider);
  return service.getHome();
});

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

/// Args for TMDB enrichment keyed by KissKH identity fields.
typedef AsianDramaTmdbQuery = ({
  String title,
  String? year,
  String? kissKhType,
  int? tmdbId,
});

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

/// TMDB rich details (+ season stills for TV) for a KissKH title.
final asianDramaTmdbEnrichmentProvider = FutureProvider.autoDispose
    .family<AsianDramaTmdbEnrichment?, AsianDramaTmdbQuery>((ref, query) async {
  final tmdb = ref.watch(tmdbApiProvider);
  final kissKhTmdbId = query.tmdbId;
  if (kissKhTmdbId != null && kissKhTmdbId > 0) {
    final preferMovie = KissKhTmdbMatch.preferMovie(query.kissKhType);
    final primary = preferMovie ? 'movie' : 'tv';
    final secondary = preferMovie ? 'tv' : 'movie';
    final direct = await _enrichByTmdbId(tmdb, kissKhTmdbId, primary) ??
        await _enrichByTmdbId(tmdb, kissKhTmdbId, secondary);
    if (direct != null) {
      if (kDebugMode) {
        debugPrint(
          '[AsianDrama] TMDB from KissKH tmdbID=$kissKhTmdbId '
          'type=${direct.rich.movie.mediaType}',
        );
      }
      return direct;
    }
  }
  final match = await KissKhTmdbMatch.resolve(
    title: query.title,
    year: query.year,
    kissKhType: query.kissKhType,
    tmdb: tmdb,
  );
  if (match == null) return null;
  final mediaType =
      match.mediaType == 'movie' || match.mediaType == 'tv'
          ? match.mediaType
          : KissKhTmdbMatch.preferMovie(query.kissKhType)
              ? 'movie'
              : 'tv';
  return _enrichByTmdbId(tmdb, match.id, mediaType);
});

Future<AsianDramaTmdbEnrichment?> _enrichByTmdbId(
  TmdbApi tmdb,
  int id,
  String mediaType,
) async {
  try {
    final rich = await tmdb.getRichDetails(id, mediaType);
    if (mediaType != 'tv') {
      return AsianDramaTmdbEnrichment(rich: rich);
    }
    final season = await _loadSeasonExtras(tmdb, id);
    return AsianDramaTmdbEnrichment(
      rich: rich,
      episodeStills: season.stills,
      episodeMeta: season.meta,
    );
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
