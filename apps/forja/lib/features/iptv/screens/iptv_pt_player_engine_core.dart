part of 'iptv_pt_player_screen.dart';

/// Shared fields for IPTV player engine parts (Slice 8).
mixin _IptvPtPlayerEngineCore on ConsumerState<IptvPtPlayerScreen> {
  _IptvPtPlayerScreenState get _s => this as _IptvPtPlayerScreenState;

  bool _playbackStarted = false;
  bool _recoveryInFlight = false;
  Future<void>? _openInFlight;
  int _openEpoch = 0;
}
