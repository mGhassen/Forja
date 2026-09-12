import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native libVLC bridge — Flutter [Texture] output (Windows / macOS / Linux).
class VlcPlayerBridge {
  VlcPlayerBridge._();

  static const MethodChannel _channel = MethodChannel('com.forjahq.app/vlc');
  static const EventChannel _events =
      EventChannel('com.forjahq.app/vlc_events');

  static bool? _availableCache;

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// True when native host can load libVLC (system install or next to binary).
  static Future<bool> isAvailable() async {
    if (!isSupportedPlatform) return false;
    if (_availableCache != null) return _availableCache!;
    try {
      final v = await _channel.invokeMethod<bool>('isAvailable');
      _availableCache = v ?? false;
    } catch (_) {
      _availableCache = false;
    }
    return _availableCache!;
  }

  static Stream<Map<dynamic, dynamic>> eventsFor(int viewId) {
    return _events.receiveBroadcastStream().where((event) {
      if (event is! Map) return false;
      return event['viewId'] == viewId;
    }).map((e) => Map<dynamic, dynamic>.from(e as Map));
  }

  /// Creates a pixel buffer texture. Returns texture id (≥0) or -1.
  static Future<int> create(int viewId) async {
    final id = await _channel.invokeMethod<int>('create', {'viewId': viewId});
    return id ?? -1;
  }

  static Future<void> open({
    required int viewId,
    required String url,
    Map<String, String>? headers,
  }) async {
    await _channel.invokeMethod<void>('open', {
      'viewId': viewId,
      'url': url,
      'headers': headers ?? const {},
    });
  }

  static Future<void> play(int viewId) =>
      _channel.invokeMethod<void>('play', {'viewId': viewId});

  static Future<void> pause(int viewId) =>
      _channel.invokeMethod<void>('pause', {'viewId': viewId});

  static Future<void> setVolume(int viewId, double volume) =>
      _channel.invokeMethod<void>('setVolume', {
        'viewId': viewId,
        'volume': (volume.clamp(0.0, 1.0) * 100).round(),
      });

  static Future<void> dispose(int viewId) =>
      _channel.invokeMethod<void>('dispose', {'viewId': viewId});
}
