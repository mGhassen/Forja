part of 'mobile_player_screen.dart';

mixin _MobilePlayerUi on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  // ─────────────────────────────────────────────────────────────────────────
  //  UI HIDE TIMER
  // ─────────────────────────────────────────────────────────────────────────

  void _revealChrome() {
    if (!_s._showControls || _s._escapeExitArmed) {
      setState(() {
        _s._showControls = true;
        _s._escapeExitArmed = false;
      });
    }
    _syncChromeHideTimer();
  }

  void _syncChromeHideTimer() {
    if (!_s._showControls || _s._isLocked) {
      _s._hideTimer?.cancel();
      return;
    }
    _startHideTimer();
  }

  void _onPlayerStatusForChromeHide() {
    _syncChromeHideTimer();
  }

  void _startHideTimer() {
    _s._hideTimer?.cancel();
    if (_s._isInitPlaybackRunning ||
        !_s._playbackConfirmed ||
        _s._hasError ||
        !_s._isPlayingNotifier.value) {
      return;
    }
    if (playerChromeOverlayBlocksSeek()) return;
    final hideAfter = widget.tvRemoteEnabled
        ? const Duration(seconds: 10)
        : const Duration(seconds: 3);
    _s._hideTimer = Timer(hideAfter, () {
      if (mounted &&
          !_s._disposed &&
          !_s._hasError &&
          _s._playbackConfirmed &&
          !_s._isInitPlaybackRunning) {
        if (playerChromeOverlayBlocksSeek()) {
          _startHideTimer();
          return;
        }
        setState(() {
          _s._showControls = false;
          _s._escapeExitArmed = false;
        });
        if (widget.tvRemoteEnabled) {
          playerTvClaimVideoKeyFocusAfterHide(
            _s._tvKeyFocus,
            mounted: () => mounted,
          );
        }
      }
    });
  }

  Movie? get _displayMovie => _s._heroMovie ?? widget.movie;

  String get _displayTitle => _displayMovie?.title ?? widget.title;

  String? get _hubEpisodeLine {
    if (widget.episodes == null) return null;
    final n = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (n == null) return null;
    final ep = n == n.truncateToDouble() ? n.toInt() : n;
    final season = widget.selectedSeason;
    if (season != null) return 'S$season E$ep';
    return 'Episode $ep';
  }

  String? get _pausedEpisodeOverview =>
      widget.episodeOverview ?? _s._episodeOverview;

  Future<void> _loadHeroMetadata() async {
    final movie = widget.movie;
    if (movie == null) return;
    final hubEpisodes = widget.episodes != null;
    // Hub episode lists own episode overview; still enrich thin title meta
    // (logo / synopsis / genres) when the pack did not ship them.
    if (hubEpisodes && !playerNeedsRichMetadata(movie)) return;
    final metadata = await loadPlayerHeroMetadata(
      movie: movie,
      season: hubEpisodes ? null : widget.selectedSeason,
      episode: hubEpisodes ? null : widget.selectedEpisode,
    );
    if (!mounted || metadata == null) return;
    setState(() {
      _s._heroMovie = metadata.movie;
      if (!hubEpisodes) {
        _s._episodeOverview = metadata.episodeOverview;
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _s._showControls = !_s._showControls;
      if (_s._showControls) _s._escapeExitArmed = false;
    });
    if (_s._showControls) {
      _startHideTimer();
      if (widget.tvRemoteEnabled) _claimPlayFocus();
    } else {
      _s._hideTimer?.cancel();
    }
  }

  void _claimPlayFocus() {
    if (!widget.tvRemoteEnabled) return;
    // Sync + one-frame retry — deferred-only left seek ↑/↓ stuck (issue 130).
    void tryClaim() {
      if (!mounted || !_s._playFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _s._playFocus.requestFocus();
    }

    tryClaim();
    if (!_s._playFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
    }
  }

  void _claimBackFocus() {
    if (!widget.tvRemoteEnabled) return;
    void tryClaim() {
      if (!mounted || !_s._backFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _s._backFocus.requestFocus();
    }

    tryClaim();
    if (!_s._backFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
    }
  }

  void _toggleLock() {
    setState(() {
      _s._isLocked = !_s._isLocked;
      _s._showControls = !_s._isLocked;
    });
    if (!_s._isLocked) _startHideTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GESTURE HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Double tap left / right: seek ∓10 s. Repeated taps on the same side
  /// extend the burst (see [PlayerTapSeekBurst]); feedback shows the total.
  void _handleDoubleTap(TapDownDetails details, bool isRight) {
    if (_s._isLocked) return;
    final target = _s._tapSeek.doubleTap(
      forward: isRight,
      now: DateTime.now(),
      position: _s._positionNotifier.value,
      duration: _s._durationNotifier.value,
    );
    _applyTapSeek(target, details.localPosition);
  }

  /// Single tap: extends a live seek burst on the same side, else toggles
  /// the chrome.
  void _handleTap(TapUpDetails details, bool isRight) {
    if (!_s._isLocked) {
      final target = _s._tapSeek.singleTap(
        forward: isRight,
        now: DateTime.now(),
        duration: _s._durationNotifier.value,
      );
      if (target != null) {
        _applyTapSeek(target, details.localPosition);
        return;
      }
    }
    _toggleControls();
  }

  void _applyTapSeek(Duration target, Offset at) {
    setState(() {
      _s._showTapSeek = true;
      _s._tapSeekPulse++;
      _s._tapSeekPosition = at;
    });
    unawaited(_s._seekTo(target));
    _s._tapSeekHideTimer?.cancel();
    // Feedback stays while the burst can still be extended.
    _s._tapSeekHideTimer = Timer(_s._tapSeek.window, () {
      _s._tapSeek.reset();
      if (mounted && !_s._disposed) {
        setState(() => _s._showTapSeek = false);
      }
    });
    if (_s._showControls) _startHideTimer();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double width) {
    if (_s._isLocked) return;

    final isRight = details.localPosition.dx > width / 2;
    // delta is inverted: drag up = positive = increase
    final delta = -details.primaryDelta! / 3;

    if (isRight) {
      _s._volume = (_s._volume + delta).clamp(0.0, 150.0);
      _s._player.setVolume(_s._mpvVolume);
      setState(() {
        _s._showVolumeIndicator = true;
        _s._showBrightnessIndicator = false;
      });
    } else {
      _s._brightness = (_s._brightness + delta / 300).clamp(0.0, 1.0);
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          ScreenBrightness().setApplicationScreenBrightness(_s._brightness);
        } catch (_) {}
      }
      setState(() {
        _s._showBrightnessIndicator = true;
        _s._showVolumeIndicator = false;
      });
    }

    _s._indicatorHideTimer?.cancel();
    _s._indicatorHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _s._showVolumeIndicator = false;
          _s._showBrightnessIndicator = false;
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ASPECT RATIO
  // ─────────────────────────────────────────────────────────────────────────

  String get _videoFitLabel => switch (_s._videoFit) {
    BoxFit.contain => 'FIT',
    BoxFit.cover => 'CROP',
    BoxFit.fill => 'FILL',
    _ => 'FIT',
  };
}
