part of 'mobile_player_screen.dart';

mixin _MobilePlayerLifecycle on State<MobilePlayerScreen>, WidgetsBindingObserver {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  String? _initialCatalogSourceKind() {
    final base = widget.stremioAddonBaseUrl;
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    // Local magnet session → Torrents tab (even if opened via Stremio/Torrentio).
    if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
      return 'torrents';
    }
    final provider = widget.activeProvider;
    if (provider == 'torrent') return 'torrents';
    if (provider == 'stremio_direct') return 'stremio';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _s._ownedProviderSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );

    // ── Provider initialization ──────────────────────────────────────────
    _s._currentProvider = widget.activeProvider;
    _s._catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    _s._catalogSourceKind = _initialCatalogSourceKind();
    // Do not pin from pinSource / preloaded sources — that blocked Auto
    // failover after green Play. Prefs + explicit user picks set pins.
    unawaited(_s._loadPlayerAutoSettings());
    final catalogSession = isCatalogSourcesMode(widget.activeProvider) ||
        (widget.magnetLink != null && widget.magnetLink!.isNotEmpty);
    if (catalogSession) {
      _s._currentSources = null;
    } else {
      _s._currentSources = widget.sources == null
          ? null
          : dedupeStreamSources(widget.sources!);
      if (_s._currentProvider != null &&
          _s._currentSources != null &&
          _s._currentSources!.isNotEmpty) {
        final pid = _s._currentProvider!;
        final valid = _s._currentSources!
            .where((s) => !isUnplayableCachedStreamUrl(s.url))
            .toList();
        if (valid.isNotEmpty) {
          final cache = _s._liveProviderSourcesCache.value;
          if (cache[pid]?.isEmpty ?? true) {
            _s._liveProviderSourcesCache.value = {...cache, pid: valid};
          }
          if (valid.length != _s._currentSources!.length) {
            _s._currentSources = valid;
          }
        } else {
          _s._currentSources = null;
        }
      }
    }
    if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TorrentStreamService().retainForExternalHandoff = false;
      });
    }
    unawaited(
      _s._playableSourcesReady = Future.wait([
        _initPlayableSources(),
        _hydrateSessionCacheFromDisk(),
      ]),
    );
    _s._currentUrl = widget.mediaPath;
    _s._activeMagnet = widget.magnetLink;
    if (_s._currentProvider == 'service111477' &&
        widget.sources != null &&
        widget.sources!.isNotEmpty) {
      _s._current111477FileUrl = widget.sources!.first.url;
    }
    widget.sourcesListNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onProbeScoringChanged);
    if (widget.tvRemoteEnabled) {
      _s._hwDecMode = _HwDecMode.software;
      WidgetsBinding.instance.addPostFrameCallback((_) => _s._claimPlayFocus());
    }

    // ── Lifecycle Observer ───────────────────────────────────────────────
    WidgetsBinding.instance.addObserver(_s);

    _s._loadHeroMetadata();
    unawaited(_s._refreshAdjacentEpisodeFlags());

    // ── PiP status listener (Android system PiP) ─────────────────────────
    // When entering PiP we hide all UI and force-resume playback if
    // currently paused. When leaving PiP we show controls again.
    _s._pipSub = PipService.instance.androidPipChanges.listen((inPip) {
      if (_s._disposed || !mounted) return;
      setState(() {
        _s._isPipMode = inPip;
        if (inPip) {
          _s._showControls = false;
          _s._hideTimer?.cancel();
        }
      });
      if (inPip) {
        // Auto-resume if paused so PiP isn't a static frame.
        if (!_s._player.state.playing) {
          _s._player.play();
        }
      }
    });

    // ── System UI ────────────────────────────────────────────────────────
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Orientation is set in addPostFrameCallback below — after the
    // first frame renders — to avoid fighting the portrait lock while
    // the widget tree is still building.
    WakelockPlus.enable();

    // Android MediaKit fallback: software-friendly decode (user chose MediaKit
    // over ExoPlayer in Settings).
    if (Platform.isAndroid) {
      _s._androidMediaKitSafeMode = true;
      _s._hwDecMode = _HwDecMode.software;
    }

    // ── Player ───────────────────────────────────────────────────────────
    _s._player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        // libass enabled so ASS/SSA subtitles render natively on the video.
        // For SRT/VTT we dynamically set sub-visibility=no so our custom
        // Flutter overlay still handles those.
        libass: true,
        // On Android, libass cannot access system fonts via fontconfig.
        // We must bundle a default font in assets and provide it here.
        libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // androidAttachSurfaceAfterVideoParameters: false fixes a blank-screen
    // race condition on some Android devices where the surface is attached
    // before mpv has negotiated video dimensions.
    // ATV emulators often lack a working GLES stack — HW decode + GPU
    // surface fails with EGL_BAD_ATTRIBUTE right after the first frame.
    _s._controller = VideoController(
      _s._player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration:
            !widget.tvRemoteEnabled && !_s._androidMediaKitSafeMode,
        hwdec: (widget.tvRemoteEnabled || _s._androidMediaKitSafeMode)
            ? 'no'
            : null,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );

    // ── Ripple animation ─────────────────────────────────────────────────
    _s._rippleController = AnimationController(
      vsync: _s,
      duration: const Duration(milliseconds: 420),
    );
    _s._rippleScale = Tween<double>(begin: 0.4, end: 1.6).animate(
      CurvedAnimation(parent: _s._rippleController, curve: Curves.easeOut),
    );
    _s._rippleOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _s._rippleController, curve: Curves.easeOut),
    );
    _s._rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _s._showRipple = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (Platform.isAndroid) {
        _s._isAndroidTv = await ExoPlayerBridge.isTelevision();
      }
      if (!mounted) return;
      await waitForRouteTransition(context);
      if (!mounted) return;
      if (!widget.tvRemoteEnabled && !_s._isAndroidTv) {
        // Lock to landscape and wait for the rotation to physically
        // complete before starting heavy media work.  Starting codec
        // initialization while the surface is still rotating causes
        // BLASTBufferQueue saturation and orientation ping-pong.
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
        ]);
        // Let Android finish the rotation & surface resize.
        // MediaTek/Transsion devices need a longer wait — the
        // fbcNotifyBufferUX storm can last several seconds.
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
      }

      _s._loadSubtitlePrefs();
      await _s._loadPlayerAutoSettings();
      if (!mounted) return;
      await _s._playableSourcesReady;
      if (!mounted) return;
      _s._initPlayback();
      _s._onProbeScoringChanged();
      _s._startHideTimer();
      _s._fetchSubtitles();
      // Initialize brightness from current screen level.
      // ScreenBrightness only works reliably on mobile — on desktop it
      // spams "Problem getting monitor brightness" errors because most
      // external monitors lack DDC/CI support.
      if (Platform.isAndroid || Platform.isIOS) {
        ScreenBrightness().application
            .then((b) {
              if (mounted) setState(() => _s._brightness = b);
            })
            .catchError((_) {
              ScreenBrightness().system
                  .then((b) {
                    if (mounted) setState(() => _s._brightness = b);
                  })
                  .catchError((_) {});
            });
      }
      // Trakt scrobble start
      if (widget.movie != null) {
        TraktService().scrobbleStart(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: 0,
        );
        SimklService().scrobbleStart(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
      }
      // Fetch skip segments from IntroDB
      _fetchIntroDbTimestamps();
    });
  }

  Future<void> _initPlayableSources() async {
    if (isCatalogSourcesMode(widget.activeProvider) ||
        (widget.magnetLink != null && widget.magnetLink!.isNotEmpty)) {
      return;
    }
    if (widget.sources == null || widget.sources!.isEmpty) return;
    final ranked = await PlayableSourceBridge.rankWidgetSources(
      sources: widget.sources,
      providerId: _s._currentProvider,
    );
    if (_s._disposed || !mounted) return;
    setState(() {
      _s._playableSources = ranked;
      _s._currentSources = playableSourcesToStreamSources(ranked);
      _syncCurrentSourceIndexFromPlayUrl();
    });
    _s._notifySourceMenuChanged();
  }

  Future<void> _hydrateSessionCacheFromDisk() async {
    if (widget.providerSourcesCache != null) return;
    final movie = widget.movie;
    if (movie == null) return;
    if (widget.magnetLink != null ||
        widget.activeProvider == 'stremio_direct' ||
        isCatalogSourcesMode(widget.activeProvider)) {
      return;
    }

    final key = WebstreamingStreamCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    final hit = await WebstreamingStreamCache.read(key);
    if (_s._disposed || !mounted || hit == null || hit.sources.isEmpty) return;

    final providerId = hit.providerId.isNotEmpty
        ? hit.providerId
        : (_s._currentProvider ?? widget.activeProvider);
    if (providerId == null || providerId.isEmpty) return;

    final sources = dedupeStreamSources(hit.sources);
    final cache = Map<String, List<StreamSource>>.from(
      _s._ownedProviderSourcesCache.value,
    );
    if (cache[providerId]?.isEmpty ?? true) {
      cache[providerId] = sources;
      _s._ownedProviderSourcesCache.value = cache;
    }

    final needsSources =
        _s._currentSources == null || _s._currentSources!.isEmpty;
    final needsProvider =
        _s._currentProvider == null || _s._currentProvider!.isEmpty;
    if (!needsSources && !needsProvider) return;

    if (!mounted) return;
    setState(() {
      if (needsProvider) _s._currentProvider = providerId;
      if (needsSources) {
        _s._currentSources = sources;
        _syncCurrentSourceIndexFromPlayUrl();
      }
    });
    _s._notifySourceMenuChanged();
  }

  List<StreamSource>? get _effectiveCurrentSources {
    if (_s._currentSources != null && _s._currentSources!.isNotEmpty) {
      return _s._currentSources;
    }
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid == null || pid.isEmpty) return _s._currentSources;
    final cached = _s._liveProviderSourcesCache.value[pid];
    if (cached != null && cached.isNotEmpty) return cached;
    return _s._currentSources;
  }

  void _refreshPanelPlayingStream() {
    if (!_s._playbackConfirmed) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    final playUrl = _s._currentUrl;
    if (pid == null || pid.isEmpty || playUrl == null || playUrl.isEmpty) {
      return;
    }
    // Catalog modes (Stremio Direct / Nuvio / torrent / Amri) use the Sources
    // right panel — never invent a one-row "server" list for the layers picker.
    if (isCatalogSourcesMode(pid)) return;

    final catalogUrl = _s._currentPlayingCatalogUrl;
    var sources = List<StreamSource>.from(
      _s._currentSources != null && _s._currentSources!.isNotEmpty
          ? _s._currentSources!
          : (_s._liveProviderSourcesCache.value[pid] ?? const <StreamSource>[]),
    );
    sources.removeWhere((s) => isUnplayableCachedStreamUrl(s.url));

    final matchIdx = sources.indexWhere(
      (s) =>
          s.url == playUrl ||
          (catalogUrl != null &&
              catalogUrl.isNotEmpty &&
              s.url == catalogUrl),
    );

    late final StreamSource playingRow;
    if (matchIdx >= 0) {
      playingRow = sources.removeAt(matchIdx);
    } else {
      final label = widget.providers != null
          ? PlayerProviderMenu.snackbarLabel(pid, widget.providers![pid])
          : StreamProviderDisplay.playerLabel(pid);
      final identity =
          (catalogUrl != null && catalogUrl.isNotEmpty) ? catalogUrl : playUrl;
      final lower = playUrl.toLowerCase();
      playingRow = StreamSource(
        url: identity,
        title: label,
        type: lower.contains('.m3u8')
            ? 'hls'
            : lower.contains('.mpd')
                ? 'dash'
                : 'mp4',
        headers: widget.headers,
      );
    }

    final deduped = dedupeStreamSources([playingRow, ...sources]);
    setState(() {
      _s._currentSources = deduped;
      _s._currentPlayingCatalogUrl = playingRow.url;
      _s._currentFallbackSourceIndex = 0;
    });
    _s._cacheProviderSources(pid, deduped);
    unawaited(_persistWebstreamingCacheForCurrent());
    _s._markSourceActive(0);
    _s._notifySourceMenuChanged();
  }

  Future<void> _persistWebstreamingCacheForCurrent() async {
    final movie = widget.movie;
    if (movie == null || widget.magnetLink != null) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid == null || !isWebStreamProviderId(pid)) return;
    final sources = _effectiveCurrentSources
        ?.where((s) => !isUnplayableCachedStreamUrl(s.url))
        .toList();
    if (sources == null || sources.isEmpty) {
      return;
    }
    final key = WebstreamingStreamCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    await WebstreamingStreamCache.write(
      key,
      WebstreamingCacheHit(providerId: pid, sources: sources),
    );
  }

  void _syncCurrentSourceIndexFromPlayUrl() {
    final sources = _s._currentSources;
    if (sources == null || sources.isEmpty) return;
    final catalogUrl = _s._currentPlayingCatalogUrl;
    if (catalogUrl != null && catalogUrl.isNotEmpty) {
      final catalogIdx = sources.indexWhere((s) => s.url == catalogUrl);
      if (catalogIdx >= 0) {
        _s._currentFallbackSourceIndex = catalogIdx;
        return;
      }
    }
    final playUrl = _s._currentUrl;
    if (playUrl == null || playUrl.isEmpty) return;
    if (_s._currentProvider == 'service111477') {
      final fileUrl = _s._current111477FileUrl;
      if (fileUrl == null || fileUrl.isEmpty) return;
      final idx = sources.indexWhere((s) => s.url == fileUrl);
      if (idx >= 0) _s._currentFallbackSourceIndex = idx;
      return;
    }
    final idx = sources.indexWhere((s) => s.url == playUrl);
    if (idx >= 0) {
      _s._currentFallbackSourceIndex = idx;
      return;
    }
    if (_s._currentFallbackSourceIndex < sources.length) return;
    _s._currentFallbackSourceIndex = 0;
  }

  String? _resolveStreamMenuProviderId() {
    var pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null && pid.isNotEmpty) return pid;
    if (!_s._playbackConfirmed) return pid;
    final playUrl = _s._currentUrl;
    if (playUrl == null || playUrl.isEmpty) return pid;
    final providers = widget.providers;
    if (providers == null || providers.isEmpty) return pid;

    final cache = _s._liveProviderSourcesCache.value;
    for (final key in providers.keys) {
      final cached = cache[key];
      if (cached == null) continue;
      if (cached.any(
        (source) =>
            source.url == playUrl ||
            source.url == _s._currentPlayingCatalogUrl,
      )) {
        return key;
      }
    }
    final live = _s._currentSources;
    if (live != null &&
        live.any(
          (source) =>
              source.url == playUrl ||
              source.url == _s._currentPlayingCatalogUrl,
        )) {
      return _s._currentProvider ?? widget.activeProvider;
    }
    return pid;
  }

  Future<void> _fetchIntroDbTimestamps() async {
    if (widget.movie == null) return;
    final data = await IntroDbService().getTimestamps(
      tmdbId: widget.movie!.id,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      imdbId: widget.movie!.imdbId,
    );
    if (mounted && data != null && data.hasAnySegments) {
      setState(() => _s._introDbData = data);
    }
  }

  /// Rotate back to portrait & restore system UI BEFORE popping,
  /// so the details page never sees stale landscape dimensions.
  Future<void> _exitPlayer() async {
    if (_s._exitInProgress) return;
    if (dismissAnyPlayerChromeOverlay()) {
      if (widget.tvRemoteEnabled) _s._claimPlayFocus();
      return;
    }
    _s._exitInProgress = true;
    _s._cancelPendingStreamWork();
    _saveWatchHistory();
    // Stop mpv before orientation/pop — dispose alone is fire-and-forget
    // and can leave audio after the route is gone (issue 059).
    await _s._stopPlaybackForExit();
    // Unlock orientation so the rest of the app follows system settings.
    await SystemChrome.setPreferredOrientations([]);
    // Let the rotation finish before popping — avoids BLASTBufferQueue
    // errors from media_kit surface teardown during an active rotation.
    await Future.delayed(const Duration(milliseconds: 300));
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    _popPlayerRoute();
  }

  void _popPlayerRoute() {
    if (!mounted) return;
    final result = _s._positionNotifier.value;
    final nav = Navigator.of(context, rootNavigator: true);
    if (_s._routePopAllowed) {
      if (nav.canPop()) nav.pop(result);
      return;
    }
    setState(() => _s._routePopAllowed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = Navigator.of(context, rootNavigator: true);
      if (n.canPop()) n.pop(result);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Save local history + send scrobblePause (not stop — user may return)
      _saveWatchHistory(isBgPause: true);
    } else if (state == AppLifecycleState.resumed) {
      // Tell Trakt we're back
      _s._historySaved = false; // allow re-save on next exit
      if (widget.movie != null && _s._isPlayingNotifier.value) {
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
      }
    }
  }

  void _saveWatchHistory({bool isBgPause = false}) {
    if (_s._historySaved && !isBgPause) return; // prevent double stop
    final pos = _s._positionNotifier.value.inMilliseconds;
    final dur = _s._durationNotifier.value.inMilliseconds;

    // Nothing to save yet (open/buffering) — stay quiet.
    if (pos <= 10000 || dur <= 0) return;

    if (!shouldPersistWatchProgress(
      positionMs: pos,
      durationMs: dur,
      confirmedAt: _s._playbackConfirmedAt,
      sessionFirstConfirmedAt: _s._sessionFirstConfirmedAt,
      hadMidPlayback: _s._hadMidPlayback,
    )) {
      debugPrint(
        '[WatchHistory] Skip early-EOF near-end progress '
        '(pos=${pos}ms dur=${dur}ms)',
      );
      return;
    }
    _s._historySaved = true;

    // External progress hook (anime / arabic flows persist their own
    // per-source history). Always fire while we have a real position so
    // the resume rail picks up where we left off.
    if (widget.onSaveProgress != null && pos > 5000) {
      widget.onSaveProgress!(
        Duration(milliseconds: pos),
        Duration(milliseconds: dur),
      );
    }

    // Save anime watch position
    if (widget.activeProvider != null &&
        widget.activeProvider!.startsWith('anime_') &&
        pos > 10000 &&
        dur > 0) {
      _saveAnimeWatchPosition(pos, dur);
    }

    if (widget.movie == null || widget.hubEpisodes != null) return;
    if (pos > 10000 && dur > 0) {
      final isTorrent = widget.magnetLink != null;
      final isStremioDirect = widget.activeProvider == 'stremio_direct';
      final String method;
      final String sourceId;
      if (isTorrent) {
        method = 'torrent';
        sourceId = widget.magnetLink!;
      } else if (isStremioDirect) {
        method = 'stremio_direct';
        sourceId = widget.mediaPath;
      } else if (widget.activeProvider == 'amri') {
        method = 'amri';
        sourceId = widget.mediaPath;
      } else {
        final liveProvider = _s._currentProvider ?? widget.activeProvider;
        if (liveProvider != null && liveProvider.isNotEmpty) {
          method = 'stream';
          sourceId = liveProvider;
        } else {
          method = 'amri';
          sourceId = widget.mediaPath;
        }
      }
      final resolvedStreamUrl = _s._currentUrl ?? widget.mediaPath;
      WatchHistoryService().saveProgress(
        tmdbId: widget.movie!.id,
        imdbId: widget.movie!.imdbId,
        title: _s._displayTitle,
        posterPath: widget.movie!.posterPath,
        backdropPath: widget.movie!.backdropPath,
        method: method,
        sourceId: sourceId,
        position: pos,
        duration: dur,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
        episodeTitle: widget.selectedEpisode != null
            ? 'Episode ${widget.selectedEpisode}'
            : null,
        magnetLink: widget.magnetLink,
        fileIndex: widget.fileIndex,
        streamUrl: isStremioDirect
            ? widget.mediaPath
            : (method == 'stream' ? resolvedStreamUrl : null),
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        stremioType: widget.movie!.mediaType == 'tv' ? 'series' : 'movie',
        mediaType: widget.movie!.mediaType,
      );

      // Trakt + Simkl scrobble — fire and forget
      final progressPercent = dur > 0 ? (pos / dur * 100) : 0.0;
      if (isBgPause) {
        // App backgrounded — pause, don't stop (user may return)
        TraktService().scrobblePause(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: progressPercent,
        );
      } else {
        TraktService().scrobbleStop(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: progressPercent,
        );
      }
      SimklService().scrobbleStop(
        tmdbId: widget.movie!.id,
        mediaType: widget.movie!.mediaType,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
    }
  }

  void _saveAnimeWatchPosition(int posMs, int durMs) {
    SharedPreferences.getInstance().then((prefs) {
      final list = prefs.getStringList('anime_watch_history') ?? [];
      for (int i = 0; i < list.length; i++) {
        final entry = jsonDecode(list[i]) as Map<String, dynamic>;
        // Match by title which contains the anime name + episode
        // The most recent entry (index 0) is the one currently playing
        if (i == 0) {
          entry['position'] = posMs;
          entry['duration'] = durMs;
          list[i] = jsonEncode(entry);
          prefs.setStringList('anime_watch_history', list);
          break;
        }
      }
    });
  }

}
