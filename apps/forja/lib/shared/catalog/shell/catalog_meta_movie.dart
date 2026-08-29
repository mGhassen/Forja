import 'package:forja/shared/catalog/protocol.dart';
import 'package:rust/rust.dart';

/// Strip a TMDB CDN URL (or keep a `/path`) for [Movie.posterPath].
String catalogTmdbPath(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('/')) return s;
  final marker = '/t/p/';
  final i = s.indexOf(marker);
  if (i >= 0) {
    final rest = s.substring(i + marker.length);
    final slash = rest.indexOf('/');
    if (slash >= 0) return rest.substring(slash);
  }
  final last = s.lastIndexOf('/');
  if (last >= 0 && last < s.length - 1) return '/${s.substring(last + 1)}';
  return s;
}

/// Map catalog meta → [Movie] for HomeMovieCard / HomeMovieSection.
Movie? catalogMetaToMovie(CatalogMetaItem item) {
  final type = item.type.toLowerCase();
  final id = item.numericId('tmdb');
  if (id == null || id <= 0) return null;

  String mediaType;
  if (type == 'movie' || type == 'tv' || type == 'series') {
    mediaType = type == 'series' ? 'tv' : type;
  } else if (type == 'drama' || type == 'anime') {
    final hint = (item.tmdbMediaType ?? '').toLowerCase();
    mediaType = hint == 'movie' ? 'movie' : 'tv';
  } else {
    return null;
  }

  return Movie(
    id: id,
    title: item.name,
    posterPath: catalogTmdbPath(item.poster),
    backdropPath: catalogTmdbPath(item.background),
    voteAverage: item.rating ?? 0,
    releaseDate: item.releaseInfo,
    overview: item.description,
    genres: item.genres,
    mediaType: mediaType,
  );
}

List<Movie> catalogMetasToMovies(Iterable<CatalogMetaItem> items) => [
      for (final item in items)
        if (catalogMetaToMovie(item) case final m?) m,
    ];
