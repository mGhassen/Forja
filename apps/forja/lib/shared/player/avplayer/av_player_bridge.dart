import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native AVFoundation player bridge (macOS).
class AvPlayerBridge {
  AvPlayerBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.forjahq.app/avplayer');
  static const EventChannel _events =
      EventChannel('com.forjahq.app/avplayer_events');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

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
  }) async {
    if (!isSupported) {
      throw UnsupportedError('AVPlayer is macOS-only');
    }
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
        'volume': volume.clamp(0.0, 1.0),
      });

  static Future<void> dispose(int viewId) =>
      _channel.invokeMethod<void>('dispose', {'viewId': viewId});
}
