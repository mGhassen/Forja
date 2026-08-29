import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_meta_movie.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

String arabicProviderIdForVideoId(String videoId) {
  final i = videoId.indexOf(':');
  if (i <= 0) return 'larozaa';
  return videoId.substring(0, i);
}

Movie arabicPlayMovieFor(CatalogMetaItem item, {List<CatalogVideo>? videos}) {
  final isMovie = item.open?.extraBool('movie') == true ||
      (item.badge ?? '').toUpperCase() == 'MOVIE';
  final id = catalogSyntheticMovieId(item);
  final poster = item.poster.trim();
  final backdrop = item.background.trim();
  final eps = videos ?? item.videos;
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
    mediaType: isMovie ? 'movie' : 'tv',
    numberOfEpisodes: eps.length,
  );
}

Map<int, String> arabicVideoIdByEpisode(List<CatalogVideo> videos) {
  final out = <int, String>{};
  for (final v in videos) {
    final ep = v.episode ?? out.length + 1;
    if (v.id.isNotEmpty) out[ep] = v.id;
  }
  return out;
}

List<PlayerHubEpisode> arabicHubEpisodes(List<CatalogVideo> videos) => [
      for (final v in videos)
        PlayerHubEpisode(
          number: v.episode ?? 1,
          title: v.title,
        ),
    ];

Map<int, List<Map<String, dynamic>>>? arabicEpisodeMaps(
  List<CatalogVideo> videos,
) {
  if (videos.isEmpty) return null;
  final bySeason = <int, List<Map<String, dynamic>>>{};
  for (final v in videos) {
    final season = v.season ?? 1;
    final epNum = v.episode ?? 1;
    bySeason.putIfAbsent(season, () => []);
    bySeason[season]!.add({
      'episode_number': epNum,
      'name': v.title.isNotEmpty ? v.title : 'Episode $epNum',
      'still_path': v.thumbnail,
    });
  }
  return bySeason;
}

Set<int> arabicSeasonNumbers(List<CatalogVideo> videos) {
  return {for (final v in videos) v.season ?? 1};
}

List<CatalogVideo> arabicVideosForSeason(
  List<CatalogVideo> videos,
  int season,
) {
  return [
    for (final v in videos)
      if ((v.season ?? 1) == season) v,
  ];
}

String arabicImageUrl(String path) {
  final p = path.trim();
  if (p.isEmpty) return '';
  return p.startsWith('http') ? p : TmdbApi.getImageUrl(p);
}
