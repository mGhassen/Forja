part of 'desktop_player_screen.dart';

mixin _DesktopPlayerPlayback on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  Future<bool> _trySourcesFromIndex(
    int startIndex, {
    int? chainGen,
    Duration? seekAfterOpen,
  }) async {
    if (_s._currentSources == null || _s._currentSources!.isEmpty) return false;

    final triedUrls = <String>{};
    _s._currentFallbackSourceIndex = startIndex;
    final runGen = chainGen ?? _s._fallbackGen;

    while (_s._currentFallbackSourceIndex < _s._currentSources!.length) {
      if (_fallbackAborted(runGen)) return false;

      final i = _s._currentFallbackSourceIndex;
      var source = _s._currentSources![i];

      if (triedUrls.contains(source.url)) {
        debugPrint('[Player] Skipping duplicate URL at index $i');
        _s._currentFallbackSourceIndex++;
        continue;
      }
      triedUrls.add(source.url);

      debugPrint(
        '[Player] Trying source ${i + 1}/${_s._currentSources!.length}: ${source.title}',
      );
      final skipCheckingUi = widget.pinSource && i == startIndex;
      if (!skipCheckingUi) {
        _s._markSourceChecking(i);
        _s._statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.loading,
        );
      }

      if (PlayableSourceBridge.isArabicEmbed(_s._playableSources, i, source)) {
        debugPrint('[Player] Extracting arabic embed: ${source.title}');
        final result = await ArabicService.extractStreamUrl(source.url);
        if (_fallbackAborted(runGen)) return false;
        if (result == null) {
          debugPrint('[Player] Arabic extract failed for ${source.title}');
          _s._statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 1200),
          );
          _s._markSourceFailed(i);
          _s._currentFallbackSourceIndex++;
          continue;
        }
        source = StreamSource(
          url: result.url,
          title: source.title,
          type: result.url.contains('.m3u8')
              ? 'hls'
              : result.url.contains('.mpd')
              ? 'dash'
              : 'mp4',
        );
        _s._currentSources![i] = source;
      }

      try {
        _s._autoTracksAppliedForSource = false;
        _s._durationNotifier.value = Duration.zero;
        _s._positionNotifier.value = Duration.zero;
        _s._bufferedNotifier.value = Duration.zero;
        await _configureMpvProperties();

        var openUrl = source.url;
        if (PlayableSourceBridge.requiresProxy(
          _s._playableSources,
          i,
          _s._currentProvider,
        )) {
          if (!site111477_proxy.is111477ProxyRunning ||
              _s._current111477FileUrl != source.url) {
            if (site111477_proxy.is111477ProxyRunning) {
              await site111477_proxy.stop111477Proxy();
            }
            openUrl = await site111477_proxy.start111477Proxy(source.url);
            _s._current111477FileUrl = source.url;
          } else {
            openUrl = site111477_proxy.site111477ProxyUrl!;
          }
        }

        final srcHeaders = source.headers ?? widget.headers;
        await resetPlayerForOpen(_s._player);
        await applyMediaHttpHeaders(_s._player, srcHeaders);
        await _s._player.open(Media(openUrl, httpHeaders: srcHeaders));
        if (_fallbackAborted(runGen)) return false;
        _s._player.setVolume(_s._volumeNotifier.value);
        final opened = await waitForMediaOpen(
          _s._player,
          streamUrl: openUrl,
          timeout: isLocalTorrentStreamUrl(openUrl)
              ? const Duration(seconds: 45)
              : const Duration(seconds: 12),
        );
        if (_fallbackAborted(runGen)) return false;
        if (!opened) {
          debugPrint('[Player] Source $i failed to open: $openUrl');
          await _s._player.stop();
          _s._statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 500),
          );
          _s._markSourceFailed(i);
          unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
          _s._currentFallbackSourceIndex++;
          continue;
        }
        final needsDuration = sourceExpectsDuration(openUrl, type: source.type);
        final decoded =
            !sourceRequiresVideoDecode(openUrl, type: source.type) ||
            await waitForVideoDecode(_s._player);
        if (_fallbackAborted(runGen)) return false;
        if (!decoded) {
          debugPrint('[Player] Source $i opened without video: $openUrl');
          await _s._player.stop();
          _s._statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 500),
          );
          _s._markSourceFailed(i);
          unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
          _s._currentFallbackSourceIndex++;
          continue;
        }
        final hasDuration =
            !needsDuration || await waitForSeekableDuration(_s._player);
        if (_fallbackAborted(runGen)) return false;
        if (!hasDuration) {
          debugPrint('[Player] Source $i opened without duration: $openUrl');
          await _s._player.stop();
          _s._statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 500),
          );
          _s._markSourceFailed(i);
          unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
          _s._currentFallbackSourceIndex++;
          continue;
        }
        syncPlayerProgressNotifiers(
          _s._player,
          duration: _s._durationNotifier,
          position: _s._positionNotifier,
          buffered: _s._bufferedNotifier,
        );
        if (seekAfterOpen != null && seekAfterOpen.inSeconds > 0) {
          await _s._player.seek(seekAfterOpen);
          if (_fallbackAborted(runGen)) return false;
        }
        _s._detectHlsQualities(openUrl, source.headers ?? widget.headers);
        setState(() {
          _s._currentUrl = openUrl;
          _s._currentPlayingCatalogUrl = source.url;
          _s._playbackConfirmed = true;
        });
        _s._statusController.complete();
        _s._markSourceActive(i);
        _s._syncPanelAfterPlaybackConfirmed();
        unawaited(
          _s._recordStreamPlaySuccess(_s._currentProvider ?? ''),
        );
        widget.onPlaybackStarted?.call();
        return true;
      } catch (e) {
        if (_fallbackAborted(runGen)) return false;
        debugPrint('[Player] Source $i catch error: $e');
        await _s._player.stop();
        _s._statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 500),
        );
        _s._markSourceFailed(i);
        _s._currentFallbackSourceIndex++;
      }
    }
    return false;
  }

  Future<void> _initPlayback({int sourceStartIndex = 0}) async {
    if (_s._disposed) return;
    if (_s._isInitPlaybackRunning)
      return; // Prevent re-entrant calls during async extraction
    _s._isInitPlaybackRunning = true;
    final initGen = _s._fallbackGen;
    _s._playbackConfirmed = false;

    try {
      setState(() {
        _s._hasError = false;
        _s._errorMessage = '';
        _s._showControls = true;
      });

      if (_s._currentSources != null && _s._currentSources!.isNotEmpty) {
        _subscribeToStreams();
        var startIndex = sourceStartIndex;
        if (sourceStartIndex == 0 && widget.pinSource) {
          _s._syncCurrentSourceIndexFromPlayUrl();
          startIndex = _s._currentFallbackSourceIndex;
        }
        final played = await _trySourcesFromIndex(
          startIndex,
          chainGen: initGen,
          seekAfterOpen: widget.startPosition,
        );
        if (played) return;
        if (_fallbackAborted(initGen)) return;

        if (_s._currentProvider != null &&
            (_s._currentSources?.isNotEmpty ?? false)) {
          _s._cacheProviderSources(_s._currentProvider!, _s._currentSources!);
          _s._markProviderLoadFailed(_s._currentProvider!);
        }

        if ((_s._providerPinned || _s._sourcePinned || widget.pinSource) &&
            !_fallbackAborted(initGen)) {
          final pid = _s._currentProvider ?? widget.activeProvider;
          final movie = widget.movie;
          final providers = widget.providers;
          if (pid != null &&
              pid.isNotEmpty &&
              movie != null &&
              providers != null &&
              providers.containsKey(pid)) {
            debugPrint(
              '[Player] Cached $pid source failed — re-resolving fresh extract',
            );
            await _invalidateWebstreamingCacheForCurrent();
            final hit = await PlayerSourceResolve.resolvePinnedForMovie(
              movie: movie,
              providers: providers,
              providerId: pid,
              season: widget.selectedSeason ?? 1,
              episode: widget.selectedEpisode ?? 1,
              isCancelled: () => _fallbackAborted(initGen),
            );
            if (!_fallbackAborted(initGen) &&
                hit != null &&
                hit.streamSources.isNotEmpty) {
              final fresh = dedupeStreamSources(hit.streamSources);
              _s._cacheProviderSources(pid, fresh);
              _s._markProviderLoadSucceeded(pid);
              setState(() {
                _s._currentSources = fresh;
                _s._currentUrl = hit.streamUrl;
                _s._currentPlayingCatalogUrl = fresh.first.url;
                _s._currentFallbackSourceIndex = 0;
                _s._failedSourceIndices.clear();
                _s._checkingSourceIndices.clear();
              });
              final retryPlayed = await _trySourcesFromIndex(
                0,
                chainGen: initGen,
                seekAfterOpen: widget.startPosition,
              );
              if (retryPlayed) return;
            }
          }
        }

        // Cached / pinned URL could not open — unlock failover for this session
        // but keep disk/session cache so details Play can retry the same server.
        if (_s._providerPinned || _s._sourcePinned) {
          debugPrint(
            '[Player] Preferred source failed to open — unlocking failover',
          );
          _s._providerPinned = false;
          _s._sourcePinned = false;
        }
        await _autoFallbackToNextProvider();
      } else {
        // No sources list — primary mediaPath (torrent localhost or direct URL).
        final openUrl = widget.mediaPath;
        final isTorrent =
            isLocalTorrentStreamUrl(openUrl) || widget.magnetLink != null;
        int retryCount = 0;
        const maxRetries = 2;

        while (retryCount < maxRetries) {
          try {
            _subscribeToStreams();
            await _configureMpvProperties();
            await resetPlayerForOpen(_s._player);
            await applyMediaHttpHeaders(_s._player, widget.headers);
            await _s._player.open(Media(openUrl, httpHeaders: widget.headers));
            if (_fallbackAborted(initGen)) return;
            _s._player.setVolume(_s._volumeNotifier.value);
            final opened = await waitForMediaOpen(
              _s._player,
              streamUrl: openUrl,
              timeout: isTorrent
                  ? const Duration(seconds: 45)
                  : const Duration(seconds: 12),
            );
            if (_fallbackAborted(initGen)) return;
            if (!opened) {
              throw Exception('Failed to open media');
            }
            _s._detectHlsQualities(openUrl, widget.headers);
            _s._playbackConfirmed = true;
            _s._syncPanelAfterPlaybackConfirmed();
            widget.onPlaybackStarted?.call();
            return;
          } catch (e) {
            retryCount++;
            debugPrint(
              '[Player] Primary open failed ($retryCount/$maxRetries): $e',
            );
            if (retryCount >= maxRetries) {
              if (_fallbackAborted(initGen)) return;
              if (mounted) {
                setState(() {
                  _s._hasError = true;
                  _s._showControls = true;
                  _s._errorMessage = isTorrent
                      ? 'Torrent stream failed to open.'
                      : 'Playback failed.';
                });
              }
              await _autoFallbackToNextProvider();
              return;
            }
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
      }
    } finally {
      _s._isInitPlaybackRunning = false;
    }
  }

  Future<void> _invalidateWebstreamingCacheForCurrent() async {
    final movie = widget.movie;
    if (movie == null) return;
    final key = WebstreamingStreamCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    await WebstreamingStreamCache.drop(key);
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null && pid.isNotEmpty) {
      final next = Map<String, List<StreamSource>>.from(
        _s._liveProviderSourcesCache.value,
      )..remove(pid);
      _s._liveProviderSourcesCache.value = next;
    }
    debugPrint('[Player] dropped stale webstreaming cache $key');
    _s._notifySourceMenuChanged();
  }

  Future<void> _autoFallbackToNextProvider() async {
    if (widget.providers == null || widget.providers!.isEmpty) {
      notifyNoServerAvailable(_s._statusController);
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
        _s._errorMessage = 'All sources and providers failed.';
      });
      _notifyAllSourcesExhausted();
      return;
    }

    final chainGen = _s._fallbackGen;
    final providerKeys = await PlayerSourceResolve.failoverChainForMovieAsync(
      movie: widget.movie,
      providers: widget.providers!,
      currentProviderId: _s._currentProvider,
    );

    for (final nextKey in providerKeys) {
      if (_fallbackAborted(chainGen)) return;
      debugPrint('[Player] Auto-falling back to provider: $nextKey');

      final success = await _silentSwitchProvider(nextKey, chainGen: chainGen);
      if (success) return;
    }

    if (mounted && !_fallbackAborted(chainGen)) {
      notifyNoServerAvailable(_s._statusController);
      _s._finalizeProbeStatusesAfterPlayback();
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
        _s._errorMessage = 'Could not find any working stream from any provider.';
      });
      _notifyAllSourcesExhausted();
      await _invalidateWebstreamingCacheForCurrent();
    }
  }

  void _notifyAllSourcesExhausted() {
    if (widget.onAllSourcesExhausted == null || _s._allSourcesExhaustedNotified) {
      return;
    }
    _s._allSourcesExhaustedNotified = true;
    widget.onAllSourcesExhausted!();
  }

  bool _fallbackAborted(int chainGen) =>
      !mounted || _s._disposed || chainGen != _s._fallbackGen;

  /// Switches provider without showing full error UI on failure, returns success
  Future<bool> _silentSwitchProvider(
    String newProvider, {
    int? chainGen,
  }) async {
    final gen = chainGen ?? _s._fallbackGen;
    if (_fallbackAborted(gen)) return false;
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
    _s._syncProbeStatus(newProvider, StreamProviderProbeStatus.trying);
    try {
      String? streamUrl;
      Map<String, String>? headers;
      List<StreamSource>? sources;

      final movie = widget.movie;
      final providers = widget.providers;
      if (movie != null && providers != null) {
        if (newProvider == 'service111477' &&
            site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        final hit = await PlayerSourceResolve.resolvePinnedForMovie(
          movie: movie,
          providers: providers,
          providerId: newProvider,
          season: widget.selectedSeason ?? 1,
          episode: widget.selectedEpisode ?? 1,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return false;
        if (hit != null) {
          streamUrl = hit.streamUrl;
          headers = hit.headers;
          sources = hit.streamSources;
        }
      }

      if (_fallbackAborted(gen)) return false;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        final resolvedSources = sources != null && sources.isNotEmpty
            ? dedupeStreamSources(sources)
            : [
                StreamSource(
                  url: streamUrl,
                  title: providerLabel,
                  type: streamUrl.toLowerCase().contains('.m3u8')
                      ? 'hls'
                      : streamUrl.toLowerCase().contains('.mpd')
                      ? 'dash'
                      : 'mp4',
                  headers: headers,
                ),
              ];

        _s._statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.success,
        );

        _s._cacheProviderSources(newProvider, resolvedSources);
        _s._scoreServerUp(newProvider);

        setState(() {
          _s._currentProvider = newProvider;
          _s._currentSources = resolvedSources;
          _s._currentFallbackSourceIndex = 0;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._hasError = false;
          _s._errorMessage = '';
          if (newProvider == 'service111477' && resolvedSources.isNotEmpty) {
            _s._current111477FileUrl = resolvedSources.first.url;
          }
        });

        final currentPos = _s._positionNotifier.value;
        final played = await _trySourcesFromIndex(
          0,
          chainGen: gen,
          seekAfterOpen: currentPos,
        );
        if (played) return true;
        if (_fallbackAborted(gen)) return false;

        _s._markProviderLoadFailed(newProvider);
        _s._statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        return false;
      }
    } catch (e) {
      if (_fallbackAborted(gen)) return false;
      debugPrint('[Player] Silent fallback to $newProvider failed: $e');
    }
    if (_fallbackAborted(gen)) return false;
    _s._markProviderLoadFailed(newProvider);
    _s._statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.failed,
      dismissAfter: const Duration(milliseconds: 1200),
    );
    return false;
  }

  void _subscribeToStreams() {
    // Cancel any existing subscriptions to prevent duplicate listeners
    _s._positionSub?.cancel();
    _s._durationSub?.cancel();
    _s._bufferSub?.cancel();
    _s._playingSub?.cancel();
    _s._bufferingSub?.cancel();
    _s._volumeSub?.cancel();
    _s._errorSub?.cancel();
    _s._completedSub?.cancel();
    _s._tracksSub?.cancel();
    _s._logSub?.cancel();
    _s._logSub?.cancel();
    _s._autoTracksAppliedForSource = false;

    _s._playbackRecovery = PlaybackRecovery(
      player: _s._player,
      onRetryNextSource: () {
        final next = _s._currentFallbackSourceIndex + 1;
        if (_s._currentSources != null && next < _s._currentSources!.length) {
          _initPlayback(sourceStartIndex: next);
        } else if (!_s._providerPinned) {
          _autoFallbackToNextProvider();
        }
      },
      onForceSoftwareDecode: () async {
        if (_s._player.platform is! NativePlayer) return;
        await (_s._player.platform as NativePlayer).setProperty('hwdec', 'no');
      },
      onRecoverAudio: _recoverAudioTrack,
    );

    // Position – drives seekbar & watch-history
    _s._positionSub = _s._player.stream.position.listen((pos) {
      if (_s._disposed) return;
      _s._positionNotifier.value = pos;

      // Near-end detection for next episode button
      if (_s._isNextEpisodeAvailable && !_s._nearEndOfEpisode) {
        final dur = _s._durationNotifier.value;
        if (dur.inSeconds > 0) {
          final remaining = dur - pos;
          final threshold = dur.inMinutes < 10
              ? Duration(seconds: (dur.inSeconds * 0.05).round())
              : const Duration(minutes: 2);
          if (remaining <= threshold) {
            setState(() => _s._nearEndOfEpisode = true);
          }
        }
      }

      // Skip segment detection (IntroDB)
      _s._updateActiveSkipSegment(pos);
    });

    // Duration – triggers auto-resume on first valid duration
    _s._durationSub = _s._player.stream.duration.listen((dur) {
      if (_s._disposed) return;
      _s._durationNotifier.value = dur;
      if (!_s._hasInitialSeek &&
          dur.inSeconds > 0 &&
          widget.startPosition != null) {
        _s._hasInitialSeek = true;
        _s._player.seek(widget.startPosition!);
      }
    });

    // Buffered position – shows how far ahead is cached
    _s._bufferSub = _s._player.stream.buffer.listen((buf) {
      if (_s._disposed) return;
      _s._bufferedNotifier.value = buf;
    });

    // Playing state
    _s._playingSub = _s._player.stream.playing.listen((playing) {
      if (_s._disposed) return;
      _s._isPlayingNotifier.value = playing;
      if (playing) {
        _s._startHideTimer();
        // Scrobble resume
        if (widget.movie != null) {
          final pos = _s._positionNotifier.value.inMilliseconds;
          final dur = _s._durationNotifier.value.inMilliseconds;
          final pct = dur > 0 ? (pos / dur * 100) : 0.0;
          TraktService().scrobbleStart(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
            progressPercent: pct,
          );
          SimklService().scrobbleStart(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
          );
        }
      } else {
        if (mounted) setState(() => _s._showControls = true);
        // Scrobble pause
        if (widget.movie != null) {
          final pos = _s._positionNotifier.value.inMilliseconds;
          final dur = _s._durationNotifier.value.inMilliseconds;
          final pct = dur > 0 ? (pos / dur * 100) : 0.0;
          TraktService().scrobblePause(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
            progressPercent: pct,
          );
          SimklService().scrobblePause(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
          );
        }
      }
    });

    // Buffering spinner
    _s._bufferingSub = _s._player.stream.buffering.listen((buffering) {
      if (_s._disposed) return;
      _s._isBufferingNotifier.value = buffering;
    });

    // Volume sync (e.g. hardware media keys)
    _s._volumeSub = _s._player.stream.volume.listen((vol) {
      if (_s._disposed) return;
      _s._volumeNotifier.value = vol;
    });

    // Error recovery – log & surface to UI
    _s._errorSub = _s._player.stream.error.listen((err) {
      if (_s._disposed || err.isEmpty) return;
      final currentUrl =
          _s._currentSources != null &&
              _s._currentFallbackSourceIndex < _s._currentSources!.length
          ? _s._currentSources![_s._currentFallbackSourceIndex].url
          : null;
      if (isVideoDecoderError(err)) {
        debugPrint('🔴 Video decoder error: $err');
        _s._playbackRecovery?.handlePlayerError(err, currentUrl: currentUrl);
        return;
      }
      if (isIgnorablePlayerError(err)) {
        if (err.contains('subtitle') ||
            err.toLowerCase().contains('sub-add') ||
            err.toLowerCase().contains('external file')) {
          debugPrint('🟡 Sub error (ignored): $err');
        }
        return;
      }

      debugPrint('🔴 Player error: $err');

      if (!isFatalPlayerOpenError(err)) return;
      if (_s._hasError || _s._isInitPlaybackRunning) {
        if (_s._isInitPlaybackRunning) {
          debugPrint(
            '[Player] Ignoring stale error — _initPlayback already running',
          );
        }
        return;
      }
      if (!_s._playbackConfirmed) {
        debugPrint('[Player] Ignoring open error — probe handles fallback');
        return;
      }
      _s._playbackConfirmed = false;
      if (_s._sourcePinned) {
        // Manual source lock: stop. Cache/resume pin: unlock and keep trying.
        if (!(widget.pinSource || _s._hasResolvedWebStream)) {
          setState(() {
            _s._hasError = true;
            _s._showControls = true;
            _s._errorMessage = 'Playback failed on the selected source.';
          });
          return;
        }
        debugPrint(
          '[Player] Cached/preferred source died — unlocking failover',
        );
        _s._sourcePinned = false;
        _s._providerPinned = false;
      }
      final next = _s._currentFallbackSourceIndex + 1;
      if (_s._currentSources != null && next < _s._currentSources!.length) {
        debugPrint(
          '[Player] Fatal error on source $_s._currentFallbackSourceIndex, trying $next...',
        );
        _initPlayback(sourceStartIndex: next);
        return;
      }
      if (!_s._providerPinned) {
        debugPrint(
          '[Player] Fatal error — no more sources, trying next provider...',
        );
        _autoFallbackToNextProvider();
        return;
      }
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
        _s._errorMessage = 'Playback failed on all sources.';
      });
    });

    _s._logSub = _s._player.stream.log.listen((l) {
      if (_s._disposed) return;
      _s._playbackRecovery?.handleMpvLog(l.text);
    });

    // Completion – could trigger next-episode logic here in the future
    _s._completedSub = _s._player.stream.completed.listen((completed) {
      if (_s._disposed || !completed) return;
      if (!_s._playbackConfirmed || _s._isInitPlaybackRunning) return;
      if (isNaturalPlaybackEnd(_s._player.state)) {
        debugPrint('✅ Playback completed');
        return;
      }
      final pos = _s._player.state.position.inMilliseconds;
      if (_s._sourcePinned || pos > 10000) return;
      final next = _s._currentFallbackSourceIndex + 1;
      if (_s._currentSources == null || next >= _s._currentSources!.length) return;
      debugPrint(
        '[Player] Abortive end at ${pos}ms on source '
        '${_s._currentFallbackSourceIndex + 1}/${_s._currentSources!.length} — trying next',
      );
      _s._playbackConfirmed = false;
      _initPlayback(sourceStartIndex: next);
    });

    _s._tracksSub = _s._player.stream.tracks.listen((tracks) {
      if (_s._disposed || _s._autoTracksAppliedForSource) return;
      final hasAudio = tracks.audio.any((t) => t.id != 'no' && t.id != 'auto');
      if (!hasAudio) return;
      _s._autoTracksAppliedForSource = true;
      Future.delayed(const Duration(milliseconds: 600), _applyTrackAutoSelect);
    });
  }

  Future<void> _applyTrackAutoSelect() async {
    if (_s._disposed || _s._audioPinned) return;
    try {
      final settings = SettingsService();
      final audioLang = await settings.getPreferredAudioLanguage();
      final avoidUnsupported = await settings.getAvoidUnsupportedAudio();

      final best = pickBestAudioTrack(
        audioTracks: _s._player.state.tracks.audio,
        preferredAudioLang: audioLang,
        avoidUnsupportedAudio: avoidUnsupported,
      );
      if (best == null) return;

      final current = _s._player.state.track.audio;
      if (current.id == best.id && current.id != 'auto' && current.id != 'no') {
        if (!_s._subtitlePinned) await _s._applyAutoSubtitle();
        return;
      }

      await _s._player.setAudioTrack(best);
      debugPrint(
        '[DesktopPlayer] auto audio → ${best.title ?? best.language ?? best.id}',
      );
      if (!_s._subtitlePinned) await _s._applyAutoSubtitle();
    } catch (e) {
      debugPrint('[DesktopPlayer] track auto-select failed: $e');
    }
  }

  Future<void> _recoverAudioTrack() async {
    if (_s._disposed || _s._audioPinned) return;
    try {
      _s._autoTracksAppliedForSource = false;
      await _applyTrackAutoSelect();
    } catch (e) {
      debugPrint('[DesktopPlayer] audio recovery failed: $e');
    }
  }

  /// Checks if [track] is an ASS/SSA or image-based subtitle (PGS/VobSub) and toggles mpv's
  /// `sub-visibility` accordingly. Native tracks render directly onto the video frame,
  /// so the custom Flutter overlay hides itself. For SRT/VTT, sub-visibility is turned off
  /// so only the Flutter overlay draws text.
  void _updateSubVisibility(SubtitleTrack track) {
    final codec = track.codec?.toLowerCase() ?? '';
    final isNativeCodec =
        codec.contains('ass') ||
        codec.contains('ssa') ||
        codec.contains('pgs') ||
        codec.contains('dvd') ||
        codec.contains('dvb') ||
        codec.contains('vobsub');
    // Also check the track title/id for .ass/.ssa extension (file picker)
    final title = (track.title ?? track.id).toLowerCase();
    final looksAss = title.endsWith('.ass') || title.endsWith('.ssa');
    final shouldUseNative = isNativeCodec || looksAss;

    if (shouldUseNative != _s._isNativeSubtitle) {
      setState(() => _s._isNativeSubtitle = shouldUseNative);
    }
    if (_s._player.platform is NativePlayer) {
      (_s._player.platform as NativePlayer).setProperty(
        'sub-visibility',
        shouldUseNative ? 'yes' : 'no',
      );
    }
  }

  Future<void> _configureMpvProperties() async {
    if (_s._player.platform is! NativePlayer) return;
    final mpv = _s._player.platform as NativePlayer;

    Future<void> safeSet(String key, String val) async {
      try {
        await mpv.setProperty(key, val);
      } catch (e) {
        debugPrint(
          '[Player] Warning: failed to set mpv property $key=$val: $e',
        );
      }
    }

    // ── Decoding ─────────────────────────────────────────────────────────
    // auto-safe: tries whitelisted GPU decoders, falls back gracefully.
    // This is the officially recommended hwdec mode by mpv developers.
    await safeSet('hwdec', _s._hwDecMode.mpvValue);

    // Zero-copy direct rendering from decoder to GPU texture when possible.
    // Reduces RAM usage and improves throughput, especially on 4K/HEVC.
    await safeSet('vd-lavc-dr', 'yes');

    // Let mpv pick the optimal thread count automatically (0 = auto).
    await safeSet('vd-lavc-threads', '0');

    // ── Audio Codec Fallback ──────────────────────────────────────────────
    // Continue playback even if audio codec is unsupported (e.g., TrueHD).
    // User can switch to alternate audio track from the menu.
    await safeSet('ad-lavc-downmix', 'no');
    await safeSet('audio-fallback-to-null', 'yes');

    // Disable built-in OSD / subtitle rendering – Flutter renders them.
    await safeSet('sub-visibility', 'no');
    await safeSet('sub-auto', 'all');

    // ── Video Sync & Smoothness ───────────────────────────────────────────
    // display-resample: syncs to the monitor's refresh rate, eliminates judder.
    // This is the best sync mode for desktop displays.
    await safeSet('video-sync', 'display-resample');

    // Temporal interpolation to smooth out frame pacing between display frames.
    // Significantly reduces judder on 24fps content on 60Hz+ monitors.
    await safeSet('interpolation', 'yes');
    await safeSet('tscale', 'oversample'); // lightweight interpolation

    // ── Network / Streaming ───────────────────────────────────────────────
    await safeSet('network-timeout', '30');
    await safeSet('tls-verify', 'no'); // for self-signed / CDN certs

    // Don't freeze on brief cache drain — keep decoding through HLS hiccups.
    await safeSet('cache-pause', 'no');
    await safeSet('cache-pause-initial', 'no');

    final isTorrent = widget.magnetLink != null;
    if (isTorrent) {
      // Torrent engine feeds bytes from disk as pieces complete — a small
      // forward window is enough and keeps memory pressure low.
      // Long network-timeout: first pieces can stall while peers connect.
      await safeSet('cache', 'yes');
      await safeSet('network-timeout', '60');
      await safeSet('demuxer-readahead-secs', '20');
      await safeSet('force-seekable', 'yes');
      await safeSet('hr-seek', 'yes');
      await safeSet('hr-seek-framedrop', 'no');
    } else {
      // Cache: 300 MB in memory, read 120 s ahead.
      // This dramatically reduces rebuffering on variable-bitrate streams.
      await safeSet('cache', 'yes');
      await safeSet('cache-secs', '120');
      await safeSet('demuxer-max-bytes', '300MiB');
      await safeSet('demuxer-readahead-secs', '120');

      // How far back the demuxer keeps decoded data (for backward seeks).
      await safeSet('demuxer-max-back-bytes', '50MiB');

      // Let mpv adapt HLS bitrate to network conditions (not locked to max).
      await safeSet('hls-bitrate', 'no');
    }

    // Prevent yt-dlp from being invoked (we supply our own URL).
    await safeSet('ytdl', 'no');

    // ── Volume ────────────────────────────────────────────────────────────
    // Allow boosting volume above 100% (up to 150%) for quiet sources.
    await safeSet('volume-max', '150');

    // ── External Audio Track ──────────────────────────────────────────────
    if (widget.audioUrl != null) {
      await safeSet('audio-file', widget.audioUrl!);
    }

    // ── HTTP Headers ──────────────────────────────────────────────────────
    if (widget.headers != null) {
      final referer = widget.headers!['Referer'] ?? widget.headers!['referer'];
      if (referer != null) await safeSet('referrer', referer);

      final ua = widget.headers!['User-Agent'] ?? widget.headers!['user-agent'];
      if (ua != null) await safeSet('user-agent', ua);
    }

    // ── Resume Position ──────────────────────────────────────────────────
    // Set mpv's native 'start' property so it begins playback at the saved
    // position. This is more reliable than seeking after open, because the
    // post-open seek can be silently dropped before the demuxer is fully
    // initialised.
    if (widget.startPosition != null && !_s._hasInitialSeek) {
      final secs = widget.startPosition!.inMilliseconds / 1000.0;
      await safeSet('start', '+${secs.toStringAsFixed(3)}');
    }
  }
}
