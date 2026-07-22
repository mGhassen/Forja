part of 'desktop_player_screen.dart';

mixin _DesktopPlayerEpisodes
    on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
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
    _s._resetEofSessionGuards();
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
      // webstreaming sources list — localhost torrent URLs are filtered as
      // "unplayable extracts" in the server-fallback path.
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      // Keep the librqbit session alive while the outgoing player disposes —
      // otherwise pushReplacement stops the torrent the next episode just started.
      if (resolved.magnetLink != null && resolved.magnetLink!.isNotEmpty) {
        TorrentStreamService().retainForExternalHandoff = true;
      }
      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved!.streamUrl,
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
      currentStreamUrl: _s._currentUrl ?? widget.mediaPath,
      preferredKind: _s._catalogSourceKind,
      currentAddonBaseUrl:
          _s._catalogAddonBaseUrl ?? widget.stremioAddonBaseUrl,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    final precheck = classifyStremioStream(
      stream,
      PlatformPlayback.capabilities,
      useDebrid: useDebrid,
      debridService: debridService,
    );
    // Magnets / infoHash need engine resolve — keep current video + loading
    // card, replace the player only when the new stream is ready.
    if (precheck == null) {
      await _switchStremioMagnetSource(stream);
      return;
    }

    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    final switchGen = ++_s._fallbackGen;
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    _s._markPlaybackConfirmed(false);
    _s._statusController.upsert(
      statusId,
      title,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._fallbackAborted(switchGen)) return;

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
      final openedUrl = await openPlayerStream(
        _s._player,
        url: resolved.streamUrl,
        headers: resolved.headers,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      _s._player.setVolume(_s._volumeNotifier.value);

      final opened = await waitForMediaOpen(
        _s._player,
        streamUrl: openedUrl,
        timeout: isLocalTorrentStreamUrl(openedUrl)
            ? const Duration(seconds: 45)
            : const Duration(seconds: 25),
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!opened) {
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }

      // Catalog switches must show a frame — buffer/audio alone leaves a
      // black picture (common on Nuvio HLS when GPU decode stalls).
      final decoded = await confirmOpenedStreamVideoDecode(
        _s._player,
        openUrl: openedUrl,
        headers: resolved.headers,
        force: true,
      );
      if (!mounted || _s._fallbackAborted(switchGen)) return;
      if (!decoded) {
        debugPrint(
          '[Player] ${catalogStreamKindLabel(stream)} switch opened without video: $openedUrl',
        );
        await _s._player.stop();
        _s._statusController.upsert(
          statusId,
          title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }

      setState(() {
        _s._currentUrl = resolved.streamUrl;
        _s._activeMagnet = resolved.magnetLink;
        _s._hasError = false;
        _s._errorMessage = '';
        _s._currentSources = null;
        final base = stream['_addonBaseUrl']?.toString();
        _s._catalogAddonBaseUrl = base;
        final magnet = resolved.magnetLink;
        final localTorrent = magnet != null &&
            magnet.isNotEmpty &&
            isLocalTorrentStreamUrl(resolved.streamUrl);
        _s._catalogSourceKind = localTorrent
            ? 'torrents'
            : ((base != null && base.startsWith('nuvio:')) ? 'nuvio' : 'stremio');
        _s._currentProvider = 'stremio_direct';
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
      debugPrint('[Player] ${catalogStreamKindLabel(stream)} switch failed: $e');
      _s._statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  /// Stremio/Torrentio magnet — same UX as [_switchTorrentSource]: keep the
  /// current player running with a bottom-right card until the new stream is
  /// ready, then open a fresh player.
  Future<void> _switchStremioMagnetSource(Map<String, dynamic> stream) async {
    if (_s._isLoadingNextEp) return;
    final title = (stream['title'] ?? stream['name'] ?? 'Stremio stream')
        .toString();
    _beginEpisodeLoading(
      label: title,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final settings = SettingsService();
      final useDebrid = await settings.useDebridForStreams();
      final debridService = await settings.getDebridService();
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
        final msg = resolved is StremioResolveFailure && resolved.message.isNotEmpty
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
      final nextTitle = widget.movie != null && season != null && episode != null
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
      debugPrint('[Player] ${catalogStreamKindLabel(stream)} switch failed: $e');
      await _failEpisodeLoading('Failed to resolve stream');
    }
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    if (_s._isLoadingNextEp) return;
    // Keep current video playing with the loading card while the new magnet
    // resolves in the background. Only replace the player when the stream is
    // ready — never tear down the active swarm first (that freezes mpv).
    _beginEpisodeLoading(
      label: result.name,
      status: 'Starting Local Torrent Engine…',
    );
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final settings = SettingsService();
      final useDebrid = await settings.useDebridForStreams();
      final debridService = await settings.getDebridService();
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
      final nextTitle = widget.movie != null && season != null && episode != null
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
            builder: (context, setPage) => Row(
              children: [
                for (final mode in _HwDecMode.values) ...[
                  if (mode != _HwDecMode.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: PlayerPopupOptionChip(
                      label: mode.label,
                      selected: _s._hwDecMode == mode,
                      expanded: true,
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
                  ),
                ],
              ],
            ),
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
              return Wrap(
                spacing: 8,
                runSpacing: 8,
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
            builder: (context, setPage) => Row(
              children: [
                for (final entry in const [
                  (BoxFit.contain, 'FIT'),
                  (BoxFit.cover, 'CROP'),
                  (BoxFit.fill, 'FILL'),
                ]) ...[
                  if (entry.$1 != BoxFit.contain) const SizedBox(width: 8),
                  Expanded(
                    child: PlayerPopupOptionChip(
                      label: entry.$2,
                      selected: _s._videoFit == entry.$1,
                      expanded: true,
                      onTap: () {
                        setState(() => _s._videoFit = entry.$1);
                        setPage(() {});
                      },
                    ),
                  ),
                ],
              ],
            ),
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

    // One host WebView — abandon other in-flight Source-panel loads.
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
        episode: widget.hubEpisodeNumber?.toInt() ??
            widget.selectedEpisode ??
            1,
        isCancelled: () =>
            _s._disposed || (_s._providerLoadGens[providerId] ?? 0) != gen,
        bypassDiskCache: forceRefresh,
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
        // Current server list prefers live [_currentSources] over session
        // cache — refresh it so panel reload is not a no-op after cache play.
        if (forceRefresh &&
            (_s._currentProvider == providerId ||
                ((_s._currentProvider == null || _s._currentProvider!.isEmpty) &&
                    widget.activeProvider == providerId))) {
          _s._currentSources = sources;
          _s._failedSourceIndices.clear();
          _s._checkingSourceIndices.clear();
        }
        _s._markProviderLoadSucceeded(providerId);
        _s._scoreServerUp(providerId);
        _s._sourceMenuRevision.value++;
        return sources;
      }
      // Re-extract miss while this server is still playing must not paint it
      // dead — live URL is still open in the player.
      final playingSame = _s._playbackConfirmed &&
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
        final playingSame = _s._playbackConfirmed &&
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
          episode: widget.hubEpisodeNumber?.toInt() ??
              widget.selectedEpisode ??
              1,
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
        );
        if (_s._fallbackAborted(gen)) return null;

        final opened = await waitForMediaOpen(
          _s._player,
          streamUrl: streamUrl,
          timeout: const Duration(seconds: 25),
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
