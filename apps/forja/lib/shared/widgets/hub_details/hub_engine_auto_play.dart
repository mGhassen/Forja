import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/engine_catalog_stream_probe.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

typedef _HubEngineAutoExtracted = Map<String, List<Map<String, dynamic>>>;

/// True when Settings → Playback would run movie-style Forja Auto on green Play
/// (Forja on + Auto on + Webstreaming off).
Future<bool> hubEngineAutoPlayEnabled([SettingsService? settings]) async {
  final s = settings ?? SettingsService();
  if (!await PlaySourceEffective.engine(s)) return false;
  if (!await s.isPlaySourceEngineAutoStartEnabled()) return false;
  if (await PlaySourceEffective.webstreaming(s)) return false;
  return true;
}

/// Movie RFC-063 Forja Auto for hub details (Asian Drama / Anime).
Future<void> runHubEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  required String engineCategory,
  int? season,
  int? episode,
  int? kisskhId,
  int? kisskhEpisodeId,
  int? anilistId,
  int? malId,
  Duration? startPosition,
  String? loadingSubtitle,
}) async {
  final settings = SettingsService();
  final profile = PlatformPlayback.capabilities;
  final category = EngineCategories.panelCategoryFor(
    panelCategory: engineCategory,
  );

  var cancelled = false;
  var playGen = 0;
  final fadeOutNotifier = ValueNotifier(false);
  final messageNotifier = ValueNotifier('Finding Forja servers…');
  final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
  final failureNotifier = ValueNotifier<ResolveFailure?>(null);
  BuildContext? loadingDialogContext;
  var openedPlayer = false;

  List<ChangeNotifier> overlayNotifiers() => [
        fadeOutNotifier,
        messageNotifier,
        failureNotifier,
        probeNotifier,
      ];

  void dismissLoading() {
    final ctx = loadingDialogContext;
    loadingDialogContext = null;
    if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
  }

  void cancel() {
    cancelled = true;
    playGen++;
    EngineService.instance.cancelPending();
    dismissLoading();
  }

  bool aborted() => cancelled || !context.mounted;

  showLoadingOverlayDialog(
    context,
    builder: (dialogContext) {
      loadingDialogContext = dialogContext;
      return LoadingOverlay(
        movie: movie,
        messageNotifier: messageNotifier,
        providerProbesNotifier: probeNotifier,
        fadeOutNotifier: fadeOutNotifier,
        failureNotifier: failureNotifier,
        subtitle: loadingSubtitle,
        onCancel: cancel,
      );
    },
  );
  await Future<void>.delayed(Duration.zero);
  if (aborted()) {
    dismissLoading();
    disposeLoadingOverlayNotifiers(overlayNotifiers());
    return;
  }

  try {
    await EngineService.instance.ensureBundledInstalled();
    if (aborted()) return;
    final packs = await EngineService.instance.listSourcesPanelPacks();
    if (aborted()) return;

    final scope = EngineCategories.matchingPluginIds(
      packs: packs,
      categories: EngineCategories.defaultsForPanelCategory(category),
    );
    final pluginIds = [
      for (final id in orderedEnginePluginIds(packs))
        if (scope.contains(id)) id,
    ];

    String labelFor(String pluginId) {
      for (final pack in packs) {
        for (final p in pack.plugins) {
          if (p.id == pluginId) {
            final name = p.name.trim();
            return name.isNotEmpty ? name : pluginId;
          }
        }
      }
      return pluginId;
    }

    if (pluginIds.isEmpty) {
      final action = Completer<void>();
      failureNotifier.value = ResolveFailure(
        title: 'Couldn’t start playback',
        detail:
            'No Forja $category plugins are enabled. Turn some on in Settings → Forja plugins.',
        primaryLabel: 'Close',
        primaryIcon: Icons.close_rounded,
        onPrimary: () {
          if (!action.isCompleted) action.complete();
        },
      );
      await action.future;
      return;
    }

    probeNotifier.value = [
      for (var i = 0; i < pluginIds.length; i++)
        StreamProviderProbe(
          id: pluginIds[i],
          label: labelFor(pluginIds[i]),
          status: StreamProviderProbeStatus.pending,
          isPreferred: i == 0,
        ),
    ];

    final thisGen = ++playGen;
    final isAborted = () => aborted() || thisGen != playGen;

    final extracted = await _extractAllHubEnginePlugins(
      pluginIds: pluginIds,
      labelFor: labelFor,
      movie: movie,
      type: category,
      season: season,
      episode: episode,
      kisskhId: kisskhId,
      kisskhEpisodeId: kisskhEpisodeId,
      anilistId: anilistId,
      malId: malId,
      probeNotifier: probeNotifier,
      messageNotifier: messageNotifier,
      isAborted: isAborted,
      batchLimit: engineSourcesBatchLimit(
        tv: context.mounted && SourcesPanelTv.isTv(context),
      ),
    );
    if (isAborted()) return;

    final allRows = [
      for (final id in pluginIds)
        ...sortEngineCatalogStreamRows(extracted[id] ?? const []),
    ];

    messageNotifier.value = 'Checking streams…';
    final probedSources = await buildProbedEngineCatalogSources(
      profile: profile,
      settings: settings,
      rows: allRows,
      isAborted: isAborted,
      messageNotifier: messageNotifier,
    );
    if (isAborted()) return;

    _publishHubEngineAutoPluginProbes(
      pluginIds: pluginIds,
      labelFor: labelFor,
      extracted: extracted,
      probedSources: probedSources,
      probeNotifier: probeNotifier,
    );

    if (probedSources.isEmpty) {
      final resolveRow = await firstEngineCatalogResolveRow(
        rows: allRows,
        profile: profile,
        settings: settings,
      );
      if (resolveRow != null && !isAborted()) {
        if (!context.mounted) return;
        openedPlayer = true;
        await _playHubEngineResolveRow(
          context: context,
          movie: movie,
          stream: resolveRow,
          season: season,
          episode: episode,
          startPosition: startPosition,
          settings: settings,
          profile: profile,
          loadingDialogContext: loadingDialogContext,
          fadeOutNotifier: fadeOutNotifier,
          isAborted: isAborted,
        );
        return;
      }

      final action = Completer<bool>();
      failureNotifier.value = ResolveFailure(
        title: 'Couldn’t start playback',
        detail:
            'None of the Forja plugins returned a working stream right now.',
        primaryLabel: 'Try again',
        onPrimary: () {
          if (!action.isCompleted) action.complete(true);
        },
        secondaryLabel: 'Close',
        onSecondary: () {
          if (!action.isCompleted) action.complete(false);
        },
      );
      final retry = await action.future;
      dismissLoading();
      if (retry && context.mounted) {
        await runHubEngineAutoPlay(
          context: context,
          movie: movie,
          engineCategory: engineCategory,
          season: season,
          episode: episode,
          kisskhId: kisskhId,
          kisskhEpisodeId: kisskhEpisodeId,
          anilistId: anilistId,
          malId: malId,
          startPosition: startPosition,
          loadingSubtitle: loadingSubtitle,
        );
      }
      return;
    }

    if (!context.mounted) return;
    openedPlayer = true;
    final primary = probedSources.first;
    final primaryRow = engineCatalogRowForSource(allRows, primary);
    await _playHubEngineFromProbedSources(
      context: context,
      movie: movie,
      sources: probedSources,
      primaryRow: primaryRow,
      season: season,
      episode: episode,
      startPosition: startPosition,
      loadingDialogContext: loadingDialogContext,
      fadeOutNotifier: fadeOutNotifier,
      isAborted: isAborted,
    );
  } finally {
    if (!openedPlayer) dismissLoading();
    disposeLoadingOverlayNotifiers(overlayNotifiers());
  }
}

bool _hubProbedSourcesIncludePlugin(
  String pluginId,
  List<StreamSource> sources,
  _HubEngineAutoExtracted extracted,
) {
  final rows = extracted[pluginId] ?? const [];
  for (final source in sources) {
    for (final row in rows) {
      final catalog = row['url']?.toString();
      if (catalog != null &&
          catalog.isNotEmpty &&
          source.catalogUrl == catalog) {
        return true;
      }
    }
  }
  return false;
}

void _publishHubEngineAutoPluginProbes({
  required List<String> pluginIds,
  required String Function(String) labelFor,
  required _HubEngineAutoExtracted extracted,
  required List<StreamSource> probedSources,
  required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
}) {
  probeNotifier.value = [
    for (var i = 0; i < pluginIds.length; i++)
      StreamProviderProbe(
        id: pluginIds[i],
        label: labelFor(pluginIds[i]),
        status: _hubEngineAutoPluginProbeStatus(
          pluginIds[i],
          extracted,
          probedSources,
        ),
        isPreferred: i == 0,
      ),
  ];
}

StreamProviderProbeStatus _hubEngineAutoPluginProbeStatus(
  String pluginId,
  _HubEngineAutoExtracted extracted,
  List<StreamSource> probedSources,
) {
  final streams = extracted[pluginId] ?? const [];
  if (streams.isEmpty) return StreamProviderProbeStatus.failed;
  if (_hubProbedSourcesIncludePlugin(pluginId, probedSources, extracted)) {
    return StreamProviderProbeStatus.success;
  }
  return StreamProviderProbeStatus.failed;
}

Future<_HubEngineAutoExtracted> _extractAllHubEnginePlugins({
  required List<String> pluginIds,
  required String Function(String) labelFor,
  required Movie movie,
  required String type,
  required int? season,
  required int? episode,
  required int? kisskhId,
  required int? kisskhEpisodeId,
  required int? anilistId,
  required int? malId,
  required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
  required ValueNotifier<String> messageNotifier,
  required bool Function() isAborted,
  required int batchLimit,
}) async {
  final year = movie.releaseDate.length >= 4
      ? movie.releaseDate.substring(0, 4)
      : null;
  final cacheKey = CatalogSourcesSessionCache.cacheKey(
    mediaId: movie.id,
    mediaType: movie.mediaType,
    season: season,
    episode: episode,
  );
  final results = <String, List<Map<String, dynamic>>>{};
  final completer = Completer<void>();
  var nextIndex = 0;
  var inFlight = 0;
  final statusById = <String, StreamProviderProbeStatus>{
    for (final id in pluginIds) id: StreamProviderProbeStatus.pending,
  };

  void mergeIntoSourcesPanel(
    String pluginId,
    List<Map<String, dynamic>> streams,
  ) {
    final cached = CatalogSourcesSessionCache.readEngine(cacheKey);
    final merged = <Map<String, dynamic>>[
      if (cached != null)
        for (final s in cached.streams)
          if (!engineStreamBelongsToPlugin(s, pluginId)) s,
      ...streams,
    ];
    final fetched = <String>{
      if (cached != null) ...cached.fetchedPluginIds,
      if (streams.isNotEmpty) pluginId,
    };
    CatalogSourcesSessionCache.writeEngine(
      cacheKey,
      merged,
      fetchedPluginIds: fetched,
    );
  }

  void publishProbes() {
    probeNotifier.value = [
      for (var i = 0; i < pluginIds.length; i++)
        StreamProviderProbe(
          id: pluginIds[i],
          label: labelFor(pluginIds[i]),
          status: statusById[pluginIds[i]]!,
          isPreferred: i == 0,
        ),
    ];
  }

  late final void Function() fill;
  late final Future<void> Function(String pluginId) launch;

  fill = () {
    while (inFlight < batchLimit &&
        nextIndex < pluginIds.length &&
        !completer.isCompleted &&
        !isAborted()) {
      final id = pluginIds[nextIndex++];
      unawaited(launch(id));
    }
  };

  launch = (String pluginId) async {
    inFlight++;
    statusById[pluginId] = StreamProviderProbeStatus.trying;
    publishProbes();
    messageNotifier.value = 'Extracting ${labelFor(pluginId)}…';
    try {
      final batch = await EngineService.instance.runPluginIsolated(
        pluginId: pluginId,
        tmdbId: movie.id > 0 ? movie.id.toString() : '0',
        type: type,
        season: season,
        episode: episode,
        title: movie.title,
        year: year,
        movie: movie,
        malId: malId,
        anilistId: anilistId,
        kisskhId: kisskhId,
        kisskhEpisodeId: kisskhEpisodeId,
        allowHostFallback: false,
      );
      if (!isAborted() && !completer.isCompleted) {
        final streams = batch?.streams ?? const <Map<String, dynamic>>[];
        mergeIntoSourcesPanel(pluginId, streams);
        results[pluginId] = List<Map<String, dynamic>>.from(streams);
        statusById[pluginId] = streams.isEmpty
            ? StreamProviderProbeStatus.failed
            : StreamProviderProbeStatus.pending;
        publishProbes();
      }
    } catch (e) {
      debugPrint('[hub-engine-auto] plugin $pluginId failed: $e');
      if (!isAborted() && !completer.isCompleted) {
        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
      }
    } finally {
      inFlight--;
    }
    if (completer.isCompleted) return;
    if (isAborted()) {
      if (!completer.isCompleted) completer.complete();
      return;
    }
    fill();
    if (nextIndex >= pluginIds.length &&
        inFlight == 0 &&
        !completer.isCompleted) {
      completer.complete();
    }
  };

  fill();
  if (pluginIds.isEmpty) return results;
  await completer.future;
  if (isAborted()) return results;
  EngineService.instance.cancelPending();
  return results;
}

Future<void> _playHubEngineFromProbedSources({
  required BuildContext context,
  required Movie movie,
  required List<StreamSource> sources,
  required Map<String, dynamic>? primaryRow,
  required int? season,
  required int? episode,
  required Duration? startPosition,
  required BuildContext? loadingDialogContext,
  required ValueNotifier<bool> fadeOutNotifier,
  required bool Function() isAborted,
}) async {
  if (isAborted() || sources.isEmpty) return;
  final needsEp = season != null || episode != null;
  final stream = primaryRow ?? <String, dynamic>{};
  final stremioId = movie.imdbId;
  final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString();
  final primary = sources.first;
  final ctx = loadingDialogContext;
  Future<void> openPlayer() => AppRouter.openPlayer(
    context,
    streamUrl: primary.url,
    title: movie.title,
    headers: primary.headers,
    movie: movie,
    selectedSeason: needsEp ? (season ?? 1) : null,
    selectedEpisode: needsEp ? (episode ?? 1) : null,
    startPosition: startPosition,
    activeProvider: primary.providerId ?? catalogHttpPlayProviderId(stream),
    sources: sources,
    pinSource: false,
    streamsPrevalidated: true,
    externalSubtitles: catalogStreamExternalSubtitles(stream),
    stremioId: stremioId,
    stremioAddonBaseUrl: stremioAddonBaseUrl,
    fadeTransition: ctx != null,
  );
  if (ctx != null && ctx.mounted) {
    await crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: ctx,
      fadeOutNotifier: fadeOutNotifier,
      openPlayer: openPlayer,
    );
  } else {
    await openPlayer();
  }
}

Future<void> _playHubEngineResolveRow({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> stream,
  required int? season,
  required int? episode,
  required Duration? startPosition,
  required SettingsService settings,
  required PlaybackProfile profile,
  required BuildContext? loadingDialogContext,
  required ValueNotifier<bool> fadeOutNotifier,
  required bool Function() isAborted,
}) async {
  if (isAborted()) return;
  final needsEp = season != null || episode != null;
  final stremioId = movie.imdbId;
  final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString();

  if (!await ensureLanP2pPlayback(context)) return;
  if (isAborted() || !context.mounted) return;

  final resolved = await resolveStremioStream(
    stream: stream,
    profile: profile,
    settings: settings,
    season: needsEp ? (season ?? 1) : null,
    episode: needsEp ? (episode ?? 1) : null,
    isCancelled: isAborted,
    onStatus: (_) {},
  );
  if (isAborted() || !context.mounted) return;
  if (resolved is! StremioPlayable) return;

  final ctx = loadingDialogContext;
  Future<void> openPlayer() => AppRouter.openPlayer(
    context,
    streamUrl: resolved.streamUrl,
    title: movie.title,
    magnetLink: resolved.magnetLink,
    movie: movie,
    selectedSeason: needsEp ? (season ?? 1) : null,
    selectedEpisode: needsEp ? (episode ?? 1) : null,
    fileIndex: resolved.fileIndex,
    startPosition: startPosition,
    activeProvider: catalogHttpPlayProviderId(stream),
    externalSubtitles: catalogStreamExternalSubtitles(stream),
    stremioId: stremioId,
    stremioAddonBaseUrl: stremioAddonBaseUrl,
    fadeTransition: ctx != null,
  );
  if (ctx != null && ctx.mounted) {
    await crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: ctx,
      fadeOutNotifier: fadeOutNotifier,
      openPlayer: openPlayer,
    );
  } else {
    await openPlayer();
  }
}
