import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/playback/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/engine_catalog_stream_probe.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/catalog/kit/play/catalog_hub_episodes.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_hooks.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_session.dart';

export 'package:forja/shared/catalog/kit/play/catalog_play_session.dart';
import 'package:forja/shared/catalog/kit/play/sources_request_context.dart';
import 'package:forja/shared/playback/play_source_effective.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/playback/stream_loading.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/media_details/sources_panel_tv.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// VOD green Play always races Forja engine providers (provider JS).
Future<bool> engineAutoPlayEnabled([SettingsService? settings]) async {
  final s = settings ?? SettingsService();
  return PlaySourceEffective.engine(s);
}

/// Current player session came from Forja Engine (`engine:<pluginId>`).
bool isEnginePlayerSession(String? providerId) =>
    providerId != null && providerId.startsWith(EngineIds.prefix);

/// Watch-history `sourceId` when last play was Sources → Forja (`engine:vidlink`).
String? enginePluginIdFromProgress(Map<String, dynamic>? progress) {
  if (progress == null) return null;
  final sourceId = progress['sourceId'] as String? ?? '';
  return EngineIds.pluginIdFromChip(sourceId);
}

bool isEngineSavedProgress(Map<String, dynamic>? progress) =>
    enginePluginIdFromProgress(progress) != null;

/// Prefer explicit [stremioId], else bag `imdb` from Sources middleware.
String? stremioIdFromSourcesBag({
  required Movie movie,
  CatalogPlaySession? session,
  String? stremioId,
  int? season,
  int? episode,
}) {
  final explicit = stremioId?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final bag = buildSourcesRequestContext(
    movie: movie,
    catalogMeta: session?.catalogMeta,
    catalogOpen: session?.effectiveOpen,
    season: season,
    episode: episode,
    episodeVideoId: session?.episodeVideoIdFor(episode ?? 1),
  ).stremioBag;
  if (bag != null && bag.hasCustomAddon) {
    return bag.customStremioId!.trim();
  }
  final imdb = bag?.ids['imdb']?.trim();
  if (imdb != null && imdb.isNotEmpty) return imdb;
  return movie.imdbId;
}

/// In-player next/prev / Episodes pick while on a Forja Engine session —
/// same race + loading overlay as green Play / Sources → Forja.
Future<void> switchEpisodeViaEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  required int season,
  required int episode,
  String? stremioId,
  EnginePlaySession? session,
  List<PlayerHubEpisode>? hubEpisodes,
}) {
  final s = session;
  final extract = engineExtractContext(
    catalogOpen: s?.effectiveOpen,
    movie: movie,
    episode: episode,
    episodeVideoId: s?.episodeVideoIdFor(episode),
    panelCategoryHint: engineCategoryForSession(s, movie),
  );
  return runEngineAutoPlay(
    context: context,
    movie: movie,
    engineCategory: extract.panelCategory,
    season: season,
    episode: episode,
    malId: extract.intVal('malId') ?? s?.malId,
    audioCategory: s?.audioCategory,
    stremioId: stremioIdFromSourcesBag(
      movie: movie,
      session: s,
      stremioId: stremioId,
      season: season,
      episode: episode,
    ),
    loadingSubtitle: s?.hasCatalogContext == true
        ? 'EP $episode'
        : 'Season $season · Episode $episode',
    catalogPlaySession: s,
    hubEpisodes: hubEpisodes,
    hubEpisodeNumber: episode,
  );
}

String? engineCategoryForSession(CatalogPlaySession? session, Movie movie) {
  if (session?.effectiveOpen != null) {
    return engineExtractContext(
      catalogOpen: session!.effectiveOpen,
      movie: movie,
    ).panelCategory;
  }
  return null;
}

Future<void> Function(PlayerHubEpisode episode)? _hubEngineEpisodePicker({
  required BuildContext context,
  required Movie movie,
  required EnginePlaySession? session,
  required List<PlayerHubEpisode>? hubEpisodes,
  int? season,
}) {
  if (session == null || hubEpisodes == null || hubEpisodes.isEmpty) {
    return null;
  }
  return (ep) async {
    if (!context.mounted) return;
    await switchEpisodeViaEngineAutoPlay(
      context: context,
      movie: movie,
      season: season ?? 1,
      episode: ep.number.round(),
      session: session,
      hubEpisodes: hubEpisodes,
    );
  };
}

class EngineAutoPlayPick {
  const EngineAutoPlayPick({
    required this.pluginId,
    required this.stream,
    required this.sources,
  });

  final String pluginId;
  final Map<String, dynamic> stream;
  final List<StreamSource> sources;
}

/// Green Play Forja Auto — same as movies/TV green Forja Play:
/// session-cache seed, Sources → Forja pool (5 TV / 10 desktop), first UP wins
/// (cancel rest). Not extract-all-then-probe-all; not webstreaming sequential.
///
/// Used by movies/TV details, Anime, and Asian Drama — one path, not copies.
Future<void> runEngineAutoPlay({
  required BuildContext context,
  required Movie movie,
  required String engineCategory,
  int? season,
  int? episode,
  int? malId,
  String? audioCategory,
  Duration? startPosition,
  String? loadingSubtitle,
  String? stremioId,
  CatalogPlaySession? catalogPlaySession,
  @Deprecated('Use catalogPlaySession') CatalogPlaySession? enginePlaySession,
  List<PlayerHubEpisode>? hubEpisodes,
  num? hubEpisodeNumber,

  /// Resume: re-extract this plugin first (from watch history `sourceId`).
  String? preferredPluginId,

  /// Resume: last play URL from watch history — probed before re-extract.
  String? savedStreamUrl,

  /// When set (e.g. provider-scoped episode id), race only these.
  /// Null → all enabled plugins in the panel category (not Sources chip prefs).
  Set<String>? selectedPluginIds,
  List<EnginePack>? packs,

  /// Keep an open Sources panel in sync with the shared session cache.
  void Function(
    List<Map<String, dynamic>> streams,
    Set<String> fetchedPluginIds,
  )?
  onCacheUpdated,
  void Function(EngineAutoPlayPick pick)? onPick,
  VoidCallback? onCancelUi,
}) async {
  final settings = SettingsService();
  final profile = PlatformPlayback.capabilities;
  final session = catalogPlaySession ?? enginePlaySession;
  final extract = engineExtractContext(
    catalogOpen: session?.effectiveOpen,
    movie: movie,
    episode: episode,
    episodeVideoId: session?.episodeVideoIdFor(episode ?? 1),
    panelCategoryHint: engineCategory,
  );
  final category = extract.panelCategory;
  final resolveType = extract.resolveType;
  final activeSession = session ??
      CatalogPlaySession(
        malId: malId,
        audioCategory: audioCategory,
      );
  final cacheKey = CatalogSourcesSessionCache.cacheKey(
    mediaId: movie.id,
    mediaType: movie.mediaType,
    season: season,
    episode: episode,
    catalogOpen: activeSession.effectiveOpen,
    pluginId: activeSession.pluginId,
    metaId: activeSession.catalogMeta?.id,
    malId: extract.intVal('malId') ?? malId,
    audioCategory: audioCategory ?? activeSession.audioCategory,
    episodeVideoId: activeSession.episodeVideoIdFor(episode ?? 1),
  );

  var cancelled = false;
  var playGen = 0;
  var openedPlayer = false;
  Completer<EngineAutoPlayPick?>? hitCompleter;

  final poolTasks = <Future<void>>{};
  var fetchGen = 0;
  var poolLimit = kEngineSourcesBatchDesktop;
  final inFlight = <String>{};
  var streams = <Map<String, dynamic>>[];
  var fetchedIds = <String>{};

  void abortPool() {
    fetchGen++;
    inFlight.clear();
    poolTasks.clear();
    EngineService.instance.cancelPending();
  }

  late final StreamLoadingSession loadingSession;
  void cancel() {
    cancelled = true;
    playGen++;
    abortPool();
    final pending = hitCompleter;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    dismissStreamLoading(loadingSession);
    onCancelUi?.call();
  }

  loadingSession = showStreamLoadingOverlay(
    context,
    movie: movie,
    kind: StreamLoadingKind.direct,
    initialMessage: 'Finding Forja servers…',
    subtitle: loadingSubtitle,
    onCancel: cancel,
  );
  final fadeOutNotifier = loadingSession.fadeOutNotifier;
  final messageNotifier = loadingSession.messageNotifier;
  final probeNotifier = loadingSession.probeNotifier;
  final failureNotifier = loadingSession.failureNotifier;

  void dismissLoading() => dismissStreamLoading(loadingSession);

  void publishCache() {
    CatalogSourcesSessionCache.writeEngine(
      cacheKey,
      List<Map<String, dynamic>>.from(streams),
      fetchedPluginIds: Set<String>.from(fetchedIds),
    );
    onCacheUpdated?.call(
      List<Map<String, dynamic>>.from(streams),
      Set<String>.from(fetchedIds),
    );
  }

  bool aborted() => cancelled || !context.mounted;

  await Future<void>.delayed(Duration.zero);
  if (aborted()) {
    dismissLoading();
    disposeStreamLoadingNotifiers(loadingSession);
    return;
  }

  try {
    await EngineService.instance.ensureOfficialInstalled();
    if (aborted()) return;

    final loadedPacks =
        packs ?? await EngineService.instance.listSourcesPanelPacks();
    if (aborted()) return;

    final enabledIds = enabledEnginePluginIds(loadedPacks);
    final scope = EngineCategories.matchingPluginIds(
      packs: loadedPacks,
      categories: EngineCategories.defaultsForPanelCategory(category),
    );
    // Green Play races the full category pool. Sources chip selection is
    // panel-only (prefs) and must not narrow this race.
    final selected = selectedPluginIds != null
        ? filterEngineSelectedPluginIds(
            savedIds: selectedPluginIds,
            enabledIds: enabledIds,
          )
        : {
            for (final id in scope)
              if (enabledIds.contains(id)) id,
          };

    final orderedIds = orderedEnginePluginIds(loadedPacks);
    var pluginIds = [
      for (final id in orderedIds)
        if (selected.contains(id) &&
            _pluginVisible(loadedPacks, id, category, selected))
          id,
    ];

    final pinPlugin = preferredPluginId?.trim();
    final resumeAt = startPosition;
    var pinActive =
        pinPlugin != null &&
        pinPlugin.isNotEmpty &&
        resumeAt != null &&
        resumeAt > Duration.zero;
    if (pinActive && !pluginIds.contains(pinPlugin)) {
      pinActive = false;
    }
    if (pinActive) {
      pluginIds = [pinPlugin!, ...pluginIds.where((id) => id != pinPlugin)];
    }

    String labelFor(String pluginId) {
      for (final pack in loadedPacks) {
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
            'No Forja plugins are on for this title. Open Sources → Forja and turn on providers.',
        primaryLabel: 'Close',
        primaryIcon: Icons.close_rounded,
        onPrimary: () {
          if (!action.isCompleted) action.complete();
        },
      );
      await action.future;
      return;
    }

    if (pinActive) {
      final savedUrl = savedStreamUrl?.trim() ?? '';
      if (savedUrl.isNotEmpty &&
          !isUnplayableCachedStreamUrl(savedUrl) &&
          !isTorrentStreamUrl(savedUrl) &&
          await probeStreamSourceUrl(savedUrl, null)) {
        if (!aborted()) {
          if (!context.mounted) return;
          openedPlayer = true;
          final isTv = movie.mediaType == 'tv';
          await AppRouter.openPlayer(
            context,
            streamUrl: savedUrl,
            title: movie.title,
            movie: movie,
            selectedSeason: isTv ? (season ?? 1) : null,
            selectedEpisode: isTv ? (episode ?? 1) : null,
            startPosition: resumeAt,
            activeProvider: EngineIds.pluginChip(pinPlugin!),
            pinSource: true,
            fadeTransition: loadingSession.dialogContext != null,
          );
          return;
        }
      }
    }

    final cached = CatalogSourcesSessionCache.readEngine(cacheKey);
    if (cached != null) {
      final wantAudio = audioCategory ?? activeSession.audioCategory;
      streams = filterStreamsByAudioCategory(
        List<Map<String, dynamic>>.from(cached.streams),
        wantAudio,
      );
      fetchedIds = Set<String>.from(cached.fetchedPluginIds);
      // Empty fetches are terminal for Sources reopen — not for green Play.
      // Drop them so pack updates / flaky upstreams get a fresh extract race.
      fetchedIds.removeAll(
        engineStaleFetchedPluginIds(
          fetchedIds: fetchedIds,
          selectedIds: pluginIds.toSet(),
          streams: streams,
        ),
      );
      onCacheUpdated?.call(
        List<Map<String, dynamic>>.from(streams),
        Set<String>.from(fetchedIds),
      );
    }

    final statusById = <String, StreamProviderProbeStatus>{
      for (final id in pluginIds) id: StreamProviderProbeStatus.pending,
    };
    final race = Completer<EngineAutoPlayPick?>();
    hitCompleter = race;
    var probingCount = 0;
    final probingIds = <String>{};
    final thisGen = ++playGen;
    bool playAborted() => aborted() || thisGen != playGen;

    // Session cache: empty fetches are terminal; rows stay pending until probed.
    for (final id in pluginIds) {
      if (!fetchedIds.contains(id)) continue;
      final hasRows = streams.any((s) => engineStreamBelongsToPlugin(s, id));
      if (!hasRows) {
        statusById[id] = StreamProviderProbeStatus.failed;
      }
    }

    void publishProbes() {
      probeNotifier.value = [
        for (var i = 0; i < pluginIds.length; i++)
          StreamProviderProbe(
            id: pluginIds[i],
            label: labelFor(pluginIds[i]),
            status: statusById[pluginIds[i]]!,
            isPreferred: pinActive ? pluginIds[i] == pinPlugin : i == 0,
          ),
      ];
    }

    bool workActive() => inFlight.isNotEmpty || poolTasks.isNotEmpty;

    void syncOverlayFromPool() {
      if (race.isCompleted) return;
      for (final id in pluginIds) {
        final cur = statusById[id]!;
        if (cur == StreamProviderProbeStatus.success ||
            cur == StreamProviderProbeStatus.failed) {
          continue;
        }
        if (inFlight.contains(id) || probingIds.contains(id)) {
          statusById[id] = StreamProviderProbeStatus.trying;
        } else if (!fetchedIds.contains(id)) {
          statusById[id] = StreamProviderProbeStatus.pending;
        } else {
          final hasRows = streams.any(
            (s) => engineStreamBelongsToPlugin(s, id),
          );
          statusById[id] = hasRows
              ? StreamProviderProbeStatus.pending
              : StreamProviderProbeStatus.failed;
        }
      }
      publishProbes();
    }

    void maybeCompleteEmpty() {
      if (race.isCompleted || playAborted()) return;
      final allFetched = pluginIds.every(fetchedIds.contains);
      if (!allFetched || probingCount > 0 || workActive()) return;
      race.complete(null);
    }

    Future<void> onPluginDone(
      String pluginId,
      List<Map<String, dynamic>> pluginStreams,
    ) async {
      if (playAborted() || race.isCompleted) return;
      if (!pluginIds.contains(pluginId)) return;

      final rows = sortEngineCatalogStreamRows(pluginStreams);
      if (rows.isEmpty) {
        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
        if (pinActive && pluginId == pinPlugin) {
          pinActive = false;
        }
        maybeCompleteEmpty();
        return;
      }

      probingIds.add(pluginId);
      probingCount++;
      statusById[pluginId] = StreamProviderProbeStatus.trying;
      publishProbes();
      messageNotifier.value = 'Checking servers…';

      try {
        for (final row in rows) {
          if (playAborted() || race.isCompleted) break;
          final probed = await buildProbedEngineCatalogSources(
            profile: profile,
            settings: settings,
            rows: [row],
            isAborted: playAborted,
            preferFirst: row,
          );
          if (probed.isEmpty) continue;
          statusById[pluginId] = StreamProviderProbeStatus.success;
          publishProbes();
          if (!race.isCompleted) {
            abortPool();
            race.complete(
              EngineAutoPlayPick(
                pluginId: pluginId,
                stream: row,
                sources: probed,
              ),
            );
          }
          return;
        }

        statusById[pluginId] = StreamProviderProbeStatus.failed;
        publishProbes();
        if (pinActive && pluginId == pinPlugin) {
          pinActive = false;
        }
        maybeCompleteEmpty();
      } finally {
        probingIds.remove(pluginId);
        probingCount--;
      }
    }

    Future<void> runAndApply(String pluginId, int gen) async {
      final year = movie.releaseDate.length >= 4
          ? movie.releaseDate.substring(0, 4)
          : null;
      final src = buildSourcesRequestContext(
        movie: movie,
        catalogMeta: activeSession.catalogMeta,
        catalogOpen: activeSession.effectiveOpen,
        season: season,
        episode: episode,
        episodeVideoId: activeSession.episodeVideoIdFor(episode ?? 1),
        panelCategoryHint: resolveType,
      );
      EngineExtractResult? batch;
      try {
        batch = await EngineService.instance.runPluginIsolated(
          pluginId: pluginId,
          tmdbId: src.engine?.tmdbId ?? '',
          type: src.engine?.resolveType ?? resolveType,
          season: season,
          episode: episode,
          title: movie.title,
          year: year,
          movie: movie,
          catalogOpen: activeSession.effectiveOpen,
          episodeVideoId: activeSession.episodeVideoIdFor(episode ?? 1),
          audioCategory: audioCategory ?? activeSession.audioCategory,
          allowHostFallback: false,
        );
      } catch (e) {
        debugPrint('[engine-auto] plugin $pluginId failed: $e');
      }
      if (playAborted() || gen != fetchGen) {
        inFlight.remove(pluginId);
        return;
      }
      fetchedIds.add(pluginId);
      inFlight.remove(pluginId);
      streams.removeWhere((s) => engineStreamBelongsToPlugin(s, pluginId));
      if (batch != null && batch.streams.isNotEmpty) {
        streams.addAll(batch.streams);
      }
      publishCache();
      await onPluginDone(
        pluginId,
        List<Map<String, dynamic>>.from(batch?.streams ?? const []),
      );
    }

    void fillPool(int gen) {
      if (playAborted() || gen != fetchGen || race.isCompleted) return;
      final slots = poolLimit - inFlight.length;
      if (slots <= 0) return;
      final raceIds = pinActive ? [pinPlugin!] : pluginIds;
      final next = nextEnginePluginBatch(
        orderedIds: raceIds,
        selectedIds: raceIds.toSet(),
        fetchedIds: {...fetchedIds, ...inFlight},
        limit: slots,
      );
      if (next.isEmpty) return;
      for (final id in next) {
        if (inFlight.contains(id) || fetchedIds.contains(id)) continue;
        inFlight.add(id);
        late final Future<void> task;
        task = () async {
          try {
            await runAndApply(id, gen);
          } finally {
            poolTasks.remove(task);
            inFlight.remove(id);
            if (!playAborted() && gen == fetchGen && !race.isCompleted) {
              fillPool(gen);
              syncOverlayFromPool();
            }
          }
        }();
        poolTasks.add(task);
      }
      syncOverlayFromPool();
    }

    publishProbes();

    final cachedIds = [
      for (final id in (pinActive ? [pinPlugin!] : pluginIds))
        if (fetchedIds.contains(id)) id,
    ];
    if (cachedIds.isNotEmpty) {
      messageNotifier.value = 'Checking servers…';
    }
    for (final id in cachedIds) {
      if (playAborted() || race.isCompleted) break;
      final cachedRows = streams
          .where((s) => engineStreamBelongsToPlugin(s, id))
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      await onPluginDone(id, cachedRows);
    }

    if (pinActive && !race.isCompleted && !playAborted() && pinPlugin != null) {
      if (!fetchedIds.contains(pinPlugin) && !inFlight.contains(pinPlugin)) {
        final gen = ++fetchGen;
        inFlight.add(pinPlugin);
        try {
          await runAndApply(pinPlugin, gen);
        } finally {
          inFlight.remove(pinPlugin);
        }
      }
    }

    if (!race.isCompleted && !playAborted()) {
      poolLimit = engineSourcesBatchLimit(
        tv: context.mounted && SourcesPanelTv.isTv(context),
      );
      var gen = ++fetchGen;
      fillPool(gen);
      while (!playAborted() &&
          !race.isCompleted &&
          (workActive() || probingCount > 0)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (pinActive && !race.isCompleted && !playAborted()) {
        pinActive = false;
        gen = ++fetchGen;
        fillPool(gen);
        while (!playAborted() &&
            !race.isCompleted &&
            (workActive() || probingCount > 0)) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
      maybeCompleteEmpty();
    }

    final hit = playAborted() ? null : await race.future;
    if (playAborted()) return;

    if (hit != null) {
      if (!context.mounted) return;
      openedPlayer = true;
      onPick?.call(hit);
      await _playFromProbedSources(
        context: context,
        movie: movie,
        sources: hit.sources,
        primaryRow: hit.stream,
        season: season,
        episode: episode,
        startPosition: startPosition,
        stremioId: stremioIdFromSourcesBag(
          movie: movie,
          session: activeSession,
          stremioId: stremioId,
          season: season,
          episode: episode,
        ),
        enginePlaySession: activeSession,
        hubEpisodes: hubEpisodes,
        hubEpisodeNumber: hubEpisodeNumber ?? episode,
        loadingDialogContext: loadingSession.dialogContext,
        fadeOutNotifier: fadeOutNotifier,
        messageNotifier: messageNotifier,
        isAborted: playAborted,
      );
      return;
    }

    final resolveRow = await firstEngineCatalogResolveRow(
      rows: [
        for (final id in pluginIds)
          ...streams.where((s) => engineStreamBelongsToPlugin(s, id)),
      ],
      profile: profile,
      settings: settings,
    );
    if (resolveRow != null && !playAborted()) {
      if (!context.mounted) return;
      openedPlayer = true;
      final pluginId =
          resolveRow['_enginePluginId']?.toString() ?? pluginIds.first;
      onPick?.call(
        EngineAutoPlayPick(
          pluginId: pluginId,
          stream: resolveRow,
          sources: const [],
        ),
      );
      await _playResolveRow(
        context: context,
        movie: movie,
        stream: resolveRow,
        season: season,
        episode: episode,
        startPosition: startPosition,
        settings: settings,
        profile: profile,
        stremioId: stremioIdFromSourcesBag(
          movie: movie,
          session: activeSession,
          stremioId: stremioId,
          season: season,
          episode: episode,
        ),
        enginePlaySession: activeSession,
        hubEpisodes: hubEpisodes,
        hubEpisodeNumber: hubEpisodeNumber ?? episode,
        loadingSession: loadingSession,
        isAborted: playAborted,
      );
      return;
    }

    final action = Completer<bool>();
    failureNotifier.value = ResolveFailure(
      title: 'Couldn’t start playback',
      detail: 'None of the Forja plugins returned a working stream right now.',
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
      await runEngineAutoPlay(
        context: context,
        movie: movie,
        engineCategory: engineCategory,
        season: season,
        episode: episode,
        malId: malId,
        audioCategory: audioCategory,
        startPosition: startPosition,
        loadingSubtitle: loadingSubtitle,
        stremioId: stremioId,
        preferredPluginId: preferredPluginId,
        savedStreamUrl: savedStreamUrl,
        catalogPlaySession: activeSession,
        hubEpisodes: hubEpisodes,
        hubEpisodeNumber: hubEpisodeNumber,
        selectedPluginIds: selectedPluginIds,
        packs: packs,
        onCacheUpdated: onCacheUpdated,
        onPick: onPick,
        onCancelUi: onCancelUi,
      );
    }
  } finally {
    if (!openedPlayer) {
      dismissLoading();
      disposeStreamLoadingNotifiers(loadingSession);
    } else {
      finishStreamLoadingSession(loadingSession);
    }
  }
}

bool _pluginVisible(
  List<EnginePack> packs,
  String pluginId,
  String panelCategory,
  Set<String> selected,
) {
  final cats = EngineCategories.defaultsForPanelCategory(panelCategory);
  for (final pack in packs) {
    for (final p in pack.plugins) {
      if (p.id != pluginId) continue;
      return EngineCategories.pluginChipVisible(
        plugin: p,
        visibleCategories: cats,
        selectedPluginIds: selected,
      );
    }
  }
  return false;
}

Future<void> _playFromProbedSources({
  required BuildContext context,
  required Movie movie,
  required List<StreamSource> sources,
  required Map<String, dynamic>? primaryRow,
  required int? season,
  required int? episode,
  required Duration? startPosition,
  required String? stremioId,
  EnginePlaySession? enginePlaySession,
  List<PlayerHubEpisode>? hubEpisodes,
  num? hubEpisodeNumber,
  required BuildContext? loadingDialogContext,
  required ValueNotifier<bool> fadeOutNotifier,
  required ValueNotifier<String>? messageNotifier,
  required bool Function() isAborted,
}) async {
  if (isAborted() || sources.isEmpty) return;
  messageNotifier?.value = 'Opening player…';
  final needsEp = season != null || episode != null;
  final stream = primaryRow ?? <String, dynamic>{};
  final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString();
  final primary = sources.first;
  final ctx = loadingDialogContext;
  final epNum = hubEpisodeNumber ?? episode;
  final playMovie = movieWithResolvedHubArt(movie);
  final playHubEpisodes = await ensureHubCatalogEpisodes(
    pluginId: enginePlaySession?.pluginId,
    metaId: enginePlaySession?.catalogMeta?.id,
    catalogMeta: enginePlaySession?.catalogMeta,
    hubEpisodes: hubEpisodes,
    liveEpisodeCount: playMovie.numberOfEpisodes,
  );
  if (!context.mounted) return;
  final onSaveProgress = hubEngineSaveProgressCallback(
    session: enginePlaySession,
    movie: playMovie,
    episodeNumber: epNum,
    hubEpisodes: playHubEpisodes,
  );
  final onHubEpisodeSelected = _hubEngineEpisodePicker(
    context: context,
    movie: playMovie,
    session: enginePlaySession,
    hubEpisodes: playHubEpisodes,
    season: season,
  );
  Future<void> openPlayer() async {
    await seedHubEngineWatchHistory(
      session: enginePlaySession,
      movie: playMovie,
      episodeNumber: epNum,
      hubEpisodes: playHubEpisodes,
    );
    if (isAborted() || !context.mounted) return;
    await AppRouter.openPlayer(
      context,
      streamUrl: primary.url,
      title: playMovie.title,
      headers: primary.headers,
      movie: playMovie,
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
      enginePlaySession: enginePlaySession,
      hubEpisodes: playHubEpisodes,
      hubEpisodeNumber: epNum,
      onHubEpisodeSelected: onHubEpisodeSelected,
      onSaveProgress: onSaveProgress,
      fadeTransition: ctx != null,
    );
  }

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

Future<void> _playResolveRow({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> stream,
  required int? season,
  required int? episode,
  required Duration? startPosition,
  required SettingsService settings,
  required PlaybackProfile profile,
  required String? stremioId,
  EnginePlaySession? enginePlaySession,
  List<PlayerHubEpisode>? hubEpisodes,
  num? hubEpisodeNumber,
  required StreamLoadingSession loadingSession,
  required bool Function() isAborted,
}) async {
  if (isAborted()) return;
  final needsEp = season != null || episode != null;
  final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString();

  if (!await ensureLanP2pPlayback(context)) return;
  if (isAborted() || !context.mounted) return;

  final debrid = settings.debridPlaybackPrefs();
  loadingSession.setKind(StreamLoadingKind.torrent);
  loadingSession.torrentStatusNotifier.value = initialStremioTorrentResolveStatus(
    profile: profile,
    useDebrid: debrid.useDebrid,
    debridService: debrid.service,
  );
  final resolved = await resolveStremioStream(
    stream: stream,
    profile: profile,
    settings: settings,
    season: needsEp ? (season ?? 1) : null,
    episode: needsEp ? (episode ?? 1) : null,
    isCancelled: isAborted,
    onStatus: torrentLoadingStatusSink(
      loadingSession.torrentStatusNotifier,
      cancelled: isAborted,
    ),
  );
  if (isAborted() || !context.mounted) return;
  if (resolved is! StremioPlayable) return;

  final ctx = loadingSession.dialogContext;
  final fadeOutNotifier = loadingSession.fadeOutNotifier;
  final epNum = hubEpisodeNumber ?? episode;
  final playMovie = movieWithResolvedHubArt(movie);
  final playHubEpisodes = await ensureHubCatalogEpisodes(
    pluginId: enginePlaySession?.pluginId,
    metaId: enginePlaySession?.catalogMeta?.id,
    catalogMeta: enginePlaySession?.catalogMeta,
    hubEpisodes: hubEpisodes,
    liveEpisodeCount: playMovie.numberOfEpisodes,
  );
  if (!context.mounted) return;
  final onSaveProgress = hubEngineSaveProgressCallback(
    session: enginePlaySession,
    movie: playMovie,
    episodeNumber: epNum,
    hubEpisodes: playHubEpisodes,
  );
  final onHubEpisodeSelected = _hubEngineEpisodePicker(
    context: context,
    movie: playMovie,
    session: enginePlaySession,
    hubEpisodes: playHubEpisodes,
    season: season,
  );
  Future<void> openPlayer() async {
    await seedHubEngineWatchHistory(
      session: enginePlaySession,
      movie: playMovie,
      episodeNumber: epNum,
      hubEpisodes: playHubEpisodes,
    );
    if (isAborted() || !context.mounted) return;
    await AppRouter.openPlayer(
      context,
      streamUrl: resolved.streamUrl,
      title: playMovie.title,
      magnetLink: resolved.magnetLink,
      movie: playMovie,
      selectedSeason: needsEp ? (season ?? 1) : null,
      selectedEpisode: needsEp ? (episode ?? 1) : null,
      fileIndex: resolved.fileIndex,
      startPosition: startPosition,
      activeProvider: catalogHttpPlayProviderId(stream),
      externalSubtitles: catalogStreamExternalSubtitles(stream),
      stremioId: stremioId,
      stremioAddonBaseUrl: stremioAddonBaseUrl,
      enginePlaySession: enginePlaySession,
      hubEpisodes: playHubEpisodes,
      hubEpisodeNumber: epNum,
      onHubEpisodeSelected: onHubEpisodeSelected,
      onSaveProgress: onSaveProgress,
      fadeTransition: ctx != null,
    );
  }

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
