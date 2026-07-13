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

  bool get _hasResolvedWebStream =>
      widget.magnetLink == null &&
      widget.stremioId == null &&
      widget.activeProvider != null &&
      widget.activeProvider!.isNotEmpty &&
      widget.sources != null &&
      widget.sources!.isNotEmpty;

  Future<void> _loadPlayerAutoSettings() async {
    final settings = SettingsService();
    final autoServer = await settings.getPlayerAutoServer();
    final autoSource = await settings.getPlayerAutoSource();
    final autoAudio = await settings.getPlayerAutoAudio();
    final autoSubtitle = await settings.getPlayerAutoSubtitle();
    if (!mounted) return;
    final lockResolved = _hasResolvedWebStream || widget.pinSource;
    setState(() {
      _s._providerPinned = lockResolved || !autoServer;
      if (lockResolved) {
        _s._sourcePinned = true;
      } else {
        _s._sourcePinned = !autoSource;
      }
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
    final hasSources = _s._currentSources != null && _s._currentSources!.isNotEmpty;

    PlayerPopupPanel.show(
      context: context,
      title: 'Settings',
      anchorContext: anchorContext,
      child: StatefulBuilder(
        builder: (context, setPanelState) {
          return ListView(
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Auto selection',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (hasProviders)
                PlayerPopupListTile(
                  label: 'Auto server',
                  subtitle: !_s._providerPinned ? 'On' : 'Off',
                  selected: !_s._providerPinned,
                  onTap: () async {
                    final settings = SettingsService();
                    if (_s._providerPinned) {
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
              if (hasSources)
                PlayerPopupListTile(
                  label: 'Auto source',
                  subtitle: !_s._sourcePinned ? 'On' : 'Off',
                  selected: !_s._sourcePinned,
                  onTap: () async {
                    final settings = SettingsService();
                    if (_s._sourcePinned) {
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
              PlayerPopupListTile(
                label: 'Auto audio',
                subtitle: !_s._audioPinned ? 'On' : 'Off',
                selected: !_s._audioPinned,
                onTap: () async {
                  final settings = SettingsService();
                  if (_s._audioPinned) {
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
              PlayerPopupListTile(
                label: 'Auto subtitles',
                subtitle: !_s._subtitlePinned ? 'On' : 'Off',
                selected: !_s._subtitlePinned,
                onTap: () async {
                  final settings = SettingsService();
                  if (_s._subtitlePinned) {
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
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video decode',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _GlassPillButton(
                          text: _s._hwDecMode.label,
                          accent: _s._hwDecMode.accent,
                          onTap: () {
                            _s._cycleHwDec();
                            setPanelState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _s._hwDecMode.description,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              const SizedBox(height: 4),
              PlayerPopupListTile(
                label: 'Playback speed',
                subtitle: '${_s._player.state.rate}x',
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  showSpeedMenu(
                    context,
                    _s._player.state.rate,
                    (s) => _s._player.setRate(s),
                  );
                },
              ),
              PlayerPopupListTile(
                label: 'Aspect ratio',
                subtitle: _s._videoFitLabel,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._cycleAspectRatio();
                },
              ),
              PlayerPopupListTile(
                label: 'Loop',
                subtitle: _s._loopEnabled ? 'On' : 'Off',
                selected: _s._loopEnabled,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._toggleLoop();
                },
              ),
              PlayerPopupListTile(
                label: 'Subtitle style',
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _s._showSubtitleSettings();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
