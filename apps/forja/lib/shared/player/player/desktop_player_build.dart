part of 'desktop_player_screen.dart';

mixin _DesktopPlayerBuild on ConsumerState<DesktopPlayerScreen>, WidgetsBindingObserver, WindowListener {
  _DesktopPlayerScreenState get _s => this as _DesktopPlayerScreenState;

  @override
  Widget build(BuildContext context) {
    ref.watch(playerResolveStatusProvider);
    // Mouse back / trackpad swipe / system pop must match the chrome Back
    // button ([_exitPlayer]) - never a bare Navigator.pop (issue 059).
    final Widget body;
    if (!_s._playerReady) {
      body = const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      );
    } else {
      // Include enter-pending: window shrinks before the stream sets _isPipMode.
      final pipMode =
          _s._isPipMode || PipService.instance.isDesktopActive;
      body = Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ListenableBuilder(
            listenable: _s._statusController,
            builder: (context, _) => MouseRegion(
              onHover: (_) => _s._onMouseMove(),
              // Immersive hide uses [SystemMouseCursors.none], but keep the
              // pointer visible while CHECKING SOURCES (status roulette) is up -
              // otherwise chrome can auto-hide mid-check and the cursor vanishes.
              cursor: _s._keepPlayerCursorVisible
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

                // Click empty video → play/pause; double-click → fullscreen.
                // Chrome sits above and keeps its own hit targets.
                if (!pipMode)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _s._player.playOrPause();
                        _s._onMouseMove();
                      },
                      onDoubleTap: () => unawaited(_s._toggleFullscreen()),
                      child: const SizedBox.expand(),
                    ),
                  ),

                // ── Custom subtitle overlay ──────────────────────────────
                // Auto-scales relative to the rendered window height so
                // the text stays readable in normal mode, fullscreen, AND
                // shrinks proportionally when in PiP (480x270).
                // Custom subtitle overlay - hidden when mpv natively handles
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
                // Hidden entirely while PiP is active - replaced by the
                // floating revert button below.
                if (!pipMode)
                  AnimatedOpacity(
                    opacity: _s._showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: IgnorePointer(
                      ignoring: !_s._showControls,
                      child: _buildControlsOverlay(),
                    ),
                  ),

                // ── PiP chrome (drag + throw snap + hover controls) ─────
                if (pipMode) _buildPipRevertOverlay(),

                if (_s._isLoadingNextEp)
                  Positioned(
                    bottom: 100,
                    right: 24,
                    child: PlayerEpisodeLoadingCard(
                      episodeLabel: _s._episodeLoadingLabel.isEmpty
                          ? 'Loading episode'
                          : _s._episodeLoadingLabel,
                      status: _s._episodeLoadingStatus.isEmpty
                          ? 'Please wait…'
                          : _s._episodeLoadingStatus,
                      failed: _s._episodeLoadingFailed,
                    ),
                  ),

                if (!_s._isLoadingNextEp)
                  PlayerStatusOverlay(
                    controller: _s._statusController,
                    bufferingListenable: _s._isBufferingNotifier,
                  ),

                if (!pipMode)
                  ParentalGuideLayer(
                    imdbId: widget.movie?.imdbId,
                    playbackStarted: _s._playbackConfirmed,
                  ),
              ],
            ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_s._exitPlayer());
      },
      child: body,
    );
  }

  /// System-style PiP chrome — expand / Minimize / Close · ±15 · scrubber.
  Widget _buildPipRevertOverlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: _s._isPlayingNotifier,
      builder: (context, playing, _) {
        return DesktopPipOverlay(
          hovering: _s._pipHover,
          onHoverChanged: (on) {
            if (!mounted) return;
            if (_s._pipHover == on) return;
            setState(() => _s._pipHover = on);
          },
          playing: playing,
          onTogglePlay: () {
            _s._player.playOrPause();
          },
          onClose: () => unawaited(_s._exitPlayer()),
          onSeekBack: () {
            final pos =
                _s._positionNotifier.value - const Duration(seconds: 15);
            unawaited(
              _s._seekTo(pos < Duration.zero ? Duration.zero : pos),
            );
          },
          onSeekForward: () {
            final dur = _s._durationNotifier.value;
            final pos =
                _s._positionNotifier.value + const Duration(seconds: 15);
            unawaited(_s._seekTo(pos > dur ? dur : pos));
          },
          positionListenable: _s._positionNotifier,
          durationListenable: _s._durationNotifier,
          onSeekTo: (pos) => unawaited(_s._seekTo(pos)),
        );
      },
    );
  }

  Widget _buildControlsOverlay() {
    final isTv = widget.movie?.mediaType == 'tv';
    final hasEpisodePicker =
        (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
    final hasStreamPicker = _s._hasStreamPicker;
    final hasTorrentSources = _s._usesCatalogSourcesPanel;
    final catalogSourceLines =
        hasTorrentSources ? _s._catalogSourcesButtonLabels() : null;
    final streamPickerLines =
        hasStreamPicker ? _s._streamPickerLabels() : null;
    final compact = MediaQuery.sizeOf(context).width < 900;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
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
            statusActions: _s._hasError
                ? PlayerTopStatusActions(
                    onRetry: _s._retryCurrentPlayback,
                    onStream: hasStreamPicker ? _s._showStreamMenu : null,
                  )
                : null,
            // Must go through [_exitPlayer] - a direct pop skipped silence/stop
            // and left mpv audio playing (issue 059).
            onBack: () => unawaited(_s._exitPlayer()),
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
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _s._isPlayingNotifier,
                _s._isBufferingNotifier,
              ]),
              builder: (context, _) {
                final showHero = !_s._isPlayingNotifier.value ||
                    _s._isBufferingNotifier.value;
                return AnimatedOpacity(
                  opacity: showHero ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !showHero,
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
                );
              },
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
                        unawaited(
                          _s._seekTo(
                            pos < Duration.zero ? Duration.zero : pos,
                          ),
                        );
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
                        unawaited(_s._seekTo(pos > dur ? dur : pos));
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
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _s._nextEpisode,
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
                              builder: (context, buffered, _) => Row(
                                children: [
                                  Expanded(
                                    child: SeekBarWithPreview(
                                      duration: duration,
                                      position: position,
                                      bufferedPosition: buffered,
                                      zones: buildSeekBarZones(
                                        introDb: _s._introDbData,
                                        duration: duration,
                                        hasNextEpisode:
                                            _s._isNextEpisodeAvailable,
                                      ),
                                      captureFrame: _s._captureSeekPreview,
                                      onSeek: (t) {
                                        unawaited(_s._seekTo(t));
                                        _s._onMouseMove();
                                      },
                                      onDragStart: () =>
                                          _s._hideTimer?.cancel(),
                                      onDragEnd: _s._startHideTimer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  PlayerTimeRange(
                                    position: position,
                                    duration: duration,
                                  ),
                                ],
                              ),
                            ),
                      ),
                ),
                const SizedBox(height: 10),
                // Full-width opaque hit target so empty space between left/right
                // clusters (and the wide anime/drama Source chip) cannot start a
                // seek scrub on the bar above. Cancel any live scrub on enter -
                // Quality / Settings sit under the right end of the bar.
                Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: double.infinity,
                    child: MouseRegion(
                      onEnter: (_) => playerChromeCancelSeekScrubs(),
                      child: Listener(
                      behavior: HitTestBehavior.opaque,
                      child: Row(
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
                        if (_s._buildTransportPrevEpisodeButton()
                            case final prevEp?) ...[
                          const SizedBox(width: 2),
                          prevEp,
                        ],
                        if (_s._buildTransportNextEpisodeButton()
                            case final nextEp?) ...[
                          const SizedBox(width: 2),
                          nextEp,
                        ],
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
                      ],
                    ),
                    Row(
                      children: [
                        if (hasTorrentSources) ...[
                          PlayerSourcesPanelButton(
                            label: catalogSourceLines!.label,
                            server: catalogSourceLines.server,
                            onPressed: _s._showTorrentSourcesPanel,
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (hasStreamPicker) ...[
                          PlayerStreamPickerButton(
                            label: streamPickerLines!.label,
                            server: streamPickerLines.server,
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
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
