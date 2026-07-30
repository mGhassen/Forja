part of 'mobile_player_screen.dart';

mixin _MobilePlayerUi on ConsumerState<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  // ─────────────────────────────────────────────────────────────────────────
  //  UI HIDE TIMER
  // ─────────────────────────────────────────────────────────────────────────

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
        if (widget.tvRemoteEnabled &&
            playerTvChromeHasFocus(_s._tvKeyFocus)) {
          _startHideTimer();
          return;
        }
        setState(() => _s._showControls = false);
      }
    });
  }

  Movie? get _displayMovie => _s._heroMovie ?? widget.movie;

  String get _displayTitle => _displayMovie?.title ?? widget.title;

  String? get _hubEpisodeLine {
    if (widget.hubEpisodes == null) return null;
    final n = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (n == null) return null;
    return 'Episode ${n == n.truncateToDouble() ? n.toInt() : n}';
  }

  String? get _pausedEpisodeOverview =>
      widget.episodeOverview ?? _s._episodeOverview;

  Future<void> _loadHeroMetadata() async {
    if (widget.hubEpisodes != null) return;
    final movie = widget.movie;
    if (movie == null) return;
    final metadata = await loadPlayerHeroMetadata(
      movie: movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted || metadata == null) return;
    setState(() {
      _s._heroMovie = metadata.movie;
      _s._episodeOverview = metadata.episodeOverview;
    });
  }

  void _toggleControls() {
    setState(() => _s._showControls = !_s._showControls);
    if (_s._showControls) {
      _startHideTimer();
      if (widget.tvRemoteEnabled) _claimPlayFocus();
    } else {
      _s._hideTimer?.cancel();
    }
  }

  void _claimPlayFocus() {
    if (!widget.tvRemoteEnabled) return;
    _s._tvBackExitArmed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._playFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _s._playFocus.requestFocus();
    });
  }

  void _claimBackFocus() {
    if (!widget.tvRemoteEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._backFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _s._backFocus.requestFocus();
    });
  }

  void _nudgeTvVolume(double delta) {
    final next = (_s._volume + delta).clamp(0.0, 150.0);
    _s._volume = next;
    _s._player.setVolume(next);
    setState(() {
      _s._showVolumeIndicator = true;
      _s._showBrightnessIndicator = false;
    });
    _s._indicatorHideTimer?.cancel();
    _s._indicatorHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _s._showVolumeIndicator = false);
      }
    });
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

  void _handleDoubleTap(TapDownDetails details, bool isRight) {
    if (_s._isLocked) return;
    setState(() {
      _s._showRipple = true;
      _s._isForward = isRight;
      _s._ripplePosition = details.localPosition;
    });
    _s._rippleController.forward(from: 0.0);

    // Calculate new position and clamp to valid range
    final currentPos = _s._positionNotifier.value;
    final duration = _s._durationNotifier.value;
    final delta = isRight
        ? const Duration(seconds: 10)
        : const Duration(seconds: -10);
    var newPos = currentPos + delta;

    // Clamp to valid range [0, duration]
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (newPos > duration) {
      newPos = duration;
    }

    _s._seekTo(newPos);
    _startHideTimer();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double width) {
    if (_s._isLocked) return;

    final isRight = details.localPosition.dx > width / 2;
    // delta is inverted: drag up = positive = increase
    final delta = -details.primaryDelta! / 3;

    if (isRight) {
      _s._volume = (_s._volume + delta).clamp(0.0, 150.0);
      _s._player.setVolume(_s._volume);
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
