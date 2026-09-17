part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

/// Lavf reconnect helpers (RFC-113 / ipdigi — no continuity proxy).
mixin _PtPlayerLavf on _PtPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  /// Progressive TS uses [iptvStreamLavfO] reconnect; HLS is `reconnect=0`
  /// (playlist EOF loop — issue 273).
  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    String? streamUrl,
  }) async {
    await p.setProperty('stream-lavf-o', iptvStreamLavfO(streamUrl: streamUrl));
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }
}
