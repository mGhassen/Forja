part of 'desktop_player_screen.dart';

mixin _DesktopPlayerSources on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  void _notifySourceMenuChanged() {
    if (_s._disposed) return;
    _s._sourceMenuRevision.value++;
  }

  ProviderScoreScope? get _scoreScope => PlayerStreamMenu.scoreScope(
        movie: widget.movie,
        providers: widget.providers,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        activeProvider: widget.activeProvider,
      );

  List<String> _streamUrlsForProvider(String providerId) {
    if (providerId.isEmpty) return const [];
    final cached = _s._liveProviderSourcesCache.value[providerId];
    if (cached != null && cached.isNotEmpty) {
      return [for (final s in cached) s.url];
    }
    if (providerId == _s._currentProvider) {
      final sources = _s._currentSources;
      if (sources != null && sources.isNotEmpty) {
        return [for (final s in sources) s.url];
      }
    }
    return const [];
  }

  Future<void> _recordStreamCheckSuccess(String providerId) async {
    final scope = _scoreScope;
    if (scope == null || providerId.isEmpty) return;
    // Server + stream are linked — commit +2+2 together.
    await ProviderScoreMemory.recordLinkedStreamsUp(scope, providerId);
    ProviderScoreProbeSync.markScoredServerUp(scope, providerId);
    _notifySourceMenuChanged();
  }

  Future<void> _recordStreamCheckFailure(String providerId) async {
    final scope = _scoreScope;
    if (scope == null || providerId.isEmpty) return;
    // Only when every known stream is dead — linked +2−2, not server alone.
    final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
      scope: scope,
      providerId: providerId,
      streamUrls: _streamUrlsForProvider(providerId),
      isStreamFailed: (url) =>
          _s._urlCheckStatuses[url] == PlayerSourceStatus.failed,
    );
    if (applied) {
      ProviderScoreProbeSync.markScoredLinkedDown(scope, providerId);
    }
    _notifySourceMenuChanged();
  }

  Future<void> _recordStreamPlaySuccess(String providerId) async {
    final scope = _scoreScope;
    if (scope == null || providerId.isEmpty) return;
    await ProviderScoreMemory.recordLinkedStreamsUp(scope, providerId);
    ProviderScoreProbeSync.markScoredServerUp(scope, providerId);
    _notifySourceMenuChanged();
  }

  Future<void> _recordStreamPlayFailure(String providerId) async {
    final scope = _scoreScope;
    if (scope == null || providerId.isEmpty) return;
    // 111477 play uses a local seek proxy; open failures are not the same as
    // the catalog soft-check used by the stream menu (those stay aligned).
    if (providerId == 'service111477') {
      _notifySourceMenuChanged();
      return;
    }
    final applied = await ProviderScoreMemory.recordAllStreamsDownIfNeeded(
      scope: scope,
      providerId: providerId,
      streamUrls: _streamUrlsForProvider(providerId),
      isStreamFailed: (url) =>
          _s._urlCheckStatuses[url] == PlayerSourceStatus.failed,
    );
    if (applied) {
      ProviderScoreProbeSync.markScoredLinkedDown(scope, providerId);
    }
    _notifySourceMenuChanged();
  }

  void _setUrlCheckStatus(String url, PlayerSourceStatus status) {
    _s._urlCheckStatuses[url] = status;
    _notifySourceMenuChanged();
  }

  void _syncUrlCheckFromIndex(int index, PlayerSourceStatus status) {
    final sources = _s._currentSources;
    if (sources == null || index < 0 || index >= sources.length) return;
    _setUrlCheckStatus(sources[index].url, status);
  }

  void _markSourceChecking(int index) {
    _s._checkingSourceIndices
      ..clear()
      ..add(index);
    _syncUrlCheckFromIndex(index, PlayerSourceStatus.checking);
    _s._hideTimer?.cancel();
    if (mounted && !_s._showControls) {
      setState(() => _s._showControls = true);
    }
    _notifySourceMenuChanged();
  }

  void _markSourceFailed(int index) {
    _s._failedSourceIndices.add(index);
    _s._checkingSourceIndices.remove(index);
    _syncUrlCheckFromIndex(index, PlayerSourceStatus.failed);
    _s._hideTimer?.cancel();
    if (mounted && !_s._showControls) {
      setState(() => _s._showControls = true);
    }
    _notifySourceMenuChanged();
  }

  void _markSourceActive(int index) {
    _s._failedSourceIndices.remove(index);
    _s._checkingSourceIndices.remove(index);
    _syncUrlCheckFromIndex(index, PlayerSourceStatus.active);
    _notifySourceMenuChanged();
  }

  bool _isCurrentSourceIndex(int index) {
    final sources = _s._currentSources;
    if (sources == null || index < 0 || index >= sources.length) return false;
    final source = sources[index];
    return _s._currentProvider == 'service111477'
        ? source.url == _s._current111477FileUrl
        : source.url == _s._currentUrl ||
            source.url == _s._currentPlayingCatalogUrl;
  }

  Future<void> _reloadStreamMenu() async {
    if (_s._isReloadingStreams.value) return;
    _s._isReloadingStreams.value = true;
    try {
      if (widget.onReloadStreams != null) {
        final fresh = await widget.onReloadStreams!();
        if (!mounted) return;
        if (fresh != null && fresh.isNotEmpty) {
          setState(() {
            _s._currentSources = fresh;
            _s._failedSourceIndices.clear();
            _s._checkingSourceIndices.clear();
            _s._urlCheckStatuses.clear();
          });
          _notifySourceMenuChanged();
        }
        return;
      }
      // Webstreaming / drama: no host callback — force-refresh the active
      // server so header reload is not a no-op after cache play.
      final pid = _s._currentProvider ?? widget.activeProvider;
      if (pid == null || pid.isEmpty) return;
      final fresh = await _s._loadProvider(pid, forceRefresh: true);
      if (!mounted) return;
      if (fresh != null && fresh.isNotEmpty) {
        setState(() {
          _s._currentSources = fresh;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._urlCheckStatuses.clear();
        });
        _notifySourceMenuChanged();
      }
    } finally {
      if (mounted) _s._isReloadingStreams.value = false;
    }
  }

  void _onLiveSourcesUpdated() {
    unawaited(_rankLiveSources());
  }

  void _onProbeScoringChanged() {
    final notifier = widget.providerProbesNotifier;
    if (notifier == null) return;
    unawaited(
      ProviderScoreProbeSync.syncProbeList(
        scope: _scoreScope,
        probes: notifier.value,
        sourcesByProvider: _s._liveProviderSourcesCache.value,
      ).then((_) {
        if (mounted) _notifySourceMenuChanged();
      }),
    );
  }

  Future<void> _rankLiveSources() async {
    if (_s._disposed || !mounted) return;
    final live = widget.sourcesListNotifier?.value;
    if (live == null || live.isEmpty) return;
    final merged = await dedupeStreamSourcesAsync(
      live,
      providerId: _s._currentProvider ?? '',
    );
    if (_s._disposed || !mounted) return;
    final prevLen = _s._currentSources?.length ?? 0;
    if (merged.length <= prevLen &&
        (_s._currentSources == null ||
            (merged.length == prevLen &&
                merged.every(
                  (s) => _s._currentSources!.any((c) => c.url == s.url),
                )))) {
      return;
    }
    setState(() => _s._currentSources = merged);
    _s._syncCurrentSourceIndexFromPlayUrl();
    _notifySourceMenuChanged();
    if (!_s._playbackConfirmed &&
        !_s._isInitPlaybackRunning &&
        merged.length > prevLen &&
        _s._currentFallbackSourceIndex < merged.length) {
      unawaited(_s._initPlayback(sourceStartIndex: _s._currentFallbackSourceIndex));
    }
  }

  List<PlayerSourceStatus> _buildSourceStatuses() {
    final sources = _s._effectiveCurrentSources ?? const [];
    return List.generate(sources.length, (i) {
      if (_s._checkingSourceIndices.contains(i)) {
        return PlayerSourceStatus.checking;
      }
      final source = sources[i];
      final isCurrent = _s._currentProvider == 'service111477'
          ? source.url == _s._current111477FileUrl
          : source.url == _s._currentUrl ||
              source.url == _s._currentPlayingCatalogUrl;
      if (isCurrent && !_s._playbackConfirmed && _s._isInitPlaybackRunning) {
        return PlayerSourceStatus.checking;
      }
      if (isCurrent && _s._playbackConfirmed) return PlayerSourceStatus.active;
      if (_s._failedSourceIndices.contains(i)) return PlayerSourceStatus.failed;
      // Not URL-checked yet — gray until probe or play confirms.
      return PlayerSourceStatus.unchecked;
    });
  }

  PlayerStreamMenuState _streamMenuState() {
    return PlayerStreamMenuState(
      currentProviderId: _s._resolveStreamMenuProviderId(),
      sources: _s._effectiveCurrentSources,
      currentUrl: _s._currentUrl,
      currentPlayingCatalogUrl: _s._currentPlayingCatalogUrl,
      current111477FileUrl: _s._current111477FileUrl,
      is111477: _s._currentProvider == 'service111477',
      sourceStatuses: _buildSourceStatuses(),
      playbackConfirmed: _s._playbackConfirmed,
      mediaPlaying: _s._isPlayingNotifier.value,
    );
  }

  ValueNotifier<Map<String, List<StreamSource>>> get _liveProviderSourcesCache =>
      widget.providerSourcesCache ?? _s._ownedProviderSourcesCache;

  void _cancelPendingStreamWork() {
    _s._fallbackGen++;
    for (final id in _s._providerLoadGens.keys.toList()) {
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    PlayerStreamMenu.dismiss();
    PlayerPopupPanel.dismiss();
    PlayerEpisodePanel.dismiss();
    PlayerHubEpisodePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    // Do not cancel Engine jobs — leaving the player must not abort a
    // torrentStream / magnet resolve started from details underneath.
    DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
  }

  void _markProviderLoadFailed(String providerId) {
    if (_s._disposed) return;
    if (_s._providerLoadFailures.value.contains(providerId)) return;
    _s._providerLoadFailures.value = {
      ..._s._providerLoadFailures.value,
      providerId,
    };
    _syncProbeStatus(providerId, StreamProviderProbeStatus.failed);
    unawaited(ProviderScoreMemory.recordServerFailure(_scoreScope, providerId));
    ProviderScoreProbeSync.markScoredServerFail(_scoreScope, providerId);
    _notifySourceMenuChanged();
  }

  void _markProviderLoadSucceeded(String providerId) {
    if (_s._disposed) return;
    if (_s._providerLoadFailures.value.contains(providerId)) {
      final next = {..._s._providerLoadFailures.value}..remove(providerId);
      _s._providerLoadFailures.value = next;
    }
    _notifySourceMenuChanged();
  }

  /// Extract-only — do not score. Server ±2 commits with stream outcome.
  void _scoreServerUp(String providerId) {
    if (providerId.isEmpty) return;
  }

  void _cacheProviderSources(String providerId, List<StreamSource> sources) {
    if (_s._disposed || providerId.isEmpty || sources.isEmpty) return;
    _s._liveProviderSourcesCache.value = {
      ..._s._liveProviderSourcesCache.value,
      providerId: dedupeStreamSources(sources),
    };
  }

  void _syncProbeStatus(String providerId, StreamProviderProbeStatus status) {
    if (_s._disposed) return;
    final notifier = widget.providerProbesNotifier;
    if (notifier == null || notifier.value.isEmpty) return;
    final existing = notifier.value;
    final updated = existing
        .map((p) => p.id == providerId ? p.copyWith(status: status) : p)
        .toList();
    if (updated != existing) notifier.value = updated;
  }

  void _finalizeProbeStatusesAfterPlayback() {
    if (_s._disposed) return;
    final notifier = widget.providerProbesNotifier;
    if (notifier == null || notifier.value.isEmpty) return;
    final current = _s._currentProvider;
    final failed = _s._providerLoadFailures.value;
    notifier.value = [
      for (final p in notifier.value)
        if (_s._playbackConfirmed && current != null && p.id == current)
          p.copyWith(status: StreamProviderProbeStatus.success)
        else if (failed.contains(p.id))
          p.copyWith(status: StreamProviderProbeStatus.failed)
        else if (p.status == StreamProviderProbeStatus.trying)
          p.copyWith(status: StreamProviderProbeStatus.failed)
        else
          p,
    ];
  }

  void _syncPanelAfterPlaybackConfirmed() {
    // Playing — stop leftover Auto / host extracts; do not keep checking
    // other providers in the background.
    DomainStreamProviderResolver.cancelAllPending(cancelEngineJobs: false);
    _s._refreshPanelPlayingStream();
    final pid = _s._currentProvider;
    if (pid == null) return;
    _markProviderLoadSucceeded(pid);
    _s._statusController.remove('provider-$pid');
    _syncProbeStatus(pid, StreamProviderProbeStatus.success);
    _finalizeProbeStatusesAfterPlayback();
    // Score only via probe sync: +2 for finished success+streams, not the
    // whole live cache (abandoned mid-check hosts must not get +2).
    _onProbeScoringChanged();
    _notifySourceMenuChanged();
  }

  Listenable? _streamMenuRefreshListenable() {
    final listenables = <Listenable>[
      _s._statusController,
      _s._sourceMenuRevision,
      _s._isReloadingStreams,
      _s._isPlayingNotifier,
      _s._providerLoadFailures,
      ProviderScoreMemory.revision,
    ];
    final probes = widget.providerProbesNotifier;
    if (probes != null) listenables.add(probes);
    listenables.add(_s._liveProviderSourcesCache);
    return Listenable.merge(listenables);
  }

  String _streamPickerLabel() {
    final key = _s._currentProvider ?? widget.activeProvider;
    if (key != null &&
        widget.providers != null &&
        widget.providers!.containsKey(key)) {
      return PlayerProviderMenu.snackbarLabel(key, widget.providers![key]);
    }
    final sources = _s._currentSources;
    if (sources != null && sources.isNotEmpty) {
      final current = sources.firstWhere(
        (s) => _s._currentProvider == 'service111477'
            ? s.url == _s._current111477FileUrl
            : s.url == _s._currentUrl,
        orElse: () => sources.first,
      );
      return current.title;
    }
    return 'Stream';
  }

  bool get _hasStreamPicker {
    // Catalog Sources (magnet / Stremio Direct / Nuvio) already covers switching —
    // don't show the layers server picker alongside it.
    if (_usesCatalogSourcesPanel) return false;
    final hasProviders =
        widget.providers != null && widget.providers!.isNotEmpty;
    final hasSources = _s._effectiveCurrentSources != null &&
        _s._effectiveCurrentSources!.isNotEmpty;
    return hasProviders || hasSources;
  }

  /// Magnet or Stremio/Nuvio catalog play — link button opens Sources panel.
  bool get _usesCatalogSourcesPanel {
    if (widget.movie == null) return false;
    final magnet = _s._activeMagnet ?? widget.magnetLink;
    if (magnet != null && magnet.isNotEmpty) return true;
    return isCatalogSourcesMode(_s._currentProvider ?? widget.activeProvider);
  }

  void _showStreamMenu([BuildContext? anchorContext]) {
    if (!_hasStreamPicker) return;
    _s._refreshPanelPlayingStream();
    PlayerStreamMenu.show(
      context,
      providers: widget.providers,
      providerSourcesCache: _s._liveProviderSourcesCache,
      providerLoadFailures: _s._providerLoadFailures,
      providerProbesNotifier: widget.providerProbesNotifier,
      statusController: _s._statusController,
      readState: _streamMenuState,
      onLoadProvider: _s._loadProvider,
      onSelectProvider: _s._switchProvider,
      onSelectSource: _switchToStreamSource,
      onCheckSource: _checkStreamSource,
      onTogglePlayPause: () {
        _s._player.playOrPause();
        _s._onMouseMove();
      },
      anchorContext: anchorContext,
      refreshListenable: _streamMenuRefreshListenable(),
      onReload: _reloadStreamMenu,
      isReloading: _s._isReloadingStreams,
      movie: widget.movie,
      selectedSeason: widget.selectedSeason,
      selectedEpisode: widget.selectedEpisode,
      hubEpisodeNumber: widget.hubEpisodeNumber,
      activeProvider: widget.activeProvider,
      readUrlCheckStatuses: () => _s._urlCheckStatuses,
    );
    _s._onMouseMove();
  }

  Future<void> _selectAutoProvider() async {
    if (!_s._providerPinned) return;
    setState(() {
      _s._providerPinned = false;
      _s._sourcePinned = false;
      _s._currentFallbackSourceIndex = 0;
    });
    final movie = widget.movie;
    final providers = widget.providers;
    if (movie != null && providers != null && providers.isNotEmpty) {
      final gen = ++_s._fallbackGen;
      DomainStreamProviderResolver.cancelAllPending();
      final hit = await PlayerSourceResolve.resolveAutoForMovie(
        movie: movie,
        providers: providers,
        season: widget.selectedSeason ?? 1,
        episode: widget.hubEpisodeNumber?.toInt() ??
            widget.selectedEpisode ??
            1,
        isCancelled: () => _s._fallbackAborted(gen),
        onHitsUpdated: (hits) {
          if (!mounted || _s._fallbackAborted(gen)) return;
          _s._liveProviderSourcesCache.value = {
            ..._s._liveProviderSourcesCache.value,
            ...PlaybackEngine.hitsToProviderCache(hits),
          };
        },
      );
      if (_s._fallbackAborted(gen)) return;
      if (hit != null) {
        _scoreServerUp(hit.providerId);
        setState(() {
          _s._currentProvider = hit.providerId;
          _s._currentSources = hit.streamSources;
          _s._currentUrl = hit.streamUrl;
          _s._currentFallbackSourceIndex = 0;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._hasError = false;
          _s._errorMessage = '';
          if (hit.providerId == 'service111477' &&
              hit.streamSources.isNotEmpty) {
            _s._current111477FileUrl = hit.streamSources.first.url;
          }
        });
        final played = await _s._trySourcesFromIndex(
          0,
          chainGen: gen,
          seekAfterOpen: _s._positionNotifier.value,
        );
        if (played) return;
      }
    }
    await _s._initPlayback();
  }

  Future<void> _selectAutoSource() async {
    if (!_s._sourcePinned) return;
    setState(() {
      _s._sourcePinned = false;
      _s._currentFallbackSourceIndex = 0;
      _s._failedSourceIndices.clear();
      _s._checkingSourceIndices.clear();
    });
    _notifySourceMenuChanged();
    await _s._initPlayback();
  }

  Future<
      ({
        String openUrl,
        Map<String, String>? headers,
        StreamSource resolved,
      })?> _resolveValidatedStream(
    StreamSource source, {
    String? providerId,
  }) async {
    final pid = providerId ?? _s._currentProvider;
    var openUrl = source.url;
    Map<String, String>? headers = source.headers ?? widget.headers;
    var resolved = source;

    if (pid == 'service111477') {
      final ok = await validateStreamSourceForCheck(
        providerId: pid,
        source: source,
        headers: headers,
      );
      if (!ok) return null;
      return (openUrl: source.url, headers: headers, resolved: source);
    }

    if (pid == 'arabic' && source.type == 'arabic_embed') {
      final result = await ArabicService.extractStreamUrl(source.url);
      if (result == null) return null;
      openUrl = result.url;
      headers = result.headers;
      resolved = StreamSource(
        url: result.url,
        title: source.title,
        type: result.url.contains('.m3u8')
            ? 'hls'
            : result.url.contains('.mpd')
                ? 'dash'
                : 'mp4',
      );
    }

    if (animeHlsNeedsPngStripFor(openUrl, sourceKey: pid)) {
      final stripped = await applyAnimePngStripIfNeeded(
        StreamSource(
          url: openUrl,
          title: source.title,
          type: source.type,
          headers: headers,
        ),
        sourceKey: pid,
      );
      openUrl = stripped.url;
      headers = stripped.headers;
      resolved = stripped;
    }

    final ok = await probeStreamSourceUrl(
      openUrl,
      headers,
      sourceKey: pid,
    );
    if (!ok) return null;
    return (openUrl: openUrl, headers: headers, resolved: resolved);
  }

  Future<bool> _checkStreamSource(
    StreamSource source,
    int index, [
    String? providerId,
  ]) async {
    final pid = providerId ?? _s._currentProvider ?? '';
    final affectsCurrent =
        providerId == null || providerId == _s._currentProvider;
    _setUrlCheckStatus(source.url, PlayerSourceStatus.checking);
    if (affectsCurrent) {
      if (_isCurrentSourceIndex(index) && _s._playbackConfirmed) {
        _markSourceActive(index);
        unawaited(_recordStreamCheckSuccess(pid));
        return true;
      }
      _markSourceChecking(index);
    }

    try {
      final validated = await _resolveValidatedStream(
        source,
        providerId: providerId,
      );
      if (!mounted) return false;

      if (validated != null) {
        _setUrlCheckStatus(source.url, PlayerSourceStatus.ready);
        if (affectsCurrent) {
          _s._failedSourceIndices.remove(index);
          _s._checkingSourceIndices.remove(index);
          _notifySourceMenuChanged();
        }
        unawaited(_recordStreamCheckSuccess(pid));
        return true;
      }

      _setUrlCheckStatus(source.url, PlayerSourceStatus.failed);
      if (affectsCurrent) {
        _markSourceFailed(index);
      } else {
        _notifySourceMenuChanged();
      }
      unawaited(_recordStreamCheckFailure(pid));
      return false;
    } catch (_) {
      if (!mounted) return false;
      _setUrlCheckStatus(source.url, PlayerSourceStatus.failed);
      if (affectsCurrent) {
        _markSourceFailed(index);
      } else {
        _notifySourceMenuChanged();
      }
      unawaited(_recordStreamCheckFailure(pid));
      return false;
    }
  }

  Future<void> _switchToStreamSource(StreamSource source, int index) async {
    if (_s._currentSources == null || _s._currentSources!.isEmpty) {
      final effective = _s._effectiveCurrentSources;
      if (effective != null && effective.isNotEmpty) {
        setState(() => _s._currentSources = List<StreamSource>.from(effective));
      }
    }

    final isCurrent = _s._currentProvider == 'service111477'
        ? source.url == _s._current111477FileUrl
        : source.url == _s._currentUrl ||
            source.url == _s._currentPlayingCatalogUrl;
    if (isCurrent && _s._sourcePinned && _s._playbackConfirmed) return;

    if (isCurrent && !_s._sourcePinned && _s._playbackConfirmed) {
      await SettingsService().setPlayerAutoSource(false);
      setState(() => _s._sourcePinned = true);
      unawaited(widget.onSourcePinned?.call(source.url, source.title));
      return;
    }

    _s._sourcePinned = true;
    unawaited(SettingsService().setPlayerAutoSource(false));
    final switchGen = ++_s._fallbackGen;
    _markSourceChecking(index);

    final currentPos = _s._positionNotifier.value;
    final statusId = 'source-switch-$index';
    _s._statusController.upsert(
      statusId,
      source.title,
      kind: StatusRouletteKind.loading,
    );

    try {
      final validated = await _resolveValidatedStream(source);
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (validated == null) {
        _s._statusController.upsert(
          statusId,
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        _markSourceFailed(index);
        unawaited(
          _recordStreamPlayFailure(_s._currentProvider ?? ''),
        );
        return;
      }

      var openUrl = validated.openUrl;
      Map<String, String>? headers = validated.headers;
      var resolved = validated.resolved;

      if (_s._currentProvider == 'service111477') {
        if (site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        openUrl = await site111477_proxy.start111477Proxy(source.url);
        headers = null;
      }

      if (!mounted || _s._fallbackAborted(switchGen)) return;

      DomainStreamProviderResolver.cancelAllPending();
      _s._statusController.clear();
      _s._markPlaybackConfirmed(false);

      // Validated — stop the prior stream before opening the new one.
      _s._autoTracksAppliedForSource = false;
      _s._durationNotifier.value = Duration.zero;
      _s._positionNotifier.value = Duration.zero;
      _s._bufferedNotifier.value = Duration.zero;
      await resetPlayerForOpen(_s._player);
      openUrl = await openPlayerStream(
        _s._player,
        url: openUrl,
        headers: headers,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;

      if (_s._currentProvider == 'service111477') {
        setState(() {
          _s._currentUrl = openUrl;
          _s._current111477FileUrl = source.url;
          // Keep the selected index — resetting to 0 played a different stream.
          _s._currentFallbackSourceIndex = index.clamp(
            0,
            (_s._currentSources?.length ?? 1) - 1,
          );
          _s._hasError = false;
          _s._errorMessage = '';
        });
      } else {
        if (_s._currentSources != null &&
            index >= 0 &&
            index < _s._currentSources!.length) {
          _s._currentSources![index] = resolved;
        }
        setState(() {
          _s._currentUrl = openUrl;
          _s._currentPlayingCatalogUrl = source.url;
          _s._currentFallbackSourceIndex = index.clamp(
            0,
            (_s._currentSources?.length ?? 1) - 1,
          );
          _s._hasError = false;
          _s._errorMessage = '';
        });
      }

      _s._detectHlsQualities(openUrl, headers);
      if (currentPos.inSeconds > 0) await _s._player.seek(currentPos);
      syncPlayerProgressNotifiers(
        _s._player,
        duration: _s._durationNotifier,
        position: _s._positionNotifier,
        buffered: _s._bufferedNotifier,
      );
      _s._markPlaybackConfirmed(true);
      _s._statusController.complete();
      _markSourceActive(index);
      _syncPanelAfterPlaybackConfirmed();
      unawaited(_recordStreamPlaySuccess(_s._currentProvider ?? ''));
      unawaited(widget.onSourcePinned?.call(source.url, source.title));
    } catch (_) {
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      _s._statusController.upsert(
        statusId,
        source.title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      _markSourceFailed(index);
      unawaited(
        _recordStreamPlayFailure(_s._currentProvider ?? ''),
      );
    }
  }

  /// Preview must never seek — seeking while paused was moving the real
  /// playhead/thumb to the hover X ("magnetized" progress).
  Future<Uint8List?> _captureSeekPreview(Duration _) async {
    try {
      return await _s._player.screenshot(format: 'image/jpeg');
    } catch (_) {
      return null;
    }
  }
}
