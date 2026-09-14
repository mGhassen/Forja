part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

/// Lavf reconnect helpers (RFC-113 / ipdigi — no continuity proxy).
mixin _PtPlayerLavf on _PtPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  /// ipdigi `stream-lavf-o` — progressive and HLS.
  static const _lavfReconnect =
      'reconnect=1,'
      'reconnect_at_eof=1,'
      'reconnect_streamed=1,'
      'reconnect_on_network_error=1,'
      'reconnect_delay_max=5';

  Future<void> _applyStreamLavfReconnect(NativePlayer p) async {
    await p.setProperty('stream-lavf-o', _lavfReconnect);
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }
}
