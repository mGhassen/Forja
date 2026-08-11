part of 'trailer_player_screen.dart';

mixin _TrailerPlayerBuild on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  Widget _buildResolveError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _s._resolveError ?? 'Could not load this trailer',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => unawaited(_s._loadCurrentTrailer()),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => unawaited(_s._openInYouTube()),
                child: const Text('Open in YouTube'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = _s._tvFocus;
    final body = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (tvFocus && ShellTvFocusCoordinator.tvBackPolicyEnabled) {
          ShellTvFocusCoordinator.handleShellBackKey();
          return;
        }
        unawaited(_s._exitTrailer());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: tvFocus ? null : (_) => _s._onPointerActivity(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_s._controller != null)
                Positioned.fill(
                  child: Video(
                    controller: _s._controller!,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                    fill: Colors.black,
                    subtitleViewConfiguration: const SubtitleViewConfiguration(
                      visible: true,
                    ),
                  ),
                ),
              if (_s._resolving || _s._resolveError != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: _s._resolving
                          ? const CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2.5,
                            )
                          : _buildResolveError(),
                    ),
                  ),
                ),
              if (!tvFocus)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_s._showControls) {
                        setState(() => _s._showControls = false);
                        _s._hideTimer?.cancel();
                      } else {
                        _s._onPointerActivity();
                      }
                    },
                    onDoubleTap: () {
                      if (!_s._supportsWindowFullscreen) return;
                      unawaited(_s._toggleFullscreen());
                    },
                  ),
                ),
              DesktopWindowChrome.overlayDragStrip(),
              AnimatedOpacity(
                opacity: _s._showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: ExcludeFocus(
                  excluding: tvFocus && !_s._showControls,
                  child: IgnorePointer(
                    ignoring: !_s._showControls,
                    child: _buildChromeOverlay(tvFocus: tvFocus),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!tvFocus) return body;
    return PlayerTvKeyScope(
      enabled: true,
      focusNode: _s._tvKeyFocus,
      showControls: _s._showControls,
      onBack: () {
        if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
          ShellTvFocusCoordinator.handleShellBackKey();
        } else {
          unawaited(_s._exitTrailer());
        }
      },
      onPlayPause: () {
        if (!_s._ready) return;
        unawaited(_s._togglePlayPause());
      },
      onShowControls: _s._showChromeAndFocusPlay,
      onSeekBack: () {
        if (!_s._ready) return;
        unawaited(_s._skip(-10));
      },
      onSeekForward: () {
        if (!_s._ready) return;
        unawaited(_s._skip(10));
      },
      onVolumeUp: () {
        if (!_s._ready) return;
        unawaited(_s._setVolume((_s._volume + 10).clamp(0, 100)));
      },
      onVolumeDown: () {
        if (!_s._ready) return;
        unawaited(_s._setVolume((_s._volume - 10).clamp(0, 100)));
      },
      onToggleControls: () {
        setState(() => _s._showControls = !_s._showControls);
        if (_s._showControls) {
          _s._startHideTimer();
          _s._claimPlayFocus();
        } else {
          _s._hideTimer?.cancel();
        }
      },
      onFocusBack: _s._showChromeAndFocusBack,
      onFocusPlay: _s._showChromeAndFocusPlay,
      onControlsActivity: _s._startHideTimer,
      child: body,
    );
  }

  Widget _buildChromeOverlay({required bool tvFocus}) {
    final layers = Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeFocus(
            child: PlayerOverlayGradient(isTop: true),
          ),
        ),
        Positioned(
          top: DesktopWindowChrome.isDesktop
              ? DesktopWindowChrome.topInset(context) + 6
              : MediaQuery.paddingOf(context).top + 6,
          left: 16,
          child: tvFocus
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: PlayerFlatIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    tvFocusable: true,
                    focusNode: _s._backFocus,
                    onRightEdge: () => _s._playerMenuFocus.requestFocus(),
                    onDownEdge: _s._focusDownFromBack,
                    onPressed: () => unawaited(_s._exitTrailer()),
                  ),
                )
              : PlayerFlatIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => unawaited(_s._exitTrailer()),
                ),
        ),
        Positioned(
          top: DesktopWindowChrome.isDesktop
              ? DesktopWindowChrome.topInset(context) + 6
              : MediaQuery.paddingOf(context).top + 6,
          right: 16,
          child: tvFocus
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(1.5),
                  child: PlayerTopBarActions(
                    tvFocusable: true,
                    showPlayer: true,
                    playerFocusNode: _s._playerMenuFocus,
                    playerOnLeftEdge: () => _s._backFocus.requestFocus(),
                    onPlayer: (anchorContext) =>
                        unawaited(_s._showPlayerMenu(anchorContext)),
                  ),
                )
              : PlayerTopBarActions(
                  showPlayer: true,
                  onPlayer: (anchorContext) =>
                      unawaited(_s._showPlayerMenu(anchorContext)),
                ),
        ),
        if (!tvFocus)
          Positioned.fill(
            child: ExcludeFocus(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerCenterActionButton(
                      icon: Icons.replay_10_rounded,
                      onPressed: () {
                        if (!_s._ready) return;
                        unawaited(_s._skip(-10));
                        _s._onPointerActivity();
                      },
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: _s._showReplayControl
                          ? Icons.replay_rounded
                          : _s._playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                      size: 80,
                      iconSize: 44,
                      onPressed: () {
                        if (!_s._ready) return;
                        unawaited(_s._togglePlayPause());
                        _s._onPointerActivity();
                      },
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: Icons.forward_10_rounded,
                      onPressed: () {
                        if (!_s._ready) return;
                        unawaited(_s._skip(10));
                        _s._onPointerActivity();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        _buildBottomChrome(tvFocus: tvFocus),
      ],
    );

    if (!tvFocus) return layers;
    return SizedBox.expand(
      child: FocusScope(
        debugLabel: 'player-chrome',
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: layers,
        ),
      ),
    );
  }

  Widget _buildBottomChrome({required bool tvFocus}) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.movie != null)
                  PlayerTitleMeta(
                    title: _s._trailer.name,
                    movie: widget.movie,
                  )
                else
                  Text(
                    _s._trailer.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_s._hasMoreTrailers) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: tvFocus
                        ? FocusTraversalOrder(
                            // Between top bar (1–1.5) and seekbar (2).
                            order: const NumericFocusOrder(1.8),
                            child: _buildMoreVideosButton(tvFocus: true),
                          )
                        : _buildMoreVideosButton(tvFocus: false),
                  ),
                ],
                const SizedBox(height: 12),
                tvFocus
                    ? FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: CustomSeekbar(
                          duration: _s._duration,
                          position: _s._position,
                          onSeek: _s._seek,
                          tvFocusable: true,
                          focusNode: _s._seekbarFocus,
                          tvFocusUpNode: _s._hasMoreTrailers
                              ? _s._nextTrailerFocus
                              : _s._backFocus,
                          onTvFocusDown: () => _s._playFocus.requestFocus(),
                          onTvFocusLeft: () => _s._playFocus.requestFocus(),
                          onTvFocusRight: () => _s._subsFocus.requestFocus(),
                        ),
                      )
                    : CustomSeekbar(
                        duration: _s._duration,
                        position: _s._position,
                        onSeek: _s._seek,
                      ),
                const SizedBox(height: 10),
                if (tvFocus)
                  _buildTvTransportRow()
                else
                  _buildDesktopTransportRow(),
                if (tvFocus) ...[
                  const SizedBox(height: 6),
                  ExcludeFocus(
                    child: PlayerTimeRange(
                      position: _s._position,
                      duration: _s._duration,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreVideosButton({required bool tvFocus}) {
    return _TrailerMoreVideosCard(
      trailer: _s._pickerTrailer,
      index: _s._pickerIndex,
      count: widget.trailers.length,
      playing: _s._pickerIndex == _s._currentIndex && !_s._ended,
      autoNextSecondsLeft: _s._autoNextSecondsLeft,
      autoNextTotal: _TrailerPlayerScreenState._autoNextSeconds,
      focusNode: _s._nextTrailerFocus,
      tvFocus: tvFocus,
      onPrev: () => _s._shiftPicker(-1),
      onNext: () => _s._shiftPicker(1),
      onPlay: () => _s._playTrailerAt(_s._pickerIndex),
      onPointerActivity: _s._onPointerActivity,
      onFocusUp: () => _s._backFocus.requestFocus(),
      onFocusDown: _s._focusSeekbar,
    );
  }

  Widget _buildVolumeControl({required bool tvFocus}) {
    if (tvFocus) {
      return PlayerFlatIconButton(
        tvFocusable: true,
        icon: _s._muted || _s._volume <= 0
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded,
        tooltip: 'Mute',
        onPressed: () {
          if (!_s._ready) return;
          unawaited(_s._toggleMute());
        },
      );
    }
    return PlayerVolumeControl(
      volume: _s._volume,
      maxVolume: 100,
      onVolumeChanged: (v) {
        if (!_s._ready) return;
        unawaited(_s._setVolume(v));
      },
      onInteraction: _s._onPointerActivity,
      onDragStart: () => _s._hideTimer?.cancel(),
      onDragEnd: _s._startHideTimer,
    );
  }

  Widget _buildTvTransportRow() {
    void upToSeek() => _s._focusSeekbar();

    Widget ordered(int order, Widget child) => FocusTraversalOrder(
          order: NumericFocusOrder(order.toDouble()),
          child: child,
        );

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ordered(
                3,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._playFocus,
                  icon: _s._showReplayControl
                      ? Icons.replay_rounded
                      : _s._playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                  tooltip: _s._showReplayControl
                      ? 'Replay'
                      : _s._playing
                          ? 'Pause'
                          : 'Play',
                  onUpEdge: upToSeek,
                  onRightEdge: () => _s._rewindFocus.requestFocus(),
                  onPressed: () {
                    if (!_s._ready) return;
                    unawaited(_s._togglePlayPause());
                  },
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                4,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._rewindFocus,
                  icon: Icons.replay_10_rounded,
                  tooltip: 'Back 10s',
                  onUpEdge: upToSeek,
                  onLeftEdge: () => _s._playFocus.requestFocus(),
                  onRightEdge: () => _s._forwardFocus.requestFocus(),
                  onPressed: () {
                    if (!_s._ready) return;
                    unawaited(_s._skip(-10));
                  },
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                5,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._forwardFocus,
                  icon: Icons.forward_10_rounded,
                  tooltip: 'Forward 10s',
                  onUpEdge: upToSeek,
                  onLeftEdge: () => _s._rewindFocus.requestFocus(),
                  onRightEdge: () => _s._subsFocus.requestFocus(),
                  onPressed: () {
                    if (!_s._ready) return;
                    unawaited(_s._skip(10));
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ordered(
                7,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._subsFocus,
                  icon: Icons.subtitles_outlined,
                  tooltip: 'Subtitles',
                  onUpEdge: upToSeek,
                  onLeftEdge: () => _s._forwardFocus.requestFocus(),
                  onRightEdge: () => _s._qualityFocus.requestFocus(),
                  onPressedWithContext: _s._showSubtitleMenu,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                8,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._qualityFocus,
                  icon: Icons.hd_outlined,
                  tooltip: 'Quality',
                  onUpEdge: upToSeek,
                  onLeftEdge: () => _s._subsFocus.requestFocus(),
                  onRightEdge: () => _s._speedFocus.requestFocus(),
                  onPressedWithContext: _s._showQualityMenu,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                9,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _s._speedFocus,
                  icon: Icons.speed_rounded,
                  tooltip: 'Playback speed',
                  onUpEdge: upToSeek,
                  onLeftEdge: () => _s._qualityFocus.requestFocus(),
                  onPressedWithContext: _s._showSpeedMenu,
                ),
              ),
              if (!_s._ready) ...[
                const SizedBox(width: 8),
                ExcludeFocus(
                  child: Text(
                    'Loading…',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTransportRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            PlayerFlatIconButton(
              icon: _s._showReplayControl
                  ? Icons.replay_rounded
                  : _s._playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
              tooltip: _s._showReplayControl
                  ? 'Replay'
                  : _s._playing
                      ? 'Pause'
                      : 'Play',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._togglePlayPause());
              },
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              icon: Icons.replay_10_rounded,
              tooltip: 'Back 10s',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._skip(-10));
              },
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              icon: Icons.forward_10_rounded,
              tooltip: 'Forward 10s',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._skip(10));
              },
            ),
            const SizedBox(width: 6),
            _buildVolumeControl(tvFocus: false),
            const SizedBox(width: 8),
            PlayerTimeRange(
              position: _s._position,
              duration: _s._duration,
            ),
          ],
        ),
        Row(
          children: [
            PlayerFlatIconButton(
              icon: Icons.subtitles_outlined,
              tooltip: 'Subtitles',
              onPressedWithContext: _s._showSubtitleMenu,
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              icon: Icons.hd_outlined,
              tooltip: 'Quality',
              onPressedWithContext: _s._showQualityMenu,
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              icon: Icons.speed_rounded,
              tooltip: 'Playback speed',
              onPressedWithContext: _s._showSpeedMenu,
            ),
            if (_s._supportsWindowFullscreen) ...[
              const SizedBox(width: 2),
              PlayerFlatIconButton(
                icon: _s._isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: 'Fullscreen',
                onPressed: () => unawaited(_s._toggleFullscreen()),
              ),
            ],
            if (!_s._ready) ...[
              const SizedBox(width: 8),
              Text(
                'Loading…',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TrailerMoreVideosCard extends StatefulWidget {
  const _TrailerMoreVideosCard({
    required this.trailer,
    required this.index,
    required this.count,
    required this.playing,
    required this.autoNextSecondsLeft,
    required this.autoNextTotal,
    required this.focusNode,
    required this.tvFocus,
    required this.onPrev,
    required this.onNext,
    required this.onPlay,
    required this.onPointerActivity,
    this.onFocusUp,
    this.onFocusDown,
  });

  final MediaTrailer trailer;
  final int index;
  final int count;
  final bool playing;
  final int? autoNextSecondsLeft;
  final int autoNextTotal;
  final FocusNode focusNode;
  final bool tvFocus;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPlay;
  final VoidCallback onPointerActivity;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  bool get autoNext => autoNextSecondsLeft != null;

  @override
  State<_TrailerMoreVideosCard> createState() => _TrailerMoreVideosCardState();
}

class _TrailerMoreVideosCardState extends State<_TrailerMoreVideosCard> {
  bool _hovered = false;
  bool _focused = false;
  int _slideDir = 1;

  static const double _w = 280;
  static const double _h = 158;
  static const double _radius = 12;

  bool get _active => _hovered || _focused;

  @override
  void didUpdateWidget(covariant _TrailerMoreVideosCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final wrappedForward =
        oldWidget.index == widget.count - 1 && widget.index == 0;
    final wrappedBack =
        oldWidget.index == 0 && widget.index == widget.count - 1;
    if (wrappedForward) {
      _slideDir = 1;
    } else if (wrappedBack) {
      _slideDir = -1;
    } else {
      _slideDir = widget.index > oldWidget.index ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.trailer.type.trim();
    final autoLeft = widget.autoNextSecondsLeft;
    final meta = widget.autoNext
        ? 'Next trailer · ${autoLeft}s'
        : [
            if (type.isNotEmpty) type,
            '${widget.index + 1}/${widget.count}',
            if (widget.playing) 'Playing',
          ].join(' · ');

    final face = AnimatedScale(
      scale: _active || widget.autoNext ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomRight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: (_active || widget.autoNext) ? Colors.white : Colors.white24,
            width: (_active || widget.autoNext) ? 2.5 : 1,
          ),
          boxShadow: (_active || widget.autoNext)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(
                    begin: Offset(_slideDir.toDouble(), 0),
                    end: Offset.zero,
                  ).animate(anim);
                  return ClipRect(
                    child: SlideTransition(
                      position: offset,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(widget.trailer.key),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.trailer.youtubeThumbnail,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.82),
                            ],
                            stops: const [0.35, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.autoNext && autoLeft != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: autoLeft / widget.autoNextTotal,
                            strokeWidth: 2.5,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        ),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                              child: Text(
                                '$autoLeft',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ShellCardPlayOverlay(
                active: false,
                visible: _active || widget.tvFocus || widget.autoNext,
                diameter: 44,
                iconSize: 26,
                onTap: () {
                  widget.onPointerActivity();
                  widget.onPlay();
                },
              ),
              Positioned(
                left: 12,
                right: 44,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.autoNext ? 'Up next' : widget.trailer.name,
                      maxLines: widget.autoNext ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.autoNext ? widget.trailer.name : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.autoNext) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget withChevrons(Widget child) {
      if (widget.count <= 1 || widget.autoNext) return child;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            width: 36,
            child: Center(
              child: _ChevronButton(
                icon: Icons.chevron_left_rounded,
                visible: _active || widget.tvFocus,
                onTap: () {
                  widget.onPointerActivity();
                  widget.onPrev();
                },
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            width: 36,
            child: Center(
              child: _ChevronButton(
                icon: Icons.chevron_right_rounded,
                visible: _active || widget.tvFocus,
                onTap: () {
                  widget.onPointerActivity();
                  widget.onNext();
                },
              ),
            ),
          ),
        ],
      );
    }

    void play() {
      widget.onPointerActivity();
      widget.onPlay();
    }

    if (widget.tvFocus) {
      return withChevrons(
        FocusableControl(
          focusNode: widget.focusNode,
          // OK on the card plays — ←/→ cycle the preview (cancels Up next).
          onTap: play,
          borderRadius: _radius,
          scaleOnFocus: 1.0,
          showFocusBorder: true,
          showFocusFill: false,
          onLeftEdge: widget.count > 1
              ? () {
                  widget.onPointerActivity();
                  widget.onPrev();
                }
              : null,
          onRightEdge: widget.count > 1
              ? () {
                  widget.onPointerActivity();
                  widget.onNext();
                }
              : null,
          onUpEdge: widget.onFocusUp == null
              ? null
              : () {
                  widget.onPointerActivity();
                  widget.onFocusUp!();
                },
          onDownEdge: widget.onFocusDown == null
              ? null
              : () {
                  widget.onPointerActivity();
                  widget.onFocusDown!();
                },
          onFocusChange: (f) {
            if (_focused == f) return;
            setState(() => _focused = f);
            if (f) widget.onPointerActivity();
          },
          child: face,
        ),
      );
    }

    // Desktop: card body is not a hit target — only center play + chevrons.
    return MouseRegion(
      onEnter: (_) {
        widget.onPointerActivity();
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      onHover: (_) => widget.onPointerActivity(),
      child: withChevrons(face),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
