import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_hooks.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_session.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shared/widgets/resolve_failure_view.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Whether hub details should show the white link Play (catalog Sources).
///
/// While [settingsPlaybackProvider] is still loading, uses the same optimistic
/// default as movie/TV [DetailsPlaySources.pending] (Forja engine on).
bool hubHasCatalogPanelSources(SettingsPlaybackSnapshot? snap) {
  final caps = PlatformPlayback.capabilities;
  if (snap == null) {
    return caps.playSourceEngine;
  }
  final torrent = snap.playSourceTorrent &&
      ((caps.playSourceTorrent && caps.builtinTorrentSearch) ||
          (!caps.localTorrentEngine && snap.playSourceTorrent));
  final stremio = snap.playSourceStremio &&
      (caps.playSourceStremio ||
          (!caps.localTorrentEngine && snap.playSourceStremio));
  final nuvio = snap.playSourceNuvio &&
      (caps.playSourceNuvio ||
          (!caps.localTorrentEngine && snap.playSourceNuvio));
  final engine = snap.playSourceEngine &&
      (caps.playSourceEngine ||
          (!caps.localTorrentEngine && snap.playSourceEngine));
  return torrent || stremio || nuvio || engine;
}

/// Opens the same Torrents / Stremio / Nuvio / Forja Sources panel as movies/TV,
/// then plays the picked row. Hub details stamp tab-local CW, not Home history.
Future<void> openHubCatalogSources({
  required BuildContext context,
  required Movie movie,
  int? season,
  int? episode,
  CatalogOpen? catalogOpen,
  int? malId,
  String? audioCategory,
  CatalogPlaySession? catalogPlaySession,
}) {
  final hooks = buildHubCatalogPlayHooks(
    movie: movie,
    season: season,
    episode: episode,
    catalogOpen: catalogOpen,
    malId: malId,
    audioCategory: audioCategory,
    catalogPlaySession: catalogPlaySession,
  );
  return PlayerSourcesPanel.show(
    context: context,
    movie: movie,
    season: season,
    episode: episode,
    catalogOpen: catalogOpen,
    malId: malId,
    animeAudioCategory: audioCategory,
    detailsHost: true,
    onTorrentSelected: (result) => _playTorrent(
      context: context,
      movie: movie,
      result: result,
      season: season,
      episode: episode,
      hooks: hooks,
    ),
    onStremioSelected: (stream) => _playStremio(
      context: context,
      movie: movie,
      stream: stream,
      season: season,
      episode: episode,
      hooks: hooks,
    ),
  );
}

Future<void> _openHubCatalogPlayer({
  required BuildContext context,
  required Movie movie,
  required HubCatalogPlayHooks hooks,
  required int? season,
  required int? episode,
  required Future<void> Function() open,
}) async {
  await hooks.seedInitial(movie: movie);
  if (!context.mounted) return;
  await open();
}

Future<void> _playTorrent({
  required BuildContext context,
  required Movie movie,
  required TorrentResult result,
  int? season,
  int? episode,
  required HubCatalogPlayHooks hooks,
}) async {
  final settings = SettingsService();
  final profile = PlatformPlayback.capabilities;
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  if (!context.mounted) return;
  if (!await ensureLanP2pPlayback(context)) return;
  if (!context.mounted) return;

  var cancelled = false;
  final overlayMessage = ValueNotifier<String>(
    playbackResolveLabel(useDebrid: useDebrid, debridService: debridService),
  );
  final fadeOutNotifier = ValueNotifier(false);
  final failureNotifier = ValueNotifier<ResolveFailure?>(null);
  BuildContext? loadingDialogContext;
  var cleanedUp = false;

  void cleanup() {
    if (cleanedUp) return;
    cleanedUp = true;
    disposeLoadingOverlayNotifiers([
      overlayMessage,
      fadeOutNotifier,
      failureNotifier,
    ]);
  }

  void popLoading() {
    final ctx = loadingDialogContext;
    loadingDialogContext = null;
    if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
  }

  Future<void> fail(String message) async {
    if (!context.mounted || cancelled) {
      popLoading();
      cleanup();
      return;
    }
    final action = Completer<void>();
    failureNotifier.value = ResolveFailure(
      title: 'Couldn’t start playback',
      detail: message,
      primaryLabel: 'Close',
      primaryIcon: Icons.close_rounded,
      onPrimary: () {
        if (!action.isCompleted) action.complete();
      },
    );
    await action.future;
    popLoading();
    cleanup();
  }

  showLoadingOverlayDialog(
    context,
    builder: (dialogContext) {
      loadingDialogContext = dialogContext;
      return LoadingOverlay(
        movie: movie,
        messageNotifier: overlayMessage,
        fadeOutNotifier: fadeOutNotifier,
        failureNotifier: failureNotifier,
        onCancel: () {
          cancelled = true;
          dismissLoadingOverlayRoute(dialogContext);
        },
      );
    },
  );

  await Future<void>.delayed(Duration.zero);
  if (!context.mounted || cancelled) {
    popLoading();
    cleanup();
    return;
  }

  String? resolvedUrl;
  var magnetLink = result.magnet;
  int? resolvedFileIndex;
  final linkResolver = LinkResolver();

  try {
    if (!magnetLink.startsWith('magnet:')) {
      overlayMessage.value = 'Resolving download link...';
      final resolved = await linkResolver.resolve(magnetLink);
      if (cancelled) {
        popLoading();
        cleanup();
        return;
      }
      if (resolved.isMagnet) {
        magnetLink = resolved.link;
      } else {
        await fail('Could not resolve a magnet link for this torrent.');
        return;
      }
    }

    overlayMessage.value = playbackResolveLabel(
      useDebrid: useDebrid,
      debridService: debridService,
    );

    final episodic = hubMediaIsEpisodic(movie);
    final playback = await resolveMagnetForPlayback(
      magnet: magnetLink,
      useDebrid: useDebrid,
      debridService: debridService,
      localTorrentEngine: profile.localTorrentEngine,
      season: episodic ? (season ?? 1) : null,
      episode: episodic ? (episode ?? 1) : null,
      onStatus: (status) {
        if (!cancelled) overlayMessage.value = status;
      },
    );
    if (cancelled) {
      if (playback != null) {
        LanClientService.instance.releaseLanTorrentIfNeeded(
          playUrl: playback.url,
          magnet: magnetLink,
        );
      } else if (!profile.localTorrentEngine) {
        LanClientService.instance.releaseLanTorrentAfterCancel(
          magnet: magnetLink,
        );
      }
      popLoading();
      cleanup();
      return;
    }
    if (playback == null || playback.url.isEmpty) {
      await fail('Torrent stream failed to start.');
      return;
    }
    resolvedUrl = playback.url;
    resolvedFileIndex = playback.fileIndex;
  } catch (e) {
    if (cancelled) {
      if (!profile.localTorrentEngine) {
        LanClientService.instance.releaseLanTorrentAfterCancel(
          magnet: magnetLink,
        );
      }
      popLoading();
      cleanup();
      return;
    }
    await fail(debridUserMessage(e, debridService));
    return;
  } finally {
    linkResolver.dispose();
  }

  final playUrl = resolvedUrl;
  if (!context.mounted || cancelled) {
    LanClientService.instance.releaseLanTorrentIfNeeded(
      playUrl: playUrl,
      magnet: magnetLink,
    );
    popLoading();
    cleanup();
    return;
  }

  final dialogContext = loadingDialogContext;
  if (dialogContext == null) {
    await fail('Torrent stream failed to start.');
    return;
  }

  final episodic = hubMediaIsEpisodic(movie);
  await crossfadeLoadingOverlayToPlayer(
    loadingDialogContext: dialogContext,
    fadeOutNotifier: fadeOutNotifier,
    openPlayer: () => _openHubCatalogPlayer(
      context: context,
      movie: movie,
      hooks: hooks,
      season: season,
      episode: episode,
      open: () => AppRouter.openPlayer(
        context,
        streamUrl: playUrl,
        title: movie.title,
        magnetLink: magnetLink,
        movie: movie,
        selectedSeason: episodic ? (season ?? 1) : null,
        selectedEpisode: episodic ? (episode ?? 1) : null,
        fileIndex: resolvedFileIndex,
        activeProvider: 'torrent',
        enginePlaySession: hooks.session,
        onSaveProgress: hooks.onSaveProgress,
        hubEpisodeNumber: hooks.episodeNumber,
        fadeTransition: true,
      ),
    ),
  );
  cleanup();
}

Future<void> _playStremio({
  required BuildContext context,
  required Movie movie,
  required Map<String, dynamic> stream,
  int? season,
  int? episode,
  required HubCatalogPlayHooks hooks,
}) async {
  final settings = SettingsService();
  final profile = PlatformPlayback.capabilities;
  final useDebrid = await settings.useDebridForStreams();
  final debridService = await settings.getDebridService();
  if (!context.mounted) return;

  final episodic = hubMediaIsEpisodic(movie);
  final stremioId = movie.imdbId;
  final stremioAddonBaseUrl = stream['_addonBaseUrl']?.toString();

  final precheck = classifyStremioStream(
    stream,
    profile,
    useDebrid: useDebrid,
    debridService: debridService,
  );

  if (precheck is StremioResolveFailure) {
    ForjaToast.info(precheck.message);
    return;
  }

  if (precheck is StremioPlayable) {
    try {
      final proxied = await proxyCatalogHttpStreamIfNeeded(
        streamUrl: precheck.streamUrl,
        headers: precheck.headers,
        stream: stream,
      );
      if (!context.mounted) return;
      await _openHubCatalogPlayer(
        context: context,
        movie: movie,
        hooks: hooks,
        season: season,
        episode: episode,
        open: () => AppRouter.openPlayer(
          context,
          streamUrl: proxied.url,
          title: movie.title,
          headers: proxied.headers,
          movie: movie,
          selectedSeason: episodic ? (season ?? 1) : null,
          selectedEpisode: episodic ? (episode ?? 1) : null,
          activeProvider: catalogHttpPlayProviderId(stream),
          externalSubtitles: catalogStreamExternalSubtitles(stream),
          stremioId: stremioId,
          stremioAddonBaseUrl: stremioAddonBaseUrl,
          enginePlaySession: hooks.session,
          onSaveProgress: hooks.onSaveProgress,
          hubEpisodeNumber: hooks.episodeNumber,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ForjaToast.info(
          'Couldn\'t start this stream. Try again or pick another source.',
        );
      }
    }
    return;
  }

  if (precheck is StremioExternalLink) {
    ForjaToast.info('Open this link from movie/TV details Sources.');
    return;
  }

  if (!await ensureLanP2pPlayback(context)) return;
  if (!context.mounted) return;

  var cancelled = false;
  final overlayMessage = ValueNotifier<String>(
    stremioResolveLoadingMessage(
      profile: profile,
      useDebrid: useDebrid,
      debridService: debridService,
    ),
  );
  final fadeOutNotifier = ValueNotifier(false);
  final failureNotifier = ValueNotifier<ResolveFailure?>(null);
  BuildContext? loadingDialogContext;

  showLoadingOverlayDialog(
    context,
    builder: (dialogContext) {
      loadingDialogContext = dialogContext;
      return LoadingOverlay(
        movie: movie,
        messageNotifier: overlayMessage,
        fadeOutNotifier: fadeOutNotifier,
        failureNotifier: failureNotifier,
        onCancel: () {
          cancelled = true;
          dismissLoadingOverlayRoute(dialogContext);
        },
      );
    },
  );

  final resolved = await resolveStremioStream(
    stream: stream,
    profile: profile,
    settings: settings,
    season: episodic ? (season ?? 1) : null,
    episode: episodic ? (episode ?? 1) : null,
    isCancelled: () => cancelled || !context.mounted,
    onStatus: (status) {
      if (!cancelled) overlayMessage.value = status;
    },
  );

  if (cancelled || !context.mounted) {
    disposeLoadingOverlayNotifiers([
      overlayMessage,
      fadeOutNotifier,
      failureNotifier,
    ]);
    return;
  }

  if (resolved is StremioPlayable && loadingDialogContext != null) {
    await crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: loadingDialogContext!,
      fadeOutNotifier: fadeOutNotifier,
      openPlayer: () => _openHubCatalogPlayer(
        context: context,
        movie: movie,
        hooks: hooks,
        season: season,
        episode: episode,
        open: () => AppRouter.openPlayer(
          context,
          streamUrl: resolved.streamUrl,
          title: movie.title,
          magnetLink: resolved.magnetLink,
          movie: movie,
          selectedSeason: episodic ? (season ?? 1) : null,
          selectedEpisode: episodic ? (episode ?? 1) : null,
          fileIndex: resolved.fileIndex,
          activeProvider: catalogHttpPlayProviderId(stream),
          externalSubtitles: catalogStreamExternalSubtitles(stream),
          stremioId: stremioId,
          stremioAddonBaseUrl: stremioAddonBaseUrl,
          enginePlaySession: hooks.session,
          onSaveProgress: hooks.onSaveProgress,
          hubEpisodeNumber: hooks.episodeNumber,
          fadeTransition: true,
        ),
      ),
    );
  } else if (resolved is StremioResolveFailure &&
      resolved.error != StremioPlaybackError.cancelled &&
      loadingDialogContext != null &&
      loadingDialogContext!.mounted) {
    final action = Completer<void>();
    failureNotifier.value = ResolveFailure(
      title: 'Couldn’t start playback',
      detail: resolved.message,
      primaryLabel: 'Close',
      primaryIcon: Icons.close_rounded,
      onPrimary: () {
        if (!action.isCompleted) action.complete();
      },
    );
    await action.future;
    if (loadingDialogContext != null &&
        loadingDialogContext!.mounted &&
        Navigator.of(loadingDialogContext!).canPop()) {
      Navigator.of(loadingDialogContext!).pop();
    }
  } else if (loadingDialogContext != null &&
      loadingDialogContext!.mounted &&
      Navigator.of(loadingDialogContext!).canPop()) {
    Navigator.of(loadingDialogContext!).pop();
  }

  disposeLoadingOverlayNotifiers([
    overlayMessage,
    fadeOutNotifier,
    failureNotifier,
  ]);
}
