part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

/// Lavf reconnect helpers (RFC-113 — no continuity proxy).
mixin _PtPlayerLavf on _PtPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  /// [iptvStreamLavfO] — lavf reconnect on (progressive + HLS).
  /// [continuityRelay]: the relay owns upstream reopen — `reconnect=0`.
  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    String? streamUrl,
    bool continuityRelay = false,
  }) async {
    await p.setProperty(
      'stream-lavf-o',
      continuityRelay ? 'reconnect=0' : iptvStreamLavfO(streamUrl: streamUrl),
    );
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }
}
