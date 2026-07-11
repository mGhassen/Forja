import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Media3 ExoPlayer bridge (Android only).
class ExoPlayerBridge {
  ExoPlayerBridge._();

  static const MethodChannel _channel = MethodChannel('com.forja.app/exoplayer');
  static const EventChannel _events =
      EventChannel('com.forja.app/exoplayer_events');

  static bool? _isTelevisionCache;

  static Future<bool> isTelevision() async {
    if (_isTelevisionCache != null) return _isTelevisionCache!;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _isTelevisionCache = false;
      return false;
    }
    try {
      final v = await _channel.invokeMethod<bool>('isTelevision');
      _isTelevisionCache = v ?? false;
      return _isTelevisionCache!;
    } catch (_) {
      _isTelevisionCache = false;
      return false;
    }
  }

  static Stream<Map<dynamic, dynamic>> eventsFor(int viewId) {
    return _events.receiveBroadcastStream().where((event) {
      if (event is! Map) return false;
      return event['viewId'] == viewId;
    }).map((e) => Map<dynamic, dynamic>.from(e as Map));
  }

  static Future<void> open({
    required int viewId,
    required String url,
    Map<String, String>? headers,
    Duration startPosition = Duration.zero,
    List<Map<String, String>> subtitles = const [],
  }) async {
    await _channel.invokeMethod<void>('open', {
      'viewId': viewId,
      'url': url,
      'headers': headers ?? const {},
      'startMs': startPosition.inMilliseconds,
      'subtitles': subtitles,
    });
  }

  static Future<void> play(int viewId) =>
      _channel.invokeMethod<void>('play', {'viewId': viewId});

  static Future<void> pause(int viewId) =>
      _channel.invokeMethod<void>('pause', {'viewId': viewId});

  static Future<void> seekTo(int viewId, Duration position) =>
      _channel.invokeMethod<void>('seekTo', {
        'viewId': viewId,
        'positionMs': position.inMilliseconds,
      });

  static Future<void> stop(int viewId) =>
      _channel.invokeMethod<void>('stop', {'viewId': viewId});

  static Future<void> dispose(int viewId) =>
      _channel.invokeMethod<void>('dispose', {'viewId': viewId});
}
