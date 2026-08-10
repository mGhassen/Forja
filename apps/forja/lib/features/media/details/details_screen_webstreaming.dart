part of 'details_screen.dart';

mixin _DetailsScreenWebstreaming on ConsumerState<DetailsScreen> {
  _DetailsScreenState get _s => this as _DetailsScreenState;

  Future<void> _resumeEpisodeWebStream(String providerId) async {
    final progress = _s._lastProgress;
    if (progress == null || !mounted) return;
    final startPosition = _s._startPositionForAutoPlay(fromRoute: false);
    var ok = await resumeSavedWebStreamProvider(
      context: context,
      movie: _s._movie,
      progress: progress,
      startPosition: startPosition,
    );
    if (ok) {
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
      return;
    }
    if (!mounted) return;
    if (await _tryResumeWebStreamFromWatchHistory(startPosition)) {
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
      return;
    }
    if (mounted) await _startWebstreamingOnlyPlayback();
  }
  void _onPlayStreamingPressed() {
    unawaited(_playWebstreamingFromDetails());
  }

  Future<void> _playWebstreamingFromDetails() async {
    // Overlay first - cache probe can take hundreds of ms with no UI.
    // Do not re-await watch history here: `_lastProgress` is already loaded in
    // initState and kept fresh via historyStream.
    await _startWebstreamingOnlyPlayback(hydrateCache: true);
  }

  String _webstreamingCacheKey() => WebstreamingStreamCache.cacheKeyFromProgress(
    tmdbId: _s._movie.id,
    mediaType: _s._movie.mediaType,
    season: _s._movie.mediaType == 'tv' ? _s._selectedSeason : null,
    episode: _s._movie.mediaType == 'tv' ? _s._selectedEpisode : null,
  );

  void _applyWebstreamingCacheHit(WebstreamingCacheHit hit) {
    _s._webstreamingStreams = hit.sources;
    _s._webstreamingActiveProviderId = hit.providerId;
  }

  Future<void> _hydrateWebstreamingFromCache() async {
    if (!_s._playSourceWebstreaming || _s._webstreamingStreams.isNotEmpty) return;
    final cached = await WebstreamingStreamCache.readLive(
      _webstreamingCacheKey(),
      probe: probeStreamSourceUrl,
    );
    if (cached == null || cached.sources.isEmpty || !mounted) return;
    setState(() => _applyWebstreamingCacheHit(cached));
    debugPrint(
      '[DetailsScreen] hydrated webstreaming cache '
      '${cached.providerId} (${cached.sources.length})',
    );
  }

  Future<void> _persistWebstreamingCache({
    required String providerId,
    required List<StreamSource> sources,
  }) async {
    if (sources.isEmpty) return;
    await WebstreamingStreamCache.write(
      _webstreamingCacheKey(),
      WebstreamingCacheHit(providerId: providerId, sources: sources),
    );
  }

  Future<void> _rememberWebstreamingSelection(
    String sourceUrl,
    String sourceTitle,
    ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache,
  ) async {
    if (sourceUrl.trim().isEmpty) return;
    final cache = providerSourcesCache?.value ?? const {};
    String? providerId;
    List<StreamSource>? providerSources;
    for (final entry in cache.entries) {
      final match = entry.value.any((s) => s.url == sourceUrl);
      if (!match) continue;
      providerId = entry.key;
      providerSources = entry.value;
      break;
    }
    providerId ??= _s._webstreamingActiveProviderId;
    providerSources ??= _s._webstreamingStreams;
    if (providerId == null || providerSources.isEmpty) return;
    // Keep extraction order - player server panel must not reshuffle on play.
    final hasSelected = providerSources.any((s) => s.url == sourceUrl);
    final sources = hasSelected
        ? List<StreamSource>.from(providerSources)
        : [
            ...providerSources,
            StreamSource(
              url: sourceUrl,
              title: sourceTitle,
              type: sourceUrl.contains('.m3u8') ? 'hls' : 'video',
            ),
          ];
    if (!mounted) return;
    setState(() {
      _s._webstreamingActiveProviderId = providerId;
      _s._webstreamingStreams = sources;
    });
    await _persistWebstreamingCache(providerId: providerId, sources: sources);
  }

  /// Prefer last-played URL when it still exists - do not reorder the list.
  StreamSource _preferredWebstreamingSource(List<StreamSource> sources) {
    final savedUrl = _s._lastProgress?['streamUrl'] as String?;
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      for (final s in sources) {
        if (s.url == savedUrl) return s;
      }
    }
    return sources.first;
  }

  Future<void> _startWebstreamingOnlyPlayback({
    bool hydrateCache = false,
  }) async {
    if (_s._isWebstreamingOnlyExtracting) return;

    final playGen = ++_s._webstreamingPlayGen;
    if (mounted) {
      setState(() => _s._isWebstreamingOnlyExtracting = true);
    } else {
      _s._isWebstreamingOnlyExtracting = true;
    }
    _s._webstreamingOnlyExtractionCancelled = false;

    bool playAborted() =>
        !mounted ||
        playGen != _s._webstreamingPlayGen ||
        _s._webstreamingOnlyExtractionCancelled;

    // One overlay for cache probe + cold extract. Dismissing then re-showing
    // looked like Cancel "didn't work" (flash off → CANCEL again).
    final fadeOutNotifier = ValueNotifier(false);
    final messageNotifier = ValueNotifier('Loading stream…');
    final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
    final failureNotifier = ValueNotifier<ResolveFailure?>(null);
    final sourcesListNotifier = ValueNotifier<List<StreamSource>>(const []);
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );
    BuildContext? loadingDialogContext;
    var openedPlayer = false;
    var handedToExtraction = false;
    void Function(String)? onManualProviderCheck;

    List<ChangeNotifier> overlayNotifiers() => [
      fadeOutNotifier,
      messageNotifier,
      failureNotifier,
      probeNotifier,
      sourcesListNotifier,
      providerSourcesCache,
    ];

    void dismissLoading() {
      final ctx = loadingDialogContext;
      loadingDialogContext = null;
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
    }

    void cancelWebstreamingPlay() {
      if (playGen != _s._webstreamingPlayGen) return;
      _s._webstreamingOnlyExtractionCancelled = true;
      PlaybackEngine.cancelAllPending();
      dismissLoading();
      // Extraction finally owns the flag after handoff — clearing here lets a
      // concurrent Play spawn a second overlay while the first resolve unwinds.
      if (handedToExtraction) return;
      if (mounted) {
        setState(() => _s._isWebstreamingOnlyExtracting = false);
      } else {
        _s._isWebstreamingOnlyExtracting = false;
      }
    }

    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _s._movie,
          messageNotifier: messageNotifier,
          providerProbesNotifier: probeNotifier,
          fadeOutNotifier: fadeOutNotifier,
          failureNotifier: failureNotifier,
          subtitle: _s._loadingOverlaySubtitle(),
          onCancel: cancelWebstreamingPlay,
          onManualCheckProvider: (id) => onManualProviderCheck?.call(id),
        );
      },
    );
    // Let the loading route paint before cache / probe work.
    await Future<void>.delayed(Duration.zero);
    if (playAborted()) {
      dismissLoading();
      disposeLoadingOverlayNotifiers(overlayNotifiers());
      _s._isWebstreamingOnlyExtracting = false;
      return;
    }

    try {
      if (hydrateCache) {
        await _hydrateWebstreamingFromCache();
        if (playAborted()) return;
      }

      final startPosition = _s._startPositionForAutoPlay(fromRoute: false);

      if (_s._webstreamingStreams.isNotEmpty) {
        final preferred = _preferredWebstreamingSource(_s._webstreamingStreams);
        // Hydrate probes sources.first; preferred may be a different saved URL.
        final alreadyLive = hydrateCache &&
            preferred.url == _s._webstreamingStreams.first.url;
        final playable = !isUnplayableCachedStreamUrl(preferred.url) &&
            (alreadyLive ||
                await probeStreamSourceUrl(preferred.url, preferred.headers));
        if (playable) {
          if (playAborted()) return;
          final ctx = loadingDialogContext;
          if (ctx != null && ctx.mounted) {
            openedPlayer = true;
            await _playWebstreamingStream(
              preferred,
              startPosition: startPosition,
              loadingDialogContext: ctx,
              fadeOutNotifier: fadeOutNotifier,
            );
          } else {
            await _playWebstreamingStream(
              preferred,
              startPosition: startPosition,
            );
          }
          return;
        }
        // Stale in-memory extract (expired JWT / dead CDN) - drop and re-resolve.
        await WebstreamingStreamCache.drop(_webstreamingCacheKey());
        if (mounted) {
          setState(() {
            _s._webstreamingStreams = [];
            _s._webstreamingActiveProviderId = null;
          });
        }
      }

      final cached = await WebstreamingStreamCache.readLive(
        _webstreamingCacheKey(),
        probe: probeStreamSourceUrl,
      );
      if (playAborted()) return;
      if (cached != null && cached.sources.isNotEmpty) {
        setState(() => _applyWebstreamingCacheHit(cached));
        debugPrint(
          '[DetailsScreen] webstreaming cache hit '
          '${cached.providerId} (${cached.sources.length})',
        );
        final ctx = loadingDialogContext;
        if (ctx != null && ctx.mounted) {
          openedPlayer = true;
          await _playWebstreamingStream(
            _preferredWebstreamingSource(cached.sources),
            startPosition: startPosition,
            loadingDialogContext: ctx,
            fadeOutNotifier: fadeOutNotifier,
          );
        } else {
          await _playWebstreamingStream(
            _preferredWebstreamingSource(cached.sources),
            startPosition: startPosition,
          );
        }
        return;
      }

      if (await _tryResumeWebStreamFromWatchHistory(
        startPosition,
        loadingDialogContext: loadingDialogContext,
        fadeOutNotifier: fadeOutNotifier,
        onOpenedPlayer: () => openedPlayer = true,
        isAborted: playAborted,
      )) {
        return;
      }

      if (playAborted()) return;

      // Keep the same overlay — fill probes in place (no dismiss → re-show).
      handedToExtraction = true;
      await _runWebstreamingOnlyExtraction(
        startPosition: startPosition,
        playGen: playGen,
        loadingDialogContext: loadingDialogContext,
        fadeOutNotifier: fadeOutNotifier,
        messageNotifier: messageNotifier,
        probeNotifier: probeNotifier,
        failureNotifier: failureNotifier,
        sourcesListNotifier: sourcesListNotifier,
        providerSourcesCache: providerSourcesCache,
        bindManualProviderCheck: (fn) => onManualProviderCheck = fn,
        onLoadingDialogContextChanged: (ctx) => loadingDialogContext = ctx,
      );
    } finally {
      if (!handedToExtraction) {
        if (!openedPlayer) dismissLoading();
        disposeLoadingOverlayNotifiers(overlayNotifiers());
        if (mounted) {
          setState(() => _s._isWebstreamingOnlyExtracting = false);
        } else {
          _s._isWebstreamingOnlyExtracting = false;
        }
      }
    }
  }

  /// Last-resume layer: reopen the saved URL + provider from watch history
  /// without re-racing extractors (survives cache drops after built-in fail).
  Future<bool> _tryResumeWebStreamFromWatchHistory(
    Duration? startPosition, {
    BuildContext? loadingDialogContext,
    ValueNotifier<bool>? fadeOutNotifier,
    VoidCallback? onOpenedPlayer,
    bool Function()? isAborted,
  }) async {
    final progress = _s._lastProgress;
    if (progress == null || progress['method'] != 'stream') return false;
    final savedUrl = progress['streamUrl'] as String?;
    final rawSourceId = progress['sourceId'] as String? ?? '';
    if (savedUrl == null ||
        savedUrl.trim().isEmpty ||
        isTorrentStreamUrl(savedUrl) ||
        isUnplayableCachedStreamUrl(savedUrl)) {
      return false;
    }
    if (isAborted?.call() ?? false) return false;
    if (!await probeStreamSourceUrl(savedUrl, null)) return false;
    if (isAborted?.call() ?? false) return false;
    final sourceId = isWebStreamProviderId(rawSourceId)
        ? rawSourceId
        : (_s._webstreamingActiveProviderId ?? 'stream');
    final source = StreamSource(
      url: savedUrl,
      title: _webstreamingProviderLabel(sourceId),
      type: savedUrl.contains('.m3u8')
          ? 'hls'
          : savedUrl.contains('.mpd')
          ? 'dash'
          : 'video',
    );
    if (!mounted) return false;
    setState(() {
      _s._webstreamingActiveProviderId = sourceId;
      _s._webstreamingStreams = [source];
    });
    await _persistWebstreamingCache(providerId: sourceId, sources: [source]);
    debugPrint(
      '[DetailsScreen] watch-history stream resume $sourceId '
      '(${startPosition?.inSeconds ?? 0}s)',
    );
    final ctx = loadingDialogContext;
    if (ctx != null && ctx.mounted) {
      onOpenedPlayer?.call();
      await _playWebstreamingStream(
        source,
        startPosition: startPosition,
        loadingDialogContext: ctx,
        fadeOutNotifier: fadeOutNotifier,
      );
    } else {
      await _playWebstreamingStream(source, startPosition: startPosition);
    }
    return true;
  }

  Future<void> _resumeContinueWatchingWebStream(
    String providerId, {
    required bool fromRoute,
  }) async {
    final progress = _s._lastProgress;
    if (progress == null) {
      if (fromRoute) {
        _s._failAutoPlayFromRoute();
      }
      return;
    }
    final ok = await resumeSavedWebStreamProvider(
      context: context,
      movie: _s._movie,
      progress: progress,
      startPosition: _s._startPositionForAutoPlay(fromRoute: fromRoute),
    );
    if (ok) {
      if (mounted) _s._claimTvHeroPlayAfterPlayer();
      return;
    }
    if (!mounted) return;
    if (fromRoute) {
      _s._failAutoPlayFromRoute();
      return;
    }
    await _resumeEpisodeWebStream(providerId);
  }

  Future<void> _resumeContinueWatchingAmri({required bool fromRoute}) async {
    final progress = _s._lastProgress;
    if (progress == null) {
      if (fromRoute) _s._failAutoPlayFromRoute();
      return;
    }
    final ok = await resumeSavedAmriStream(
      context: context,
      movie: _s._movie,
      progress: progress,
      startPosition: _s._startPositionForAutoPlay(fromRoute: fromRoute),
    );
    if (ok || !mounted) return;
    if (fromRoute) {
      _s._failAutoPlayFromRoute();
      return;
    }
    if (_s._playSourceWebstreaming) await _startWebstreamingOnlyPlayback();
  }

  Future<void> _runWebstreamingOnlyExtraction({
    Duration? startPosition,
    required int playGen,
    required BuildContext? loadingDialogContext,
    required ValueNotifier<bool> fadeOutNotifier,
    required ValueNotifier<String> messageNotifier,
    required ValueNotifier<List<StreamProviderProbe>> probeNotifier,
    required ValueNotifier<ResolveFailure?> failureNotifier,
    required ValueNotifier<List<StreamSource>> sourcesListNotifier,
    required ValueNotifier<Map<String, List<StreamSource>>>
        providerSourcesCache,
    required void Function(void Function(String)?) bindManualProviderCheck,
    required void Function(BuildContext?) onLoadingDialogContextChanged,
  }) async {
    List<ChangeNotifier> allNotifiers() => [
      fadeOutNotifier,
      messageNotifier,
      failureNotifier,
      probeNotifier,
      sourcesListNotifier,
      providerSourcesCache,
    ];

    void abandonSharedOverlay(BuildContext? ctx) {
      bindManualProviderCheck(null);
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
      onLoadingDialogContextChanged(null);
      if (mounted) {
        setState(() => _s._isWebstreamingOnlyExtracting = false);
      } else {
        _s._isWebstreamingOnlyExtracting = false;
      }
      disposeLoadingOverlayNotifiers(allNotifiers());
    }

    if (!mounted ||
        playGen != _s._webstreamingPlayGen ||
        _s._webstreamingOnlyExtractionCancelled) {
      abandonSharedOverlay(loadingDialogContext);
      return;
    }
    if (mounted) {
      setState(() => _s._isWebstreamingOnlyExtracting = true);
    } else {
      _s._isWebstreamingOnlyExtracting = true;
    }
    var liveNotifiersDisposed = false;
    var overlayNotifiersDisposed = false;
    var dialogContext = loadingDialogContext;
    var switchingManualProvider = false;
    String? pendingManualProviderId;
    var preferredProvider = SourceEngine.auto;

    void dismissLoading() {
      final ctx = dialogContext;
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
      dialogContext = null;
      onLoadingDialogContextChanged(null);
    }

    bool playAborted() =>
        !mounted ||
        playGen != _s._webstreamingPlayGen ||
        _s._webstreamingOnlyExtractionCancelled;

    void requestManualProviderCheck(String providerId) {
      if (playAborted()) return;
      if (TvStreamFallback.isSkippedOnTv(providerId, _orderedWebstreamingProviders)) {
        return;
      }
      pendingManualProviderId = providerId;
      switchingManualProvider = true;
      PlaybackEngine.cancelAllPending();
    }

    bindManualProviderCheck(requestManualProviderCheck);
    messageNotifier.value = 'Finding servers…';

    await WidgetsBinding.instance.endOfFrame;
    if (playAborted() || !mounted) {
      abandonSharedOverlay(dialogContext);
      dialogContext = null;
      liveNotifiersDisposed = true;
      overlayNotifiersDisposed = true;
      return;
    }

    final providers = PlatformInfo.isAndroidTv
        ? TvStreamFallback.prioritizeProviders(_orderedWebstreamingProviders)
        : _orderedWebstreamingProviders;
    var found = false;

    try {
      final orderedKeys = SourceEngine.orderProviderIds(
        domain: SourceDomain.fromMediaType(_s._movie.mediaType),
        candidateIds: providers.keys,
        settingsOrder: _s._webstreamingProviderOrder,
      );
      if (orderedKeys.isNotEmpty) {
        final firstActiveIdx = orderedKeys.indexWhere(
          (k) => !TvStreamFallback.isSkippedOnTv(k, providers),
        );
        probeNotifier.value = [
          for (var i = 0; i < orderedKeys.length; i++)
            StreamProviderProbe(
              id: orderedKeys[i],
              label: _webstreamingProviderLabel(orderedKeys[i]),
              status: TvStreamFallback.isSkippedOnTv(orderedKeys[i], providers)
                  ? StreamProviderProbeStatus.skippedOnTv
                  : StreamProviderProbeStatus.pending,
              isPreferred: i == (firstActiveIdx >= 0 ? firstActiveIdx : 0),
            ),
        ];
      }

      StreamProviderProbeStatus probeStatusFromProgress(String status) {
        return switch (status) {
          'success' => StreamProviderProbeStatus.success,
          'failed' => StreamProviderProbeStatus.failed,
          'trying' => StreamProviderProbeStatus.trying,
          'skipped' => StreamProviderProbeStatus.skippedOnTv,
          _ => StreamProviderProbeStatus.pending,
        };
      }

      void syncResolvedHits(List<PlaybackResolveHit> hits) {
        if (hits.isEmpty || playAborted() || switchingManualProvider) {
          return;
        }
        providerSourcesCache.value = PlaybackEngine.hitsToProviderCache(hits);
        sourcesListNotifier.value = PlaybackEngine.mergeHitSources(hits);
        final best = hits.first;
        if (mounted) {
          setState(() {
            _s._webstreamingStreams = best.streamSources;
            _s._webstreamingActiveProviderId = best.providerId;
          });
        }
        final scope = ProviderScoreProbeSync.scopeFromPlayer(
          movie: _s._movie,
          providers: providers,
          selectedSeason: _s._selectedSeason,
          selectedEpisode: _s._selectedEpisode,
        );
        var probes = probeNotifier.value;
        for (final hit in hits) {
          final pid = hit.providerId;
          final idx = probes.indexWhere((p) => p.id == pid);
          if (idx >= 0) {
            probes = [
              for (final p in probes)
                if (p.id == pid)
                  p.copyWith(status: StreamProviderProbeStatus.success)
                else
                  p,
            ];
          }
        }
        probeNotifier.value = probes;
        // Only finished hits - not partial cache from abandoned checks.
        unawaited(
          ProviderScoreProbeSync.syncSourcesCache(
            scope: scope,
            sourcesByProvider: {
              for (final hit in hits)
                if (hit.streamSources.isNotEmpty)
                  hit.providerId: hit.streamSources,
            },
          ),
        );
      }

      void applyProbeProgress(String providerId, String status) {
        if (!mounted || switchingManualProvider) return;
        final nextStatus = probeStatusFromProgress(status);
        final existing = probeNotifier.value;
        final idx = existing.indexWhere((p) => p.id == providerId);
        if (idx < 0) {
          probeNotifier.value = [
            ...existing,
            StreamProviderProbe(
              id: providerId,
              label: _webstreamingProviderLabel(providerId),
              status: nextStatus,
              isPreferred: existing.isEmpty,
            ),
          ];
        } else {
          probeNotifier.value = existing
              .map(
                (probe) => probe.id == providerId
                    ? probe.copyWith(status: nextStatus)
                    : probe,
              )
              .toList();
        }
        final hasSources =
            (providerSourcesCache.value[providerId] ?? []).isNotEmpty;
        unawaited(
          ProviderScoreProbeSync.onProbeStatusChanged(
            scope: ProviderScoreProbeSync.scopeFromPlayer(
              movie: _s._movie,
              providers: providers,
              selectedSeason: _s._selectedSeason,
              selectedEpisode: _s._selectedEpisode,
            ),
            providerId: providerId,
            status: nextStatus,
            hasSources: hasSources,
          ),
        );
      }

      void prepareProbesForPreferred(String preferred) {
        final isManual = !SourceEngine.isAuto(preferred);
        probeNotifier.value = [
          for (final p in probeNotifier.value)
            StreamProviderProbe(
              id: p.id,
              label: p.label,
              status: p.status == StreamProviderProbeStatus.trying
                  ? StreamProviderProbeStatus.pending
                  : p.status,
              isPreferred: isManual
                  ? p.id == preferred
                  : p.isPreferred,
            ),
        ];
      }

      final useSimpleResolve =
          await _s._settings.isSimpleStreamingResolveEnabled();

      PlaybackResolveHit? hit;
      while (mounted && !playAborted()) {
        switchingManualProvider = false;
        final preferred = preferredProvider;
        prepareProbesForPreferred(preferred);

        final cancelled = () => playAborted() || switchingManualProvider;

        hit = useSimpleResolve
            ? await SimpleStreamingResolve.resolve(
                providers: providers,
                movie: _s._movie,
                season: _s._selectedSeason,
                episode: _s._selectedEpisode,
                preferredProvider: preferred,
                settingsOrder: _s._webstreamingProviderOrder,
                isCancelled: cancelled,
                onProgress: applyProbeProgress,
              )
            : await PlaybackService.resolveWebstreaming(
                providers: providers,
                movie: _s._movie,
                season: _s._selectedSeason,
                episode: _s._selectedEpisode,
                preferredProvider: preferred,
                settingsOrder: _s._webstreamingProviderOrder,
                isCancelled: cancelled,
                onHitsUpdated: syncResolvedHits,
                onProgress: applyProbeProgress,
              );

        if (useSimpleResolve && hit != null) {
          syncResolvedHits([hit]);
        }

        if (playAborted()) {
          hit = null;
          break;
        }
        if (switchingManualProvider && pendingManualProviderId != null) {
          preferredProvider = pendingManualProviderId!;
          pendingManualProviderId = null;
          continue;
        }
        break;
      }

      final manualPick = !SourceEngine.isAuto(preferredProvider);

      if (playAborted()) {
        // cancelled
      } else if (hit != null) {
        found = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final key = hit.providerId;
        // Winner first - otherwise pin/failover can open a sibling instead.
        final sources = <StreamSource>[
          for (final s in hit.streamSources)
            if (s.url == hit.streamUrl) s,
          for (final s in hit.streamSources)
            if (s.url != hit.streamUrl) s,
        ];
        final result = StreamProviderResolveResult(
          streamUrl: hit.streamUrl,
          audioUrl: hit.audioUrl,
          headers: hit.headers,
          sources: sources,
          subtitles: hit.subtitles,
        );

        if (!mounted) {
          // skip
        } else {
          setState(() {
            _s._webstreamingStreams = sources;
            _s._webstreamingActiveProviderId = key;
          });
          // Do not disk-cache until mpv confirms playback - dead resolves must
          // not poison the next Play for any provider.

          final isTv = _s._movie.mediaType == 'tv';
          final title = isTv
              ? '${_s._movie.title} - S${_s._selectedSeason} E${_s._selectedEpisode}'
              : _s._movie.title;
          final ctx = dialogContext;
          if (ctx != null && ctx.mounted) {
            final playerFuture = crossfadeLoadingOverlayToPlayer(
              loadingDialogContext: ctx,
              fadeOutNotifier: fadeOutNotifier,
              openPlayer: () => AppRouter.openPlayer(
                context,
                streamUrl: result.streamUrl,
                audioUrl: result.audioUrl,
                title: title,
                headers: result.headers,
                movie: _s._movie,
                providers: providers,
                activeProvider: key,
                selectedSeason: isTv ? _s._selectedSeason : null,
                selectedEpisode: isTv ? _s._selectedEpisode : null,
                startPosition: startPosition ?? widget.startPosition,
                sources: sources,
                externalSubtitles: result.subtitles,
                providerSourcesCache: providerSourcesCache,
                providerProbesNotifier: probeNotifier,
                // Manual list pick pins; Auto race keeps failover on.
                // Simple resolve: streams already probed - no Auto re-race.
                pinSource: manualPick || useSimpleResolve,
                streamsPrevalidated: useSimpleResolve,
                onSourcePinned: (sourceUrl, sourceTitle) =>
                    _rememberWebstreamingSelection(
                      sourceUrl,
                      sourceTitle,
                      providerSourcesCache,
                    ),
                fadeTransition: true,
              ),
            );
            await playerFuture;
            if (mounted) _s._claimTvHeroPlayAfterPlayer();
            _s._webstreamingOnlyExtractionCancelled = true;
            PlaybackEngine.cancelAllPending();
            liveNotifiersDisposed = true;
            disposeLoadingOverlayNotifiers([
              sourcesListNotifier,
              providerSourcesCache,
              probeNotifier,
            ]);
          } else {
            await _playWebstreamingStream(
              sources.first,
              startPosition: startPosition,
            );
          }
        }
      }

      if (!found && mounted && !playAborted()) {
        final action = Completer<bool>();
        failureNotifier.value = ResolveFailure(
          title: 'Couldn’t start playback',
          detail:
              'None of the servers returned a working stream right now.',
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
        if (retry && mounted) {
          // Restart after the overlay is gone so probes/notifiers are fresh.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_startWebstreamingOnlyPlayback());
          });
        }
      }
    } finally {
      bindManualProviderCheck(null);
      if (mounted) {
        setState(() => _s._isWebstreamingOnlyExtracting = false);
      } else {
        _s._isWebstreamingOnlyExtracting = false;
      }
      // Dismiss may already have run on cancel; ensure route is gone before
      // disposing notifiers the overlay still listens to.
      dismissLoading();
      if (!overlayNotifiersDisposed) {
        final pending = <ChangeNotifier>[
          fadeOutNotifier,
          messageNotifier,
          failureNotifier,
          if (!liveNotifiersDisposed) ...[
            sourcesListNotifier,
            providerSourcesCache,
            probeNotifier,
          ],
        ];
        disposeLoadingOverlayNotifiers(pending);
      }
    }
  }
  Future<void> _loadWebstreamingProviderOrder() async {
    final order = await _s._settings.getStreamProviderOrder();
    if (!mounted) return;
    setState(() => _s._webstreamingProviderOrder = order);
  }

  Map<String, dynamic> get _orderedWebstreamingProviders {
    final order = _s._webstreamingProviderOrder;
    final raw = <String, dynamic>{
      for (final k in order)
        if (_s._webstreamingProviders.containsKey(k)) k: _s._webstreamingProviders[k],
      for (final k in _s._webstreamingProviders.keys)
        if (!order.contains(k)) k: _s._webstreamingProviders[k],
    };
    return SourceEngine.orderProvidersMap(
      domain: SourceDomain.fromMediaType(_s._movie.mediaType),
      providers: raw,
      settingsOrder: order,
    );
  }

  String _webstreamingProviderLabel(String key) {
    final provider = _s._webstreamingProviders[key];
    final fallbackName = provider is Map ? provider['name']?.toString() : null;
    return StreamProviderDisplay.playerLabel(
      key,
      fallbackName: fallbackName,
    );
  }

  Future<void> _playWebstreamingStream(
    StreamSource source, {
    Duration? startPosition,
    BuildContext? loadingDialogContext,
    ValueNotifier<bool>? fadeOutNotifier,
  }) async {
    final isTv = _s._movie.mediaType == 'tv';
    final title = isTv
        ? '${_s._movie.title} - S${_s._selectedSeason} E${_s._selectedEpisode}'
        : _s._movie.title;
    final providerId = _s._webstreamingActiveProviderId ?? 'videasy';
    final pool = _s._webstreamingStreams.isNotEmpty
        ? _s._webstreamingStreams
        : <StreamSource>[source];
    // Chosen stream first so player index 0 / pin sync cannot open a sibling.
    final resolvedSources = <StreamSource>[
      source,
      for (final s in pool)
        if (s.url != source.url) s,
    ];
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {providerId: resolvedSources},
    );
    // Persist only after playbackConfirmed (player lifecycle) so unreachable
    // extracts from any provider are not reused on the next green Play.
    if (mounted && _s._sourcesPanelOpen) _s._closeSourcesPanel();
    try {
      Future<void> openPlayer() {
        return AppRouter.openPlayer(
          context,
          streamUrl: source.url,
          title: title,
          headers: source.headers,
          movie: _s._movie,
          providers: _orderedWebstreamingProviders,
          activeProvider: providerId,
          selectedSeason: isTv ? _s._selectedSeason : null,
          selectedEpisode: isTv ? _s._selectedEpisode : null,
          startPosition: startPosition ?? widget.startPosition,
          sources: resolvedSources,
          providerSourcesCache: providerSourcesCache,
          pinSource: true,
          onSourcePinned: (sourceUrl, sourceTitle) =>
              _rememberWebstreamingSelection(
                sourceUrl,
                sourceTitle,
                providerSourcesCache,
              ),
          fadeTransition: true,
        );
      }

      final ctx = loadingDialogContext;
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
    } finally {
      providerSourcesCache.dispose();
    }
  }
  bool get _isWebstreamingSource =>
      _s._selectedSourceId == 'webstream_picker' ||
      _s._selectedSourceId.startsWith('stream:');
}
