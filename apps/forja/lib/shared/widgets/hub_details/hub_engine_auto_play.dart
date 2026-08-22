import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

class _HubEngineAutoHit {
  const _HubEngineAutoHit({
    required this.pluginId,
    required this.stream,
  });

  final String pluginId;
  final Map<String, dynamic> stream;
}

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
///
/// Races enabled Forja HTTP plugins in [engineCategory] (`drama` / `anime`),
/// probes the first playable URL, opens the standard player. Returns after the
/// player closes (or after cancel / failure UI).
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
    final hit = await _raceHubEnginePlugins(
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
      settings: settings,
      profile: profile,
      probeNotifier: probeNotifier,
      messageNotifier: messageNotifier,
      isAborted: () => aborted() || thisGen != playGen,
      batchLimit: engineSourcesBatchLimit(
        tv: context.mounted && SourcesPanelTv.isTv(context),
      ),
    );
    if (aborted() || thisGen != playGen) return;

    if (hit == null) {
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
      disposeLoadingOverlayNotifiers(overlayNotifiers());
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
    await _playHubEngineWinner(
      context: context,
      movie: movie,
      stream: hit.stream,
      season: season,
      episode: episode,
      startPosition: startPosition,
      settings: settings,
      profile: profile,
      loadingDialogContext: loadingDialogContext,
      fadeOutNotifier: fadeOutNotifier,
      isAborted: () => aborted() || thisGen != playGen,
    );
  } finally {
    if (!openedPlayer) dismissLoading();
    disposeLoadingOverlayNotifiers(overlayNotifiers());
  }
}

Future<_HubEngineAutoHit?> _raceHubEnginePlugins({
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
  required SettingsService settings,
  required PlaybackProfile profile,
  required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
  required ValueNotifier<String> messageNotifier,
  required bool Function() isAborted,
  required int batchLimit,
}) async {
  final year = movie.releaseDate.length >= 4
      ? movie.releaseDate.substring(0, 4)
      : null;
  final completer = Completer<_HubEngineAutoHit?>();
  var nextIndex = 0;
  var inFlight = 0;
  final statusById = <String, StreamProviderProbeStatus>{
    for (final id in pluginIds) id: StreamProviderProbeStatus.pending,
  };

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
    messageNotifier.value = 'Checking ${labelFor(pluginId)}…';
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
      if (isAborted() || completer.isCompleted) return;
      final streams = batch?.streams ?? const <Map<String, dynamic>>[];
      if (streams.isEmpty) {
        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
        return;
      }

      messageNotifier.value = 'Probing ${labelFor(pluginId)}…';
      final pick = await _pickProbedEngineStream(
        streams,
        settings: settings,
        profile: profile,
        isAborted: isAborted,
        orSettled: () => completer.isCompleted,
      );
      if (isAborted() || completer.isCompleted) return;
      if (pick == null) {
        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
        return;
      }

      statusById[pluginId] = StreamProviderProbeStatus.success;
      publishProbes();
      if (!completer.isCompleted) {
        completer.complete(
          _HubEngineAutoHit(pluginId: pluginId, stream: pick),
        );
        EngineService.instance.cancelPending();
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
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    fill();
    if (nextIndex >= pluginIds.length &&
        inFlight == 0 &&
        !completer.isCompleted) {
      completer.complete(null);
    }
  };

  fill();
  if (pluginIds.isEmpty) return null;
  final result = await completer.future;
  if (isAborted()) return null;
  return result;
}

Future<Map<String, dynamic>?> _pickProbedEngineStream(
  List<Map<String, dynamic>> streams, {
  required SettingsService settings,
  required PlaybackProfile profile,
  required bool Function() isAborted,
  required bool Function() orSettled,
}) async {
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  if (isAborted() || orSettled()) return null;

  for (final stream in streams) {
    if (isAborted() || orSettled()) return null;
    final check = classifyStremioStream(
      stream,
      profile,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    if (check is StremioExternalLink || check is StremioResolveFailure) {
      continue;
    }
    if (check is! StremioPlayable) {
      return stream;
    }
    final pid = catalogHttpPlayProviderId(stream);
    final ok = await probeStreamSourceUrl(
      check.streamUrl,
      check.headers,
      sourceKey: pid,
    );
    if (isAborted() || orSettled()) return null;
    if (ok) return stream;
  }
  return null;
}

Future<void> _playHubEngineWinner({
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

  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  if (isAborted()) return;

  final precheck = classifyStremioStream(
    stream,
    profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );

  if (precheck is StremioPlayable) {
    final proxied = await proxyCatalogHttpStreamIfNeeded(
      streamUrl: precheck.streamUrl,
      headers: precheck.headers,
      stream: stream,
    );
    if (isAborted() || !context.mounted) return;
    final ctx = loadingDialogContext;
    Future<void> openPlayer() => AppRouter.openPlayer(
      context,
      streamUrl: proxied.url,
      title: movie.title,
      headers: proxied.headers,
      movie: movie,
      selectedSeason: needsEp ? (season ?? 1) : null,
      selectedEpisode: needsEp ? (episode ?? 1) : null,
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
    return;
  }

  if (!context.mounted || isAborted()) return;
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
