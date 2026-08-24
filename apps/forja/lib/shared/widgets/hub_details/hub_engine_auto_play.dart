import 'package:flutter/material.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

/// Hub alias — same Settings gate as movies/TV green Play Forja Auto.
Future<bool> hubEngineAutoPlayEnabled([SettingsService? settings]) =>
    engineAutoPlayEnabled(settings);

/// Anime / Asian Drama green Play → shared [runEngineAutoPlay] (Sources → Forja).
Future<void> runHubEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  required String engineCategory,
  int? season,
  int? episode,
  int? kisskhId,
  int? kisskhEpisodeId,
  Map<int, int> kisskhEpisodeIdByNumber = const {},
  int? anilistId,
  int? malId,
  String? animeAudioCategory,
  Duration? startPosition,
  String? loadingSubtitle,
  List<PlayerHubEpisode>? hubEpisodes,
}) {
  final mergedKisskh = {
    ...kisskhEpisodeIdByNumber,
    if (kisskhEpisodeId != null && episode != null) episode: kisskhEpisodeId,
  };
  return runEngineAutoPlay(
    context: context,
    movie: movie,
    engineCategory: engineCategory,
    season: season,
    episode: episode,
    kisskhId: kisskhId,
    kisskhEpisodeId: kisskhEpisodeId,
    anilistId: anilistId,
    malId: malId,
    animeAudioCategory: animeAudioCategory,
    startPosition: startPosition,
    loadingSubtitle: loadingSubtitle,
    hubEpisodes: hubEpisodes,
    hubEpisodeNumber: episode,
    enginePlaySession: EnginePlaySession(
      category: engineCategory,
      anilistId: anilistId,
      malId: malId,
      kisskhId: kisskhId,
      kisskhEpisodeIdByNumber: mergedKisskh,
    ),
  );
}
