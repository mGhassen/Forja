import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/play/catalog_iptv_play.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_context.dart';
import 'package:forja/shared/playback/engine_auto_play.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/hub_details/hub_catalog_sources.dart';

CatalogPlaySession _sessionFromContext(CatalogPlayContext ctx) {
  return CatalogPlaySession(
    pluginId: ctx.pluginId,
    catalogMeta: ctx.catalogMeta,
    catalogOpen: ctx.effectiveOpen,
    malId: ctx.malId,
    episodeVideoIdByNumber: ctx.episodeVideoIdByNumber,
    audioCategory: ctx.audioCategory,
  );
}

/// Shared hub details play dispatch — green Play and Sources panel.
Future<void> runHubPlayFromContext({
  required BuildContext context,
  required CatalogPlayContext ctx,
}) {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    return runIptvPortalPlayFromContext(context: context, ctx: ctx);
  }
  final session = _sessionFromContext(ctx);
  return runEngineAutoPlay(
    context: context,
    movie: ctx.movie,
    engineCategory: engineCategoryForSession(session, ctx.movie) ?? 'movie',
    season: ctx.season,
    episode: ctx.episode,
    malId: ctx.malId,
    audioCategory: ctx.audioCategory,
    startPosition: ctx.startPosition,
    preferredPluginId: ctx.preferredPluginId,
    savedStreamUrl: ctx.savedStreamUrl,
    loadingSubtitle: ctx.loadingSubtitle,
    hubEpisodes: ctx.hubEpisodes,
    hubEpisodeNumber: ctx.episode,
    selectedPluginIds: ctx.selectedPluginIds,
    catalogPlaySession: session,
  );
}

Future<void> openHubSourcesFromContext({
  required BuildContext context,
  required CatalogPlayContext ctx,
}) {
  final session = _sessionFromContext(ctx);
  return openHubCatalogSources(
    context: context,
    movie: ctx.movie,
    season: ctx.season,
    episode: ctx.episode,
    catalogOpen: ctx.effectiveOpen,
    catalogMeta: ctx.catalogMeta,
    malId: ctx.malId,
    audioCategory: ctx.audioCategory,
    episodeVideoId: ctx.episode != null
        ? ctx.episodeVideoIdByNumber[ctx.episode!]
        : ctx.episodeVideoIdByNumber[1],
    engineCategory: engineCategoryForSession(session, ctx.movie),
    preferredEnginePluginId: ctx.selectedPluginIds?.length == 1
        ? ctx.selectedPluginIds!.first
        : null,
    catalogPlaySession: session,
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
