import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
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

/// True when episodic hub rows use season/episode (not plain `tv` only).
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

/// Home Continue Watching pool — excludes hub-tab rows that leaked before enforcement.
bool isHomeTabWatchHistoryEntry(Map<String, dynamic> item) {
  if (isHubTabMediaType(item['mediaType'] as String?)) return false;
  if (watchHistoryInt(item['tmdbId'], -1) < 0) return false;
  return true;
}

/// Whether this player session should persist to Home [`watch_history`].
bool usesHomeWatchHistory({
  required Movie? movie,
  List<PlayerHubEpisode>? hubEpisodes,
  Future<void> Function(Duration position, Duration duration)? onSaveProgress,
  EnginePlaySession? enginePlaySession,
}) {
  if (movie == null) return false;
  if (hubEpisodes != null) return false;
  if (onSaveProgress != null) return false;
  if (enginePlaySession != null && hubEngineNeedsWatchHistory(enginePlaySession)) {
    return false;
  }
  if (isHubTabMediaType(movie.mediaType)) return false;
  if (movie.id < 0) return false;
  return true;
}

/// Hooks for catalog Sources opened from anime / Asian Drama details.
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
      (kisskhId == null && anilistId == null && (arabicVideoId ?? '').isEmpty)) {
    return const HubCatalogPlayHooks.none();
  }

  final ep = episode ?? (hubMediaIsEpisodic(movie) ? (season ?? 1) : null);
  final session = EnginePlaySession(
    category: category,
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
  return session.category == EngineCategories.anime ||
      session.category == EngineCategories.drama;
}

AnimeCard _animeCardFromHub(Movie movie, int anilistId) {
  final title = movie.title.trim();
  return AnimeCard(
    id: anilistId,
    titleEnglish: title,
    titleRomaji: title,
    titleNative: '',
    coverLarge: movie.posterPath,
    bannerImage: movie.backdropPath.isNotEmpty ? movie.backdropPath : null,
    episodes: movie.numberOfEpisodes,
    duration: movie.runtime > 0 ? movie.runtime : null,
    description: movie.overview,
    genres: movie.genres,
    seasonYear: int.tryParse(movie.releaseDate),
  );
}

KdramaCard _dramaCardFromHub(Movie movie, int kisskhId) {
  return KdramaCard(
    id: kisskhId,
    title: movie.title,
    cover: KissKhService.resolveCoverUrl(movie.posterPath),
    episodesCount: movie.numberOfEpisodes,
  );
}

/// TMDB poster/backdrop keys saved on hub [Movie] rows must be full URLs in player UI.
Movie movieWithResolvedHubArt(Movie movie) {
  final poster = KissKhService.resolveCoverUrl(movie.posterPath);
  final backdropRaw =
      movie.backdropPath.trim().isNotEmpty ? movie.backdropPath : movie.posterPath;
  return movie.copyWith(
    posterPath: poster,
    backdropPath: KissKhService.resolveCoverUrl(backdropRaw),
  );
}
List<KdramaEpisode> _dramaEpisodesFromHub(
  List<PlayerHubEpisode>? hubEpisodes,
  EnginePlaySession session,
) {
  if (hubEpisodes == null || hubEpisodes.isEmpty) return const [];
  return [
    for (final hub in hubEpisodes)
      KdramaEpisode(
        id: session.kisskhEpisodeIdFor(hub.number.round()) ?? 0,
        number: hub.number.toDouble(),
      ),
  ];
}

/// Stamp CW row when Forja Engine Auto opens a hub player (anime / drama).
Future<void> seedHubEngineWatchHistory({
  required EnginePlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) async {
  if (session == null || !hubEngineNeedsWatchHistory(session)) return;
  final ep = episodeNumber?.round();
  if (ep == null || ep <= 0) return;

  if (session.category == EngineCategories.anime && session.anilistId != null) {
    await AnimeService().recordWatch(
      anime: _animeCardFromHub(movie, session.anilistId!),
      episodeNumber: ep,
      category: session.animeAudioCategory ?? 'sub',
    );
    return;
  }

  if (session.category == EngineCategories.drama && session.kisskhId != null) {
    final episodes = _dramaEpisodesFromHub(hubEpisodes, session);
    final episodeId = session.kisskhEpisodeIdFor(ep);
    await KissKhService().recordWatch(
      drama: _dramaCardFromHub(movie, session.kisskhId!),
      episodeNumber:
          episodeNumber != null ? episodeNumber.toDouble() : ep.toDouble(),
      episodeId: episodeId != null && episodeId > 0 ? episodeId : null,
      episodes: episodes,
      totalEpisodes: episodes.isNotEmpty ? episodes.length : ep,
    );
  }
}

Future<void> Function(Duration position, Duration duration)?
hubEngineSaveProgressCallback({
  required EnginePlaySession? session,
  required Movie movie,
  required num? episodeNumber,
  List<PlayerHubEpisode>? hubEpisodes,
}) {
  if (session == null || !hubEngineNeedsWatchHistory(session)) return null;
  final ep = episodeNumber?.round();
  if (ep == null || ep <= 0) return null;

  if (session.category == EngineCategories.anime && session.anilistId != null) {
    final anime = _animeCardFromHub(movie, session.anilistId!);
    final category = session.animeAudioCategory ?? 'sub';
    return (pos, dur) async {
      await AnimeService().recordWatch(
        anime: anime,
        episodeNumber: ep,
        category: category,
        position: pos,
        duration: dur,
      );
      await EpisodeWatchedService()
          .markWatchedIfFinished(
            mediaId: anime.id,
            season: 1,
            episode: ep,
            positionMs: pos.inMilliseconds,
            durationMs: dur.inMilliseconds,
            catalog: EpisodeWatchedService.catalogAnilist,
          )
          .then((marked) async {
            if (!marked) return;
            final target = HubListFollowTarget.anime(
              anilistId: anime.id,
              title: anime.displayTitle,
              posterPath: anime.coverUrl,
            );
            HubListFollow.syncEpisodeWatched(
              target,
              episode: ep,
            );
            await ListFollowFromWatched.applyHubAfterAutoMark(
              target: target,
              mediaId: anime.id,
              catalog: EpisodeWatchedService.catalogAnilist,
              totalEpisodes: anime.episodes ?? ep,
            );
          });
    };
  }

  if (session.category == EngineCategories.drama && session.kisskhId != null) {
    final drama = _dramaCardFromHub(movie, session.kisskhId!);
    final episodes = _dramaEpisodesFromHub(hubEpisodes, session);
    final episodeId = session.kisskhEpisodeIdFor(ep);
    final epNum = (episodeNumber ?? ep.toDouble()).toDouble();
    return (pos, dur) async {
      await KissKhService().recordWatch(
        drama: drama,
        episodeNumber: epNum,
        episodeId: episodeId != null && episodeId > 0 ? episodeId : null,
        episodes: episodes,
        totalEpisodes: episodes.isNotEmpty ? episodes.length : ep,
        position: pos,
        duration: dur,
      );
      final index = episodes.indexWhere(
        (e) => episodeId != null && episodeId > 0
            ? e.id == episodeId
            : e.number == epNum,
      );
      final epKey = index >= 0 ? index + 1 : ep;
      await EpisodeWatchedService()
          .markWatchedIfFinished(
            mediaId: drama.id,
            season: 1,
            episode: epKey,
            positionMs: pos.inMilliseconds,
            durationMs: dur.inMilliseconds,
            catalog: EpisodeWatchedService.catalogKisskh,
          )
          .then((marked) async {
            if (!marked) return;
            final target = HubListFollowTarget.drama(
              kisskhId: drama.id,
              title: drama.title,
              posterPath: drama.cover,
              releaseDate: drama.year ?? '',
              kissKhType: drama.type,
            );
            HubListFollow.syncEpisodeWatched(
              target,
              episode: epKey,
            );
            await ListFollowFromWatched.applyHubAfterAutoMark(
              target: target,
              mediaId: drama.id,
              catalog: EpisodeWatchedService.catalogKisskh,
              totalEpisodes: episodes.isNotEmpty ? episodes.length : ep,
            );
          });
    };
  }

  return null;
}
