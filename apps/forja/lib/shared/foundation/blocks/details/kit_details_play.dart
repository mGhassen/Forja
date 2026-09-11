import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/blocks/play/play_context.dart';
import 'package:forja/shared/foundation/services/registry/kit_iptv_play_hooks.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/components/details/kit_sources.dart';

PlaySession _sessionFromContext(PlayContext ctx) {
  return PlaySession(
    pluginId: ctx.pluginId,
    metaItem: ctx.metaItem,
    metaOpen: ctx.effectiveOpen,
    malId: ctx.malId,
    episodeVideoIdByNumber: ctx.episodeVideoIdByNumber,
    audioCategory: ctx.audioCategory,
  );
}

/// Shared hub details play dispatch — green Play and Sources panel.
Future<void> runPlayFromContext({
  required BuildContext context,
  required PlayContext ctx,
}) {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    final play = KitIptvPlayHooks.playPortalFromContext;
    if (play == null) return Future.value();
    return play(context: context, ctx: ctx);
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
    episodes: ctx.kitEpisodes,
    hubEpisodeNumber: ctx.episode,
    selectedPluginIds: ctx.selectedPluginIds,
    playSession: session,
  );
}

Future<void> openSourcesFromContext({
  required BuildContext context,
  required PlayContext ctx,
}) {
  final session = _sessionFromContext(ctx);
  return openKitSources(
    context: context,
    movie: ctx.movie,
    season: ctx.season,
    episode: ctx.episode,
    open: ctx.effectiveOpen,
    meta: ctx.metaItem,
    malId: ctx.malId,
    audioCategory: ctx.audioCategory,
    episodeVideoId: ctx.episode != null
        ? ctx.episodeVideoIdByNumber[ctx.episode!]
        : ctx.episodeVideoIdByNumber[1],
    engineCategory: engineCategoryForSession(session, ctx.movie),
    preferredEnginePluginId: ctx.selectedPluginIds?.length == 1
        ? ctx.selectedPluginIds!.first
        : null,
    playSession: session,
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
