part of 'details_screen.dart';

mixin _DetailsScreenWebstreaming on State<DetailsScreen> {
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
    if (ok || !mounted) return;
    if (await _tryResumeWebStreamFromWatchHistory(startPosition)) return;
    if (mounted) await _startWebstreamingOnlyPlayback();
  }
  void _onPlayStreamingPressed() {
    unawaited(_playWebstreamingFromDetails());
  }

  Future<void> _playWebstreamingFromDetails() async {
    await _s._checkHistory();
    await _hydrateWebstreamingFromCache();
    if (!mounted) return;
    await _startWebstreamingOnlyPlayback();
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
    final cached = await WebstreamingStreamCache.read(_webstreamingCacheKey());
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
    final selected = providerSources.firstWhere(
      (s) => s.url == sourceUrl,
      orElse: () => StreamSource(
        url: sourceUrl,
        title: sourceTitle,
        type: sourceUrl.contains('.m3u8') ? 'hls' : 'video',
      ),
    );
    final reordered = [
      selected,
      for (final s in providerSources)
        if (s.url != sourceUrl) s,
    ];
    if (!mounted) return;
    setState(() {
      _s._webstreamingActiveProviderId = providerId;
      _s._webstreamingStreams = reordered;
    });
    await _persistWebstreamingCache(providerId: providerId, sources: reordered);
  }

  Future<void> _startWebstreamingOnlyPlayback() async {
    final startPosition = _s._startPositionForAutoPlay(fromRoute: false);
    if (_s._webstreamingStreams.isNotEmpty) {
      await _playWebstreamingStream(
        _s._webstreamingStreams.first,
        startPosition: startPosition,
      );
      return;
    }

    final cached = await WebstreamingStreamCache.read(_webstreamingCacheKey());
    if (cached != null && cached.sources.isNotEmpty) {
      if (!mounted) return;
      setState(() => _applyWebstreamingCacheHit(cached));
      debugPrint(
        '[DetailsScreen] webstreaming cache hit '
        '${cached.providerId} (${cached.sources.length})',
      );
      await _playWebstreamingStream(
        cached.sources.first,
        startPosition: startPosition,
      );
      return;
    }

    if (await _tryResumeWebStreamFromWatchHistory(startPosition)) return;

    if (_s._isWebstreamingOnlyExtracting) return;
    await _runWebstreamingOnlyExtraction(startPosition: startPosition);
  }

  /// Last-resume layer: reopen the saved URL + provider from watch history
  /// without re-racing extractors (survives cache drops after built-in fail).
  Future<bool> _tryResumeWebStreamFromWatchHistory(Duration? startPosition) async {
    final progress = _s._lastProgress;
    if (progress == null || progress['method'] != 'stream') return false;
    final savedUrl = progress['streamUrl'] as String?;
    final rawSourceId = progress['sourceId'] as String? ?? '';
    if (savedUrl == null ||
        savedUrl.trim().isEmpty ||
        isTorrentStreamUrl(savedUrl)) {
      return false;
    }
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
    await _playWebstreamingStream(source, startPosition: startPosition);
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
    if (ok || !mounted) return;
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

  Future<void> _runWebstreamingOnlyExtraction({Duration? startPosition}) async {
    if (mounted) {
      setState(() => _s._isWebstreamingOnlyExtracting = true);
    } else {
      _s._isWebstreamingOnlyExtracting = true;
    }
    _s._webstreamingOnlyExtractionCancelled = false;
    final probeNotifier = ValueNotifier<List<StreamProviderProbe>>([]);
    final sourcesListNotifier = ValueNotifier<List<StreamSource>>(const []);
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );
    final fadeOutNotifier = ValueNotifier(false);
    var liveNotifiersDisposed = false;
    BuildContext? loadingDialogContext;
    var switchingManualProvider = false;
    String? pendingManualProviderId;
    var preferredProvider = SourceEngine.auto;

    void dismissLoading() {
      final ctx = loadingDialogContext;
      if (ctx != null && ctx.mounted) dismissLoadingOverlayRoute(ctx);
      loadingDialogContext = null;
    }

    void requestManualProviderCheck(String providerId) {
      if (_s._webstreamingOnlyExtractionCancelled) return;
      if (TvStreamFallback.isSkippedOnTv(providerId, _orderedWebstreamingProviders)) {
        return;
      }
      pendingManualProviderId = providerId;
      switchingManualProvider = true;
      PlaybackEngine.cancelAllPending();
    }

    showLoadingOverlayDialog(
      context,
      builder: (dialogContext) {
        loadingDialogContext = dialogContext;
        return LoadingOverlay(
          movie: _s._movie,
          providerProbesNotifier: probeNotifier,
          fadeOutNotifier: fadeOutNotifier,
          onCancel: () {
            _s._webstreamingOnlyExtractionCancelled = true;
            switchingManualProvider = false;
            pendingManualProviderId = null;
            PlaybackEngine.cancelAllPending();
            dismissLoading();
          },
          onManualCheckProvider: requestManualProviderCheck,
        );
      },
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      dismissLoading();
      _s._isWebstreamingOnlyExtracting = false;
      fadeOutNotifier.dispose();
      liveNotifiersDisposed = true;
      probeNotifier.dispose();
      sourcesListNotifier.dispose();
      providerSourcesCache.dispose();
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
        if (hits.isEmpty ||
            _s._webstreamingOnlyExtractionCancelled ||
            switchingManualProvider) {
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
        unawaited(
          ProviderScoreProbeSync.syncSourcesCache(
            scope: scope,
            sourcesByProvider: providerSourcesCache.value,
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

      PlaybackResolveHit? hit;
      while (mounted && !_s._webstreamingOnlyExtractionCancelled) {
        switchingManualProvider = false;
        final preferred = preferredProvider;
        prepareProbesForPreferred(preferred);

        hit = await PlaybackService.resolveWebstreaming(
          providers: providers,
          movie: _s._movie,
          season: _s._selectedSeason,
          episode: _s._selectedEpisode,
          preferredProvider: preferred,
          settingsOrder: _s._webstreamingProviderOrder,
          isCancelled: () =>
              _s._webstreamingOnlyExtractionCancelled || switchingManualProvider,
          onHitsUpdated: syncResolvedHits,
          onProgress: applyProbeProgress,
        );

        if (_s._webstreamingOnlyExtractionCancelled) {
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

      if (!mounted || _s._webstreamingOnlyExtractionCancelled) {
        // cancelled
      } else if (hit != null) {
        found = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final sources = hit.streamSources;
        final key = hit.providerId;
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
          // Do not disk-cache until mpv confirms playback — dead resolves must
          // not poison the next Play for any provider.

          final isTv = _s._movie.mediaType == 'tv';
          final title = isTv
              ? '${_s._movie.title} - S${_s._selectedSeason} E${_s._selectedEpisode}'
              : _s._movie.title;
          final ctx = loadingDialogContext;
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
                pinSource: manualPick,
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
            _s._webstreamingOnlyExtractionCancelled = true;
            PlaybackEngine.cancelAllPending();
            liveNotifiersDisposed = true;
            sourcesListNotifier.dispose();
            providerSourcesCache.dispose();
            probeNotifier.dispose();
          } else {
            await _playWebstreamingStream(
              sources.first,
              startPosition: startPosition,
            );
          }
        }
      }

      if (!found && mounted && !_s._webstreamingOnlyExtractionCancelled) {
        dismissLoading();
        ForjaToast.error('Failed to find a working stream.');
      }
    } finally {
      if (mounted) {
        setState(() => _s._isWebstreamingOnlyExtracting = false);
      } else {
        _s._isWebstreamingOnlyExtracting = false;
      }
      fadeOutNotifier.dispose();
      if (!liveNotifiersDisposed) {
        sourcesListNotifier.dispose();
        providerSourcesCache.dispose();
        probeNotifier.dispose();
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
  }) async {
    final isTv = _s._movie.mediaType == 'tv';
    final title = isTv
        ? '${_s._movie.title} - S${_s._selectedSeason} E${_s._selectedEpisode}'
        : _s._movie.title;
    final providerId = _s._webstreamingActiveProviderId ?? 'videasy';
    final resolvedSources = _s._webstreamingStreams.isNotEmpty
        ? _s._webstreamingStreams
        : <StreamSource>[source];
    final providerSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {providerId: resolvedSources},
    );
    // Persist only after playbackConfirmed (player lifecycle) so unreachable
    // extracts from any provider are not reused on the next green Play.
    if (mounted && _s._sourcesPanelOpen) setState(() => _s._sourcesPanelOpen = false);
    try {
      await AppRouter.openPlayer(
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
    } finally {
      providerSourcesCache.dispose();
    }
  }
  bool get _isWebstreamingSource =>
      _s._selectedSourceId == 'webstream_picker' ||
      _s._selectedSourceId.startsWith('stream:');
}
