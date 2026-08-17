import 'dart:async';

import 'package:flutter/foundation.dart';

/// After a user seek, remount once if playback does not resume:
/// - BUFFERING stays true for [stallAfter], **or**
/// - position never advances past the seek target (MediaKit silent freeze)
///
/// Clears when position advances ≥[progressClear] past the target, or pause.
/// Does not hop providers — same URL reopen only (issue 184).
class PostSeekStallWatchdog {
  PostSeekStallWatchdog({
    required this.onRemount,
    this.stallAfter = const Duration(seconds: 10),
    this.armWindow = const Duration(seconds: 45),
    this.progressClear = const Duration(seconds: 2),
    this.enabled = true,
  });

  final Future<void> Function(Duration seekTarget) onRemount;
  final Duration stallAfter;
  final Duration armWindow;
  final Duration progressClear;

  /// Caller sets false for torrents / local files that should not remount.
  bool enabled;

  Timer? _timer;
  DateTime? _seekAt;
  Duration? _target;
  Duration _lastPos = Duration.zero;
  bool _buffering = false;
  bool _playing = true;
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
    _lastPos = _target!;
    _remountedForSeek = false;
    // Always arm — MediaKit often freezes with buffering=false.
    if (_playing) _armTimer();
  }

  void onBuffering(bool buffering) {
    _buffering = buffering;
    if (!enabled || _seekAt == null || _remountedForSeek || _remountInFlight) {
      return;
    }
    // Do not cancel on buffering=false — silent freeze is the MediaKit case.
    if (buffering && _playing) _armTimer();
  }

  void onPlaying(bool playing) {
    _playing = playing;
    if (!enabled) return;
    if (!playing) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_seekAt != null && !_remountedForSeek && !_remountInFlight) {
      final age = DateTime.now().difference(_seekAt!);
      if (age <= armWindow) _armTimer();
    }
  }

  /// Clear when playback advances past the seek target.
  void onPosition(Duration position) {
    _lastPos = position;
    if (!enabled || _seekAt == null || _remountInFlight) return;
    final target = _target;
    if (target == null) return;
    if (position - target >= progressClear) {
      _seekAt = null;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _armTimer() {
    if (_timer != null || _remountedForSeek || _remountInFlight) return;
    final target = _target;
    if (target == null || !_playing) return;
    _timer = Timer(stallAfter, () => unawaited(_fire(target)));
  }

  bool _looksStalled() {
    if (_buffering) return true;
    final target = _target;
    if (target == null) return false;
    // Frozen on/near seek point — never made progressClear past it.
    return _lastPos - target < progressClear;
  }

  Future<void> _fire(Duration target) async {
    _timer?.cancel();
    _timer = null;
    if (!enabled || _remountedForSeek || _remountInFlight) return;
    if (!_playing || !_looksStalled()) return;
    _remountedForSeek = true;
    _remountInFlight = true;
    debugPrint(
      '[Player] Post-seek stall ≥${stallAfter.inSeconds}s '
      '(buffering=$_buffering pos=${_lastPos.inSeconds}s) — '
      'remount @${target.inSeconds}s',
    );
    try {
      await onRemount(target);
    } finally {
      _remountInFlight = false;
    }
  }
}
