import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:rust/rust.dart';

/// Legacy [Movie] → hub meta (host route/id scheme only — no plugin id).
CatalogMetaItem catalogMetaFromMovie(Movie movie) {
  final mediaType = movie.mediaType == 'tv' ? 'tv' : 'movie';
  final ids = <String, dynamic>{'tmdb': movie.id.toString()};
  final imdb = movie.imdbId?.trim();
  if (imdb != null && imdb.isNotEmpty) ids['imdb'] = imdb;

  return CatalogMetaItem(
    id: 'tmdb:$mediaType:${movie.id}',
    type: mediaType,
    name: movie.title,
    poster: catalogTmdbImagePath(movie.posterPath),
    background: catalogTmdbImagePath(
      movie.backdropPath.isNotEmpty ? movie.backdropPath : movie.posterPath,
    ),
    description: movie.overview,
    releaseInfo: movie.releaseDate.length >= 4
        ? movie.releaseDate.substring(0, 4)
        : movie.releaseDate,
    rating: movie.voteAverage,
    tmdbMediaType: mediaType,
    ids: ids,
    open: CatalogOpen(
      surface: 'tmdb',
      id: movie.id.toString(),
      extras: {'mediaType': mediaType},
      extract: CatalogOpenExtract(
        resolveType: mediaType == 'tv' ? 'tv' : 'movie',
        panelCategory: 'movie',
        ctx: {'tmdbId': movie.id},
      ),
    ),
  );
}

/// Stremio catalog/search row → hub meta ([open.surface] `stremio`).
///
/// Uses the addon's opaque id and catalog addon URL — not TMDB/IMDB routing.
CatalogMetaItem catalogMetaFromStremioSearchResult(
  Map<String, dynamic> item,
) {
  final id = item['id']?.toString() ?? '';
  var type = item['type']?.toString() ?? 'movie';
  if (type.isEmpty) type = 'movie';
  final isCollection = type == 'collections' || id.startsWith('ctmdb.');
  final metaType = isCollection
      ? 'collections'
      : (type == 'series' ? 'tv' : 'movie');

  final ids = <String, dynamic>{};
  if (id.startsWith('tt')) ids['imdb'] = id;

  final name = item['name']?.toString().trim();
  final poster = item['poster']?.toString() ?? '';
  final background = item['background']?.toString() ?? poster;
  final description = item['description']?.toString() ?? '';
  final releaseInfo = item['releaseInfo']?.toString() ?? '';
  final rating = double.tryParse(item['imdbRating']?.toString() ?? '');

  return CatalogMetaItem(
    id: 'stremio:$metaType:$id',
    type: metaType,
    name: (name != null && name.isNotEmpty) ? name : 'Unknown',
    poster: poster,
    background: background,
    description: description,
    releaseInfo: releaseInfo.length >= 4 ? releaseInfo.substring(0, 4) : releaseInfo,
    rating: rating,
    tmdbMediaType: metaType == 'tv' ? 'tv' : 'movie',
    ids: ids,
    open: CatalogOpen(
      surface: 'stremio',
      id: id,
      extras: {
        'stremioId': id,
        'stremioType': isCollection ? 'collections' : type,
        if (item['_addonBaseUrl'] != null)
          'stremioAddonBaseUrl': item['_addonBaseUrl'],
        if (item['_addonName'] != null) 'stremioAddonName': item['_addonName'],
        'mediaType': metaType,
      },
    ),
  );
}

/// Stremio addon row + optional TMDB [movie] overlay (legacy [AppRouter.openDetails]).
CatalogMetaItem catalogMetaFromStremioItem(
  Map<String, dynamic> stremioItem,
  Movie movie,
) {
  final meta = catalogMetaFromStremioSearchResult(stremioItem);
  final ids = Map<String, dynamic>.from(meta.ids);
  if (movie.id > 0 && movie.mediaType != 'collections') {
    ids['tmdb'] = movie.id.toString();
  }
  final imdb = movie.imdbId?.trim();
  if (imdb != null && imdb.isNotEmpty) ids['imdb'] = imdb;

  final stremioName = stremioItem['name']?.toString().trim() ?? '';
  final title = stremioName.isNotEmpty ? stremioName : movie.title;
  final poster = meta.poster.isNotEmpty ? meta.poster : movie.posterPath;
  final backdrop = meta.background.isNotEmpty
      ? meta.background
      : (movie.backdropPath.isNotEmpty ? movie.backdropPath : movie.posterPath);

  return CatalogMetaItem(
    id: meta.id,
    type: meta.type,
    name: title,
    poster: poster,
    background: backdrop,
    description: meta.description.isNotEmpty ? meta.description : movie.overview,
    releaseInfo: meta.releaseInfo.isNotEmpty
        ? meta.releaseInfo
        : (movie.releaseDate.length >= 4
            ? movie.releaseDate.substring(0, 4)
            : movie.releaseDate),
    rating: meta.rating ?? movie.voteAverage,
    tmdbMediaType: meta.tmdbMediaType,
    ids: ids,
    open: meta.open,
  );
}
