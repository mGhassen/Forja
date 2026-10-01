part of 'live_sports_player_screen.dart';

/// Shared fields for IPTV player engine parts (Slice 8).
mixin _LiveSportsPlayerEngineCore on ConsumerState<LiveSportsPlayerScreen> {
  _LiveSportsPlayerScreenState get _s => this as _LiveSportsPlayerScreenState;

  bool _playbackStarted = false;
  bool _recoveryInFlight = false;
  Future<void>? _openInFlight;
  int _openEpoch = 0;
}
