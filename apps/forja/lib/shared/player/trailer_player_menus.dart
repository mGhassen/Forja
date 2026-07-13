part of 'trailer_player_screen.dart';

mixin _TrailerPlayerMenus on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  Future<void> _showSubtitleMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
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
              padding: EdgeInsets.all(12),
              child: Text(
                'No subtitles available for this trailer.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...tracks.map((track) {
              final code = track['languageCode'] as String;
              final name = track['languageName'] as String? ?? languageDisplayName(code);
              return PlayerPopupListTile(
                label: name,
                badge: code.toUpperCase(),
                selected: activeCode == code,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _s._runJs("window.trailerSetCaptionTrack('$code');");
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
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
              label: _defaultAudioLabel(),
              badge: _defaultAudioBadge(),
              selected: true,
            )
          else
            ...tracks.map((track) {
              final id = track['id'] as String;
              final label = track['label'] as String;
              final selected = track['isActive'] as bool;
              return PlayerPopupListTile(
                label: label,
                selected: selected,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _s._runJs("window.trailerSetAudioTrack('$id');");
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showQualityMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
    final currentRaw = await _s._runJsJson('window.trailerGetPlaybackQuality()');
    final levelsRaw = await _s._runJsJson('window.trailerGetAvailableQualityLevels()');
    final current = currentRaw is String ? currentRaw : 'auto';
    final levels = _parseQualityLevels(levelsRaw);

    if (!mounted) return;
    await PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      anchorContext: anchorContext,
      maxHeight: 360,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: [
          if (levels.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No quality options for this trailer.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ...levels.map((level) {
              return PlayerPopupListTile(
                label: _qualityLabel(level),
                badge: level == 'auto' ? 'AUTO' : null,
                selected: level == current,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await _s._runJs("window.trailerSetPlaybackQuality('$level');");
                },
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showSpeedMenu(BuildContext anchorContext) async {
    if (!_s._ready) return;
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
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        children: rates.map((rate) {
          final selected = (rate - currentRate).abs() < 0.01;
          return PlayerPopupListTile(
            label: '${_formatRate(rate)}x',
            selected: selected,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await _s._runJs('window.trailerSetPlaybackRate($rate);');
            },
          );
        }).toList(),
      ),
    );
  }

  String _defaultAudioLabel() {
    final lang = widget.languageCode?.trim();
    if (lang != null && lang.isNotEmpty) {
      return languageDisplayName(lang);
    }
    return 'Original';
  }

  String? _defaultAudioBadge() {
    final lang = widget.languageCode?.trim();
    if (lang != null && lang.isNotEmpty) return lang.toUpperCase();
    return null;
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
        .map((item) => {
              'id': item['id']?.toString() ?? '',
              'label': item['label']?.toString() ?? 'Unknown',
              'isActive': item['isActive'] == true,
            })
        .where((t) => (t['id'] as String).isNotEmpty)
        .toList();
  }

  @override
}

