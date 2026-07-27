import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// TMDB details identity — family key for meta / recommendations providers.
@immutable
class DetailsMetaKey {
  const DetailsMetaKey({required this.id, required this.mediaType});

  final int id;
  final String mediaType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailsMetaKey &&
          id == other.id &&
          mediaType == other.mediaType;

  @override
  int get hashCode => Object.hash(id, mediaType);
}

final tmdbApiProvider = Provider<TmdbApi>((ref) => TmdbApi());

/// Rich TMDB movie/TV metadata for the details screen (autoDispose per title).
final detailsMetaProvider = FutureProvider.autoDispose
    .family<RichMediaDetails, DetailsMetaKey>((ref, key) async {
  final api = ref.watch(tmdbApiProvider);
  if (key.mediaType == 'tv') {
    return api.getRichTvDetails(key.id);
  }
  return api.getRichMovieDetails(key.id);
});

/// TMDB recommendations for the open title (depends on [detailsMetaProvider]).
final detailsRecommendationsProvider = FutureProvider.autoDispose
    .family<List<Movie>, DetailsMetaKey>((ref, key) async {
  final api = ref.watch(tmdbApiProvider);
  final meta = await ref.watch(detailsMetaProvider(key).future);
  if (meta.movie.mediaType == 'tv') {
    return api.getTvRecommendations(meta.movie.id);
  }
  return api.getMovieRecommendations(meta.movie.id);
});

/// Panel source-resolve lifecycle (torrent search slice — not full Stremio/Nuvio).
enum DetailsResolveStatus { idle, loading, ready, error }

class DetailsResolveStatusNotifier
    extends AutoDisposeFamilyNotifier<DetailsResolveStatus, DetailsMetaKey> {
  @override
  DetailsResolveStatus build(DetailsMetaKey arg) => DetailsResolveStatus.idle;

  void setLoading() => state = DetailsResolveStatus.loading;

  void setReady() => state = DetailsResolveStatus.ready;

  void setError() => state = DetailsResolveStatus.error;
}

final detailsResolveStatusProvider = NotifierProvider.autoDispose
    .family<DetailsResolveStatusNotifier, DetailsResolveStatus, DetailsMetaKey>(
  DetailsResolveStatusNotifier.new,
);
