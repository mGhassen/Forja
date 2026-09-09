import 'dart:io' show Platform;

import 'package:rust/rust.dart';

/// DRM (Widevine / ClearKey) is not playable in MediaKit yet.
/// Desktop FairPlay / AVPlayer is tracked separately — do not point users at Android.
bool streamDrmBlockedOffAndroid(dynamic drmRaw) {
  final drm = StreamDrmConfig.tryParse(drmRaw);
  if (drm == null) return false;
  // Until macOS FairPlay ships, skip DRM open on every non-Android engine.
  return !Platform.isAndroid;
}

/// Drop rows that would only open a dead MediaKit attempt off Android.
List<Map<String, dynamic>> omitPlatformBlockedDrmStreams(
  Iterable<Map<String, dynamic>> rows,
) {
  if (Platform.isAndroid) {
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }
  return [
    for (final r in rows)
      if (!streamDrmBlockedOffAndroid(r['drm'])) Map<String, dynamic>.from(r),
  ];
}

/// True when [rows] had at least one stream and every row is DRM-blocked here.
bool streamsArePlatformBlockedDrmOnly(Iterable<Map<String, dynamic>> rows) {
  if (Platform.isAndroid) return false;
  var any = false;
  for (final r in rows) {
    any = true;
    if (!streamDrmBlockedOffAndroid(r['drm'])) return false;
  }
  return any;
}

const kStreamDrmAndroidOnlyMessage =
    'This title is DRM-protected — desktop playback is not available yet.';
