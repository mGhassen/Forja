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
}
