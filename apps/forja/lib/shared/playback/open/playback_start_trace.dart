import 'package:flutter/foundation.dart';

/// One recorded point on the Play → first-frame timeline.
@immutable
class PlaybackTraceMark {
  const PlaybackTraceMark(this.name, this.ms);

  final String name;

  /// Milliseconds since the session started.
  final int ms;

  @override
  String toString() => '$name +${ms}ms';
}

/// Host-generic timeline from the Play press to the first rendered frame.
///
/// Prints `[play-trace] <mark> +<ms>` through [debugPrint] in debug and
/// profile builds; a release build records nothing and prints nothing.
///
/// A session starts on the Play action ([start]) and ends on the first
/// rendered frame ([finish]). Marks outside a session are dropped so a later
/// in-player action does not print against a stale origin.
///
/// Marks carry no product vocabulary — only pipeline stage names.
class PlaybackStartTrace {
  PlaybackStartTrace({
    bool? enabled,
    int Function()? nowMs,
    void Function(String line)? sink,
  }) : _enabled = enabled ?? buildEnabled,
       _nowMs = nowMs,
       _sink = sink ?? debugPrint;

  /// Process-wide trace used by the play pipeline.
  static final PlaybackStartTrace instance = PlaybackStartTrace();

  /// Tracing is compiled out of release builds.
  static bool get buildEnabled => kDebugMode || kProfileMode;

  static const prefix = '[play-trace]';
  static const playPressed = 'play-pressed';

  final bool _enabled;
  final int Function()? _nowMs;
  final void Function(String line) _sink;

  final Stopwatch _stopwatch = Stopwatch();
  int _startMs = 0;
  bool _active = false;
  final List<PlaybackTraceMark> _marks = [];
  final Set<String> _onceSeen = {};

  bool get isActive => _enabled && _active;

  /// Marks recorded since [start], in order.
  List<PlaybackTraceMark> get marks => List.unmodifiable(_marks);

  int get _elapsedMs {
    final now = _nowMs;
    if (now != null) return now() - _startMs;
    return _stopwatch.elapsedMilliseconds;
  }

  /// Milliseconds since the session started; 0 when inactive.
  int get elapsedMs => isActive ? _elapsedMs : 0;

  /// Begin a session at the Play press. Resets any previous session.
  ///
  /// [label] distinguishes the entry point (details Play, episode switch…)
  /// without changing the mark name callers key on.
  void start({String label = ''}) {
    if (!_enabled) return;
    _marks.clear();
    _onceSeen.clear();
    _active = true;
    if (_nowMs != null) {
      _startMs = _nowMs();
    } else {
      _stopwatch
        ..reset()
        ..start();
    }
    mark(label.isEmpty ? playPressed : '$playPressed ($label)');
  }

  /// Record [name] at the current offset. Dropped when no session is active.
  void mark(String name, {String detail = ''}) {
    if (!isActive) return;
    final m = PlaybackTraceMark(name, _elapsedMs);
    _marks.add(m);
    _sink(detail.isEmpty ? '$prefix $m' : '$prefix $m $detail');
  }

  /// Record [name] only the first time it is seen in this session.
  ///
  /// Used where many parallel workers hit the same stage (first plugin to
  /// load its script, first plugin to finish) and only the first matters.
  void markOnce(String name, {String detail = ''}) {
    if (!isActive) return;
    if (!_onceSeen.add(name)) return;
    mark(name, detail: detail);
  }

  /// Record the terminal mark and close the session.
  void finish(String name, {String detail = ''}) {
    if (!isActive) return;
    mark(name, detail: detail);
    _active = false;
    _stopwatch.stop();
  }

  /// Drop the session without a terminal mark (Play cancelled or failed).
  void abandon() {
    if (!_enabled) return;
    _active = false;
    _stopwatch.stop();
  }
}
