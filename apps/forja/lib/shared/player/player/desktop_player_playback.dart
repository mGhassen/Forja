part of 'desktop_player_screen.dart';

mixin _DesktopPlayerPlayback
    on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
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
          dismissAfter: const Duration(milliseconds: 500),
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

        // Megaplay/nekostream PNG-wrapped TS — unwrap via local hls-proxy.
        if (animeHlsNeedsPngStripFor(
          openUrl,
          sourceKey: _s._currentProvider,
        )) {
          final stripped = await applyAnimePngStripIfNeeded(
            StreamSource(
              url: openUrl,
              title: source.title,
              type: source.type,
              headers: source.headers ?? widget.headers,
            ),
            sourceKey: _s._currentProvider,
          );
          if (stripped.url != openUrl) {
            openUrl = stripped.url;
            source = stripped;
            _s._currentSources![i] = stripped;
          }
        }

        // Fast-fail dead CDN/extract links for every provider before mpv open.
        // Local torrent/loopback is validated by demux, not HTTP probe.
        final catalogUrl = source.url;
        if (!widget.streamsPrevalidated &&
            !isLocalTorrentStreamUrl(catalogUrl) &&
            !isLocalTorrentStreamUrl(openUrl) &&
            !isLocalLoopbackPlayUrl(catalogUrl) &&
            !isLocalLoopbackPlayUrl(openUrl) &&
            widget.magnetLink == null) {
          final reachable = await validateStreamSourceForCheck(
            providerId: _s._currentProvider,
            source: source,
            headers: source.headers ?? widget.headers,
          );
          if (_fallbackAborted(runGen)) return false;
          if (!reachable) {
            debugPrint('[Player] Source $i failed reachability: $catalogUrl');
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
        }

        final srcHeaders = source.headers ?? widget.headers;
        await resetPlayerForOpen(_s._player);
        openUrl = await openPlayerStream(
          _s._player,
          url: openUrl,
          headers: srcHeaders,
          providerId: source.providerId ?? _s._currentProvider,
        );
        if (_fallbackAborted(runGen)) return false;
        _s._player.setVolume(_s._volumeNotifier.value);
        final opened = await waitForMediaOpen(
          _s._player,
          streamUrl: openUrl,
          timeout: isLocalTorrentStreamUrl(openUrl)
              ? const Duration(seconds: 45)
              : const Duration(seconds: 25),
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
        final decoded = await confirmOpenedStreamVideoDecode(
          _s._player,
          openUrl: openUrl,
          headers: srcHeaders,
          type: source.type,
        );
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
          final dur = _s._player.state.duration;
          final nearCredits =
              dur.inSeconds >= 90 &&
              seekAfterOpen >= dur - const Duration(seconds: 15);
          if (!nearCredits) {
            await _s._player.seek(seekAfterOpen);
            if (_fallbackAborted(runGen)) return false;
          }
          _s._hasInitialSeek = true;
        }
        _s._detectHlsQualities(openUrl, source.headers ?? widget.headers);
        setState(() {
          _s._currentUrl = openUrl;
          _s._currentPlayingCatalogUrl = source.url;
          _s._markPlaybackConfirmed(true);
        });
        _s._statusController.complete();
        _s._markSourceActive(i);
        _s._syncPanelAfterPlaybackConfirmed();
        unawaited(_s._recordStreamPlaySuccess(_s._currentProvider ?? ''));
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

  Future<void> _initPlayback({
    int sourceStartIndex = 0,
    bool resetEofSession = true,
  }) async {
    if (_s._disposed) return;
    if (_s._isInitPlaybackRunning) {
      return; // Prevent re-entrant calls during async extraction
    }
    _s._isInitPlaybackRunning = true;
    final initGen = _s._fallbackGen;
    if (resetEofSession) {
      _s._resetEofSessionGuards();
    }
    _s._markPlaybackConfirmed(false);

    try {
      setState(() {
        _s._hasError = false;
        _s._errorMessage = '';
        _s._showControls = true;
      });

      if (_s._currentSources != null &&
          _s._currentSources!.isNotEmpty &&
          !isCatalogSourcesMode(widget.activeProvider) &&
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
          seekAfterOpen: widget.startPosition,
        );
        if (played) return;
        if (_fallbackAborted(initGen)) return;

        if (_s._currentProvider != null &&
            (_s._currentSources?.isNotEmpty ?? false)) {
          _s._cacheProviderSources(_s._currentProvider!, _s._currentSources!);
          _s._markProviderLoadFailed(_s._currentProvider!);
        }

        // Anime owns reload: skip same-server pin re-extract — VidNest/Megaplay
        // often re-emit the same ad-poisoned nekostream URL. Walk Auto instead.
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
              '[Player] Cached $pid source failed — re-resolving fresh extract',
            );
            await _invalidateWebstreamingCacheForCurrent();
            final hit = await PlayerSourceResolve.resolvePinnedForMovie(
              movie: movie,
              providers: providers,
              providerId: pid,
              season: widget.selectedSeason ?? 1,
              episode: widget.hubEpisodeNumber?.toInt() ??
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
                  seekAfterOpen: widget.startPosition,
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
        // when Auto server is Off — otherwise a 1-URL session cache leaves an
        // empty Sources panel and no recovery (movie I43 host path).
        await _invalidateWebstreamingCacheForCurrent();

        final hostOwnsReload = widget.onReloadStreams != null;
        if (widget.streamsPrevalidated ||
            (_s._providerPinned && !hostOwnsReload)) {
          await _failPlaybackNoFailover(
            message: 'Playback failed. Pick another server from Sources.',
          );
        } else {
          final recovered = await _reresolveLikeFirstPlay(
            chainGen: initGen,
            seekAfterOpen: widget.startPosition,
          );
          if (!recovered && !_fallbackAborted(initGen)) {
            await _failPlaybackNoFailover(
              message: 'Could not find any working stream from any provider.',
            );
          }
        }
      } else {
        // No sources list — primary mediaPath (torrent localhost or direct URL).
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
                _s._errorMessage = 'Torrent stream failed to open.';
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
            isLocalTorrentStreamUrl(openUrl) || widget.magnetLink != null;
        int retryCount = 0;
        const maxRetries = 2;

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
            );
            if (_fallbackAborted(initGen)) return;
            _s._player.setVolume(_s._volumeNotifier.value);
            final opened = await waitForMediaOpen(
              _s._player,
              streamUrl: openedUrl,
              timeout: isTorrent
                  ? const Duration(seconds: 45)
                  : const Duration(seconds: 25),
            );
            if (_fallbackAborted(initGen)) return;
            if (!opened) {
              throw Exception('Failed to open media');
            }
            _s._detectHlsQualities(openedUrl, widget.headers);
            // Confirm first — duration events before this were dropped by the
            // stream listener. Do not block open waiting for duration: torrent
            // moov can arrive late; a long wait froze the loading transition.
            _s._markPlaybackConfirmed(true);
            syncPlayerProgressNotifiers(
              _s._player,
              duration: _s._durationNotifier,
              position: _s._positionNotifier,
              buffered: _s._bufferedNotifier,
            );
            final seekAfterOpen = widget.startPosition;
            if (seekAfterOpen != null && seekAfterOpen.inSeconds > 0) {
              final dur = _s._player.state.duration;
              final nearCredits = dur.inSeconds >= 90 &&
                  seekAfterOpen >= dur - const Duration(seconds: 15);
              if (!nearCredits && dur > Duration.zero) {
                await _s._player.seek(seekAfterOpen);
                if (_fallbackAborted(initGen)) return;
              }
              if (dur > Duration.zero) _s._hasInitialSeek = true;
            }
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

  Future<void> _invalidateWebstreamingCacheForCurrent() async {
    final movie = widget.movie;
    if (movie == null) return;
    final key = WebstreamingStreamCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.hubEpisodeNumber?.toInt() ?? widget.selectedEpisode,
    );
    await WebstreamingStreamCache.drop(key);
    if (_s._disposed) return;
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

  /// After sibling streams fail: full Auto resolve (same as first Play).
  Future<bool> _reresolveLikeFirstPlay({
    required int chainGen,
    Duration? seekAfterOpen,
  }) async {
    final movie = widget.movie;
    final providers = widget.providers;
    if (movie == null) return false;

    debugPrint('[Player] Dead sources — full Auto re-resolve like first Play');
    _s._statusController.upsert(
      'reresolve',
      'Finding servers…',
      kind: StatusRouletteKind.loading,
    );

    final episode = widget.hubEpisodeNumber?.toInt() ??
        widget.selectedEpisode ??
        1;
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
      // Anime: race embeds via providers without cancelAllPending first —
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
            _s._errorMessage = '';
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
        // Prefer a provider that already has these URLs cached from the race;
        // do not dump every stream under the dead current server.
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
          _s._errorMessage = '';
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
        _s._errorMessage = '';
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

  /// Stop on failure — no silent hop to the next provider.
  /// Used when the user pinned a server/stream (or Auto server is Off).
  Future<void> _failPlaybackNoFailover({required String message}) async {
    final pinned =
        _s._providerPinned || _s._sourcePinned || widget.pinSource;
    debugPrint(
      pinned
          ? '[Player] Playback failed — no auto failover (pinned)'
          : '[Player] Playback failed — recovery returned no playable streams',
    );
    if (!mounted || _s._disposed) return;
    final pid = _s._currentProvider;
    if (pid != null && pid.isNotEmpty) {
      _s._markProviderLoadFailed(pid);
    }
    _s._finalizeProbeStatusesAfterPlayback();
    // Terminal error owns the center chrome — drop "Finding servers…" etc.
    _s._statusController.clear();
    setState(() {
      _s._hasError = true;
      _s._showControls = true;
      _s._errorMessage = message;
    });
    await _invalidateWebstreamingCacheForCurrent();
  }

  Future<void> _autoFallbackToNextProvider() async {
    if (widget.providers == null || widget.providers!.isEmpty) {
      _s._statusController.clear();
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
      _s._finalizeProbeStatusesAfterPlayback();
      _s._statusController.clear();
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
        _s._errorMessage =
            'Could not find any working stream from any provider.';
      });
      _notifyAllSourcesExhausted();
      await _invalidateWebstreamingCacheForCurrent();
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
          episode: widget.hubEpisodeNumber?.toInt() ??
              widget.selectedEpisode ??
              1,
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

  bool _fallbackAborted(int chainGen) =>
      !mounted || _s._disposed || chainGen != _s._fallbackGen;

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
        if (_s._sourcePinned) return;
        final next = _s._currentFallbackSourceIndex + 1;
        if (_s._currentSources != null && next < _s._currentSources!.length) {
          unawaited(
            _initPlayback(sourceStartIndex: next, resetEofSession: false),
          );
        } else if (!_s._providerPinned) {
          unawaited(_autoFallbackToNextProvider());
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
      // Ignore ephemeral demux while hunting a playable source — otherwise the
      // seek bar flashes full/empty as each CDN briefly reports duration.
      if (!_s._playbackConfirmed) return;
      // keep-open EOF often emits position 0 after a real finish — don't empty
      // a seek bar that was already at the end.
      final shownDur = _s._durationNotifier.value;
      final shownPos = _s._positionNotifier.value;
      if (pos <= Duration.zero &&
          shownDur >= const Duration(seconds: 90) &&
          shownPos >= shownDur - const Duration(seconds: 2)) {
        return;
      }
      final openAge = openPlaybackAge(
        openConfirmedAt: _s._playbackConfirmedAt,
      );
      final effectiveDurMs = shownDur.inMilliseconds > 0
          ? shownDur.inMilliseconds
          : _s._player.state.duration.inMilliseconds;
      // Dead CDN: demux jumps to duration within the early-EOF grace — do not
      // paint a fake "finished" bar the user then cannot scrub off.
      // Use this-open age/mid only — session mid from a prior source must not
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

    // Duration – triggers auto-resume on first valid duration
    _s._durationSub = _s._player.stream.duration.listen((dur) {
      if (_s._disposed) return;
      if (!_s._playbackConfirmed) return;
      _s._durationNotifier.value = dur;
      if (!_s._hasInitialSeek &&
          dur.inSeconds >= 90 &&
          widget.startPosition != null) {
        final start = widget.startPosition!;
        // Don't seek into the credits — that looks like "started finished".
        if (start.inMilliseconds > 0 &&
            start < dur - const Duration(seconds: 15)) {
          _s._hasInitialSeek = true;
          _s._player.seek(start);
        } else {
          _s._hasInitialSeek = true;
        }
      }
    });

    // Buffered position – shows how far ahead is cached
    _s._bufferSub = _s._player.stream.buffer.listen((buf) {
      if (_s._disposed) return;
      if (!_s._playbackConfirmed) return;
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
        debugPrint('[Player] Ignoring open error — probe handles open failure');
        return;
      }
      _s._markPlaybackConfirmed(false);
      final idx = _s._currentFallbackSourceIndex;
      _s._markSourceFailed(idx);
      final pid = _s._currentProvider;
      if (pid != null && pid.isNotEmpty) {
        _s._markProviderLoadFailed(pid);
      }
      setState(() {
        _s._hasError = true;
        _s._showControls = true;
        _s._errorMessage = 'Playback failed. Pick another server from Sources.';
      });
      _s._statusController.clear();
      unawaited(_invalidateWebstreamingCacheForCurrent());
    });

    _s._logSub = _s._player.stream.log.listen((l) {
      if (_s._disposed) return;
      _s._playbackRecovery?.handleMpvLog(l.text);
    });

    // Completion – natural end may auto-play next episode; abortive end does not hop
    _s._completedSub = _s._player.stream.completed.listen((completed) {
      if (_s._disposed || !completed) return;
      if (!_s._playbackConfirmed || _s._isInitPlaybackRunning) return;
      if (_s._abortiveCompletedLatched) return;
      final openAge = openPlaybackAge(
        openConfirmedAt: _s._playbackConfirmedAt,
      );
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
        // 0/end — do not yank the bar back to EOF after the user left the end.
        if (!shouldPinSeekBarAtEof(
          uiPosition: _s._positionNotifier.value,
          duration: pinDur,
        )) {
          debugPrint(
            '[Player] Ignoring completed pin — UI already seeked away from EOF',
          );
          return;
        }
        debugPrint('✅ Playback completed');
        // keep-open may reset mpv position to 0 — pin the seek bar at EOF.
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
          setState(() => _s._showControls = true);
        }
        return;
      }
      _s._abortiveCompletedLatched = true;
      debugPrint(
        '[Player] Ignoring abortive completed '
        '(openFor=${openAge.inSeconds}s '
        'openMid=${_s._openHadMidPlayback} sessionMid=${_s._hadMidPlayback})',
      );
      // Failed / early EOF — never leave a pinned "finished" seek bar.
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
      if (mounted) setState(() => _s._showControls = true);
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

    // Stay on the last frame at EOF so the seek bar still works (scrub back /
    // replay). Without this, mpv goes idle and seeks no-op after completed.
    await safeSet('keep-open', 'yes');

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

      // Start HLS on the highest variant (same as IPTV). Manual Quality
      // menu still locks a specific rung by opening that playlist URL.
      await safeSet('hls-bitrate', 'max');
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
    // Always apply a browser UA before open; full header list goes on Media.
    final hdrs = resolvePlaybackHttpHeaders(
      widget.headers,
      streamUrl: widget.mediaPath,
      providerId: _s._currentProvider ??
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

    // Resume seeks happen after open (seekAfterOpen / duration listener) so we
    // can skip near-end positions. Do not set mpv `start` here — that jumps
    // into credits when history still has a false-finished near-end position.
  }
}
