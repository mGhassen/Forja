import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';

/// VOD playback recovery — hw decode fallback + failed URL blocklist.
class PlaybackRecovery {
  PlaybackRecovery({
    required this.player,
    required this.onRetryNextSource,
    this.onForceSoftwareDecode,
    this.onRecoverAudio,
  });

  final Player player;
  final VoidCallback onRetryNextSource;
  final Future<void> Function()? onForceSoftwareDecode;
  final Future<void> Function()? onRecoverAudio;

  bool softwareDecodeForced = false;
  bool hwFallbackAttempted = false;
  bool _audioRecoveryAttempted = false;

  void handleMpvLog(String text) {
    final lower = text.toLowerCase();
    if (!softwareDecodeForced &&
        !hwFallbackAttempted &&
        (lower.contains('hardware accelerator failed') ||
            lower.contains('vt decoder cb') ||
            lower.contains('output image buffer is null') ||
            lower.contains('no suitable decoder'))) {
      debugPrint('[PlaybackRecovery] hw decode failed — falling back');
      hwFallbackAttempted = true;
      unawaited(_forceSoftwareDecode());
    }
    if (!_audioRecoveryAttempted &&
        onRecoverAudio != null &&
        isAudioDecoderLog(text)) {
      debugPrint('[PlaybackRecovery] audio decode failed — recovering');
      _audioRecoveryAttempted = true;
      unawaited(onRecoverAudio!());
    }
  }

  void handlePlayerError(String err, {required String? currentUrl}) {
    if (isVideoDecoderError(err)) {
      if (currentUrl != null) PlaybackSelection.recordFailedUrl(currentUrl);
      // One-shot software decode on the same stream — never hop providers/sources.
      if (!hwFallbackAttempted && onForceSoftwareDecode != null) {
        hwFallbackAttempted = true;
        unawaited(_forceSoftwareDecode());
        return;
      }
      onRetryNextSource();
      return;
    }
    if (isAudioDecoderError(err)) {
      debugPrint('[PlaybackRecovery] audio decoder error (continuing): $err');
      return;
    }
    if (currentUrl != null && isFatalPlayerOpenError(err)) {
      PlaybackSelection.recordFailedUrl(currentUrl);
      onRetryNextSource();
    }
  }

  Future<void> _forceSoftwareDecode() async {
    if (softwareDecodeForced) return;
    softwareDecodeForced = true;
    if (onForceSoftwareDecode != null) {
      await onForceSoftwareDecode!();
      return;
    }
    if (player.platform is! NativePlayer) return;
    final native = player.platform as NativePlayer;
    await native.setProperty('hwdec', 'no');
    debugPrint('[PlaybackRecovery] hwdec=no');
  }
}
