part of 'trailer_player_screen.dart';

mixin _TrailerPlayerBuild on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  @override
  Widget build(BuildContext context) {
    final tvFocus = _s._tvFocus;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_s._exitTrailer());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: tvFocus ? null : (_) => _s._onPointerActivity(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ForjaInAppWebView(
                key: ValueKey('trailer-player-${_s._trailer.key}'),
                initialData: InAppWebViewInitialData(
                  data: _s._embedHtml(),
                  baseUrl: WebUri(kYoutubeEmbedOrigin),
                ),
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: false,
                  disableVerticalScroll: true,
                  disableHorizontalScroll: true,
                  supportZoom: false,
                ),
                onWebViewCreated: (controller) {
                  _s._controller = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerReady',
                    callback: (_) {
                      if (!mounted) return;
                      setState(() => _s._ready = true);
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerState',
                    callback: (args) {
                      if (!mounted || args.length < 2) return;
                      final playing = args[0] == true;
                      final ended = args[1] == true;
                      if (_s._playing == playing && _s._ended == ended) return;
                      setState(() {
                        _s._playing = playing;
                        _s._ended = ended;
                      });
                      if (ended) {
                        _s._hideTimer?.cancel();
                        if (!_s._showControls) {
                          setState(() => _s._showControls = true);
                        }
                        _s._maybeStartAutoNext();
                      } else if (playing) {
                        _s._cancelAutoNext();
                        _s._startHideTimer();
                      }
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerProgress',
                    callback: (args) {
                      if (!mounted || args.length < 2) return;
                      final currentSec = (args[0] as num?)?.toDouble() ?? 0;
                      final durationSec = (args[1] as num?)?.toDouble() ?? 0;
                      final pos =
                          Duration(milliseconds: (currentSec * 1000).round());
                      final dur =
                          Duration(milliseconds: (durationSec * 1000).round());
                      if (_s._position == pos && _s._duration == dur) return;
                      final wasNearEnd = _s._showNextTrailerChip;
                      setState(() {
                        _s._position = pos;
                        _s._duration = dur;
                      });
                      if (!wasNearEnd && _s._showNextTrailerChip) {
                        _s._hideTimer?.cancel();
                        if (!_s._showControls) {
                          setState(() => _s._showControls = true);
                        }
                        _s._focusNextTrailerIfNeeded();
                      }
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerEscape',
                    callback: (_) => unawaited(_s._exitTrailer()),
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerDoubleClick',
                    callback: (_) {
                      if (!_s._supportsWindowFullscreen) return;
                      unawaited(_s._toggleFullscreen());
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerTap',
                    callback: (_) {
                      if (_s._tvFocus) return;
                      if (!mounted) return;
                      if (_s._showControls) {
                        setState(() => _s._showControls = false);
                        _s._hideTimer?.cancel();
                      } else {
                        _s._onPointerActivity();
                      }
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'trailerPointer',
                    callback: (_) {
                      if (_s._tvFocus) return;
                      _s._onPointerActivity();
                    },
                  );
                },
              ),
              // Chrome sits above the WebView. Pointer/fullscreen come from JS
              // (platform WebView steals Flutter gesture arena on desktop).
              DesktopWindowChrome.overlayDragStrip(),
              AnimatedOpacity(
                opacity: (tvFocus || _s._showControls) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !tvFocus && !_s._showControls,
                  child: _buildChromeOverlay(tvFocus: tvFocus),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChromeOverlay({required bool tvFocus}) {
    final layers = Stack(
      clipBehavior: Clip.none,
      children: [
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
                    onPressed: () => unawaited(_s._exitTrailer()),
                  ),
                )
              : PlayerFlatIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => unawaited(_s._exitTrailer()),
                ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ExcludeFocus(
            child: PlayerOverlayGradient(isTop: true),
          ),
        ),
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
    return Positioned.fill(
      child: FocusScope(
        debugLabel: 'trailer-player-chrome',
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
                            order: const NumericFocusOrder(12),
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
                          tvFocusUpNode: _s._hasMoreTrailers
                              ? _s._nextTrailerFocus
                              : _s._backFocus,
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
                  icon: Icons.replay_10_rounded,
                  tooltip: 'Back 10s',
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
                  icon: Icons.forward_10_rounded,
                  tooltip: 'Forward 10s',
                  onPressed: () {
                    if (!_s._ready) return;
                    unawaited(_s._skip(10));
                  },
                ),
              ),
              const SizedBox(width: 2),
              ordered(6, _buildVolumeControl(tvFocus: true)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ordered(
                7,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.audiotrack_rounded,
                  tooltip: 'Audio',
                  onPressedWithContext: _s._showAudioMenu,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                8,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.subtitles_outlined,
                  tooltip: 'Subtitles',
                  onPressedWithContext: _s._showSubtitleMenu,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                9,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.hd_outlined,
                  tooltip: 'Quality',
                  onPressedWithContext: _s._showQualityMenu,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                10,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  icon: Icons.speed_rounded,
                  tooltip: 'Playback speed',
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
              icon: Icons.audiotrack_rounded,
              tooltip: 'Audio',
              onPressedWithContext: _s._showAudioMenu,
            ),
            const SizedBox(width: 2),
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
              Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.autoNext && autoLeft != null)
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
                          width: widget.autoNext ? 30 : 34,
                          height: widget.autoNext ? 30 : 34,
                          child: widget.autoNext && autoLeft != null
                              ? Center(
                                  child: Text(
                                    '$autoLeft',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : Icon(
                                  widget.playing
                                      ? Icons.replay_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          onTap: play,
          borderRadius: _radius,
          scaleOnFocus: 1.0,
          showFocusBorder: true,
          showFocusFill: false,
          onLeftEdge: widget.count > 1 && !widget.autoNext ? widget.onPrev : null,
          onRightEdge:
              widget.count > 1 && !widget.autoNext ? widget.onNext : null,
          onFocusChange: (f) {
            if (_focused == f) return;
            setState(() => _focused = f);
            if (f) widget.onPointerActivity();
          },
          child: face,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        widget.onPointerActivity();
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      onHover: (_) => widget.onPointerActivity(),
      child: withChevrons(
        GestureDetector(
          onTap: play,
          behavior: HitTestBehavior.opaque,
          child: face,
        ),
      ),
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
