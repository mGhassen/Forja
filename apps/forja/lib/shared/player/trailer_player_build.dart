part of 'trailer_player_screen.dart';

mixin _TrailerPlayerBuild on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  Widget build(BuildContext context) {
    final tvFocus = _s._tvFocus;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _s._exitTrailer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
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
                    if (ended) _s._focusNextTrailerIfNeeded();
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'trailerProgress',
                  callback: (args) {
                    if (!mounted || args.length < 2) return;
                    final currentSec = (args[0] as num?)?.toDouble() ?? 0;
                    final durationSec = (args[1] as num?)?.toDouble() ?? 0;
                    final pos = Duration(milliseconds: (currentSec * 1000).round());
                    final dur = Duration(milliseconds: (durationSec * 1000).round());
                    if (_s._position == pos && _s._duration == dur) return;
                    setState(() {
                      _s._position = pos;
                      _s._duration = dur;
                    });
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'trailerEscape',
                  callback: (_) => _s._exitTrailer(),
                );
              },
            ),
            DesktopWindowChrome.overlayDragStrip(),
            _buildChromeOverlay(tvFocus: tvFocus),
          ],
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
          left: 8,
          child: tvFocus
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: PlayerFlatIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    tvFocusable: true,
                    focusNode: _s._backFocus,
                    onPressed: _s._exitTrailer,
                  ),
                )
              : PlayerFlatIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: _s._exitTrailer,
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
        if (_s._ended && _s._hasNextTrailer) _buildUpNextOverlay(tvFocus: tvFocus),
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

  Widget _buildUpNextOverlay({required bool tvFocus}) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Next Trailer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );

    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Up next',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _s._nextTrailer!.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              if (tvFocus)
                FocusTraversalOrder(
                  order: const NumericFocusOrder(11),
                  child: FocusableControl(
                    focusNode: _s._nextTrailerFocus,
                    onTap: _s._playNextTrailer,
                    borderRadius: 8,
                    child: button,
                  ),
                )
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _s._playNextTrailer,
                    borderRadius: BorderRadius.circular(8),
                    child: button,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChrome({required bool tvFocus}) {
    final excludeFromTraversal = tvFocus && _s._ended && _s._hasNextTrailer;
    final chrome = Positioned(
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
                const SizedBox(height: 12),
                tvFocus
                    ? FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: CustomSeekbar(
                          duration: _s._duration,
                          position: _s._position,
                          onSeek: _s._seek,
                          tvFocusable: true,
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
                  _buildDesktopTransportRow(tvFocus: false),
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

    if (!excludeFromTraversal) return chrome;
    return ExcludeFocus(child: chrome);
  }

  Widget _buildTvTransportRow() {
    Widget ordered(int order, Widget child) => FocusTraversalOrder(
          order: NumericFocusOrder(order.toDouble()),
          child: child,
        );

    return Row(
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
        ordered(
          6,
          PlayerFlatIconButton(
            tvFocusable: true,
            icon: _s._muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            tooltip: 'Mute',
            onPressed: () {
              if (!_s._ready) return;
              unawaited(_s._toggleMute());
            },
          ),
        ),
        const SizedBox(width: 12),
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
    );
  }

  Widget _buildDesktopTransportRow({required bool tvFocus}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
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
              tvFocusable: tvFocus,
              icon: Icons.replay_10_rounded,
              tooltip: 'Back 10s',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._skip(-10));
              },
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
              icon: Icons.forward_10_rounded,
              tooltip: 'Forward 10s',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._skip(10));
              },
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
              icon: _s._muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              tooltip: 'Mute',
              onPressed: () {
                if (!_s._ready) return;
                unawaited(_s._toggleMute());
              },
            ),
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
              tvFocusable: tvFocus,
              icon: Icons.audiotrack_rounded,
              tooltip: 'Audio',
              onPressedWithContext: _s._showAudioMenu,
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
              icon: Icons.subtitles_outlined,
              tooltip: 'Subtitles',
              onPressedWithContext: _s._showSubtitleMenu,
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
              icon: Icons.hd_outlined,
              tooltip: 'Quality',
              onPressedWithContext: _s._showQualityMenu,
            ),
            const SizedBox(width: 2),
            PlayerFlatIconButton(
              tvFocusable: tvFocus,
              icon: Icons.speed_rounded,
              tooltip: 'Playback speed',
              onPressedWithContext: _s._showSpeedMenu,
            ),
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

