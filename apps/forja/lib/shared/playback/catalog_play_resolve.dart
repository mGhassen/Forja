import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/playback/hub_open_engine.dart';
import 'package:forja/shared/playback/hub_play_context.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

/// Playback boundary — maps pack [CatalogMetaItem] → engine play args.
/// Catalog kit must not import feature services or pack names.
HubPlayContext catalogPlayContextFromMeta({
  required CatalogMetaItem meta,
  String? pluginId,
  CatalogVideo? episode,
  int? episodeNumber,
  int? season,
  String? episodeVideoId,
  List<CatalogVideo>? videos,
  Map<String, dynamic> extras = const {},
  Duration? startPosition,
  Set<String>? selectedPluginIds,
}) {
  final vids = videos ?? meta.videos;
  final ep = episode;
  final epNum = ep?.episode ?? episodeNumber ?? 1;
  final seasonNum = ep?.season ?? season ?? 1;
  final isMovie = _metaIsMovie(meta);
  final isTv = !isMovie && vids.length > 1;
  final open = meta.open;
  final engineCategory = engineCategoryForOpen(open, metaType: meta.type);

  final videoId = episodeVideoId ?? ep?.id;
  final providerFromVideo = videoId != null
      ? providerIdFromEpisodeVideoId(videoId)
      : null;

  var episodeIds = _videoIdByEpisode(vids);
  if (videoId != null && videoId.isNotEmpty) {
    episodeIds = {...episodeIds, epNum: videoId};
  }

  if (selectedPluginIds == null && providerFromVideo != null) {
    selectedPluginIds = {providerFromVideo};
  }

  final malId =
      int.tryParse(open?.extraString('mal') ?? '') ?? meta.numericId('mal');

  return HubPlayContext(
    movie: _playMovieFor(meta, videos: vids),
    engineCategory: engineCategory,
    pluginId: pluginId,
    catalogMeta: meta,
    catalogOpen: open,
    season: isTv ? seasonNum : null,
    episode: isTv ? epNum : (isMovie ? null : epNum),
    malId: malId,
    episodeVideoIdByNumber: episodeIds,
    animeAudioCategory: extras['category']?.toString(),
    hubEpisodes: isTv ? _episodesFromVideos(vids) : null,
    selectedPluginIds: selectedPluginIds,
    startPosition: startPosition,
    loadingSubtitle: isMovie ? null : 'EP $epNum',
  );
}

bool _metaIsMovie(CatalogMetaItem item) {
  if (item.open?.extraBool('movie') == true) return true;
  if ((item.badge ?? '').toUpperCase() == 'MOVIE') return true;
  if (item.type == 'movie') return true;
  final fmt = (item.badge ?? '').toUpperCase();
  return fmt == 'MOVIE' || item.tmdbMediaType == 'movie';
}

Movie _playMovieFor(CatalogMetaItem item, {List<CatalogVideo>? videos}) {
  final isMovie = _metaIsMovie(item);
  final poster = item.poster.trim();
  final backdrop = item.background.trim();
  final eps = videos ?? item.videos;
  final tmdbId = item.numericId('tmdb');
  final id = tmdbId ?? catalogSyntheticMovieId(item);
  return Movie(
    id: id,
    title: item.name,
    posterPath: catalogPosterPathForMovie(poster),
    backdropPath: catalogPosterPathForMovie(
      backdrop.isNotEmpty ? backdrop : poster,
    ),
    voteAverage: item.rating ?? 0,
    releaseDate: item.releaseInfo,
    overview: item.description,
    mediaType: isMovie
        ? 'movie'
        : (item.type == 'anime' ? 'anime' : 'tv'),
    numberOfEpisodes: eps.isNotEmpty ? eps.length : (item.episodes ?? 0),
  );
}

Map<int, String> _videoIdByEpisode(List<CatalogVideo> videos) {
  final out = <int, String>{};
  for (final v in videos) {
    final ep = v.episode ?? out.length + 1;
    if (v.id.isNotEmpty) out[ep] = v.id;
  }
  return out;
}

List<PlayerHubEpisode> _episodesFromVideos(List<CatalogVideo> videos) => [
      for (final v in videos)
        PlayerHubEpisode(
          number: v.episode ?? 1,
          title: v.title,
        ),
    ];
