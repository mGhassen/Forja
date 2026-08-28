part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerLiveProxy on _IptvPtPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  void _onProxyUpstreamReconnected() {
    unawaited(() async {
      if (_s._disposed || _s._exoBackend || _recoveryInFlight) return;
      if (!_s._playerAlive) return;
      _armTransientHwDecodeIgnore();
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        var cacheSecs = _s._cacheAheadSecs;
        try {
          final aheadRaw = await p.getProperty('demuxer-cache-duration');
          final ahead = double.tryParse(aheadRaw.toString());
          if (ahead != null &&
              ahead.isFinite &&
              ahead >= 0 &&
              ahead <= _IptvPtPlayerScreenState._maxSaneCacheAheadSecs) {
            cacheSecs = ahead;
            _applyCacheAheadSample(ahead, source: 'reconnect-probe');
          }
        } catch (_) {}

        final playThrough = cacheSecs >=
            _IptvPtPlayerScreenState._minHealthyCacheSecs;
        if (playThrough) {
          debugPrint(
            '[IPTV Proxy] play-through reconnect '
            '(cache=${cacheSecs.toStringAsFixed(1)}s — no drop-buffers)',
          );
        } else if (_playbackStarted && _s._playerAlive && !_recoveryInFlight) {
          // Empty cushion: let watchdog soft-reopen. drop-buffers on a demuxer
          // that already failed format probe can native-crash (macOS).
          debugPrint(
            '[IPTV Proxy] empty cache on reconnect — leave to watchdog '
            '(cache=${cacheSecs.toStringAsFixed(1)}s, no drop-buffers)',
          );
        }
        if (_s._userPlayWhenReady && !_s._playing && !_recoveryInFlight) {
          await _enginePlay();
        }
      } catch (e) {
        debugPrint('[IPTV Proxy] reconnect handoff failed: $e');
      }
    }());
  }

  void _invalidatePendingLiveEdgeSnaps() {
    _s._liveEdgeSnapEpoch++;
  }

  static const _lavfReconnectDirect =
      'reconnect=1,'
      'reconnect_at_eof=1,'
      'reconnect_streamed=1,'
      'reconnect_delay_max=30,'
      'reconnect_on_network_error=1,'
      'reconnect_on_http_error=4xx\\,5xx';

  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    required bool continuityProxy,
  }) async {
    if (continuityProxy) {
      await p.setProperty('stream-lavf-o', 'reconnect=0');
    } else {
      await p.setProperty('stream-lavf-o', _lavfReconnectDirect);
    }
  }

  int _continuityProxyMaxQueueBytes() {
    final h = _s._lastVideoHeight;
    final br = _s._lastVideoBitrate;
    if (h >= 2160 || br >= 25_000_000) return 16 * 1024 * 1024;
    if ((h > 0 && h < 1080) || (br > 0 && br < 8_000_000)) {
      return 8 * 1024 * 1024;
    }
    return 12 * 1024 * 1024;
  }

}
