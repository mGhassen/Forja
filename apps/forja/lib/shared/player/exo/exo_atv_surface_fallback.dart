import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

/// Detects physical ATV Exo SurfaceView bind failure (audio-only black) and
/// flips [ExoPlayerBridge.preferTextureSurface] so [ExoPlayerView] remounts.
///
/// Emulators already force TextureView in the view factory; phones always use
/// TextureView. This watchdog only arms on physical leanback while SurfaceView
/// is still preferred.
class ExoAtvSurfaceFallback {
  ExoAtvSurfaceFallback({
    required this.onFallback,
  });

  /// Called once after the prefer-TextureView flag flips — reopen at position.
  final Future<void> Function() onFallback;

  static const _watchdog = Duration(milliseconds: 2500);

  Timer? _timer;
  bool _gotFirstFrame = false;
  bool _hasVideoTrack = true;
  bool _fallingBack = false;
  bool _ready = false;
  bool _playing = false;

  bool get _shouldWatch =>
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
    _playing = false;
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
        _playing = event['value'] == true;
        if (_playing) _armIfNeeded();
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
    if (!_shouldWatch || !_ready || !_playing || !_hasVideoTrack) return;
    if (_gotFirstFrame || _timer != null) return;
    _timer = Timer(_watchdog, () {
      if (!_shouldWatch || _gotFirstFrame || !_hasVideoTrack) return;
      unawaited(_trigger(reason: 'no renderedFirstFrame within ${_watchdog.inMilliseconds}ms'));
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
