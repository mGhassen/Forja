import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shared/playback/kit_episodes.dart';
import 'package:forja/shared/playback/play_session.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

/// After ≥85% auto-mark: keep the show on Continue Watching as the next ep.
Future<void> advanceHubContinueAfterFinish({
  required PlaySession session,
  required int finishedEpisode,
  int? season,
  List<PlayerKitEpisode>? episodes,
}) async {
  final pluginId = session.pluginId;
  final meta = session.metaItem;
  if (pluginId == null || meta == null) return;

  final list = _resolveHubEpisodes(meta: meta, episodes: episodes);
  if (list == null || list.isEmpty) return;
  final idx = hubEpisodeIndex(list, finishedEpisode);
  if (idx == null) return;
  final next = nextAiredHubEpisode(list, idx);
  if (next == null) return;

  final nextEp = next.number.round();
  if (nextEp <= 0) return;

  await WatchHistory.record(
    pluginId: pluginId,
    meta: meta,
    episodeNumber: nextEp,
    season: season,
    episodeVideoId: session.episodeVideoIdFor(nextEp),
    extras: {
      if (session.audioCategory != null) 'category': session.audioCategory,
    },
    position: Duration.zero,
    duration: Duration.zero,
    upNext: true,
  );
}

/// Home / TMDB TV: seed the next aired S/E into [WatchHistoryService].
Future<void> advanceHomeContinueAfterFinish({
  required Movie movie,
  required int season,
  required int episode,
}) async {
  if (movie.mediaType != 'tv' || movie.id < 0) return;
  final next = await nextAiredTmdbEpisode(
    tvId: movie.id,
    season: season,
    episode: episode,
  );
  if (next == null) return;

  await WatchHistoryService().seedUpNext(
    tmdbId: movie.id,
    imdbId: movie.imdbId,
    title: movie.title,
    posterPath: movie.posterPath,
    backdropPath: movie.backdropPath,
    season: next.season,
    episode: next.episode,
    mediaType: movie.mediaType,
  );
}

List<PlayerKitEpisode>? _resolveHubEpisodes({
  required MetaItem meta,
  List<PlayerKitEpisode>? episodes,
}) {
  if (episodes != null && episodes.isNotEmpty) return episodes;
  try {
    final fromMeta = episodesFromMeta(meta);
    if (fromMeta.isNotEmpty) return fromMeta;
  } catch (_) {}
  return null;
}
