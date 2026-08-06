part of 'iptv_pt_player_screen.dart';

mixin _IptvPtPlayerUi on ConsumerState<IptvPtPlayerScreen> {
  _IptvPtPlayerScreenState get _s => this as _IptvPtPlayerScreenState;

  void _closeGuideAndFocusPlayer() {
    setState(() {
      _s._guideVisible = false;
      _s._controlsVisible = true;
    });
    _scheduleHideControls();
    _focusPlayerChrome();
  }

  void _toggleGuide() {
    if (widget.channelGuide == null) return;
    setState(() {
      _s._guideVisible = !_s._guideVisible;
      if (_s._guideVisible) {
        _s._searchVisible = false;
        _s._controlsVisible = true;
        _s._hideControlsTimer?.cancel();
        // Always open on the playing channel's category.
        final playingGroup =
            widget.channelGuide!.groupIdForChannel(_s._currentChannelId);
        if (playingGroup != null && playingGroup.isNotEmpty) {
          _s._selectedGroupId = playingGroup;
        }
      } else {
        _scheduleHideControls();
        _focusPlayerChrome();
      }
    });
  }

  void _toggleSearch() {
    if (widget.channelGuide == null) return;
    setState(() {
      _s._searchVisible = !_s._searchVisible;
      if (_s._searchVisible) {
        _s._guideVisible = false;
        _s._controlsVisible = true;
        _s._hideControlsTimer?.cancel();
      } else {
        _scheduleHideControls();
      }
    });
  }

  void _onSearchChannelSelected(IptvGuideChannel ch) {
    setState(() => _s._searchVisible = false);
    _s._switchChannel(ch);
    _scheduleHideControls();
  }

  IptvGuideChannel? _currentGuideChannel() {
    final guide = widget.channelGuide;
    if (guide == null || _s._currentChannelId.isEmpty) return null;
    for (final ch in guide.channels) {
      if (ch.id == _s._currentChannelId) return ch;
    }
    return null;
  }

  Future<List<EpgEntry>>? _floatingEpgFuture() {
    final epgEnabled = ref.watch(iptvEpgEnabledProvider);
    if (!epgEnabled || _s._epgCache == null) return null;
    final stream = _currentGuideChannel()?.xtreamStream;
    if (stream == null) return null;
    return _s._epgCache!.load(stream, limit: 8);
  }

  /// Android TV Exo: no bottom progress chrome (live track or VOD scrubber).
  bool get _showProgressChrome =>
      !(_s._exoBackend && PlatformInfo.isAndroidTv);

  double _floatingEpgBottomInset(BuildContext context, bool compact) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barPad = compact ? 12.0 : 18.0;
    const barHeight = 56.0;
    final seekbar =
        _showProgressChrome ? (compact ? 48.0 : 56.0) : 0.0;
    return safeBottom + barPad + barHeight + seekbar + 12;
  }

  void _showStatsMenu(BuildContext anchorContext) {
    if (_s._exoBackend || _s._player == null) return;
    // Opening a menu cancels an armed player-exit Back.
    _s._tvBackExitArmed = false;
    PlayerBackExitGate.exitReady = false;
    _scheduleHideControls();
    IptvPlayerStatsPanel.show(
      context,
      player: _s._player!,
      anchorContext: anchorContext,
      alignment: Alignment.topRight,
      margin: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        right: 16,
      ),
      snapshot: () => IptvPlayerStatsSnapshot(
        playing: _s._playing,
        buffering: _s._buffering,
        sourceLabel: _s._sources[_s._sourceIdx].label,
        retryAttempt: _s._retryAttempt,
        volume: _s._volume,
        buffered: _s._buffered,
      ),
    );
  }

  void _scheduleHideControls() {
    _s._hideControlsTimer?.cancel();
    if (_s._guideVisible || _s._searchVisible) return;
    // TV: match movie/Exo idle (10s). 4s was hiding mid D-pad walk.
    final hideAfter = iptvUseTvFocus(context)
        ? const Duration(seconds: 10)
        : const Duration(seconds: 4);
    _s._hideControlsTimer = Timer(hideAfter, () {
      if (!mounted) return;
      // Keep chrome (and its focus graph) while a menu owns D-pad.
      if (playerChromeOverlayBlocksSeek()) {
        _scheduleHideControls();
        return;
      }
      // D-pad still on a chrome control — do not ExcludeFocus mid-traversal
      // (same as Exo I130-T05; left focus on Play with dead ←/→).
      if (iptvUseTvFocus(context) &&
          playerTvChromeHasFocus(_s._playerTvKeyFocus)) {
        _scheduleHideControls();
        return;
      }
      setState(() => _s._controlsVisible = false);
    });
  }

  void _onPlayerMouseMove() {
    if (iptvUseTvFocus(context)) return;
    if (_s._guideVisible || _s._searchVisible) return;
    if (!_s._controlsVisible) {
      setState(() => _s._controlsVisible = true);
    }
    _scheduleHideControls();
  }

  void _claimPlayFocus() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    _s._tvBackExitArmed = false;
    // Underlay WebView / Exo SurfaceView can re-take leanback focus after
    // hybrid composition remounts — re-block before claiming Play.
    if (PlatformInfo.isAndroidTv) {
      unawaited(PlatformChannel.releaseUnderlayPlatformViewFocus());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._controlsVisible) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      if (!_s._playFocus.canRequestFocus) return;
      _s._playFocus.requestFocus();
    });
  }

  void _claimBackFocus() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._controlsVisible) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      if (!_s._backFocus.canRequestFocus) return;
      _s._backFocus.requestFocus();
    });
  }

  /// Alias used by engine boot — same as movie/Exo [claimPlayFocus].
  void _focusPlayerChrome() => _claimPlayFocus();

  void _focusPlayerBack() => _claimBackFocus();

  bool _isPlayerBackFocused() => _s._backFocus.hasFocus;

  void _revealControlsAndFocus({required bool back}) {
    setState(() => _s._controlsVisible = true);
    _scheduleHideControls();
    if (back) {
      _claimBackFocus();
    } else {
      _claimPlayFocus();
    }
  }

  void _toggleControls() {
    final show = !_s._controlsVisible;
    setState(() => _s._controlsVisible = show);
    if (show) {
      _scheduleHideControls();
      _claimPlayFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellScopeBuilder(builder: (context, _) => _buildPlayer(context));
  }

  Widget _buildPlayer(BuildContext context) {
    if (!_s._playerReady) {
      final banner = _s._statusBanner;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white54),
              if (banner != null) ...[
                const SizedBox(height: 16),
                Text(
                  banner,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final compact = size.shortestSide < 600;
    // Include enter-pending: window shrinks before the stream sets _isPipMode.
    final pipMode =
        _s._isPipMode || PipService.instance.isDesktopActive;
    final epgFuture = (!_s._guideVisible && !_s._searchVisible)
        ? _floatingEpgFuture()
        : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: PlayerTvKeyScope(
        enabled:
            iptvUseTvFocus(context) && !_s._guideVisible && !_s._searchVisible,
        focusNode: _s._playerTvKeyFocus,
        showControls: _s._controlsVisible,
        onBack: () {
          if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
            ShellTvFocusCoordinator.handleShellBackKey();
            return;
          }
          if (dismissAnyPlayerChromeOverlay()) return;
          unawaited(_s._exitIptvPlayer());
        },
        onPlayPause: () {
          if (_s._playing) {
            unawaited(_s._enginePause());
          } else {
            unawaited(_s._enginePlay());
          }
          _scheduleHideControls();
        },
        onShowControls: () {
          setState(() => _s._controlsVisible = true);
          _scheduleHideControls();
          _focusPlayerChrome();
        },
        onSeekBack: () {
          if (!_s._isVod) {
            _revealControlsAndFocus(back: false);
            return;
          }
          var target = _s._position - const Duration(seconds: 10);
          if (target < Duration.zero) target = Duration.zero;
          unawaited(_s._engineSeek(target));
          _scheduleHideControls();
        },
        onSeekForward: () {
          if (!_s._isVod) {
            _revealControlsAndFocus(back: false);
            return;
          }
          var target = _s._position + const Duration(seconds: 10);
          if (target > _s._duration) target = _s._duration;
          unawaited(_s._engineSeek(target));
          _scheduleHideControls();
        },
        onVolumeUp: () {
          setState(() => _s._setCachedVolume((_s._volume + 5).clamp(0, 100)));
        },
        onVolumeDown: () {
          setState(() => _s._setCachedVolume((_s._volume - 5).clamp(0, 100)));
        },
        onToggleControls: _toggleControls,
        onFocusBack: () => _revealControlsAndFocus(back: true),
        onFocusPlay: () => _revealControlsAndFocus(back: false),
        onControlsActivity: _scheduleHideControls,
        child: MouseRegion(
          onHover: (_) => _onPlayerMouseMove(),
          cursor: (_s._controlsVisible || _s._guideVisible || _s._searchVisible)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: pipMode ? null : _toggleControls,
            // Double-click / double-tap video → toggle fullscreen (same as films).
            // Android TV is already immersive — no fullscreen toggle.
            onDoubleTap: () {
              if (pipMode ||
                  _s._guideVisible ||
                  _s._searchVisible ||
                  iptvUseTvFocus(context)) {
                return;
              }
              unawaited(_s._toggleFullscreen());
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video - fill the stack like the main player (Center can leave
                // a zero-sized surface on Android when Impeller composites siblings).
                Positioned.fill(
                  child: ExcludeFocus(
                    child: RepaintBoundary(
                      child: _s._exoBackend
                          ? ExoPlayerView(
                              viewId: _s._exoViewId!,
                              // IPTV Exo always TextureView on ATV: physical
                              // SurfaceView + hybrid composition went audio-only
                              // black (even cold-open) and the composition-dead
                              // surface still fires renderedFirstFrame, so the
                              // watchdog cannot rescue it (issue 133).
                              allowSurfaceView: false,
                            )
                          : Video(
                              key: ValueKey(_s._videoEpoch),
                              controller: _s._controller!,
                              fit: BoxFit.contain,
                              fill: Colors.black,
                              controls: NoVideoControls,
                            ),
                    ),
                  ),
                ),
                // Reconnect/buffering banner - hidden in PiP
                if (!pipMode &&
                    (_s._buffering || _s._statusBanner != null))
                  _buildBanner(),
                // Top bar + bottom controls (below guide when open).
                // Hidden entirely while PiP is active - replaced by the
                // floating revert button below on desktop.
                if (!pipMode)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _s._controlsVisible ? 1 : 0,
                    child: ExcludeFocus(
                      excluding:
                          iptvUseTvFocus(context) &&
                          (!_s._controlsVisible ||
                              _s._guideVisible ||
                              _s._searchVisible),
                      child: IgnorePointer(
                        ignoring:
                            !_s._controlsVisible ||
                            _s._guideVisible ||
                            _s._searchVisible,
                        child: _buildOverlay(compact),
                      ),
                    ),
                  ),
                if (pipMode) _buildPipRevertOverlay(),
                // Positioned.fill must be a direct Stack child — wrapping the
                // overlay (which used to return Positioned) in RepaintBoundary
                // caused ParentDataWidget spam on every frame.
                if (!pipMode &&
                    _s._searchVisible &&
                    widget.channelGuide != null)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: IptvChannelSearchOverlay(
                        guide: widget.channelGuide!,
                        currentChannelId: _s._currentChannelId,
                        onChannelSelected: _onSearchChannelSelected,
                        onClose: () => setState(() {
                          _s._searchVisible = false;
                          _scheduleHideControls();
                        }),
                      ),
                    ),
                  ),
                if (!pipMode &&
                    _s._guideVisible &&
                    widget.channelGuide != null)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: IptvChannelGuidePanel(
                        guide: widget.channelGuide!,
                        selectedGroupId: _s._selectedGroupId,
                        currentChannelId: _s._currentChannelId,
                        onGroupSelected: (id) {
                          setState(() => _s._selectedGroupId = id);
                        },
                        onChannelSelected: _s._switchChannel,
                        onClose: _closeGuideAndFocusPlayer,
                      ),
                    ),
                  ),
                if (!pipMode && epgFuture != null)
                  Positioned(
                    right: 16,
                    bottom: _floatingEpgBottomInset(context, compact),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _s._controlsVisible ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_s._controlsVisible,
                        child: IptvFloatingEpg(
                          key: ValueKey(_s._currentChannelId),
                          future: epgFuture,
                          maxWidth: compact ? 440 : 540,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: IptvShellStyle.accent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IptvShellStyle.accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _s._statusBanner ?? 'Buffering…',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(bool compact) {
    final overlay = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0, 0.25, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(compact),
            const Spacer(),
            // VOD scrubber or live EPG / live-edge — hidden on Android TV Exo.
            if (_showProgressChrome)
              _s._isVod
                  ? _buildSeekbar(compact)
                  : _buildLiveProgressBar(compact),
            _buildBottomBar(compact),
          ],
        ),
      ),
    );
    if (!iptvUseTvFocus(context)) return overlay;
    return FocusScope(
      debugLabel: 'player-chrome',
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: overlay,
      ),
    );
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return 8;
  }

  double _topBarLeftPadding(BuildContext context) => 16;

  /// System-style PiP chrome — expand / Minimize / Close · ±15 · scrubber.
  Widget _buildPipRevertOverlay() {
    final vod = _s._isVod;
    return DesktopPipOverlay(
      hovering: _s._pipHover,
      onHoverChanged: (on) {
        if (!mounted) return;
        if (_s._pipHover == on) return;
        setState(() => _s._pipHover = on);
      },
      playing: _s._playing,
      onTogglePlay: () {
        if (_s._playing) {
          _s._userPlayWhenReady = false;
          unawaited(_s._enginePause());
        } else {
          _s._userPlayWhenReady = true;
          unawaited(_s._enginePlay());
        }
        setState(() {});
      },
      onClose: () => unawaited(_s._exitIptvPlayer()),
      onSeekBack: vod
          ? () {
              var target = _s._position - const Duration(seconds: 15);
              if (target < Duration.zero) target = Duration.zero;
              unawaited(_s._engineSeek(target));
            }
          : null,
      onSeekForward: vod
          ? () {
              var target = _s._position + const Duration(seconds: 15);
              if (target > _s._duration) target = _s._duration;
              unawaited(_s._engineSeek(target));
            }
          : null,
      position: vod ? _s._position : null,
      duration: vod ? _s._duration : null,
      onSeekTo: vod
          ? (pos) => unawaited(_s._engineSeek(pos))
          : null,
    );
  }

  Future<void> _togglePip() async {
    await PipService.instance.toggle();
    if (!mounted) return;
    setState(() {});
    _scheduleHideControls();
  }

  BuiltInPlayerEngine get _builtInEngine => _s._exoBackend
      ? BuiltInPlayerEngine.exoPlayer
      : BuiltInPlayerEngine.mediaKit;

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    _scheduleHideControls();
    if (!anchorContext.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: _builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) async {
        if (builtInEngine != null) {
          await _s._switchBuiltInEngine(builtInEngine);
          return;
        }
        if (externalPlayer == null) return;
        final url = _s._sources[_s._sourceIdx].url;
        if (url.isEmpty) return;
        _s._userPlayWhenReady = false;
        await _s._enginePause();
        if (!mounted) return;
        final ok = await ExternalPlayerService.launch(
          url: url,
          title: _s._title,
          headers: const {'User-Agent': _IptvPtPlayerScreenState._ua},
          context: context,
          playerName: externalPlayer,
        );
        if (!mounted) return;
        if (!ok) {
          ForjaToast.warning('$externalPlayer not found.');
          _s._userPlayWhenReady = true;
          await _s._enginePlay();
        }
      },
    );
  }

  /// Flat top-bar action — same widget path as movie/Exo (`PlayerFlatIconButton`).
  /// TV must use [tvFocusable] + FocusableControl edges; the old iptvTap wrapper
  /// looked focused but → from Back often failed to claim Player (issue 110).
  Widget _topBarFlatAction({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    ValueChanged<BuildContext>? onPressedWithContext,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    FocusNode? focusNode,
    int? tvFocusOrder,
  }) {
    assert(onPressed != null || onPressedWithContext != null);
    final tv = iptvUseTvFocus(context);
    final button = PlayerFlatIconButton(
      icon: icon,
      tooltip: tooltip,
      size: 44,
      tvFocusable: tv,
      focusNode: focusNode,
      onPressed: onPressed,
      onPressedWithContext: onPressedWithContext,
      onDownEdge: onDownEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
    );
    if (tvFocusOrder == null) return button;
    return FocusTraversalOrder(
      order: NumericFocusOrder(tvFocusOrder.toDouble()),
      child: button,
    );
  }

  Widget _buildTopBar(bool compact) {
    // PiP is phone/desktop chrome - hide on Android TV (matches VOD player).
    final showPip =
        PipService.instance.isSupported && !iptvUseTvFocus(context);
    final showStats = !_s._exoBackend;
    final tv = iptvUseTvFocus(context);

    void downFromTop() {
      if (_showProgressChrome &&
          _s._isVod &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      _claimPlayFocus();
    }

    void claim(FocusNode node) {
      void tryClaim() {
        if (!mounted) return;
        if (node.canRequestFocus) node.requestFocus();
      }

      tryClaim();
      // Mid-rebuild / ExcludeFocus race — retry once next frame (issue 110).
      if (!node.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
      }
    }

    /// Explicit ←/→ edges — [focusInDirection] often fails across the title gap.
    VoidCallback? rightFromBack() {
      if (!tv) return null;
      return () => claim(_s._playerMenuFocus);
    }

    VoidCallback? leftFromPlayer() {
      if (!tv) return null;
      return () => claim(_s._backFocus);
    }

    VoidCallback? rightFromPlayer() {
      if (!tv || !showStats) return null;
      return () => claim(_s._statsFocus);
    }

    Widget wrapOrder(int order, Widget child) {
      if (!tv) return child;
      return FocusTraversalOrder(
        order: NumericFocusOrder(order.toDouble()),
        child: child,
      );
    }

    var next = 1; // 1 = Back
    final playerOrder = ++next;
    final statsOrder = showStats ? ++next : null;
    final pipOrder = showPip ? ++next : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _topBarLeftPadding(context),
        _topBarTopPadding(context),
        8,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            wrapOrder(
              1,
              iptvBackButton(
                context,
                onTap: () => unawaited(_s._exitIptvPlayer()),
                color: Colors.white,
                size: 22,
                focusNode: _s._backFocus,
                onRightEdge: rightFromBack(),
                onDownEdge: () {
                  _s._tvBackExitArmed = false;
                  downFromTop();
                },
                onFocusChange: (focused) {
                  if (focused) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!_isPlayerBackFocused()) {
                      _s._tvBackExitArmed = false;
                      PlayerBackExitGate.exitReady = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _s._title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IptvShellStyle.overlayTitle.copyWith(
                      fontSize: compact ? 16 : 18,
                      height: 1.15,
                    ),
                  ),
                  if ((_s._subtitle ?? '').isNotEmpty)
                    Text(
                      _s._subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _topBarFlatAction(
              icon: Icons.smart_display_outlined,
              tooltip: 'Player',
              tvFocusOrder: playerOrder,
              focusNode: _s._playerMenuFocus,
              onPressedWithContext: (ctx) => unawaited(_showPlayerMenu(ctx)),
              onDownEdge: downFromTop,
              onLeftEdge: leftFromPlayer(),
              onRightEdge: rightFromPlayer(),
            ),
            if (showStats)
              _topBarFlatAction(
                icon: Icons.monitor_heart_outlined,
                tooltip: 'Stream stats',
                tvFocusOrder: statsOrder,
                focusNode: _s._statsFocus,
                onPressedWithContext: _showStatsMenu,
                onDownEdge: downFromTop,
                onLeftEdge:
                    tv ? () => claim(_s._playerMenuFocus) : null,
              ),
            if (showPip)
              _topBarFlatAction(
                icon: PipService.instance.isDesktopActive
                    ? Icons.picture_in_picture_alt_rounded
                    : Icons.picture_in_picture_rounded,
                tooltip: 'Picture in Picture',
                tvFocusOrder: pipOrder,
                onPressed: () => unawaited(_togglePip()),
                onDownEdge: downFromTop,
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  VOD SEEKBAR - only shown when duration > 0 (Xtream movies / series)
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildChannelLogo(bool compact) {
    if ((_s._logoUrl ?? '').isEmpty) return const SizedBox.shrink();
    final size = compact ? 56.0 : 72.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _s._logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  static double _epgProgress(EpgEntry e) {
    final now = DateTime.now();
    final total = e.stop.difference(e.start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(e.start).inSeconds.clamp(0, total);
    return elapsed / total;
  }

  /// Live chrome: same logo + track + time row as VOD, driven by EPG when
  /// available (read-only). Pure live with no guide still shows a full track.
  /// Not used on Android TV Exo ([_showProgressChrome] is false there).
  Widget _buildLiveProgressBar(bool compact) {
    final future = _floatingEpgFuture();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          if ((_s._logoUrl ?? '').isNotEmpty) ...[
            _buildChannelLogo(compact),
            SizedBox(width: compact ? 10 : 16),
          ],
          Expanded(
            child: future == null
                ? _liveProgressTrack(value: 1.0, compact: compact)
                : FutureBuilder<List<EpgEntry>>(
                    future: future,
                    builder: (context, snap) {
                      final data = snap.data ?? const <EpgEntry>[];
                      EpgEntry? nowEntry;
                      if (data.isNotEmpty) {
                        nowEntry = data.cast<EpgEntry?>().firstWhere(
                          (e) => e!.isNow,
                          orElse: () => data.first,
                        );
                      }
                      final value = nowEntry != null
                          ? _epgProgress(nowEntry).clamp(0.0, 1.0)
                          : 1.0;
                      return _liveProgressTrack(
                        value: value,
                        compact: compact,
                      );
                    },
                  ),
          ),
          SizedBox(
            width: compact ? 84 : 100,
            child: future == null
                ? _liveProgressTimeLabel('LIVE', compact)
                : FutureBuilder<List<EpgEntry>>(
                    future: future,
                    builder: (context, snap) {
                      final data = snap.data ?? const <EpgEntry>[];
                      EpgEntry? nowEntry;
                      if (data.isNotEmpty) {
                        nowEntry = data.cast<EpgEntry?>().firstWhere(
                          (e) => e!.isNow,
                          orElse: () => data.first,
                        );
                      }
                      if (nowEntry == null || !nowEntry.isNow) {
                        return _liveProgressTimeLabel('LIVE', compact);
                      }
                      final elapsed = DateTime.now().difference(nowEntry.start);
                      final safe = elapsed.isNegative ? Duration.zero : elapsed;
                      return _liveProgressTimeLabel(
                        _IptvPtPlayerScreenState._fmtDur(safe),
                        compact,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _liveProgressTimeLabel(String text, bool compact) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: GoogleFonts.spaceMono(
        color: Colors.white,
        fontSize: compact ? 12 : 13,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
      ),
    );
  }

  Widget _liveProgressTrack({required double value, required bool compact}) {
    return SizedBox(
      height: compact ? 28 : 32,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 3.5,
            backgroundColor: Colors.white24,
            color: ForjaShellColors.brandGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildSeekbar(bool compact) {
    final totalMs = _s._duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();
    final currentMs = _s._isSeeking
        ? _s._seekPreview
        : _s._position.inMilliseconds.toDouble().clamp(0.0, totalMs);
    final shownPos = Duration(milliseconds: currentMs.toInt());
    final tv = iptvUseTvFocus(context);

    Widget slider;
    if (tv) {
      slider = CustomSeekbar(
        duration: _s._duration,
        position: _s._isSeeking
            ? Duration(milliseconds: _s._seekPreview.toInt())
            : _s._position,
        bufferedPosition: _s._buffered,
        focusNode: _s._seekFocus,
        tvFocusable: true,
        onTvFocusUp: () => _claimBackFocus(),
        onTvFocusDown: () => _claimPlayFocus(),
        onDragStart: () {
          setState(() {
            _s._isSeeking = true;
            _s._seekPreview = _s._position.inMilliseconds.toDouble();
          });
          _s._hideControlsTimer?.cancel();
        },
        onDragEnd: () {
          if (!_s._isSeeking) return;
          setState(() => _s._isSeeking = false);
          _scheduleHideControls();
        },
        onSeek: (target) async {
          setState(() {
            _s._isSeeking = false;
            _s._position = target;
            _s._seekPreview = target.inMilliseconds.toDouble();
          });
          try {
            await _s._engineSeek(target);
          } catch (_) {}
          _scheduleHideControls();
        },
      );
    } else {
      slider = SliderTheme(
        data: IptvShellStyle.sliderTheme(context).copyWith(
          activeTrackColor: ForjaShellColors.brandGreen,
          thumbColor: ForjaShellColors.brandGreen,
          overlayColor: ForjaShellColors.brandGreen.withValues(alpha: 0.2),
          trackHeight: 3.5,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 7,
            elevation: 3,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: currentMs.clamp(0.0, totalMs),
          min: 0,
          max: totalMs,
          onChangeStart: (v) {
            setState(() {
              _s._isSeeking = true;
              _s._seekPreview = v;
            });
            _s._hideControlsTimer?.cancel();
          },
          onChanged: (v) {
            setState(() => _s._seekPreview = v);
          },
          onChangeEnd: (v) async {
            final target = Duration(milliseconds: v.toInt());
            setState(() {
              _s._isSeeking = false;
              _s._position = target;
            });
            try {
              await _s._engineSeek(target);
            } catch (_) {}
            _scheduleHideControls();
          },
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          if ((_s._logoUrl ?? '').isNotEmpty) ...[
            _buildChannelLogo(compact),
            SizedBox(width: compact ? 10 : 16),
          ],
          Expanded(child: slider),
          // Current time
          SizedBox(
            width: compact ? 84 : 100,
            child: Text(
              _IptvPtPlayerScreenState._fmtDur(shownPos),
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool compact) {
    final tvFocus = iptvUseTvFocus(context);
    /// Left transport (Play / Replay) → seekbar when present, else Back.
    void upFromLeftControls() {
      if (_showProgressChrome &&
          _s._isVod &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      _claimBackFocus();
    }

    /// Right chrome (Search / Guide / Source) → top-right Player (not Back).
    /// ATV Exo hides the progress bar, so ↑ used to dump everything on Back and
    /// leave Player unreachable except → across the title gap.
    void upFromRightControls() {
      if (_showProgressChrome &&
          _s._isVod &&
          _s._seekFocus.canRequestFocus) {
        _s._seekFocus.requestFocus();
        return;
      }
      if (_s._playerMenuFocus.canRequestFocus) {
        _s._playerMenuFocus.requestFocus();
        return;
      }
      _claimBackFocus();
    }

    void claim(FocusNode node) {
      void tryClaim() {
        if (!mounted) return;
        if (node.canRequestFocus) node.requestFocus();
      }

      tryClaim();
      if (!node.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tryClaim());
      }
    }

    Widget wrapOrder(int order, Widget child) {
      if (!tvFocus) return child;
      return FocusTraversalOrder(
        order: NumericFocusOrder(order.toDouble()),
        child: child,
      );
    }

    final hasGuide = widget.channelGuide != null;
    final hasSources = _s._sources.length > 1;

    // Explicit ←/→ chain (issue 131) — Spacer / title-gap geometry fails on ATV.
    FocusNode? rightOfPlay() {
      if (!tvFocus) return null;
      return _s._replayFocus;
    }

    FocusNode? rightOfReplay() {
      if (!tvFocus) return null;
      if (hasGuide) return _s._searchChromeFocus;
      if (hasSources) return _s._bottomSourceFocus;
      return null;
    }

    FocusNode? leftOfSearch() {
      if (!tvFocus) return null;
      return _s._replayFocus;
    }

    FocusNode? rightOfSearch() {
      if (!tvFocus) return null;
      return _s._guideFocus;
    }

    FocusNode? leftOfGuide() {
      if (!tvFocus) return null;
      return _s._searchChromeFocus;
    }

    FocusNode? rightOfGuide() {
      if (!tvFocus || !hasSources) return null;
      return _s._bottomSourceFocus;
    }

    FocusNode? leftOfBottomSource() {
      if (!tvFocus) return null;
      if (hasGuide) return _s._guideFocus;
      return _s._replayFocus;
    }

    var order = 10; // bottom row after top-bar orders
    Widget nextIcon({
      required IconData icon,
      required VoidCallback onTap,
      bool big = false,
      FocusNode? focusNode,
      VoidCallback? onUpEdge,
      VoidCallback? onLeftEdge,
      VoidCallback? onRightEdge,
    }) {
      final widget = IptvRoundIcon(
        icon: icon,
        big: big,
        focusNode: focusNode,
        onUpEdge: onUpEdge,
        onLeftEdge: onLeftEdge,
        onRightEdge: onRightEdge,
        onTap: onTap,
      );
      return wrapOrder(order++, widget);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 12 : 18,
      ),
      child: Row(
        children: [
          nextIcon(
            icon: _s._playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            big: true,
            focusNode: _s._playFocus,
            onUpEdge: tvFocus ? upFromLeftControls : null,
            onRightEdge: rightOfPlay() == null
                ? null
                : () => claim(rightOfPlay()!),
            onTap: () async {
              if (_s._playing) {
                _s._userPlayWhenReady = false;
                _s._pausedAt = DateTime.now();
                await _s._enginePause();
              } else {
                _s._userPlayWhenReady = true;
                final pausedAt = _s._pausedAt;
                _s._pausedAt = null;
                await _s._enginePlay();
                // Live: after a real pause, rejoin the edge (don't resume
                // from the frozen demuxer position seconds behind).
                if (pausedAt != null &&
                    iptvExoUrlLooksLive(
                      _s._sources.isEmpty
                          ? ''
                          : _s._sources[_s._sourceIdx].url,
                    ) &&
                    DateTime.now().difference(pausedAt) >=
                        const Duration(seconds: 2)) {
                  _s._scheduleJumpToLive();
                }
              }
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 14),
          nextIcon(
            icon: Icons.replay_rounded,
            focusNode: _s._replayFocus,
            onUpEdge: tvFocus ? upFromLeftControls : null,
            onLeftEdge: tvFocus ? () => claim(_s._playFocus) : null,
            onRightEdge: rightOfReplay() == null
                ? null
                : () => claim(rightOfReplay()!),
            onTap: () {
              unawaited(_s._reloadCurrent());
              _scheduleHideControls();
            },
          ),
          if (!tvFocus) ...[
            const SizedBox(width: 14),
            MouseRegion(
              onEnter: (_) {
                setState(() => _s._volumeHovering = true);
                _s._hideVolumeTimer?.cancel();
                _scheduleHideControls();
              },
              onExit: (_) {
                setState(() => _s._volumeHovering = false);
                _scheduleHideVolumeSlider();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IptvRoundIcon(
                    icon: _s._muted || _s._volume == 0
                        ? Icons.volume_off_rounded
                        : (_s._volume < 40
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded),
                    onTap: _toggleMute,
                    onLongPress: () {
                      setState(
                        () => _s._showVolumeSlider = !_s._showVolumeSlider,
                      );
                      if (_s._showVolumeSlider) {
                        _s._hideVolumeTimer?.cancel();
                      } else {
                        _scheduleHideVolumeSlider();
                      }
                      _scheduleHideControls();
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: SizedBox(
                      width: (_s._showVolumeSlider || _s._volumeHovering)
                          ? (compact ? 110 : 160)
                          : 0,
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SliderTheme(
                            data: IptvShellStyle.sliderTheme(context).copyWith(
                              inactiveTrackColor: Colors.white24,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: _s._volume.clamp(0.0, 100.0),
                              min: 0,
                              max: 100,
                              onChangeStart: (_) {
                                _s._hideVolumeTimer?.cancel();
                                _scheduleHideControls();
                              },
                              onChanged: (v) {
                                setState(() => _s._setCachedVolume(v));
                                _scheduleHideVolumeSlider();
                                _scheduleHideControls();
                              },
                              onChangeEnd: (_) => _scheduleHideVolumeSlider(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (hasGuide) ...[
            nextIcon(
              icon: Icons.search_rounded,
              focusNode: _s._searchChromeFocus,
              onUpEdge: tvFocus ? upFromRightControls : null,
              onLeftEdge:
                  leftOfSearch() == null ? null : () => claim(leftOfSearch()!),
              onRightEdge: rightOfSearch() == null
                  ? null
                  : () => claim(rightOfSearch()!),
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 14),
            nextIcon(
              icon: Icons.grid_view_rounded,
              focusNode: _s._guideFocus,
              onUpEdge: tvFocus ? upFromRightControls : null,
              onLeftEdge:
                  leftOfGuide() == null ? null : () => claim(leftOfGuide()!),
              onRightEdge: rightOfGuide() == null
                  ? null
                  : () => claim(rightOfGuide()!),
              onTap: _toggleGuide,
            ),
            const SizedBox(width: 14),
          ],
          if (hasSources)
            Builder(
              builder: (anchorContext) => nextIcon(
                icon: Icons.swap_horiz_rounded,
                focusNode: _s._bottomSourceFocus,
                onUpEdge: tvFocus ? upFromRightControls : null,
                onLeftEdge: leftOfBottomSource() == null
                    ? null
                    : () => claim(leftOfBottomSource()!),
                onTap: () => _showSourcePicker(anchorContext: anchorContext),
              ),
            ),
          if (hasSources) const SizedBox(width: 14),
          if (!tvFocus)
            IptvRoundIcon(
              icon: _s._isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              onTap: _s._toggleFullscreen,
            ),
        ],
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      if (_s._muted || _s._volume == 0) {
        _s._setCachedVolume(
          _s._volumeBeforeMute > 0 ? _s._volumeBeforeMute : 100.0,
        );
      } else {
        _s._volumeBeforeMute = _s._volume;
        _s._setCachedVolume(0);
      }
      _s._showVolumeSlider = true;
    });
    _scheduleHideVolumeSlider();
    _scheduleHideControls();
  }

  void _scheduleHideVolumeSlider() {
    _s._hideVolumeTimer?.cancel();
    _s._hideVolumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _s._volumeHovering) return;
      setState(() => _s._showVolumeSlider = false);
    });
  }

  String _sourceHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  /// Floating panel (not a bottom sheet) so TV gets D-pad focus + autofocus on
  /// the active source, same chrome as the Player / Stats menus.
  void _showSourcePicker({BuildContext? anchorContext}) {
    _scheduleHideControls();
    PlayerPopupPanel.show(
      context: context,
      title: 'Source',
      leadingIcon: Icons.swap_horiz_rounded,
      anchorContext: anchorContext,
      alignment: Alignment.bottomRight,
      margin: const EdgeInsets.only(right: 16, bottom: 96),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _s._sources.length; i++)
              PlayerPopupListTile(
                label: _s._sources[i].label,
                // Host only — full URLs wrap the tile to several lines.
                subtitle: _sourceHost(_s._sources[i].url),
                selected: i == _s._sourceIdx,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._switchSource(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}
