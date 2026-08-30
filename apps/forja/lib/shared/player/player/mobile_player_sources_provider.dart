part of 'mobile_player_screen.dart';

mixin _MobilePlayerSourcesProvider on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  Future<List<StreamSource>?> _loadProvider(
    String providerId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _s._liveProviderSourcesCache.value[providerId];
      if (cached != null && cached.isNotEmpty) {
        _s._markProviderLoadSucceeded(providerId);
        return cached;
      }
    } else {
      final next = Map<String, List<StreamSource>>.from(
        _s._liveProviderSourcesCache.value,
      )..remove(providerId);
      _s._liveProviderSourcesCache.value = next;
    }

    // One host WebView - abandon other in-flight Source-panel loads.
    for (final id in _s._providerLoadGens.keys.toList()) {
      if (id == providerId) continue;
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    EngineService.instance.cancelPending();

    final gen = (_s._providerLoadGens[providerId] ?? 0) + 1;
    _s._providerLoadGens[providerId] = gen;

    try {
      if (widget.movie == null || widget.providers == null) {
        _s._markProviderLoadFailed(providerId);
        return null;
      }
      final hit = await PlayerSourceResolve.resolvePinnedForMovie(
        movie: widget.movie!,
        providers: widget.providers!,
        providerId: providerId,
        season: widget.selectedSeason ?? 1,
        episode:
            widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
      );
      if (_s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen) {
        return null;
      }
      if (hit != null && hit.streamSources.isNotEmpty) {
        if (hit.providerId.isNotEmpty && hit.providerId != providerId) {
          debugPrint(
            '[Player] refuse cache $providerId ← hit ${hit.providerId}',
          );
          _s._markProviderLoadFailed(providerId);
          _s._sourceMenuRevision.value++;
          return null;
        }
        final sources = sourcesOwnedByProvider(
          providerId,
          dedupeStreamSources(hit.streamSources),
        );
        if (sources.isEmpty) {
          _s._markProviderLoadFailed(providerId);
          _s._sourceMenuRevision.value++;
          return null;
        }
        _s._cacheProviderSources(providerId, sources);
        // Keep live session list as full as the server cache - selecting a
        // stream must not leave [_currentSources] as a singleton forever.
        final isActive =
            _s._currentProvider == providerId ||
            ((_s._currentProvider == null || _s._currentProvider!.isEmpty) &&
                widget.activeProvider == providerId);
        if (isActive &&
            (forceRefresh ||
                (_s._currentSources?.length ?? 0) < sources.length)) {
          _s._currentSources = preferFullerProviderSources(
            providerId: providerId,
            live: _s._currentSources,
            cached: _s._liveProviderSourcesCache.value[providerId] ?? sources,
          );
          if (forceRefresh) {
            _s._failedSourceIndices.clear();
            _s._checkingSourceIndices.clear();
          }
        }
        _s._markProviderLoadSucceeded(providerId);
        _s._scoreServerUp(providerId);
        _s._sourceMenuRevision.value++;
        return sources;
      }
      final playingSame =
          _s._playbackConfirmed &&
          (_s._currentProvider == providerId ||
              widget.activeProvider == providerId);
      if (!playingSame) {
        _s._markProviderLoadFailed(providerId);
      } else {
        _s._markProviderLoadSucceeded(providerId);
        _s._syncProbeStatus(providerId, StreamProviderProbeStatus.success);
      }
      _s._sourceMenuRevision.value++;
      return null;
    } catch (_) {
      if ((_s._providerLoadGens[providerId] ?? 0) == gen) {
        final playingSame =
            _s._playbackConfirmed &&
            (_s._currentProvider == providerId ||
                widget.activeProvider == providerId);
        if (!playingSame) {
          _s._markProviderLoadFailed(providerId);
        }
        _s._sourceMenuRevision.value++;
      }
      return null;
    }
  }

  Future<List<StreamSource>?> _switchProvider(String newProvider) async {
    _s._providerPinned = true;
    _s._sourcePinned = false;
    unawaited(SettingsService().setPlayerAutoServer(false));

    final gen = ++_s._fallbackGen;
    EngineService.instance.cancelPending();
    _s._statusController.clear();
    _s._markPlaybackConfirmed(false);

    // Chip label follows selection immediately (not only after open/decode).
    if (mounted) {
      setState(() => _s._currentProvider = newProvider);
    } else {
      _s._currentProvider = newProvider;
    }

    final currentPos = switchResumePosition(
      uiPosition: _s._positionNotifier.value,
      playerPosition: _s._player.state.position,
    );
    final provider = widget.providers![newProvider];
    final providerLabel = PlayerProviderMenu.snackbarLabel(
      newProvider,
      provider,
    );
    _s._statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.loading,
    );

    try {
      String? streamUrl;
      Map<String, String>? headers;
      List<StreamSource>? sources;

      final cached = _s._liveProviderSourcesCache.value[newProvider];
      final usedCache = cached != null && cached.isNotEmpty;
      if (usedCache) {
        streamUrl = cached.first.url;
        headers = cached.first.headers;
        sources = cached;
      } else if (widget.movie != null && widget.providers != null) {
        if (newProvider == 'service111477' &&
            site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        final hit = await PlayerSourceResolve.resolvePinnedForMovie(
          movie: widget.movie!,
          providers: widget.providers!,
          providerId: newProvider,
          season: widget.selectedSeason ?? 1,
          episode:
              widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
          isCancelled: () => _s._fallbackAborted(gen),
        );
        if (_s._fallbackAborted(gen)) return null;
        if (hit != null) {
          streamUrl = hit.streamUrl;
          final srcs = hit.streamSources;
          sources = srcs;
          final firstHdrs = srcs.isNotEmpty ? srcs.first.headers : null;
          headers = (firstHdrs != null && firstHdrs.isNotEmpty)
              ? firstHdrs
              : hit.headers;
        }
      }

      if (_s._fallbackAborted(gen)) return null;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        _s._resetTrackAutoSelectForSource();
        _s._durationNotifier.value = Duration.zero;
        _s._positionNotifier.value = Duration.zero;
        _s._bufferedNotifier.value = Duration.zero;
        await resetPlayerForOpen(_s._player);
        streamUrl = await openPlayerStream(
          _s._player,
          url: streamUrl,
          headers: headers,
          providerId: newProvider,
          startAt: currentPos.inSeconds > 0 ? currentPos : null,
        );
        if (_s._fallbackAborted(gen)) return null;

        final opened = await waitForPlayerStreamOpen(
          _s._player,
          streamUrl: streamUrl,
          headers: headers,
          providerId: newProvider,
        );
        if (_s._fallbackAborted(gen)) return null;
        if (!opened) {
          if (mounted) {
            _s._markProviderLoadFailed(newProvider);
            _s._statusController.upsert(
              'provider-$newProvider',
              providerLabel,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(seconds: 2),
            );
            setState(() => _s._hasError = true);
          }
          return null;
        }
        final decoded = await confirmOpenedStreamVideoDecode(
          _s._player,
          openUrl: streamUrl,
          headers: headers,
          type: sources?.first.type,
        );
        if (_s._fallbackAborted(gen)) return null;
        if (!decoded) {
          if (mounted) {
            _s._markProviderLoadFailed(newProvider);
            _s._statusController.upsert(
              'provider-$newProvider',
              providerLabel,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(seconds: 2),
            );
            setState(() => _s._hasError = true);
          }
          return null;
        }

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
        _s._detectHlsQualities(streamUrl, headers);

        setState(() {
          _s._currentProvider = newProvider;
          _s._currentSources = sources == null
              ? null
              : dedupeStreamSources(sources);
          _s._currentUrl = streamUrl;
          _s._currentPlayingCatalogUrl =
              _s._currentSources?.first.url ?? streamUrl;
          _s._currentFallbackSourceIndex = 0; // Reset index on manual switch
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._hasError = false;
          _s._markPlaybackConfirmed(true);
          if (newProvider == 'service111477' &&
              _s._currentSources != null &&
              _s._currentSources!.isNotEmpty) {
            _s._current111477FileUrl = _s._currentSources!.first.url;
          }
        });
        if (_s._durationNotifier.value <= Duration.zero &&
            sourceExpectsDuration(streamUrl, type: sources?.first.type)) {
          await waitForSeekableDuration(
            _s._player,
            timeout: const Duration(seconds: 8),
          );
          if (_s._fallbackAborted(gen)) return null;
          syncPlayerProgressNotifiers(
            _s._player,
            duration: _s._durationNotifier,
            position: _s._positionNotifier,
            buffered: _s._bufferedNotifier,
          );
        }

        _s._statusController.complete();
        _s._markSourceActive(0);
        _s._syncPanelAfterPlaybackConfirmed();
        widget.onPlaybackStarted?.call();
        final selectedSources = _s._currentSources;
        if (selectedSources != null && selectedSources.isNotEmpty) {
          _s._cacheProviderSources(newProvider, selectedSources);
          _s._markProviderLoadSucceeded(newProvider);
          if (!usedCache) _s._scoreServerUp(newProvider);
          unawaited(
            widget.onSourcePinned?.call(
              selectedSources.first.url,
              selectedSources.first.title,
            ),
          );
        } else {
          unawaited(widget.onSourcePinned?.call(streamUrl, providerLabel));
        }
        return _s._currentSources;
      } else {
        if (mounted && !_s._fallbackAborted(gen)) {
          _s._markProviderLoadFailed(newProvider);
          _s._statusController.upsert(
            'provider-$newProvider',
            providerLabel,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
          setState(() => _s._hasError = true);
        }
      }
    } catch (e) {
      if (mounted && !_s._fallbackAborted(gen)) {
        _s._statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        setState(() => _s._hasError = true);
      }
    }
    return null;
  }
}
