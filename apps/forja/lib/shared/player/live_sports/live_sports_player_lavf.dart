part of 'live_sports_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

/// Live Sports lavf reconnect — v1.5.36 direct string always.
mixin _LiveSportsPlayerLavf on _LiveSportsPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    String? streamUrl,
    bool continuityProxy = false,
  }) async {
    await p.setProperty(
      'stream-lavf-o',
      liveSportsStreamLavfO(
        streamUrl: streamUrl,
        continuityProxy: continuityProxy,
      ),
    );
    // Live HLS segments often start with a bad DTS. discardcorrupt drops that
    // packet and the picture stalls until the next piece. Ignore the bad DTS
    // and fetch the next segment while this one plays.
    if (!_s.widget.vodPlayback &&
        streamUrl != null &&
        streamUrl.isNotEmpty &&
        iptvUrlLooksLikeHls(streamUrl)) {
      await p.setProperty(
        'demuxer-lavf-o',
        'fflags=+genpts+igndts,'
        'http_multiple=1,'
        'probesize=5000000,'
        'analyzeduration=5000000',
      );
    }
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }
}
