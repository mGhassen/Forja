part of 'mobile_player_screen.dart';

mixin _MobilePlayerBuild on State<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  @override
  Widget build(BuildContext context) {
    final body = PopScope(
      // Always false - exit via [_exitPlayer] manual pop + loading dismiss.
      // canPop:true raced a deferred system pop and skipped dismiss (I101).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // Forced pops (episode handoff / sources exhausted) must NOT strip the
        // loading host - those flows keep it for pushReplacement / reload UI.
        if (didPop) return;
        await _s._exitPlayer();
      },
      child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Video ─────────────────────────────────────────────────
              // Positioned.fill: loose Stack children can get a zero-sized
              // surface on Android (Impeller/Skia sibling composite).
              Positioned.fill(
                child: Video(
                  controller: _s._controller,
                  controls: NoVideoControls,
                  fit: _s._videoFit,
                  fill: Colors.black,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    visible: false,
                  ),
                ),
              ),

                // ── 1b. Custom subtitle overlay ─────────────────────────────
                // Auto-scales relative to the rendered window height so
                // it shrinks proportionally when in PiP.
                // Custom subtitle overlay - hidden when libass is handling
                // ASS/SSA subtitles (they render on the video frame instead).
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
                      // Reference height = 720p. PiP windows are ~108px tall
                      // so scale clamps to a readable minimum.
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

                // ── 2. Gesture layer ─────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _s._toggleControls,
                      onDoubleTapDown: (d) {
                        _s._handleDoubleTap(
                          d,
                          d.localPosition.dx > constraints.maxWidth / 2,
                        );
                      },
                      onVerticalDragUpdate: (d) =>
                          _s._onVerticalDragUpdate(d, constraints.maxWidth),
                      onLongPressStart: (_) {
                        if (!_s._isLocked) _s._player.setRate(2.0);
                      },
                      onLongPressEnd: (_) {
                        if (!_s._isLocked) _s._player.setRate(1.0);
                      },
                      child: Container(color: Colors.transparent),
                    );
                  },
                ),

                // ── 3. Double-tap ripple ──────────────────────────────────────
                if (_s._showRipple)
                  Positioned(
                    left: _s._isForward ? null : _s._ripplePosition.dx - 50,
                    right: _s._isForward
                        ? (MediaQuery.of(context).size.width -
                                  _s._ripplePosition.dx) -
                              50
                        : null,
                    top: _s._ripplePosition.dy - 50,
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _s._rippleOpacity,
                        child: ScaleTransition(
                          scale: _s._rippleScale,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _s._isForward ? '+10s' : '-10s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── 4. Controls overlay ───────────────────────────────────────
                // Hidden entirely while Android system PiP is active so the
                // floating window shows only the video frame.
                AnimatedOpacity(
                  opacity: (_s._showControls && !_s._isLocked && !_s._isPipMode)
                      ? 1.0
                      : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: ExcludeFocus(
                    excluding:
                        widget.tvRemoteEnabled &&
                        !(_s._showControls && !_s._isLocked && !_s._isPipMode),
                    child: IgnorePointer(
                      ignoring: !(_s._showControls && !_s._isLocked) || _s._isPipMode,
                      child: _buildControlsOverlay(),
                    ),
                  ),
                ),

                // ── 5. Lock button (always visible when locked + controls shown)
                if (_s._isLocked)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 72,
                    left: 12,
                    child: AnimatedOpacity(
                      opacity: _s._showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: PlayerFlatIconButton(
                        icon: Icons.lock_rounded,
                        onPressed: _s._toggleLock,
                        active: true,
                        tooltip: 'Unlock',
                      ),
                    ),
                  ),

                // ── 6. Volume indicator ───────────────────────────────────────
                if (_s._showVolumeIndicator)
                  Positioned(
                    right: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _SideIndicator(
                        icon: Icons.volume_up_rounded,
                        value: _s._volume / 150.0,
                      ),
                    ),
                  ),

                // ── 7. Brightness indicator ───────────────────────────────────
                if (_s._showBrightnessIndicator)
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _SideIndicator(
                        icon: Icons.light_mode_rounded,
                        value: _s._brightness,
                      ),
                    ),
                  ),

                // ── 7.5 Skip Segment Overlay (IntroDB) ─────────────────────
                if (!widget.tvRemoteEnabled &&
                    _s._activeSkipLabel != null &&
                    !_s._skipDismissed)
                  Positioned(
                    bottom: _s._showNextEpButton ? 170 : 120,
                    right: 16,
                    child: PlayerFloatingChip(
                      label: _s._activeSkipLabel!,
                      onPressed: _s._performSkip,
                    ),
                  ),

                // ── 8. Next Episode Overlay ──────────────────────────────
                if (!widget.tvRemoteEnabled && _s._showNextEpButton)
                  Positioned(
                    bottom: 120,
                    right: 16,
                    child: PlayerFloatingChip(
                      label: 'Next Episode',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: _s._nextEpisode,
                    ),
                  ),

                if (_s._isLoadingNextEp)
                  Positioned(
                    bottom: 120,
                    right: 16,
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

                if (!_s._isLoadingNextEp && !_s._hasError)
                  PlayerStatusOverlay(
                    controller: _s._statusController,
                    bufferingListenable: _s._isBufferingNotifier,
                  ),
              ],
            ),
          ),
        ),
    );

    if (!widget.tvRemoteEnabled) return body;
    return PlayerTvKeyScope(
      enabled: true,
      focusNode: _s._tvKeyFocus,
      showControls: _s._showControls,
      onBack: () => unawaited(_s._exitPlayer()),
      onPlayPause: () {
        if (_s._player.state.playing) {
          _s._player.pause();
        } else {
          _s._player.play();
        }
      },
      onShowControls: () {
        setState(() => _s._showControls = true);
        _s._claimPlayFocus();
      },
      onSeekBack: () {
        final pos = _s._positionNotifier.value - const Duration(seconds: 10);
        unawaited(
          _s._seekTo(pos < Duration.zero ? Duration.zero : pos),
        );
      },
      onSeekForward: () {
        final dur = _s._durationNotifier.value;
        final pos = _s._positionNotifier.value + const Duration(seconds: 10);
        unawaited(_s._seekTo(pos > dur ? dur : pos));
      },
      onVolumeUp: () => _s._nudgeTvVolume(10),
      onVolumeDown: () => _s._nudgeTvVolume(-10),
      onToggleControls: _s._toggleControls,
      child: body,
    );
  }

  Widget _buildControlsOverlay() {
    final isTv = widget.movie?.mediaType == 'tv';
    final hasEpisodePicker =
        (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
    final hasStreamPicker = _s._hasStreamPicker;
    final hasTorrentSources = _s._usesCatalogSourcesPanel;
    final btnSize = 38.0;
    final iconSz = 20.0;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusMessage: _s._hasError,
      hasStatusActions: _s._hasError,
    );
    final tvFocus = widget.tvRemoteEnabled;

    final overlayChildren = <Widget>[
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
          child: tvFocus
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: PlayerTopBar(
                    title: _s._displayTitle,
                    season: widget.hubEpisodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.hubEpisodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeLine: _s._hubEpisodeLine,
                    statusMessage: _s._hasError ? _s._errorMessage : null,
                    statusActions: _s._hasError
                        ? PlayerTopStatusActions(
                            onRetry: _s._initPlayback,
                            onStream: hasStreamPicker ? _s._showStreamMenu : null,
                            tvFocusable: true,
                          )
                        : null,
                    onBack: _s._exitPlayer,
                    tvFocusable: true,
                    backFocusNode: _s._backFocus,
                    trailing: PlayerTopBarActions(
                      tvFocusable: true,
                      showPlayer: widget.onSwitchPlayer != null,
                      onPlayer: widget.onSwitchPlayer != null
                          ? (anchorContext) =>
                              unawaited(_s._showPlayerMenu(anchorContext))
                          : null,
                      // Cast / PiP are phone/desktop chrome - hide on ATV.
                      showCast: false,
                      showPip: false,
                    ),
                  ),
                )
              : PlayerTopBar(
                  title: _s._displayTitle,
                  season: widget.hubEpisodes != null
                      ? null
                      : widget.selectedSeason,
                  episode: widget.hubEpisodes != null
                      ? null
                      : widget.selectedEpisode,
                  episodeLine: _s._hubEpisodeLine,
                  statusMessage: _s._hasError ? _s._errorMessage : null,
                  statusActions: _s._hasError
                      ? PlayerTopStatusActions(
                          onRetry: _s._initPlayback,
                          onStream: hasStreamPicker ? _s._showStreamMenu : null,
                        )
                      : null,
                  onBack: _s._exitPlayer,
                  tvFocusable: tvFocus,
                  trailing: PlayerTopBarActions(
                    tvFocusable: tvFocus,
                    showPlayer: widget.onSwitchPlayer != null,
                    onPlayer: widget.onSwitchPlayer != null
                        ? (anchorContext) =>
                            unawaited(_s._showPlayerMenu(anchorContext))
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
                      _s._startHideTimer();
                    },
                    showPip: PipService.instance.isSupported,
                    onPip: () async {
                      await PipService.instance.enter();
                      _s._startHideTimer();
                    },
                  ),
                ),
        ),

        if (_s._displayMovie != null)
          Positioned(
            left: 0,
            top: topBarHeight,
            bottom: 110,
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

        if (!_s._isLocked && !tvFocus)
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
                child: IgnorePointer(
                  ignoring: _s._isLocked,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerCenterActionButton(
                          tvFocusable: tvFocus,
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
                            _s._startHideTimer();
                          },
                        ),
                        const SizedBox(width: 24),
                        ValueListenableBuilder<bool>(
                          valueListenable: _s._isPlayingNotifier,
                          builder: (context, playing, _) =>
                              PlayerCenterActionButton(
                                tvFocusable: tvFocus,
                                icon: playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 80,
                                iconSize: 44,
                                onPressed: () {
                                  playing ? _s._player.pause() : _s._player.play();
                                  _s._startHideTimer();
                                },
                              ),
                        ),
                        const SizedBox(width: 24),
                        PlayerCenterActionButton(
                          tvFocusable: tvFocus,
                          icon: Icons.forward_10_rounded,
                          onPressed: () {
                            final dur = _s._durationNotifier.value;
                            final pos =
                                _s._positionNotifier.value +
                                const Duration(seconds: 10);
                            unawaited(_s._seekTo(pos > dur ? dur : pos));
                            _s._startHideTimer();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: _s._durationNotifier,
                    builder: (context, duration, _) =>
                        ValueListenableBuilder<Duration>(
                          valueListenable: _s._positionNotifier,
                          builder: (context, position, _) =>
                              ValueListenableBuilder<Duration>(
                                valueListenable: _s._bufferedNotifier,
                                builder: (context, buffered, _) => tvFocus
                                    ? FocusTraversalOrder(
                                        order: const NumericFocusOrder(2),
                                        child: CustomSeekbar(
                                          duration: duration,
                                          position: position,
                                          bufferedPosition: buffered,
                                          tvFocusable: true,
                                          onTvFocusUp: _s._focusUpFromSeekbar,
                                          onSeek: (t) => unawaited(_s._seekTo(t)),
                                        ),
                                      )
                                    : _MobileSeekbar(
                                        duration: duration,
                                        position: position,
                                        bufferedPosition: buffered,
                                        onSeek: (t) {
                                          unawaited(_s._seekTo(t));
                                          _s._startHideTimer();
                                        },
                                        onDragStart: () => _s._hideTimer?.cancel(),
                                        onDragEnd: _s._startHideTimer,
                                      ),
                              ),
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (tvFocus)
                    _buildTvFilmTransportRow(
                      btnSize: btnSize,
                      iconSz: iconSz,
                      hasTorrentSources: hasTorrentSources,
                      hasStreamPicker: hasStreamPicker,
                      hasEpisodePicker: hasEpisodePicker,
                    )
                  else
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
                                    size: btnSize,
                                    iconSize: iconSz,
                                    onPressed: () {
                                      playing
                                          ? _s._player.pause()
                                          : _s._player.play();
                                      _s._startHideTimer();
                                    },
                                  ),
                            ),
                            _s._buildTransportBackButton(
                              btnSize: btnSize,
                              iconSz: iconSz,
                            ),
                            _s._buildTransportForwardButton(
                              btnSize: btnSize,
                              iconSz: iconSz,
                            ),
                            PlayerVolumeControl(
                              volume: _s._volume,
                              maxVolume: 150,
                              size: btnSize,
                              iconSize: iconSz,
                              compact: compact,
                              onVolumeChanged: (v) {
                                setState(() => _s._volume = v);
                                _s._player.setVolume(v);
                              },
                              onInteraction: _s._startHideTimer,
                              onDragStart: () => _s._hideTimer?.cancel(),
                              onDragEnd: _s._startHideTimer,
                            ),
                            const SizedBox(width: 6),
                            ValueListenableBuilder<Duration>(
                              valueListenable: _s._positionNotifier,
                              builder: (context, pos, _) =>
                                  ValueListenableBuilder<Duration>(
                                    valueListenable: _s._durationNotifier,
                                    builder: (context, dur, _) =>
                                        PlayerTimeRange(
                                      position: pos,
                                      duration: dur,
                                      fontSize: 11,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (hasTorrentSources)
                              PlayerFlatIconButton(
                                icon: Icons.link_rounded,
                                size: btnSize,
                                iconSize: iconSz,
                                tooltip: 'Sources',
                                onPressed: _s._showTorrentSourcesPanel,
                              ),
                            if (hasStreamPicker)
                              PlayerStreamPickerButton(
                                size: btnSize,
                                iconSize: iconSz - 2,
                                label: _s._streamPickerLabel(),
                                onPressedWithContext: (ctx) =>
                                    _s._showStreamMenu(ctx),
                              ),
                            if (hasEpisodePicker)
                              PlayerFlatIconButton(
                                icon: Icons.video_library_outlined,
                                size: btnSize,
                                iconSize: iconSz,
                                onPressedWithContext: _s._showEpisodesMenu,
                              ),
                            PlayerFlatIconButton(
                              icon: Icons.audiotrack_rounded,
                              size: btnSize,
                              iconSize: iconSz,
                              tooltip: 'Audio',
                              onPressedWithContext: _s._showAudioMenu,
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.subtitles_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressedWithContext: _s._showSubtitlesMenu,
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.hd_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              tooltip: 'Quality',
                              onPressedWithContext: _s._showQualityMenu,
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.settings_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressedWithContext: _s._showSettingsMenu,
                            ),
                            PlayerFlatIconButton(
                              icon: _s._isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              active: _s._isLocked,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressed: _s._toggleLock,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ];

    if (tvFocus && _s._activeSkipLabel != null && !_s._skipDismissed) {
      overlayChildren.add(
        Positioned(
          bottom: _s._showNextEpButton ? 170 : 120,
          right: 16,
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(15),
            child: PlayerFloatingChip(
              label: _s._activeSkipLabel!,
              onPressed: _s._performSkip,
              tvFocusable: true,
              focusNode: _s._skipChipFocus,
            ),
          ),
        ),
      );
    }
    if (tvFocus && _s._showNextEpButton) {
      overlayChildren.add(
        Positioned(
          bottom: 120,
          right: 16,
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(16),
            child: PlayerFloatingChip(
              label: 'Next Episode',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _s._nextEpisode,
              tvFocusable: true,
              focusNode: _s._nextEpChipFocus,
            ),
          ),
        ),
      );
    }

    final overlay = Stack(children: overlayChildren);
    if (!tvFocus) return overlay;
    return SizedBox.expand(
      child: FocusScope(
        debugLabel: 'player-chrome',
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: overlay,
        ),
      ),
    );
  }

  Widget _buildTvFilmTransportRow({
    required double btnSize,
    required double iconSz,
    required bool hasTorrentSources,
    required bool hasStreamPicker,
    required bool hasEpisodePicker,
  }) {
    Widget ordered(int order, Widget child) => FocusTraversalOrder(
          order: NumericFocusOrder(order.toDouble()),
          child: child,
        );

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _s._isPlayingNotifier,
                builder: (context, playing, _) => ordered(
                  3,
                  PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._playFocus,
                  icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: () {
                    playing ? _s._player.pause() : _s._player.play();
                  },
                ),
              ),
            ),
            const SizedBox(width: 2),
            _s._buildTransportBackButton(
              btnSize: btnSize,
              iconSz: iconSz,
              tvFocusable: true,
              tvFocusOrder: 4,
            ),
            const SizedBox(width: 2),
            _s._buildTransportForwardButton(
              btnSize: btnSize,
              iconSz: iconSz,
              tvFocusable: true,
              tvFocusOrder: 5,
            ),
            const SizedBox(width: 2),
            ordered(
              6,
              PlayerVolumeControl(
                volume: _s._volume,
                maxVolume: 150,
                size: btnSize,
                iconSize: iconSz,
                tvFocusable: true,
                compact: true,
                onVolumeChanged: (v) {
                  setState(() => _s._volume = v);
                  _s._player.setVolume(v);
                },
                onInteraction: () {},
                onDragStart: () {},
                onDragEnd: () {},
              ),
            ),
            const SizedBox(width: 6),
            ExcludeFocus(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _s._positionNotifier,
                builder: (context, pos, _) => ValueListenableBuilder<Duration>(
                  valueListenable: _s._durationNotifier,
                  builder: (context, dur, _) => PlayerTimeRange(
                    position: pos,
                    duration: dur,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTorrentSources)
              ordered(
                7,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.link_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Sources',
                  onPressed: _s._showTorrentSourcesPanel,
                ),
              ),
            if (hasTorrentSources) const SizedBox(width: 2),
            if (hasStreamPicker)
              ordered(
                8,
                PlayerStreamPickerButton(
                  tvFocusable: true,
                  size: btnSize,
                  iconSize: iconSz - 2,
                  label: _s._streamPickerLabel(),
                  onPressedWithContext: (ctx) => _s._showStreamMenu(ctx),
                ),
              ),
            if (hasStreamPicker) const SizedBox(width: 2),
            if (hasEpisodePicker)
              ordered(
                9,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.video_library_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressedWithContext: _s._showEpisodesMenu,
                ),
              ),
            if (hasEpisodePicker) const SizedBox(width: 2),
            ordered(
              10,
              PlayerFlatIconButton(
                tvFocusable: true,
                icon: Icons.audiotrack_rounded,
                size: btnSize,
                iconSize: iconSz,
                tooltip: 'Audio',
                onPressedWithContext: _s._showAudioMenu,
              ),
            ),
            const SizedBox(width: 2),
            ordered(
              11,
              PlayerFlatIconButton(
                tvFocusable: true,
                icon: Icons.subtitles_outlined,
                size: btnSize,
                iconSize: iconSz,
                onPressedWithContext: _s._showSubtitlesMenu,
              ),
            ),
            const SizedBox(width: 2),
            ordered(
              12,
              PlayerFlatIconButton(
                tvFocusable: true,
                icon: Icons.hd_outlined,
                size: btnSize,
                iconSize: iconSz,
                tooltip: 'Quality',
                onPressedWithContext: _s._showQualityMenu,
              ),
            ),
            const SizedBox(width: 2),
            ordered(
              13,
              PlayerFlatIconButton(
                tvFocusable: true,
                icon: Icons.settings_outlined,
                size: btnSize,
                iconSize: iconSz,
                onPressedWithContext: _s._showSettingsMenu,
              ),
            ),
            const SizedBox(width: 2),
            ordered(
              14,
              PlayerFlatIconButton(
                tvFocusable: true,
                icon: _s._isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                active: _s._isLocked,
                size: btnSize,
                iconSize: iconSz,
                onPressed: _s._toggleLock,
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}
