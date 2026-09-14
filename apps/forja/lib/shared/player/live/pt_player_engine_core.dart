part of 'pt_player_screen.dart';

/// Shared fields for IPTV player engine parts (Slice 8).
mixin _PtPlayerEngineCore on ConsumerState<PtPlayerScreen> {
  _PtPlayerScreenState get _s => this as _PtPlayerScreenState;

  bool _playbackStarted = false;
  bool _recoveryInFlight = false;
  Future<void>? _openInFlight;
  int _openEpoch = 0;
}
