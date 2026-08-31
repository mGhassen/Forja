part of 'mobile_player_screen.dart';

mixin _MobilePlayerLifecycle
    on ConsumerState<MobilePlayerScreen>, WidgetsBindingObserver {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  String? _initialCatalogSourceKind() {
    final base = widget.stremioAddonBaseUrl;
    if (base != null && base.startsWith('nuvio:')) return 'nuvio';
    if (base != null && base.startsWith('engine:')) return 'engine';
    // Local magnet session → Torrents tab (even if opened via Stremio/Torrentio).
    if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty) {
      return 'torrents';
    }
    final provider = widget.activeProvider;
    if (provider == 'torrent') return 'torrents';
    if (provider == 'stremio_direct') return 'stremio';
    if (provider != null && provider.startsWith('engine:')) return 'engine';
    return null;
  }

  @override
  void initState() {
    super.initState();
    PlayerBackExitGate.setTryFocusBack(() {
      if (!mounted || _s._disposed) return false;
      return PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: _s._showControls,
        armed: _s._tvBackExitArmed,
        hideChrome: () {
          _s._hideTimer?.cancel();
          setState(() => _s._showControls = false);
        },
        setArmed: (v) => _s._tvBackExitArmed = v,
      );
    });
    _s._ownedProviderSourcesCache =
        ValueNotifier<Map<String, List<StreamSource>>>({});

    // ── Provider initialization ──────────────────────────────────────────
    _s._currentProvider = widget.activeProvider;
    _s._catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    _s._catalogSourceKind = _initialCatalogSourceKind();
    // Do not pin from pinSource / preloaded sources - that blocked Auto
    // failover after green Play. Prefs + explicit user picks set pins.
    unawaited(_s._loadPlayerAutoSettings());
    final catalogSession =
        isCatalogSourcesMode(widget.activeProvider) ||
        (widget.magnetLink != null && widget.magnetLink!.isNotEmpty);
    // Catalog mode normally skips the webstreaming sources list — but green
    // Forja Play passes explicit failover URLs; keep those so open can hop.
    if (catalogSession && (widget.sources == null || widget.sources!.isEmpty)) {
      _s._currentSources = null;
    } else {
      _s._currentSources = widget.sources == null
          ? null
          : dedupeStreamSources(
              normalizeStreamSourcesPlayUrls(widget.sources!),
            );
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
    _s._currentUrl = normalizePlaybackStreamUrl(widget.mediaPath);
    if (widget.magnetLink == null || widget.magnetLink!.isEmpty) {
      _s._currentPlayingCatalogUrl = widget.mediaPath;
    }
    _s._activeMagnet = widget.magnetLink;
    if (_s._currentProvider == 'service111477' &&
        widget.sources != null &&
        widget.sources!.isNotEmpty) {
      final match = widget.sources!.indexWhere(
        (s) => s.url == widget.mediaPath,
      );
      _s._current111477FileUrl = match >= 0
          ? widget.sources![match].url
          : widget.sources!.first.url;
    }
    widget.sourcesListNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onProbeScoringChanged);
    if (widget.tvRemoteEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _s._claimPlayFocus());
    }

    // ── Lifecycle Observer ───────────────────────────────────────────────
    WidgetsBinding.instance.addObserver(_s);
    _s._progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_s._disposed || !_s._isPlayingNotifier.value) return;
      _s._saveWatchHistory(isBgPause: true);
    });
    playerChromeOnOverlayDismissed = () {
      if (mounted) _s._syncChromeHideTimer();
    };
    _s._statusController.addListener(_s._onPlayerStatusForChromeHide);

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
          // Lifecycle may have paused us before the PiP flag flipped — keep PiP alive.
          _s._pausedByLifecycle = false;
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
    // Orientation is set in addPostFrameCallback below - after the
    // first frame renders - to avoid fighting the portrait lock while
    // the widget tree is still building.
    WakelockPlus.enable();

    // Phone MediaKit: software-friendly decode (some MediaCodec paths flake).
    // ATV MediaKit: keep MediaCodec HW - Impeller is disabled in
    // ForjaApplication / MainActivity so the SurfaceProducer shows frames
    // (not audio-only).
    if (Platform.isAndroid &&
        !widget.tvRemoteEnabled &&
        !PlatformInfo.isAndroidTv) {
      _s._androidMediaKitSafeMode = true;
      _s._hwDecMode = _HwDecMode.software;
    }

    // ── Player ───────────────────────────────────────────────────────────
    // Track like IPTV/desktop so engine hot-swap can await MediaKit teardown
    // before Exo mounts (issue 129 zoomed crop after MediaKit → Exo).
    unawaited(MpvExclusiveSession.instance.prepareForVideoPlayer());
    _s._player = MpvExclusiveSession.instance.trackPlayer(
      Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          // Match VOD `demuxer-max-bytes=100MiB`. media_kit default is 32MB
          // and `cache-on-disk=yes` — both starve ATV HLS prefetch (issue 187).
          bufferSize: 100 * 1024 * 1024,
          // libass enabled so ASS/SSA subtitles render natively on the video.
          // For SRT/VTT we dynamically set sub-visibility=no so our custom
          // Flutter overlay still handles those.
          libass: true,
          // On Android, libass cannot access system fonts via fontconfig.
          // We must bundle a default font in assets and provide it here.
          libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
          libassAndroidFontName: 'Roboto',
        ),
      ),
    );

    // ATV: vo=gpu needs an EGL context - ATV emulators die with
    // EGL_BAD_ATTRIBUTE (audio OK, black frame). mediacodec_embed paints
    // MediaCodec straight into the Flutter Surface (no mpv GL). Same knobs
    // as IPTV [_IptvPtPlayerEngine._initPlayerInstances].
    final tvMediaKit = _s._tvMediaKit;
    _s._controller = VideoController(
      _s._player,
      configuration: VideoControllerConfiguration(
        vo: tvMediaKit ? 'mediacodec_embed' : null,
        enableHardwareAcceleration: tvMediaKit || !_s._androidMediaKitSafeMode,
        hwdec: tvMediaKit
            ? 'mediacodec'
            : (_s._androidMediaKitSafeMode ? 'no' : null),
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
        // MediaTek/Transsion devices need a longer wait - the
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
      // ScreenBrightness only works reliably on mobile - on desktop it
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
        unawaited(ListFollowFromWatched.markMovieWatchingOnPlay(widget.movie!));
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

    final key = PlayerStreamExtractCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    final hit = await PlayerStreamExtractCache.read(key);
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
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid != null && pid.isNotEmpty) {
      final fuller = preferFullerProviderSources(
        providerId: pid,
        live: _s._currentSources,
        cached: _s._liveProviderSourcesCache.value[pid],
      );
      if (fuller.isNotEmpty) return fuller;
    }
    if (_s._currentSources != null && _s._currentSources!.isNotEmpty) {
      return _s._currentSources;
    }
    return _s._currentSources;
  }

  /// Keeps extraction order - never promote the playing/checking row to front.
  void _refreshPanelPlayingStream() {
    if (!_s._playbackConfirmed) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    final playUrl = _s._currentUrl;
    if (pid == null || pid.isEmpty || playUrl == null || playUrl.isEmpty) {
      return;
    }
    // Catalog modes (Stremio Direct / Nuvio / torrent / Amri) use the Sources
    // right panel - never invent a one-row "server" list for the layers picker.
    if (isCatalogSourcesMode(pid)) return;

    final catalogUrl = durableStreamCatalogUrl(
      catalogUrl: _s._currentPlayingCatalogUrl,
      playUrl: playUrl,
    );
    final cached = _s._liveProviderSourcesCache.value[pid];
    var sources = List<StreamSource>.from(
      preferFullerProviderSources(
        providerId: pid,
        live: _s._currentSources,
        cached: cached,
      ),
    );
    sources.removeWhere((s) => isUnplayableCachedStreamUrl(s.url));
    sources = [
      for (final s in sources)
        if (isLocalLoopbackPlayUrl(s.url))
          StreamSource(
            url:
                durableStreamCatalogUrl(
                  catalogUrl: s.catalogUrl,
                  sourceUrl: s.url,
                  playUrl: s.url,
                ) ??
                s.url,
            title: s.title,
            type: s.type,
            headers: s.headers,
            providerId: s.providerId,
            catalogUrl: s.catalogUrl,
          )
        else
          s,
    ];
    sources.removeWhere((s) => s.url.isEmpty || isLocalLoopbackPlayUrl(s.url));
    sources = dedupeStreamSources(sources);

    var matchIdx = sources.indexWhere(
      (s) => streamSourceMatchesPlaying(
        s,
        playUrl: playUrl,
        catalogUrl: catalogUrl,
      ),
    );

    if (matchIdx < 0) {
      final identity = catalogUrl;
      if (identity == null || identity.isEmpty) return;
      final label = widget.providers != null
          ? PlayerProviderMenu.snackbarLabel(pid, widget.providers![pid])
          : StreamProviderDisplay.playerLabel(pid);
      final lower = identity.toLowerCase();
      final playingRow = StreamSource(
        url: identity,
        title: label,
        type: lower.contains('.m3u8')
            ? 'hls'
            : lower.contains('.mpd')
            ? 'dash'
            : 'mp4',
        headers: widget.headers,
        catalogUrl: identity,
      );
      // Append missing row - do not insert at front (panel order stays stable).
      sources = dedupeStreamSources([...sources, playingRow]);
      matchIdx = sources.indexWhere((s) => s.url == identity);
      if (matchIdx < 0) matchIdx = sources.isEmpty ? -1 : sources.length - 1;
    }
    if (matchIdx < 0 || matchIdx >= sources.length) return;

    final playingRow = sources[matchIdx];
    final nextCatalog =
        durableStreamCatalogUrl(
          catalogUrl: catalogUrl ?? playingRow.catalogUrl,
          sourceUrl: playingRow.url,
          playUrl: playUrl,
        ) ??
        playingRow.url;
    setState(() {
      _s._currentSources = sources;
      _s._currentPlayingCatalogUrl = nextCatalog;
      _s._currentFallbackSourceIndex = matchIdx;
    });
    _s._cacheProviderSources(pid, sources);
    unawaited(_persistPlayerStreamExtractCacheForCurrent());
    _s._markSourceActive(matchIdx);
    _s._notifySourceMenuChanged();
  }

  Future<void> _persistPlayerStreamExtractCacheForCurrent() async {
    final movie = widget.movie;
    if (movie == null || widget.magnetLink != null) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid == null || !isPlayerStreamExtractCacheProviderId(pid)) return;
    final sources = _s._effectiveCurrentSources
        ?.where((s) => !isUnplayableCachedStreamUrl(s.url))
        .toList();
    if (sources == null || sources.isEmpty) {
      return;
    }
    final key = PlayerStreamExtractCache.cacheKeyFromProgress(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    await PlayerStreamExtractCache.write(
      key,
      PlayerStreamExtractHit(providerId: pid, sources: sources),
    );
  }

  void _syncCurrentSourceIndexFromPlayUrl() {
    final sources = _s._currentSources;
    if (sources == null || sources.isEmpty) return;
    if (_s._currentProvider == 'service111477') {
      final fileUrl = _s._current111477FileUrl;
      if (fileUrl == null || fileUrl.isEmpty) return;
      final idx = sources.indexWhere((s) => s.url == fileUrl);
      if (idx >= 0) _s._currentFallbackSourceIndex = idx;
      return;
    }
    final idx = sources.indexWhere(
      (s) => streamSourceMatchesPlaying(
        s,
        playUrl: _s._currentUrl,
        catalogUrl: _s._currentPlayingCatalogUrl,
      ),
    );
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
            source.url == playUrl || source.url == _s._currentPlayingCatalogUrl,
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
    if (ShellTvFocusCoordinator.consumeOverlayBack()) {
      // Opener chrome button is refocused by playerMenuRestoreReturnFocus.
      return;
    }
    _s._exitInProgress = true;
    // Capture before awaits - flipping canPop / unmount must not skip dismiss.
    final nav = Navigator.of(context, rootNavigator: true);
    final result = _s._positionNotifier.value;
    _s._cancelPendingStreamWork();
    _saveWatchHistory();
    // Tell desktop LAN to stop before MediaKit teardown races the UI isolate.
    LanClientService.instance.releaseLanTorrentIfNeeded(
      playUrl: _s._currentUrl ?? widget.mediaPath,
      magnet: _s._activeMagnet ?? widget.magnetLink,
    );
    // Stop mpv before orientation/pop - dispose alone is fire-and-forget
    // and can leave audio after the route is gone (issue 059).
    await _s._stopPlaybackForExit();
    // Unmount MediaCodec surface before pop (issue 128) — ATV ANR otherwise.
    if (Platform.isAndroid && mounted && _s._showVideoSurface) {
      setState(() => _s._showVideoSurface = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!PlatformInfo.isAndroidTv) {
      // Unlock orientation so the rest of the app follows system settings.
      await SystemChrome.setPreferredOrientations([]);
      // Let the rotation finish before popping - avoids BLASTBufferQueue
      // errors from media_kit surface teardown during an active rotation.
      await Future.delayed(const Duration(milliseconds: 300));
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!mounted) {
      _popPlayerRoute(nav: nav, result: result);
      return;
    }
    _popPlayerRoute(nav: nav, result: result);
  }

  void _popPlayerRoute({NavigatorState? nav, Duration? result}) {
    final navigator =
        nav ?? (mounted ? Navigator.of(context, rootNavigator: true) : null);
    final popResult = result ?? _s._positionNotifier.value;
    // Strip loading under the player first — pop-then-dismiss paints resolve UI.
    // Keep canPop false for the whole session (desktop parity).
    dismissActiveLoadingOverlayRoute(navigator);
    if (navigator != null && navigator.mounted && navigator.canPop()) {
      navigator.pop(popResult);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Local progress only — pause scrobble fires from playing=false.
      _saveWatchHistory(isBgPause: true);
      // Stop audio when another app takes the screen (e.g. Netflix on ATV).
      // Skip PiP — that path is meant to keep playing (issue 134).
      _pauseForAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      // Capture play intent before focus/other apps pause us (inactive fires first).
      if (!_s._disposed &&
          !_s._isPipMode &&
          !SettingsService.keepsPlayingInBackground &&
          _s._player.state.playing) {
        _s._pausedByLifecycle = true;
      }
      // Phone control-center / brief blur: save progress only. Do not pause
      // here — `paused`/`hidden` cover real backgrounding.
      _saveWatchHistory(isBgPause: true);
    } else if (state == AppLifecycleState.resumed) {
      // Tell Trakt we're back
      _s._historySaved = false; // allow re-save on next exit
      _s._armDeadSurfaceCoverIfNeeded();
      _resumeAfterAppBackground();
      unawaited(_s._recoverPlaybackAfterForeground());
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

  void _pauseForAppBackground() {
    if (_s._disposed || _s._isPipMode) return;
    if (SettingsService.keepsPlayingInBackground) return;
    if (_s._player.state.playing) {
      _s._pausedByLifecycle = true;
      unawaited(_s._player.pause());
    }
  }

  void _resumeAfterAppBackground() {
    if (_s._disposed || !_s._pausedByLifecycle) return;
    _s._pausedByLifecycle = false;
    if (_s._isPipMode) return;
    unawaited(_s._player.play());
  }

  /// Veille kills mediacodec_embed; paused decode leaves green YUV. Cover until play.
  void _armDeadSurfaceCoverIfNeeded() {
    if (_s._disposed ||
        !PlatformInfo.isAndroidTv ||
        _s._pausedByLifecycle ||
        _s._player.state.playing) {
      return;
    }
    if (_s._coverDeadSurface) return;
    setState(() => _s._coverDeadSurface = true);
  }

  void _clearDeadSurfaceCover() {
    if (!_s._coverDeadSurface) return;
    if (mounted) {
      setState(() => _s._coverDeadSurface = false);
    } else {
      _s._coverDeadSurface = false;
    }
  }

  void _saveWatchHistory({bool isBgPause = false}) {
    if (_s._historySaved && !isBgPause) return; // prevent double stop
    final pos = _s._positionNotifier.value.inMilliseconds;
    final dur = _s._durationNotifier.value.inMilliseconds;

    // Nothing to save yet (open/buffering) - stay quiet.
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
    if (!isBgPause) _s._historySaved = true;

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

    if (widget.movie == null ||
        !usesHomeWatchHistory(
          movie: widget.movie,
          hubEpisodes: widget.hubEpisodes,
          onSaveProgress: widget.onSaveProgress,
          catalogPlaySession: widget.enginePlaySession,
        )) {
      return;
    }
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
      final season = widget.selectedSeason;
      final episode = widget.selectedEpisode;
      if (season != null && episode != null) {
        unawaited(() async {
          final marked = await EpisodeWatchedService().markWatchedIfFinished(
            mediaId: widget.movie!.id,
            season: season,
            episode: episode,
            positionMs: pos,
            durationMs: dur,
          );
          if (!marked) return;
          await ListFollowFromWatched.applyTmdbAfterAutoMark(
            movie: widget.movie!,
          );
        }());
      } else if (widget.movie!.mediaType == 'movie') {
        unawaited(
          ListFollowFromWatched.markMovieCompletedIfFinished(
            widget.movie!,
            positionMs: pos,
            durationMs: dur,
          ),
        );
      }

      if (!isBgPause) {
        final progressPercent = dur > 0 ? (pos / dur * 100) : 0.0;
        TraktService().scrobbleStop(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: progressPercent,
        );
        SimklService().scrobbleStop(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
      }
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
