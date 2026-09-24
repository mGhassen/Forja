/// Smooths instantaneous download throughput for UI speed / ETA labels.
///
/// Instant 1s samples jump (disk flush, segment gaps). The sampler keeps the
/// last smoothed rate between windows so the Active row does not flash
/// `0 KB/s` while bytes are still arriving.
class DownloadSpeedSampler {
  DownloadSpeedSampler({this.alpha = 0.35});

  /// EMA weight for each new 1s+ window sample (0–1). Higher = snappier.
  final double alpha;

  double _smoothedBytesPerSec = 0;
  int _bytesInWindow = 0;
  DateTime _windowStart = DateTime.now();

  double get speedBytesPerSec => _smoothedBytesPerSec;

  /// Add [byteCount] from the transfer. Returns true when a ≥1s window closed
  /// and [speedBytesPerSec] was updated (HTTP UI can tick only then).
  bool addBytes(int byteCount) {
    if (byteCount > 0) {
      _bytesInWindow += byteCount;
    }
    final now = DateTime.now();
    final elapsedMs = now.difference(_windowStart).inMilliseconds;
    if (elapsedMs < 1000) return false;

    final instant = _bytesInWindow / (elapsedMs / 1000.0);
    _smoothedBytesPerSec = _smoothedBytesPerSec <= 0
        ? instant
        : (alpha * instant) + ((1 - alpha) * _smoothedBytesPerSec);
    _bytesInWindow = 0;
    _windowStart = now;
    return true;
  }

  /// ETA in whole seconds for [remainingBytes], or null when unknown.
  int? etaSecondsFor(int remainingBytes) {
    if (_smoothedBytesPerSec <= 0 || remainingBytes <= 0) return null;
    return (remainingBytes / _smoothedBytesPerSec).ceil();
  }

  void reset() {
    _smoothedBytesPerSec = 0;
    _bytesInWindow = 0;
    _windowStart = DateTime.now();
  }
}
