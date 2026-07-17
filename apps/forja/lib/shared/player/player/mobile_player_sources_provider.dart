part of 'mobile_player_screen.dart';

mixin _MobilePlayerSourcesProvider on State<MobilePlayerScreen> {
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

    // One host WebView — abandon other in-flight Source-panel loads.
    for (final id in _s._providerLoadGens.keys.toList()) {
      if (id == providerId) continue;
      _s._providerLoadGens[id] = (_s._providerLoadGens[id] ?? 0) + 1;
    }
    DomainStreamProviderResolver.cancelAllPending();

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
        episode: widget.hubEpisodeNumber?.toInt() ??
            widget.selectedEpisode ??
            1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
      );
      if (_s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen) {
        return null;
      }
      if (hit != null && hit.streamSources.isNotEmpty) {
        final sources = dedupeStreamSources(hit.streamSources);
        _s._liveProviderSourcesCache.value = {
          ..._s._liveProviderSourcesCache.value,
          providerId: sources,
        };
        // Current server list prefers live [_currentSources] over session
        // cache — refresh it so panel reload is not a no-op after cache play.
        if (forceRefresh &&
            (_s._currentProvider == providerId ||
                ((_s._currentProvider == null || _s._currentProvider!.isEmpty) &&
                    widget.activeProvider == providerId))) {
          _s._currentSources = sources;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
        }
        _s._markProviderLoadSucceeded(providerId);
        _s._scoreServerUp(providerId);
        _s._sourceMenuRevision.value++;
        return sources;
      }
      _s._markProviderLoadFailed(providerId);
      _s._sourceMenuRevision.value++;
      return null;
    } catch (_) {
      if ((_s._providerLoadGens[providerId] ?? 0) == gen) {
        _s._markProviderLoadFailed(providerId);
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
    DomainStreamProviderResolver.cancelAllPending();
    _s._statusController.clear();
    _s._markPlaybackConfirmed(false);

    final currentPos = _s._positionNotifier.value;
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
          episode: widget.hubEpisodeNumber?.toInt() ??
              widget.selectedEpisode ??
              1,
          isCancelled: () => _s._fallbackAborted(gen),
        );
        if (_s._fallbackAborted(gen)) return null;
        if (hit != null) {
          streamUrl = hit.streamUrl;
          headers = hit.headers;
          sources = hit.streamSources;
        }
      }

      if (_s._fallbackAborted(gen)) return null;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        _s._autoTracksAppliedForSource = false;
        _s._durationNotifier.value = Duration.zero;
        _s._positionNotifier.value = Duration.zero;
        _s._bufferedNotifier.value = Duration.zero;
        await resetPlayerForOpen(_s._player);
        streamUrl = await openPlayerStream(
          _s._player,
          url: streamUrl,
          headers: headers,
        );
        if (_s._fallbackAborted(gen)) return null;

        if (currentPos.inSeconds > 0) {
          await _s._player.seek(currentPos);
        }
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
          _s._errorMessage = '';
          _s._markPlaybackConfirmed(true);
          if (newProvider == 'service111477' &&
              _s._currentSources != null &&
              _s._currentSources!.isNotEmpty) {
            _s._current111477FileUrl = _s._currentSources!.first.url;
          }
        });

        _s._statusController.complete();
        _s._markSourceActive(0);
        _s._syncPanelAfterPlaybackConfirmed();
        widget.onPlaybackStarted?.call();
        final selectedSources = _s._currentSources;
        if (selectedSources != null && selectedSources.isNotEmpty) {
          _s._liveProviderSourcesCache.value = {
            ..._s._liveProviderSourcesCache.value,
            newProvider: selectedSources,
          };
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
      }
    }
    return null;
  }
}
