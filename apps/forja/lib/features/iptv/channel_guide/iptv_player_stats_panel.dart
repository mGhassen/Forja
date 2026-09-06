import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';

import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

class IptvPlayerStatsSnapshot {
  const IptvPlayerStatsSnapshot({
    required this.playing,
    required this.buffering,
    required this.sourceLabel,
    required this.retryAttempt,
    required this.volume,
    this.buffered,
    this.position,
  });

  final bool playing;
  final bool buffering;
  final String sourceLabel;
  final int retryAttempt;
  final double volume;

  /// Absolute buffer-end from media_kit (not "seconds ahead").
  final Duration? buffered;
  final Duration? position;
}

class IptvPlayerStatsPanel {
  static void show(
    BuildContext context, {
    required IptvPlayerStatsSnapshot Function() snapshot,
    Player? player,
    int? exoViewId,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.topRight,
    EdgeInsets margin = const EdgeInsets.only(top: 72, right: 16),
  }) {
    assert(
      player != null || exoViewId != null,
      'IptvPlayerStatsPanel needs MediaKit player or Exo viewId',
    );
    PlayerPopupPanel.show(
      context: context,
      title: 'Stream stats',
      leadingIcon: Icons.monitor_heart_outlined,
      width: 320,
      maxHeight: 440,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      // Read-only rows — land TV focus on Close so Select dismisses.
      autofocusClose: true,
      child: ExcludeFocus(
        child: player != null
            ? _IptvMediaKitStatsBody(
                player: player,
                snapshot: snapshot,
              )
            : _IptvExoStatsBody(
                viewId: exoViewId!,
                snapshot: snapshot,
              ),
      ),
    );
  }
}

class _IptvMediaKitStatsBody extends StatefulWidget {
  const _IptvMediaKitStatsBody({
    required this.player,
    required this.snapshot,
  });

  final Player player;
  final IptvPlayerStatsSnapshot Function() snapshot;

  @override
  State<_IptvMediaKitStatsBody> createState() => _IptvMediaKitStatsBodyState();
}

class _IptvMediaKitStatsBodyState extends State<_IptvMediaKitStatsBody> {
  /// Matches IPTV player Stable gate — above this is PTS garbage, not cache.
  static const double _maxSaneCacheAheadSecs = 90.0;

  Timer? _timer;
  StreamSubscription<Duration>? _bufferSub;
  Map<String, String> _mpv = const {};
  Duration? _buffered;

  @override
  void initState() {
    super.initState();
    _buffered = widget.snapshot().buffered;
    _bufferSub = widget.player.stream.buffer.listen((b) {
      if (!mounted) return;
      setState(() => _buffered = b);
    });
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_bufferSub?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    final p = widget.player.platform;
    if (p is! NativePlayer) return;

    Future<String> prop(String name) async {
      try {
        final v = await p.getProperty(name);
        final s = v.toString().trim();
        if (s.isEmpty || s == 'none' || s == 'null' || s == 'N/A') return '-';
        return s;
      } catch (_) {
        return '-';
      }
    }

    final next = <String, String>{
      'videoCodec': await prop('video-codec'),
      'audioCodec': await prop('audio-codec'),
      'width': await prop('width'),
      'height': await prop('height'),
      'fps': await prop('container-fps'),
      'displayFps': await prop('estimated-vf-fps'),
      'videoBitrate': await prop('video-bitrate'),
      'audioBitrate': await prop('audio-bitrate'),
      'cacheDuration': await prop('demuxer-cache-duration'),
      'cacheBytes': await prop('cache-used'),
      'drops': await prop('frame-drop-count'),
      'decoderDrops': await prop('decoder-frame-drop-count'),
      'speed': await prop('speed'),
    };

    if (!mounted) return;
    setState(() => _mpv = next);
  }

  static String _fmtBitrate(String raw) {
    if (raw == '-') return raw;
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return raw;
    if (n < 1000) return '${n.round()} bps';
    if (n < 1e6) return '${(n / 1000).toStringAsFixed(0)} kbps';
    return '${(n / 1e6).toStringAsFixed(2)} Mbps';
  }

  static String _fmtBytes(String raw) {
    if (raw == '-') return raw;
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return raw;
    if (n < 1024) return '${n.round()} B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// demuxer-cache-duration in seconds — hide PTS discontinuity spikes.
  static String _fmtCacheAhead(String raw) {
    if (raw == '-') return raw;
    final n = double.tryParse(raw);
    if (n == null || n < 0) return raw;
    if (n > _maxSaneCacheAheadSecs) return 'n/a (invalid PTS)';
    if (n < 60) return '${n.toStringAsFixed(1)} s';
    return '${(n / 60).toStringAsFixed(1)} min';
  }

  /// True seconds ahead of playhead when buffer-end and position are sane.
  String? _fmtBufferedAhead(Duration? position) {
    final end = _buffered;
    if (end == null || position == null) return null;
    final aheadSecs = end.inMilliseconds - position.inMilliseconds;
    if (aheadSecs <= 0) return null;
    final secs = aheadSecs / 1000.0;
    if (secs > _maxSaneCacheAheadSecs) return null; // absolute TS, not ahead
    if (secs < 60) return '${secs.toStringAsFixed(1)} s';
    return '${(secs / 60).toStringAsFixed(1)} min';
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot();
    final state = widget.player.state;
    final video = state.track.video;
    final audio = state.track.audio;
    final subtitle = state.track.subtitle;
    final position = snap.position ?? state.position;
    final bufferedAhead = _fmtBufferedAhead(position);

    final w = _mpv['width'] ?? '-';
    final h = _mpv['height'] ?? '-';
    final resolution = (w != '-' && h != '-') ? '$w×$h' : '-';

    final rows = <_StatRow>[
      _StatRow(
        'Status',
        snap.buffering
            ? 'Buffering'
            : snap.playing
                ? 'Playing'
                : 'Paused',
      ),
      _StatRow('Engine', 'MediaKit'),
      _StatRow('Source', snap.sourceLabel),
      if (snap.retryAttempt > 0) _StatRow('Recoveries', '${snap.retryAttempt}'),
      _StatRow('Resolution', resolution),
      _StatRow('Video', _mpv['videoCodec'] ?? '-'),
      _StatRow('Video bitrate', _fmtBitrate(_mpv['videoBitrate'] ?? '-')),
      _StatRow('FPS', _mpv['fps'] ?? '-'),
      _StatRow('Display FPS', _mpv['displayFps'] ?? '-'),
      _StatRow('Audio', _mpv['audioCodec'] ?? '-'),
      _StatRow(
        'Audio track',
        audio.id == 'no' ? '-' : (audio.title ?? audio.language ?? audio.id),
      ),
      _StatRow('Audio bitrate', _fmtBitrate(_mpv['audioBitrate'] ?? '-')),
      _StatRow(
        'Subtitle',
        subtitle.id == 'no'
            ? 'Off'
            : (subtitle.title ?? subtitle.language ?? subtitle.id),
      ),
      _StatRow('Cache', _fmtCacheAhead(_mpv['cacheDuration'] ?? '-')),
      _StatRow('Cache used', _fmtBytes(_mpv['cacheBytes'] ?? '-')),
      if (bufferedAhead != null) _StatRow('Buffered ahead', bufferedAhead),
      _StatRow('Volume', '${snap.volume.round()}%'),
      _StatRow('Speed', _mpv['speed'] ?? '-'),
      if ((_mpv['drops'] ?? '-') != '-' && _mpv['drops'] != '0')
        _StatRow('Dropped frames', _mpv['drops']!),
      if ((_mpv['decoderDrops'] ?? '-') != '-' &&
          _mpv['decoderDrops'] != '0')
        _StatRow('Decoder drops', _mpv['decoderDrops']!),
      if (video.id != 'auto' && video.id != 'no')
        _StatRow('Video track', video.id),
    ];

    return _StatsList(rows: rows);
  }
}

class _IptvExoStatsBody extends StatefulWidget {
  const _IptvExoStatsBody({
    required this.viewId,
    required this.snapshot,
  });

  final int viewId;
  final IptvPlayerStatsSnapshot Function() snapshot;

  @override
  State<_IptvExoStatsBody> createState() => _IptvExoStatsBodyState();
}

class _IptvExoStatsBodyState extends State<_IptvExoStatsBody> {
  static const double _maxSaneCacheAheadSecs = 90.0;

  Timer? _timer;
  ExoTracksSnapshot _tracks = ExoTracksSnapshot.empty;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final next = await ExoPlayerBridge.getTracks(widget.viewId);
      if (!mounted) return;
      setState(() => _tracks = next);
    } catch (_) {}
  }

  static String _fmtBitrate(int bps) {
    if (bps <= 0) return '-';
    if (bps < 1000) return '$bps bps';
    if (bps < 1000000) return '${(bps / 1000).toStringAsFixed(0)} kbps';
    return '${(bps / 1e6).toStringAsFixed(2)} Mbps';
  }

  String? _fmtBufferedAhead(IptvPlayerStatsSnapshot snap) {
    final end = snap.buffered;
    final position = snap.position;
    if (end == null || position == null) return null;
    final aheadSecs = end.inMilliseconds - position.inMilliseconds;
    if (aheadSecs <= 0) return null;
    final secs = aheadSecs / 1000.0;
    if (secs > _maxSaneCacheAheadSecs) return null;
    if (secs < 60) return '${secs.toStringAsFixed(1)} s';
    return '${(secs / 60).toStringAsFixed(1)} min';
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot();
    ExoTrackInfo? selected(List<ExoTrackInfo> list) {
      for (final t in list) {
        if (t.selected) return t;
      }
      return null;
    }

    final video = selected(_tracks.video);
    final audio = selected(_tracks.audio);
    final text = selected(_tracks.text);
    final bufferedAhead = _fmtBufferedAhead(snap);

    final resolution = video != null && video.height > 0
        ? '${video.height}p'
        : '-';

    final rows = <_StatRow>[
      _StatRow(
        'Status',
        snap.buffering
            ? 'Buffering'
            : snap.playing
                ? 'Playing'
                : 'Paused',
      ),
      _StatRow('Engine', 'ExoPlayer'),
      _StatRow('Source', snap.sourceLabel),
      if (snap.retryAttempt > 0) _StatRow('Recoveries', '${snap.retryAttempt}'),
      _StatRow('Resolution', resolution),
      _StatRow(
        'Video',
        _tracks.videoAuto
            ? 'Auto${video != null ? ' (${video.label})' : ''}'
            : (video?.label ?? '-'),
      ),
      _StatRow('Video bitrate', _fmtBitrate(video?.bitrate ?? 0)),
      _StatRow(
        'Audio',
        audio == null
            ? '-'
            : (audio.language.isNotEmpty
                ? '${audio.label} (${audio.language})'
                : audio.label),
      ),
      _StatRow('Audio bitrate', _fmtBitrate(audio?.bitrate ?? 0)),
      _StatRow(
        'Subtitle',
        _tracks.textOff
            ? 'Off'
            : (text?.label ?? '-'),
      ),
      if (bufferedAhead != null) _StatRow('Buffered ahead', bufferedAhead),
      _StatRow('Volume', '${snap.volume.round()}%'),
      _StatRow('Speed', '${_tracks.rate.toStringAsFixed(2)}x'),
    ];

    return _StatsList(rows: rows);
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({required this.rows});

  final List<_StatRow> rows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      shrinkWrap: true,
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      r.label,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.value,
                      style: GoogleFonts.spaceMono(
                        color: Colors.white,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatRow {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;
}
