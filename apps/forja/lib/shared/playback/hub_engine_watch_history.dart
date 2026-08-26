import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/features/asian_drama/catalog/kisskh_service.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:rust/rust.dart';

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
    cover: KissKhService.normalizeCoverUrl(movie.posterPath),
    episodesCount: movie.numberOfEpisodes,
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
          .then((marked) {
            if (!marked) return;
            HubListFollow.syncEpisodeWatched(
              HubListFollowTarget.anime(
                anilistId: anime.id,
                title: anime.displayTitle,
                posterPath: anime.coverUrl,
              ),
              episode: ep,
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
          .then((marked) {
            if (!marked) return;
            HubListFollow.syncEpisodeWatched(
              HubListFollowTarget.drama(
                kisskhId: drama.id,
                title: drama.title,
                posterPath: drama.cover,
                releaseDate: drama.year ?? '',
                kissKhType: drama.type,
              ),
              episode: epKey,
            );
          });
    };
  }

  return null;
}
