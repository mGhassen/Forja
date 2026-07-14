part of 'mobile_player_screen.dart';

mixin _MobilePlayerEpisodes on State<MobilePlayerScreen> {
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

  // ─────────────────────────────────────────────────────────────────────────
  //  NEXT EPISODE
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isNextEpisodeAvailable =>
      (widget.onNextEpisode != null && widget.hasNextEpisode) ||
      (widget.movie != null &&
          widget.movie!.mediaType == 'tv' &&
          widget.selectedSeason != null &&
          widget.selectedEpisode != null);

  bool get _showNextEpButton =>
      _isNextEpisodeAvailable && (_s._nearEndOfEpisode || _s._isLoadingNextEp);

  Future<void> _nextEpisode() async {
    if (!_isNextEpisodeAvailable || _s._isLoadingNextEp) return;

    setState(() => _s._isLoadingNextEp = true);

    // Anime / external resolver path — the caller knows how to fetch the
    // next episode and will navigate themselves. Save history first so the
    // current position isn't lost.
    if (widget.onNextEpisode != null) {
      try {
        _s._saveWatchHistory();
        await widget.onNextEpisode!();
      } catch (e) {
        if (mounted) {
          _s._statusController.upsert(
            'episode',
            'Next episode failed',
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
          setState(() => _s._isLoadingNextEp = false);
        }
      }
      return;
    }

    final next = await _s._computeNextEpisode();
    if (next == null) {
      if (mounted) setState(() => _s._isLoadingNextEp = false);
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
      setState(() => _s._isLoadingNextEp = true);
      try {
        _s._saveWatchHistory();
        await widget.onHubEpisodeSelected!(widget.hubEpisodes![idx - 1]);
      } catch (e) {
        if (mounted) {
          _s._statusController.upsert(
            'episode',
            'Previous episode failed',
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
          setState(() => _s._isLoadingNextEp = false);
        }
      }
      return;
    }

    setState(() => _s._isLoadingNextEp = true);
    final prev = await _s._computePreviousEpisode();
    if (prev == null) {
      if (mounted) setState(() => _s._isLoadingNextEp = false);
      return;
    }
    await _s._switchToEpisode(prev.season, prev.episode);
  }

  void _seekBack10Seconds() {
    final pos = _s._positionNotifier.value - const Duration(seconds: 10);
    _s._player.seek(pos < Duration.zero ? Duration.zero : pos);
    _s._startHideTimer();
  }

  void _seekForward10Seconds() {
    final dur = _s._durationNotifier.value;
    final pos = _s._positionNotifier.value + const Duration(seconds: 10);
    _s._player.seek(pos > dur ? dur : pos);
    _s._startHideTimer();
  }

  Widget _buildTransportBackButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    FocusNode? focusNode,
    int? tvFocusOrder,
  }) {
    Widget button;
    if (_s._hasPrevEpisodeAdjacent) {
      button = PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        icon: Icons.skip_previous_rounded,
        tooltip: 'Previous Episode',
        size: btnSize,
        iconSize: iconSz,
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_previousEpisode());
        },
      );
    } else {
      button = PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        focusNode: focusNode,
        icon: Icons.replay_10_rounded,
        tooltip: 'Back 10s',
        size: btnSize,
        iconSize: iconSz,
        onPressed: _seekBack10Seconds,
      );
    }
    if (tvFocusOrder != null) {
      return FocusTraversalOrder(
        order: NumericFocusOrder(tvFocusOrder.toDouble()),
        child: button,
      );
    }
    return button;
  }

  Widget _buildTransportForwardButton({
    required double btnSize,
    required double iconSz,
    bool tvFocusable = false,
    int? tvFocusOrder,
  }) {
    Widget button;
    if (_s._hasNextEpisodeAdjacent) {
      button = PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        icon: Icons.skip_next_rounded,
        tooltip: 'Next Episode',
        size: btnSize,
        iconSize: iconSz,
        onPressed: () {
          if (_s._isLoadingNextEp) return;
          unawaited(_nextEpisode());
        },
      );
    } else {
      button = PlayerFlatIconButton(
        tvFocusable: tvFocusable,
        icon: Icons.forward_10_rounded,
        tooltip: 'Forward 10s',
        size: btnSize,
        iconSize: iconSz,
        onPressed: _seekForward10Seconds,
      );
    }
    if (tvFocusOrder != null) {
      return FocusTraversalOrder(
        order: NumericFocusOrder(tvFocusOrder.toDouble()),
        child: button,
      );
    }
    return button;
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

  String _episodeSwitchStatusLabel(
    int season,
    int episode, {
    String? providerKey,
  }) {
    final key = providerKey ?? _s._currentProvider ?? widget.activeProvider;
    if (key != null) {
      return PlayerProviderMenu.snackbarLabel(key, widget.providers?[key]);
    }
    if (widget.magnetLink != null) return 'Torrents';
    return 'S$season E$episode';
  }

  void _showEpisodeSwitchStatus(
    int season,
    int episode, {
    String? providerKey,
  }) {
    _s._statusController.upsert(
      'episode-switch',
      _episodeSwitchStatusLabel(season, episode, providerKey: providerKey),
      kind: StatusRouletteKind.loading,
    );
  }

  Future<void> _switchToEpisode(int season, int episode) async {
    if (widget.movie == null) return;
    if (!_s._isLoadingNextEp && mounted) setState(() => _s._isLoadingNextEp = true);
    _showEpisodeSwitchStatus(season, episode);

    try {
      debugPrint('[EpSwitch] Playing S${season}E$episode');
      _s._saveWatchHistory();

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
      if (mounted) {
        _s._statusController.upsert(
          'episode-switch',
          _episodeSwitchStatusLabel(season, episode),
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        setState(() => _s._isLoadingNextEp = false);
      }
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
        onEpisodeSelected: widget.onHubEpisodeSelected!,
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
}
