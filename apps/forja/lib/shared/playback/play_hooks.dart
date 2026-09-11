import 'package:forja/shared/playback/play_session.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/host/watch/watch_history.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/engine/lists/list_follow_from_watched.dart';
import 'package:rust/rust.dart';

/// Hub tab media types — episodic catalog rows, not Home TMDB watch history.
bool isKitTabMediaType(String? mediaType) {
  if (mediaType == null || mediaType.isEmpty) return false;
  return mediaType != 'movie' && mediaType != 'tv';
}

bool hubMediaIsEpisodic(Movie movie) {
  final t = movie.mediaType;
  if (t == 'tv') return true;
  // Pack-emitted types (anime, drama, …) — anything that isn't Home movie/tv.
  return isKitTabMediaType(t);
}

bool usesHomeWatchHistory({
  required Movie? movie,
  List<PlayerKitEpisode>? episodes,
  Future<void> Function(Duration position, Duration duration)? onSaveProgress,
  PlaySession? playSession,
}) {
  if (movie == null) return false;
  if (episodes != null) return false;
  if (onSaveProgress != null) return false;
  if (playSession != null &&
      playNeedsWatchHistory(playSession)) {
    return false;
  }
  if (isKitTabMediaType(movie.mediaType)) return false;
  if (movie.id < 0) return false;
  return true;
}

class KitPlayHooks {
  const KitPlayHooks({
    this.session,
    this.episodeNumber,
    this.onSaveProgress,
  });

  const KitPlayHooks.none()
      : session = null,
        episodeNumber = null,
        onSaveProgress = null;

  final PlaySession? session;
  final num? episodeNumber;
  final Future<void> Function(Duration position, Duration duration)?
      onSaveProgress;

  Future<void> seedInitial({required Movie movie}) async {
    await seedPlayWatchHistory(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
    );
  }
}

KitPlayHooks buildPlayHooks({
  required Movie movie,
  int? season,
  int? episode,
  MetaOpen? open,
  int? malId,
  String? audioCategory,
  String? pluginId,
  MetaItem? meta,
  PlaySession? playSession,
}) {
  final resolvedOpen = open ?? meta?.open;
  if (resolvedOpen == null && meta == null && playSession == null) {
    return const KitPlayHooks.none();
  }

  final ep = episode ?? (hubMediaIsEpisodic(movie) ? (season ?? 1) : null);
  final session = playSession ??
      PlaySession(
        pluginId: pluginId,
        metaItem: meta,
        metaOpen: resolvedOpen,
        malId: malId,
        audioCategory: audioCategory,
      );
  if (!playNeedsWatchHistory(session)) {
    return const KitPlayHooks.none();
  }

  return KitPlayHooks(
    session: session,
    episodeNumber: ep,
    onSaveProgress: catalogPlaySaveProgressCallback(
      session: session,
      movie: movie,
      episodeNumber: ep,
    ),
  );
}

bool playNeedsWatchHistory(PlaySession? session) {
  if (session == null) return false;
  return session.pluginId != null && session.metaItem != null;
}

Future<void> _recordWatchHistory({
  required PlaySession session,
  required int ep,
  Duration? position,
  Duration? duration,
}) async {
  final pluginId = session.pluginId;
  final meta = session.metaItem;
  if (pluginId == null || meta == null) return;
  await WatchHistory.record(
    pluginId: pluginId,
    meta: meta,
    episodeNumber: ep,
    episodeVideoId: session.episodeVideoIdFor(ep),
    extras: {
      if (session.audioCategory != null) 'category': session.audioCategory,
    },
    position: position,
    duration: duration,
  );
}

Movie movieWithResolvedArt(Movie movie) {
  final poster = movie.posterPath.trim();
  final backdropRaw =
      movie.backdropPath.trim().isNotEmpty ? movie.backdropPath : poster;
  String resolve(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http')) {
      return u.replaceAll('media.themoviedb.org/t/p', 'image.tmdb.org/t/p');
    }
    return u;
  }

  return movie.copyWith(
    posterPath: resolve(poster),
    backdropPath: resolve(backdropRaw),
  );
}

int? _catalogWatchEpisode(num? episodeNumber, Movie movie) {
  final ep = episodeNumber?.round();
  if (ep != null && ep > 0) return ep;
  return 1;
}

Future<void> seedPlayWatchHistory({
  required PlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerKitEpisode>? episodes,
}) async {
  if (session == null || !playNeedsWatchHistory(session)) return;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return;
  await _recordWatchHistory(session: session, ep: ep);
}

Future<void> seedEngineWatchHistory({
  required PlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerKitEpisode>? episodes,
}) =>
    seedPlayWatchHistory(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
      episodes: episodes,
    );

Future<void> Function(Duration position, Duration duration)?
catalogPlaySaveProgressCallback({
  required PlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerKitEpisode>? episodes,
}) {
  if (session == null || !playNeedsWatchHistory(session)) return null;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return null;

  return (pos, dur) async {
    await _recordWatchHistory(
      session: session,
      ep: ep,
      position: pos,
      duration: dur,
    );
    await _syncEpisodeWatched(session: session, ep: ep, pos: pos, dur: dur);
  };
}

Future<void> Function(Duration position, Duration duration)?
hubEngineSaveProgressCallback({
  required PlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerKitEpisode>? episodes,
}) =>
    catalogPlaySaveProgressCallback(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
      episodes: episodes,
    );

Future<void> _syncEpisodeWatched({
  required PlaySession session,
  required int ep,
  required Duration pos,
  required Duration dur,
}) async {
  final pluginId = session.pluginId;
  final meta = session.metaItem;
  final open = session.effectiveOpen;
  final mediaId = open?.idInt;
  if (pluginId == null || meta == null || open == null || mediaId == null) {
    return;
  }

  final catalog = pluginId;
  await EpisodeWatchedService()
      .markWatchedIfFinished(
        mediaId: mediaId,
        season: 1,
        episode: ep,
        positionMs: pos.inMilliseconds,
        durationMs: dur.inMilliseconds,
        catalog: catalog,
      )
      .then((marked) async {
        if (!marked) return;
        final target = ListFollowTarget.fromMeta(
          pluginId: pluginId,
          meta: meta,
        );
        if (target == null) return;
        ListFollow.syncEpisodeWatched(target, episode: ep);
        await ListFollowFromWatched.applyHubAfterAutoMark(
          target: target,
          mediaId: mediaId,
          catalog: catalog,
          totalEpisodes: meta.episodes ?? ep,
        );
      });
}
