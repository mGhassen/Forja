part of 'mobile_player_screen.dart';

mixin _MobilePlayerSources on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

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
    final cached = _liveProviderSourcesCache.value[providerId];
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
    await ProviderScoreMemory.recordLinkedStreamsUp(scope, providerId);
    ProviderScoreProbeSync.markScoredServerUp(scope, providerId);
    _notifySourceMenuChanged();
  }

  Future<void> _recordStreamCheckFailure(String providerId) async {
    final scope = _scoreScope;
    if (scope == null || providerId.isEmpty) return;
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
        sourcesByProvider: _liveProviderSourcesCache.value,
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
    // Playing session: never clobber panel rows with a notifier list that
    // lacks the active catalog identity (PNG-strip play URL ≠ catalog URL).
    if (_s._playbackConfirmed &&
        !merged.any(
          (s) => streamSourceMatchesPlaying(
            s,
            playUrl: _s._currentUrl,
            catalogUrl: _s._currentPlayingCatalogUrl,
          ),
        )) {
      return;
    }
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
      unawaited(
        _s._initPlayback(sourceStartIndex: _s._currentFallbackSourceIndex),
      );
    }
  }

  List<PlayerSourceStatus> _buildSourceStatuses() {
    final sources = _s._effectiveCurrentSources ?? const [];
    return List.generate(sources.length, (i) {
      final source = sources[i];
      final isCurrent = _s._currentProvider == 'service111477'
          ? source.url == _s._current111477FileUrl
          : streamSourceMatchesPlaying(
                  source,
                  playUrl: _s._currentUrl,
                  catalogUrl: _s._currentPlayingCatalogUrl,
                ) ||
                (_s._playbackConfirmed && sources.length == 1);
      if (isCurrent && _s._playbackConfirmed) return PlayerSourceStatus.active;
      if (_s._checkingSourceIndices.contains(i)) {
        return PlayerSourceStatus.checking;
      }
      if (isCurrent && !_s._playbackConfirmed && _s._isInitPlaybackRunning) {
        return PlayerSourceStatus.checking;
      }
      if (_s._failedSourceIndices.contains(i)) return PlayerSourceStatus.failed;
      // Not URL-checked yet - gray until probe or play confirms.
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

  ValueNotifier<Map<String, List<StreamSource>>>
  get _liveProviderSourcesCache =>
      widget.providerSourcesCache ?? _s._ownedProviderSourcesCache;

  void _cancelPendingStreamWork() {
    _s._fallbackGen++;
    for (final id in _s._providerLoadGens.keys.toList()) {
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    _s._trackAutoSelectTimer?.cancel();
    _s._trackAutoSelectTimer = null;
    _s._embeddedSubtitleAutoTimer?.cancel();
    _s._embeddedSubtitleAutoTimer = null;
    PlayerSubtitleSettingsDialog.dismissIfShowing();
    PlayerStreamMenu.dismiss();
    PlayerPopupPanel.dismiss();
    PlayerEpisodePanel.dismiss();
    PlayerHubEpisodePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    // Exit / failover must not restore focus onto chrome that is going away.
    playerMenuClearReturnFocus();
    // Do not cancel Engine jobs - leaving the player must not abort a
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

  /// Extract-only - do not score. Server ±2 commits with stream outcome.
  void _scoreServerUp(String providerId) {
    if (providerId.isEmpty) return;
  }

  void _cacheProviderSources(String providerId, List<StreamSource> sources) {
    if (_s._disposed || providerId.isEmpty || sources.isEmpty) return;
    final owned = sourcesOwnedByProvider(providerId, sources);
    if (owned.isEmpty) return;
    final existingMap = _liveProviderSourcesCache.value;
    final withoutForeignUrls = <StreamSource>[
      for (final s in owned)
        if (!_urlOwnedByOtherProvider(
          providerId: providerId,
          url: s.url,
          cache: existingMap,
        ))
          s,
    ];
    if (withoutForeignUrls.isEmpty) return;
    final existing = existingMap[providerId];
    final next = preferFullerProviderSources(
      providerId: providerId,
      live: withoutForeignUrls,
      cached: existing,
    );
    _liveProviderSourcesCache.value = {
      ...existingMap,
      providerId: next,
    };
  }

  bool _urlOwnedByOtherProvider({
    required String providerId,
    required String url,
    required Map<String, List<StreamSource>> cache,
  }) {
    final want = StreamProviderDisplay.canonicalId(providerId);
    final u = url.trim();
    if (u.isEmpty) return false;
    for (final e in cache.entries) {
      if (StreamProviderDisplay.canonicalId(e.key) == want) continue;
      if (e.value.any((s) => s.url.trim() == u)) return true;
    }
    return false;
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
    // Playing - stop leftover Auto / host extracts; do not keep checking
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
      _s._isPlayingNotifier,
      _s._providerLoadFailures,
      ProviderScoreMemory.revision,
    ];
    final probes = widget.providerProbesNotifier;
    if (probes != null) listenables.add(probes);
    listenables.add(_liveProviderSourcesCache);
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

  String _catalogSourcesButtonLabel() {
    final key = _s._currentProvider ?? widget.activeProvider;
    if (key != null &&
        widget.providers != null &&
        widget.providers!.containsKey(key)) {
      return PlayerProviderMenu.snackbarLabel(key, widget.providers![key]);
    }
    return catalogSourcesButtonLabel(
      movie: widget.movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      catalogAddonBaseUrl: _s._catalogAddonBaseUrl,
      widgetAddonBaseUrl: widget.stremioAddonBaseUrl,
      currentProvider: _s._currentProvider,
      activeProvider: widget.activeProvider,
      activeMagnet: _s._activeMagnet,
      widgetMagnetLink: widget.magnetLink,
      currentStreamUrl: _s._currentUrl ?? widget.mediaPath,
      currentPlayingCatalogUrl: _s._currentPlayingCatalogUrl,
      catalogSourceKind: _s._catalogSourceKind,
      anilistId: widget.enginePlaySession?.anilistId,
      malId: widget.enginePlaySession?.malId,
      kisskhId: widget.enginePlaySession?.kisskhId,
      animeAudioCategory: widget.enginePlaySession?.animeAudioCategory,
    );
  }

  bool get _hasStreamPicker {
    // Catalog Sources (magnet / Stremio Direct / Nuvio) already covers switching -
    // don't show the layers server picker alongside it.
    if (_usesCatalogSourcesPanel) return false;
    final hasProviders =
        widget.providers != null && widget.providers!.isNotEmpty;
    final hasSources =
        _s._effectiveCurrentSources != null &&
        _s._effectiveCurrentSources!.isNotEmpty;
    return hasProviders || hasSources;
  }

  bool get _hasEpisodePicker =>
      (widget.movie?.mediaType == 'tv' && widget.movie != null) ||
      (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);

  /// Magnet or Stremio/Nuvio catalog play - link button opens Sources panel.
  bool get _usesCatalogSourcesPanel {
    if (widget.movie == null) return false;
    final magnet = _s._activeMagnet ?? widget.magnetLink;
    if (magnet != null && magnet.isNotEmpty) return true;
    return isCatalogSourcesMode(_s._currentProvider ?? widget.activeProvider);
  }

  void _showStreamMenu([BuildContext? anchorContext]) {
    if (!_hasStreamPicker) return;
    _s._refreshPanelPlayingStream();
    final bottom = MediaQuery.paddingOf(context).bottom + 76;
    PlayerStreamMenu.show(
      context,
      providers: widget.providers,
      providerSourcesCache: _liveProviderSourcesCache,
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
        _s._startHideTimer();
      },
      anchorContext: anchorContext,
      margin: EdgeInsets.only(right: 12, bottom: bottom),
      refreshListenable: _streamMenuRefreshListenable(),
      movie: widget.movie,
      selectedSeason: widget.selectedSeason,
      selectedEpisode: widget.selectedEpisode,
      hubEpisodeNumber: widget.hubEpisodeNumber,
      activeProvider: widget.activeProvider,
      readUrlCheckStatuses: () => _s._urlCheckStatuses,
    );
    _s._startHideTimer();
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
        episode:
            widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
        isCancelled: () => _s._fallbackAborted(gen),
        onHitsUpdated: (hits) {
          if (!mounted || _s._fallbackAborted(gen)) return;
          _liveProviderSourcesCache.value = {
            ..._liveProviderSourcesCache.value,
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
    final keepPos = _s._positionNotifier.value;
    await _s._initPlayback(
      seekOverride: keepPos.inSeconds > 0 ? keepPos : null,
    );
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
    final keepPos = _s._positionNotifier.value;
    await _s._initPlayback(
      seekOverride: keepPos.inSeconds > 0 ? keepPos : null,
    );
  }

  Future<
    ({String openUrl, Map<String, String>? headers, StreamSource resolved})?
  >
  _resolveValidatedStream(StreamSource source, {String? providerId}) async {
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

    final ok = await probeStreamSourceUrl(openUrl, headers, sourceKey: pid);
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
    final playingRow =
        _s._playbackConfirmed &&
        affectsCurrent &&
        streamSourceMatchesPlaying(
          source,
          playUrl: _s._currentUrl,
          catalogUrl: _s._currentPlayingCatalogUrl,
        );
    // Playing row: keep active glyph - probe in background without Checking….
    if (playingRow) {
      _setUrlCheckStatus(source.url, PlayerSourceStatus.active);
    } else {
      _setUrlCheckStatus(source.url, PlayerSourceStatus.checking);
      if (affectsCurrent) {
        _markSourceChecking(index);
      }
    }

    try {
      final validated = await _resolveValidatedStream(
        source,
        providerId: providerId,
      );
      if (!mounted) return false;

      if (validated != null) {
        _setUrlCheckStatus(
          source.url,
          playingRow ? PlayerSourceStatus.active : PlayerSourceStatus.ready,
        );
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
    final pid = _s._currentProvider ?? widget.activeProvider ?? '';
    if (pid.isNotEmpty) {
      final fuller = preferFullerProviderSources(
        providerId: pid,
        live: _s._currentSources,
        cached: _s._liveProviderSourcesCache.value[pid],
      );
      if (fuller.isNotEmpty &&
          fuller.length > (_s._currentSources?.length ?? 0)) {
        setState(() => _s._currentSources = List<StreamSource>.from(fuller));
      }
    }
    if (_s._currentSources == null || _s._currentSources!.isEmpty) {
      final effective = _s._effectiveCurrentSources;
      if (effective != null && effective.isNotEmpty) {
        setState(() => _s._currentSources = List<StreamSource>.from(effective));
      }
    }
    var targetIndex = index;
    if (_s._currentSources != null && _s._currentSources!.isNotEmpty) {
      final byUrl = _s._currentSources!.indexWhere((s) => s.url == source.url);
      if (byUrl >= 0) targetIndex = byUrl;
    }

    final isCurrent = _s._currentProvider == 'service111477'
        ? source.url == _s._current111477FileUrl
        : streamSourceMatchesPlaying(
            source,
            playUrl: _s._currentUrl,
            catalogUrl: _s._currentPlayingCatalogUrl,
          );
    // Same catalog URL under a different quality row must still switch.
    final alreadyPlayingRow =
        isCurrent && targetIndex == _s._currentFallbackSourceIndex;
    if (alreadyPlayingRow && _s._sourcePinned && _s._playbackConfirmed) {
      return;
    }

    if (alreadyPlayingRow && !_s._sourcePinned && _s._playbackConfirmed) {
      await SettingsService().setPlayerAutoSource(false);
      setState(() => _s._sourcePinned = true);
      unawaited(widget.onSourcePinned?.call(source.url, source.title));
      _s._startHideTimer();
      return;
    }

    _s._sourcePinned = true;
    unawaited(SettingsService().setPlayerAutoSource(false));
    final switchGen = ++_s._fallbackGen;
    // Fence stop/open so the error listener does not bump _fallbackGen and
    // abort this switch (same as _initPlayback).
    _s._isInitPlaybackRunning = true;
    setState(() {
      _s._hasError = false;
    });
    _markSourceChecking(targetIndex);

    final currentPos = switchResumePosition(
      uiPosition: _s._positionNotifier.value,
      playerPosition: _s._player.state.position,
    );
    final statusId = 'source-switch-$targetIndex';
    final resolvePid = source.providerId ?? source.title;
    ref.read(playerResolveStatusProvider.notifier).setLoading(resolvePid);
    _s._statusController.upsert(
      statusId,
      source.title,
      kind: StatusRouletteKind.loading,
    );

    void abortSwitchUi() {
      if (!mounted || _s._disposed) return;
      ref
          .read(playerResolveStatusProvider.notifier)
          .setError('Failed: ${source.title}');
      _s._statusController.upsert(
        statusId,
        source.title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      _markSourceFailed(targetIndex);
      unawaited(_recordStreamPlayFailure(_s._currentProvider ?? ''));
    }

    try {
      final validated = await _resolveValidatedStream(source);
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (validated == null) {
        abortSwitchUi();
        return;
      }

      var openUrl = validated.openUrl;
      Map<String, String>? headers = validated.headers;
      var resolved = validated.resolved.copyWith(
        providerId: validated.resolved.providerId ?? source.providerId,
        catalogUrl:
            validated.resolved.catalogUrl ?? source.catalogUrl ?? source.url,
        title: validated.resolved.title.trim().isNotEmpty
            ? validated.resolved.title
            : source.title,
      );

      if (site111477_proxy.is111477UpstreamUrl(source.url)) {
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

      _s._resetTrackAutoSelectForSource();
      _s._durationNotifier.value = Duration.zero;
      _s._positionNotifier.value = Duration.zero;
      _s._bufferedNotifier.value = Duration.zero;
      await resetPlayerForOpen(_s._player);
      openUrl = await openPlayerStream(
        _s._player,
        url: openUrl,
        headers: headers,
        providerId: resolved.providerId ?? _s._currentProvider,
        startAt: currentPos.inSeconds > 0 ? currentPos : null,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;

      final opened = await waitForPlayerStreamOpen(
        _s._player,
        streamUrl: openUrl,
        headers: headers,
        providerId: resolved.providerId ?? _s._currentProvider,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!opened) {
        try {
          await _s._player.stop();
        } catch (_) {}
        abortSwitchUi();
        return;
      }
      final decoded = await confirmOpenedStreamVideoDecode(
        _s._player,
        openUrl: openUrl,
        headers: headers,
        type: resolved.type,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!decoded) {
        try {
          await _s._player.stop();
        } catch (_) {}
        abortSwitchUi();
        return;
      }

      if (_s._currentProvider == 'service111477') {
        setState(() {
          _s._currentUrl = openUrl;
          _s._current111477FileUrl = source.url;
          // Keep the selected index - resetting to 0 played a different stream.
          _s._currentFallbackSourceIndex = targetIndex.clamp(
            0,
            (_s._currentSources?.length ?? 1) - 1,
          );
          _s._hasError = false;
        });
      } else {
        if (_s._currentSources != null &&
            targetIndex >= 0 &&
            targetIndex < _s._currentSources!.length) {
          _s._currentSources![targetIndex] = resolved;
        }
        setState(() {
          _s._currentUrl = openUrl;
          _s._currentPlayingCatalogUrl = source.url;
          _s._currentFallbackSourceIndex = targetIndex.clamp(
            0,
            (_s._currentSources?.length ?? 1) - 1,
          );
          _s._hasError = false;
        });
      }

      _s._detectHlsQualities(openUrl, headers);
      if (currentPos.inSeconds > 0) {
        await ensureOpenedNearPosition(
          _s._player,
          currentPos,
          skipNearCredits: false,
        );
      }
      syncPlayerProgressNotifiers(
        _s._player,
        duration: _s._durationNotifier,
        position: _s._positionNotifier,
        buffered: _s._bufferedNotifier,
      );
      _s._markPlaybackConfirmed(true);
      if (_s._durationNotifier.value <= Duration.zero &&
          sourceExpectsDuration(openUrl, type: resolved.type)) {
        await waitForSeekableDuration(
          _s._player,
          timeout: const Duration(seconds: 8),
        );
        if (!mounted || _s._fallbackAborted(switchGen)) return;
        syncPlayerProgressNotifiers(
          _s._player,
          duration: _s._durationNotifier,
          position: _s._positionNotifier,
          buffered: _s._bufferedNotifier,
        );
      }
      _s._statusController.complete();
      ref.read(playerResolveStatusProvider.notifier).setReady();
      _markSourceActive(targetIndex);
      _syncPanelAfterPlaybackConfirmed();
      unawaited(_recordStreamPlaySuccess(_s._currentProvider ?? ''));
      unawaited(widget.onSourcePinned?.call(source.url, source.title));
    } catch (_) {
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      abortSwitchUi();
    } finally {
      if (switchGen == _s._fallbackGen) {
        _s._isInitPlaybackRunning = false;
      }
    }
  }
}
