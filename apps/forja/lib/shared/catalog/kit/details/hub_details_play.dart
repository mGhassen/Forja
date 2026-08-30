import 'package:flutter/material.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/playback/hub_play_context.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';

EnginePlaySession _sessionFromContext(HubPlayContext ctx) {
  return EnginePlaySession(
    category: ctx.engineCategory,
    pluginId: ctx.pluginId,
    catalogMeta: ctx.catalogMeta,
    catalogOpen: ctx.effectiveOpen,
    malId: ctx.malId,
    episodeVideoIdByNumber: ctx.episodeVideoIdByNumber,
    animeAudioCategory: ctx.animeAudioCategory,
  );
}

/// Shared hub details play dispatch — green Play and Sources panel.
Future<void> runHubPlayFromContext({
  required BuildContext context,
  required HubPlayContext ctx,
}) {
  final session = _sessionFromContext(ctx);
  return runEngineAutoPlay(
    context: context,
    movie: ctx.movie,
    engineCategory: ctx.engineCategory,
    season: ctx.season,
    episode: ctx.episode,
    malId: ctx.malId,
    animeAudioCategory: ctx.animeAudioCategory,
    startPosition: ctx.startPosition,
    preferredPluginId: ctx.preferredPluginId,
    savedStreamUrl: ctx.savedStreamUrl,
    loadingSubtitle: ctx.loadingSubtitle,
    hubEpisodes: ctx.hubEpisodes,
    hubEpisodeNumber: ctx.episode,
    selectedPluginIds: ctx.selectedPluginIds,
    enginePlaySession: session,
  );
}

Future<void> openHubSourcesFromContext({
  required BuildContext context,
  required HubPlayContext ctx,
}) {
  final session = _sessionFromContext(ctx);
  final resolve = session.resolveForEpisode(ctx.episode);
  return openHubCatalogSources(
    context: context,
    movie: ctx.movie,
    season: ctx.season,
    episode: ctx.episode,
    catalogOpen: ctx.effectiveOpen,
    malId: resolve.malId ?? ctx.malId,
    anilistId: resolve.anilistId,
    kisskhId: resolve.kisskhId,
    kisskhEpisodeId: resolve.kisskhEpisodeId,
    arabicVideoId: resolve.arabicVideoId,
    episodeVideoId: session.episodeVideoIdFor(ctx.episode ?? 1),
    engineCategory: ctx.engineCategory,
    animeAudioCategory: ctx.animeAudioCategory,
    enginePlaySession: session,
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
