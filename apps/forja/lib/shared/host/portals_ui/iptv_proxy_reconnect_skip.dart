/// Bitrate-adaptive CDN overlap skip for [IptvLiveContinuityProxy].
///
/// Xtream fresh GETs often restart a few seconds behind the previous socket.
/// Skip too little → replay; skip too long (wall clock) → Exo/MediaKit underrun
/// even when the proxy byte queue looks full (player LoadControl backpressure).
int iptvProxyReconnectSkipBytes({
  required int estimatedBytesPerSec,
  double targetSecs = 2.5,
  int minBytes = 768 * 1024,
  int maxBytes = 4 * 1024 * 1024,
  int fallbackBytes = 2 * 1024 * 1024,
}) {
  if (estimatedBytesPerSec <= 0) return fallbackBytes;
  final raw = (estimatedBytesPerSec * targetSecs).round();
  if (raw < minBytes) return minBytes;
  if (raw > maxBytes) return maxBytes;
  return raw;
}

/// Minimum overlap that must be dropped before a queue-based early-abort.
/// Aborting at skipped=0 with an empty queue feeds the CDN replay (~5 s).
int iptvProxyMinSkipBytes({
  required int estimatedBytesPerSec,
  double minSecs = 1.5,
  int minBytes = 512 * 1024,
  int maxBytes = 2 * 1024 * 1024,
  int fallbackBytes = 1024 * 1024,
}) {
  if (estimatedBytesPerSec <= 0) return fallbackBytes;
  final raw = (estimatedBytesPerSec * minSecs).round();
  if (raw < minBytes) return minBytes;
  if (raw > maxBytes) return maxBytes;
  return raw;
}

/// Abort remaining overlap skip when the loopback queue would starve the player.
/// Prefer a short replay over a hard underrun freeze on Android TV.
int iptvProxySkipAbortQueueFloorBytes({
  required int estimatedBytesPerSec,
  double floorSecs = 2.0,
  int minBytes = 256 * 1024,
  int maxBytes = 2 * 1024 * 1024,
  int fallbackBytes = 512 * 1024,
}) {
  if (estimatedBytesPerSec <= 0) return fallbackBytes;
  final raw = (estimatedBytesPerSec * floorSecs).round();
  if (raw < minBytes) return minBytes;
  if (raw > maxBytes) return maxBytes;
  return raw;
}

/// Wall-clock / min-skip gate for overlap skip (Exo LoadControl can keep the
/// proxy queue fat while playhead ahead collapses).
bool iptvProxyShouldAbortSkip({
  required int skippedBytes,
  required int minSkipBytes,
  required int queuedBytes,
  required int abortFloorBytes,
  required int elapsedMs,
  int maxSkipMs = 1200,
}) {
  if (elapsedMs >= maxSkipMs) return true;
  if (skippedBytes >= minSkipBytes && queuedBytes < abortFloorBytes) {
    return true;
  }
  return false;
}

/// Continuity-proxy read-ahead: cover one reconnect skip (≤4 MiB) plus play.
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
