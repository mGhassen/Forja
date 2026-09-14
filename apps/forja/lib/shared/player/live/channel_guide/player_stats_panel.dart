import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja_foundation/widgets/guide/player_stats_panel.dart';

typedef IptvPlayerStatsSnapshot = PlayerStatsSnapshot;

class PlayerStatsPanel {
  static void show(
    BuildContext context, {
    required PlayerStatsSnapshot Function() snapshot,
    Player? player,
    int? exoViewId,
    /// When set (AVPlayer / VLC), show session snapshot without native probes.
    String? nativeEngineLabel,
    BuildContext? anchorContext,
    Alignment alignment = Alignment.topRight,
    EdgeInsets margin = const EdgeInsets.only(top: 72, right: 16),
  }) {
    assert(
      player != null || exoViewId != null || nativeEngineLabel != null,
      'PlayerStatsPanel needs MediaKit, Exo, or nativeEngineLabel',
    );
    final Widget body;
    if (player != null) {
      body = _IptvMediaKitStatsBody(player: player, snapshot: snapshot);
    } else if (exoViewId != null) {
      body = _IptvExoStatsBody(viewId: exoViewId, snapshot: snapshot);
    } else {
      body = _IptvNativeSnapshotStatsBody(
        engineLabel: nativeEngineLabel!,
        snapshot: snapshot,
      );
    }
    PlayerPopupPanel.show(
      context: context,
      title: 'Stream stats',
      leadingIcon: Icons.monitor_heart_outlined,
      width: 320,
      maxHeight: 440,
      alignment: alignment,
      margin: margin,
      anchorContext: anchorContext,
      // Close first (Select dismisses); ↓ moves into the scrollable rows.
      autofocusClose: true,
      child: body,
    );
  }
}

class _IptvMediaKitStatsBody extends StatefulWidget {
  const _IptvMediaKitStatsBody({
    required this.player,
    required this.snapshot,
  });

  final Player player;
  final PlayerStatsSnapshot Function() snapshot;

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

    final rows = <PlayerStatsRow>[
      PlayerStatsRow(
        'Status',
        snap.buffering
            ? 'Buffering'
            : snap.playing
                ? 'Playing'
                : 'Paused',
      ),
      PlayerStatsRow('Engine', 'MediaKit'),
      PlayerStatsRow('Source', snap.sourceLabel),
      if (snap.retryAttempt > 0) PlayerStatsRow('Recoveries', '${snap.retryAttempt}'),
      PlayerStatsRow('Resolution', resolution),
      PlayerStatsRow('Video', _mpv['videoCodec'] ?? '-'),
      PlayerStatsRow('Video bitrate', _fmtBitrate(_mpv['videoBitrate'] ?? '-')),
      PlayerStatsRow('FPS', _mpv['fps'] ?? '-'),
      PlayerStatsRow('Display FPS', _mpv['displayFps'] ?? '-'),
      PlayerStatsRow('Audio', _mpv['audioCodec'] ?? '-'),
      PlayerStatsRow(
        'Audio track',
        audio.id == 'no' ? '-' : (audio.title ?? audio.language ?? audio.id),
      ),
      PlayerStatsRow('Audio bitrate', _fmtBitrate(_mpv['audioBitrate'] ?? '-')),
      PlayerStatsRow(
        'Subtitle',
        subtitle.id == 'no'
            ? 'Off'
            : (subtitle.title ?? subtitle.language ?? subtitle.id),
      ),
      PlayerStatsRow('Cache', _fmtCacheAhead(_mpv['cacheDuration'] ?? '-')),
      PlayerStatsRow('Cache used', _fmtBytes(_mpv['cacheBytes'] ?? '-')),
      if (bufferedAhead != null) PlayerStatsRow('Buffered ahead', bufferedAhead),
      PlayerStatsRow('Volume', '${snap.volume.round()}%'),
      PlayerStatsRow('Speed', _mpv['speed'] ?? '-'),
      if ((_mpv['drops'] ?? '-') != '-' && _mpv['drops'] != '0')
        PlayerStatsRow('Dropped frames', _mpv['drops']!),
      if ((_mpv['decoderDrops'] ?? '-') != '-' &&
          _mpv['decoderDrops'] != '0')
        PlayerStatsRow('Decoder drops', _mpv['decoderDrops']!),
      if (video.id != 'auto' && video.id != 'no')
        PlayerStatsRow('Video track', video.id),
    ];

    return PlayerStatsList(rows: rows);
  }
}

class _IptvExoStatsBody extends StatefulWidget {
  const _IptvExoStatsBody({
    required this.viewId,
    required this.snapshot,
  });

  final int viewId;
  final PlayerStatsSnapshot Function() snapshot;

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

  String? _fmtBufferedAhead(PlayerStatsSnapshot snap) {
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
    final pb = _tracks.playback;
    final bufferedAhead = _fmtBufferedAhead(snap) ??
        _fmtBufferedMs(pb.bufferedMs);

    final resolution = () {
      if (pb.width > 0 && pb.height > 0) return '${pb.width}×${pb.height}';
      if (pb.height > 0) return '${pb.height}p';
      if (video != null && video.height > 0) return '${video.height}p';
      return '-';
    }();

    final videoBitrate =
        pb.videoBitrate > 0 ? pb.videoBitrate : (video?.bitrate ?? 0);
    final audioBitrate =
        pb.audioBitrate > 0 ? pb.audioBitrate : (audio?.bitrate ?? 0);

    final videoLabel = () {
      final codec = pb.videoCodec;
      if (_tracks.videoAuto) {
        final rung = video?.label;
        if (codec.isNotEmpty && rung != null && rung.isNotEmpty) {
          return 'Auto · $codec ($rung)';
        }
        if (codec.isNotEmpty) return 'Auto · $codec';
        return 'Auto${rung != null ? ' ($rung)' : ''}';
      }
      if (codec.isNotEmpty) return codec;
      return video?.label ?? '-';
    }();

    final rows = <PlayerStatsRow>[
      PlayerStatsRow(
        'Status',
        snap.buffering
            ? 'Buffering'
            : snap.playing
                ? 'Playing'
                : 'Paused',
      ),
      PlayerStatsRow('Engine', 'ExoPlayer'),
      PlayerStatsRow('Source', snap.sourceLabel),
      if (snap.retryAttempt > 0) PlayerStatsRow('Recoveries', '${snap.retryAttempt}'),
      PlayerStatsRow('Resolution', resolution),
      PlayerStatsRow('Video', videoLabel),
      PlayerStatsRow('Video bitrate', _fmtBitrate(videoBitrate)),
      if (pb.fps > 0) PlayerStatsRow('FPS', pb.fps.toStringAsFixed(2)),
      PlayerStatsRow(
        'Audio',
        pb.audioCodec.isNotEmpty ? pb.audioCodec : '-',
      ),
      PlayerStatsRow(
        'Audio track',
        audio == null
            ? '-'
            : (audio.language.isNotEmpty
                ? '${audio.label} (${audio.language})'
                : audio.label),
      ),
      PlayerStatsRow('Audio bitrate', _fmtBitrate(audioBitrate)),
      PlayerStatsRow(
        'Subtitle',
        _tracks.textOff
            ? 'Off'
            : (text?.label ?? '-'),
      ),
      if (bufferedAhead != null) PlayerStatsRow('Buffered ahead', bufferedAhead),
      PlayerStatsRow('Volume', '${snap.volume.round()}%'),
      PlayerStatsRow('Speed', '${_tracks.rate.toStringAsFixed(2)}x'),
      if (pb.droppedFrames > 0)
        PlayerStatsRow('Dropped frames', '${pb.droppedFrames}'),
    ];

    return PlayerStatsList(rows: rows);
  }

  static String? _fmtBufferedMs(int ms) {
    if (ms <= 0) return null;
    final secs = ms / 1000.0;
    if (secs > _maxSaneCacheAheadSecs) return null;
    if (secs < 60) return '${secs.toStringAsFixed(1)} s';
    return '${(secs / 60).toStringAsFixed(1)} min';
  }
}

/// AVPlayer / VLC — session fields only (no demuxer / track probe API yet).
class _IptvNativeSnapshotStatsBody extends StatefulWidget {
  const _IptvNativeSnapshotStatsBody({
    required this.engineLabel,
    required this.snapshot,
  });

  final String engineLabel;
  final PlayerStatsSnapshot Function() snapshot;

  @override
  State<_IptvNativeSnapshotStatsBody> createState() =>
      _IptvNativeSnapshotStatsBodyState();
}

class _IptvNativeSnapshotStatsBodyState
    extends State<_IptvNativeSnapshotStatsBody> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot();
    return PlayerStatsList(
      rows: [
        PlayerStatsRow('Engine', widget.engineLabel),
        PlayerStatsRow('Playing', snap.playing ? 'yes' : 'no'),
        PlayerStatsRow('Buffering', snap.buffering ? 'yes' : 'no'),
        PlayerStatsRow('Source', snap.sourceLabel),
        PlayerStatsRow('Volume', '${snap.volume.round()}%'),
        if (snap.retryAttempt > 0)
          PlayerStatsRow('Retries', '${snap.retryAttempt}'),
      ],
    );
  }
}
