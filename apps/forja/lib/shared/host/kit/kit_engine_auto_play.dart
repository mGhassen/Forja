import 'package:flutter/material.dart';
import 'package:forja/shared/host/kit/kit_details_play.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';
import 'package:rust/rust.dart';

/// Hub alias — VOD green Play always uses provider JS via [runEngineAutoPlay].
Future<bool> kitEngineAutoPlayEnabled([SettingsService? settings]) =>
    engineAutoPlayEnabled(settings);

/// Anime / Asian Drama / Arabic green Play → shared engine auto path.
Future<void> runKitEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  MetaOpen? open,
  MetaItem? meta,
  String? pluginId,
  int? season,
  int? episode,
  int? malId,
  Map<int, String> episodeVideoIdByNumber = const {},
  String? audioCategory,
  Duration? startPosition,
  String? preferredPluginId,
  String? savedStreamUrl,
  String? loadingSubtitle,
  List<PlayerKitEpisode>? episodes,
  Set<String>? selectedPluginIds,
}) {
  return runPlayFromContext(
    context: context,
    ctx: PlayContext(
      movie: movie,
      pluginId: pluginId,
      metaItem: meta,
      metaOpen: open ?? meta?.open,
      season: season,
      episode: episode,
      malId: malId,
      episodeVideoIdByNumber: episodeVideoIdByNumber,
      audioCategory: audioCategory,
      startPosition: startPosition,
      preferredPluginId: preferredPluginId,
      savedStreamUrl: savedStreamUrl,
      loadingSubtitle: loadingSubtitle,
      kitEpisodes: episodes,
      selectedPluginIds: selectedPluginIds,
    ),
  );
}
