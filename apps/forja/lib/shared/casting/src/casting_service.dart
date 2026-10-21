import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cast_subtitle.dart';

enum CastTarget { airplay, chromecast }

/// What the local player does while a cast owns playback.
class CastHandoff {
  const CastHandoff({
    required this.onStarted,
    required this.onEnded,
    this.onFailed,
    this.onSubtitlesUnavailable,
    this.onPosition,
  });

  /// The receiver took over — pause local playback.
  final VoidCallback onStarted;

  /// The receiver let go at [position] — resume locally from there.
  final void Function(Duration position) onEnded;

  /// The receiver could not play the stream. [message] is user-facing.
  final void Function(String message)? onFailed;

  /// The stream plays on the receiver, but without Forja's subtitle.
  final VoidCallback? onSubtitlesUnavailable;

  /// Receiver playhead while casting — keep the in-app seek bar in sync.
  final void Function(Duration position)? onPosition;
}

class CastingService {
  CastingService._();
  static final CastingService instance = CastingService._();

  static const _airPlay = MethodChannel('com.forjahq.app/airplay');
  static const _airPlayEvents = EventChannel('com.forjahq.app/airplay_events');

  StreamSubscription<dynamic>? _airPlaySub;
  CastHandoff? _handoff;

  /// True while an AirPlay device is playing the stream.
  final ValueNotifier<bool> airPlayActive = ValueNotifier(false);

  /// Last known receiver playhead while [airPlayActive] is true.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  bool get isAirPlayAvailable =>
      !kIsWeb && (Platform.isMacOS || Platform.isIOS);

  bool get isChromecastAvailable =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isWindows);

  /// Starts a cast. For AirPlay this opens the system device picker; the
  /// hand-off fires once a device is chosen. Returns false when [target]
  /// cannot start.
  ///
  /// [subtitle] is what Forja shows now. [duration] and [startTime] (the
  /// stream's first timestamp) place an external subtitle on the receiver's
  /// clock.
  Future<bool> castUrl({
    required String url,
    required CastTarget target,
    Map<String, String>? headers,
    String? title,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    Duration startTime = Duration.zero,
    CastSubtitle? subtitle,
    CastHandoff? handoff,
  }) async {
    if (target == CastTarget.airplay && isAirPlayAvailable) {
      return _startAirPlay(
        url: url,
        headers: headers,
        position: position,
        duration: duration,
        startTime: startTime,
        subtitle: subtitle,
        handoff: handoff,
      );
    }
    debugPrint('[Casting] ${target.name} cast requested: $url');
    return false;
  }

  Future<bool> _startAirPlay({
    required String url,
    Map<String, String>? headers,
    required Duration position,
    required Duration duration,
    required Duration startTime,
    CastSubtitle? subtitle,
    CastHandoff? handoff,
  }) async {
    _airPlaySub ??=
        _airPlayEvents.receiveBroadcastStream().listen(_onAirPlayEvent);
    try {
      // Already on a device: reopen the picker so the user can switch or
      // pick this device to come back.
      if (airPlayActive.value) {
        _handoff = handoff ?? _handoff;
        return await _airPlay.invokeMethod<bool>('showPicker') ?? false;
      }
      _handoff = handoff;
      this.position.value = position;
      final opened = await _airPlay.invokeMethod<bool>('start', {
            'url': url,
            'headers': headers ?? const <String, String>{},
            'positionMs': position.inMilliseconds,
            'durationMs': duration.inMilliseconds,
            'startTimeMs': startTime.inMilliseconds,
            'subtitle': subtitle?.toChannel(),
          }) ??
          false;
      if (opened && subtitle?.kind == CastSubtitleKind.unsupported) {
        handoff?.onSubtitlesUnavailable?.call();
      }
      return opened;
    } on PlatformException catch (e) {
      debugPrint('[Casting] AirPlay start failed: ${e.message}');
      _handoff = null;
      return false;
    } on MissingPluginException {
      _handoff = null;
      return false;
    }
  }

  /// Scrub the AirPlay receiver. Returns false when nothing is casting.
  Future<bool> seekIfCasting(Duration position) async {
    if (!airPlayActive.value) return false;
    final clamped = position < Duration.zero ? Duration.zero : position;
    try {
      await _airPlay.invokeMethod<void>('seek', {
        'positionMs': clamped.inMilliseconds,
      });
      this.position.value = clamped;
      _handoff?.onPosition?.call(clamped);
      return true;
    } on PlatformException catch (e) {
      debugPrint('[Casting] AirPlay seek failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void _onAirPlayEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = raw['event'];
    final ms = (raw['positionMs'] as num?)?.toInt() ?? 0;
    final at = Duration(milliseconds: ms);
    final handoff = _handoff;
    switch (event) {
      case 'active':
        airPlayActive.value = true;
        position.value = at;
        handoff?.onStarted();
        if (ms > 0) handoff?.onPosition?.call(at);
      case 'position':
        if (!airPlayActive.value) return;
        position.value = at;
        handoff?.onPosition?.call(at);
      case 'inactive':
        airPlayActive.value = false;
        _handoff = null;
        position.value = at;
        handoff?.onEnded(at);
      case 'error':
        final wasActive = airPlayActive.value;
        airPlayActive.value = false;
        _handoff = null;
        debugPrint('[Casting] AirPlay error: ${raw['message']}');
        handoff?.onFailed?.call("AirPlay can't play this stream");
        if (wasActive) handoff?.onEnded(at);
      case 'subtitles':
        if (raw['status'] == 'unavailable') handoff?.onSubtitlesUnavailable?.call();
      case 'cancelled':
        _handoff = null;
    }
  }

  /// Ends any cast without handing playback back (the player is going away).
  Future<void> stopCasting() async {
    _handoff = null;
    airPlayActive.value = false;
    position.value = Duration.zero;
    if (_airPlaySub == null) return;
    try {
      await _airPlay.invokeMethod<int>('stop');
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }
}
