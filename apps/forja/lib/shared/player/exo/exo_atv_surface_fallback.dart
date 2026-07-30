import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

/// Detects physical ATV Exo SurfaceView bind failure (audio-only black) and
/// flips [ExoPlayerBridge.preferTextureSurface] so [ExoPlayerView] remounts.
///
/// Only arm when [enabled] — Home/VOD always uses TextureView and must leave
/// this disabled. IPTV live may enable SurfaceView (issue 108) and needs the
/// watchdog (issue 133).
class ExoAtvSurfaceFallback {
  ExoAtvSurfaceFallback({
    required this.onFallback,
    this.enabled = true,
  });

  /// Called once after the prefer-TextureView flag flips — reopen at position.
  final Future<void> Function() onFallback;

  /// False for VOD (always TextureView). True for IPTV when SurfaceView is allowed.
  final bool enabled;

  static const _watchdog = Duration(milliseconds: 2500);

  Timer? _timer;
  bool _gotFirstFrame = false;
  bool _hasVideoTrack = true;
  bool _fallingBack = false;
  bool _ready = false;

  bool get _shouldWatch =>
      enabled &&
      PlatformInfo.isAndroidTv &&
      !PlatformInfo.isAndroidEmulator &&
      !ExoPlayerBridge.preferTextureSurface.value &&
      !_fallingBack;

  void resetForNewOpen() {
    _timer?.cancel();
    _timer = null;
    _gotFirstFrame = false;
    _hasVideoTrack = true;
    _ready = false;
    // Keep _fallingBack false so a later session can watch again only when
    // preferTexture is still false (SurfaceView path).
    _fallingBack = false;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Returns true when the caller should treat [message] as handled (do not
  /// hop sources / hard-recover — TextureView remount is in progress).
  bool handleNativeEvent(Map<dynamic, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'renderedFirstFrame':
        _gotFirstFrame = true;
        _timer?.cancel();
        _timer = null;
        return false;
      case 'ready':
        _ready = true;
        _armIfNeeded();
        return false;
      case 'playing':
        // Playing alone is enough to arm once READY has landed.
        if (event['value'] == true) _armIfNeeded();
        return false;
      case 'progress':
        // Bind-dead SurfaceView: audio/position advance, no first frame.
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        if (_shouldWatch &&
            _ready &&
            _hasVideoTrack &&
            !_gotFirstFrame &&
            posMs >= 1500) {
          unawaited(
            _trigger(reason: 'progress ${posMs}ms without renderedFirstFrame'),
          );
          return true;
        }
        return false;
      case 'tracksChanged':
        final snap = ExoTracksSnapshot.fromMap(event);
        // Empty video list after tracks land → likely audio-only stream; skip.
        if (snap.video.isEmpty &&
            (snap.audio.isNotEmpty || snap.text.isNotEmpty)) {
          _hasVideoTrack = false;
          _timer?.cancel();
          _timer = null;
        } else if (snap.video.isNotEmpty) {
          _hasVideoTrack = true;
          _armIfNeeded();
        }
        return false;
      case 'error':
        final msg = event['message']?.toString() ?? '';
        if (_shouldWatch && ExoPlayerBridge.isSurfaceAttachError(msg)) {
          unawaited(_trigger(reason: 'surface error: $msg'));
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  void _armIfNeeded() {
    // Do not require playing — READY without a frame within the watchdog is
    // already enough for bind-dead SurfaceView (audio may start slightly later).
    if (!_shouldWatch || !_ready || !_hasVideoTrack) return;
    if (_gotFirstFrame || _timer != null) return;
    _timer = Timer(_watchdog, () {
      if (!_shouldWatch || _gotFirstFrame || !_hasVideoTrack) return;
      unawaited(
        _trigger(
          reason:
              'no renderedFirstFrame within ${_watchdog.inMilliseconds}ms after ready',
        ),
      );
    });
  }

  Future<void> _trigger({required String reason}) async {
    if (!_shouldWatch || _fallingBack) return;
    _fallingBack = true;
    _timer?.cancel();
    _timer = null;
    ExoPlayerBridge.markPreferTextureSurface(reason: reason);
    try {
      await onFallback();
    } catch (e) {
      debugPrint('[ExoAtvSurfaceFallback] reopen failed: $e');
    }
  }
}
