part of 'trailer_player_screen.dart';

mixin _TrailerPlayerMenus on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  Future<void> _showSubtitleMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
    _s._hideTimer?.cancel();
    if (!_s._showControls) setState(() => _s._showControls = true);
    final tracksRaw = await _s._runJsJson('window.trailerGetCaptionTracks()');
    final active = await _s._runJsJson('window.trailerGetActiveCaption()');
    final tracks = _parseCaptionTracks(tracksRaw);
    final activeCode = active is String ? active : null;

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          PlayerPopupListTile(
            label: 'Off',
            selected: activeCode == null,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await _s._runJs('window.trailerSetCaptionTrack(null);');
            },
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'No subtitles available for this trailer.',
                style: TextStyle(color: PlayerPopupTokens.muted, fontSize: 13),
              ),
            )
          else
            for (final track in tracks)
              PlayerPopupListTile(
                label: _flaggedLabel(
                  track['languageCode'] as String,
                  track['languageName'] as String,
                ),
                selected: activeCode == track['languageCode'],
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  final code = track['languageCode'] as String;
                  await _s._runJs("window.trailerSetCaptionTrack('$code');");
                },
              ),
        ],
      ),
    );
    if (mounted) _s._startHideTimer();
  }

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
    _s._hideTimer?.cancel();
    if (!_s._showControls) setState(() => _s._showControls = true);
    final tracksRaw = await _s._runJsJson('window.trailerGetAudioTracks()');
    final tracks = _parseAudioTracks(tracksRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          if (tracks.isEmpty)
            PlayerPopupListTile(
              label: _flaggedLabel(widget.languageCode, _defaultAudioLabel()),
              selected: true,
            )
          else
            for (final track in tracks)
              PlayerPopupListTile(
                label: track['label'] as String,
                selected: track['isActive'] as bool,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  final id = track['id'] as String;
                  await _s._runJs("window.trailerSetAudioTrack('$id');");
                },
              ),
        ],
      ),
    );
    if (mounted) _s._startHideTimer();
  }

  Future<void> _showQualityMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
    _s._hideTimer?.cancel();
    if (!_s._showControls) setState(() => _s._showControls = true);
    final currentRaw = await _s._runJsJson('window.trailerGetPlaybackQuality()');
    final levelsRaw = await _s._runJsJson('window.trailerGetAvailableQualityLevels()');
    final playingQuality = currentRaw is String ? currentRaw : 'unknown';
    final levels = _parseQualityLevels(levelsRaw);
    final qualityAuto = _s._selectedQuality == 'auto';

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: levels.isEmpty
            ? const Text(
                'No quality options for this trailer.',
                style: TextStyle(color: PlayerPopupTokens.muted, fontSize: 13),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                // While Auto is active, hide Auto and highlight the level
                // currently playing (main-player quality menu parity).
                children: levels
                    .where((level) => level != 'auto' || !qualityAuto)
                    .map((level) {
                  final selected = level == 'auto'
                      ? false
                      : (qualityAuto
                          ? level == playingQuality
                          : level == _s._selectedQuality);
                  return PlayerPopupOptionChip(
                    label: _qualityLabel(level),
                    selected: selected,
                    onTap: () async {
                      PlayerPopupPanel.dismiss();
                      setState(() => _s._selectedQuality = level);
                      await _s._runJs(
                        "window.trailerSetPlaybackQuality('$level');",
                      );
                    },
                  );
                }).toList(),
              ),
      ),
    );
    if (mounted) _s._startHideTimer();
  }

  Future<void> _showSpeedMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
    _s._hideTimer?.cancel();
    if (!_s._showControls) setState(() => _s._showControls = true);
    final rateRaw = await _s._runJsJson('window.trailerGetPlaybackRate()');
    final ratesRaw = await _s._runJsJson('window.trailerGetAvailablePlaybackRates()');
    final currentRate = rateRaw is num ? rateRaw.toDouble() : 1.0;
    final rates = _parsePlaybackRates(ratesRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Playback speed',
      leadingIcon: Icons.speed_rounded,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rates.map((rate) {
            final selected = (rate - currentRate).abs() < 0.01;
            return PlayerPopupOptionChip(
              label: '${_formatRate(rate)}x',
              selected: selected,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                await _s._runJs('window.trailerSetPlaybackRate($rate);');
              },
            );
          }).toList(),
        ),
      ),
    );
    if (mounted) _s._startHideTimer();
  }

  String _defaultAudioLabel() {
    final lang = widget.languageCode?.trim();
    if (lang != null && lang.isNotEmpty) {
      return languageDisplayName(lang);
    }
    return 'Original';
  }

  String _flaggedLabel(String? code, String name) {
    final flag = _flagForLang(code);
    if (flag.isEmpty) return name;
    return '$flag  $name';
  }

  String _flagForLang(String? code) {
    if (code == null || code.trim().isEmpty) return '';
    final raw = code.trim().toLowerCase();
    final direct = StreamProviderDisplay.flagForCountry(raw);
    if (direct.isNotEmpty) return direct;
    final base = raw.split(RegExp(r'[-_]')).first;
    final fromBase = StreamProviderDisplay.flagForCountry(base);
    if (fromBase.isNotEmpty) return fromBase;
    return StreamProviderDisplay.flagsForText(raw);
  }

  List<Map<String, dynamic>> _parseCaptionTracks(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final code = item['languageCode']?.toString();
      if (code == null || code.isEmpty || seen.contains(code)) continue;
      seen.add(code);
      out.add({
        'languageCode': code,
        'languageName': item['languageName']?.toString() ?? languageDisplayName(code),
      });
    }
    out.sort((a, b) => compareLanguageCodes(
          a['languageCode'] as String,
          b['languageCode'] as String,
        ));
    return out;
  }

  List<double> _parsePlaybackRates(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const [1.0];
    final rates = raw
        .whereType<num>()
        .map((r) => r.toDouble())
        .where((r) => r > 0)
        .toSet()
        .toList()
      ..sort();
    return rates.isEmpty ? const [1.0] : rates;
  }

  List<String> _parseQualityLevels(dynamic raw) {
    if (raw is! List) return const [];
    const order = [
      'highres',
      'hd1080',
      'hd720',
      'large',
      'medium',
      'small',
      'tiny',
      'auto',
    ];
    final levels = raw
        .map((e) => e?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    levels.sort((a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return levels;
  }

  String _formatRate(double rate) {
    if (rate == rate.roundToDouble()) return rate.toStringAsFixed(0);
    return rate.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _qualityLabel(String code) {
    switch (code) {
      case 'highres':
        return '4K';
      case 'hd1080':
        return '1080p';
      case 'hd720':
        return '720p';
      case 'large':
        return '480p';
      case 'medium':
        return '360p';
      case 'small':
        return '240p';
      case 'tiny':
        return '144p';
      case 'auto':
        return 'Auto';
      default:
        return code;
    }
  }

  List<Map<String, dynamic>> _parseAudioTracks(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = item['id']?.toString() ?? '';
          final rawLabel = item['label']?.toString() ?? '';
          final name = languageDisplayName(
            rawLabel.isNotEmpty ? rawLabel : id,
          );
          return {
            'id': id,
            'label': _flaggedLabel(rawLabel.isNotEmpty ? rawLabel : id, name),
            'isActive': item['isActive'] == true,
          };
        })
        .where((t) => (t['id'] as String).isNotEmpty)
        .toList();
  }
}
