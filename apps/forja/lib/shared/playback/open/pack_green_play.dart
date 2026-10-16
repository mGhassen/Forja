import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/details_meta.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/models/plugin_language.dart';
import 'package:forja/shared/engine/packs/settings/pack_green_play_config.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shell/feedback/forja_toast.dart';

/// Pack-owned green Play (RFC-118) — Forja providers only.
///
/// Preferred providers from hub settings are tried first; empty preferred
/// races all enabled Forja HTTP plugins (host fallback when undeclared).
Future<void> runPackGreenPlay({
  required BuildContext context,
  required PlayContext ctx,
}) async {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    return;
  }

  final config = await PackGreenPlayConfig.resolve(ctx.pluginId);
  if (!context.mounted) return;

  final packs = await EngineService.instance.listSourcesPanelPacks();
  if (!context.mounted) return;

  final langKeys = await PluginStreamLanguages.selectedKeys(ctx.pluginId);
  if (!context.mounted) return;
  final audioCategory = ctx.audioCategory ??
      PluginStreamLanguages.audioCategoryFromKeys(langKeys);

  final session = PlaySession(
    pluginId: ctx.pluginId,
    metaItem: ctx.metaItem,
    metaOpen: ctx.effectiveOpen,
    malId: ctx.malId,
    episodeVideoIdByNumber: ctx.episodeVideoIdByNumber,
    audioCategory: audioCategory,
    useHomeEpisodeWatched:
        ctx.metaItem != null && hubMetaUsesHomeWatchHistory(ctx.metaItem!),
  );
  final category = engineCategoryForSession(session, ctx.movie) ?? 'movie';

  final enabled = enabledEnginePluginIds(packs);
  final scope = EngineCategories.matchingPluginIds(
    packs: packs,
    categories: EngineCategories.defaultsForPanelCategory(category),
  );
  final available = [
    for (final id in orderedEnginePluginIds(packs))
      if (enabled.contains(id) && scope.contains(id)) id,
  ];

  // Language filter narrows hub-scoped plugins only — never pulls other hubs.
  final langFiltered = PluginStreamLanguages.filterPluginIds(
    packs: packs,
    ids: available,
    selected: langKeys,
  );

  // Preferred first (settings order), then the rest of enabled plugins.
  final preferred = config
      .providerPrefs(PackGreenPlayTechs.engine)
      .preferred
      .where(langFiltered.contains)
      .toList();
  final ordered = [
    ...preferred,
    for (final id in langFiltered)
      if (!preferred.contains(id)) id,
  ];
  if (ordered.isEmpty) {
    if (context.mounted) {
      ForjaToast.info(
        langKeys.isEmpty
            ? 'No Forja providers are enabled for green Play'
            : 'No Forja providers match the selected languages',
      );
    }
    return;
  }

  final resumePin = ctx.preferredPluginId?.trim();
  final pin = (resumePin != null &&
          resumePin.isNotEmpty &&
          ordered.contains(resumePin))
      ? resumePin
      : (preferred.isNotEmpty ? preferred.first : null);

  await runEngineAutoPlay(
    context: context,
    movie: ctx.movie,
    engineCategory: category,
    season: ctx.season,
    episode: ctx.episode,
    malId: ctx.malId,
    audioCategory: audioCategory,
    startPosition: ctx.startPosition,
    preferredPluginId: pin,
    savedStreamUrl: ctx.savedStreamUrl,
    loadingSubtitle: ctx.loadingSubtitle,
    episodes: ctx.kitEpisodes,
    hubEpisodeNumber: ctx.episode,
    selectedPluginIds: ordered.toSet(),
    racePluginOrder: ordered,
    packs: packs,
    playSession: session,
  );
}
