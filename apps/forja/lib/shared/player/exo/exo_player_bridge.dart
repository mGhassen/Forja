import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/platform/platform_info.dart';

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

  static const MethodChannel _channel = MethodChannel('com.forjahq.app/exoplayer');
  static const EventChannel _events =
      EventChannel('com.forjahq.app/exoplayer_events');

  /// Process-lifetime: physical ATV prefers TextureView after SurfaceView
  /// failed to paint (audio-only). [ExoPlayerView] listens and remounts.
  static final ValueNotifier<bool> preferTextureSurface = ValueNotifier(false);

  static bool? _isTelevisionCache;

  /// Creation param for the PlatformView factory (`texture` | `surface`).
  static String creationSurfaceType() {
    if (!PlatformInfo.isAndroidTv || PlatformInfo.isAndroidEmulator) {
      return 'texture';
    }
    if (preferTextureSurface.value) return 'texture';
    return 'surface';
  }

  static void markPreferTextureSurface({String reason = ''}) {
    if (preferTextureSurface.value) return;
    debugPrint(
      '[ExoPlayer] ATV prefer TextureView'
      '${reason.isEmpty ? '' : ': $reason'}',
    );
    preferTextureSurface.value = true;
  }

  /// MediaCodec / SurfaceView bind failures that leave audio-only black.
  static bool isSurfaceAttachError(String message) {
    final m = message.toLowerCase();
    return m.contains('setoutputsurface') ||
        m.contains('bad_index') ||
        m.contains('null surface') ||
        m.contains('surface was abandoned') ||
        m.contains('surface is invalid') ||
        (m.contains('dequeuinputbuffer') && m.contains('surface')) ||
        (m.contains('mediacodec') && m.contains('surface'));
  }

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
    /// IPTV live: larger buffers + live offset. No automatic quality cap.
    bool live = false,
    /// Explicit opt-in from Settings → IPTV live max quality. `0` = no cap.
    int maxVideoHeight = 0,
    /// Soft bitrate companion when [maxVideoHeight] is set. `0` = none.
    int maxVideoBitrate = 0,
  }) async {
    await _channel.invokeMethod<void>('open', {
      'viewId': viewId,
      'url': url,
      'headers': headers ?? const {},
      'startMs': startPosition.inMilliseconds,
      'subtitles': subtitles,
      'live': live,
      'maxVideoHeight': maxVideoHeight,
      'maxVideoBitrate': maxVideoBitrate,
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

  /// [volume] is 0.0–1.0 (UI 100 = full; values above 100 clamp to 1.0).
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

  /// Soft-reload external SRT/VTT sideloads on the current media (keeps position).
  static Future<void> setSubtitles(
    int viewId,
    List<Map<String, String>> subtitles,
  ) =>
      _channel.invokeMethod<void>('setSubtitles', {
        'viewId': viewId,
        'subtitles': subtitles,
      });

  /// Apply Media3 [SubtitleView] appearance (size, color, background, position).
  static Future<void> setSubtitleStyle(
    int viewId, {
    required double sizeSp,
    required int textColorArgb,
    required double backgroundOpacity,
    required double bottomPaddingPx,
    required bool bold,
    String font = 'Default',
  }) =>
      _channel.invokeMethod<void>('setSubtitleStyle', {
        'viewId': viewId,
        'sizeSp': sizeSp,
        'textColorArgb': textColorArgb,
        'backgroundOpacity': backgroundOpacity.clamp(0.0, 1.0),
        'bottomPaddingPx': bottomPaddingPx,
        'bold': bold,
        'font': font,
      });

  static Future<void> stop(int viewId) =>
      _channel.invokeMethod<void>('stop', {'viewId': viewId});

  static Future<void> dispose(int viewId) =>
      _channel.invokeMethod<void>('dispose', {'viewId': viewId});
}
