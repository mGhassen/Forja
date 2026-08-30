import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/playback/hub_play_context.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:rust/rust.dart';

/// Hub alias — VOD green Play always uses provider JS via [runEngineAutoPlay].
Future<bool> hubEngineAutoPlayEnabled([SettingsService? settings]) =>
    engineAutoPlayEnabled(settings);

/// Anime / Asian Drama / Arabic green Play → shared engine auto path.
Future<void> runHubEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  required String engineCategory,
  CatalogOpen? catalogOpen,
  CatalogMetaItem? catalogMeta,
  String? pluginId,
  int? season,
  int? episode,
  int? malId,
  Map<int, String> episodeVideoIdByNumber = const {},
  String? animeAudioCategory,
  Duration? startPosition,
  String? preferredPluginId,
  String? savedStreamUrl,
  String? loadingSubtitle,
  List<PlayerHubEpisode>? hubEpisodes,
  Set<String>? selectedPluginIds,
}) {
  return runHubPlayFromContext(
    context: context,
    ctx: HubPlayContext(
      movie: movie,
      engineCategory: engineCategory,
      pluginId: pluginId,
      catalogMeta: catalogMeta,
      catalogOpen: catalogOpen ?? catalogMeta?.open,
      season: season,
      episode: episode,
      malId: malId,
      episodeVideoIdByNumber: episodeVideoIdByNumber,
      animeAudioCategory: animeAudioCategory,
      startPosition: startPosition,
      preferredPluginId: preferredPluginId,
      savedStreamUrl: savedStreamUrl,
      loadingSubtitle: loadingSubtitle,
      hubEpisodes: hubEpisodes,
      selectedPluginIds: selectedPluginIds,
    ),
  );
}
