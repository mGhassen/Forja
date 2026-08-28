part of 'desktop_player_screen.dart';

mixin _DesktopPlayerEpisodes
    on
        ConsumerState<DesktopPlayerScreen>,
        WidgetsBindingObserver,
        WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  void _toggleLoop() {
    setState(() => _s._loopEnabled = !_s._loopEnabled);
    _s._player.setPlaylistMode(
      _s._loopEnabled ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SKIP SEGMENTS (IntroDB)
  // ───────────────────────────────────────────────────────────────────────────

  void _updateActiveSkipSegment(Duration pos) {
    if (_s._introDbData == null) return;

    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    // Check each segment type – first match wins
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

    // Only setState when needed – avoid per-frame rebuilds
    if (label != _s._activeSkipLabel) {
      setState(() {
        _s._activeSkipLabel = label;
        _s._activeSkipTarget = target;
        _s._skipDismissed = false; // reset dismiss when segment changes
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

  // ───────────────────────────────────────────────────────────────────────────
  //  NEXT EPISODE
  // ───────────────────────────────────────────────────────────────────────────

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
      _s._isNextEpisodeAvailable &&
      _s._nearEndOfEpisode &&
      !_s._isLoadingNextEp;

  /// Extra space under the torrent stats card so it sits above Skip / Next.
  double get _torrentStatsLift {
    final skipVisible = _s._activeSkipLabel != null && !_s._skipDismissed;
    if (skipVisible && _showNextEpButton) return 110;
    if (skipVisible || _showNextEpButton) return 55;
    return 0;
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
      _s._episodeLoadingFailed = false;
    });
  }

  void _setEpisodeLoadingStatus(String status, {bool failed = false}) {
    if (!mounted || !_s._isLoadingNextEp) return;
    setState(() {
      _s._episodeLoadingStatus = status;
      _s._episodeLoadingFailed = failed;
    });
  }

  void _endEpisodeLoading() {
    if (!mounted) return;
    setState(() {
      _s._isLoadingNextEp = false;
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
    if (_s._disposed || !_s._playerReady) return;
    try {
      await silenceMediaKitPlayer(_s._player);
    } catch (_) {}
  }

  Future<void> _resumeAfterFailedEpisodeHandoff() async {
    if (_s._disposed || !_s._playerReady || !mounted) return;
    try {
      final platform = _s._player.platform;
      if (platform is NativePlayer) {
        await restoreMediaKitAudioOutput(platform);
      }
      await _s._player.setVolume(_s._volumeNotifier.value);
      if (!_s._disposed) await _s._player.play();
    } catch (_) {}
  }

  Future<void> _nextEpisode() async {
    if (!_s._isNextEpisodeAvailable || _s._isLoadingNextEp) return;

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
    final next = await _computeNextEpisode();
    if (next == null) {
      await _failEpisodeLoading('No next episode available');
      return;
    }
    await _switchToEpisode(next.season, next.episode);
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
    final prev = await _computePreviousEpisode();
    if (prev == null) {
      await _failEpisodeLoading('No previous episode available');
      return;
    }
    await _switchToEpisode(prev.season, prev.episode);
  }

  void _seekBack10Seconds() {
    final pos = _s._positionNotifier.value - const Duration(seconds: 10);
    unawaited(_s._seekTo(pos < Duration.zero ? Duration.zero : pos));
    _s._onMouseMove();
  }

  void _seekForward10Seconds() {
    final dur = _s._durationNotifier.value;
    final pos = _s._positionNotifier.value + const Duration(seconds: 10);
    unawaited(_s._seekTo(pos > dur ? dur : pos));
    _s._onMouseMove();
  }

  Widget _buildTransportBackButton() {
    return PlayerFlatIconButton(
      icon: Icons.replay_10_rounded,
      tooltip: 'Back 10s',
      onPressed: _seekBack10Seconds,
    );
  }

  Widget _buildTransportForwardButton() {
    return PlayerFlatIconButton(
      icon: Icons.forward_10_rounded,
      tooltip: 'Forward 10s',
      onPressed: _seekForward10Seconds,
    );
  }

  Widget? _buildTransportPrevEpisodeButton() {
    if (!_s._hasPrevEpisodeAdjacent) return null;
    return PlayerFlatIconButton(
      icon: Icons.skip_previous_rounded,
      tooltip: 'Previous Episode',
      onPressed: () {
        if (_s._isLoadingNextEp) return;
        unawaited(_previousEpisode());
      },
    );
  }

  Widget? _buildTransportNextEpisodeButton() {
    if (!_s._hasNextEpisodeAdjacent) return null;
    return PlayerFlatIconButton(
      icon: Icons.skip_next_rounded,
      tooltip: 'Next Episode',
      onPressed: () {
        if (_s._isLoadingNextEp) return;
        unawaited(_nextEpisode());
      },
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
      // Same full-screen Forja Auto loader as green Play — not the episode card.
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
        // Still mounted ⇒ Auto cancelled/failed without replacing this route.
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
        );
        if (resolved != null) break;
      }
      if (resolved == null || resolved.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }

      if (!mounted) return;
      _setEpisodeLoadingStatus('Opening stream…');

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      // Catalog torrent/Stremio: open like details Play (url + magnet), not a
      // webstreaming sources list - localhost torrent URLs are filtered as
      // "unplayable extracts" in the server-fallback path.
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      // Keep the librqbit session alive while the outgoing player disposes -
      // otherwise replacing the route stops the torrent the next episode just started.
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

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _s._hideTimer?.cancel();
    final session = widget.enginePlaySession;
    final ep = widget.selectedEpisode;
    PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: ep,
      currentMagnet: _s._activeMagnet ?? widget.magnetLink,
      currentStreamUrl: _s._currentUrl ?? widget.mediaPath,
      currentPlayingCatalogUrl: _s._currentPlayingCatalogUrl,
      preferredKind: _s._catalogSourceKind,
      currentAddonBaseUrl:
          _s._catalogAddonBaseUrl ?? widget.stremioAddonBaseUrl,
      anilistId: session?.anilistId,
      malId: session?.malId,
      kisskhId: session?.kisskhId,
      kisskhEpisodeId: ep != null ? session?.kisskhEpisodeIdFor(ep) : null,
      engineCategory: session?.category,
      animeAudioCategory: session?.animeAudioCategory,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final debrid = SettingsService().debridPlaybackPrefs();
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
      useDebrid: debrid.useDebrid,
      debridService: debrid.service,
    );
    // Magnets / infoHash need engine resolve - keep current video + loading
    // card, replace the player only when the new stream is ready.
    if (precheck == null) {
      await _switchStremioMagnetSource(stream);
      return;
    }

    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final switchGen = ++_s._fallbackGen;
    // Fence stop/open so the error listener does not abort this switch.
    _s._isInitPlaybackRunning = true;
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    setState(() {
      _s._hasError = false;
    });
    _s._markPlaybackConfirmed(false);
    _s._statusController.upsert(
      statusId,
      title,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._fallbackAborted(switchGen)) {
      if (switchGen == _s._fallbackGen) _s._isInitPlaybackRunning = false;
      return;
    }

    try {
      await _s._player.stop();

      final resolved = await resolveStremioStream(
        stream: stream,
        profile: PlatformPlayback.capabilities,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;

      if (resolved is! StremioPlayable) {
        final msg = resolved is StremioResolveFailure
            ? resolved.message
            : 'Failed to resolve stream';
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        if (msg.isNotEmpty) {
          final kind = catalogStreamKindLabel(stream);
          debugPrint('[Player] $kind switch failed: $msg');
        }
        return;
      }

      await _s._configureMpvProperties();
      await resetPlayerForOpen(_s._player);
      final playPid = catalogHttpPlayProviderId(stream);
      if (!await validateStreamSourceForCheck(
        providerId: playPid,
        source: StreamSource(
          url: resolved.streamUrl,
          title: title,
          type: 'video',
          headers: resolved.headers,
        ),
        headers: resolved.headers,
      )) {
        if (!mounted || _s._fallbackAborted(switchGen)) return;
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch probe failed: '
          '${resolved.streamUrl}',
        );
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }
      final openedUrl = await openCatalogHttpStreamWithPipeline(
        _s._player,
        stream: stream,
        streamUrl: resolved.streamUrl,
        headers: resolved.headers,
        providerId: playPid,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      _s._player.setVolume(_s._volumeNotifier.value);

      if (openedUrl == null) {
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch failed: '
          '${resolved.streamUrl}',
        );
        return;
      }

      setState(() {
        _s._currentUrl = resolved.streamUrl;
        _s._activeMagnet = resolved.magnetLink;
        _s._hasError = false;
        _s._currentSources = null;
        final base = stream['_addonBaseUrl']?.toString();
        _s._catalogAddonBaseUrl = base;
        final magnet = resolved.magnetLink;
        final localTorrent =
            magnet != null &&
            magnet.isNotEmpty &&
            isLocalTorrentStreamUrl(resolved.streamUrl);
        _s._catalogSourceKind = localTorrent
            ? 'torrents'
            : ((base != null && base.startsWith('nuvio:'))
                  ? 'nuvio'
                  : 'stremio');
        _s._currentProvider = catalogHttpPlayProviderId(stream);
      });
      _s._markPlaybackConfirmed(true);
      syncPlayerProgressNotifiers(
        _s._player,
        duration: _s._durationNotifier,
        position: _s._positionNotifier,
        buffered: _s._bufferedNotifier,
      );
      _s._statusController.complete();
      widget.onPlaybackStarted?.call();
      _s._onMouseMove();
    } catch (e) {
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      debugPrint(
        '[Player] ${catalogStreamKindLabel(stream)} switch failed: $e',
      );
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    } finally {
      if (switchGen == _s._fallbackGen) {
        _s._isInitPlaybackRunning = false;
      }
    }
  }

  /// Stremio/Torrentio magnet - same UX as [_switchTorrentSource]: keep the
  /// current player running with a bottom-right card until the new stream is
  /// ready, then open a fresh player.
  Future<void> _switchStremioMagnetSource(Map<String, dynamic> stream) async {
    // Supersede a prior episode/magnet loading card — never silent-return
    // after Sources already dismissed.
    final debrid = SettingsService().debridPlaybackPrefs();
    final useDebrid = debrid.useDebrid;
    final debridService = debrid.service;
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(
      context,
      useDebrid: useDebrid,
      debridService: debridService,
    )) {
      return;
    }
    if (!mounted) return;
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    _beginEpisodeLoading(
      label: title,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      _setEpisodeLoadingStatus(
        playbackResolveLabel(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final resolved = await resolveStremioStream(
        stream: stream,
        profile: PlatformPlayback.capabilities,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted) return;
      if (resolved is! StremioPlayable || resolved.streamUrl.isEmpty) {
        final msg =
            resolved is StremioResolveFailure && resolved.message.isNotEmpty
            ? resolved.message
            : 'Failed to resolve stream';
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch failed: $msg',
        );
        await _failEpisodeLoading(msg);
        return;
      }

      _setEpisodeLoadingStatus('Opening stream…');
      TorrentStreamService().retainForExternalHandoff = true;

      final season = widget.selectedSeason;
      final episode = widget.selectedEpisode;
      final nextTitle =
          widget.movie != null && season != null && episode != null
          ? '${widget.movie!.title} - S$season E$episode'
          : widget.title;
      final base = stream['_addonBaseUrl']?.toString();
      final magnet = resolved.magnetLink;

      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved.streamUrl,
            title: nextTitle,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: magnet,
            fileIndex: resolved.fileIndex,
            headers: resolved.headers.isEmpty ? null : resolved.headers,
            activeProvider: 'stremio_direct',
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: base ?? widget.stremioAddonBaseUrl,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        '[Player] ${catalogStreamKindLabel(stream)} switch failed: $e',
      );
      await _failEpisodeLoading('Failed to resolve stream');
    }
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    // Supersede a prior episode/magnet loading card — never silent-return
    // after Sources already dismissed.
    final debrid = SettingsService().debridPlaybackPrefs();
    final useDebrid = debrid.useDebrid;
    final debridService = debrid.service;
    if (!mounted) return;
    if (!await ensureLanP2pPlayback(
      context,
      useDebrid: useDebrid,
      debridService: debridService,
    )) {
      return;
    }
    if (!mounted) return;
    // Keep current video playing with the loading card while the new magnet
    // resolves in the background. Only replace the player when the stream is
    // ready - never tear down the active swarm first (that freezes mpv).
    _beginEpisodeLoading(
      label: result.name,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final localEngine = PlatformPlayback.capabilities.localTorrentEngine;
      _setEpisodeLoadingStatus(
        playbackResolveLabel(
          useDebrid: useDebrid,
          debridService: debridService,
        ),
      );

      final playback = await resolveMagnetForPlayback(
        magnet: result.magnet,
        useDebrid: useDebrid,
        debridService: debridService,
        localTorrentEngine: localEngine,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
      if (!mounted) return;
      if (playback == null || playback.url.isEmpty) {
        await _failEpisodeLoading('Torrent stream failed to start');
        return;
      }

      _setEpisodeLoadingStatus('Opening stream…');
      // Keep librqbit alive while the outgoing player disposes.
      TorrentStreamService().retainForExternalHandoff = true;

      final season = widget.selectedSeason;
      final episode = widget.selectedEpisode;
      final nextTitle =
          widget.movie != null && season != null && episode != null
          ? '${widget.movie!.title} - S$season E$episode'
          : widget.title;

      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: playback.url,
            title: nextTitle,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: result.magnet,
            fileIndex: playback.fileIndex,
            activeProvider: 'torrent',
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Player] Torrent switch failed: $e');
      await _failEpisodeLoading('Torrent stream failed to start');
    }
  }

  Future<void> _persistProgressForSwitch() async {
    if (widget.onSaveProgress == null) return;
    final pos = _s._positionNotifier.value;
    final dur = _s._durationNotifier.value;
    if (pos.inMilliseconds <= 0 || dur.inMilliseconds <= 0) return;
    await widget.onSaveProgress!(pos, dur);
  }

  ({String url, Map<String, String>? headers}) _externalHandoffTarget() {
    var url = _s._currentUrl ?? widget.mediaPath;
    Map<String, String>? headers = widget.headers;
    final sources = _s._currentSources;
    final idx = _s._currentFallbackSourceIndex;
    if (sources != null && idx >= 0 && idx < sources.length) {
      final source = sources[idx];
      headers = source.headers ?? headers;
      if (url.isEmpty) url = source.url;
    }
    return (url: url, headers: headers);
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _persistProgressForSwitch();
    if (!mounted || !anchorContext.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) {
        if (externalPlayer != null) {
          final target = _externalHandoffTarget();
          return handler(
            _s._positionNotifier.value,
            externalPlayer: externalPlayer,
            streamUrl: target.url,
            headers: target.headers,
            activeProvider: _s._currentProvider,
            sources: _s._currentSources,
          );
        }
        return handler(
          _s._positionNotifier.value,
          builtInEngine: builtInEngine,
        );
      },
    );
    _s._onMouseMove();
  }

  Future<void> _applyAutoSubtitle() async {
    if (_s._disposed || !mounted) return;
    final settings = SettingsService();
    final preferred = await settings.getPreferredSubtitleLanguage();
    if (_s._disposed || !mounted) return;
    final embedded = _s._player.state.tracks.subtitle
        .where(
          (t) => t.id != 'no' && t.id != 'auto' && !t.id.startsWith('http'),
        )
        .toList();

    if (preferred != 'None' && preferred.isNotEmpty) {
      final track = pickEmbeddedSubtitleWithFallback(
        preferredLang: preferred,
        tracks: embedded,
      );
      if (track == null) return;
      await _s._player.setSubtitleTrack(track);
      if (_s._disposed || !mounted) return;
      _s._updateSubVisibility(track);
      if (mounted) setState(() => _s._selectedExternalSubUrl = null);
      return;
    }

    // No preferred language - only pick first embedded when Auto subtitles is on.
    if (_s._subtitlePinned) return;
    if (embedded.isEmpty) return;
    final track = embedded.first;
    await _s._player.setSubtitleTrack(track);
    if (_s._disposed || !mounted) return;
    _s._updateSubVisibility(track);
    if (mounted) setState(() => _s._selectedExternalSubUrl = null);
  }

  Future<void> _loadPlayerAutoSettings() async {
    final settings = await ref.read(playerAutoSettingsProvider.future);
    if (!mounted) return;
    // Respect Auto toggles only. Do not lock because an extract already exists
    // (green Play / cache) - that made dead CDNs hit "no auto failover".
    setState(() {
      _s._providerPinned = settings.providerPinned;
      _s._sourcePinned = settings.sourcePinned;
      _s._audioPinned = settings.audioPinned;
      _s._subtitlePinned = settings.subtitlePinned;
    });
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    final hasProviders =
        widget.providers != null &&
        widget.providers!.isNotEmpty &&
        widget.movie != null &&
        !_s._usesCatalogSourcesPanel;
    final hasSources =
        _s._currentSources != null && _s._currentSources!.isNotEmpty;
    final hasTorrent =
        widget.magnetLink != null && widget.magnetLink!.isNotEmpty;

    List<PlayerSettingsEntry> buildEntries() {
      final speed = _s._player.state.rate;
      return [
        PlayerSettingsEntry(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto selection',
          subtitle: 'Servers, tracks, skip intro',
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => Column(
              children: [
                if (hasProviders) ...[
                  PlayerPopupToggleRow(
                    label: 'Auto server',
                    value: !_s._providerPinned,
                    onChanged: (on) async {
                      final settings = SettingsService();
                      if (on) {
                        await settings.setPlayerAutoServer(true);
                        setState(() => _s._providerPinned = false);
                        setPage(() {});
                        await _s._selectAutoProvider();
                      } else {
                        await settings.setPlayerAutoServer(false);
                        setState(() => _s._providerPinned = true);
                        setPage(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasSources) ...[
                  PlayerPopupToggleRow(
                    label: 'Auto source',
                    value: !_s._sourcePinned,
                    onChanged: (on) async {
                      final settings = SettingsService();
                      if (on) {
                        await settings.setPlayerAutoSource(true);
                        setState(() => _s._sourcePinned = false);
                        setPage(() {});
                        await _s._selectAutoSource();
                      } else {
                        await settings.setPlayerAutoSource(false);
                        setState(() => _s._sourcePinned = true);
                        setPage(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                PlayerPopupToggleRow(
                  label: 'Auto audio',
                  value: !_s._audioPinned,
                  onChanged: (on) async {
                    final settings = SettingsService();
                    if (on) {
                      await settings.setPlayerAutoAudio(true);
                      setState(() => _s._audioPinned = false);
                      setPage(() {});
                      _s._autoTracksAppliedForSource = false;
                      await _s._applyTrackAutoSelect();
                    } else {
                      await settings.setPlayerAutoAudio(false);
                      setState(() => _s._audioPinned = true);
                      setPage(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: 'Auto subtitles',
                  value: !_s._subtitlePinned,
                  onChanged: (on) async {
                    final settings = SettingsService();
                    if (on) {
                      await settings.setPlayerAutoSubtitle(true);
                      setState(() => _s._subtitlePinned = false);
                      setPage(() {});
                      await _applyAutoSubtitle();
                    } else {
                      await settings.setPlayerAutoSubtitle(false);
                      setState(() => _s._subtitlePinned = true);
                      setPage(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: 'Auto skip intro',
                  value: SettingsService.autoSkipIntroNotifier.value,
                  onChanged: (on) async {
                    await SettingsService().setAutoSkipIntro(on);
                    setPage(() {});
                  },
                ),
                const SizedBox(height: 12),
                PlayerPopupToggleRow(
                  label: 'Content warnings',
                  value: SettingsService.contentWarningsNotifier.value,
                  onChanged: (on) async {
                    await SettingsService().setContentWarnings(on);
                    setPage(() {});
                  },
                ),
              ],
            ),
          ),
        ),
        PlayerSettingsEntry(
          icon: Icons.memory_rounded,
          title: 'Video decode',
          subtitle: _s._hwDecMode.description,
          value: _s._hwDecMode.label,
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => playerPopupChipRow([
              for (final mode in _HwDecMode.values)
                PlayerPopupOptionChip(
                  label: mode.label,
                  selected: _s._hwDecMode == mode,
                  expanded: true,
                  grouped: true,
                  onTap: () {
                    if (_s._hwDecMode == mode) return;
                    setState(() => _s._hwDecMode = mode);
                    if (_s._player.platform is NativePlayer) {
                      (_s._player.platform as NativePlayer).setProperty(
                        'hwdec',
                        mode.mpvValue,
                      );
                    }
                    setPage(() {});
                  },
                ),
            ]),
          ),
        ),
        PlayerSettingsEntry(
          icon: Icons.speed_rounded,
          title: 'Playback speed',
          subtitle: 'How fast playback runs',
          value: speed == 1.0 ? 'Normal' : '${speed}x',
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) {
              final current = _s._player.state.rate;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in const [
                    0.25,
                    0.5,
                    0.75,
                    1.0,
                    1.25,
                    1.5,
                    1.75,
                    2.0,
                  ])
                    PlayerPopupOptionChip(
                      label: s == 1.0 ? 'Normal' : '${s}x',
                      selected: s == current,
                      expanded: true,
                      onTap: () {
                        _s._player.setRate(s);
                        setPage(() {});
                      },
                    ),
                ],
              );
            },
          ),
        ),
        PlayerSettingsEntry(
          icon: Icons.aspect_ratio_rounded,
          title: 'Aspect ratio',
          subtitle: 'Fit video in the frame',
          value: _s._videoFitLabel,
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => playerPopupChipRow([
              for (final entry in const [
                (BoxFit.contain, 'FIT'),
                (BoxFit.cover, 'CROP'),
                (BoxFit.fill, 'FILL'),
              ])
                PlayerPopupOptionChip(
                  label: entry.$2,
                  selected: _s._videoFit == entry.$1,
                  expanded: true,
                  grouped: true,
                  onTap: () {
                    setState(() => _s._videoFit = entry.$1);
                    setPage(() {});
                  },
                ),
            ]),
          ),
        ),
        PlayerSettingsEntry(
          icon: Icons.loop_rounded,
          title: 'Loop',
          subtitle: 'Repeat the current title',
          value: _s._loopEnabled ? 'On' : 'Off',
          pageBuilder: (_) => StatefulBuilder(
            builder: (context, setPage) => playerPopupOnOffChips(
              value: _s._loopEnabled,
              onChanged: (on) {
                if (on == _s._loopEnabled) return;
                _toggleLoop();
                setPage(() {});
              },
            ),
          ),
        ),
        if (hasTorrent)
          PlayerSettingsEntry(
            icon: Icons.graphic_eq_rounded,
            title: 'Torrent stats',
            subtitle: 'Show live transfer overlay',
            value: _s._showTorrentStatsOverlay ? 'On' : 'Off',
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) => playerPopupOnOffChips(
                value: _s._showTorrentStatsOverlay,
                onChanged: (on) async {
                  if (on == _s._showTorrentStatsOverlay) return;
                  setState(() => _s._showTorrentStatsOverlay = on);
                  setPage(() {});
                  await SettingsService().setShowTorrentStatsOverlay(on);
                  _s._syncTorrentStatsSubscription();
                },
              ),
            ),
          ),
      ];
    }

    showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      buildEntries: buildEntries,
    );
  }

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
      // Re-extract miss while this server is still playing must not paint it
      // dead - live URL is still open in the player.
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
    DomainStreamProviderResolver.cancelAllPending();
    _s._statusController.clear();
    _s._markPlaybackConfirmed(false);

    // Chip label follows selection immediately (not only after open/decode).
    if (mounted) {
      setState(() => _s._currentProvider = newProvider);
    } else {
      _s._currentProvider = newProvider;
    }

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
        _s._autoTracksAppliedForSource = false;
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
