import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/details/details_meta.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/settings/pack_green_play_config.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_playback_router.dart';
import 'package:forja/shared/nuvio/nuvio_service.dart';
import 'package:forja/shared/playback/kit_episodes.dart';
import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/playback/open/stream_loading.dart';
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shared/playback/play_hooks.dart';
import 'package:forja/shared/playback/probe/sources_panel_stream_probe.dart';
import 'package:forja/shared/playback/resolve_failure_view.dart';
import 'package:forja/shared/playback/sources_request_context.dart';
import 'package:forja/shared/playback/stremio_stream_id.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:rust/rust.dart';

/// Pack-owned green Play entry (RFC-118).
Future<void> runPackGreenPlay({
  required BuildContext context,
  required PlayContext ctx,
}) async {
  final open = ctx.effectiveOpen;
  if (open?.effectiveExtract.resolveType == 'iptv') {
    return;
  }

  final config = await PackGreenPlayConfig.resolve(ctx.pluginId);
  final techs = await config.effectiveTechIds();
  if (techs.isEmpty) {
    if (context.mounted) {
      ForjaToast.info('No play sources are enabled for green Play');
    }
    return;
  }

  final session = _sessionFromContext(ctx);
  final category = engineCategoryForSession(session, ctx.movie) ?? 'movie';

  if (techs.length == 1 && techs.first == PackGreenPlayTechs.engine) {
    await _runEngineOnly(
      context: context,
      ctx: ctx,
      session: session,
      category: category,
      config: config,
    );
    return;
  }

  await _runMultiTechRace(
    context: context,
    ctx: ctx,
    session: session,
    category: category,
    config: config,
    techs: techs,
  );
}

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

Future<void> _runEngineOnly({
  required BuildContext context,
  required PlayContext ctx,
  required PlaySession session,
  required String category,
  required PackGreenPlayConfig config,
}) async {
  final packs = await EngineService.instance.listSourcesPanelPacks();
  final enabled = enabledEnginePluginIds(packs);
  final scope = EngineCategories.matchingPluginIds(
    packs: packs,
    categories: EngineCategories.defaultsForPanelCategory(category),
  );
  final available = [
    for (final id in orderedEnginePluginIds(packs))
      if (enabled.contains(id) && scope.contains(id)) id,
  ];
  final ordered = config.orderProviderIds(
    tech: PackGreenPlayTechs.engine,
    available: available,
  );
  if (ordered.isEmpty) {
    if (context.mounted) {
      ForjaToast.info('No Forja providers match green Play settings');
    }
    return;
  }

  final packPreferred =
      config.firstPreferredIn(PackGreenPlayTechs.engine, ordered);
  final resumePin = ctx.preferredPluginId?.trim();
  final preferred = (resumePin != null &&
          resumePin.isNotEmpty &&
          ordered.contains(resumePin))
      ? resumePin
      : packPreferred;

  await runEngineAutoPlay(
    context: context,
    movie: ctx.movie,
    engineCategory: category,
    season: ctx.season,
    episode: ctx.episode,
    malId: ctx.malId,
    audioCategory: ctx.audioCategory,
    startPosition: ctx.startPosition,
    preferredPluginId: preferred,
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

Future<void> _runMultiTechRace({
  required BuildContext context,
  required PlayContext ctx,
  required PlaySession session,
  required String category,
  required PackGreenPlayConfig config,
  required List<String> techs,
}) async {
  var cancelled = false;
  final win = Completer<_GreenPlayWin?>();
  var pending = techs.length;

  late final StreamLoadingSession loading;
  void cancel() {
    cancelled = true;
    EngineService.instance.cancelPending();
    NuvioService.instance.cancelPending();
    if (!win.isCompleted) win.complete(null);
    dismissStreamLoading(loading);
  }

  bool aborted() => cancelled || !context.mounted || win.isCompleted;

  void techFinished() {
    pending--;
    if (pending <= 0 && !win.isCompleted) win.complete(null);
  }

  void tryWin(_GreenPlayWin hit) {
    if (cancelled || !context.mounted || win.isCompleted) return;
    cancelled = true;
    EngineService.instance.cancelPending();
    NuvioService.instance.cancelPending();
    win.complete(hit);
  }

  loading = showStreamLoadingOverlay(
    context,
    movie: ctx.movie,
    kind: StreamLoadingKind.direct,
    initialMessage: 'Finding servers…',
    subtitle: ctx.loadingSubtitle,
    onCancel: cancel,
  );

  await Future<void>.delayed(Duration.zero);
  if (cancelled || !context.mounted) {
    finishStreamLoadingSession(loading);
    return;
  }

  for (final tech in techs) {
    switch (tech) {
      case PackGreenPlayTechs.engine:
        unawaited(() async {
          try {
            final packs =
                await EngineService.instance.listSourcesPanelPacks();
            if (aborted()) return;
            final enabled = enabledEnginePluginIds(packs);
            final scope = EngineCategories.matchingPluginIds(
              packs: packs,
              categories:
                  EngineCategories.defaultsForPanelCategory(category),
            );
            final available = [
              for (final id in orderedEnginePluginIds(packs))
                if (enabled.contains(id) && scope.contains(id)) id,
            ];
            final ordered = config.orderProviderIds(
              tech: PackGreenPlayTechs.engine,
              available: available,
            );
            if (ordered.isEmpty) return;

            final packPreferred = config.firstPreferredIn(
              PackGreenPlayTechs.engine,
              ordered,
            );
            final resumePin = ctx.preferredPluginId?.trim();
            final preferred = (resumePin != null &&
                    resumePin.isNotEmpty &&
                    ordered.contains(resumePin))
                ? resumePin
                : packPreferred;

            if (!context.mounted || aborted()) return;
            final pick = await runEngineAutoPlay(
              context: context,
              movie: ctx.movie,
              engineCategory: category,
              season: ctx.season,
              episode: ctx.episode,
              malId: ctx.malId,
              audioCategory: ctx.audioCategory,
              startPosition: ctx.startPosition,
              preferredPluginId: preferred,
              savedStreamUrl: ctx.savedStreamUrl,
              loadingSubtitle: ctx.loadingSubtitle,
              episodes: ctx.kitEpisodes,
              hubEpisodeNumber: ctx.episode,
              selectedPluginIds: ordered.toSet(),
              racePluginOrder: ordered,
              packs: packs,
              playSession: session,
              downloadOnly: true,
              existingLoading: loading,
            );
            if (pick != null && !win.isCompleted) {
              tryWin(_GreenPlayWin.engine(pick));
            }
          } finally {
            techFinished();
          }
        }());
      case PackGreenPlayTechs.stremio:
        unawaited(() async {
          try {
            await _raceStremio(
              ctx: ctx,
              config: config,
              aborted: aborted,
              onWin: tryWin,
              message: loading.messageNotifier,
            );
          } finally {
            techFinished();
          }
        }());
      case PackGreenPlayTechs.nuvio:
        unawaited(() async {
          try {
            await _raceNuvio(
              ctx: ctx,
              config: config,
              aborted: aborted,
              onWin: tryWin,
              message: loading.messageNotifier,
            );
          } finally {
            techFinished();
          }
        }());
      case PackGreenPlayTechs.torrent:
        unawaited(() async {
          try {
            await _raceTorrent(
              ctx: ctx,
              config: config,
              aborted: aborted,
              onWin: tryWin,
              message: loading.messageNotifier,
              torrentStatus: loading.torrentStatusNotifier,
            );
          } finally {
            techFinished();
          }
        }());
    }
  }

  final hit = await win.future;
  if (!context.mounted) {
    finishStreamLoadingSession(loading);
    return;
  }

  if (hit == null) {
    final action = Completer<void>();
    loading.failureNotifier.value = ResolveFailure(
      title: 'No playable stream',
      detail:
          'None of the selected green Play sources returned a working stream.',
      primaryLabel: 'Close',
      primaryIcon: Icons.close_rounded,
      onPrimary: () {
        if (!action.isCompleted) action.complete();
      },
    );
    await action.future;
    dismissStreamLoading(loading);
    finishStreamLoadingSession(loading);
    return;
  }

  loading.messageNotifier.value = 'Opening player…';
  switch (hit.kind) {
    case _GreenPlayWinKind.engine:
      final pick = hit.enginePick!;
      if (pick.sources.isEmpty) {
        dismissStreamLoading(loading);
        finishStreamLoadingSession(loading);
        if (context.mounted) {
          ForjaToast.info('No playable stream');
        }
        return;
      }
      await _openHttpPlayer(
        context: context,
        ctx: ctx,
        session: session,
        url: pick.sources.first.url,
        headers: pick.sources.first.headers ?? const {},
        providerId: pick.sources.first.providerId ??
            EngineIds.pluginChip(pick.pluginId),
        stream: pick.stream,
        loading: loading,
        isAborted: () => !context.mounted,
      );
    case _GreenPlayWinKind.http:
      await _openHttpPlayer(
        context: context,
        ctx: ctx,
        session: session,
        url: hit.url!,
        headers: hit.headers ?? const {},
        providerId: hit.providerId,
        stream: hit.stream,
        loading: loading,
        isAborted: () => !context.mounted,
      );
    case _GreenPlayWinKind.torrent:
      await _openHttpPlayer(
        context: context,
        ctx: ctx,
        session: session,
        url: hit.url!,
        headers: const {},
        providerId: hit.providerId ?? 'torrent',
        stream: null,
        loading: loading,
        isAborted: () => !context.mounted,
        magnet: hit.magnet,
        torrentFileIndex: hit.torrentFileIndex,
      );
  }
}

Future<void> _raceStremio({
  required PlayContext ctx,
  required PackGreenPlayConfig config,
  required bool Function() aborted,
  required void Function(_GreenPlayWin) onWin,
  required ValueNotifier<String> message,
}) async {
  final settings = SettingsService();
  final profile = PlatformPlayback.capabilities;
  final addons = await settings.getStremioAddons();
  if (aborted()) return;

  final available = <String>[];
  final byBase = <String, Map<String, dynamic>>{};
  for (final addon in addons) {
    if (!StremioAddonFeatures.isEnabled(addon)) continue;
    final base = SettingsService.normalizeStremioAddonBaseUrl(
      (addon['baseUrl'] ?? addon['url'] ?? '').toString(),
    );
    if (base.isEmpty) continue;
    available.add(base);
    byBase[base] = addon;
  }
  final ordered = config.orderProviderIds(
    tech: PackGreenPlayTechs.stremio,
    available: available,
  );
  if (ordered.isEmpty) return;

  final series = hubMediaIsEpisodic(ctx.movie);
  final type = series ? 'series' : 'movie';
  final bag = buildSourcesRequestContext(
    movie: ctx.movie,
    meta: ctx.metaItem,
    open: ctx.effectiveOpen,
    season: ctx.season,
    episode: ctx.episode,
  ).stremioBag;
  final ids = <String, String>{
    if (bag != null) ...bag.ids,
    if (ctx.movie.imdbId != null && ctx.movie.imdbId!.isNotEmpty)
      'imdb': ctx.movie.imdbId!,
    if (ctx.movie.id > 0) 'tmdb': '${ctx.movie.id}',
  };

  final stremio = StremioService();
  for (final base in ordered) {
    if (aborted()) return;
    final addon = byBase[base];
    if (addon == null) continue;
    message.value =
        'Checking ${PackGreenPlayTechs.label(PackGreenPlayTechs.stremio)}…';
    final streamId = resolveStremioStreamId(
      ids: ids,
      addonManifest: addon['manifest'] is Map
          ? Map<String, dynamic>.from(addon['manifest'] as Map)
          : null,
      series: series,
      season: ctx.season,
      episode: ctx.episode,
    );
    if (streamId == null || streamId.isEmpty) continue;

    List<dynamic> raw;
    try {
      raw = await stremio.getStreams(
        baseUrl: base,
        type: type,
        id: streamId,
      );
    } catch (_) {
      continue;
    }
    if (aborted()) return;

    final filtered = filterStremioStreamsForProfile(raw, profile);
    for (final row in filtered) {
      if (aborted()) return;
      final tagged = Map<String, dynamic>.from(row)
        ..['_addonBaseUrl'] = base
        ..['_addonName'] =
            (addon['name'] ?? addon['manifestName'] ?? base).toString();
      final classified = classifyStremioStream(tagged, profile);
      if (classified is StremioPlayable) {
        final ok = await probeSourcesPanelStream(tagged);
        if (!ok || aborted()) continue;
        onWin(
          _GreenPlayWin.http(
            url: classified.streamUrl,
            headers: classified.headers,
            providerId: 'stremio:$base',
            stream: tagged,
          ),
        );
        return;
      }
      final resolved = await resolveStremioStream(
        stream: tagged,
        profile: profile,
        settings: settings,
        season: ctx.season,
        episode: ctx.episode,
        isCancelled: aborted,
      );
      if (aborted()) return;
      if (resolved is StremioPlayable) {
        onWin(
          _GreenPlayWin.http(
            url: resolved.streamUrl,
            headers: resolved.headers,
            providerId: 'stremio:$base',
            stream: tagged,
          ),
        );
        return;
      }
    }
  }
}

Future<void> _raceNuvio({
  required PlayContext ctx,
  required PackGreenPlayConfig config,
  required bool Function() aborted,
  required void Function(_GreenPlayWin) onWin,
  required ValueNotifier<String> message,
}) async {
  final profile = PlatformPlayback.capabilities;
  final addons = await NuvioService.instance.listAddons();
  if (aborted()) return;
  final enabled = enabledNuvioScraperIds(addons);
  final ordered = config.orderProviderIds(
    tech: PackGreenPlayTechs.nuvio,
    available: enabled,
  );
  if (ordered.isEmpty) return;

  final type = hubMediaIsEpisodic(ctx.movie) ? 'tv' : 'movie';
  final tmdbId = '${ctx.movie.id}';
  if (ctx.movie.id <= 0) return;

  for (final scraperId in ordered) {
    if (aborted()) return;
    message.value = 'Checking Nuvio…';
    final result = await NuvioService.instance.runSourcesScraper(
      scraperId: scraperId,
      tmdbId: tmdbId,
      type: type,
      season: ctx.season,
      episode: ctx.episode,
    );
    if (aborted() || result == null) continue;
    for (final row in result.streams) {
      if (aborted()) return;
      final tagged = Map<String, dynamic>.from(row)
        ..['_addonBaseUrl'] = 'nuvio:$scraperId';
      final classified = classifyStremioStream(tagged, profile);
      if (classified is! StremioPlayable) continue;
      final ok = await probeSourcesPanelStream(tagged);
      if (!ok || aborted()) continue;
      onWin(
        _GreenPlayWin.http(
          url: classified.streamUrl,
          headers: classified.headers,
          providerId: 'nuvio:$scraperId',
          stream: tagged,
        ),
      );
      return;
    }
  }
}

Future<void> _raceTorrent({
  required PlayContext ctx,
  required PackGreenPlayConfig config,
  required bool Function() aborted,
  required void Function(_GreenPlayWin) onWin,
  required ValueNotifier<String> message,
  required ValueNotifier<TorrentLoadingStatus?> torrentStatus,
}) async {
  final profile = PlatformPlayback.capabilities;
  if (!profile.playSourceTorrent) return;

  final debridId = DebridPackBridge.activePluginId?.call()?.trim() ?? '';
  if (debridId.isEmpty) {
    final decision = await LanPlaybackRouter.routeTorrent(profile);
    if (decision != LanRouteDecision.desktopServes &&
        decision != LanRouteDecision.localEngine) {
      return;
    }
  }
  if (aborted()) return;

  final available = TorrentSearchProviders.all;
  final ordered = config.orderProviderIds(
    tech: PackGreenPlayTechs.torrent,
    available: available,
  );
  if (ordered.isEmpty) return;

  message.value = 'Searching torrents…';
  final query = ctx.movie.title;
  List<Map<String, dynamic>> maps;
  try {
    maps = await Engine.searchTorrents(
      query,
      imdbId: ctx.movie.imdbId,
      season: ctx.season,
      episode: ctx.episode,
      enabledProviders: ordered,
    );
  } catch (_) {
    return;
  }
  if (aborted() || maps.isEmpty) return;

  final results = [
    for (final m in maps) TorrentResult.fromJson(m),
  ]..sort((a, b) => b.seedersCount.compareTo(a.seedersCount));

  for (final result in results.take(8)) {
    if (aborted()) return;
    final magnet = result.magnet;
    if (!magnet.startsWith('magnet:')) continue;

    torrentStatus.value = torrentLoadingStatusGeneric(
      playbackResolveLabel(
        debridLabel: DebridPackBridge.activePluginLabel?.call(),
      ),
    );
    final episodic = hubMediaIsEpisodic(ctx.movie);
    final playback = await resolveMagnetForPlayback(
      magnet: magnet,
      localTorrentEngine: profile.localTorrentEngine,
      season: episodic ? (ctx.season ?? 1) : null,
      episode: episodic ? (ctx.episode ?? 1) : null,
      onStatus: torrentLoadingStatusSink(
        torrentStatus,
        cancelled: aborted,
      ),
    );
    if (aborted()) {
      if (playback != null) {
        LanClientService.instance.releaseLanTorrentIfNeeded(
          playUrl: playback.url,
          magnet: magnet,
        );
      }
      return;
    }
    if (playback == null || playback.url.isEmpty) continue;
    onWin(
      _GreenPlayWin.torrent(
        url: playback.url,
        magnet: magnet,
        fileIndex: playback.fileIndex,
        providerId: result.source,
      ),
    );
    return;
  }
}

Future<void> _openHttpPlayer({
  required BuildContext context,
  required PlayContext ctx,
  required PlaySession session,
  required String url,
  required Map<String, String> headers,
  required String? providerId,
  required Map<String, dynamic>? stream,
  required StreamLoadingSession loading,
  required bool Function() isAborted,
  String? magnet,
  int? torrentFileIndex,
}) async {
  if (isAborted() || !context.mounted) {
    dismissStreamLoading(loading);
    finishStreamLoadingSession(loading);
    return;
  }
  final needsEp = ctx.season != null || ctx.episode != null;
  final playMovie = movieWithResolvedArt(ctx.movie);
  final epNum = ctx.episode;
  final playHubEpisodes = await ensureKitEpisodes(
    pluginId: session.pluginId,
    metaId: session.meta?.id,
    meta: session.meta,
    episodes: ctx.kitEpisodes,
    liveEpisodeCount: playMovie.numberOfEpisodes,
  );
  if (isAborted() || !context.mounted) {
    dismissStreamLoading(loading);
    finishStreamLoadingSession(loading);
    return;
  }

  final sources = [
    StreamSource(
      url: url,
      title: providerId ?? 'Stream',
      type: 'direct',
      headers: headers.isEmpty ? null : headers,
      providerId: providerId,
    ),
  ];

  Future<void> openPlayer() async {
    await seedEngineWatchHistory(
      session: session,
      movie: playMovie,
      episodeNumber: epNum,
      season: ctx.season,
      episodes: playHubEpisodes,
    );
    if (isAborted() || !context.mounted) return;
    await AppRouter.openPlayer(
      context,
      streamUrl: url,
      title: playMovie.title,
      headers: headers.isEmpty ? null : headers,
      movie: playMovie,
      selectedSeason: needsEp ? (ctx.season ?? 1) : null,
      selectedEpisode: needsEp ? (ctx.episode ?? 1) : null,
      startPosition: ctx.startPosition,
      activeProvider: providerId,
      sources: sources,
      pinSource: false,
      streamsPrevalidated: true,
      externalSubtitles: stream == null
          ? null
          : catalogStreamExternalSubtitles(stream),
      stremioId: stremioIdFromSourcesBag(
        movie: ctx.movie,
        session: session,
        season: ctx.season,
        episode: ctx.episode,
      ),
      stremioAddonBaseUrl: stream?['_addonBaseUrl']?.toString(),
      enginePlaySession: session,
      episodes: playHubEpisodes,
      hubEpisodeNumber: epNum,
      magnetLink: magnet,
      fileIndex: torrentFileIndex,
      fadeTransition: loading.dialogContext != null,
    );
  }

  final dialogCtx = loading.dialogContext;
  if (dialogCtx != null && dialogCtx.mounted) {
    await crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: dialogCtx,
      fadeOutNotifier: loading.fadeOutNotifier,
      openPlayer: openPlayer,
    );
  } else {
    await openPlayer();
  }
  finishStreamLoadingSession(loading);
}

enum _GreenPlayWinKind { engine, http, torrent }

class _GreenPlayWin {
  const _GreenPlayWin._({
    required this.kind,
    this.enginePick,
    this.url,
    this.headers,
    this.providerId,
    this.stream,
    this.magnet,
    this.torrentFileIndex,
  });

  factory _GreenPlayWin.engine(EngineAutoPlayPick pick) => _GreenPlayWin._(
        kind: _GreenPlayWinKind.engine,
        enginePick: pick,
      );

  factory _GreenPlayWin.http({
    required String url,
    required Map<String, String> headers,
    required String? providerId,
    required Map<String, dynamic>? stream,
  }) =>
      _GreenPlayWin._(
        kind: _GreenPlayWinKind.http,
        url: url,
        headers: headers,
        providerId: providerId,
        stream: stream,
      );

  factory _GreenPlayWin.torrent({
    required String url,
    required String magnet,
    required int? fileIndex,
    required String? providerId,
  }) =>
      _GreenPlayWin._(
        kind: _GreenPlayWinKind.torrent,
        url: url,
        magnet: magnet,
        torrentFileIndex: fileIndex,
        providerId: providerId,
      );

  final _GreenPlayWinKind kind;
  final EngineAutoPlayPick? enginePick;
  final String? url;
  final Map<String, String>? headers;
  final String? providerId;
  final Map<String, dynamic>? stream;
  final String? magnet;
  final int? torrentFileIndex;
}
