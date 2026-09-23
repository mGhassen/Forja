part of 'live_sports_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

/// Live Sports lavf reconnect — v1.5.36 direct string always.
mixin _LiveSportsPlayerLavf on _LiveSportsPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  Future<void> _applyStreamLavfReconnect(NativePlayer p, {String? streamUrl}) async {
    await p.setProperty('stream-lavf-o', liveSportsStreamLavfO());
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }
}
