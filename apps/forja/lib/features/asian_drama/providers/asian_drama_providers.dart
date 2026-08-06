import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_tmdb_match.dart';
import 'package:rust/rust.dart';

final kissKhServiceProvider = Provider<KissKhService>((ref) => KissKhService());

final tmdbApiProvider = Provider<TmdbApi>((ref) => TmdbApi());

/// Primary KissKH hub feed load.
final asianDramaFeedProvider =
    FutureProvider.autoDispose<KdramaHomeFeed>((ref) async {
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
});

/// TMDB rich details for a KissKH title (null when no confident match).
final asianDramaTmdbEnrichmentProvider = FutureProvider.autoDispose
    .family<RichMediaDetails?, AsianDramaTmdbQuery>((ref, query) async {
  final tmdb = ref.watch(tmdbApiProvider);
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
  return tmdb.getRichDetails(match.id, mediaType);
});
