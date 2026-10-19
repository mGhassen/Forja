import 'dart:async';

/// Drops overlapping native live-player opens.
///
/// Rapid Providers taps used to push several [Navigator] routes at once — each
/// unlocked + booted MediaKit, freezing the UI (issue 449).
abstract final class NativePlayerOpenGate {
  static Completer<void>? _lock;

  /// Runs [open] if idle; returns `null` while another open session is active
  /// (from first call through the player route pop).
  static Future<T?> run<T>(Future<T?> Function() open) async {
    if (_lock != null) return null;
    final lock = Completer<void>();
    _lock = lock;
    try {
      return await open();
    } finally {
      if (identical(_lock, lock)) _lock = null;
      if (!lock.isCompleted) lock.complete();
    }
  }
}
