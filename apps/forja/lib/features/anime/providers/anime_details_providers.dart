import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:rust/rust.dart';

final animeServiceProvider = Provider<AnimeService>((ref) => AnimeService());

/// PREQUEL→SEQUEL spine for the open title.
final animeSeasonsProvider = FutureProvider.autoDispose
    .family<List<AnimeCard>, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getSeasons(animeId);
});

/// Rich AniList details card for one id (episodes load separately — needs card).
final animeDetailsProvider = FutureProvider.autoDispose
    .family<AnimeCard, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getDetails(animeId);
});

final animeRelationsProvider = FutureProvider.autoDispose
    .family<List<AnimeRelation>, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getRelations(animeId);
});

final animeCharactersProvider = FutureProvider.autoDispose
    .family<List<Map<String, String>>, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getCharacters(animeId);
});

final animeStaffProvider = FutureProvider.autoDispose
    .family<List<Map<String, String>>, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getStaff(animeId);
});

final animeRecommendationsProvider = FutureProvider.autoDispose
    .family<List<AnimeCard>, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getRecommendations(animeId);
});

final animeProgressProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, animeId) {
  return ref.watch(animeServiceProvider).getProgress(animeId);
});

/// TMDB logo / overview / facts (null when no match).
typedef AnimeTmdbQuery = ({String title, int? year, bool isMovie});

final animeTmdbEnrichmentProvider = FutureProvider.autoDispose
    .family<RichMediaDetails?, AnimeTmdbQuery>((ref, query) async {
  if (query.title.isEmpty) return null;
  return ref.watch(animeServiceProvider).getTmdbRichDetails(
        title: query.title,
        year: query.year,
        isMovie: query.isMovie,
      );
});
