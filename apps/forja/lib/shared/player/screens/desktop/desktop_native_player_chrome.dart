part of 'desktop_native_player_screen.dart';

mixin _DesktopNativeChrome on State<DesktopNativePlayerScreen> {
  _DesktopNativePlayerScreenState get _n =>
      this as _DesktopNativePlayerScreenState;

  bool get _hasEpisodePicker {
    final isTv = widget.movie?.mediaType == 'tv';
    return (isTv && widget.movie != null) ||
        (widget.episodes != null && widget.episodes!.isNotEmpty);
  }

  bool get _usesCatalogSourcesPanel {
    if (widget.movie == null) return false;
    final magnet = _n._activeMagnet ?? widget.magnetLink;
    if (magnet != null && magnet.isNotEmpty) return true;
    return isCatalogSourcesMode(_n._currentProvider ?? widget.activeProvider);
  }

  bool get _hasStreamPicker {
    if (_n._usesCatalogSourcesPanel) return false;
    final hasProviders =
        widget.providers != null && widget.providers!.isNotEmpty;
    final hasSources = _n._currentSources != null && _n._currentSources!.isNotEmpty;
    return hasProviders || hasSources;
  }

  String? _playingSourceTitle() {
    final sources = _n._currentSources;
    if (sources != null && sources.isNotEmpty) {
      final t = sources.first.title.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  String? _providerDisplayLabel() {
    final pid = _n._currentProvider ?? widget.activeProvider;
    if (pid != null &&
        pid.isNotEmpty &&
        widget.providers != null &&
        widget.providers!.containsKey(pid)) {
      return PlayerProviderMenu.snackbarLabel(pid, widget.providers![pid]);
    }
    return null;
  }

  ({String label, String? server}) _streamPickerLabels() {
    final offline = offlineDownloadButtonLinesForPlayUrl(
      _n._url.isNotEmpty ? _n._url : widget.mediaPath,
    );
    if (offline != null) return offline;
    final provider = _n._providerDisplayLabel();
    final sourceTitle = _n._playingSourceTitle();
    if (provider != null) {
      if (sourceTitle != null) {
        return splitSourceButtonLines(sourceTitle, providerHint: provider);
      }
      return (label: provider, server: null);
    }
    if (sourceTitle != null) return splitSourceButtonLines(sourceTitle);
    return (label: 'Sources', server: null);
  }

  ({String label, String? server}) _catalogSourcesButtonLabels() {
    final session = widget.enginePlaySession;
    final ep = widget.selectedEpisode ?? 1;
    return catalogSourcesButtonLabels(
      movie: widget.movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      catalogAddonBaseUrl: _n._catalogAddonBaseUrl,
      widgetAddonBaseUrl: widget.stremioAddonBaseUrl,
      currentProvider: _n._currentProvider,
      activeProvider: widget.activeProvider,
      activeMagnet: _n._activeMagnet,
      widgetMagnetLink: widget.magnetLink,
      currentStreamUrl: _n._url.isNotEmpty ? _n._url : widget.mediaPath,
      catalogSourceKind: _n._catalogSourceKind,
      currentSourceTitle: _n._playingSourceTitle(),
      catalogAddonName: _n._catalogAddonName,
      open: session?.effectiveOpen,
      pluginId: session?.pluginId,
      metaId: session?.meta?.id,
      malId: session?.malId,
      audioCategory: session?.audioCategory,
      episodeVideoId: session?.episodeVideoIdFor(ep),
    );
  }

  Widget _buildChrome({required bool compact}) {
    final topBarHeight = PlayerTopBar.totalHeight(context);
    final showCenter = !_n._buffering;
    final showPausedHero = widget.movie != null && (!_n._playing || _n._buffering);
    final hasTorrentSources = _n._usesCatalogSourcesPanel;
    final hasStreamPicker = _n._hasStreamPicker;
    final catalogSourceLines = hasTorrentSources
        ? _n._catalogSourcesButtonLabels()
        : null;
    final streamPickerLines = hasStreamPicker ? _n._streamPickerLabels() : null;
    final playingOffline = isOfflineDownloadPlayUrl(
      _n._url.isNotEmpty ? _n._url : widget.mediaPath,
    );
    final casting = CastingService.instance;

    return Positioned.fill(
      child: Stack(
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
              title: widget.title,
              season: widget.episodes != null ? null : widget.selectedSeason,
              episode: widget.episodes != null ? null : widget.selectedEpisode,
              onBack: () => unawaited(_n._exit()),
              trailing: PlayerTopBarActions(
                showPlayer: widget.onSwitchPlayer != null,
                onPlayer: widget.onSwitchPlayer != null
                    ? (anchor) => unawaited(_n._showPlayerMenu(anchor))
                    : null,
                showCast:
                    casting.isAirPlayAvailable || casting.isChromecastAvailable,
                onCast: _n._showCastPicker,
                showInAppMini: true,
                onInAppMini: () {
                  unawaited(InAppMiniPlayerController.instance.enter());
                  _n._bumpControls();
                },
                showPip: PipService.instance.isSupported,
                pipActive: false,
                onPip: () {
                  ForjaToast.info('Desktop PiP needs MediaKit for now');
                  _n._bumpControls();
                },
              ),
            ),
          ),
          if (showPausedHero)
            Positioned(
              left: 0,
              top: topBarHeight,
              bottom: 110,
              child: AnimatedOpacity(
                opacity: showPausedHero ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlayerPausedHero(
                    movie: widget.movie!,
                    season: widget.episodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.episodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeOverview: widget.episodeOverview,
                  ),
                ),
              ),
            ),
          if (showCenter)
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerCenterActionButton(
                      icon: Icons.replay_10_rounded,
                      onPressed: () => unawaited(
                        _n._seek(_n._position - const Duration(seconds: 10)),
                      ),
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: _n._playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 80,
                      iconSize: 44,
                      onPressed: () => unawaited(_n._playPause()),
                    ),
                    const SizedBox(width: 28),
                    PlayerCenterActionButton(
                      icon: Icons.forward_10_rounded,
                      onPressed: () => unawaited(
                        _n._seek(_n._position + const Duration(seconds: 10)),
                      ),
                    ),
                  ],
                ),
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
                  Row(
                    children: [
                      Expanded(
                        child: SeekBarWithPreview(
                          duration: _n._duration,
                          position: _n._position,
                          bufferedPosition: _n._buffered,
                          zones: buildSeekBarZones(
                            introDb: _n._introDbData,
                            duration: _n._duration,
                            hasNextEpisode: _n._hasNextEpisodeAdjacent,
                          ),
                          onSeek: (t) => unawaited(_n._seek(t)),
                          onDragStart: () => _n._hideControlsTimer?.cancel(),
                          onDragEnd: _n._scheduleHideControls,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PlayerTimeRange(position: _n._position, duration: _n._duration),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                                  PlayerFlatIconButton(
                                    icon: _n._playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    tooltip: _n._playing ? 'Pause' : 'Play',
                                    onPressed: () => unawaited(_n._playPause()),
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.replay_10_rounded,
                                    tooltip: '-10s',
                                    onPressed: () => unawaited(
                                      _n._seek(
                                        _n._position - const Duration(seconds: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.forward_10_rounded,
                                    tooltip: '+10s',
                                    onPressed: () => unawaited(
                                      _n._seek(
                                        _n._position + const Duration(seconds: 10),
                                      ),
                                    ),
                                  ),
                                  if (_n._hasPrevEpisodeAdjacent) ...[
                                    const SizedBox(width: 2),
                                    PlayerFlatIconButton(
                                      icon: Icons.skip_previous_rounded,
                                      tooltip: 'Previous episode',
                                      onPressed: () =>
                                          unawaited(_n._previousEpisode()),
                                    ),
                                  ],
                                  if (_n._hasNextEpisodeAdjacent) ...[
                                    const SizedBox(width: 2),
                                    PlayerFlatIconButton(
                                      icon: Icons.skip_next_rounded,
                                      tooltip: 'Next episode',
                                      onPressed: () =>
                                          unawaited(_n._nextEpisode()),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  PlayerVolumeControl(
                                    volume: _n._volume,
                                    maxVolume: 100,
                                    compact: compact,
                                    onVolumeChanged: (v) =>
                                        unawaited(_n._setVolume(v)),
                                    onInteraction: _n._bumpControls,
                                    onDragStart: () =>
                                        _n._hideControlsTimer?.cancel(),
                                    onDragEnd: _n._scheduleHideControls,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (hasTorrentSources) ...[
                                    PlayerSourcesPanelButton(
                                      label: catalogSourceLines!.label,
                                      server: catalogSourceLines.server,
                                      offline: playingOffline,
                                      onPressed: () =>
                                          unawaited(_n._showTorrentSourcesPanel()),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  if (hasStreamPicker) ...[
                                    PlayerStreamPickerButton(
                                      label: streamPickerLines!.label,
                                      server: streamPickerLines.server,
                                      offline: playingOffline,
                                      onPressedWithContext: (ctx) =>
                                          _n._showStreamMenu(ctx),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (_n._hasEpisodePicker) ...[
                                    PlayerFlatIconButton(
                                      icon: Icons.video_library_outlined,
                                      tooltip: 'Episodes',
                                      onPressedWithContext: (ctx) =>
                                          unawaited(_n._showEpisodesMenu(ctx)),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  PlayerFlatIconButton(
                                    icon: Icons.audiotrack_rounded,
                                    tooltip: 'Audio',
                                    onPressed: () {
                                      ForjaToast.info(
                                        'Audio tracks need MediaKit or Exo for now',
                                      );
                                      _n._bumpControls();
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.subtitles_outlined,
                                    tooltip: 'Subtitles',
                                    onPressed: () {
                                      ForjaToast.info(
                                        'Subtitles need MediaKit or Exo for now',
                                      );
                                      _n._bumpControls();
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.hd_outlined,
                                    tooltip: 'Quality',
                                    onPressed: () {
                                      ForjaToast.info(
                                        'Quality needs MediaKit or Exo for now',
                                      );
                                      _n._bumpControls();
                                    },
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: Icons.settings_outlined,
                                    tooltip: 'Settings',
                                    onPressedWithContext: _n._showSettingsMenu,
                                  ),
                                  const SizedBox(width: 2),
                                  PlayerFlatIconButton(
                                    icon: _n._isFullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    tooltip: 'Fullscreen',
                                    onPressed: () =>
                                        unawaited(_n._toggleFullscreen()),
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
      ),
    );
  }
}
