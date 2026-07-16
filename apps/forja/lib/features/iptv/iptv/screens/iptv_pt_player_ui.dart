part of 'iptv_pt_player_screen.dart';

mixin _IptvPtPlayerUi on State<IptvPtPlayerScreen> {
  _IptvPtPlayerScreenState get _s => this as _IptvPtPlayerScreenState;

  void _toggleGuide() {
    if (widget.channelGuide == null) return;
    setState(() {
      _s._guideVisible = !_s._guideVisible;
      if (_s._guideVisible) {
        _s._searchVisible = false;
        _s._controlsVisible = true;
        _s._hideControlsTimer?.cancel();
      } else {
        _scheduleHideControls();
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

  Future<void> _loadIptvEpgPref() async {
    final enabled = await SettingsService().isIptvEpgEnabled();
    SettingsService.iptvEpgEnabledNotifier.value = enabled;
  }

  void _onIptvEpgPrefChanged() {
    if (!mounted) return;
    setState(
      () => _s._iptvEpgEnabled = SettingsService.iptvEpgEnabledNotifier.value,
    );
  }

  Future<List<EpgEntry>>? _floatingEpgFuture() {
    if (!_s._iptvEpgEnabled || _s._epgCache == null) return null;
    final stream = _currentGuideChannel()?.xtreamStream;
    if (stream == null) return null;
    return _s._epgCache!.load(stream, limit: 8);
  }

  double _floatingEpgBottomInset(BuildContext context, bool compact) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barPad = compact ? 12.0 : 18.0;
    const barHeight = 56.0;
    final seekbar = _s._isVod ? (compact ? 48.0 : 56.0) : 0.0;
    return safeBottom + barPad + barHeight + seekbar + 12;
  }

  void _showStatsMenu(BuildContext anchorContext) {
    if (_s._exoBackend || _s._player == null) return;
    _scheduleHideControls();
    IptvPlayerStatsPanel.show(
      context,
      player: _s._player!,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
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
    _s._hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
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

  void _focusPlayerChrome() {
    if (!iptvUseTvFocus(context) || !_s._controlsVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_s._controlsVisible) return;
      iptvFocusRowItem('iptv-player-controls', 0);
    });
  }

  void _toggleControls() {
    final show = !_s._controlsVisible;
    setState(() => _s._controlsVisible = show);
    if (show) {
      _scheduleHideControls();
      _focusPlayerChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellScopeBuilder(builder: (context, _) => _buildPlayer(context));
  }

  Widget _buildPlayer(BuildContext context) {
    if (!_s._playerReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final compact = size.shortestSide < 600;
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
          if (Navigator.canPop(context)) Navigator.pop(context);
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
          if (!_s._isVod) return;
          var target = _s._position - const Duration(seconds: 10);
          if (target < Duration.zero) target = Duration.zero;
          unawaited(_s._engineSeek(target));
          _scheduleHideControls();
        },
        onSeekForward: () {
          if (!_s._isVod) return;
          var target = _s._position + const Duration(seconds: 10);
          if (target > _s._duration) target = _s._duration;
          unawaited(_s._engineSeek(target));
          _scheduleHideControls();
        },
        onVolumeUp: () {
          _s._engineSetVolume((_s._volume + 5).clamp(0, 100));
          setState(() => _s._volume = (_s._volume + 5).clamp(0, 100));
        },
        onVolumeDown: () {
          _s._engineSetVolume((_s._volume - 5).clamp(0, 100));
          setState(() => _s._volume = (_s._volume - 5).clamp(0, 100));
        },
        onToggleControls: _toggleControls,
        child: MouseRegion(
          onHover: (_) => _onPlayerMouseMove(),
          cursor: (_s._controlsVisible || _s._guideVisible || _s._searchVisible)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            // Double-click / double-tap video → toggle fullscreen (same as films).
            onDoubleTap: () {
              if (_s._guideVisible || _s._searchVisible) return;
              unawaited(_s._toggleFullscreen());
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video — fill the stack like the main player (Center can leave
                // a zero-sized surface on Android when Impeller composites siblings).
                Positioned.fill(
                  child: _s._exoBackend
                      ? ExoPlayerView(viewId: _s._exoViewId!)
                      : Video(
                          key: ValueKey(_s._videoEpoch),
                          controller: _s._controller!,
                          fit: BoxFit.contain,
                          fill: Colors.black,
                          controls: NoVideoControls,
                        ),
                ),
                // Reconnect/buffering banner
                if (_s._buffering || _s._statusBanner != null) _buildBanner(),
                // Top bar + bottom controls (below guide when open)
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
                if (_s._searchVisible && widget.channelGuide != null)
                  IptvChannelSearchOverlay(
                    guide: widget.channelGuide!,
                    currentChannelId: _s._currentChannelId,
                    onChannelSelected: _onSearchChannelSelected,
                    onClose: () => setState(() {
                      _s._searchVisible = false;
                      _scheduleHideControls();
                    }),
                  ),
                if (_s._guideVisible && widget.channelGuide != null)
                  IptvChannelGuidePanel(
                    guide: widget.channelGuide!,
                    selectedGroupId: _s._selectedGroupId,
                    currentChannelId: _s._currentChannelId,
                    onGroupSelected: (id) {
                      setState(() => _s._selectedGroupId = id);
                    },
                    onChannelSelected: _s._switchChannel,
                    onClose: () => setState(() => _s._guideVisible = false),
                  ),
                if (epgFuture != null)
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
            if (_s._isVod)
              _buildSeekbar(compact)
            else
              _buildLiveChannelLogo(compact),
            _buildBottomBar(compact),
          ],
        ),
      ),
    );
    if (!iptvUseTvFocus(context)) return overlay;
    return FocusScope(
      debugLabel: 'player-chrome',
      child: FocusTraversalGroup(child: overlay),
    );
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return 8;
  }

  double _topBarLeftPadding(BuildContext context) => 8;

  Widget _buildTopBar(bool compact) {
    const topRowId = 'iptv-player-top';
    final topCount = _s._sources.length > 1 ? 2 : 1;
    iptvSyncRow(rowId: topRowId, sortOrder: 0, itemCount: topCount);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _topBarLeftPadding(context),
        _topBarTopPadding(context),
        16,
        0,
      ),
      child: Row(
        children: [
          iptvBackButton(
            context,
            onTap: () => Navigator.of(context).maybePop(),
            color: Colors.white,
            size: 26,
            tvRowId: topRowId,
            tvItemIndex: 0,
            onDownEdge: () => iptvFocusRowItem('iptv-player-controls', 0),
            onRightEdge: topCount > 1
                ? () => iptvFocusRowItem(topRowId, 1)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s._title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.overlayTitle.copyWith(
                    fontSize: compact ? 18 : 22,
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
                    ),
                  ),
              ],
            ),
          ),
          if (_s._sources.length > 1) ...[
            const Spacer(),
            _SourceChip(
              label: _s._sources[_s._sourceIdx].label,
              onTap: _showSourcePicker,
              tvRowId: topRowId,
              tvItemIndex: 1,
              onDownEdge: () => iptvFocusRowItem('iptv-player-controls', 0),
              onLeftEdge: () => iptvFocusRowItem(topRowId, 0),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  VOD SEEKBAR — only shown when duration > 0 (Xtream movies / series)
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

  Widget _buildLiveChannelLogo(bool compact) {
    if ((_s._logoUrl ?? '').isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 0, 0, 8),
        child: _buildChannelLogo(compact),
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
          // Slider
          Expanded(
            child: SliderTheme(
              data: IptvShellStyle.sliderTheme(context).copyWith(
                activeTrackColor: ForjaShellColors.brandGreen,
                thumbColor: ForjaShellColors.brandGreen,
                overlayColor: ForjaShellColors.brandGreen.withValues(
                  alpha: 0.2,
                ),
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
            ),
          ),
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
    const rowId = 'iptv-player-controls';
    final expectedCount =
        3 // play, replay, mute
        +
        (_s._exoBackend ? 0 : 1) // stats
        +
        (widget.channelGuide != null ? 2 : 0) +
        (_s._sources.length > 1 ? 1 : 0) +
        1; // fullscreen
    iptvSyncRow(rowId: rowId, sortOrder: 1, itemCount: expectedCount);
    var i = 0;
    void upToTop() => iptvFocusRowItem('iptv-player-top', 0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 12 : 18,
      ),
      child: Row(
        children: [
          IptvRoundIcon(
            icon: _s._playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            big: true,
            tvRowId: rowId,
            tvItemIndex: i++,
            onUpEdge: upToTop,
            onTap: () async {
              if (_s._playing) {
                _s._userPlayWhenReady = false;
                _s._pausedAt = DateTime.now();
                await _s._enginePause();
              } else {
                _s._userPlayWhenReady = true;
                _s._pausedAt = null;
                await _s._enginePlay();
              }
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 14),
          IptvRoundIcon(
            icon: Icons.replay_rounded,
            tvRowId: rowId,
            tvItemIndex: i++,
            onTap: () async {
              _s._retryAttempt = 0;
              await _s._openCurrent();
              _scheduleHideControls();
            },
          ),
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
                  tvRowId: rowId,
                  tvItemIndex: i++,
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
                              setState(() {
                                _s._volume = v;
                                _s._muted = v == 0;
                              });
                              _s._engineSetVolume(v);
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
          if (!_s._exoBackend) ...[
            const SizedBox(width: 14),
            Builder(
              builder: (btnCtx) => IptvRoundIcon(
                icon: Icons.monitor_heart_outlined,
                tvRowId: rowId,
                tvItemIndex: i++,
                onTap: () => _showStatsMenu(btnCtx),
              ),
            ),
          ],
          const Spacer(),
          if (widget.channelGuide != null) ...[
            IptvRoundIcon(
              icon: Icons.search_rounded,
              tvRowId: rowId,
              tvItemIndex: i++,
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 14),
            IptvRoundIcon(
              icon: Icons.grid_view_rounded,
              tvRowId: rowId,
              tvItemIndex: i++,
              onTap: _toggleGuide,
            ),
            const SizedBox(width: 14),
          ],
          if (_s._sources.length > 1)
            IptvRoundIcon(
              icon: Icons.swap_horiz_rounded,
              tvRowId: rowId,
              tvItemIndex: i++,
              onTap: _showSourcePicker,
            ),
          if (_s._sources.length > 1) const SizedBox(width: 14),
          IptvRoundIcon(
            icon: _s._isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tvRowId: rowId,
            tvItemIndex: i++,
            onTap: _s._toggleFullscreen,
          ),
        ],
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      if (_s._muted || _s._volume == 0) {
        _s._muted = false;
        _s._volume = _s._volumeBeforeMute > 0 ? _s._volumeBeforeMute : 100.0;
      } else {
        _s._volumeBeforeMute = _s._volume;
        _s._muted = true;
        _s._volume = 0;
      }
      _s._showVolumeSlider = true;
    });
    _s._engineSetVolume(_s._volume);
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

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: IptvShellStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Choose source',
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 22),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _s._sources.length,
                  itemBuilder: (_, i) {
                    final s = _s._sources[i];
                    final active = i == _s._sourceIdx;
                    return ListTile(
                      leading: Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: active ? IptvShellStyle.accent : Colors.white54,
                      ),
                      title: Text(
                        s.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        s.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _s._switchSource(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
