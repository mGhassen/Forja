import 'package:forja/shared/host/search/host_search_engine.dart';
import 'package:forja/shared/host/search/host_search_helpers.dart';
import 'package:forja/shared/host/search/host_search_models.dart';
import 'package:forja/shared/shell/kit_search_page.dart';
import 'package:rust/rust.dart';

/// Map host engine sections → flat kit search cards (TMDB first, then addons).
List<KitSearchResult> kitResultsFromHostSearch(HostSearchState state) {
  final out = <KitSearchResult>[];
  final seen = <String>{};
  for (final section in state.sections) {
    for (final raw in section.results) {
      if (raw is Movie) {
        final key = 'tmdb:${raw.mediaType}:${raw.id}';
        if (!seen.add(key)) continue;
        out.add(_movieResult(raw));
        continue;
      }
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final type = map['type']?.toString() ?? 'movie';
        final key = 'stremio:$type:$id';
        if (!seen.add(key)) continue;
        out.add(_stremioResult(map, sectionTitle: section.title));
      }
    }
  }
  return out;
}

KitSearchResult _movieResult(Movie movie) {
  final media = movie.mediaType == 'tv' ? 'TV' : 'FILM';
  final year = movie.releaseDate.length >= 4
      ? movie.releaseDate.substring(0, 4)
      : '';
  final poster = movie.posterPath.isNotEmpty
      ? TmdbApi.getImageUrl(movie.posterPath)
      : '';
  final backdrop = movie.backdropPath.isNotEmpty
      ? TmdbApi.getImageUrl(movie.backdropPath)
      : null;
  return KitSearchResult(
    key: 'tmdb:${movie.mediaType}:${movie.id}',
    title: movie.title,
    posterUrl: poster,
    backdropUrl: backdrop,
    subtitle: year.isEmpty ? media : '$media · $year',
    rating: movie.voteAverage > 0 ? movie.voteAverage : null,
    payload: movie,
  );
}

KitSearchResult _stremioResult(
  Map<String, dynamic> item, {
  required String sectionTitle,
}) {
  final id = item['id']?.toString() ?? '';
  final type = item['type']?.toString() ?? 'movie';
  final name = item['name']?.toString().trim() ?? 'Unknown';
  final poster = item['poster']?.toString() ?? '';
  final background = item['background']?.toString();
  final release = item['releaseInfo']?.toString() ?? '';
  final year = release.length >= 4 ? release.substring(0, 4) : release;
  final kind = type == 'series' ? 'TV' : 'FILM';
  final rating = double.tryParse(item['imdbRating']?.toString() ?? '');
  return KitSearchResult(
    key: 'stremio:$type:$id',
    title: name.isEmpty ? 'Unknown' : name,
    posterUrl: poster,
    backdropUrl: (background != null && background.isNotEmpty)
        ? background
        : null,
    subtitle: year.isEmpty ? '$kind · $sectionTitle' : '$kind · $year',
    rating: rating,
    payload: item,
  );
}

/// Progressive host search for [KitSearchPage.onSearchProgressive].
Future<void> runHostKitSearch(
  String query,
  void Function(
    List<KitSearchResult> results, {
    required bool done,
  }) emit, {
  HostSearchEngine? engine,
}) async {
  final host = engine ?? HostSearchEngine();
  await host.run(
    query,
    onUpdate: (state) {
      emit(
        kitResultsFromHostSearch(state),
        done: state.done,
      );
    },
  );
}

Future<List<String>> hostKitRecommendations({
  required String query,
  required List<KitSearchResult> results,
}) async {
  if (results.isEmpty) {
    return HostSearchHelpers.trendingTitles();
  }
  Movie? seed;
  final exclude = <String>{};
  for (final r in results) {
    final t = r.title.trim();
    if (t.isNotEmpty) exclude.add(t.toLowerCase());
    final p = r.payload;
    if (seed == null && p is Movie) seed = p;
  }
  if (seed == null) {
    return HostSearchHelpers.trendingTitles();
  }
  return HostSearchHelpers.contextualTitles(seed, exclude: exclude);
}
