part of 'desktop_player_screen.dart';

mixin _DesktopPlayerEpisodes on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
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
    _s._player.seek(_s._activeSkipTarget!);
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
      (widget.movie != null &&
          widget.movie!.mediaType == 'tv' &&
          widget.selectedSeason != null &&
          widget.selectedEpisode != null);

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

  Future<void> _nextEpisode() async {
    if (!_s._isNextEpisodeAvailable || _s._isLoadingNextEp) return;

    if (widget.onNextEpisode != null) {
      _beginEpisodeLoading(
        label: 'Next episode',
        status: 'Loading next episode…',
      );
      try {
        _s._saveWatchHistory();
        await widget.onNextEpisode!();
        _endEpisodeLoading();
      } catch (e) {
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
        await widget.onHubEpisodeSelected!(prev);
        _endEpisodeLoading();
      } catch (e) {
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
    _s._player.seek(pos < Duration.zero ? Duration.zero : pos);
    _s._onMouseMove();
  }

  void _seekForward10Seconds() {
    final dur = _s._durationNotifier.value;
    final pos = _s._positionNotifier.value + const Duration(seconds: 10);
    _s._player.seek(pos > dur ? dur : pos);
    _s._onMouseMove();
  }

  Widget _buildTransportBackButton() {
    if (_s._hasPrevEpisodeAdjacent) {
      return PlayerFlatIconButton(
        icon: Icons.skip_previous_rounded,
        tooltip: 'Previous Episode',
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_previousEpisode());
        },
      );
    }
    return PlayerFlatIconButton(
      icon: Icons.replay_10_rounded,
      tooltip: 'Back 10s',
      onPressed: _seekBack10Seconds,
    );
  }

  Widget _buildTransportForwardButton() {
    if (_s._hasNextEpisodeAdjacent) {
      return PlayerFlatIconButton(
        icon: Icons.skip_next_rounded,
        tooltip: 'Next Episode',
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_nextEpisode());
        },
      );
    }
    return PlayerFlatIconButton(
      icon: Icons.forward_10_rounded,
      tooltip: 'Forward 10s',
      onPressed: _seekForward10Seconds,
    );
  }

  Future<({int season, int episode})?> _computeNextEpisode({
    bool silent = false,
  }) async {
    if (widget.movie == null ||
        widget.selectedSeason == null ||
        widget.selectedEpisode == null) {
      return null;
    }
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
  }

  Future<({int season, int episode})?> _computePreviousEpisode() async {
    if (widget.movie == null ||
        widget.selectedSeason == null ||
        widget.selectedEpisode == null) {
      return null;
    }
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

    if (widget.movie?.mediaType == 'tv' &&
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
    _beginEpisodeLoading(
      label: 'Season $season · Episode $episode',
      status: 'Loading episode info…',
    );
    // Let the loading card paint before resolve starts.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      debugPrint('[EpSwitch] Playing S${season}E$episode');
      _s._saveWatchHistory();
      _setEpisodeLoadingStatus('Checking sources…');

      final chain = episodeProviderChain(
        providers: widget.providers,
        activeProvider: widget.activeProvider,
        currentProvider: _s._currentProvider,
        magnetLink: widget.magnetLink,
      );
      if (chain.isEmpty) {
        throw Exception('No provider available for S${season}E$episode');
      }

      final hit = await PlaybackService.resolveWebstreaming(
        movie: widget.movie!,
        providers: {
          for (final k in chain)
            if (widget.providers?.containsKey(k) ?? false) k: widget.providers![k]!,
        },
        season: season,
        episode: episode,
        preferredProvider: chain.first,
        onProgress: (providerId, status) {
          if (!mounted || !_s._isLoadingNextEp) return;
          final label = PlayerProviderMenu.snackbarLabel(
            providerId,
            widget.providers?[providerId],
          );
          switch (status) {
            case 'trying':
              _setEpisodeLoadingStatus('Checking $label…');
            case 'success':
              _setEpisodeLoadingStatus('Found a stream on $label…');
            case 'failed':
            case 'skipped':
              _setEpisodeLoadingStatus('Trying another source…');
            default:
              _setEpisodeLoadingStatus('Checking sources…');
          }
        },
      );
      if (hit == null || hit.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }
      final resolved = EpisodeSwitchResult(
        streamUrl: hit.streamUrl,
        headers: hit.headers,
        sources: hit.streamSources,
        activeProvider: hit.providerId,
      );

      if (!mounted) return;
      _setEpisodeLoadingStatus('Opening stream…');

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved.streamUrl,
            title: nextTitle,
            headers: resolved.headers,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: resolved.magnetLink,
            fileIndex: resolved.fileIndex,
            activeProvider: resolved.activeProvider,
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
            providers: widget.providers,
            sources: resolved.sources,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[EpSwitch] Error: $e');
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
    if (widget.hubEpisodes != null &&
        widget.hubEpisodes!.isNotEmpty &&
        widget.onHubEpisodeSelected != null) {
      if (!mounted) return;
      PlayerPopupPanel.dismiss();
      PlayerHubEpisodePanel.show(
        context: context,
        episodes: widget.hubEpisodes!,
        currentEpisode: widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: (ep) async {
          _beginEpisodeLoading(
            label: 'Episode ${ep.displayNumber}',
            status: 'Loading episode info…',
          );
          try {
            await widget.onHubEpisodeSelected!(ep);
            _endEpisodeLoading();
          } catch (e) {
            await _failEpisodeLoading('Could not load this episode');
          }
        },
        fallbackBackdropPath: widget.movie?.backdropPath,
        fallbackPosterPath: widget.movie?.posterPath,
      );
      return;
    }
    if (!mounted) return;
    final movie = widget.movie;
    if (movie == null || movie.mediaType != 'tv') return;
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
    PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      currentMagnet: _s._activeMagnet ?? widget.magnetLink,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    _s._playbackConfirmed = false;
    _s._statusController.upsert(statusId, title, kind: StatusRouletteKind.loading);
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _s._player.stop();

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: PlatformPlayback.capabilities,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;

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
      throw Exception(msg);
    }

    await _s._configureMpvProperties();
    await resetPlayerForOpen(_s._player);
    final openedUrl = await openPlayerStream(
      _s._player,
      url: resolved.streamUrl,
      headers: resolved.headers,
    );
    _s._player.setVolume(_s._volumeNotifier.value);

    final opened = await waitForMediaOpen(
      _s._player,
      streamUrl: openedUrl,
      timeout: isLocalTorrentStreamUrl(openedUrl)
          ? const Duration(seconds: 45)
          : const Duration(seconds: 25),
    );
    if (!mounted) return;
    if (!opened) {
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Stream failed to open');
    }

    setState(() {
      _s._currentUrl = resolved.streamUrl;
      _s._activeMagnet = resolved.magnetLink;
      _s._hasError = false;
      _s._errorMessage = '';
      _s._currentSources = null;
    });
    _s._playbackConfirmed = true;
    _s._statusController.complete();
    widget.onPlaybackStarted?.call();
    _s._onMouseMove();
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-torrent-${result.magnet.hashCode}';
    _s._playbackConfirmed = false;
    _s._statusController.upsert(
      statusId,
      result.name,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _s._player.stop();

    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    final localEngine = PlatformPlayback.capabilities.localTorrentEngine;

    final playback = await resolveMagnetForPlayback(
      magnet: result.magnet,
      useDebrid: useDebrid,
      debridService: debridService,
      localTorrentEngine: localEngine,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;
    if (playback == null) {
      _s._statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Failed to resolve torrent');
    }

    await _s._configureMpvProperties();
    await resetPlayerForOpen(_s._player);
    await _s._player.open(Media(playback.url));
    _s._player.setVolume(_s._volumeNotifier.value);

    final opened = await waitForMediaOpen(
      _s._player,
      streamUrl: playback.url,
      timeout: const Duration(seconds: 45),
    );
    if (!mounted) return;
    if (!opened) {
      _s._statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Torrent failed to open');
    }

    setState(() {
      _s._currentUrl = playback.url;
      _s._activeMagnet = result.magnet;
      _s._hasError = false;
      _s._errorMessage = '';
      _s._currentSources = null;
    });
    _s._playbackConfirmed = true;
    _s._statusController.complete();
    widget.onPlaybackStarted?.call();
    _s._onMouseMove();
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
        return handler(_s._positionNotifier.value, builtInEngine: builtInEngine);
      },
    );
    _s._onMouseMove();
  }

  Future<void> _applyAutoSubtitle() async {
    if (_s._disposed || _s._subtitlePinned) return;
    final embedded = _s._player.state.tracks.subtitle
        .where(
          (t) => t.id != 'no' && t.id != 'auto' && !t.id.startsWith('http'),
        )
        .toList();
    if (embedded.isEmpty) return;
    final track = embedded.first;
    await _s._player.setSubtitleTrack(track);
    _s._updateSubVisibility(track);
    if (mounted) setState(() => _s._selectedExternalSubUrl = null);
  }

  Future<void> _loadPlayerAutoSettings() async {
    final settings = SettingsService();
    final autoServer = await settings.getPlayerAutoServer();
    final autoSource = await settings.getPlayerAutoSource();
    final autoAudio = await settings.getPlayerAutoAudio();
    final autoSubtitle = await settings.getPlayerAutoSubtitle();
    // Hydrate live notifiers used by skip/next episode and the Episodes panel.
    await settings.getAutoNextEpisode();
    await settings.getAutoSkipIntro();
    if (!mounted) return;
    // Respect Auto toggles only. Do not lock because an extract already exists
    // (green Play / cache) — that made dead CDNs hit "no auto failover".
    setState(() {
      _s._providerPinned = !autoServer;
      _s._sourcePinned = !autoSource;
      _s._audioPinned = !autoAudio;
      _s._subtitlePinned = !autoSubtitle;
    });
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    final hasProviders =
        widget.providers != null &&
        widget.providers!.isNotEmpty &&
        widget.movie != null &&
        widget.magnetLink == null &&
        widget.activeProvider != 'stremio_direct';
    final hasSources = _s._currentSources != null && _s._currentSources!.isNotEmpty;

    PlayerPopupPanel.show(
      context: context,
      title: 'Settings',
      anchorContext: anchorContext,
      child: StatefulBuilder(
        builder: (context, setPanelState) {
          return ListView(
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Auto selection',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (hasProviders)
                PlayerPopupListTile(
                  label: 'Auto server',
                  subtitle: !_s._providerPinned ? 'On' : 'Off',
                  selected: !_s._providerPinned,
                  onTap: () async {
                    final settings = SettingsService();
                    if (_s._providerPinned) {
                      await settings.setPlayerAutoServer(true);
                      setState(() => _s._providerPinned = false);
                      setPanelState(() {});
                      await _s._selectAutoProvider();
                    } else {
                      await settings.setPlayerAutoServer(false);
                      setState(() => _s._providerPinned = true);
                      setPanelState(() {});
                    }
                  },
                ),
              if (hasSources)
                PlayerPopupListTile(
                  label: 'Auto source',
                  subtitle: !_s._sourcePinned ? 'On' : 'Off',
                  selected: !_s._sourcePinned,
                  onTap: () async {
                    final settings = SettingsService();
                    if (_s._sourcePinned) {
                      await settings.setPlayerAutoSource(true);
                      setState(() => _s._sourcePinned = false);
                      setPanelState(() {});
                      await _s._selectAutoSource();
                    } else {
                      await settings.setPlayerAutoSource(false);
                      setState(() => _s._sourcePinned = true);
                      setPanelState(() {});
                    }
                  },
                ),
              PlayerPopupListTile(
                label: 'Auto audio',
                subtitle: !_s._audioPinned ? 'On' : 'Off',
                selected: !_s._audioPinned,
                onTap: () async {
                  final settings = SettingsService();
                  if (_s._audioPinned) {
                    await settings.setPlayerAutoAudio(true);
                    setState(() => _s._audioPinned = false);
                    setPanelState(() {});
                    _s._autoTracksAppliedForSource = false;
                    await _s._applyTrackAutoSelect();
                  } else {
                    await settings.setPlayerAutoAudio(false);
                    setState(() => _s._audioPinned = true);
                    setPanelState(() {});
                  }
                },
              ),
              PlayerPopupListTile(
                label: 'Auto subtitles',
                subtitle: !_s._subtitlePinned ? 'On' : 'Off',
                selected: !_s._subtitlePinned,
                onTap: () async {
                  final settings = SettingsService();
                  if (_s._subtitlePinned) {
                    await settings.setPlayerAutoSubtitle(true);
                    setState(() => _s._subtitlePinned = false);
                    setPanelState(() {});
                    await _applyAutoSubtitle();
                  } else {
                    await settings.setPlayerAutoSubtitle(false);
                    setState(() => _s._subtitlePinned = true);
                    setPanelState(() {});
                  }
                },
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video decode',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ForjaShellChip(
                          label: _s._hwDecMode.label,
                          selected: true,
                          radius: 8,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          fontSize: 12,
                          onTap: () {
                            _s._cycleHwDec();
                            setPanelState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _s._hwDecMode.description,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              const SizedBox(height: 4),
              PlayerPopupListTile(
                label: 'Playback speed',
                subtitle: '${_s._player.state.rate}x',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 18,
                ),
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  showSpeedMenu(
                    context,
                    _s._player.state.rate,
                    (s) => _s._player.setRate(s),
                  );
                },
              ),
              PlayerPopupListTile(
                label: 'Aspect ratio',
                subtitle: _s._videoFitLabel,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._cycleAspectRatio();
                },
              ),
              PlayerPopupListTile(
                label: 'Loop',
                subtitle: _s._loopEnabled ? 'On' : 'Off',
                selected: _s._loopEnabled,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _toggleLoop();
                },
              ),
              PlayerPopupListTile(
                label: 'Subtitle style',
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._showSubtitleSettings();
                },
              ),
              if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty)
                PlayerPopupListTile(
                  label: 'Torrent stats',
                  subtitle: _s._showTorrentStatsOverlay ? 'On' : 'Off',
                  selected: _s._showTorrentStatsOverlay,
                  onTap: () async {
                    final next = !_s._showTorrentStatsOverlay;
                    setState(() => _s._showTorrentStatsOverlay = next);
                    setPanelState(() {});
                    await SettingsService().setShowTorrentStatsOverlay(next);
                    _s._syncTorrentStatsSubscription();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<List<StreamSource>?> _loadProvider(String providerId) async {
    final cached = _s._liveProviderSourcesCache.value[providerId];
    if (cached != null && cached.isNotEmpty) {
      _s._markProviderLoadSucceeded(providerId);
      return cached;
    }

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
        episode: widget.selectedEpisode ?? 1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
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
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    VideasyExtractor.cancelPending();
    NuvioService.instance.cancelPending();
    DomainStreamProviderResolver.cancelAllPending();
    _s._statusController.clear();
    _s._playbackConfirmed = false;

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
          episode: widget.selectedEpisode ?? 1,
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
          _s._playbackConfirmed = true;
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
