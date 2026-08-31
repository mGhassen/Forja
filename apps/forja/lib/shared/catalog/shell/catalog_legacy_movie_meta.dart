import 'package:forja/shared/catalog/plugin_nav.dart';
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

/// Stremio addon row → hub meta; pack `details` is skipped on [open.surface].
CatalogMetaItem catalogMetaFromStremioItem(
  Map<String, dynamic> stremioItem,
  Movie movie,
) {
  final id = stremioItem['id']?.toString() ?? '';
  var type = stremioItem['type']?.toString() ?? '';
  if (type.isEmpty) {
    type = movie.mediaType == 'tv' ? 'series' : 'movie';
  }
  final isCollection = type == 'collections' || id.startsWith('ctmdb.');
  final metaType = isCollection
      ? 'collections'
      : (type == 'series' || movie.mediaType == 'tv' ? 'tv' : 'movie');

  final ids = <String, dynamic>{};
  if (id.startsWith('tt')) ids['imdb'] = id;
  if (movie.id > 0 && movie.mediaType != 'collections') {
    ids['tmdb'] = movie.id.toString();
  }

  return CatalogMetaItem(
    id: 'stremio:$metaType:$id',
    type: metaType,
    name: movie.title,
    poster: movie.posterPath,
    background: movie.backdropPath.isNotEmpty
        ? movie.backdropPath
        : movie.posterPath,
    description: movie.overview,
    releaseInfo: movie.releaseDate.length >= 4
        ? movie.releaseDate.substring(0, 4)
        : movie.releaseDate,
    rating: movie.voteAverage,
    tmdbMediaType: metaType == 'tv' ? 'tv' : 'movie',
    ids: ids,
    open: CatalogOpen(
      surface: 'stremio',
      id: id,
      extras: {
        'stremioId': id,
        'stremioType': isCollection ? 'collections' : type,
        if (stremioItem['_addonBaseUrl'] != null)
          'stremioAddonBaseUrl': stremioItem['_addonBaseUrl'],
        if (stremioItem['_addonName'] != null)
          'stremioAddonName': stremioItem['_addonName'],
        'mediaType': metaType,
      },
    ),
  );
}

Future<String?> resolveHubPluginIdForTab(String tabId) async {
  return PluginNavRegistry.resolveHubPluginId(tabId: tabId);
}
