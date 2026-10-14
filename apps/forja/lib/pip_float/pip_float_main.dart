import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/controls/chrome/desktop_pip_overlay.dart';
import 'package:forja/shared/player/platform/mpv_exclusive_session.dart';
import 'package:forja/shared/player/platform/pip_handoff.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Secondary-engine entry for the desktop PiP float window.
@pragma('vm:entry-point')
Future<void> pipFloatMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const PipFloatApp());
}

class PipFloatApp extends StatelessWidget {
  const PipFloatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PipFloatSurface(),
    );
  }
}

class PipFloatSurface extends StatefulWidget {
  const PipFloatSurface({super.key});

  @override
  State<PipFloatSurface> createState() => _PipFloatSurfaceState();
}

class _PipFloatSurfaceState extends State<PipFloatSurface> {
  static const _host = MethodChannel('forja/pip_float');

  Player? _player;
  VideoController? _controller;
  bool _hover = false;
  bool _playing = false;
  bool _isLive = false;
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;

  @override
  void initState() {
    super.initState();
    _host.setMethodCallHandler(_onHostCall);
    unawaited(_host.invokeMethod('floatReady'));
  }

  Future<dynamic> _onHostCall(MethodCall call) async {
    switch (call.method) {
      case 'open':
        final args = call.arguments;
        if (args is Map) {
          await _open(PipHandoffSnapshot.fromMap(args));
        }
        return null;
      case 'teardown':
        await _teardown();
        return null;
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<void> _open(PipHandoffSnapshot snap) async {
    await _teardown();
    if (snap.url.isEmpty) return;

    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    final player = MpvExclusiveSession.instance.trackPlayer(Player());
    final controller = VideoController(player);
    _player = player;
    _controller = controller;
    _isLive = snap.isLive;

    _playingSub = player.stream.playing.listen((v) {
      if (!mounted) return;
      setState(() => _playing = v);
    });
    _posSub = player.stream.position.listen((v) => _position.value = v);
    _durSub = player.stream.duration.listen((v) => _duration.value = v);

    try {
      await openPlayerStream(
        player,
        url: snap.url,
        headers: snap.headers.isEmpty ? null : snap.headers,
        providerId: snap.providerId,
        startAt: snap.isLive ? null : snap.position,
      );
      if (snap.playing) {
        await player.play();
      } else {
        await player.pause();
      }
      if (mounted) setState(() => _playing = snap.playing);
    } catch (e) {
      debugPrint('[PipFloat] open failed: $e');
    }
  }

  Future<void> _teardown() async {
    await _playingSub?.cancel();
    await _posSub?.cancel();
    await _durSub?.cancel();
    _playingSub = null;
    _posSub = null;
    _durSub = null;
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      MpvExclusiveSession.instance.untrackPlayer(player);
      final dispose = teardownMediaKitPlayer(player);
      MpvExclusiveSession.instance.trackVideoDispose(dispose);
      await dispose;
    }
  }

  Future<void> _expand() async {
    final player = _player;
    final pos = player?.state.position ?? _position.value;
    final playing = player?.state.playing ?? _playing;
    await _host.invokeMethod('expand', {
      'positionMs': pos.inMilliseconds,
      'playing': playing,
    });
  }

  Future<void> _close() async {
    await _host.invokeMethod('close');
  }

  Future<void> _minimize() async {
    await _host.invokeMethod('minimize');
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (player.state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final player = _player;
    if (player == null || _isLive) return;
    final next = player.state.position + delta;
    await player.seek(next < Duration.zero ? Duration.zero : next);
  }

  Future<void> _seekTo(Duration d) async {
    final player = _player;
    if (player == null || _isLive) return;
    await player.seek(d);
  }

  @override
  void dispose() {
    unawaited(_teardown());
    _position.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            Video(
              controller: controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
              fill: Colors.black,
              subtitleViewConfiguration: const SubtitleViewConfiguration(
                visible: false,
              ),
            )
          else
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          DesktopPipOverlay(
            hovering: _hover,
            onHoverChanged: (v) {
              if (_hover == v) return;
              setState(() => _hover = v);
            },
            playing: _playing,
            onTogglePlay: () => unawaited(_togglePlay()),
            onRestore: () => unawaited(_expand()),
            onMinimize: () => unawaited(_minimize()),
            onClose: () => unawaited(_close()),
            onSeekBack: _isLive ? null : () => unawaited(_seekBy(const Duration(seconds: -15))),
            onSeekForward: _isLive ? null : () => unawaited(_seekBy(const Duration(seconds: 15))),
            positionListenable: _isLive ? null : _position,
            durationListenable: _isLive ? null : _duration,
            onSeekTo: _isLive ? null : (d) => unawaited(_seekTo(d)),
            onStartDrag: () => _host.invokeMethod('startDrag'),
          ),
        ],
      ),
    );
  }
}
