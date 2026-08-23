import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/player/player/utils.dart';

/// After a user seek, remount once if playback does not resume near the target
/// within [stallAfter] — including stuck BUFFERING (issue 184 / Videasy HLS).
///
/// Clears when position advances ≥[progressClear] past the target, or pause.
/// Does not hop providers — same URL reopen only.
class PostSeekStallWatchdog {
  PostSeekStallWatchdog({
    required this.onRemount,
    this.stallAfter = const Duration(seconds: 10),
    this.armWindow = const Duration(seconds: 45),
    this.progressClear = const Duration(seconds: 2),
    this.enabled = true,
    this.scaleStallWithDepth = true,
  });

  /// Return true only when remount actually ran and resumed playback.
  final Future<bool> Function(Duration seekTarget) onRemount;
  final Duration stallAfter;
  final Duration armWindow;
  final Duration progressClear;

  /// Caller sets false for torrents / local files that should not remount.
  bool enabled;

  /// When true, [noteSeek] uses [postSeekStallTimeoutForTarget] (min 15s deep HLS).
  final bool scaleStallWithDepth;

  Timer? _timer;
  DateTime? _seekAt;
  Duration? _target;
  Duration _lastPos = Duration.zero;
  bool _buffering = false;
  bool _playing = true;
  bool _remountedForSeek = false;
  bool _remountInFlight = false;
  Duration _armedStallAfter = const Duration(seconds: 10);

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
    _armedStallAfter = scaleStallWithDepth
        ? postSeekStallTimeoutForTarget(_target!)
        : stallAfter;
    _remountedForSeek = false;
    if (_playing) _armTimer();
  }

  void onBuffering(bool buffering) {
    _buffering = buffering;
    if (!enabled || _seekAt == null || _remountedForSeek || _remountInFlight) {
      return;
    }
    if (_playing && _timer == null) _armTimer();
  }

  void onPlaying(bool playing) {
    _playing = playing;
    if (!enabled) return;
    if (!playing) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_seekAt != null &&
        !_remountedForSeek &&
        !_remountInFlight &&
        _timer == null) {
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
      return;
    }
    if (_playing && !_remountedForSeek && _timer == null) {
      _armTimer();
    }
  }

  void _armTimer() {
    if (_timer != null || _remountedForSeek || _remountInFlight) return;
    final target = _target;
    if (target == null || !_playing) return;
    _timer = Timer(_armedStallAfter, () => unawaited(_fire(target)));
  }

  bool _looksStalled() {
    final target = _target;
    if (target == null) return false;
    return _lastPos - target < progressClear;
  }

  Future<void> _fire(Duration target) async {
    _timer?.cancel();
    _timer = null;
    if (!enabled || _remountedForSeek || _remountInFlight) return;
    if (!_playing || !_looksStalled()) return;
    _remountInFlight = true;
    debugPrint(
      '[Player] Post-seek stall ≥${_armedStallAfter.inMilliseconds}ms '
      '(buffering=$_buffering pos=${_lastPos.inSeconds}s) — '
      'remount @${target.inSeconds}s',
    );
    var remounted = false;
    try {
      remounted = await onRemount(target);
    } finally {
      _remountInFlight = false;
      if (remounted) _remountedForSeek = true;
    }
  }
}
