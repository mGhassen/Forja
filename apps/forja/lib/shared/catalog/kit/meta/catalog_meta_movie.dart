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

/// Stable negative id for hub meta without TMDB (Arabic catalog cards).
int catalogSyntheticMovieId(CatalogMetaItem item) {
  return -item.id.hashCode.abs().clamp(1, 0x7FFFFFFF);
}

final Map<int, CatalogMetaItem> _catalogMetaByMovieId = {};

/// Reverse lookup after [catalogMetaToMovie] (Arabic home rails tap).
CatalogMetaItem? catalogMetaItemForMovie(Movie movie) =>
    _catalogMetaByMovieId[movie.id];

String catalogPosterPathForMovie(String raw) {
  final s = raw.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  return catalogTmdbPath(s);
}

/// Map catalog meta → [Movie] when meta carries TMDB-shaped ids (hero bleed).
Movie? catalogMetaToMovie(CatalogMetaItem item) {
  final type = item.type.toLowerCase();
  if (type == 'arabic') {
    final movieId = catalogSyntheticMovieId(item);
    _catalogMetaByMovieId[movieId] = item;
    final isMovie = item.open?.extraBool('movie') == true ||
        (item.badge ?? '').toUpperCase() == 'MOVIE';
    final poster = item.poster.trim();
    final backdrop = item.background.trim();
    return Movie(
      id: movieId,
      title: item.name,
      posterPath: catalogPosterPathForMovie(poster),
      backdropPath: catalogPosterPathForMovie(
        backdrop.isNotEmpty ? backdrop : poster,
      ),
      voteAverage: item.rating ?? 0,
      releaseDate: item.releaseInfo,
      overview: item.description,
      genres: item.genres,
      mediaType: isMovie ? 'movie' : 'tv',
    );
  }

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
