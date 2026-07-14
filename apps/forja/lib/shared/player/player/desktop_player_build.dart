part of 'desktop_player_screen.dart';

mixin _DesktopPlayerBuild on State<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  @override
  Widget build(BuildContext context) {
    if (!_s._playerReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      );
    }

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (_) => _s._onMouseMove(),
          cursor: _s._showControls
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video ────────────────────────────────────────────────
              Video(
                controller: _s._controller,
                controls: NoVideoControls,
                fit: _s._videoFit,
                fill: Colors.black,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  visible: false,
                ),
              ),

              // Double-click empty video area → toggle fullscreen
              // (controls chrome sits above and keeps its own hit targets).
              if (!_s._isPipMode)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => unawaited(_s._toggleFullscreen()),
                    child: const SizedBox.expand(),
                  ),
                ),

              // ── Custom subtitle overlay ──────────────────────────────
              // Auto-scales relative to the rendered window height so
              // the text stays readable in normal mode, fullscreen, AND
              // shrinks proportionally when in PiP (480x270).
              // Custom subtitle overlay — hidden when mpv natively handles
              // ASS/SSA or image-based subtitles (they render on the video frame instead).
              if (!_s._isNativeSubtitle)
                StreamBuilder<List<String>>(
                  stream: _s._player.stream.subtitle,
                  initialData: _s._player.state.subtitle,
                  builder: (context, snap) {
                    final lines = snap.data ?? [];
                    final text = lines
                        .where((l) => l.trim().isNotEmpty)
                        .join('\n');
                    if (text.isEmpty) return const SizedBox.shrink();
                    const refHeight = 720.0;
                    final winH = MediaQuery.of(context).size.height;
                    final scale = (winH / refHeight).clamp(0.35, 1.0);
                    final hSidePad = 24.0 * scale;
                    return Positioned(
                      left: hSidePad,
                      right: hSidePad,
                      bottom: _s._subtitleBottomPadding * scale,
                      child: IgnorePointer(
                        child: Text(
                          text,
                          style: _s._buildSubtitleTextStyle(scale: scale),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),

              // ── Controls Overlay ─────────────────────────────────────
              // Hidden entirely while PiP is active — replaced by the
              // floating revert button below.
              if (!_s._isPipMode)
                AnimatedOpacity(
                  opacity: _s._showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_s._showControls,
                    child: _buildControlsOverlay(),
                  ),
                ),

              // ── PiP revert button (hover-only) ───────────────────────
              if (_s._isPipMode) _buildPipRevertOverlay(),

              PlayerStatusOverlay(
                controller: _s._statusController,
                bufferingListenable: _s._isBufferingNotifier,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating revert button shown only while desktop PiP is active.
  /// Transparent hover region across the whole window; the button itself
  /// fades in only when the cursor is over the PiP, so the picture stays
  /// clean otherwise. Click exits PiP and restores the window chrome.
  Widget _buildPipRevertOverlay() {
    return MouseRegion(
      opaque: false,
      onEnter: (_) {
        if (mounted && !_s._pipHover) setState(() => _s._pipHover = true);
      },
      onExit: (_) {
        if (mounted && _s._pipHover) setState(() => _s._pipHover = false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-window drag handle so the user can click+drag the
          // frameless PiP window around the desktop. DragToMoveArea
          // listens for primary-button drags and forwards them to the
          // OS via window_manager.
          const Positioned.fill(
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: _s._pipHover ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_s._pipHover,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await PipService.instance.leave();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final isTv = widget.movie?.mediaType == 'tv';
    final hasEpisodePicker =
        (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
    final hasStreamPicker = _s._hasStreamPicker;
    final hasTorrentSources =
        widget.movie != null &&
        ((_s._activeMagnet ?? widget.magnetLink)?.isNotEmpty ?? false);
    final compact = MediaQuery.sizeOf(context).width < 900;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusMessage: _s._hasError,
      hasStatusActions: _s._hasError,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PlayerOverlayGradient(isTop: true),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: PlayerOverlayGradient(isTop: false),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PlayerTopBar(
            title: _s._displayTitle,
            season: widget.hubEpisodes != null ? null : widget.selectedSeason,
            episode: widget.hubEpisodes != null ? null : widget.selectedEpisode,
            episodeLine: _s._hubEpisodeLine,
            statusMessage: _s._hasError ? _s._errorMessage : null,
            statusActions: _s._hasError
                ? PlayerTopStatusActions(
                    onRetry: _s._initPlayback,
                    onStream: hasStreamPicker ? _s._showStreamMenu : null,
                  )
                : null,
            onBack: () async {
              if (_s._isFullscreen) {
                await windowManager.setFullScreen(false);
                setState(() => _s._isFullscreen = false);
              }
              _s._cancelPendingStreamWork();
              _s._saveWatchHistory();
              if (mounted) Navigator.of(context).pop(_s._positionNotifier.value);
            },
            trailing: PlayerTopBarActions(
              showPlayer: widget.onSwitchPlayer != null,
              onPlayer: widget.onSwitchPlayer != null
                  ? (anchorContext) => unawaited(_s._showPlayerMenu(anchorContext))
                  : null,
              showCast:
                  CastingService.instance.isAirPlayAvailable ||
                  CastingService.instance.isChromecastAvailable,
              onCast: () {
                showPlayerCastPicker(
                  context,
                  streamUrl: _s._currentUrl,
                  title: widget.title,
                  headers: widget.headers,
                  statusController: _s._statusController,
                );
                _s._onMouseMove();
              },
              showPip: PipService.instance.isSupported,
              pipActive: PipService.instance.isDesktopActive,
              onPip: () async {
                await PipService.instance.toggle();
                if (mounted) setState(() {});
                _s._onMouseMove();
              },
            ),
          ),
        ),

        if (_s._displayMovie != null)
          Positioned(
            left: 0,
            top: topBarHeight,
            bottom: 120,
            child: ValueListenableBuilder<bool>(
              valueListenable: _s._isPlayingNotifier,
              builder: (context, playing, _) => AnimatedOpacity(
                opacity: playing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: playing,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PlayerPausedHero(
                      movie: _s._displayMovie!,
                      season: widget.hubEpisodes != null
                          ? null
                          : widget.selectedSeason,
                      episode: widget.hubEpisodes != null
                          ? null
                          : widget.selectedEpisode,
                      episodeLine: _s._hubEpisodeLine,
                      episodeOverview: _s._pausedEpisodeOverview,
                    ),
                  ),
                ),
              ),
            ),
          ),

        ListenableBuilder(
          listenable: playerStatusOverlayListenable(
            _s._statusController,
            _s._isBufferingNotifier,
          ),
          builder: (context, _) {
            if (playerStatusOverlayVisible(
              _s._statusController,
              _s._isBufferingNotifier.value,
            )) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerCenterActionButton(
                      icon: Icons.replay_10_rounded,
                      onPressed: () {
                        final pos =
                            _s._positionNotifier.value -
                            const Duration(seconds: 10);
                        _s._player.seek(pos < Duration.zero ? Duration.zero : pos);
                        _s._onMouseMove();
                      },
                    ),
                    const SizedBox(width: 28),
                    ValueListenableBuilder<bool>(
                      valueListenable: _s._isPlayingNotifier,
                      builder: (context, playing, _) =>
                          PlayerCenterActionButton(
                            icon: playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 80,
                            iconSize: 44,
                            onPressed: () {
                              _s._player.playOrPause();
                              _s._onMouseMove();
                            },
                          ),
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: Icons.forward_10_rounded,
                      onPressed: () {
                        final dur = _s._durationNotifier.value;
                        final pos =
                            _s._positionNotifier.value +
                            const Duration(seconds: 10);
                        _s._player.seek(pos > dur ? dur : pos);
                        _s._onMouseMove();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        if (_s._activeSkipLabel != null && !_s._skipDismissed)
          Positioned(
            bottom: _s._showNextEpButton ? 155 : 100,
            right: 24,
            child: PlayerFloatingChip(
              label: _s._activeSkipLabel!,
              onPressed: _s._performSkip,
            ),
          ),

        if (_s._showNextEpButton)
          Positioned(
            bottom: 100,
            right: 24,
            child: PlayerFloatingChip(
              label: 'Next Episode',
              loading: _s._isLoadingNextEp,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _s._isLoadingNextEp ? null : _s._nextEpisode,
            ),
          ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_s._showTorrentStatsOverlay &&
                    _s._torrentStats != null &&
                    widget.magnetLink != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      // Lift above Skip Intro / Next Episode when those sit bottom-right.
                      padding: EdgeInsets.only(bottom: 8 + _s._torrentStatsLift),
                      child: PlayerTorrentStatsCard(stats: _s._torrentStats!),
                    ),
                  ),
                ValueListenableBuilder<Duration>(
                  valueListenable: _s._durationNotifier,
                  builder: (context, duration, _) =>
                      ValueListenableBuilder<Duration>(
                        valueListenable: _s._positionNotifier,
                        builder: (context, position, _) =>
                            ValueListenableBuilder<Duration>(
                              valueListenable: _s._bufferedNotifier,
                              builder: (context, buffered, _) =>
                                  SeekBarWithPreview(
                                    duration: duration,
                                    position: position,
                                    bufferedPosition: buffered,
                                    captureFrame: _s._captureSeekPreview,
                                    onSeek: (t) {
                                      _s._player.seek(t);
                                      _s._onMouseMove();
                                    },
                                    onDragStart: () => _s._hideTimer?.cancel(),
                                    onDragEnd: _s._startHideTimer,
                                  ),
                            ),
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _s._isPlayingNotifier,
                          builder: (context, playing, _) =>
                              PlayerFlatIconButton(
                                icon: playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                tooltip: playing ? 'Pause' : 'Play',
                                onPressed: () {
                                  _s._player.playOrPause();
                                  _s._onMouseMove();
                                },
                              ),
                        ),
                        const SizedBox(width: 2),
                        _s._buildTransportBackButton(),
                        const SizedBox(width: 2),
                        _s._buildTransportForwardButton(),
                        const SizedBox(width: 6),
                        ValueListenableBuilder<double>(
                          valueListenable: _s._volumeNotifier,
                          builder: (context, vol, _) => PlayerVolumeControl(
                            volume: vol,
                            maxVolume: 150,
                            compact: compact,
                            onVolumeChanged: _s._player.setVolume,
                            onInteraction: _s._onMouseMove,
                            onDragStart: () => _s._hideTimer?.cancel(),
                            onDragEnd: _s._startHideTimer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<Duration>(
                          valueListenable: _s._positionNotifier,
                          builder: (context, pos, _) =>
                              ValueListenableBuilder<Duration>(
                                valueListenable: _s._durationNotifier,
                                builder: (context, dur, _) => PlayerTimeRange(
                                  position: pos,
                                  duration: dur,
                                ),
                              ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (hasTorrentSources) ...[
                          PlayerFlatIconButton(
                            icon: Icons.link_rounded,
                            tooltip: 'Sources',
                            onPressed: _s._showTorrentSourcesPanel,
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (hasStreamPicker) ...[
                          PlayerStreamPickerButton(
                            label: _s._streamPickerLabel(),
                            onPressedWithContext: (ctx) => _s._showStreamMenu(ctx),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (hasEpisodePicker) ...[
                          PlayerFlatIconButton(
                            icon: Icons.video_library_outlined,
                            tooltip: 'Episodes',
                            onPressedWithContext: _s._showEpisodesMenu,
                          ),
                          const SizedBox(width: 2),
                        ],
                        PlayerFlatIconButton(
                          icon: Icons.audiotrack_rounded,
                          tooltip: 'Audio',
                          onPressedWithContext: _s._showAudioMenu,
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          icon: Icons.subtitles_outlined,
                          tooltip: 'Subtitles',
                          onPressedWithContext: _s._showSubtitlesMenu,
                        ),
                        const SizedBox(width: 2),
                        ValueListenableBuilder<List<HlsQuality>?>(
                          valueListenable: _s._hlsQualitiesNotifier,
                          builder: (context, qs, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerFlatIconButton(
                                icon: Icons.hd_outlined,
                                tooltip: 'Quality',
                                onPressedWithContext: _s._showQualityMenu,
                              ),
                              const SizedBox(width: 2),
                            ],
                          ),
                        ),
                        PlayerFlatIconButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Settings',
                          onPressedWithContext: _s._showSettingsMenu,
                        ),
                        const SizedBox(width: 2),
                        PlayerFlatIconButton(
                          icon: _s._isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          tooltip: 'Fullscreen',
                          onPressed: _s._toggleFullscreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
