import 'dart:async';

import 'package:flutter/foundation.dart';

/// After a user seek, if BUFFERING stays true for [stallAfter], remount once
/// at the seek target. Clears on buffering end or a new seek.
///
/// Does not hop providers — same URL reopen only (issue 184).
class PostSeekStallWatchdog {
  PostSeekStallWatchdog({
    required this.onRemount,
    this.stallAfter = const Duration(seconds: 10),
    this.armWindow = const Duration(seconds: 45),
    this.enabled = true,
  });

  final Future<void> Function(Duration seekTarget) onRemount;
  final Duration stallAfter;
  final Duration armWindow;

  /// Caller sets false for torrents / local files that should not remount.
  bool enabled;

  Timer? _timer;
  DateTime? _seekAt;
  Duration? _target;
  bool _buffering = false;
  bool _remountedForSeek = false;
  bool _remountInFlight = false;

  Duration? get pendingTarget => _target;
  bool get remountInFlight => _remountInFlight;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call from every user-facing seek (±10s, scrub, D-pad).
  void noteSeek(Duration target) {
    if (!enabled) return;
    _timer?.cancel();
    _timer = null;
    _seekAt = DateTime.now();
    _target = target < Duration.zero ? Duration.zero : target;
    _remountedForSeek = false;
    if (_buffering) _armTimer();
  }

  void onBuffering(bool buffering) {
    _buffering = buffering;
    if (!enabled) return;
    if (!buffering) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_seekAt == null || _remountedForSeek || _remountInFlight) return;
    final age = DateTime.now().difference(_seekAt!);
    if (age > armWindow) return;
    _armTimer();
  }

  /// When playback advances after a seek without hanging, drop the arm.
  void onPosition(Duration position) {
    if (!enabled || _seekAt == null || _buffering || _remountInFlight) return;
    final target = _target;
    if (target == null) return;
    final delta = (position - target).abs();
    if (delta <= const Duration(seconds: 3)) {
      _seekAt = null;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _armTimer() {
    if (_timer != null || _remountedForSeek || _remountInFlight) return;
    final target = _target;
    if (target == null) return;
    _timer = Timer(stallAfter, () => unawaited(_fire(target)));
  }

  Future<void> _fire(Duration target) async {
    _timer?.cancel();
    _timer = null;
    if (!enabled || _remountedForSeek || _remountInFlight) return;
    if (!_buffering) return;
    _remountedForSeek = true;
    _remountInFlight = true;
    debugPrint(
      '[Player] Post-seek BUFFERING ≥${stallAfter.inSeconds}s — '
      'remount @${target.inSeconds}s',
    );
    try {
      await onRemount(target);
    } finally {
      _remountInFlight = false;
    }
  }
}
