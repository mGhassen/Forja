import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:rust/rust.dart';

/// Pack/cover URL for [Movie.posterPath] — absolute https as shipped by packs.
String catalogPosterPathForMovie(String raw) {
  return normalizeCoverUrl(raw.trim());
}

/// Stable negative id for hub meta without a numeric upstream id.
int catalogSyntheticMovieId(MetaItem item) {
  return -item.id.hashCode.abs().clamp(1, 0x7FFFFFFF);
}

final Map<int, MetaItem> _metaItemByMovieId = {};

/// Reverse lookup after [metaItemToMovie].
MetaItem? metaItemForMovie(Movie movie) =>
    _metaItemByMovieId[movie.id];

int? _numericOpenId(MetaItem item) {
  final open = item.open;
  if (open != null) return open.idInt;
  final tail = item.id.split(':').last;
  return int.tryParse(tail);
}

/// [Movie.id] for play / Wyzie / generic extract.
///
/// Prefer enrich `ids.tmdb` over hub `open.id`. Pack extract keeps the hub id
/// in [MetaOpen.extract] `ctx`.
int catalogMovieIdForPlay(MetaItem item) {
  final tmdb = item.numericId('tmdb');
  if (tmdb != null && tmdb > 0) return tmdb;
  final openId = _numericOpenId(item);
  if (openId != null && openId > 0) return openId;
  return catalogSyntheticMovieId(item);
}

/// Declared series episode total for My List / Simkl Completed.
///
/// Prefer [MetaItem.episodes], then pack `facts.episodeCount`. Never invent
/// from `videos.length` or the episode just watched — that falsely Completed
/// after E1 when only one video row (or `meta.episodes ?? ep`) was available.
int metaDeclaredEpisodeCount(MetaItem item) {
  final declared = item.episodes;
  if (declared != null && declared > 0) return declared;
  final fromFacts = (item.facts?['episodeCount'] as num?)?.toInt() ?? 0;
  if (fromFacts > 0) return fromFacts;
  return 0;
}

/// Map catalog meta → [Movie] for hero bleed / TMDB-shaped playback ids.
Movie? metaItemToMovie(MetaItem item) {
  final open = item.open;
  final extract = open?.effectiveExtract;
  final resolveType = extract?.resolveType ?? item.type.toLowerCase();

  if (open?.surface == 'stremio') {
    final movieId = catalogSyntheticMovieId(item);
    _metaItemByMovieId[movieId] = item;
    final isMovie = item.type == 'movie' || item.tmdbMediaType == 'movie';
    final poster = item.poster.trim();
    final backdrop = item.background.trim();
    final imdb = item.ids['imdb']?.toString();
    return Movie(
      id: movieId,
      imdbId: (imdb != null && imdb.startsWith('tt')) ? imdb : null,
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
      numberOfEpisodes: metaDeclaredEpisodeCount(item),
    );
  }

  final tmdb = item.numericId('tmdb');
  final openId = _numericOpenId(item);
  final numeric = (tmdb != null && tmdb > 0) ? tmdb : openId;
  final id =
      (numeric != null && numeric > 0) ? numeric : catalogSyntheticMovieId(item);
  _metaItemByMovieId[id] = item;

  String mediaType;
  if (resolveType == 'movie' || resolveType == 'tv' || resolveType == 'series') {
    mediaType = resolveType == 'series' ? 'tv' : resolveType;
  } else if (item.tmdbMediaType == 'movie' || item.tmdbMediaType == 'tv') {
    mediaType = item.tmdbMediaType!;
  } else if (open?.extraBool('movie') == true ||
      (item.badge ?? '').toUpperCase() == 'MOVIE') {
    mediaType = 'movie';
  } else {
    mediaType = 'tv';
  }

  final imdb = item.ids['imdb']?.toString();
  return Movie(
    id: id,
    imdbId: (imdb != null && imdb.startsWith('tt')) ? imdb : null,
    title: item.name,
    posterPath: catalogPosterPathForMovie(item.poster),
    backdropPath: catalogPosterPathForMovie(item.background),
    voteAverage: item.rating ?? 0,
    releaseDate: item.releaseInfo,
    overview: item.description,
    genres: item.genres,
    mediaType: mediaType,
  );
}

List<Movie> metaItemsToMovies(Iterable<MetaItem> items) => [
      for (final item in items) ?metaItemToMovie(item),
    ];

/// Home-style card meta under the title: `2026 • FILM` / `TV` / …
///
/// Packs that already put format in [MetaItem.releaseInfo] (e.g.
/// `2026 • 12 eps`) are passed through unchanged.
String? kitPosterSubtitle(MetaItem item) {
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

String? hubPosterTypeLabel(MetaItem item) {
  final hint = (item.tmdbMediaType ?? '').trim().toLowerCase();
  final kind = item.type.trim().toLowerCase();

  if (hint == 'tv' || kind == 'tv' || kind == 'series') return 'TV';
  if (hint == 'movie' || kind == 'movie') return 'FILM';

  final badge = (item.badge ?? '').trim().toUpperCase();
  if (badge == 'MOVIE' || badge == 'FILM' || badge == 'HOLLYWOOD') {
    return 'FILM';
  }
  return null;
}

/// Overlay badge on [KitPosterCard] — pack-supplied [MetaItem.badge] only.
///
/// Omits redundant FILM/TV/MOVIE/SERIES chips (type already lives in the
/// subtitle via [kitPosterSubtitle] / hub paint). Other labels (unlock,
/// remake, …) stay.
String? kitPosterBadge(
  MetaItem item, {
  String? pluginId,
}) {
  final badge = item.badge?.trim();
  if (badge == null || badge.isEmpty) return null;
  final upper = badge.toUpperCase();
  if (upper == 'FILM' ||
      upper == 'MOVIE' ||
      upper == 'HOLLYWOOD' ||
      upper == 'TV' ||
      upper == 'SERIES') {
    return null;
  }
  return badge;
}
