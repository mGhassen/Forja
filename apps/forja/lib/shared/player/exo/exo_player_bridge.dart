import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One selectable Media3 track exposed to Dart menus.
class ExoTrackInfo {
  const ExoTrackInfo({
    required this.id,
    required this.label,
    this.language = '',
    this.selected = false,
    this.height = 0,
    this.bitrate = 0,
  });

  final String id;
  final String label;
  final String language;
  final bool selected;
  final int height;
  final int bitrate;

  factory ExoTrackInfo.fromMap(Map<dynamic, dynamic> map) {
    return ExoTrackInfo(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? 'Track',
      language: map['language']?.toString() ?? '',
      selected: map['selected'] == true,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bitrate: (map['bitrate'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Snapshot of audio / text / video tracks from the native ExoPlayer host.
class ExoTracksSnapshot {
  const ExoTracksSnapshot({
    this.audio = const [],
    this.text = const [],
    this.video = const [],
    this.videoAuto = true,
    this.textOff = true,
    this.rate = 1.0,
  });

  final List<ExoTrackInfo> audio;
  final List<ExoTrackInfo> text;
  final List<ExoTrackInfo> video;
  final bool videoAuto;
  final bool textOff;
  final double rate;

  static const empty = ExoTracksSnapshot();

  factory ExoTracksSnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return empty;
    List<ExoTrackInfo> parse(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ExoTrackInfo.fromMap(Map<dynamic, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList();
    }

    return ExoTracksSnapshot(
      audio: parse(map['audio']),
      text: parse(map['text']),
      video: parse(map['video']),
      videoAuto: map['videoAuto'] != false,
      textOff: map['textOff'] == true,
      rate: (map['rate'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

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

  /// [volume] is 0.0–1.0 (maps from UI 0–150 scale).
  static Future<void> setVolume(int viewId, double volume) =>
      _channel.invokeMethod<void>('setVolume', {
        'viewId': viewId,
        'volume': volume.clamp(0.0, 1.0),
      });

  static Future<void> setRate(int viewId, double rate) =>
      _channel.invokeMethod<void>('setRate', {
        'viewId': viewId,
        'rate': rate.clamp(0.25, 2.0),
      });

  /// [mode]: `fit` | `fill` | `zoom`
  static Future<void> setResizeMode(int viewId, String mode) =>
      _channel.invokeMethod<void>('setResizeMode', {
        'viewId': viewId,
        'mode': mode,
      });

  static Future<ExoTracksSnapshot> getTracks(int viewId) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getTracks',
      {'viewId': viewId},
    );
    return ExoTracksSnapshot.fromMap(raw);
  }

  /// [type]: `audio` | `text` | `video`. Pass `trackId` null/`off` for text off,
  /// null/`auto` for video auto.
  static Future<void> selectTrack(
    int viewId, {
    required String type,
    String? trackId,
  }) =>
      _channel.invokeMethod<void>('selectTrack', {
        'viewId': viewId,
        'type': type,
        'trackId': trackId,
      });

  static Future<void> stop(int viewId) =>
      _channel.invokeMethod<void>('stop', {'viewId': viewId});

  static Future<void> dispose(int viewId) =>
      _channel.invokeMethod<void>('dispose', {'viewId': viewId});
}
