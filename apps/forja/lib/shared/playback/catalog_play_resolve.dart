import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/protocol.dart';
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
  final surface = open?.surface ?? meta.type;
  final engineCategory = _engineCategoryForSurface(surface);

  final videoId = episodeVideoId ?? ep?.id;
  final providerFromVideo = videoId != null && videoId.contains(':')
      ? videoId.substring(0, videoId.indexOf(':'))
      : null;

  int? anilistId;
  int? malId;
  int? kisskhId;
  int? kisskhEpisodeId;
  String? arabicVideoId;

  if (surface == 'anime' || meta.type == 'anime') {
    anilistId = open?.idInt ?? meta.numericId('anilist');
    malId =
        int.tryParse(open?.extraString('mal') ?? '') ?? meta.numericId('mal');
  }
  if (surface == 'drama' || meta.type == 'drama') {
    kisskhId = open?.idInt ?? meta.numericId('kisskh');
    if (ep != null) kisskhEpisodeId = int.tryParse(ep.id);
  }
  if (surface == 'arabic' || meta.type == 'arabic') {
    arabicVideoId = videoId;
    if (videoId != null && videoId.isNotEmpty) {
      selectedPluginIds ??= {_providerIdFromVideoId(videoId)};
    }
  }

  return HubPlayContext(
    movie: _playMovieFor(meta, videos: vids),
    engineCategory: engineCategory,
    pluginId: pluginId,
    catalogMeta: meta,
    season: isTv ? seasonNum : null,
    episode: isTv ? epNum : (isMovie ? null : epNum),
    anilistId: anilistId,
    malId: malId,
    kisskhId: kisskhId,
    kisskhEpisodeId: kisskhEpisodeId,
    kisskhEpisodeIdByNumber: _episodeIdByNumber(vids),
    arabicVideoId: arabicVideoId,
    arabicVideoIdByEpisode: _videoIdByEpisode(vids),
    animeAudioCategory: extras['category']?.toString(),
    hubEpisodes: isTv ? _episodesFromVideos(vids) : null,
    selectedPluginIds: selectedPluginIds ??
        (providerFromVideo != null ? {providerFromVideo} : null),
    startPosition: startPosition,
    loadingSubtitle: isMovie ? null : 'EP $epNum',
  );
}

String _engineCategoryForSurface(String surface) {
  switch (surface) {
    case 'anime':
      return 'anime';
    case 'drama':
      return 'drama';
    case 'arabic':
      return 'arabic';
    default:
      return 'movie';
  }
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

String _providerIdFromVideoId(String videoId) {
  final i = videoId.indexOf(':');
  if (i <= 0) return 'larozaa';
  return videoId.substring(0, i);
}

Map<int, String> _videoIdByEpisode(List<CatalogVideo> videos) {
  final out = <int, String>{};
  for (final v in videos) {
    final ep = v.episode ?? out.length + 1;
    if (v.id.isNotEmpty) out[ep] = v.id;
  }
  return out;
}

Map<int, int> _episodeIdByNumber(List<CatalogVideo> videos) {
  final out = <int, int>{};
  for (final v in videos) {
    final ep = v.episode ?? out.length + 1;
    final id = int.tryParse(v.id);
    if (id != null && id > 0) out[ep] = id;
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
