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

/// Stable negative id for hub meta without a numeric upstream id.
int catalogSyntheticMovieId(CatalogMetaItem item) {
  return -item.id.hashCode.abs().clamp(1, 0x7FFFFFFF);
}

final Map<int, CatalogMetaItem> _catalogMetaByMovieId = {};

/// Reverse lookup after [catalogMetaToMovie].
CatalogMetaItem? catalogMetaItemForMovie(Movie movie) =>
    _catalogMetaByMovieId[movie.id];

String catalogPosterPathForMovie(String raw) {
  final s = raw.trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  return catalogTmdbPath(s);
}

int? _numericOpenId(CatalogMetaItem item) {
  final open = item.open;
  if (open != null) return open.idInt;
  final tail = item.id.split(':').last;
  return int.tryParse(tail);
}

/// [Movie.id] for play / Wyzie / generic extract.
///
/// Prefer enrich `ids.tmdb` over hub `open.id` (KissKh / AniList / …). Pack
/// extract keeps the hub id in [CatalogOpen.extract] `ctx` (e.g. `kisskhId`).
int catalogMovieIdForPlay(CatalogMetaItem item) {
  final tmdb = item.numericId('tmdb');
  if (tmdb != null && tmdb > 0) return tmdb;
  final openId = _numericOpenId(item);
  if (openId != null && openId > 0) return openId;
  return catalogSyntheticMovieId(item);
}

/// Map catalog meta → [Movie] for hero bleed / TMDB-shaped playback ids.
Movie? catalogMetaToMovie(CatalogMetaItem item) {
  final open = item.open;
  final extract = open?.effectiveExtract;
  final resolveType = extract?.resolveType ?? item.type.toLowerCase();

  if (resolveType == 'arabic' ||
      (open == null && item.type.toLowerCase() == 'arabic')) {
    final movieId = catalogSyntheticMovieId(item);
    _catalogMetaByMovieId[movieId] = item;
    final isMovie = open?.extraBool('movie') == true ||
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

  final tmdb = item.numericId('tmdb');
  final openId = _numericOpenId(item);
  final id = (tmdb != null && tmdb > 0) ? tmdb : openId;
  if (id == null || id <= 0) return null;

  String mediaType;
  if (resolveType == 'movie' || resolveType == 'tv' || resolveType == 'series') {
    mediaType = resolveType == 'series' ? 'tv' : resolveType;
  } else if (resolveType == 'anime' || resolveType == 'drama') {
    final hint = (item.tmdbMediaType ?? '').toLowerCase();
    mediaType = hint == 'movie' ? 'movie' : 'tv';
  } else {
    mediaType = item.tmdbMediaType == 'movie' ? 'movie' : 'tv';
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

/// Home-style card meta under the title: `2026 • FILM` / `TV` / …
///
/// Packs that already put format in [CatalogMetaItem.releaseInfo] (anime:
/// `2026 • 12 eps`) are passed through unchanged.
String? hubPosterCardSubtitle(CatalogMetaItem item) {
  final release = item.releaseInfo.trim();
  if (release.contains(' • ')) {
    return release.isEmpty ? null : release;
  }

  final parts = <String>[];
  if (release.isNotEmpty) {
    parts.add(release.contains('-') ? release.split('-').first : release);
  }

  final typeLabel = hubPosterTypeLabel(item);
  if (typeLabel != null) parts.add(typeLabel);

  return parts.isEmpty ? null : parts.join(' • ');
}

String? hubPosterTypeLabel(CatalogMetaItem item) {
  if (item.type == 'anime') return null;

  final hint = (item.tmdbMediaType ?? '').trim().toLowerCase();
  final kind = item.type.trim().toLowerCase();

  if (hint == 'tv' || kind == 'tv' || kind == 'series') return 'TV';
  if (hint == 'movie' || kind == 'movie') return 'FILM';

  if (kind == 'drama') {
    final badge = (item.badge ?? '').trim().toUpperCase();
    if (badge == 'MOVIE' || badge == 'FILM' || badge == 'HOLLYWOOD') {
      return 'FILM';
    }
    return 'TV';
  }

  return null;
}
