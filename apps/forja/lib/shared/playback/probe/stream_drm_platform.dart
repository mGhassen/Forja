import 'dart:io' show Platform;

import 'package:rust/rust.dart';

/// Widevine / ClearKey only play on Android Exo (RFC-101).
bool streamDrmBlockedOffAndroid(dynamic drmRaw) {
  final drm = StreamDrmConfig.tryParse(drmRaw);
  return drm != null && !Platform.isAndroid;
}

const kStreamDrmAndroidOnlyMessage =
    'This stream needs Android ExoPlayer (Widevine DRM).';
