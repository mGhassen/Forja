part of 'desktop_player_screen.dart';

mixin _DesktopPlayerUi on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  /// Keep the pointer visible while CHECKING SOURCES / episode load is on screen.
  bool get _keepPlayerCursorVisible {
    if (_s._showControls ||
        _s._isInitPlaybackRunning ||
        _s._isLoadingNextEp ||
        _s._hasError ||
        _s._checkingSourceIndices.isNotEmpty) {
      return true;
    }
    return _s._statusController.entries.any(isStatusRouletteEntry);
  }

  bool get _statusBlocksControlsHide {
    if (_s._isLoadingNextEp || _s._checkingSourceIndices.isNotEmpty) {
      return true;
    }
    return _s._statusController.entries.any(isStatusRouletteEntry);
  }

  void _startHideTimer() {
    _s._hideTimer?.cancel();
    if (_s._isInitPlaybackRunning ||
        !_s._playbackConfirmed ||
        _s._hasError ||
        !_s._isPlayingNotifier.value ||
        _statusBlocksControlsHide) {
      return;
    }
    _s._hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          !_s._disposed &&
          !_s._hasError &&
          _s._playbackConfirmed &&
          !_s._isInitPlaybackRunning &&
          !_s._statusBlocksControlsHide) {
        setState(() => _s._showControls = false);
      }
    });
  }

  void _onMouseMove() {
    if (!_s._showControls) setState(() => _s._showControls = true);
    _startHideTimer();
  }

  Movie? get _displayMovie => _s._heroMovie ?? widget.movie;

  String get _displayTitle => _s._displayMovie?.title ?? widget.title;

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

  // ─────────────────────────────────────────────────────────────────────────
  //  FULLSCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    if (!isFull && await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setFullScreen(!isFull);
    if (mounted) setState(() => _s._isFullscreen = !isFull);
  }

  Future<void> _exitPlayer() async {
    if (PlayerStreamMenu.isShowing) {
      PlayerStreamMenu.dismiss();
      return;
    }
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      return;
    }
    if (_s._isFullscreen) {
      await windowManager.setFullScreen(false);
      if (mounted) setState(() => _s._isFullscreen = false);
    }
    _s._cancelPendingStreamWork();
    _s._saveWatchHistory();
    if (mounted) Navigator.of(context).pop(_s._positionNotifier.value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KEYBOARD SHORTCUTS
  // ─────────────────────────────────────────────────────────────────────────

  bool _handleKeyEvent(KeyEvent event) {
    if (!_s._playerReady) return false;
    if (event is! KeyDownEvent) return false;
    _onMouseMove();

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _s._player.playOrPause();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: -30)
          : const Duration(seconds: -10);
      var newPos = _s._positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _s._durationNotifier.value) newPos = _s._durationNotifier.value;
      _s._player.seek(newPos);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: 30)
          : const Duration(seconds: 10);
      var newPos = _s._positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _s._durationNotifier.value) newPos = _s._durationNotifier.value;
      _s._player.seek(newPos);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _s._player.setVolume((_s._volumeNotifier.value + 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _s._player.setVolume((_s._volumeNotifier.value - 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.keyM) {
      _s._player.setVolume(_s._volumeNotifier.value > 0 ? 0.0 : 100.0);
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.escape) {
      unawaited(_exitPlayer());
    } else if (key == LogicalKeyboardKey.keyL) {
      _s._toggleLoop();
    } else {
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ASPECT RATIO CYCLE
  // ─────────────────────────────────────────────────────────────────────────

  /// Short label shown on the pill button for the current fit mode.
  String get _videoFitLabel => switch (_s._videoFit) {
    BoxFit.contain => 'FIT',
    BoxFit.cover => 'CROP',
    BoxFit.fill => 'FILL',
    _ => 'FIT',
  };
}
