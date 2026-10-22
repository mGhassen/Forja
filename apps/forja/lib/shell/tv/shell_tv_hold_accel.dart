import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hold ↑/↓/←/→ acceleration for Android TV lists and rails.
///
/// OS key-repeat already steps once per event; this increases the **stride**
/// (items / grid rows / rail cards per repeat) the longer the same arrow key
/// is held. Callers decide which axis consumes [lastStep]: vertical menus and
/// grids (issue 156) and horizontal catalog rails (RFC-122) do; chip strips
/// and linear settings menus keep horizontal moves at 1.
abstract final class ShellTvHoldAccel {
  static DateTime? _startedAt;
  static LogicalKeyboardKey? _key;
  static int _lastStep = 1;
  static bool _repeating = false;

  /// Clock — overridable in tests so the hold curve can be asserted without
  /// real waits.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Stride from the most recent [note] call (1 when idle / non-arrow).
  static int get lastStep => _lastStep < 1 ? 1 : _lastStep;

  /// True from the first [KeyRepeatEvent] of the held arrow until its key-up.
  ///
  /// Rail focus scroll jumps instead of animating while this is set so a
  /// repeat burst never outruns the scroll tween.
  static bool get isHolding => _repeating && _key != null;

  static bool _isArrow(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;

  /// Record a navigation key event and refresh [lastStep].
  static int note(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      if (_key == key || _isArrow(key)) reset();
      return _lastStep;
    }
    if (!_isArrow(key)) {
      reset();
      return 1;
    }
    if (event is KeyDownEvent) {
      _startedAt = now();
      _key = key;
      _lastStep = 1;
      _repeating = false;
      return 1;
    }
    if (event is KeyRepeatEvent && _key == key && _startedAt != null) {
      _repeating = true;
      _lastStep = stepForHoldMs(now().difference(_startedAt!).inMilliseconds);
      return _lastStep;
    }
    return _lastStep;
  }

  /// Acceleration curve — exposed for unit tests.
  ///
  /// Deliberately slow: short holds stay 1-step; ramp only after a real hold.
  static int stepForHoldMs(int holdMs) {
    if (holdMs >= 5000) return 8;
    if (holdMs >= 3500) return 5;
    if (holdMs >= 2200) return 3;
    if (holdMs >= 1200) return 2;
    return 1;
  }

  /// Player progress-bar scrub: 0–3s 10s · 3–7s 20s · 7–11s 30s · 11s+ 50s.
  static int seekStepForHoldMs(int holdMs) {
    if (holdMs >= 11000) return 5;
    if (holdMs >= 7000) return 3;
    if (holdMs >= 3000) return 2;
    return 1;
  }

  static void reset() {
    _startedAt = null;
    _key = null;
    _lastStep = 1;
    _repeating = false;
  }

  /// Test-only — clear hold state between cases.
  @visibleForTesting
  static void clearForTest() {
    reset();
    now = DateTime.now;
  }
}
