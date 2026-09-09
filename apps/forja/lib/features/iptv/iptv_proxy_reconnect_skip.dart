/// Bitrate-adaptive CDN overlap skip for [IptvLiveContinuityProxy].
///
/// Xtream fresh GETs often restart a few seconds behind the previous socket.
/// A fixed 3 MiB skip is ~3–12 s depending on bitrate — too little → replay,
/// too much → underrun freeze on thin ATV cushions. Target ~[targetSecs] of
/// media, clamped.
int iptvProxyReconnectSkipBytes({
  required int estimatedBytesPerSec,
  double targetSecs = 5.0,
  int minBytes = 1 * 1024 * 1024,
  int maxBytes = 8 * 1024 * 1024,
  int fallbackBytes = 3 * 1024 * 1024,
}) {
  if (estimatedBytesPerSec <= 0) return fallbackBytes;
  final raw = (estimatedBytesPerSec * targetSecs).round();
  if (raw < minBytes) return minBytes;
  if (raw > maxBytes) return maxBytes;
  return raw;
}

/// Abort remaining overlap skip when the loopback queue would starve the player.
/// Prefer a short replay over a hard underrun freeze on Android TV.
int iptvProxySkipAbortQueueFloorBytes({
  required int estimatedBytesPerSec,
  double floorSecs = 3.0,
  int minBytes = 256 * 1024,
  int maxBytes = 4 * 1024 * 1024,
  int fallbackBytes = 512 * 1024,
}) {
  if (estimatedBytesPerSec <= 0) return fallbackBytes;
  final raw = (estimatedBytesPerSec * floorSecs).round();
  if (raw < minBytes) return minBytes;
  if (raw > maxBytes) return maxBytes;
  return raw;
}

/// Continuity-proxy read-ahead: cover one reconnect skip (≤8 MiB) plus play.
int iptvContinuityProxyMaxQueueBytes({
  required int videoHeight,
  required int videoBitrate,
}) {
  if (videoHeight >= 2160 || videoBitrate >= 25_000_000) {
    return 20 * 1024 * 1024;
  }
  if ((videoHeight > 0 && videoHeight < 1080) ||
      (videoBitrate > 0 && videoBitrate < 8_000_000)) {
    return 12 * 1024 * 1024;
  }
  return 16 * 1024 * 1024;
}
