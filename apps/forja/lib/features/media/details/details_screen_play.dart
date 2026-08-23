part of 'details_screen.dart';

mixin _DetailsScreenPlay on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  /// Loading overlay line under the status message — season/episode for TV,
  /// optionally joined with a torrent/debrid source hint.
  String? _loadingOverlaySubtitle({String? sourceHint}) {
    final parts = <String>[];
    if (_s._movie.mediaType == 'tv') {
      final s = _s._selectedSeason.toString().padLeft(2, '0');
      final e = _s._selectedEpisode.toString().padLeft(2, '0');
      parts.add('S${s}E$e');
    }
    final hint = sourceHint?.trim();
    if (hint != null && hint.isNotEmpty) parts.add(hint);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Duration? _startPositionForAutoPlay({required bool fromRoute}) {
    if (fromRoute) return widget.startPosition;
    final progress = _s._lastProgress;
    if (progress == null) return null;
    final pos = resumeStartPositionFromProgress(progress);
    return pos > Duration.zero ? pos : null;
  }

  void _failEpisodePlayPending() {
    if (!_s._episodePlayPending || !mounted) return;
    _s._episodePlayPending = false;
    if (!_s._hasPanelPlaySources && _s._playSourceWebstreaming) {
      unawaited(_s._startWebstreamingOnlyPlayback());
      return;
    }
    if (!_s._hasPanelPlaySources &&
        _s._playSourceEngine &&
        _s._playSourceEngineAutoStart) {
      unawaited(_s._startEngineAutoPlayback());
      return;
    }
    _s._openSourcesPanel();
  }

  void _failAutoPlayFromRoute() {
    if (!mounted) return;
    if (!_s._hasPanelPlaySources && _s._playSourceWebstreaming) {
      unawaited(_s._startWebstreamingOnlyPlayback());
      return;
    }
    if (!_s._hasPanelPlaySources &&
        _s._playSourceEngine &&
        _s._playSourceEngineAutoStart) {
      unawaited(_s._startEngineAutoPlayback());
      return;
    }
    _s._openSourcesPanel();
  }

  List<dynamic> _streamsForAutoPlay() {
    if (_s._isNuvioSource || _s._selectedSourceId == 'all_nuvio') {
      return _s._nuvioStreams.where(_s._nuvioStreamSelected).toList();
    }
    if (_s._isEngineSource || _s._selectedSourceId == EngineIds.allChip) {
      return _s._engineStreams.where(_s._engineStreamSelected).toList();
    }
    if (_s._selectedSourceId == 'all_stremio' || _s._isTorrentSource) {
      return _s._allCombinedStremioStreams;
    }
    return _s._stremioStreams;
  }

  void _consumeAutoPlayFlags({
    required bool fromRoute,
    required bool fromEpisode,
  }) {
    if (fromRoute) _s._autoPlayConsumed = true;
    if (fromEpisode) _s._episodePlayPending = false;
  }

  void _maybeAutoPlay() {
    final fromRoute = widget.autoPlay && !_s._autoPlayConsumed;
    final fromEpisode = _s._episodePlayPending;
    if (!fromRoute && !fromEpisode) return;
    if (!mounted || _s._isLoading) return;

    final progress = _s._lastProgress;
    final isContinueWatchingResume =
        fromRoute && widget.startPosition != null && progress != null;
    final episodeSavedPlayback =
        fromEpisode && hasSavedEpisodePlayback(progress);
    final savedMethod = isContinueWatchingResume || episodeSavedPlayback
        ? (progress?['method'] as String?)
        : null;

    // Home hero Play → webstreaming, else Forja auto when enabled.
    if (fromRoute && !isContinueWatchingResume) {
      if (_s._playSourceWebstreaming) {
        _consumeAutoPlayFlags(fromRoute: true, fromEpisode: fromEpisode);
        unawaited(_s._startWebstreamingOnlyPlayback());
        return;
      }
      if (_s._playSourceEngine && _s._playSourceEngineAutoStart) {
        _consumeAutoPlayFlags(fromRoute: true, fromEpisode: fromEpisode);
        unawaited(_s._startEngineAutoPlayback());
        return;
      }
    }

    if (savedMethod == 'stream') {
      final sourceId = progress?['sourceId'] as String? ?? '';
      if (_s._playSourceWebstreaming) {
        if (_s._isWebstreamingOnlyExtracting) return;
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        unawaited(
          _s._resumeContinueWatchingWebStream(sourceId, fromRoute: fromRoute),
        );
        return;
      }
    }

    if (savedMethod == 'amri' && _s._playSourceWebstreaming) {
      _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
      unawaited(_s._resumeContinueWatchingAmri(fromRoute: fromRoute));
      return;
    }

    if (savedMethod == 'stremio_direct' && _s._playSourceStremio) {
      if (_s._isStremioFetching || _s._isNuvioFetching) return;
      unawaited(() async {
        if (progress == null || !mounted) return;
        final ok = await resumeSavedStremioDirectStream(
          context: context,
          movie: _s._movie,
          progress: progress,
          startPosition: resumeStartPositionFromProgress(progress),
        );
        if (!mounted) return;
        if (ok) {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
          return;
        }
        if (fromEpisode) {
          setState(() => _s._episodePlayPending = false);
          _s._openSourcesPanel();
        } else {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: false);
          _failAutoPlayFromRoute();
        }
      }());
      return;
    }

    final startPosition = _startPositionForAutoPlay(fromRoute: fromRoute);

    // Episode picks never auto-launch torrent/stremio from search results.
    if (fromEpisode) {
      _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: true);
      return;
    }

    // Route auto-play must never fall through to torrent when saved method is
    // direct streaming.
    if (hasSavedEpisodePlayback(progress) &&
        _s._isDirectStreamingSavedMethod(savedMethod)) {
      return;
    }

    if (_s._playSourceTorrent &&
        (_s._playbackProfile.builtinTorrentSearch ||
            !_s._playbackProfile.localTorrentEngine)) {
      if (_s._isSearching) return;
      if (_s._allTorrentResults.isNotEmpty) {
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        final toPlay = savedMethod == 'torrent'
            ? (_s._historyMatchedTorrent() ?? _s._allTorrentResults.first)
            : _s._allTorrentResults.first;
        _playTorrent(toPlay, startPosition: startPosition);
        return;
      }
      if (savedMethod == 'torrent' &&
          progress != null &&
          (progress['magnetLink'] as String?)?.isNotEmpty == true) {
        _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
        unawaited(() async {
          final ok = await resumeSavedTorrentStream(
            context: context,
            movie: _s._movie,
            progress: progress,
            startPosition: resumeStartPositionFromProgress(progress),
          );
          if (!ok && mounted) _s._openSourcesPanel();
        }());
        return;
      }
    }

    if (_s._playSourceStremio) {
      if (_s._isStremioFetching || _s._isNuvioFetching) return;
      final streams = _streamsForAutoPlay();
      if (streams.isNotEmpty) {
        final stream = streams.first;
        if (stream is Map<String, dynamic>) {
          _consumeAutoPlayFlags(fromRoute: fromRoute, fromEpisode: fromEpisode);
          _playStremioStream(stream, startPosition: startPosition);
          return;
        }
      }
    }

    final torrentPending =
        _s._playSourceTorrent &&
        _s._playbackProfile.builtinTorrentSearch &&
        _s._isSearching;
    final stremioPending = _s._playSourceStremio && _s._isStremioFetching;
    final nuvioPending = _s._panelShowNuvio && _s._isNuvioFetching;
    final enginePending = _s._panelShowEngine && _s._isEngineFetching;
    if (torrentPending || stremioPending || nuvioPending || enginePending) {
      return;
    }

    if (fromEpisode) {
      _failEpisodePlayPending();
    } else if (fromRoute) {
      _consumeAutoPlayFlags(fromRoute: true, fromEpisode: false);
      _failAutoPlayFromRoute();
    }
  }
  void _playStremioStream(
    Map<String, dynamic> stream, {
    Duration? startPosition,
  }) async {
    final kind = catalogStreamKindLabel(stream);
    debugPrint(
      '[Details] play $kind stream '
      'infoHash=${stream['infoHash']} fileIdx=${stream['fileIdx']} '
      'url=${stream['url']}',
    );
    // Do not close Sources yet - closing mid-tap races the gesture arena
    // (pointer_router) and can cancel the resolve that starts next.
    final stremioId = widget.stremioItem?['id']?.toString() ?? _s._movie.imdbId;
    final stremioAddonBaseUrl =
        stream['_addonBaseUrl']?.toString() ?? _s._selectedSourceId;
    final isTv = _s._movie.mediaType == 'tv';

    final useDebrid = await _s._settings.useDebridForStreams();
    final debridService = await _s._settings.getDebridService();
    final precheck = classifyStremioStream(
      stream,
      _s._playbackProfile,
      useDebrid: useDebrid,
      debridService: debridService,
    );

    if (precheck is StremioExternalLink) {
      if (mounted && _s._sourcesPanelOpen) {
        _s._closeSourcesPanel(cancelEngineJobs: false);
      }
      await _handleExternalUrl(
        precheck.externalUrl,
        addonBaseUrl: stremioAddonBaseUrl,
      );
      return;
    }

    if (precheck is StremioResolveFailure) {
      if (mounted) {
        ForjaToast.info(precheck.message);
      }
      return;
    }

    if (precheck is StremioPlayable) {
      if (!mounted) return;
      final enginePluginId = stream['_enginePluginId']?.toString();
      if (enginePluginId != null && enginePluginId.isNotEmpty) {
        // Probe the tapped row under the loading overlay — closing Sources
        // alone looked like a no-op while siblings were checked silently.
        _s._streamCancelled = false;
        final overlayMessage = ValueNotifier<String>('CHECKING STREAM');
        final fadeOutNotifier = ValueNotifier(false);
        final failureNotifier = ValueNotifier<ResolveFailure?>(null);
        BuildContext? loadingDialogContext;
        showLoadingOverlayDialog(
          context,
          builder: (dialogContext) {
            loadingDialogContext = dialogContext;
            return LoadingOverlay(
              movie: _s._movie,
              messageNotifier: overlayMessage,
              fadeOutNotifier: fadeOutNotifier,
              failureNotifier: failureNotifier,
              subtitle: _loadingOverlaySubtitle(),
              onCancel: () => _s._dismissStreamLoadingDialog(dialogContext),
            );
          },
        );
        if (mounted && _s._sourcesPanelOpen) {
          _s._closeSourcesPanel(cancelEngineJobs: false);
        }
        try {
          // Manual pick: only the row they tapped (not every plugin sibling).
          final sources = await _buildProbedEnginePlaySources(
            _s,
            [stream],
            isAborted: () => !mounted || _s._streamCancelled,
            preferFirst: stream,
          );
          if (!mounted || _s._streamCancelled) {
            if (mounted) _s._claimTvHeroPlayAfterPlayer();
            return;
          }
          if (sources.isEmpty) {
            final ctx = loadingDialogContext;
            if (ctx != null && ctx.mounted) {
              dismissLoadingOverlayRoute(ctx);
            }
            ForjaToast.info(
              'This file isn’t available — try another source.',
            );
            return;
          }
          final primary = sources.first;
          final ctx = loadingDialogContext;
          Future<void> openPlayer() => AppRouter.openPlayer(
            context,
            streamUrl: primary.url,
            title: _s._movie.title,
            headers: primary.headers,
            movie: _s._movie,
            selectedSeason: isTv ? _s._selectedSeason : null,
            selectedEpisode: isTv ? _s._selectedEpisode : null,
            startPosition: startPosition,
            activeProvider:
                primary.providerId ?? catalogHttpPlayProviderId(stream),
            sources: sources,
            pinSource: true,
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
          if (mounted) _s._claimTvHeroPlayAfterPlayer();
        } catch (e, st) {
          debugPrint('[Details] Forja catalog play failed: $e\n$st');
          final ctx = loadingDialogContext;
          if (ctx != null && ctx.mounted) {
            dismissLoadingOverlayRoute(ctx);
          }
          if (mounted) {
            ForjaToast.info(
              'Couldn\'t start this stream. Try again or pick another source.',
            );
          }
        } finally {
          disposeLoadingOverlayNotifiers([
            overlayMessage,
            fadeOutNotifier,
            failureNotifier,
          ]);
        }
        return;
      }

      if (_s._sourcesPanelOpen) {
        _s._closeSourcesPanel(cancelEngineJobs: false);
      }
      try {
        final proxied = await proxyCatalogHttpStreamIfNeeded(
          streamUrl: precheck.streamUrl,
          headers: precheck.headers,
          stream: stream,
        );
        if (!mounted) return;
        await AppRouter.openPlayer(
          context,
          streamUrl: proxied.url,
          title: _s._movie.title,
          headers: proxied.headers,
          movie: _s._movie,
          selectedSeason: isTv ? _s._selectedSeason : null,
          selectedEpisode: isTv ? _s._selectedEpisode : null,
          startPosition: startPosition,
          activeProvider: catalogHttpPlayProviderId(stream),
          externalSubtitles: catalogStreamExternalSubtitles(stream),
          stremioId: stremioId,
          stremioAddonBaseUrl: stremioAddonBaseUrl,
        );
        if (mounted) _s._claimTvHeroPlayAfterPlayer();
      } catch (e, st) {
        debugPrint('[Details] Forja catalog play failed: $e\n$st');
        if (mounted) {
          ForjaToast.info(
            'Couldn\'t start this stream. Try again or pick another source.',
          );
        }
      }
      return;
    }

    if (!mounted) return;
    if (!await ensureLanP2pPlayback(context)) return;
    if (!mounted) return;
    _s._streamCancelled = false;
    final overlayMessage = ValueNotifier<String>(
      stremioResolveLoadingMessage(
        profile: _s._playbackProfile,
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
          movie: _s._movie,
          messageNotifier: overlayMessage,
          fadeOutNotifier: fadeOutNotifier,
          failureNotifier: failureNotifier,
          subtitle: _loadingOverlaySubtitle(
            sourceHint: playbackSourceHint(
              useDebrid: useDebrid,
              debridService: debridService,
            ),
          ),
          onCancel: () => _s._dismissStreamLoadingDialog(dialogContext),
        );
      },
    );
    if (mounted && _s._sourcesPanelOpen) {
      _s._closeSourcesPanel(cancelEngineJobs: false);
    }

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: _s._playbackProfile,
      settings: _s._settings,
      season: isTv ? _s._selectedSeason : null,
      episode: isTv ? _s._selectedEpisode : null,
      isCancelled: () => !mounted || _s._streamCancelled,
      onStatus: (status) {
        if (!_s._streamCancelled) overlayMessage.value = status;
      },
    );

    if (_s._streamCancelled) {
      disposeLoadingOverlayNotifiers([
        overlayMessage,
        fadeOutNotifier,
        failureNotifier,
      ]);
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
      return;
    }

    if (resolved is StremioPlayable && mounted) {
      final dialogContext = loadingDialogContext;
      if (dialogContext != null) {
        await crossfadeLoadingOverlayToPlayer(
          loadingDialogContext: dialogContext,
          fadeOutNotifier: fadeOutNotifier,
          openPlayer: () => AppRouter.openPlayer(
            context,
            streamUrl: resolved.streamUrl,
            title: _s._movie.title,
            magnetLink: resolved.magnetLink,
            movie: _s._movie,
            selectedSeason: isTv ? _s._selectedSeason : null,
            selectedEpisode: isTv ? _s._selectedEpisode : null,
            fileIndex: resolved.fileIndex,
            startPosition: startPosition,
            activeProvider: catalogHttpPlayProviderId(stream),
            externalSubtitles: catalogStreamExternalSubtitles(stream),
            stremioId: stremioId,
            stremioAddonBaseUrl: stremioAddonBaseUrl,
            fadeTransition: true,
          ),
        );
        if (mounted) _s._claimTvHeroPlayAfterPlayer();
      }
    } else if (resolved is StremioResolveFailure &&
        resolved.error != StremioPlaybackError.cancelled &&
        mounted &&
        loadingDialogContext != null &&
        loadingDialogContext!.mounted) {
      final action = Completer<void>();
      failureNotifier.value = ResolveFailure(
        title: 'Couldn’t start playback',
        detail: _friendlyResolveDetail(resolved.message),
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

  String _friendlyResolveDetail(String raw) {
    final m = raw.trim();
    if (m.isEmpty) {
      return 'We couldn’t open this stream. Try another source.';
    }
    final lower = m.toLowerCase();
    if (lower.contains('torrent file')) {
      return 'This release is a torrent file, not a magnet. Pick a magnet link instead.';
    }
    if (lower.contains('unsupported')) {
      return 'This stream type isn’t supported here. Try another source.';
    }
    if (lower.contains('debrid') && lower.contains('login')) {
      return 'Debrid sign-in failed. Check your API key in Settings, or turn off Debrid and try the local engine.';
    }
    if (lower.contains('debrid')) {
      return 'Debrid couldn’t resolve this link. Try another source, or check Settings → Debrid.';
    }
    if (lower.contains('magnet')) {
      return 'We couldn’t resolve a magnet for this torrent. Try another release.';
    }
    if (lower.contains('failed to resolve') ||
        lower.contains('failed to start') ||
        lower.contains('torrent stream failed')) {
      return 'We couldn’t open this stream. Try another source.';
    }
    return m;
  }

  /// Handles a Stremio externalUrl: stremio:///detail, stremio:///search, or web URLs.
  Future<void> _handleExternalUrl(String url, {String? addonBaseUrl}) async {
    // Try parsing as a stremio:// link
    final parsed = StremioService.parseMetaLink(url);
    if (parsed != null) {
      switch (parsed['action']) {
        case 'detail':
          var id = parsed['id']?.toString() ?? '';
          final type = parsed['type']?.toString() ?? 'movie';
          // Extract IMDB ID from prefixed IDs like "mlt-rec-tt14905854"
          if (!id.startsWith('tt')) {
            final imdbMatch = RegExp(r'(tt\d+)').firstMatch(id);
            if (imdbMatch != null) {
              id = imdbMatch.group(1)!;
            }
          }
          await _s._openRecommendation({'id': id, 'type': type, 'name': ''});
          return;

        case 'search':
          final query = parsed['query']?.toString() ?? '';
          if (query.isNotEmpty && mounted) {
            // Pop back to MainScreen, then fire the search notifier
            Navigator.popUntil(context, (route) => route.isFirst);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ShellBus.openStremioSearch(
                query: query,
                addonBaseUrl: addonBaseUrl ?? '',
              );
            });
          }
          return;

        case 'discover':
          // Open the catalog screen for this discover link
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StremioCatalogScreen()),
            );
          }
          return;
      }
    }

    // Regular https:// URL → open in external browser
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (mounted) {
      ForjaToast.error('Unable to handle this link');
    }
  }

  void _playTorrent(TorrentResult result, {Duration? startPosition}) async {
    debugPrint('[Details] play torrent title=${result.name}');
    // Reset before any await so a stale cancel from a prior overlay cannot
    // abort this play after settings load.
    _s._streamCancelled = false;

    final useDebrid = await _s._settings.useDebridForStreams();
    final debridService = await _s._settings.getDebridService();
    if (!mounted || _s._streamCancelled) return;
    if (!await ensureLanP2pPlayback(context)) return;
    if (!mounted || _s._streamCancelled) return;

    final overlayMessage = ValueNotifier<String>(
      playbackResolveLabel(useDebrid: useDebrid, debridService: debridService),
    );
    final fadeOutNotifier = ValueNotifier(false);
    final failureNotifier = ValueNotifier<ResolveFailure?>(null);
    BuildContext? loadingDialogContext;
    var cleanedUp = false;
    final sourceHint = playbackSourceHint(
      useDebrid: useDebrid,
      debridService: debridService,
    );

    void cleanupNotifiers() {
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
      if (ctx != null && ctx.mounted) {
        dismissLoadingOverlayRoute(ctx);
      }
    }

    Future<void> fail(String message) async {
      debugPrint('[Torrent] $message');
      if (!mounted || _s._streamCancelled) {
        popLoading();
        cleanupNotifiers();
        return;
      }
      final action = Completer<void>();
      failureNotifier.value = ResolveFailure(
        title: 'Couldn’t start playback',
        detail: _friendlyResolveDetail(message),
        primaryLabel: 'Close',
        primaryIcon: Icons.close_rounded,
        onPrimary: () {
          if (!action.isCompleted) action.complete();
        },
      );
      await action.future;
      popLoading();
      cleanupNotifiers();
    }

    // Show loading BEFORE closing Sources - closing the panel mid-tap disposes
    // gesture routes under the pointer (pointer_router asserts) and can dismiss
    // the new overlay / cancel the resolve with no logs.
    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _s._movie,
          messageNotifier: overlayMessage,
          fadeOutNotifier: fadeOutNotifier,
          failureNotifier: failureNotifier,
          subtitle: _loadingOverlaySubtitle(sourceHint: sourceHint),
          onCancel: () => _s._dismissStreamLoadingDialog(dialogContext),
        );
      },
    );

    if (mounted && _s._sourcesPanelOpen) {
      _s._closeSourcesPanel(cancelEngineJobs: false);
    }
    // Let the loading route paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._streamCancelled) {
      popLoading();
      cleanupNotifiers();
      return;
    }

    String? resolvedUrl;
    var magnetLink = result.magnet;
    int? resolvedFileIndex;

    try {
      if (!magnetLink.startsWith('magnet:')) {
        overlayMessage.value = 'Resolving download link...';
        final resolved = await _s._linkResolver.resolve(magnetLink);
        if (_s._streamCancelled) {
          popLoading();
          cleanupNotifiers();
          return;
        }
        if (resolved.isMagnet) {
          magnetLink = resolved.link;
        } else if (resolved.torrentBytes != null) {
          await fail(
            'Torrent file downloads not yet supported. Please use magnet links.',
          );
          return;
        } else {
          await fail('Could not resolve a magnet link for this torrent.');
          return;
        }
      }

      overlayMessage.value = playbackResolveLabel(
        useDebrid: useDebrid,
        debridService: debridService,
      );

      debugPrint(
        '[Torrent] resolving magnet '
        'debrid=$useDebrid service=$debridService '
        'localEngine=${_s._playbackProfile.localTorrentEngine}',
      );

      final isTv = _s._movie.mediaType == 'tv';
      final playback = await resolveMagnetForPlayback(
        magnet: magnetLink,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: _s._playbackProfile.localTorrentEngine,
        season: isTv ? _s._selectedSeason : null,
        episode: isTv ? _s._selectedEpisode : null,
        onStatus: (status) {
          if (!_s._streamCancelled) overlayMessage.value = status;
        },
      );
      if (_s._streamCancelled) {
        if (playback != null) {
          LanClientService.instance.releaseLanTorrentIfNeeded(
            playUrl: playback.url,
            magnet: magnetLink,
          );
        } else if (!_s._playbackProfile.localTorrentEngine) {
          LanClientService.instance.releaseLanTorrentAfterCancel(
            magnet: magnetLink,
          );
        }
        popLoading();
        cleanupNotifiers();
        return;
      }
      if (playback == null || playback.url.isEmpty) {
        await fail('Torrent stream failed to start.');
        return;
      }
      resolvedUrl = playback.url;
      resolvedFileIndex = playback.fileIndex;
      debugPrint('[Torrent] Playing via ${playback.sourceLabel}');
    } catch (e, st) {
      debugPrint('[Torrent] Stream error: $e\n$st');
      if (_s._streamCancelled) {
        if (!_s._playbackProfile.localTorrentEngine) {
          LanClientService.instance.releaseLanTorrentAfterCancel(
            magnet: magnetLink,
          );
        }
        popLoading();
        cleanupNotifiers();
        return;
      }
      final message = e is DebridAuthException
          ? e.toString()
          : debridUserMessage(e, debridService);
      await fail(message);
      return;
    }

    if (!mounted || _s._streamCancelled) {
      if (resolvedUrl != null) {
        LanClientService.instance.releaseLanTorrentIfNeeded(
          playUrl: resolvedUrl!,
          magnet: magnetLink,
        );
      } else if (!_s._playbackProfile.localTorrentEngine) {
        LanClientService.instance.releaseLanTorrentAfterCancel(
          magnet: magnetLink,
        );
      }
      popLoading();
      cleanupNotifiers();
      return;
    }

    final dialogContext = loadingDialogContext;
    if (dialogContext == null) {
      await fail('Torrent stream failed to start.');
      return;
    }

    await crossfadeLoadingOverlayToPlayer(
      loadingDialogContext: dialogContext,
      fadeOutNotifier: fadeOutNotifier,
      openPlayer: () => AppRouter.openPlayer(
        context,
        streamUrl: resolvedUrl!,
        title: _s._movie.title,
        magnetLink: magnetLink,
        movie: _s._movie,
        selectedSeason:
            _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
        selectedEpisode:
            _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
        fileIndex: resolvedFileIndex,
        startPosition: startPosition,
        activeProvider: 'torrent',
        fadeTransition: true,
      ),
    );
    if (mounted) _s._claimTvHeroPlayAfterPlayer();
    cleanupNotifiers();
  }
}
