part of 'mobile_player_screen.dart';

mixin _MobilePlayerSourcesSettings on State<MobilePlayerScreen> {
  _MobilePlayerScreenState get _s => this as _MobilePlayerScreenState;

  Future<void> _applyAutoSubtitle() async {
    if (_s._disposed || _s._subtitlePinned) return;
    final embedded = _s._player.state.tracks.subtitle
        .where(
          (t) => t.id != 'no' && t.id != 'auto' && !t.id.startsWith('http'),
        )
        .toList();
    if (embedded.isEmpty) return;
    final track = embedded.first;
    await _s._player.setSubtitleTrack(track);
    _s._updateSubVisibility(track);
    if (mounted) setState(() => _s._selectedExternalSubUrl = null);
  }

  Future<void> _loadPlayerAutoSettings() async {
    final settings = SettingsService();
    final autoServer = await settings.getPlayerAutoServer();
    final autoSource = await settings.getPlayerAutoSource();
    final autoAudio = await settings.getPlayerAutoAudio();
    final autoSubtitle = await settings.getPlayerAutoSubtitle();
    // Hydrate live notifiers used by skip/next episode and the Episodes panel.
    await settings.getAutoNextEpisode();
    await settings.getAutoSkipIntro();
    if (!mounted) return;
    // Respect Auto toggles only. Do not lock because an extract already exists
    // (green Play / cache) — that made dead CDNs hit "no auto failover".
    setState(() {
      _s._providerPinned = !autoServer;
      _s._sourcePinned = !autoSource;
      _s._audioPinned = !autoAudio;
      _s._subtitlePinned = !autoSubtitle;
    });
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    final hasProviders =
        widget.providers != null &&
        widget.providers!.isNotEmpty &&
        widget.movie != null &&
        widget.magnetLink == null &&
        widget.activeProvider != 'stremio_direct';
    final hasSources =
        _s._currentSources != null && _s._currentSources!.isNotEmpty;

    PlayerPopupPanel.show(
      context: context,
      title: 'Settings',
      leadingIcon: Icons.tune_rounded,
      anchorContext: anchorContext,
      width: 320,
      maxHeight: 460,
      child: StatefulBuilder(
        builder: (context, setPanelState) {
          final speed = _s._player.state.rate;
          final autoSkip = SettingsService.autoSkipIntroNotifier.value;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            shrinkWrap: true,
            children: [
              PlayerPopupSectionCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Auto selection',
                subtitle: 'Pick tracks and servers for you',
                child: Column(
                  children: [
                    if (hasProviders) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto server',
                        value: !_s._providerPinned,
                        onChanged: (on) async {
                          final settings = SettingsService();
                          if (on) {
                            await settings.setPlayerAutoServer(true);
                            setState(() => _s._providerPinned = false);
                            setPanelState(() {});
                            await _s._selectAutoProvider();
                          } else {
                            await settings.setPlayerAutoServer(false);
                            setState(() => _s._providerPinned = true);
                            setPanelState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (hasSources) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto source',
                        value: !_s._sourcePinned,
                        onChanged: (on) async {
                          final settings = SettingsService();
                          if (on) {
                            await settings.setPlayerAutoSource(true);
                            setState(() => _s._sourcePinned = false);
                            setPanelState(() {});
                            await _s._selectAutoSource();
                          } else {
                            await settings.setPlayerAutoSource(false);
                            setState(() => _s._sourcePinned = true);
                            setPanelState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    PlayerPopupToggleRow(
                      label: 'Auto audio',
                      value: !_s._audioPinned,
                      onChanged: (on) async {
                        final settings = SettingsService();
                        if (on) {
                          await settings.setPlayerAutoAudio(true);
                          setState(() => _s._audioPinned = false);
                          setPanelState(() {});
                          _s._autoTracksAppliedForSource = false;
                          await _s._applyTrackAutoSelect();
                        } else {
                          await settings.setPlayerAutoAudio(false);
                          setState(() => _s._audioPinned = true);
                          setPanelState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    PlayerPopupToggleRow(
                      label: 'Auto subtitles',
                      value: !_s._subtitlePinned,
                      onChanged: (on) async {
                        final settings = SettingsService();
                        if (on) {
                          await settings.setPlayerAutoSubtitle(true);
                          setState(() => _s._subtitlePinned = false);
                          setPanelState(() {});
                          await _applyAutoSubtitle();
                        } else {
                          await settings.setPlayerAutoSubtitle(false);
                          setState(() => _s._subtitlePinned = true);
                          setPanelState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    PlayerPopupToggleRow(
                      label: 'Auto skip intro',
                      value: autoSkip,
                      onChanged: (on) async {
                        await SettingsService().setAutoSkipIntro(on);
                        setPanelState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PlayerPopupSectionCard(
                icon: Icons.memory_rounded,
                title: 'Video decode',
                subtitle: _s._hwDecMode.description,
                valueBadge: _s._hwDecMode.label,
                child: Row(
                  children: [
                    for (final mode in _HwDecMode.values) ...[
                      if (mode != _HwDecMode.values.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: PlayerPopupOptionChip(
                          label: mode.label,
                          selected: _s._hwDecMode == mode,
                          expanded: true,
                          onTap: () {
                            if (_s._hwDecMode == mode) return;
                            setState(() => _s._hwDecMode = mode);
                            if (_s._player.platform is NativePlayer) {
                              (_s._player.platform as NativePlayer)
                                  .setProperty('hwdec', mode.mpvValue);
                            }
                            setPanelState(() {});
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PlayerPopupSectionCard(
                icon: Icons.speed_rounded,
                title: 'Playback speed',
                subtitle: 'How fast playback runs',
                valueBadge: speed == 1.0 ? 'Normal' : '${speed}x',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in const [
                      0.25,
                      0.5,
                      0.75,
                      1.0,
                      1.25,
                      1.5,
                      1.75,
                      2.0,
                    ])
                      PlayerPopupOptionChip(
                        label: s == 1.0 ? 'Normal' : '${s}x',
                        selected: s == speed,
                        onTap: () {
                          _s._player.setRate(s);
                          setPanelState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PlayerPopupSectionCard(
                icon: Icons.aspect_ratio_rounded,
                title: 'Aspect ratio',
                subtitle: 'Fit video in the frame',
                valueBadge: _s._videoFitLabel,
                child: Row(
                  children: [
                    for (final entry in const [
                      (BoxFit.contain, 'FIT'),
                      (BoxFit.cover, 'CROP'),
                      (BoxFit.fill, 'FILL'),
                    ]) ...[
                      if (entry.$1 != BoxFit.contain) const SizedBox(width: 8),
                      Expanded(
                        child: PlayerPopupOptionChip(
                          label: entry.$2,
                          selected: _s._videoFit == entry.$1,
                          expanded: true,
                          onTap: () {
                            setState(() => _s._videoFit = entry.$1);
                            setPanelState(() {});
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PlayerPopupSectionCard(
                icon: Icons.loop_rounded,
                title: 'Loop',
                subtitle: 'Repeat the current title',
                valueBadge: _s._loopEnabled ? 'On' : 'Off',
                child: playerPopupOnOffChips(
                  value: _s._loopEnabled,
                  onChanged: (on) {
                    if (on == _s._loopEnabled) return;
                    _s._toggleLoop();
                    setPanelState(() {});
                  },
                ),
              ),
              const SizedBox(height: 10),
              PlayerPopupSectionCard(
                icon: Icons.subtitles_outlined,
                title: 'Subtitle style',
                subtitle: 'Font, size, and color',
                child: PlayerPopupOptionChip(
                  label: 'Customize',
                  selected: false,
                  expanded: true,
                  onTap: () {
                    PlayerPopupPanel.dismiss();
                    _s._showSubtitleSettings();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
