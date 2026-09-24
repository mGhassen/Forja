import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/details_meta.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shared/player/sources/resolve/stream_play_hooks.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shared/player/sources/kit/kit_sources.dart';
import 'package:rust/rust.dart';

PlaySession _sessionFromContext(PlayContext ctx) {
  final meta = ctx.metaItem;
  return PlaySession(
    pluginId: ctx.pluginId,
    metaItem: meta,
    metaOpen: ctx.effectiveOpen,
    malId: ctx.malId,
    episodeVideoIdByNumber: ctx.episodeVideoIdByNumber,
    audioCategory: ctx.audioCategory,
    useHomeEpisodeWatched:
        meta != null && hubMetaUsesHomeWatchHistory(meta),
  );
}

/// Shared hub details play dispatch — green Play is always [runEngineAutoPlay]
/// (same Forja race as Home). IPTV is the only extract-type fork.
Future<void> runPlayFromContext({
  required BuildContext context,
  required PlayContext ctx,
}) {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    final play = KitStreamPlayHooks.playPortalFromContext;
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

/// Details Download CTA — opens Sources so the user picks a stream via the
/// row download icon (hover / focus).
Future<void> runDownloadFromContext({
  required BuildContext context,
  required PlayContext ctx,
}) async {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    ForjaToast.info('IPTV channels can’t be saved offline');
    return;
  }

  ForjaToast.info(
    'Hover a source and tap download',
    duration: const Duration(seconds: 3),
  );
  await openSourcesFromContext(context: context, ctx: ctx);
}
