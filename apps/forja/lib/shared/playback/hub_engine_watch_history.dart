import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/list_follow_from_watched.dart';
import 'package:rust/rust.dart';

/// Hub tab media types — never written to Home [`watch_history`].
bool isHubTabMediaType(String? mediaType) {
  switch (mediaType) {
    case 'asian_drama':
    case 'anime':
      return true;
    default:
      return false;
  }
}

bool hubMediaIsEpisodic(Movie movie) {
  switch (movie.mediaType) {
    case 'tv':
    case 'asian_drama':
    case 'anime':
      return true;
    default:
      return false;
  }
}

bool isHomeTabWatchHistoryEntry(Map<String, dynamic> item) {
  if (isHubTabMediaType(item['mediaType'] as String?)) return false;
  if (watchHistoryInt(item['tmdbId'], -1) < 0) return false;
  return true;
}

bool usesHomeWatchHistory({
  required Movie? movie,
  List<PlayerHubEpisode>? hubEpisodes,
  Future<void> Function(Duration position, Duration duration)? onSaveProgress,
  EnginePlaySession? enginePlaySession,
}) {
  if (movie == null) return false;
  if (hubEpisodes != null) return false;
  if (onSaveProgress != null) return false;
  if (enginePlaySession != null &&
      hubEngineNeedsWatchHistory(enginePlaySession)) {
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

  final EnginePlaySession? session;
  final num? episodeNumber;
  final Future<void> Function(Duration position, Duration duration)?
      onSaveProgress;

  Future<void> seedInitial({required Movie movie}) async {
    await seedHubEngineWatchHistory(
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
  int? kisskhId,
  int? kisskhEpisodeId,
  String? arabicVideoId,
  int? anilistId,
  int? malId,
  String? engineCategory,
  String? animeAudioCategory,
  String? pluginId,
  CatalogMetaItem? catalogMeta,
}) {
  final category = engineCategory ??
      (kisskhId != null
          ? EngineCategories.drama
          : anilistId != null
              ? EngineCategories.anime
              : (arabicVideoId != null && arabicVideoId.isNotEmpty)
                  ? EngineCategories.arabic
                  : null);
  if (category == null ||
      (kisskhId == null &&
          anilistId == null &&
          (arabicVideoId ?? '').isEmpty &&
          catalogMeta == null)) {
    return const HubCatalogPlayHooks.none();
  }

  final ep = episode ?? (hubMediaIsEpisodic(movie) ? (season ?? 1) : null);
  final session = EnginePlaySession(
    category: category,
    pluginId: pluginId,
    catalogMeta: catalogMeta,
    anilistId: anilistId,
    malId: malId,
    kisskhId: kisskhId,
    kisskhEpisodeIdByNumber: kisskhEpisodeId != null && ep != null
        ? {ep: kisskhEpisodeId}
        : const {},
    arabicVideoIdByEpisode: arabicVideoId != null &&
            arabicVideoId.isNotEmpty &&
            ep != null
        ? {ep: arabicVideoId}
        : const {},
    animeAudioCategory: animeAudioCategory,
  );
  if (!hubEngineNeedsWatchHistory(session)) {
    return const HubCatalogPlayHooks.none();
  }

  return HubCatalogPlayHooks(
    session: session,
    episodeNumber: ep,
    onSaveProgress: hubEngineSaveProgressCallback(
      session: session,
      movie: movie,
      episodeNumber: ep,
    ),
  );
}

bool hubEngineNeedsWatchHistory(EnginePlaySession? session) {
  if (session == null) return false;
  if (session.pluginId != null && session.catalogMeta != null) return true;
  return session.category == EngineCategories.anime ||
      session.category == EngineCategories.drama;
}

String? _episodeVideoId(EnginePlaySession session, int ep) {
  if (session.category == EngineCategories.drama) {
    final id = session.kisskhEpisodeIdFor(ep);
    return id != null && id > 0 ? id.toString() : null;
  }
  if (session.category == EngineCategories.arabic) {
    return session.arabicVideoIdFor(ep);
  }
  return null;
}

Future<void> _recordCatalogWatchHistory({
  required EnginePlaySession session,
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
    episodeVideoId: _episodeVideoId(session, ep),
    extras: {
      if (session.animeAudioCategory != null)
        'category': session.animeAudioCategory,
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

Future<void> seedHubEngineWatchHistory({
  required EnginePlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) async {
  if (session == null || !hubEngineNeedsWatchHistory(session)) return;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return;
  await _recordCatalogWatchHistory(session: session, ep: ep);
}

Future<void> Function(Duration position, Duration duration)?
hubEngineSaveProgressCallback({
  required EnginePlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) {
  if (session == null || !hubEngineNeedsWatchHistory(session)) return null;
  final ep = _catalogWatchEpisode(episodeNumber, movie);
  if (ep == null) return null;

  if (session.pluginId != null && session.catalogMeta != null) {
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

  return null;
}

Future<void> _syncEpisodeWatched({
  required EnginePlaySession session,
  required int ep,
  required Duration pos,
  required Duration dur,
}) async {
  if (session.category == EngineCategories.anime && session.anilistId != null) {
    await EpisodeWatchedService()
        .markWatchedIfFinished(
          mediaId: session.anilistId!,
          season: 1,
          episode: ep,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          catalog: EpisodeWatchedService.catalogAnilist,
        )
        .then((marked) async {
          if (!marked) return;
          final meta = session.catalogMeta;
          final target = HubListFollowTarget.anime(
            anilistId: session.anilistId!,
            title: meta?.name ?? '',
            posterPath: meta?.poster ?? '',
          );
          HubListFollow.syncEpisodeWatched(target, episode: ep);
          await ListFollowFromWatched.applyHubAfterAutoMark(
            target: target,
            mediaId: session.anilistId!,
            catalog: EpisodeWatchedService.catalogAnilist,
            totalEpisodes: meta?.episodes ?? ep,
          );
        });
    return;
  }

  if (session.category == EngineCategories.drama && session.kisskhId != null) {
    await EpisodeWatchedService()
        .markWatchedIfFinished(
          mediaId: session.kisskhId!,
          season: 1,
          episode: ep,
          positionMs: pos.inMilliseconds,
          durationMs: dur.inMilliseconds,
          catalog: EpisodeWatchedService.catalogKisskh,
        )
        .then((marked) async {
          if (!marked) return;
          final meta = session.catalogMeta;
          final target = HubListFollowTarget.drama(
            kisskhId: session.kisskhId!,
            title: meta?.name ?? '',
            posterPath: meta?.poster ?? '',
            releaseDate: meta?.releaseInfo ?? '',
          );
          HubListFollow.syncEpisodeWatched(target, episode: ep);
          await ListFollowFromWatched.applyHubAfterAutoMark(
            target: target,
            mediaId: session.kisskhId!,
            catalog: EpisodeWatchedService.catalogKisskh,
            totalEpisodes: meta?.episodes ?? ep,
          );
        });
  }
}
