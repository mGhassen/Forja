import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shared/playback/kit_episodes.dart';
import 'package:forja/shared/playback/play_session.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart';

/// After ≥85%: keep the show on Continue Watching as the next ep.
/// Returns true when an up-next row was written.
Future<bool> advanceHubContinueAfterFinish({
  required PlaySession session,
  required int finishedEpisode,
  int? season,
  List<PlayerKitEpisode>? episodes,
}) async {
  final pluginId = session.pluginId;
  final meta = session.metaItem;
  if (pluginId == null || meta == null) return false;

  final list = _resolveHubEpisodes(meta: meta, episodes: episodes);
  final next = _nextEpisodeAfter(list, finishedEpisode, season: season);
  final nextEp = next?.number;
  if (next == null || nextEp == null) {
    debugPrint(
      '[CW] no next after ep $finishedEpisode '
      '(list=${list?.length ?? 0}) — show leaves Continue Watching',
    );
    return false;
  }

  await WatchHistory.record(
    pluginId: pluginId,
    meta: meta,
    episodeNumber: nextEp,
    season: next.season ?? season,
    episodeVideoId: session.episodeVideoIdFor(
      nextEp,
      season: next.season ?? season,
    ),
    extras: {
      if (session.audioCategory != null) 'category': session.audioCategory,
    },
    position: Duration.zero,
    duration: Duration.zero,
    upNext: true,
  );
  debugPrint('[CW] up-next $pluginId → ep $nextEp (after $finishedEpisode)');
  return true;
}

/// Home / TMDB TV: seed the next aired S/E into [WatchHistoryService].
Future<bool> advanceHomeContinueAfterFinish({
  required Movie movie,
  required int season,
  required int episode,
}) async {
  if (movie.mediaType != 'tv' || movie.id < 0) return false;
  final next = await nextAiredTmdbEpisode(
    tvId: movie.id,
    season: season,
    episode: episode,
  );
  if (next == null) {
    debugPrint(
      '[CW] no next TMDB after S${season}E$episode for ${movie.id}',
    );
    return false;
  }

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
  debugPrint(
    '[CW] up-next tmdb:${movie.id} → S${next.season}E${next.episode}',
  );
  return true;
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

/// Next aired row after [finished] (in [season] when the list is tagged),
/// or null when the show is done. Rolls into the next season's first row.
({int number, int? season})? _nextEpisodeAfter(
  List<PlayerKitEpisode>? list,
  int finished, {
  int? season,
}) {
  if (list == null || list.isEmpty) {
    // No list at save time — still keep CW as ep+1 (Play re-resolves).
    return (number: finished + 1, season: null);
  }
  final idx = hubEpisodeIndex(list, finished, season: season);
  if (idx != null) {
    final next = nextAiredHubEpisode(list, idx);
    if (next == null) return null;
    final n = next.number.round();
    return n > 0 ? (number: n, season: next.season) : null;
  }
  // Number miss (remap / int vs double): first aired with number > finished,
  // staying inside the finished season when rows are tagged.
  PlayerKitEpisode? best;
  for (final e in list) {
    if (e.notShippedYet) continue;
    if (season != null && e.season != null && e.season != season) continue;
    if (e.number <= finished) continue;
    if (best == null || e.number < best.number) best = e;
  }
  if (best == null) return null;
  final n = best.number.round();
  return n > 0 ? (number: n, season: best.season) : null;
}
