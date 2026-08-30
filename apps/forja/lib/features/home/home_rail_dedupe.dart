import 'package:rust/rust.dart';

/// TMDB pages to fetch per rail on first paint (one page ≈ 20 titles).
const kHomeRailFetchPages = 1;

String homeMediaKey(Movie movie) => '${movie.mediaType}:${movie.id}';

/// Merge page results preserving first-seen order.
List<Movie> mergeHomeRailPages(List<List<Movie>> pages) {
  final out = <Movie>[];
  final seen = <String>{};
  for (final page in pages) {
    for (final movie in page) {
      if (seen.add(homeMediaKey(movie))) out.add(movie);
    }
  }
  return out;
}
