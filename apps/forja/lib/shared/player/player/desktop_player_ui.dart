part of 'desktop_player_screen.dart';

mixin _DesktopPlayerUi on ConsumerState<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
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

  void _armEscapeExit() {
    _s._escapeExitArmed = true;
  }

  void _revealChrome() {
    _s._escapeExitArmed = false;
    _s._escapeHandledAt = null;
    if (!_s._showControls) {
      setState(() => _s._showControls = true);
    }
    _syncChromeHideTimer();
  }

  /// Hide chrome and block hover re-show briefly (cursor-none + MouseRegion
  /// rebuild otherwise re-fires [onHover] and leaves chrome stuck visible).
  /// Auto-hide must not leave Escape armed — first Escape after idle hide
  /// only arms; second exits.
  void _hideChromeIntentional({bool armEscape = false}) {
    _s._hideTimer?.cancel();
    _s._suppressChromeRevealUntil =
        DateTime.now().add(const Duration(milliseconds: 450));
    _s._lastHoverPos = null;
    if (!armEscape) {
      _s._escapeExitArmed = false;
    }
    if (!_s._showControls) return;
    setState(() => _s._showControls = false);
  }

  /// Single Escape ladder for HW / DismissIntent / Shortcuts. Same-pulse
  /// re-entry is a no-op so one key cannot arm then leave.
  void _handleEscapeKey() {
    debugPrint(
      '[DesktopPlayer] Escape down armed=${_s._escapeExitArmed} '
      'chrome=${_s._showControls} fs=${_s._isFullscreen}',
    );
    final handledAt = _s._escapeHandledAt;
    if (handledAt != null &&
        DateTime.now().difference(handledAt) <
            const Duration(milliseconds: 80)) {
      debugPrint(
        '[DesktopPlayer] Escape ignored (same pulse, armed=${_s._escapeExitArmed})',
      );
      return;
    }
    _s._escapeHandledAt = DateTime.now();
    PlayerBackExitGate.notePlayerEscapeHandled();

    if (dismissAnyPlayerChromeOverlay()) {
      debugPrint(
        '[DesktopPlayer] Escape → dismiss overlay (stay) armed=${_s._escapeExitArmed}',
      );
      return;
    }
    // Fullscreen first — Escape must leave OS fullscreen, not the player.
    unawaited(_escapeLeaveFullscreenOrContinue());
  }

  Future<void> _escapeLeaveFullscreenOrContinue() async {
    final osFull = DesktopWindowGeometry.isDesktop &&
        await windowManager.isFullScreen();
    debugPrint(
      '[DesktopPlayer] Escape ladder armed=${_s._escapeExitArmed} '
      'chrome=${_s._showControls} fs=${_s._isFullscreen} osFull=$osFull',
    );
    if (osFull || _s._isFullscreen) {
      debugPrint(
        '[DesktopPlayer] Escape → exit fullscreen (stay) armed=${_s._escapeExitArmed}',
      );
      await DesktopWindowGeometry.exitFullscreen();
      if (!mounted || _s._disposed) return;
      setState(() {
        _s._isFullscreen = false;
        _s._escapeExitArmed = false;
      });
      debugPrint('[DesktopPlayer] Escape fullscreen done armed=${_s._escapeExitArmed}');
      return;
    }
    if (_s._showControls) {
      // Hide only — do not arm. Next Escape arms; then confirm exits.
      debugPrint(
        '[DesktopPlayer] Escape → hide chrome (no arm) wasArmed=${_s._escapeExitArmed}',
      );
      _hideChromeIntentional(armEscape: false);
      debugPrint('[DesktopPlayer] Escape after hide armed=${_s._escapeExitArmed}');
      return;
    }
    if (!_s._escapeExitArmed) {
      debugPrint('[DesktopPlayer] Escape → arm only (armed=false → true)');
      _armEscapeExit();
      debugPrint('[DesktopPlayer] Escape after arm armed=${_s._escapeExitArmed}');
      return;
    }
    debugPrint(
      '[DesktopPlayer] Escape → confirm exit (armed=true)',
    );
    _s._escapeExitArmed = false;
    await _exitPlayer();
  }

  @override
  void onWindowEnterFullScreen() {
    if (!mounted || _s._disposed) return;
    setState(() => _s._isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (!mounted || _s._disposed) return;
    setState(() {
      _s._isFullscreen = false;
      _s._escapeExitArmed = false;
    });
  }

  void _syncChromeHideTimer() {
    if (!_s._showControls) {
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
        _hideChromeIntentional();
      }
    });
  }

  /// Real pointer motion over the video — ignore zero-delta / suppressed hovers.
  void _onPointerHover(PointerHoverEvent event) {
    final until = _s._suppressChromeRevealUntil;
    if (until != null && DateTime.now().isBefore(until)) return;
    final pos = event.position;
    final last = _s._lastHoverPos;
    if (last != null && (last - pos).distanceSquared < 0.25) return;
    _s._lastHoverPos = pos;
    _revealChrome();
  }

  void _onMouseMove() {
    // Tap / key / chrome button — always show.
    _s._suppressChromeRevealUntil = null;
    _revealChrome();
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
    final next = await DesktopWindowGeometry.toggleFullscreen();
    if (mounted) setState(() => _s._isFullscreen = next);
  }

  Future<void> _exitPlayer() async {
    // Escape + Back (or held Escape) can re-enter while stop awaits - second
    // pop throws Bad state: No element / !_debugLocked.
    if (_s._exitInProgress || _s._disposed) return;
    // First Back closes an open panel/menu; second exits (mobile parity).
    // Escape uses local [_handleEscapeKey] — force path skips overlay-only return.
    if (!_s._bypassEscapeArm && dismissAnyPlayerChromeOverlay()) return;
    _s._bypassEscapeArm = false;
    _s._escapeExitArmed = false;
    _s._escapeHandledAt = null;
    _s._exitInProgress = true;
    // Capture before awaits - State may unmount during stop; dismiss must still run.
    final nav = Navigator.of(context, rootNavigator: true);
    final result = _s._positionNotifier.value;
    await DesktopWindowGeometry.leavePlayerChrome();
    if (mounted) setState(() => _s._isFullscreen = false);
    _s._cancelPendingStreamWork();
    await _s._saveWatchHistory();
    // Instant native mute/pause/ao=null - do not await hung media_kit stop
    // before popping (that left the UI stuck with audio still playing).
    await _s._stopPlaybackForExit();
    // Strip loading under the player first — pop-then-dismiss paints resolve UI.
    dismissActiveLoadingOverlayRoute(nav);
    if (nav.mounted && nav.canPop()) {
      nav.pop(result);
    }
  }

  /// Back icon / mouse Back / trackpad — leave immediately (no Escape arm).
  void _forceLeavePlayer() {
    _s._bypassEscapeArm = true;
    unawaited(_exitPlayer());
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KEYBOARD SHORTCUTS
  // ─────────────────────────────────────────────────────────────────────────

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Allow leaving while the player shell is still initializing (black
    // spinner). Other shortcuts wait until controls are ready.
    if (!_s._playerReady) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _forceLeavePlayer();
        return true;
      }
      return false;
    }

    final key = event.logicalKey;

    // Space toggles playback only — do not reveal chrome (mouse / other keys do).
    if (key == LogicalKeyboardKey.space) {
      _s._player.playOrPause();
      if (_s._showControls) _startHideTimer();
      return true;
    }

    // Escape: one local ladder. Never maybePop — Flutter DismissIntent and
    // Shortcuts also see Escape; maybePop let a twin arm then leave.
    if (key == LogicalKeyboardKey.escape) {
      _handleEscapeKey();
      return true;
    }

    _onMouseMove();

    if (key == LogicalKeyboardKey.arrowLeft) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: -30)
          : const Duration(seconds: -10);
      var newPos = _s._positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _s._durationNotifier.value) newPos = _s._durationNotifier.value;
      unawaited(_s._seekTo(newPos));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: 30)
          : const Duration(seconds: 10);
      var newPos = _s._positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _s._durationNotifier.value) newPos = _s._durationNotifier.value;
      unawaited(_s._seekTo(newPos));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _s._player.setVolume((_s._volumeNotifier.value + 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _s._player.setVolume((_s._volumeNotifier.value - 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.keyM) {
      _s._player.setVolume(_s._volumeNotifier.value > 0 ? 0.0 : 100.0);
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
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
