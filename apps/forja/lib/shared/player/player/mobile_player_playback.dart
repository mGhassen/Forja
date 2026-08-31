part of 'mobile_player_screen.dart';

mixin _MobilePlayerPlayback on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

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

      if (isUnplayableCachedStreamUrl(source.url) &&
          !isLocalTorrentStreamUrl(source.url) &&
          !isLocalLoopbackPlayUrl(source.url)) {
        debugPrint(
          '[Player] Skipping unplayable extract at index $i: ${source.url}',
        );
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

      try {
        _s._resetTrackAutoSelectForSource();
        _s._durationNotifier.value = Duration.zero;
        _s._positionNotifier.value = Duration.zero;
        _s._bufferedNotifier.value = Duration.zero;
        await _configureMpvProperties();
        final srcHeaders = source.headers ?? widget.headers;

        var openUrl = source.url;
        if (PlayableSourceBridge.requiresProxy(
          _s._playableSources,
          i,
          _s._currentProvider,
          streamUrl: source.url,
        )) {
          if (!site111477_proxy.is111477ProxyRunning ||
              _s._current111477FileUrl != source.url) {
            if (site111477_proxy.is111477ProxyRunning) {
              await site111477_proxy.stop111477Proxy();
            }
            final upstream = resolvePlaybackHttpHeaders(
              source.headers ?? widget.headers,
              streamUrl: source.url,
              providerId: source.providerId ?? _s._currentProvider,
            );
            openUrl = await site111477_proxy.start111477Proxy(
              source.url,
              headers: upstream,
            );
            _s._current111477FileUrl = source.url;
          } else {
            openUrl = site111477_proxy.site111477ProxyUrl!;
          }
        }

        // RFC-045 open pipeline (identity → classify → technique → observe).
        final useOpenPipeline =
            !PlayableSourceBridge.requiresProxy(
              _s._playableSources,
              i,
              _s._currentProvider,
              streamUrl: source.url,
            ) &&
            !isLocalTorrentStreamUrl(openUrl) &&
            widget.magnetLink == null;

        if (!useOpenPipeline) {
          final catalogUrl = source.url;
          if (!widget.streamsPrevalidated &&
              !isLocalTorrentStreamUrl(catalogUrl) &&
              !isLocalTorrentStreamUrl(openUrl) &&
              !isLocalLoopbackPlayUrl(catalogUrl) &&
              !isLocalLoopbackPlayUrl(openUrl)) {
            final reachable = await validateStreamSourceForCheck(
              providerId: source.providerId ?? _s._currentProvider,
              source: source,
              headers: srcHeaders,
            );
            if (_fallbackAborted(runGen)) return false;
            if (!reachable) {
              debugPrint('[Player] Source $i failed reachability: $catalogUrl');
              _s._statusController.upsert(
                'source-$i',
                source.title,
                kind: StatusRouletteKind.failed,
                dismissAfter: const Duration(milliseconds: 1200),
              );
              _s._markSourceFailed(i);
              unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
              _s._currentFallbackSourceIndex++;
              continue;
            }
          }

          await resetPlayerForOpen(_s._player);
          openUrl = await openPlayerStream(
            _s._player,
            url: openUrl,
            headers: srcHeaders,
            providerId: source.providerId ?? _s._currentProvider,
            startAt: seekAfterOpen,
          );
          if (_fallbackAborted(runGen)) return false;
          _s._player.setVolume(_s._mpvVolume);
          final opened = await waitForPlayerStreamOpen(
            _s._player,
            streamUrl: openUrl,
            headers: srcHeaders,
            providerId: source.providerId ?? _s._currentProvider,
          );
          if (_fallbackAborted(runGen)) return false;
          if (!opened) {
            debugPrint('[Player] Source $i failed to open: $openUrl');
            await _s._player.stop();
            _s._statusController.upsert(
              'source-$i',
              source.title,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(milliseconds: 1200),
            );
            _s._markSourceFailed(i);
            unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
            _s._currentFallbackSourceIndex++;
            continue;
          }
          final needsDurationGate = sourceRequiresSeekableDurationBeforeConfirm(
            openUrl,
            type: source.type,
          );
          final decoded = await confirmOpenedStreamVideoDecode(
            _s._player,
            openUrl: openUrl,
            headers: srcHeaders,
            type: source.type,
            providerId: source.providerId ?? _s._currentProvider,
          );
          if (_fallbackAborted(runGen)) return false;
          if (!decoded) {
            debugPrint('[Player] Source $i opened without video: $openUrl');
            await _s._player.stop();
            _s._statusController.upsert(
              'source-$i',
              source.title,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(milliseconds: 1200),
            );
            _s._markSourceFailed(i);
            unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
            _s._currentFallbackSourceIndex++;
            continue;
          }
          final hasDuration =
              !needsDurationGate ||
              await waitForSeekableDuration(
                _s._player,
                timeout: widget.tvRemoteEnabled
                    ? const Duration(seconds: 15)
                    : const Duration(seconds: 5),
              );
          if (_fallbackAborted(runGen)) return false;
          if (!hasDuration) {
            debugPrint('[Player] Source $i opened without duration: $openUrl');
            await _s._player.stop();
            _s._statusController.upsert(
              'source-$i',
              source.title,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(milliseconds: 1200),
            );
            _s._markSourceFailed(i);
            unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
            _s._currentFallbackSourceIndex++;
            continue;
          }
        } else {
          // RFC-045: pipeline owns identity + classify - no separate probe.
          final pid = source.providerId ?? _s._currentProvider;
          final catalogUrl = hlsProxyTargetUrl(source.url) ?? source.url;
          final hdrs = resolvePlaybackHttpHeaders(
            srcHeaders,
            streamUrl: catalogUrl,
            providerId: pid,
          );
          upsertStreamOpenStatus(
            _s._statusController,
            StreamOpenStatusStage.checking,
          );
          final pipeline = await StreamOpenPipeline.start(
            catalogUrl: catalogUrl,
            headers: hdrs,
            providerId: pid,
          );
          var branchOk = false;
          while (true) {
            if (_fallbackAborted(runGen)) return false;
            final step = await pipeline.next();
            if (step == null) break;

            upsertStreamOpenStatus(
              _s._statusController,
              StreamOpenStatusStage.preparing,
            );
            await resetPlayerForOpen(_s._player);
            openUrl = await openPlayerStream(
              _s._player,
              url: step.playUrl,
              headers: step.headers ?? hdrs,
              providerId: pid,
              startAt: seekAfterOpen,
            );
            if (_fallbackAborted(runGen)) return false;
            _s._player.setVolume(_s._mpvVolume);
            final opened = await waitForMediaOpen(
              _s._player,
              streamUrl: openUrl,
              timeout: const Duration(seconds: 25),
            );
            if (_fallbackAborted(runGen)) return false;
            if (!opened) {
              debugPrint('[OpenPipeline] open fail ${step.label}: $openUrl');
              await _s._player.stop();
              pipeline.report(StreamOpenStepResult.openFailed);
              continue;
            }
            final needsDurationGate =
                sourceRequiresSeekableDurationBeforeConfirm(
                  openUrl,
                  type: source.type,
                );
            final decoded = await confirmOpenedStreamVideoDecode(
              _s._player,
              openUrl: openUrl,
              headers: step.headers,
              type: source.type,
              providerId: source.providerId ?? _s._currentProvider,
            );
            if (_fallbackAborted(runGen)) return false;
            if (!decoded) {
              debugPrint('[OpenPipeline] decode fail ${step.label}: $openUrl');
              await _s._player.stop();
              pipeline.report(StreamOpenStepResult.decodeFailed);
              continue;
            }
            final hasDuration =
                !needsDurationGate ||
                await waitForSeekableDuration(
                  _s._player,
                  timeout: widget.tvRemoteEnabled
                      ? const Duration(seconds: 15)
                      : const Duration(seconds: 5),
                );
            if (_fallbackAborted(runGen)) return false;
            if (!hasDuration) {
              await _s._player.stop();
              pipeline.report(StreamOpenStepResult.decodeFailed);
              continue;
            }

            pipeline.report(StreamOpenStepResult.success);
            // Keep panel row on catalog URL - proxy is play-only (_currentUrl).
            branchOk = true;
            break;
          }
          if (!branchOk) {
            debugPrint('[OpenPipeline] all branches failed source $i');
            _s._statusController.upsert(
              kStreamOpenStatusId,
              'Stream failed',
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(milliseconds: 1200),
            );
            _s._statusController.upsert(
              'source-$i',
              source.title,
              kind: StatusRouletteKind.failed,
              dismissAfter: const Duration(milliseconds: 1200),
            );
            _s._markSourceFailed(i);
            unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
            _s._currentFallbackSourceIndex++;
            continue;
          }
        }

        syncPlayerProgressNotifiers(
          _s._player,
          duration: _s._durationNotifier,
          position: _s._positionNotifier,
          buffered: _s._bufferedNotifier,
        );
        if (seekAfterOpen != null && seekAfterOpen.inSeconds > 0) {
          await ensureOpenedNearPosition(_s._player, seekAfterOpen);
          if (_fallbackAborted(runGen)) return false;
          _s._hasInitialSeek = true;
        }
        _s._detectHlsQualities(
          catalogUrlForHlsQualities(
            catalogUrl: source.catalogUrl,
            sourceUrl: source.url,
            playUrl: openUrl,
          ),
          srcHeaders,
        );
        final catalogIdentity = durableStreamCatalogUrl(
          catalogUrl: source.catalogUrl,
          sourceUrl: source.url,
          playUrl: openUrl,
        );
        setState(() {
          _s._currentUrl = openUrl;
          _s._currentPlayingCatalogUrl = catalogIdentity ?? source.url;
          _s._markPlaybackConfirmed(true);
        });
        if (_s._durationNotifier.value <= Duration.zero &&
            sourceExpectsDuration(openUrl, type: source.type)) {
          await waitForSeekableDuration(
            _s._player,
            timeout: widget.tvRemoteEnabled
                ? const Duration(seconds: 15)
                : const Duration(seconds: 8),
          );
          if (_fallbackAborted(runGen)) return false;
          syncPlayerProgressNotifiers(
            _s._player,
            duration: _s._durationNotifier,
            position: _s._positionNotifier,
            buffered: _s._bufferedNotifier,
          );
        }
        _s._statusController.complete();
        _s._markSourceActive(i);
        _s._syncPanelAfterPlaybackConfirmed();
        unawaited(_s._recordStreamPlaySuccess(_s._currentProvider ?? ''));
        widget.onPlaybackStarted?.call();
        await _ensureTvPlaybackStarted();
        return true;
      } catch (e) {
        if (_fallbackAborted(runGen)) return false;
        debugPrint('[Player] Source $i catch error: $e');
        await _s._player.stop();
        _s._statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        _s._markSourceFailed(i);
        _s._currentFallbackSourceIndex++;
      }
    }
    return false;
  }

  Future<void> _ensureTvPlaybackStarted() async {
    if (!widget.tvRemoteEnabled || _s._disposed) return;
    if (_s._player.state.playing) return;
    try {
      await _s._player.play();
    } catch (e) {
      debugPrint('[Player] TV play() failed: $e');
    }
  }

  Future<void> _initPlayback({
    int sourceStartIndex = 0,
    bool resetEofSession = true,

    /// Mid-watch Auto / re-init: keep live playhead (else [widget.startPosition]).
    Duration? seekOverride,
  }) async {
    if (_s._disposed) return;
    if (_s._isInitPlaybackRunning) {
      return; // Prevent re-entrant calls during async extraction
    }
    _s._isInitPlaybackRunning = true;
    final initGen = _s._fallbackGen;
    final resumeAt = seekOverride ?? widget.startPosition;
    if (resetEofSession) {
      _s._resetEofSessionGuards();
    }
    _s._markPlaybackConfirmed(false);
    _s._statusController.clear();

    try {
      setState(() {
        _s._hasError = false;
        _s._showControls = true;
      });

      if (_s._currentSources != null &&
          _s._currentSources!.isNotEmpty &&
          (widget.magnetLink == null || widget.magnetLink!.isEmpty)) {
        _subscribeToStreams();
        var startIndex = sourceStartIndex;
        if (sourceStartIndex == 0 && widget.pinSource) {
          _s._syncCurrentSourceIndexFromPlayUrl();
          startIndex = _s._currentFallbackSourceIndex;
        }
        final played = await _trySourcesFromIndex(
          startIndex,
          chainGen: initGen,
          seekAfterOpen: resumeAt,
        );
        if (played) return;
        if (_fallbackAborted(initGen)) return;

        if (_s._currentProvider != null &&
            (_s._currentSources?.isNotEmpty ?? false)) {
          _s._cacheProviderSources(_s._currentProvider!, _s._currentSources!);
          _s._markProviderLoadFailed(_s._currentProvider!);
        }

        // Anime owns reload: skip same-server pin re-extract (poison CDN loop).
        final hostOwnsReloadEarly = widget.onReloadStreams != null;
        if (!hostOwnsReloadEarly &&
            (_s._providerPinned || _s._sourcePinned || widget.pinSource) &&
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
              '[Player] Cached $pid source failed - re-resolving fresh extract',
            );
            await _invalidatePlayerStreamExtractCacheForCurrent();
            final hit = await PlayerSourceResolve.resolvePinnedForMovie(
              movie: movie,
              providers: providers,
              providerId: pid,
              season: widget.selectedSeason ?? 1,
              episode:
                  widget.hubEpisodeNumber?.toInt() ??
                  widget.selectedEpisode ??
                  1,
              isCancelled: () => _fallbackAborted(initGen),
            );
            if (!_fallbackAborted(initGen) &&
                hit != null &&
                hit.streamSources.isNotEmpty) {
              final fresh = dedupeStreamSources(
                hit.streamSources,
              ).where((s) => !isUnplayableCachedStreamUrl(s.url)).toList();
              if (fresh.isEmpty) {
                _s._markProviderLoadFailed(pid);
              } else {
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
                  seekAfterOpen: resumeAt,
                );
                if (retryPlayed) return;
                if (_fallbackAborted(initGen)) return;
                _s._markProviderLoadFailed(pid);
              }
            }
          }
        }

        // Dead sources (often a stale disk cache): siblings already tried.
        // Drop cache, then either re-extract the pinned server or run a full
        // Auto race like green Play (score order from the top).
        // Anime / host reload callback: always re-resolve like first Play even
        // when Auto server is Off - otherwise a 1-URL session cache leaves an
        // empty Sources panel and no recovery (movie I43 host path).
        await _invalidatePlayerStreamExtractCacheForCurrent();

        final hostOwnsReload = widget.onReloadStreams != null;
        if (widget.streamsPrevalidated ||
            (_s._providerPinned && !hostOwnsReload)) {
          await _failPlaybackNoFailover(
            message: 'Playback failed. Open Sources and choose another stream.',
          );
        } else {
          final recovered = await _reresolveLikeFirstPlay(
            chainGen: initGen,
            seekAfterOpen: resumeAt,
          );
          if (!recovered && !_fallbackAborted(initGen)) {
            await _failPlaybackNoFailover(
              message: 'Could not find any working stream from any provider.',
            );
          }
        }
      } else {
        // No sources list - primary mediaPath (torrent localhost or direct URL).
        // Never hand a raw magnet to mpv (treated as a relative file under tmp).
        var openUrl = widget.mediaPath;
        if (isTorrentStreamUrl(openUrl)) {
          final magnet =
              (widget.magnetLink != null && widget.magnetLink!.isNotEmpty)
              ? widget.magnetLink!
              : openUrl;
          final settings = SettingsService();
          final playback = await resolveMagnetForPlayback(
            magnet: magnet,
            useDebrid: await settings.useDebridForStreams(),
            debridService: await settings.getDebridService(),
            localTorrentEngine:
                PlatformPlayback.capabilities.localTorrentEngine,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
            fileIdx: widget.fileIndex,
          );
          if (_fallbackAborted(initGen)) return;
          if (playback == null) {
            if (mounted) {
              setState(() {
                _s._hasError = true;
                _s._showControls = true;
              });
            }
            await _failPlaybackNoFailover(
              message: 'Torrent stream failed to open.',
            );
            return;
          }
          openUrl = playback.url;
          setState(() {
            _s._currentUrl = openUrl;
            _s._activeMagnet = magnet;
          });
        }
        final isTorrent =
            isLocalTorrentStreamUrl(openUrl) ||
            (widget.magnetLink != null && widget.magnetLink!.isNotEmpty);
        int retryCount = 0;
        final maxRetries = isTorrent ? 3 : 2;

        while (retryCount < maxRetries) {
          try {
            _subscribeToStreams();
            await _configureMpvProperties();
            await resetPlayerForOpen(_s._player);
            final openedUrl = await openPlayerStream(
              _s._player,
              url: openUrl,
              headers: widget.headers,
              providerId: _s._currentProvider,
              startAt: resumeAt,
            );
            if (_fallbackAborted(initGen)) return;
            _s._player.setVolume(_s._mpvVolume);
            final opened = await waitForPlayerStreamOpen(
              _s._player,
              streamUrl: openedUrl,
              headers: widget.headers,
              providerId: _s._currentProvider,
            );
            if (_fallbackAborted(initGen)) return;
            if (!opened) {
              throw Exception('Failed to open media');
            }
            _s._detectHlsQualities(openedUrl, widget.headers);
            // Confirm first - duration events before this were dropped by the
            // stream listener. Do not block open waiting for duration: torrent
            // moov can arrive late; a long wait froze the loading transition.
            _s._markPlaybackConfirmed(true);
            syncPlayerProgressNotifiers(
              _s._player,
              duration: _s._durationNotifier,
              position: _s._positionNotifier,
              buffered: _s._bufferedNotifier,
            );
            if (resumeAt != null && resumeAt.inSeconds > 0) {
              await ensureOpenedNearPosition(_s._player, resumeAt);
              if (_fallbackAborted(initGen)) return;
              _s._hasInitialSeek = true;
            }
            _s._syncPanelAfterPlaybackConfirmed();
            widget.onPlaybackStarted?.call();
            await _ensureTvPlaybackStarted();
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
                });
              }
              if (_s._providerPinned) {
                await _failPlaybackNoFailover(
                  message: isTorrent
                      ? 'Torrent stream failed to open.'
                      : 'Playback failed.',
                );
              } else {
                await _autoFallbackToNextProvider();
              }
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

  Future<void> _invalidatePlayerStreamExtractCacheForCurrent() async {
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
        _s._liveProviderSourcesCache.value,
      )..remove(pid);
      _s._liveProviderSourcesCache.value = next;
    }
    debugPrint('[Player] dropped stale player stream extract cache $key');
  }

  /// After sibling streams fail: full Auto resolve (same as first Play).
  Future<bool> _reresolveLikeFirstPlay({
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    final movie = widget.movie;
    final providers = widget.providers;
    if (movie == null) return false;

    debugPrint('[Player] Dead sources - full Auto re-resolve like first Play');
    _s._statusController.upsert(
      'reresolve',
      'Finding servers…',
      kind: StatusRouletteKind.loading,
    );

    final episode =
        widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1;
    final season = widget.selectedSeason ?? 1;
    final animeHost = movie.mediaType.toLowerCase() == 'anime';

    // Clear temporary pins so recovery can hop servers (Auto Off / pinSource
    // otherwise same-panel re-extract forever). Restore after the attempt.
    final restoreProviderPin = _s._providerPinned;
    final restoreSourcePin = _s._sourcePinned;
    if (animeHost || widget.onReloadStreams != null) {
      _s._providerPinned = false;
      _s._sourcePinned = false;
    }

    try {
      // Anime: race embeds via providers without cancelAllPending first -
      // cancel kills the Miruro WebView pipe and cold reload often returns empty.
      if (animeHost && providers != null && providers.isNotEmpty) {
        // Walk servers: first extract can be a valid master with PNG-ad media
        // (nekostream). Keep excluding dead providers until one plays.
        final remaining = Map<String, dynamic>.from(providers);
        while (remaining.isNotEmpty && !_fallbackAborted(chainGen)) {
          final hit = await PlayerSourceResolve.resolveAutoForMovie(
            movie: movie,
            providers: remaining,
            season: season,
            episode: episode,
            isCancelled: () => _fallbackAborted(chainGen),
            onProgress: (providerId, status) {
              if (_fallbackAborted(chainGen)) return;
              final label = PlayerProviderMenu.snackbarLabel(
                providerId,
                providers[providerId],
              );
              final kind = switch (status) {
                'success' => StatusRouletteKind.success,
                'failed' || 'skipped' => StatusRouletteKind.failed,
                _ => StatusRouletteKind.loading,
              };
              _s._statusController.upsert(
                'provider-$providerId',
                label,
                kind: kind,
              );
              _s._syncProbeStatus(providerId, switch (status) {
                'success' => StreamProviderProbeStatus.success,
                'failed' => StreamProviderProbeStatus.failed,
                'skipped' => StreamProviderProbeStatus.skippedOnTv,
                'trying' => StreamProviderProbeStatus.trying,
                _ => StreamProviderProbeStatus.pending,
              });
            },
            onHitsUpdated: (hits) {
              if (_fallbackAborted(chainGen)) return;
              _s._liveProviderSourcesCache.value = {
                ..._s._liveProviderSourcesCache.value,
                ...PlaybackEngine.hitsToProviderCache(hits),
              };
            },
          );
          if (_fallbackAborted(chainGen)) return false;
          if (hit == null || hit.streamSources.isEmpty) break;

          remaining.remove(hit.providerId);
          final fresh = dedupeStreamSources(
            hit.streamSources,
          ).where((s) => !isUnplayableCachedStreamUrl(s.url)).toList();
          if (fresh.isEmpty) {
            _s._markProviderLoadFailed(hit.providerId);
            continue;
          }
          _s._cacheProviderSources(hit.providerId, fresh);
          _s._markProviderLoadSucceeded(hit.providerId);
          setState(() {
            _s._currentProvider = hit.providerId;
            _s._currentSources = fresh;
            _s._currentUrl = hit.streamUrl;
            _s._currentPlayingCatalogUrl = fresh.first.url;
            _s._currentFallbackSourceIndex = 0;
            _s._failedSourceIndices.clear();
            _s._checkingSourceIndices.clear();
            _s._hasError = false;
          });
          final played = await _trySourcesFromIndex(
            0,
            chainGen: chainGen,
            seekAfterOpen: seekAfterOpen,
          );
          if (played) return true;
          _s._markProviderLoadFailed(hit.providerId);
        }
      }

      if (!animeHost) {
        PlaybackEngine.cancelAllPending();
      }

      // Host-owned reload (anime callback): full embed race as fallback.
      if (widget.onReloadStreams != null) {
        final fresh = await widget.onReloadStreams!();
        if (_fallbackAborted(chainGen)) return false;
        if (fresh == null || fresh.isEmpty) {
          _s._statusController.complete();
          return false;
        }
        final playable = dedupeStreamSources(
          fresh,
        ).where((s) => !isUnplayableCachedStreamUrl(s.url)).toList();
        if (playable.isEmpty) {
          _s._statusController.complete();
          return false;
        }
        String pid = '';
        for (final e in _s._liveProviderSourcesCache.value.entries) {
          if (e.value.any((s) => s.url == playable.first.url)) {
            pid = e.key;
            break;
          }
        }
        if (pid.isEmpty) {
          pid = _s._currentProvider ?? widget.activeProvider ?? '';
        }
        if (pid.isNotEmpty) {
          _s._cacheProviderSources(pid, playable);
          _s._markProviderLoadSucceeded(pid);
        }
        setState(() {
          if (pid.isNotEmpty) _s._currentProvider = pid;
          _s._currentSources = playable;
          _s._currentUrl = playable.first.url;
          _s._currentPlayingCatalogUrl = playable.first.url;
          _s._currentFallbackSourceIndex = 0;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._hasError = false;
        });
        return _trySourcesFromIndex(
          0,
          chainGen: chainGen,
          seekAfterOpen: seekAfterOpen,
        );
      }

      if (providers == null || providers.isEmpty) {
        _s._statusController.complete();
        return false;
      }

      final hit = await PlayerSourceResolve.resolveAutoForMovie(
        movie: movie,
        providers: providers,
        season: season,
        episode: episode,
        isCancelled: () => _fallbackAborted(chainGen),
        onProgress: (providerId, status) {
          if (_fallbackAborted(chainGen)) return;
          final label = PlayerProviderMenu.snackbarLabel(
            providerId,
            providers[providerId],
          );
          final kind = switch (status) {
            'success' => StatusRouletteKind.success,
            'failed' || 'skipped' => StatusRouletteKind.failed,
            _ => StatusRouletteKind.loading,
          };
          _s._statusController.upsert(
            'provider-$providerId',
            label,
            kind: kind,
          );
          _s._syncProbeStatus(providerId, switch (status) {
            'success' => StreamProviderProbeStatus.success,
            'failed' => StreamProviderProbeStatus.failed,
            'skipped' => StreamProviderProbeStatus.skippedOnTv,
            'trying' => StreamProviderProbeStatus.trying,
            _ => StreamProviderProbeStatus.pending,
          });
        },
        onHitsUpdated: (hits) {
          if (_fallbackAborted(chainGen)) return;
          _s._liveProviderSourcesCache.value = {
            ..._s._liveProviderSourcesCache.value,
            ...PlaybackEngine.hitsToProviderCache(hits),
          };
        },
      );

      if (_fallbackAborted(chainGen)) return false;
      if (hit == null || hit.streamSources.isEmpty) {
        _s._statusController.complete();
        return false;
      }

      final fresh = dedupeStreamSources(
        hit.streamSources,
      ).where((s) => !isUnplayableCachedStreamUrl(s.url)).toList();
      if (fresh.isEmpty) {
        _s._statusController.complete();
        return false;
      }

      _s._cacheProviderSources(hit.providerId, fresh);
      _s._markProviderLoadSucceeded(hit.providerId);
      setState(() {
        _s._currentProvider = hit.providerId;
        _s._currentSources = fresh;
        _s._currentUrl = hit.streamUrl;
        _s._currentPlayingCatalogUrl = fresh.first.url;
        _s._currentFallbackSourceIndex = 0;
        _s._failedSourceIndices.clear();
        _s._checkingSourceIndices.clear();
        _s._hasError = false;
      });
      return _trySourcesFromIndex(
        0,
        chainGen: chainGen,
        seekAfterOpen: seekAfterOpen,
      );
    } finally {
      if (animeHost || widget.onReloadStreams != null) {
        _s._providerPinned = restoreProviderPin;
        _s._sourcePinned = restoreSourcePin;
      }
    }
  }

  /// Mid-playback fatal error.
  /// Auto (not pinned): remaining siblings → full re-resolve like first Play,
  /// seeking back to the watch position. Pin / Auto Off: stop for Retry.
  Future<void> _showPlaybackFailureOnWatch({String? reason}) async {
    if (_s._hasError || _s._disposed || _s._isInitPlaybackRunning) return;

    final pinned = _s._providerPinned || _s._sourcePinned || widget.pinSource;
    final canAutoHop =
        !pinned &&
        !widget.streamsPrevalidated &&
        widget.movie != null &&
        ((widget.providers != null && widget.providers!.isNotEmpty) ||
            widget.onReloadStreams != null);

    if (!canAutoHop) {
      debugPrint(
        '[Player] Playback stopped during watch - no auto failover'
        '${pinned ? ' (pinned)' : ''}'
        '${reason != null ? ' ($reason)' : ''}',
      );
      _s._fallbackGen++;
      try {
        await _s._player.stop();
      } catch (_) {}
      _s._markPlaybackConfirmed(false);
      if (!mounted || _s._disposed) return;
      _s._finalizeProbeStatusesAfterPlayback();
      _s._statusController.upsert(
        'playback-failed',
        'Failed to stream',
        kind: StatusRouletteKind.failed,
      );
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
      });
      return;
    }

    final resumeAt = _s._positionNotifier.value;
    final failedIdx = _s._currentFallbackSourceIndex;
    final seek = resumeAt.inSeconds > 0 ? resumeAt : null;

    debugPrint(
      '[Player] Mid-watch failure - Auto hopping'
      '${reason != null ? ' ($reason)' : ''}'
      ' @${resumeAt.inSeconds}s',
    );
    _s._fallbackGen++;
    final chainGen = _s._fallbackGen;
    _s._isInitPlaybackRunning = true;
    _s._abortiveCompletedLatched = false;

    try {
      try {
        await _s._player.stop();
      } catch (_) {}
      _s._markPlaybackConfirmed(false);
      _s._markSourceFailed(failedIdx);
      unawaited(_s._recordStreamPlayFailure(_s._currentProvider ?? ''));
      if (!mounted || _s._disposed || _fallbackAborted(chainGen)) return;

      _s._statusController.upsert(
        'mid-watch-hop',
        'Finding another stream…',
        kind: StatusRouletteKind.loading,
      );
      setState(() {
        _s._hasError = false;
        _s._showControls = true;
      });

      final nextIdx = failedIdx + 1;
      if (_s._currentSources != null && nextIdx < _s._currentSources!.length) {
        final played = await _trySourcesFromIndex(
          nextIdx,
          chainGen: chainGen,
          seekAfterOpen: seek,
        );
        if (played) return;
        if (_fallbackAborted(chainGen)) return;
        if (_s._currentProvider != null) {
          _s._markProviderLoadFailed(_s._currentProvider!);
        }
      }

      await _invalidatePlayerStreamExtractCacheForCurrent();
      if (_fallbackAborted(chainGen)) return;

      final recovered = await _reresolveLikeFirstPlay(
        chainGen: chainGen,
        seekAfterOpen: seek,
      );
      if (!recovered && !_fallbackAborted(chainGen)) {
        await _failPlaybackNoFailover(
          message: 'Could not find any working stream from any provider.',
        );
      }
    } finally {
      _s._isInitPlaybackRunning = false;
    }
  }

  Future<void> _retryCurrentPlayback() async {
    final idx = _s._currentFallbackSourceIndex;
    _s._failedSourceIndices.remove(idx);
    await _invalidatePlayerStreamExtractCacheForCurrent();
    await _initPlayback(sourceStartIndex: idx);
  }

  /// Mid-watch fatal: remount same URL after connectivity returns, then hop / Retry.
  Future<void> _onMidWatchFatal(String err) async {
    if (_s._disposed || !mounted || _s._hasError) return;
    if (await _tryNetworkRemount(err)) return;
    await _showPlaybackFailureOnWatch(reason: err);
  }

  Future<bool> _tryNetworkRemount(String err) async {
    if (_s._disposed ||
        !mounted ||
        _s._networkRemountInFlight ||
        _s._isInitPlaybackRunning ||
        _s._hasError) {
      return false;
    }
    if (!shouldAttemptNetworkRemount(err)) return false;
    final url = _s._currentQualityUrl ?? _s._currentUrl;
    if (url == null ||
        isLocalTorrentStreamUrl(url) ||
        isLocalLoopbackPlayUrl(url)) {
      return false;
    }

    _s._networkRemountInFlight = true;
    final resumeAt = _s._positionNotifier.value;
    _s._statusController.upsert(
      'network-remount',
      'Reconnecting…',
      kind: StatusRouletteKind.loading,
    );
    debugPrint('[Player] Network remount @${resumeAt.inSeconds}s ($err)');
    try {
      final ok = await attemptNetworkPlaybackRemount(
        isCancelled: () => _s._disposed || !mounted || _s._hasError,
        remount: () =>
            _remountCurrentStreamAt(resumeAt, allowFallbackInit: false),
      );
      if (ok) {
        _s._statusController.complete();
        debugPrint('[Player] Network remount resumed');
        return true;
      }
      _s._statusController.remove('network-remount');
      return false;
    } finally {
      _s._networkRemountInFlight = false;
    }
  }

  /// Same URL reopen at [target] after post-seek silent freeze (issue 184).
  Future<bool> _remountCurrentStreamAt(
    Duration target, {
    bool allowFallbackInit = true,
  }) async {
    if (_s._disposed || !mounted || _s._isInitPlaybackRunning) return false;
    final url = _s._currentQualityUrl ?? _s._currentUrl;
    if (url == null ||
        isLocalTorrentStreamUrl(url) ||
        isLocalLoopbackPlayUrl(url)) {
      return false;
    }
    final playUrl = normalizePlaybackStreamUrl(url);
    final src =
        _s._currentSources != null &&
            _s._currentFallbackSourceIndex < _s._currentSources!.length
        ? _s._currentSources![_s._currentFallbackSourceIndex]
        : null;
    final pid = src?.providerId ?? _s._currentProvider;
    final headers = resolvePlaybackHttpHeaders(
      _s._hlsMasterHeaders ?? src?.headers ?? widget.headers,
      streamUrl: playUrl,
      providerId: pid,
    );
    _s._isInitPlaybackRunning = true;
    _s._statusController.upsert(
      'post-seek-remount',
      'Reconnecting…',
      kind: StatusRouletteKind.loading,
    );
    debugPrint(
      '[Player] Post-seek remount open @${target.inSeconds}s: $playUrl',
    );
    try {
      final ok = await remountPlayerStreamAtPosition(
        _s._player,
        url: playUrl,
        headers: headers,
        providerId: pid,
        seekTarget: target,
      );
      if (_s._disposed || !mounted) return false;
      if (ok) {
        _s._currentUrl = playUrl;
        _s._positionNotifier.value = target;
        _s._statusController.complete();
        debugPrint('[Player] Post-seek remount resumed @${target.inSeconds}s');
        return true;
      }
      debugPrint('[Player] Post-seek remount failed to resume: $url');
    } catch (e) {
      debugPrint('[Player] Post-seek remount error: $e');
    } finally {
      if (!_s._disposed) _s._isInitPlaybackRunning = false;
    }
    if (_s._disposed || !mounted) return false;
    _s._statusController.remove('post-seek-remount');
    if (!allowFallbackInit) return false;
    debugPrint(
      '[Player] Post-seek remount failed — reopening source @${target.inSeconds}s',
    );
    await _initPlayback(
      sourceStartIndex: _s._currentFallbackSourceIndex,
      resetEofSession: false,
      seekOverride: target,
    );
    if (_s._disposed || !mounted) return false;
    return remountPlaybackResumed(_s._player.state, target);
  }

  Future<void> _recoverPlaybackAfterForeground() async {
    if (_s._disposed || !_s._playbackConfirmed) return;
    final url = _s._currentQualityUrl ?? _s._currentUrl;
    if (url == null ||
        isLocalTorrentStreamUrl(url) ||
        isLocalLoopbackPlayUrl(url)) {
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 4));
    if (_s._disposed || !_s._playbackConfirmed) return;
    if (_s._networkRemountInFlight ||
        _s._isInitPlaybackRunning ||
        (_s._postSeekStall?.remountInFlight ?? false)) {
      return;
    }

    final pos = _s._positionNotifier.value;
    final dur = _s._durationNotifier.value;
    final state = _s._player.state;
    if (!foregroundResumePlaybackStalled(state: state, pos: pos, dur: dur)) {
      return;
    }

    debugPrint(
      '[Player] Foreground resume stalled @${pos.inSeconds}s '
      '(buffering=${state.buffering}) — remount',
    );
    await _remountCurrentStreamAt(pos, allowFallbackInit: false);
  }

  void _ensurePostSeekStallWatchdog() {
    _s._postSeekStall ??= PostSeekStallWatchdog(
      onRemount: _remountCurrentStreamAt,
    );
  }

  /// Stop on failure - no silent hop to the next provider.
  /// Used when the user pinned a server/stream (or Auto server is Off).
  Future<void> _failPlaybackNoFailover({required String message}) async {
    final pinned = _s._providerPinned || _s._sourcePinned || widget.pinSource;
    debugPrint(
      pinned
          ? '[Player] Playback failed - no auto failover (pinned)'
          : '[Player] Playback failed - recovery returned no playable streams',
    );
    if (!mounted || _s._disposed) return;
    final pid = _s._currentProvider;
    if (pid != null && pid.isNotEmpty) {
      _s._markProviderLoadFailed(pid);
    }
    _s._finalizeProbeStatusesAfterPlayback();
    _s._statusController.upsert(
      'playback-failed',
      'Failed to stream',
      kind: StatusRouletteKind.failed,
    );
    setState(() {
      _s._hasError = true;
      _s._showControls = true;
    });
    await _invalidatePlayerStreamExtractCacheForCurrent();
  }

  Future<void> _autoFallbackToNextProvider() async {
    if (widget.providers == null || widget.providers!.isEmpty) {
      _s._statusController.upsert(
        'playback-failed',
        'Failed to stream',
        kind: StatusRouletteKind.failed,
      );
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
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
      _s._finalizeProbeStatusesAfterPlayback();
      _s._statusController.upsert(
        'playback-failed',
        'Failed to stream',
        kind: StatusRouletteKind.failed,
      );
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
      });
      _notifyAllSourcesExhausted();
      await _invalidatePlayerStreamExtractCacheForCurrent();
    }
  }

  void _notifyAllSourcesExhausted() {
    if (widget.onAllSourcesExhausted == null ||
        _s._allSourcesExhaustedNotified) {
      return;
    }
    _s._allSourcesExhaustedNotified = true;
    widget.onAllSourcesExhausted!();
  }

  /// Switches provider without showing full error UI on failure, returns success.
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
          episode:
              widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode ?? 1,
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
            ? dedupeStreamSources(
                sources,
              ).where((s) => !isUnplayableCachedStreamUrl(s.url)).toList()
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
                  providerId: newProvider,
                  catalogUrl: streamUrl,
                ),
              ];
        if (resolvedSources.isEmpty) {
          _s._markProviderLoadFailed(newProvider);
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

        _s._cacheProviderSources(newProvider, resolvedSources);
        _s._scoreServerUp(newProvider);

        setState(() {
          _s._currentProvider = newProvider;
          _s._currentSources = resolvedSources;
          _s._currentFallbackSourceIndex = 0;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
          _s._hasError = false;
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

  bool _fallbackAborted(int chainGen) =>
      !mounted || _s._disposed || chainGen != _s._fallbackGen;

  void _subscribeToStreams() {
    // Cancel any existing subscriptions to prevent duplicate listeners
    _s._positionSub?.cancel();
    _s._durationSub?.cancel();
    _s._bufferSub?.cancel();
    _s._cacheAheadPoll?.cancel();
    _s._cacheAheadPoll = null;
    _s._playingSub?.cancel();
    _s._bufferingSub?.cancel();
    _s._errorSub?.cancel();
    _s._completedSub?.cancel();
    _s._tracksSub?.cancel();
    _s._logSub?.cancel();
    _s._resetTrackAutoSelectForSource();
    _ensurePostSeekStallWatchdog();

    if (widget.builtInEngine == BuiltInPlayerEngine.mediaKit) {
      _s._playbackRecovery = PlaybackRecovery(
        player: _s._player,
        onPlaybackFailed: () {
          if (_s._disposed || !mounted || _s._isInitPlaybackRunning) return;
          unawaited(_showPlaybackFailureOnWatch());
        },
        onForceSoftwareDecode: () async {
          if (_s._player.platform is! NativePlayer) return;
          await (_s._player.platform as NativePlayer).setProperty(
            'hwdec',
            'no',
          );
        },
        onRecoverAudio: _recoverAudioTrack,
      );
    }

    _s._positionSub = _s._player.stream.position.listen((pos) {
      if (_s._disposed) return;
      // Ignore ephemeral demux while hunting a playable source - otherwise the
      // seek bar flashes full/empty as each CDN briefly reports duration.
      if (!_s._playbackConfirmed) return;
      // keep-open EOF often emits position 0 after a real finish - don't empty
      // a seek bar that was already at the end.
      final shownDur = _s._durationNotifier.value;
      final shownPos = _s._positionNotifier.value;
      if (pos <= Duration.zero &&
          shownDur >= const Duration(seconds: 90) &&
          shownPos >= shownDur - const Duration(seconds: 2)) {
        return;
      }
      final openAge = openPlaybackAge(openConfirmedAt: _s._playbackConfirmedAt);
      final effectiveDurMs = shownDur.inMilliseconds > 0
          ? shownDur.inMilliseconds
          : _s._player.state.duration.inMilliseconds;
      // Dead CDN: demux jumps to duration within the early-EOF grace - do not
      // paint a fake "finished" bar the user then cannot scrub off.
      // Use this-open age/mid only - session mid from a prior source must not
      // disable suppress on a fresh fail-open.
      if (shouldSuppressEarlyEofSeekBarPosition(
        positionMs: pos.inMilliseconds,
        durationMs: effectiveDurMs,
        confirmedFor: openAge,
        hadMidPlayback: _s._openHadMidPlayback,
      )) {
        return;
      }
      if (shouldIgnoreStaleEofPosition(
        reported: pos,
        duration: shownDur.inMilliseconds > 0
            ? shownDur
            : _s._player.state.duration,
        uiPosition: shownPos,
        seekAwayFromEofAt: _s._seekAwayFromEofAt,
      )) {
        return;
      }
      _s._positionNotifier.value = pos;
      _s._postSeekStall?.onPosition(pos);

      final dur = _s._durationNotifier.value;
      if (isMidEpisodePlayback(pos.inMilliseconds, dur.inMilliseconds)) {
        if (!_s._openHadMidPlayback) _s._openHadMidPlayback = true;
        if (!_s._hadMidPlayback) {
          _s._hadMidPlayback = true;
          _s._abortiveCompletedLatched = false;
        }
      }

      // Near-end detection for next episode button (clears if seeked back /
      // duration corrects after a bogus early report).
      if (_s._isNextEpisodeAvailable) {
        final nearEnd = isNearEndOfEpisode(pos, _s._durationNotifier.value);
        if (nearEnd != _s._nearEndOfEpisode) {
          setState(() => _s._nearEndOfEpisode = nearEnd);
        }
      } else if (_s._nearEndOfEpisode) {
        setState(() => _s._nearEndOfEpisode = false);
      }

      // Skip segment detection (IntroDB)
      _s._updateActiveSkipSegment(pos);
    });

    _s._durationSub = _s._player.stream.duration.listen((dur) {
      if (_s._disposed) return;
      if (!_s._playbackConfirmed) return;
      _s._durationNotifier.value = dur;
      if (!_s._hasInitialSeek &&
          dur.inSeconds >= 90 &&
          widget.startPosition != null) {
        final target = widget.startPosition!;
        // Don't seek into the credits - that looks like "started finished".
        if (target.inMilliseconds <= 0 ||
            target >= dur - const Duration(seconds: 15)) {
          _s._hasInitialSeek = true;
          return;
        }
        _s._hasInitialSeek = true;
        // mpv 'start' property handles the initial seek natively (set in
        // _configureMpvProperties). Fire a deferred seek as a safety net in
        // case the property was ignored (e.g. live streams, non-seekable src).
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_s._disposed || !_s._playbackConfirmed) return;
          final currentPos = _s._positionNotifier.value;
          if ((currentPos - target).abs() > const Duration(seconds: 5)) {
            _s._player.seek(target);
          }
        });
      }
    });

    _s._bufferSub = _s._player.stream.buffer.listen((buf) {
      if (_s._disposed) return;
      if (!_s._playbackConfirmed) return;
      _applyBufferedEnd(cacheTime: buf);
    });
    _s._cacheAheadPoll?.cancel();
    _s._cacheAheadPoll = Timer.periodic(const Duration(milliseconds: 750), (_) {
      unawaited(_sampleDemuxerCacheAhead());
    });

    _s._playingSub = _s._player.stream.playing.listen((playing) {
      if (_s._disposed) return;
      _s._isPlayingNotifier.value = playing;
      _s._postSeekStall?.onPlaying(playing);
      if (playing) {
        _s._clearDeadSurfaceCover();
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
        // Do not force chrome on pause — Space / media keys keep chrome hidden;
        // paused hero still shows via _isPlayingNotifier.
        _s._saveWatchHistory(isBgPause: true);
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

    _s._bufferingSub = _s._player.stream.buffering.listen((buffering) {
      if (_s._disposed) return;
      _s._isBufferingNotifier.value = buffering;
      _s._postSeekStall?.onBuffering(buffering);
    });

    // Surface only fatal errors - transient network blips are handled by mpv
    _s._errorSub = _s._player.stream.error.listen((err) {
      if (_s._disposed || err.isEmpty) return;
      final currentUrl =
          _s._currentSources != null &&
              _s._currentFallbackSourceIndex < _s._currentSources!.length
          ? _s._currentSources![_s._currentFallbackSourceIndex].url
          : null;
      if (isVideoDecoderError(err)) {
        debugPrint('🔴 [MobilePlayer] video decoder error: $err');
        _s._playbackRecovery?.handlePlayerError(err, currentUrl: currentUrl);
        return;
      }
      if (isIgnorablePlayerError(err)) {
        if (err.toLowerCase().contains('subtitle') ||
            err.toLowerCase().contains('sub-add')) {
          debugPrint('🟡 [MobilePlayer] sub error (ignored): $err');
        }
        return;
      }

      debugPrint('🔴 [MobilePlayer] $err');

      if (!isFatalPlayerOpenError(err)) return;
      if (_s._hasError) return;
      if (_s._isInitPlaybackRunning) {
        if (_s._networkRemountInFlight) {
          debugPrint('[Player] Open failed during network remount ($err)');
          return;
        }
        // Drop stale extract during probe only — retry uses fresh extract.
        unawaited(_invalidatePlayerStreamExtractCacheForCurrent());
        debugPrint('[Player] Open failed during probe - hopping ($err)');
        return;
      }
      unawaited(_onMidWatchFatal(err));
    });

    _s._logSub = _s._player.stream.log.listen((l) {
      if (_s._disposed) return;
      _s._playbackRecovery?.handleMpvLog(l.text);
    });

    _s._completedSub = _s._player.stream.completed.listen((completed) {
      if (_s._disposed || !completed) return;
      if (!_s._playbackConfirmed || _s._isInitPlaybackRunning) return;
      if (_s._abortiveCompletedLatched) return;
      final openAge = openPlaybackAge(openConfirmedAt: _s._playbackConfirmedAt);
      final dur = _s._player.state.duration;
      final pinDur = dur > Duration.zero ? dur : _s._durationNotifier.value;
      if (shouldAcceptNaturalPlaybackEnd(
        state: _s._player.state,
        openConfirmedFor: openAge,
        openHadMidPlayback: _s._openHadMidPlayback,
        sessionHadMidPlayback: _s._hadMidPlayback,
        uiPosition: _s._positionNotifier.value,
        uiDuration: pinDur,
      )) {
        // Scrub-back race: keep-open re-emits completed while mpv pos is still
        // 0/end - do not yank the bar back to EOF after the user left the end.
        if (!shouldPinSeekBarAtEof(
          uiPosition: _s._positionNotifier.value,
          duration: pinDur,
        )) {
          debugPrint(
            '[Player] Ignoring completed pin - UI already seeked away from EOF',
          );
          return;
        }
        debugPrint('✅ Playback completed');
        // keep-open may reset mpv position to 0 - pin the seek bar at EOF.
        if (pinDur > Duration.zero) {
          _s._durationNotifier.value = pinDur;
          _s._positionNotifier.value = pinDur;
        }
        final autoNext = SettingsService.autoNextEpisodeNotifier.value;
        if (autoNext &&
            !_s._loopEnabled &&
            _s._isNextEpisodeAvailable &&
            !_s._isLoadingNextEp) {
          unawaited(_s._nextEpisode());
        } else if (mounted) {
          _s._revealChrome();
        }
        return;
      }
      _s._abortiveCompletedLatched = true;
      debugPrint(
        '[Player] Ignoring abortive completed '
        '(openFor=${openAge.inSeconds}s '
        'openMid=${_s._openHadMidPlayback} sessionMid=${_s._hadMidPlayback})',
      );
      // Failed / early EOF - never leave a pinned "finished" seek bar.
      if (shouldPinSeekBarAtEof(
            uiPosition: _s._positionNotifier.value,
            duration: pinDur,
          ) ||
          shouldPinSeekBarAtEof(
            uiPosition: _s._player.state.position,
            duration: pinDur,
          ) ||
          !_s._openHadMidPlayback) {
        _s._positionNotifier.value = Duration.zero;
      }
      // Abortive early end - stop; do not hop to the next source.
      if (mounted) _s._revealChrome();
    });

    _s._tracksSub = _s._player.stream.tracks.listen((tracks) {
      if (_s._disposed) return;
      final audioCount = concreteAudioTracks(tracks.audio).length;
      if (audioCount == 0 || _s._userPickedAudioThisSource) {
        _scheduleEmbeddedSubtitleAuto(tracks);
        return;
      }
      if (audioCount > _s._lastAutoSelectAudioCount) {
        _s._lastAutoSelectAudioCount = audioCount;
        _s._trackAutoSelectTimer?.cancel();
        final delayMs = audioCount > 1 ? 400 : 100;
        _s._trackAutoSelectTimer = Timer(Duration(milliseconds: delayMs), () {
          _s._trackAutoSelectTimer = null;
          unawaited(_applyTrackAutoSelect());
        });
      }
      _scheduleEmbeddedSubtitleAuto(tracks);
    });
  }

  void _scheduleEmbeddedSubtitleAuto(Tracks tracks) {
    if (_s._disposed ||
        _s._embeddedSubtitleAutoApplied ||
        _s._userPickedExternalSubtitle) {
      return;
    }
    if (embeddedSubtitleTracks(tracks.subtitle).isEmpty) return;
    _s._embeddedSubtitleAutoTimer?.cancel();
    _s._embeddedSubtitleAutoTimer = Timer(
      const Duration(milliseconds: 200),
      () {
        _s._embeddedSubtitleAutoTimer = null;
        if (_s._disposed ||
            _s._embeddedSubtitleAutoApplied ||
            _s._userPickedExternalSubtitle) {
          return;
        }
        unawaited(_applyLateEmbeddedSubtitle());
      },
    );
  }

  Future<void> _applyLateEmbeddedSubtitle() async {
    if (_s._disposed || !mounted) return;
    await _s._applyAutoSubtitle();
  }

  Future<void> _applyTrackAutoSelect() async {
    if (_s._disposed || !mounted || _s._userPickedAudioThisSource) return;
    try {
      await applyPreferredPlayerAudioTrack(
        _s._player,
        audioPinned: _s._audioPinned,
      );
      if (_s._disposed || !mounted) return;
      final active = await resolveActiveAudioTrack(_s._player);
      if (active != null) {
        debugPrint(
          '[Player] auto audio → ${active.title ?? active.language ?? active.id}',
        );
      }
      await _s._reapplyPreferredSubtitle();
    } catch (e) {
      debugPrint('[Player] track auto-select failed: $e');
    }
  }

  Future<void> _recoverAudioTrack() async {
    if (_s._disposed || _s._audioPinned) return;
    try {
      _s._resetTrackAutoSelectForSource();
      await _applyTrackAutoSelect();
    } catch (e) {
      debugPrint('[Player] audio recovery failed: $e');
    }
  }

  /// Checks if [track] is an ASS/SSA or image-based subtitle (PGS/VobSub) and toggles mpv's
  /// `sub-visibility` accordingly. Native tracks render directly onto the video frame,
  /// so the custom Flutter overlay hides itself. For SRT/VTT, sub-visibility is turned off
  /// so only the Flutter overlay draws text.
  void _updateSubVisibility(SubtitleTrack track) {
    if (_s._disposed || !mounted) return;
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

  void _applyBufferedEnd({
    Duration cacheTime = Duration.zero,
    double? aheadSecs,
  }) {
    if (_s._disposed || !_s._playbackConfirmed) return;
    final pos = _s._positionNotifier.value;
    final end = bufferedEndFromCacheAhead(
      position: pos,
      duration: _s._durationNotifier.value,
      aheadSecs: aheadSecs ?? 0,
      cacheTime: cacheTime,
    );
    if (end == null || end <= pos) {
      if (_s._bufferedNotifier.value < pos) {
        _s._bufferedNotifier.value = pos;
      }
      return;
    }
    _s._bufferedNotifier.value = end;
  }

  Future<void> _sampleDemuxerCacheAhead() async {
    if (_s._disposed || !_s._playbackConfirmed || _s._cacheAheadProbeInFlight) {
      return;
    }
    final platform = _s._player.platform;
    if (platform is! NativePlayer) return;
    _s._cacheAheadProbeInFlight = true;
    try {
      final raw = await platform.getProperty('demuxer-cache-duration');
      final ahead = double.tryParse(raw.toString());
      if (ahead == null) return;
      _applyBufferedEnd(cacheTime: _s._player.state.buffer, aheadSecs: ahead);
    } catch (_) {
    } finally {
      _s._cacheAheadProbeInFlight = false;
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
    // Phone safe-mode: hwdec=no. ATV: keep mediacodec (matches VideoController
    // vo=mediacodec_embed - do not overwrite with auto-safe/software).
    final tvMediaKit = _s._tvMediaKit;
    if (tvMediaKit) {
      await safeSet('hwdec', 'mediacodec');
    } else {
      await safeSet('hwdec', _s._hwDecMode.mpvValue);
    }
    final phoneSafeMode = _s._androidMediaKitSafeMode && !tvMediaKit;
    await safeSet('vd-lavc-dr', phoneSafeMode ? 'no' : 'yes');
    if (Platform.isAndroid && (tvMediaKit || phoneSafeMode)) {
      // OpenSLES misconfigures on some ATV images (0 frames delivered).
      await safeSet('ao', 'audiotrack');
    }

    // Auto thread count (0 = let mpv decide). On mobile 4–8 cores typical.
    await safeSet('vd-lavc-threads', '0');

    // ── Audio Codec Fallback ──────────────────────────────────────────────
    // Continue playback even if audio codec is unsupported (e.g., TrueHD).
    // User can switch to alternate audio track from the menu.
    await safeSet('ad-lavc-downmix', 'no');
    await safeSet('audio-fallback-to-null', 'yes');

    // Flutter renders subtitles - kill mpv's own OSD overlay.
    await safeSet('sub-visibility', 'no');
    await safeSet('sub-auto', 'all');

    // ── Video Sync ────────────────────────────────────────────────────────
    // On mobile we use audio sync (not display-resample).
    // display-resample requires a stable vsync signal from the display driver
    // which is unreliable on Android and drains battery unnecessarily.
    // audio sync gives smooth playback tied to the audio clock instead.
    await safeSet('video-sync', 'audio');

    // ── Network / Cache ───────────────────────────────────────────────────
    await safeSet('network-timeout', '30');
    await safeSet('tls-verify', 'no');

    // RAM packet cache. media_kit defaults cache-on-disk=yes; on ATV that
    // prunes metadata and never builds an HLS ahead window (issue 187).
    await safeSet('cache-on-disk', 'no');
    await safeSet('cache-pause', 'yes');
    await safeSet('cache-pause-wait', '3');
    await safeSet('cache-pause-initial', 'yes');

    // Stay on the last frame at EOF so the seek bar still works (scrub back /
    // replay). Without this, mpv goes idle and seeks no-op after completed.
    await safeSet('keep-open', 'yes');

    final isTorrent =
        (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) ||
        isLocalTorrentStreamUrl(widget.mediaPath);
    if (isTorrent) {
      // Seekable HTTP Range (librqbit prioritizes pieces). Cap lavf probe so
      // open prefers the already-fetched head instead of scanning the whole
      // file; do NOT set seekable=0 — that permanently breaks scrub.
      await safeSet('cache', 'yes');
      await safeSet('network-timeout', '120');
      await safeSet('demuxer-readahead-secs', '20');
      await safeSet('demuxer-lavf-probesize', '65536');
      await safeSet('demuxer-lavf-analyzeduration', '0.5');
      await safeSet('force-seekable', 'yes');
      await safeSet('hr-seek', 'yes');
      await safeSet('hr-seek-framedrop', 'no');
    } else {
      // Sliding RAM window (cache-secs wins over readahead). Pause-to-refill
      // is set above so HLS underruns BUFFER instead of stuttering.
      await safeSet('cache', 'yes');
      await safeSet('cache-secs', '45');
      await safeSet('demuxer-max-bytes', '100MiB');
      await safeSet('demuxer-readahead-secs', '20');

      // 30 MiB back-buffer so backward seeks don't require a full rebuffer.
      await safeSet('demuxer-max-back-bytes', '30MiB');

      // Cap from Settings → Max stream quality (Auto = soft ~5 Mbps).
      final maxH = await SettingsService().getMaxPlaybackHeight();
      await safeSet('hls-bitrate', hlsBitrateForMaxPlaybackHeight(maxH));

      // Brief socket blips — remount path covers longer offline (issue 205).
      await safeSet(
        'stream-lavf-o',
        'reconnect=1,'
            'reconnect_at_eof=1,'
            'reconnect_streamed=1,'
            'reconnect_delay_max=15,'
            'reconnect_on_network_error=1,'
            'reconnect_on_http_error=4xx\\,5xx',
      );
    }

    // We supply our own URL - no yt-dlp needed.
    await safeSet('ytdl', 'no');

    // Allow volume boosting up to 150% for quiet sources. TV MediaKit needs
    // room for [kAtvMediaKitVolumeGain] on top of that (150 × 1.3 = 195).
    await safeSet('volume-max', tvMediaKit ? '200' : '150');

    // ── External Audio ────────────────────────────────────────────────────
    if (widget.audioUrl != null) {
      await safeSet('audio-file', widget.audioUrl!);
    } else {
      await safeSet('audio-file', '');
    }

    // ── HTTP Headers ──────────────────────────────────────────────────────
    // Always apply a browser UA before open; full header list goes on Media.
    final hdrs = resolvePlaybackHttpHeaders(
      widget.headers,
      streamUrl: widget.mediaPath,
      providerId:
          _s._currentProvider ??
          (_s._currentSources?.isNotEmpty == true
              ? _s._currentSources!.first.providerId
              : null),
    );
    await applyMediaHttpHeaders(
      _s._player,
      hdrs,
      streamUrl: widget.mediaPath,
      alreadyResolved: true,
    );

    // Resume uses mpv `start` on open (see openPlayerStream.startAt) so HLS
    // does not play 0:00 then fail a late Range seek. Near-end history is
    // already filtered to Duration.zero by resumeStartPositionFromProgress.
  }
}
