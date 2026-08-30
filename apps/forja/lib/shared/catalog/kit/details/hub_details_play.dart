import 'package:flutter/material.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/playback/hub_play_context.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';

/// Shared hub details play dispatch — green Play and Sources panel.
Future<void> runHubPlayFromContext({
  required BuildContext context,
  required HubPlayContext ctx,
}) {
  final mergedKisskh = {
    ...ctx.kisskhEpisodeIdByNumber,
    if (ctx.kisskhEpisodeId != null && ctx.episode != null)
      ctx.episode!: ctx.kisskhEpisodeId!,
  };
  final mergedArabic = {
    ...ctx.arabicVideoIdByEpisode,
    if (ctx.arabicVideoId != null &&
        ctx.arabicVideoId!.isNotEmpty &&
        ctx.episode != null)
      ctx.episode!: ctx.arabicVideoId!,
  };
  return runEngineAutoPlay(
    context: context,
    movie: ctx.movie,
    engineCategory: ctx.engineCategory,
    season: ctx.season,
    episode: ctx.episode,
    kisskhId: ctx.kisskhId,
    kisskhEpisodeId: ctx.kisskhEpisodeId,
    arabicVideoId: ctx.arabicVideoId,
    anilistId: ctx.anilistId,
    malId: ctx.malId,
    animeAudioCategory: ctx.animeAudioCategory,
    startPosition: ctx.startPosition,
    preferredPluginId: ctx.preferredPluginId,
    savedStreamUrl: ctx.savedStreamUrl,
    loadingSubtitle: ctx.loadingSubtitle,
    hubEpisodes: ctx.hubEpisodes,
    hubEpisodeNumber: ctx.episode,
    selectedPluginIds: ctx.selectedPluginIds,
    enginePlaySession: EnginePlaySession(
      category: ctx.engineCategory,
      pluginId: ctx.pluginId,
      catalogMeta: ctx.catalogMeta,
      anilistId: ctx.anilistId,
      malId: ctx.malId,
      kisskhId: ctx.kisskhId,
      kisskhEpisodeIdByNumber: mergedKisskh,
      arabicVideoIdByEpisode: mergedArabic,
      animeAudioCategory: ctx.animeAudioCategory,
    ),
  );
}

Future<void> openHubSourcesFromContext({
  required BuildContext context,
  required HubPlayContext ctx,
}) {
  return openHubCatalogSources(
    context: context,
    movie: ctx.movie,
    season: ctx.season,
    episode: ctx.episode,
    anilistId: ctx.anilistId,
    malId: ctx.malId,
    kisskhId: ctx.kisskhId,
    kisskhEpisodeId: ctx.kisskhEpisodeId,
    arabicVideoId: ctx.arabicVideoId,
    engineCategory: ctx.engineCategory,
    animeAudioCategory: ctx.animeAudioCategory,
  );
}

/// TV focus helper after player closes — shared by hub details screens.
Future<void> hubDetailsAfterPlayClosed({
  required ScrollController scrollController,
  required FocusNode heroPlayFocus,
  required bool Function() isMounted,
}) async {
  if (!isMounted()) return;
  if (scrollController.hasClients) {
    scrollController.jumpTo(0);
  }
  ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit(
    heroPlayFocus,
    isMounted: isMounted,
  );
}
