part of 'exo_player_screen.dart';

/// Auto failover for Exo — MediaKit parity (siblings → reload / next provider).
mixin _ExoPlayerFailover on ConsumerState<ExoPlayerScreen> {
  _ExoPlayerScreenState get _s => this as _ExoPlayerScreenState;

  bool get _exoPinned =>
      _s._providerPinned || _s._sourcePinned || widget.pinSource;

  bool get _exoCanProviderHop =>
      !_exoPinned &&
      !widget.streamsPrevalidated &&
      widget.movie != null &&
      ((widget.providers != null && widget.providers!.isNotEmpty) ||
          widget.onReloadStreams != null);

  Future<void> _failCurrentSource(String message) async {
    if (_s._disposed || !mounted) return;
    if (_s._failoverInFlight) {
      _s._pendingOpenError = message;
      return;
    }

    if (_s._playbackStartedNotified) {
      if (await _s._tryNetworkRemount(message)) return;
    }

    _s._failoverInFlight = true;
    final chainGen = ++_s._fallbackGen;
    try {
      if (_s._sourceIndex < _s._sources.length) {
        PlaybackSelection.recordFailedUrl(_s._sources[_s._sourceIndex].url);
        _s._statusController.upsert(
          'source-${_s._sourceIndex}',
          _s._sources[_s._sourceIndex].title,
          kind: StatusRouletteKind.failed,
        );
      }

      final resumeAt = _s._playbackStartedNotified && _s._position.inSeconds > 0
          ? _s._position
          : null;
      final nextIdx = _s._sourceIndex + 1;

      debugPrint(
        '[ExoPlayer] Source failed ($message)'
        '${resumeAt != null ? ' @${resumeAt.inSeconds}s' : ''}'
        ' — ${_s._sources.isEmpty ? 0 : _s._sourceIndex + 1}'
        '/${_s._sources.length}',
      );

      if (nextIdx < _s._sources.length) {
        _s._statusController.upsert(
          'auto-hop',
          'Trying next stream…',
          kind: StatusRouletteKind.loading,
        );
        if (mounted) {
          setState(() {
            _s._hasError = false;
            _s._showControls = true;
          });
        }
        final played = await _exoTrySourcesFromIndex(
          nextIdx,
          chainGen: chainGen,
          seekAfterOpen: resumeAt,
        );
        if (played || _exoFallbackAborted(chainGen)) return;
        final pid = _s._currentProvider;
        if (pid != null && pid.isNotEmpty) {
          _exoMarkProviderFailed(pid);
        }
      }

      if (!_exoCanProviderHop) {
        debugPrint(
          '[ExoPlayer] Playback failed - no auto failover'
          '${_exoPinned ? ' (pinned)' : ''}',
        );
        await _exoShowHardFailure();
        return;
      }

      _s._statusController.upsert(
        'auto-hop',
        'Finding another stream…',
        kind: StatusRouletteKind.loading,
      );
      if (mounted) {
        setState(() {
          _s._hasError = false;
          _s._showControls = true;
        });
      }

      await _exoInvalidateExtractCache();
      if (_exoFallbackAborted(chainGen)) return;

      if (widget.onReloadStreams != null) {
        final recovered = await _exoReresolveLikeFirstPlay(
          chainGen: chainGen,
          seekAfterOpen: resumeAt,
        );
        if (recovered || _exoFallbackAborted(chainGen)) return;
      }

      if (widget.providers != null && widget.providers!.isNotEmpty) {
        await _exoAutoFallbackToNextProvider(
          chainGen: chainGen,
          seekAfterOpen: resumeAt,
        );
        return;
      }

      if (!_exoFallbackAborted(chainGen)) {
        await _exoShowHardFailure(
          message: 'Could not find any working stream from any provider.',
        );
      }
    } finally {
      if (chainGen == _s._fallbackGen) {
        _s._failoverInFlight = false;
      }
    }
  }

  Future<bool> _exoTrySourcesFromIndex(
    int startIndex, {
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    if (_s._sources.isEmpty) return false;
    final tried = <String>{};
    for (var i = startIndex; i < _s._sources.length; i++) {
      if (_exoFallbackAborted(chainGen)) return false;
      final source = _s._sources[i];
      if (tried.contains(source.url)) continue;
      tried.add(source.url);
      if (isUnplayableCachedStreamUrl(source.url) &&
          !isLocalTorrentStreamUrl(source.url) &&
          !isLocalLoopbackPlayUrl(source.url)) {
        PlaybackSelection.recordFailedUrl(source.url);
        _s._statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 500),
        );
        continue;
      }
      _s._sourceIndex = i;
      _s._currentUrl = source.url;
      _s._pendingOpenSeek = seekAfterOpen;
      _s._pendingOpenError = null;
      _s._hasError = false;
      _s._exoReady = false;
      // Keep mid-watch "started" flag so remount/hop UI stays consistent; only
      // clear when this open confirms via READY (native handler sets it again).
      if (seekAfterOpen == null) {
        _s._playbackStartedNotified = false;
      }
      try {
        await ExoPlayerBridge.stop(_s._viewId);
      } catch (_) {}
      if (_exoFallbackAborted(chainGen)) return false;
      await _s._openCurrentSource();
      if (_exoFallbackAborted(chainGen)) return false;
      final pending = _s._pendingOpenError;
      if (pending != null) {
        _s._pendingOpenError = null;
        PlaybackSelection.recordFailedUrl(source.url);
        _s._statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
        );
        continue;
      }
      if (_s._hasError) continue;
      final ok = await _exoWaitOpenSettled(chainGen);
      if (ok) return true;
      PlaybackSelection.recordFailedUrl(source.url);
      _s._statusController.upsert(
        'source-$i',
        source.title,
        kind: StatusRouletteKind.failed,
      );
    }
    return false;
  }

  /// True when READY before a hard error for this chain gen.
  Future<bool> _exoWaitOpenSettled(int chainGen) async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (_exoFallbackAborted(chainGen)) return false;
      if (_s._exoReady) return true;
      if (_s._hasError) return false;
      final pending = _s._pendingOpenError;
      if (pending != null && !_s._opening) {
        _s._pendingOpenError = null;
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return _s._exoReady;
  }

  Future<bool> _exoReresolveLikeFirstPlay({
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    final reload = widget.onReloadStreams;
    if (reload == null) return false;
    debugPrint('[ExoPlayer] Dead sources - full Auto re-resolve like first Play');
    _s._statusController.upsert(
      'reresolve',
      'Finding servers…',
      kind: StatusRouletteKind.loading,
    );
    final restoreProviderPin = _s._providerPinned;
    final restoreSourcePin = _s._sourcePinned;
    _s._providerPinned = false;
    _s._sourcePinned = false;
    try {
      final fresh = await reload();
      if (_exoFallbackAborted(chainGen)) return false;
      if (fresh == null || fresh.isEmpty) {
        _s._statusController.complete();
        return false;
      }
      final playable = dedupeStreamSources(fresh)
          .where((s) => !isUnplayableCachedStreamUrl(s.url))
          .toList();
      if (playable.isEmpty) {
        _s._statusController.complete();
        return false;
      }
      String pid = '';
      for (final e in _s._providerSourcesCache.value.entries) {
        if (e.value.any((s) => s.url == playable.first.url)) {
          pid = e.key;
          break;
        }
      }
      if (pid.isEmpty) {
        pid = _s._currentProvider ?? widget.activeProvider ?? '';
      }
      _exoApplySources(playable, providerId: pid.isEmpty ? null : pid);
      return _exoTrySourcesFromIndex(
        0,
        chainGen: chainGen,
        seekAfterOpen: seekAfterOpen,
      );
    } finally {
      _s._providerPinned = restoreProviderPin;
      _s._sourcePinned = restoreSourcePin;
    }
  }

  Future<void> _exoAutoFallbackToNextProvider({
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    final providers = widget.providers;
    if (providers == null || providers.isEmpty) {
      await _exoShowHardFailure();
      return;
    }
    final providerKeys = await PlayerSourceResolve.failoverChainForMovieAsync(
      movie: widget.movie,
      providers: providers,
      currentProviderId: _s._currentProvider,
    );
    for (final nextKey in providerKeys) {
      if (_exoFallbackAborted(chainGen)) return;
      debugPrint('[ExoPlayer] Auto-falling back to provider: $nextKey');
      final success = await _exoSilentSwitchProvider(
        nextKey,
        chainGen: chainGen,
        seekAfterOpen: seekAfterOpen,
      );
      if (success) return;
    }
    if (!_exoFallbackAborted(chainGen)) {
      await _exoShowHardFailure(
        message: 'Could not find any working stream from any provider.',
      );
    }
  }

  Future<bool> _exoSilentSwitchProvider(
    String newProvider, {
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    if (_exoFallbackAborted(chainGen)) return false;
    final providers = widget.providers;
    final movie = widget.movie;
    if (providers == null || movie == null) return false;
    final provider = providers[newProvider];
    final providerLabel =
        PlayerProviderMenu.snackbarLabel(newProvider, provider);
    _s._statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.loading,
    );
    try {
      final hit = await PlayerSourceResolve.resolvePinnedForMovie(
        movie: movie,
        providers: providers,
        providerId: newProvider,
        season: widget.selectedSeason ?? 1,
        episode:
            widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
        isCancelled: () => _exoFallbackAborted(chainGen),
      );
      if (_exoFallbackAborted(chainGen)) return false;
      if (hit == null || hit.streamUrl.isEmpty) {
        _exoMarkProviderFailed(newProvider);
        _s._statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        return false;
      }
      final resolvedSources = hit.streamSources.isNotEmpty
          ? dedupeStreamSources(hit.streamSources)
              .where((s) => !isUnplayableCachedStreamUrl(s.url))
              .toList()
          : [
              StreamSource(
                url: hit.streamUrl,
                title: providerLabel,
                type: hit.streamUrl.toLowerCase().contains('.m3u8')
                    ? 'hls'
                    : hit.streamUrl.toLowerCase().contains('.mpd')
                        ? 'dash'
                        : 'mp4',
                headers: hit.headers,
                providerId: newProvider,
                catalogUrl: hit.streamUrl,
              ),
            ];
      if (resolvedSources.isEmpty) {
        _exoMarkProviderFailed(newProvider);
        _s._statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        return false;
      }
      _s._statusController.upsert(
        'provider-$newProvider',
        providerLabel,
        kind: StatusRouletteKind.success,
      );
      _exoApplySources(resolvedSources, providerId: newProvider);
      final played = await _exoTrySourcesFromIndex(
        0,
        chainGen: chainGen,
        seekAfterOpen: seekAfterOpen,
      );
      if (played) return true;
      if (_exoFallbackAborted(chainGen)) return false;
      _exoMarkProviderFailed(newProvider);
      _s._statusController.upsert(
        'provider-$newProvider',
        providerLabel,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(milliseconds: 1200),
      );
      return false;
    } catch (e) {
      if (_exoFallbackAborted(chainGen)) return false;
      debugPrint('[ExoPlayer] Silent fallback to $newProvider failed: $e');
      _exoMarkProviderFailed(newProvider);
      return false;
    }
  }

  void _exoApplySources(
    List<StreamSource> sources, {
    String? providerId,
  }) {
    final pid = providerId ?? _s._currentProvider;
    if (!mounted || _s._disposed) return;
    setState(() {
      if (pid != null && pid.isNotEmpty) {
        _s._currentProvider = pid;
        _s._providerSourcesCache.value = {
          ..._s._providerSourcesCache.value,
          pid: sources,
        };
        final fails = {..._s._providerLoadFailures.value}..remove(pid);
        _s._providerLoadFailures.value = fails;
      }
      _s._currentSources = sources;
      _s._currentUrl = sources.first.url;
      _s._currentPlayingCatalogUrl =
          sources.first.catalogUrl ?? sources.first.url;
      _s._hasError = false;
      _s._sources = [
        for (final s in sources)
          _ExoSource(
            url: s.url,
            title: s.title,
            headers: s.headers ?? widget.headers,
          ),
      ];
      _s._sourceIndex = 0;
    });
  }

  Future<void> _exoInvalidateExtractCache() async {
    final movie = widget.movie;
    if (movie == null) return;
    final key = PlayerStreamExtractCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode,
    );
    await PlayerStreamExtractCache.drop(key);
    if (_s._disposed) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null && pid.isNotEmpty) {
      final next = Map<String, List<StreamSource>>.from(
        _s._providerSourcesCache.value,
      )..remove(pid);
      _s._providerSourcesCache.value = next;
    }
    debugPrint('[ExoPlayer] dropped stale player stream extract cache $key');
  }

  void _exoMarkProviderFailed(String pid) {
    _s._providerLoadFailures.value = {
      ..._s._providerLoadFailures.value,
      pid,
    };
  }

  Future<void> _exoShowHardFailure({String? message}) async {
    if (!mounted || _s._disposed) return;
    if (message != null) {
      debugPrint('[ExoPlayer] $message');
    }
    _s._statusController.upsert(
      'playback-failed',
      'Failed to stream',
      kind: StatusRouletteKind.failed,
    );
    setState(() {
      _s._hasError = true;
      _s._showControls = true;
    });
    if (!_s._playbackStartedNotified) {
      _exoNotifyAllSourcesExhausted();
    }
    await _exoInvalidateExtractCache();
  }

  void _exoNotifyAllSourcesExhausted() {
    if (widget.onAllSourcesExhausted == null ||
        _s._allSourcesExhaustedNotified) {
      return;
    }
    _s._allSourcesExhaustedNotified = true;
    widget.onAllSourcesExhausted!();
  }

  bool _exoFallbackAborted(int chainGen) =>
      !mounted || _s._disposed || chainGen != _s._fallbackGen;
}
