part of 'pt_player_screen.dart';

/// Shared fields for IPTV player engine parts (Slice 8).
mixin _PtPlayerEngineCore on ConsumerState<PtPlayerScreen> {
  _PtPlayerScreenState get _s => this as _PtPlayerScreenState;

  bool _playbackStartedRaw = false;

  /// Per-source "frames flowing" flag — reset by every open / zap / reconnect
  /// (watchdog semantics). Setting it true also latches the session-level
  /// [_PtPlayerScreenState._sessionHadFrame] used by the TV Back ladder.
  bool get _playbackStarted => _playbackStartedRaw;
  set _playbackStarted(bool value) {
    _playbackStartedRaw = value;
    if (value) _s._sessionHadFrame = true;
  }
  bool _recoveryInFlight = false;
  Future<void>? _openInFlight;
  int _openEpoch = 0;
}
