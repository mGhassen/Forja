import 'package:forja/shared/catalog/kit/play/catalog_play_session.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/list_follow_from_watched.dart';
import 'package:rust/rust.dart';

/// Hub tab media types — episodic catalog rows, not Home TMDB watch history.
bool isHubTabMediaType(String? mediaType) {
  if (mediaType == null || mediaType.isEmpty) return false;
  return mediaType != 'movie' && mediaType != 'tv';
}

bool hubMediaIsEpisodic(Movie movie) {
  final t = movie.mediaType;
  if (t == 'tv') return true;
  // Pack-emitted types (anime, drama, …) — anything that isn't Home movie/tv.
  return isHubTabMediaType(t);
}

bool usesHomeWatchHistory({
  required Movie? movie,
  List<PlayerHubEpisode>? hubEpisodes,
  Future<void> Function(Duration position, Duration duration)? onSaveProgress,
  CatalogPlaySession? catalogPlaySession,
}) {
  if (movie == null) return false;
  if (hubEpisodes != null) return false;
  if (onSaveProgress != null) return false;
  if (catalogPlaySession != null &&
      catalogPlayNeedsWatchHistory(catalogPlaySession)) {
    return false;
  }
  if (isHubTabMediaType(movie.mediaType)) return false;
  if (movie.id < 0) return false;
  return true;
}

class HubCatalogPlayHooks {
  const HubCatalogPlayHooks({
    this.session,
    this.episodeNumber,
    this.onSaveProgress,
  });

  const HubCatalogPlayHooks.none()
      : session = null,
        episodeNumber = null,
        onSaveProgress = null;

  final CatalogPlaySession? session;
  final num? episodeNumber;
  final Future<void> Function(Duration position, Duration duration)?
      onSaveProgress;

  Future<void> seedInitial({required Movie movie}) async {
    await seedCatalogPlayWatchHistory(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
    );
  }
}

HubCatalogPlayHooks buildHubCatalogPlayHooks({
  required Movie movie,
  int? season,
  int? episode,
  CatalogOpen? catalogOpen,
  int? malId,
  String? audioCategory,
  String? pluginId,
  CatalogMetaItem? catalogMeta,
  CatalogPlaySession? catalogPlaySession,
}) {
  final open = catalogOpen ?? catalogMeta?.open;
  if (open == null && catalogMeta == null && catalogPlaySession == null) {
    return const HubCatalogPlayHooks.none();
  }

  final ep = episode ?? (hubMediaIsEpisodic(movie) ? (season ?? 1) : null);
  final session = catalogPlaySession ??
      CatalogPlaySession(
        pluginId: pluginId,
        catalogMeta: catalogMeta,
        catalogOpen: open,
        malId: malId,
        audioCategory: audioCategory,
      );
  if (!catalogPlayNeedsWatchHistory(session)) {
    return const HubCatalogPlayHooks.none();
  }

  return HubCatalogPlayHooks(
    session: session,
    episodeNumber: ep,
    onSaveProgress: catalogPlaySaveProgressCallback(
      session: session,
      movie: movie,
      episodeNumber: ep,
    ),
  );
}

bool catalogPlayNeedsWatchHistory(CatalogPlaySession? session) {
  if (session == null) return false;
  return session.pluginId != null && session.catalogMeta != null;
}

Future<void> _recordCatalogWatchHistory({
  required CatalogPlaySession session,
  required int ep,
  Duration? position,
  Duration? duration,
}) async {
  final pluginId = session.pluginId;
  final meta = session.catalogMeta;
  if (pluginId == null || meta == null) return;
  await CatalogWatchHistory.record(
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

Movie movieWithResolvedHubArt(Movie movie) {
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
  return hubMediaIsEpisodic(movie) ? null : 1;
}

Future<void> seedCatalogPlayWatchHistory({
  required CatalogPlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) async {
  if (session == null || !catalogPlayNeedsWatchHistory(session)) return;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return;
  await _recordCatalogWatchHistory(session: session, ep: ep);
}

Future<void> seedHubEngineWatchHistory({
  required CatalogPlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) =>
    seedCatalogPlayWatchHistory(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
      hubEpisodes: hubEpisodes,
    );

Future<void> Function(Duration position, Duration duration)?
catalogPlaySaveProgressCallback({
  required CatalogPlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) {
  if (session == null || !catalogPlayNeedsWatchHistory(session)) return null;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return null;

  return (pos, dur) async {
    await _recordCatalogWatchHistory(
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
  required CatalogPlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) =>
    catalogPlaySaveProgressCallback(
      session: session,
      movie: movie,
      episodeNumber: episodeNumber,
      hubEpisodes: hubEpisodes,
    );

Future<void> _syncEpisodeWatched({
  required CatalogPlaySession session,
  required int ep,
  required Duration pos,
  required Duration dur,
}) async {
  final pluginId = session.pluginId;
  final meta = session.catalogMeta;
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
        final target = CatalogListFollowTarget.fromMeta(
          pluginId: pluginId,
          meta: meta,
        );
        if (target == null) return;
        HubListFollow.syncEpisodeWatched(target, episode: ep);
        await ListFollowFromWatched.applyHubAfterAutoMark(
          target: target,
          mediaId: mediaId,
          catalog: catalog,
          totalEpisodes: meta.episodes ?? ep,
        );
      });
}
