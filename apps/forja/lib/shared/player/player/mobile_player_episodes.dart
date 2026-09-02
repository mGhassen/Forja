part of 'mobile_player_screen.dart';

mixin _MobilePlayerEpisodes on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  // ─────────────────────────────────────────────────────────────────────────
  //  MISC
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleLoop() {
    setState(() => _s._loopEnabled = !_s._loopEnabled);
    _s._player.setPlaylistMode(
      _s._loopEnabled ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SKIP SEGMENTS (IntroDB)
  // ─────────────────────────────────────────────────────────────────────────

  void _updateActiveSkipSegment(Duration pos) {
    if (_s._introDbData == null) return;

    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    for (final seg in _s._introDbData!.recap) {
      final s = seg.startMs ?? 0;
      final e = seg.endMs;
      if (e != null && posMs >= s && posMs < e) {
        label = 'Skip Recap';
        target = Duration(milliseconds: e);
        break;
      }
    }
    if (label == null) {
      for (final seg in _s._introDbData!.intro) {
        final s = seg.startMs ?? 0;
        final e = seg.endMs;
        if (e != null && posMs >= s && posMs < e) {
          label = 'Skip Intro';
          target = Duration(milliseconds: e);
          break;
        }
      }
    }
    if (label == null) {
      for (final seg in _s._introDbData!.credits) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _s._durationNotifier.value.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Credits';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }
    if (label == null) {
      for (final seg in _s._introDbData!.preview) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _s._durationNotifier.value.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Preview';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }

    if (label != _s._activeSkipLabel) {
      setState(() {
        _s._activeSkipLabel = label;
        _s._activeSkipTarget = target;
        _s._skipDismissed = false;
      });
      final skipAuto = SettingsService.autoSkipIntroNotifier.value;
      if (skipAuto &&
          (label == 'Skip Intro' || label == 'Skip Recap') &&
          target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _s._disposed) return;
          if (_s._activeSkipLabel != label) return;
          _performSkip();
        });
      }
    }
  }

  void _performSkip() {
    if (_s._activeSkipTarget == null) return;
    unawaited(_s._seekTo(_s._activeSkipTarget!));
    setState(() {
      _s._activeSkipLabel = null;
      _s._activeSkipTarget = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NEXT EPISODE
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isNextEpisodeAvailable =>
      (widget.onNextEpisode != null && widget.hasNextEpisode) ||
      (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty) ||
      (widget.movie != null &&
          _isSeriesMediaType(widget.movie!.mediaType) &&
          widget.selectedSeason != null &&
          widget.selectedEpisode != null) ||
      (widget.enginePlaySession?.isHubFlatList == true &&
          widget.selectedEpisode != null);

  bool _isSeriesMediaType(String? mediaType) {
    final m = (mediaType ?? '').toLowerCase();
    return m == 'tv' ||
        m == 'anime' ||
        m == 'asian_drama' ||
        m == 'drama' ||
        m == 'series';
  }

  bool get _showNextEpButton =>
      _isNextEpisodeAvailable &&
      _s._nearEndOfEpisode &&
      !_s._isLoadingNextEp;

  bool get _showSkipChip =>
      _s._activeSkipLabel != null && !_s._skipDismissed;

  /// Progress bar ↑: Next Episode (closest) → Skip → top Back.
  void _focusUpFromSeekbar() {
    if (_showNextEpButton && _s._nextEpChipFocus.canRequestFocus) {
      _s._nextEpChipFocus.requestFocus();
      return;
    }
    if (_showSkipChip && _s._skipChipFocus.canRequestFocus) {
      _s._skipChipFocus.requestFocus();
      return;
    }
    if (_s._backFocus.canRequestFocus) {
      _s._backFocus.requestFocus();
    }
  }

  void _focusDownFromSeekbar() {
    if (_s._playFocus.canRequestFocus) {
      _s._playFocus.requestFocus();
    }
  }

  void _focusLeftFromSeekbar() => _focusDownFromSeekbar();

  void _focusRightFromSeekbar() => _focusFirstRightTransport();

  void _focusDownFromTopBar() {
    _s._tvBackExitArmed = false;
    if (_s._seekbarFocus.canRequestFocus) {
      _s._seekbarFocus.requestFocus();
      return;
    }
    _focusDownFromSeekbar();
  }

  void _focusFirstRightTransport() {
    final nodes = <FocusNode>[
      if (_s._usesCatalogSourcesPanel) _s._transportSourcesFocus,
      if (_s._hasStreamPicker) _s._transportStreamFocus,
      if (_s._hasEpisodePicker) _s._transportEpisodesFocus,
      _s._transportAudioFocus,
    ];
    for (final node in nodes) {
      if (node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
  }

  /// Right-hand cluster ← : next/prev episode (when shown) → Forward 10s.
  void _focusLeftOfRightTransport() {
    if (_s._hasNextEpisodeAdjacent && _s._transportNextEpFocus.canRequestFocus) {
      _s._transportNextEpFocus.requestFocus();
      return;
    }
    if (_s._hasPrevEpisodeAdjacent && _s._transportPrevEpFocus.canRequestFocus) {
      _s._transportPrevEpFocus.requestFocus();
      return;
    }
    _s._forwardFocus.requestFocus();
  }

  /// Forward 10s → prev/next episode (when shown) → right-hand action cluster.
  void _focusRightOfForward() {
    if (_s._hasPrevEpisodeAdjacent && _s._transportPrevEpFocus.canRequestFocus) {
      _s._transportPrevEpFocus.requestFocus();
      return;
    }
    if (_s._hasNextEpisodeAdjacent && _s._transportNextEpFocus.canRequestFocus) {
      _s._transportNextEpFocus.requestFocus();
      return;
    }
    _focusFirstRightTransport();
  }

  void _beginEpisodeLoading({
    required String label,
    String status = 'Loading episode info…',
  }) {
    if (!mounted) return;
    setState(() {
      _s._isLoadingNextEp = true;
      _s._episodeLoadingLabel = label;
      _s._episodeLoadingStatus = status;
      _s._episodeTorrentStatus = null;
      _s._episodeLoadingFailed = false;
    });
  }

  void _setEpisodeLoadingStatus(String status, {bool failed = false}) {
    if (!mounted || !_s._isLoadingNextEp) return;
    setState(() {
      _s._episodeLoadingStatus = status;
      _s._episodeTorrentStatus = null;
      _s._episodeLoadingFailed = failed;
    });
  }

  void _setEpisodeTorrentLoading(TorrentLoadingStatus status) {
    if (!mounted || !_s._isLoadingNextEp) return;
    setState(() {
      _s._episodeTorrentStatus = status;
      _s._episodeLoadingStatus = status.headline;
      _s._episodeLoadingFailed = false;
    });
  }

  void _endEpisodeLoading() {
    if (!mounted) return;
    setState(() {
      _s._isLoadingNextEp = false;
      _s._episodeTorrentStatus = null;
      _s._episodeLoadingFailed = false;
    });
  }

  Future<void> _failEpisodeLoading(String status) async {
    _setEpisodeLoadingStatus(status, failed: true);
    await Future<void>.delayed(const Duration(seconds: 2));
    _endEpisodeLoading();
  }

  /// Kill audio immediately — resolve/openPlayer can take seconds while this
  /// route is still mounted, and dispose teardown is fire-and-forget.
  Future<void> _silenceForEpisodeHandoff() async {
    if (_s._disposed) return;
    try {
      await silenceMediaKitPlayer(_s._player);
    } catch (_) {}
  }

  Future<void> _resumeAfterFailedEpisodeHandoff() async {
    if (_s._disposed || !mounted) return;
    try {
      final platform = _s._player.platform;
      if (platform is NativePlayer) {
        await restoreMediaKitAudioOutput(platform);
      }
      await _s._player.setVolume(_s._mpvVolume);
      if (!_s._disposed) await _s._player.play();
    } catch (_) {}
  }

  Future<void> _nextEpisode() async {
    if (!_isNextEpisodeAvailable || _s._isLoadingNextEp) return;

    // Anime / external resolver path - the caller knows how to fetch the
    // next episode and will navigate themselves. Save history first so the
    // current position isn't lost.
    if (widget.onNextEpisode != null) {
      _beginEpisodeLoading(
        label: 'Next episode',
        status: 'Loading next episode…',
      );
      try {
        _s._saveWatchHistory();
        await _silenceForEpisodeHandoff();
        await widget.onNextEpisode!();
        // Success pops this route; only resume if we're still the top route.
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          await _resumeAfterFailedEpisodeHandoff();
          _endEpisodeLoading();
        }
      } catch (e) {
        await _resumeAfterFailedEpisodeHandoff();
        await _failEpisodeLoading('Could not load the next episode');
      }
      return;
    }

    _beginEpisodeLoading(
      label: 'Next episode',
      status: 'Looking up next episode…',
    );
    final next = await _s._computeNextEpisode();
    if (next == null) {
      await _failEpisodeLoading('No next episode available');
      return;
    }
    await _s._switchToEpisode(next.season, next.episode);
  }

  Future<void> _previousEpisode() async {
    if (_s._isLoadingNextEp) return;

    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (widget.hubEpisodes != null &&
        widget.onHubEpisodeSelected != null &&
        current != null) {
      final idx = hubEpisodeIndex(widget.hubEpisodes!, current);
      if (idx == null || idx <= 0) return;
      final prev = widget.hubEpisodes![idx - 1];
      _beginEpisodeLoading(
        label: 'Episode ${prev.displayNumber}',
        status: 'Loading previous episode…',
      );
      try {
        _s._saveWatchHistory();
        await _silenceForEpisodeHandoff();
        await widget.onHubEpisodeSelected!(prev);
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          await _resumeAfterFailedEpisodeHandoff();
          _endEpisodeLoading();
        }
      } catch (e) {
        await _resumeAfterFailedEpisodeHandoff();
        await _failEpisodeLoading('Could not load the previous episode');
      }
      return;
    }

    _beginEpisodeLoading(
      label: 'Previous episode',
      status: 'Looking up previous episode…',
    );
    final prev = await _s._computePreviousEpisode();
    if (prev == null) {
      await _failEpisodeLoading('No previous episode available');
      return;
    }
    await _s._switchToEpisode(prev.season, prev.episode);
  }

  void _seekBack10Seconds() {
    final pos = _s._positionNotifier.value - const Duration(seconds: 10);
    unawaited(_s._seekTo(pos < Duration.zero ? Duration.zero : pos));
    _s._startHideTimer();
  }

  void _seekForward10Seconds() {
    final dur = _s._durationNotifier.value;
    final pos = _s._positionNotifier.value + const Duration(seconds: 10);
    unawaited(_s._seekTo(pos > dur ? dur : pos));
    _s._startHideTimer();
  }

  Widget _wrapTvFocusOrder(int? tvFocusOrder, Widget button) {
    if (tvFocusOrder == null) return button;
    return FocusTraversalOrder(
      order: NumericFocusOrder(tvFocusOrder.toDouble()),
      child: button,
    );
  }

  Widget _buildTransportBackButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    FocusNode? focusNode,
    int? tvFocusOrder,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    VoidCallback? onUpEdge,
  }) {
    return _wrapTvFocusOrder(
      tvFocusOrder,
      PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onUpEdge: onUpEdge,
        icon: Icons.replay_10_rounded,
        tooltip: 'Back 10s',
        size: btnSize,
        iconSize: iconSz,
        onPressed: _seekBack10Seconds,
      ),
    );
  }

  Widget _buildTransportForwardButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    FocusNode? focusNode,
    int? tvFocusOrder,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    VoidCallback? onUpEdge,
  }) {
    return _wrapTvFocusOrder(
      tvFocusOrder,
      PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onUpEdge: onUpEdge,
        icon: Icons.forward_10_rounded,
        tooltip: 'Forward 10s',
        size: btnSize,
        iconSize: iconSz,
        onPressed: _seekForward10Seconds,
      ),
    );
  }

  Widget? _buildTransportPrevEpisodeButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    FocusNode? focusNode,
    int? tvFocusOrder,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    VoidCallback? onUpEdge,
  }) {
    if (!_s._hasPrevEpisodeAdjacent) return null;
    return _wrapTvFocusOrder(
      tvFocusOrder,
      PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onUpEdge: onUpEdge,
        icon: Icons.skip_previous_rounded,
        tooltip: 'Previous Episode',
        size: btnSize,
        iconSize: iconSz,
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_previousEpisode());
        },
      ),
    );
  }

  Widget? _buildTransportNextEpisodeButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    FocusNode? focusNode,
    int? tvFocusOrder,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    VoidCallback? onUpEdge,
  }) {
    if (!_s._hasNextEpisodeAdjacent) return null;
    return _wrapTvFocusOrder(
      tvFocusOrder,
      PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onUpEdge: onUpEdge,
        icon: Icons.skip_next_rounded,
        tooltip: 'Next Episode',
        size: btnSize,
        iconSize: iconSz,
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_nextEpisode());
        },
      ),
    );
  }

  Future<({int season, int episode})?> _computeNextEpisode({
    bool silent = false,
  }) async {
    final hub = widget.hubEpisodes;
    final hubCurrent = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (hub != null && hub.isNotEmpty && hubCurrent != null) {
      final idx = hubEpisodeIndex(hub, hubCurrent);
      if (idx == null || idx >= hub.length - 1) return null;
      final next = hub[idx + 1];
      return (season: 1, episode: next.number.round());
    }

    final session = widget.enginePlaySession;
    if (session?.isHubFlatList == true && widget.selectedEpisode != null) {
      final next = widget.selectedEpisode! + 1;
      final max = widget.movie?.numberOfEpisodes ?? 0;
      if (max > 0 && next > max) {
        if (!silent && mounted) {
          _s._statusController.upsert(
            'episode',
            'No more episodes',
            kind: StatusRouletteKind.info,
            dismissAfter: const Duration(seconds: 2),
          );
        }
        return null;
      }
      return (season: 1, episode: next);
    }

    if (widget.movie == null ||
        widget.selectedSeason == null ||
        widget.selectedEpisode == null) {
      return null;
    }
    try {
      final tmdb = TmdbService();
      final tvId = widget.movie!.id;
      var nextSeason = widget.selectedSeason!;
      var nextEpisode = widget.selectedEpisode! + 1;

      final seasonData = await tmdb.getTvSeasonDetails(tvId, nextSeason);
      final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
      final maxEp = episodes.isNotEmpty
          ? episodes
                .map((e) => e['episode_number'] as int)
                .reduce((a, b) => a > b ? a : b)
          : 0;

      if (nextEpisode > maxEp) {
        final totalSeasons = await tmdb.getTvSeasonCount(tvId);
        if (nextSeason < totalSeasons) {
          nextSeason++;
          nextEpisode = 1;
        } else {
          if (!silent && mounted) {
            _s._statusController.upsert(
              'episode',
              'No more episodes',
              kind: StatusRouletteKind.info,
              dismissAfter: const Duration(seconds: 2),
            );
          }
          return null;
        }
      }
      return (season: nextSeason, episode: nextEpisode);
    } catch (e) {
      debugPrint('[Episodes] next-episode lookup failed: $e');
      return null;
    }
  }

  Future<({int season, int episode})?> _computePreviousEpisode() async {
    final hub = widget.hubEpisodes;
    final hubCurrent = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (hub != null && hub.isNotEmpty && hubCurrent != null) {
      final idx = hubEpisodeIndex(hub, hubCurrent);
      if (idx == null || idx <= 0) return null;
      final prev = hub[idx - 1];
      return (season: 1, episode: prev.number.round());
    }

    final session = widget.enginePlaySession;
    if (session?.isHubFlatList == true && widget.selectedEpisode != null) {
      final prev = widget.selectedEpisode! - 1;
      if (prev < 1) return null;
      return (season: 1, episode: prev);
    }

    if (widget.movie == null ||
        widget.selectedSeason == null ||
        widget.selectedEpisode == null) {
      return null;
    }
    try {
      final tmdb = TmdbService();
      final tvId = widget.movie!.id;
      var prevSeason = widget.selectedSeason!;
      var prevEpisode = widget.selectedEpisode! - 1;

      if (prevEpisode < 1) {
        if (prevSeason <= 1) return null;
        prevSeason--;
        final seasonData = await tmdb.getTvSeasonDetails(tvId, prevSeason);
        final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
        if (episodes.isEmpty) return null;
        prevEpisode = episodes
            .map((e) => e['episode_number'] as int)
            .reduce((a, b) => a > b ? a : b);
      }
      return (season: prevSeason, episode: prevEpisode);
    } catch (e) {
      debugPrint('[Episodes] previous-episode lookup failed: $e');
      return null;
    }
  }

  Future<void> _refreshAdjacentEpisodeFlags() async {
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty) {
      final flags = adjacentHubEpisodeFlags(widget.hubEpisodes, current);
      if (!mounted) return;
      setState(() {
        _s._hasPrevEpisodeAdjacent = flags.hasPrev;
        _s._hasNextEpisodeAdjacent = flags.hasNext;
      });
      return;
    }

    if (widget.onNextEpisode != null) {
      if (!mounted) return;
      setState(() {
        _s._hasNextEpisodeAdjacent = widget.hasNextEpisode;
        _s._hasPrevEpisodeAdjacent = current != null && current > 1;
      });
      return;
    }

    if (widget.enginePlaySession?.isHubFlatList == true &&
        widget.selectedEpisode != null) {
      final next = await _computeNextEpisode(silent: true);
      final prev = await _computePreviousEpisode();
      if (!mounted) return;
      setState(() {
        _s._hasPrevEpisodeAdjacent = prev != null;
        _s._hasNextEpisodeAdjacent = next != null;
      });
      return;
    }

    if (_isSeriesMediaType(widget.movie?.mediaType) &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      final results = await Future.wait([
        _computePreviousEpisode(),
        _computeNextEpisode(silent: true),
      ]);
      if (!mounted) return;
      setState(() {
        _s._hasPrevEpisodeAdjacent = results[0] != null;
        _s._hasNextEpisodeAdjacent = results[1] != null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _s._hasPrevEpisodeAdjacent = false;
      _s._hasNextEpisodeAdjacent = false;
    });
  }

  Future<void> _switchToEpisode(int season, int episode) async {
    if (widget.movie == null) return;
    _s._resetEofSessionGuards();
    final enginePid = _s._currentProvider ?? widget.activeProvider;
    if (isEnginePlayerSession(enginePid)) {
      _s._saveWatchHistory();
      if (_s._isLoadingNextEp) _endEpisodeLoading();
      if (!mounted) return;
      setState(() => _s._isLoadingNextEp = true);
      await _silenceForEpisodeHandoff();
      if (!mounted) return;
      try {
        debugPrint('[EpSwitch] Engine Auto S${season}E$episode');
        await switchEpisodeViaEngineAutoPlay(
          context: context,
          movie: widget.movie!,
          season: season,
          episode: episode,
          stremioId: widget.stremioId,
          session: widget.enginePlaySession,
          hubEpisodes: widget.hubEpisodes,
        );
      } finally {
        if (mounted) {
          await _resumeAfterFailedEpisodeHandoff();
          _endEpisodeLoading();
        }
      }
      return;
    }

    _beginEpisodeLoading(
      label: 'Season $season · Episode $episode',
      status: 'Loading episode info…',
    );
    // Let the loading card paint before resolve starts.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _silenceForEpisodeHandoff();

    try {
      debugPrint('[EpSwitch] Playing S${season}E$episode');
      _s._saveWatchHistory();
      _setEpisodeLoadingStatus('Checking sources…');

      final chain = episodeProviderChain(
        providers: widget.providers,
        activeProvider: widget.activeProvider,
        currentProvider: _s._currentProvider,
        magnetLink: _s._activeMagnet ?? widget.magnetLink,
      );
      if (chain.isEmpty) {
        throw Exception('No provider available for S${season}E$episode');
      }

      EpisodeSwitchResult? resolved;
      for (final key in chain) {
        _setEpisodeLoadingStatus(
          key == 'torrent'
              ? 'Resolving torrent…'
              : key == 'stremio_direct'
              ? 'Checking Stremio…'
              : 'Checking sources…',
        );
        resolved = await resolveEpisodeForProvider(
          providerKey: key,
          movie: widget.movie!,
          season: season,
          episode: episode,
          providers: widget.providers,
          magnetLink: _s._activeMagnet ?? widget.magnetLink,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl:
              _s._catalogAddonBaseUrl ?? widget.stremioAddonBaseUrl,
          torrentEp: catalogOpenTorrentEp(
            widget.enginePlaySession?.effectiveOpen,
          ),
        );
        if (resolved != null) break;
      }
      if (resolved == null || resolved.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }

      if (!mounted) return;
      _setEpisodeLoadingStatus('Opening stream…');

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      if (resolved.magnetLink != null && resolved.magnetLink!.isNotEmpty) {
        TorrentStreamService().retainForExternalHandoff = true;
      }
      // openPlayer (not pushReplacement): clears old player + loading dialogs /
      // hub host so Back returns to details, not the previous episode.
      unawaited(
        AppRouter.openPlayer(
          context,
          streamUrl: resolved.streamUrl,
          title: nextTitle,
          headers: catalog ? null : resolved.headers,
          movie: widget.movie,
          selectedSeason: season,
          selectedEpisode: episode,
          magnetLink: resolved.magnetLink,
          fileIndex: resolved.fileIndex,
          activeProvider: resolved.activeProvider,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          providers: catalog ? null : widget.providers,
          sources: catalog ? null : resolved.sources,
          enginePlaySession: widget.enginePlaySession,
          hubEpisodes: widget.hubEpisodes,
          hubEpisodeNumber: widget.hubEpisodes != null ? episode : null,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          onSaveProgress: widget.onSaveProgress,
          onSourcePinned: widget.onSourcePinned,
          pinSource: widget.pinSource,
          sourcesListNotifier: widget.sourcesListNotifier,
          providerSourcesCache: widget.providerSourcesCache,
          providerProbesNotifier: widget.providerProbesNotifier,
        ),
      );
    } catch (e) {
      debugPrint('[EpSwitch] Error: $e');
      await _resumeAfterFailedEpisodeHandoff();
      await _failEpisodeLoading('Could not find a stream for this episode');
    }
  }

  Future<void> _goToEpisode(int season, int episode) async {
    if (season == widget.selectedSeason && episode == widget.selectedEpisode) {
      return;
    }
    await _switchToEpisode(season, episode);
  }

  Future<void> _showEpisodesMenu(BuildContext anchorContext) async {
    if (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty) {
      if (!mounted) return;
      PlayerPopupPanel.dismiss();
      final useHubCallback = widget.onHubEpisodeSelected != null;
      PlayerHubEpisodePanel.show(
        context: context,
        episodes: widget.hubEpisodes!,
        currentEpisode: widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: (ep) async {
          if (useHubCallback) {
            _beginEpisodeLoading(
              label: 'Episode ${ep.displayNumber}',
              status: 'Loading episode info…',
            );
            try {
              _s._saveWatchHistory();
              await _silenceForEpisodeHandoff();
              await widget.onHubEpisodeSelected!(ep);
              if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                await _resumeAfterFailedEpisodeHandoff();
                _endEpisodeLoading();
              }
            } catch (e) {
              await _resumeAfterFailedEpisodeHandoff();
              await _failEpisodeLoading('Could not load this episode');
            }
            return;
          }
          await _switchToEpisode(1, ep.number.round());
        },
        fallbackBackdropPath: widget.movie?.backdropPath,
        fallbackPosterPath: widget.movie?.posterPath,
      );
      return;
    }
    if (!mounted) return;
    final movie = widget.movie;
    if (movie == null || !_isSeriesMediaType(movie.mediaType)) return;
    final season = widget.selectedSeason ?? 1;
    final episode = widget.selectedEpisode ?? 1;
    PlayerEpisodeMenu.show(
      context,
      movie: movie,
      currentSeason: season,
      currentEpisode: episode,
      onEpisodeSelected: _goToEpisode,
      anchorContext: anchorContext,
    );
  }
}
