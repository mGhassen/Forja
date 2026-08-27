part of 'desktop_player_screen.dart';

mixin _DesktopPlayerLifecycle on ConsumerState<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

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
    _s._ownedProviderSourcesCache = ValueNotifier<Map<String, List<StreamSource>>>(
      {},
    );

    // ── Provider initialization ──────────────────────────────────────────
    _s._currentProvider = widget.activeProvider;
    _s._catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    _s._catalogSourceKind = _initialCatalogSourceKind();
    // Do not pin from pinSource / preloaded sources - that blocked Auto
    // failover after green Play. Prefs + explicit user picks set pins.
    unawaited(_s._loadPlayerAutoSettings());
    // Torrent / Stremio Direct: never seed the webstreaming sources list with
    // localhost stream URLs - that path skips them as "unplayable extracts"
    // and then fails pinned failover.
    final catalogSession = isCatalogSourcesMode(widget.activeProvider) ||
        (widget.magnetLink != null && widget.magnetLink!.isNotEmpty);
    // Catalog mode normally skips the webstreaming sources list — but green
    // Forja Play passes explicit failover URLs; keep those so open can hop.
    if (catalogSession &&
        (widget.sources == null || widget.sources!.isEmpty)) {
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
    // Episode-switch handoff set retain=true; take ownership after the outgoing
    // player has disposed (same frame) so we don't stop our own stream.
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
    // Seed catalog URL so pinSource sync starts on the chosen stream, not [0].
    if (widget.magnetLink == null || widget.magnetLink!.isEmpty) {
      _s._currentPlayingCatalogUrl = widget.mediaPath;
    }
    _s._activeMagnet = widget.magnetLink;
    if (_s._currentProvider == 'service111477' &&
        widget.sources != null &&
        widget.sources!.isNotEmpty) {
      final match = widget.sources!.indexWhere((s) => s.url == widget.mediaPath);
      _s._current111477FileUrl = match >= 0
          ? widget.sources![match].url
          : widget.sources!.first.url;
    }
    widget.sourcesListNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_s._onProbeScoringChanged);

    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    // Track desktop PiP state so we can hide all controls when active.
    _s._pipSub = PipService.instance.desktopPipChanges.listen((on) {
      if (!mounted) return;
      setState(() {
        _s._isPipMode = on;
        if (on) _s._pausedByLifecycle = false;
      });
      // Space-switch auto-PiP can race lifecycle pause — keep video alive.
      if (on && !_s._disposed && !_s._player.state.playing) {
        unawaited(_s._player.play());
      }
    });
    PipService.instance.bindAutoEnterOnDesktopSwitch(
      token: this,
      shouldEnter: () {
        if (_s._disposed || !mounted || !_s._playerReady) return false;
        return _s._player.state.playing || _s._pausedByLifecycle;
      },
    );

    _s._loadHeroMetadata();
    unawaited(_s._refreshAdjacentEpisodeFlags());

    HardwareKeyboard.instance.addHandler(_s._handleKeyEvent);
    unawaited(_createPlayer());
    _s._progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_s._disposed || !_s._isPlayingNotifier.value) return;
      unawaited(_saveWatchHistory(isBgPause: true));
    });
  }

  Future<void> _createPlayer() async {
    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    if (!mounted || _s._disposed) return;

    _s._player = MpvExclusiveSession.instance.trackPlayer(
      Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          libass: true,
          libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
          libassAndroidFontName: 'Roboto',
        ),
      ),
    );

    _s._controller = VideoController(
      _s._player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    if (!mounted || _s._disposed) {
      MpvExclusiveSession.instance.untrackPlayer(_s._player);
      final disposeFuture = _s._player.dispose();
      MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
      await disposeFuture;
      return;
    }

    _s._playerReady = true;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_s._playerReady) return;
      await waitForRouteTransition(context);
      if (!mounted || !_s._playerReady) return;
      await _s._loadPlayerAutoSettings();
      if (!mounted || !_s._playerReady) return;
      _s._loadSubtitlePrefs();
      _s._loadTorrentStatsPref();
      await _s._playableSourcesReady;
      if (!mounted || !_s._playerReady) return;
      _s._initPlayback();
      _s._onProbeScoringChanged();
      _s._startHideTimer();
      _s._fetchSubtitles();
      if (widget.movie != null && widget.hubEpisodes == null) {
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

  /// Session/disk cache when live [_s._currentSources] is empty (reopen same episode).
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

  /// Align panel rows + session cache with the URL mpv is actually playing.
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
    // Drop session junk, but keep known loopback play URLs out of the panel
    // by rewriting them to catalog identity below - never list proxy rows.
    sources.removeWhere((s) => isUnplayableCachedStreamUrl(s.url));
    sources = [
      for (final s in sources)
        if (isLocalLoopbackPlayUrl(s.url))
          StreamSource(
            url: durableStreamCatalogUrl(
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
    sources.removeWhere(
      (s) => s.url.isEmpty || isLocalLoopbackPlayUrl(s.url),
    );
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
    final nextCatalog = durableStreamCatalogUrl(
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
    unawaited(_persistWebstreamingCacheForCurrent());
    _s._markSourceActive(matchIdx);
    _s._notifySourceMenuChanged();
  }

  Future<void> _persistWebstreamingCacheForCurrent() async {
    final movie = widget.movie;
    if (movie == null || widget.magnetLink != null) return;
    final pid = _s._currentProvider ?? widget.activeProvider;
    if (pid == null || !isWebStreamProviderId(pid)) return;
    final sources = _s._effectiveCurrentSources
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

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Save progress when app goes to background or is paused
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveWatchHistory(isBgPause: true);
      _pauseForAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      if (!_s._disposed &&
          !_s._isPipMode &&
          !PipService.instance.isDesktopActive &&
          !PipService.instance.autoPipArmed &&
          !SettingsService.keepsPlayingInBackground &&
          _s._player.state.playing) {
        _s._pausedByLifecycle = true;
      }
      // macOS focus blur fires inactive often — save only; pause on paused/hidden.
      _saveWatchHistory(isBgPause: true);
    } else if (state == AppLifecycleState.resumed) {
      _s._historySaved = false;
      _resumeAfterAppBackground();
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
    if (_s._disposed ||
        _s._isPipMode ||
        PipService.instance.isDesktopActive) {
      return;
    }
    // Space / desktop switch: enter PiP instead of pausing (fluid).
    if (PipService.instance.autoPipArmed &&
        _s._playerReady &&
        (_s._player.state.playing || _s._pausedByLifecycle)) {
      unawaited(PipService.instance.enterInsteadOfPause());
      return;
    }
    if (SettingsService.keepsPlayingInBackground) return;
    if (_s._player.state.playing) {
      _s._pausedByLifecycle = true;
      unawaited(_s._player.pause());
    }
  }

  void _resumeAfterAppBackground() {
    if (_s._disposed || !_s._pausedByLifecycle) return;
    _s._pausedByLifecycle = false;
    if (_s._isPipMode || PipService.instance.isDesktopActive) return;
    unawaited(_s._player.play());
  }

  Future<void> _saveWatchHistory({bool isBgPause = false}) =>
      _persistWatchHistory(isBgPause: isBgPause);

  Future<void> _persistWatchHistory({bool isBgPause = false}) async {
    if (_s._historySaved && !isBgPause) return;
    final pos = _s._positionNotifier.value.inMilliseconds;
    final dur = _s._durationNotifier.value.inMilliseconds;

    // Nothing to save yet (open/buffering) - stay quiet; macOS fires
    // inactive/lifecycle often and used to spam this path.
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

    if (widget.onSaveProgress != null && pos > 5000) {
      await widget.onSaveProgress!(
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

    if (!usesHomeWatchHistory(
      movie: widget.movie,
      hubEpisodes: widget.hubEpisodes,
      onSaveProgress: widget.onSaveProgress,
      enginePlaySession: widget.enginePlaySession,
    )) {
      if (!isBgPause) _s._historySaved = true;
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
      await WatchHistoryService().saveProgress(
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
        unawaited(
          EpisodeWatchedService().markWatchedIfFinished(
            mediaId: widget.movie!.id,
            season: season,
            episode: episode,
            positionMs: pos,
            durationMs: dur,
          ),
        );
      }
      // Heartbeat / pause / lifecycle keep writing; only exit latches.
      if (!isBgPause) {
        _s._historySaved = true;
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
      // Extract animeId from the activeProvider or match by title
      // The most recent entry at index 0 is the currently playing anime
      // (addToWatchHistory inserts at 0 before playback starts)
      if (list.isNotEmpty) {
        final entry = jsonDecode(list[0]) as Map<String, dynamic>;
        entry['position'] = posMs;
        entry['duration'] = durMs;
        list[0] = jsonEncode(entry);
        prefs.setStringList('anime_watch_history', list);
      }
    });
  }
}
