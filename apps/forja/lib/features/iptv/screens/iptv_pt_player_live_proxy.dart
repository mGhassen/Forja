part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerLiveProxy on _IptvPtPlayerEngineCore {
  void _armTransientHwDecodeIgnore();
  Future<void> _enginePlay();
  void _applyCacheAheadSample(double aheadSecs, {required String source});

  void _onProxyUpstreamReconnected() {
    _s._lastProxyReconnectAt = DateTime.now();
    _s._cacheAheadAtProxyReconnect = _s._cacheAheadSecs;
    unawaited(() async {
      if (_s._disposed || _recoveryInFlight) return;
      // Exo reads loopback; LoadControl cushion plays through CDN reopen
      // (no mpv demuxer nudge). MediaKit path below.
      if (_s._exoBackend) {
        debugPrint(
          '[IPTV Proxy] exo play-through reconnect '
          '(ahead=${_s._cacheAheadSecs.toStringAsFixed(1)}s '
          'grace=${_IptvPtPlayerScreenState._proxyReconnectRecoveryGrace.inSeconds}s)',
        );
        return;
      }
      if (!_s._playerAlive) return;
      _armTransientHwDecodeIgnore();
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        var cacheSecs = _s._cacheAheadSecs;
        String avsync = '?';
        String fps = '?';
        try {
          final aheadRaw = await p.getProperty('demuxer-cache-duration');
          final ahead = double.tryParse(aheadRaw.toString());
          if (ahead != null &&
              ahead.isFinite &&
              ahead >= 0 &&
              ahead <= _IptvPtPlayerScreenState._maxSaneCacheAheadSecs) {
            cacheSecs = ahead;
            _applyCacheAheadSample(ahead, source: 'reconnect-probe');
            _s._cacheAheadAtProxyReconnect = ahead;
          }
          final avRaw = await p.getProperty('avsync');
          avsync = avRaw.toString();
          final fpsRaw = await p.getProperty('estimated-vf-fps');
          fps = fpsRaw.toString();
        } catch (_) {}

        final playThrough = cacheSecs >=
            _IptvPtPlayerScreenState._minHealthyCacheSecs;
        if (playThrough) {
          debugPrint(
            '[IPTV Proxy] play-through reconnect '
            '(cache=${cacheSecs.toStringAsFixed(1)}s avsync=$avsync '
            'fps=$fps — no drop-buffers)',
          );
        } else if (_playbackStarted && _s._playerAlive && !_recoveryInFlight) {
          // Empty cushion: watchdog holds during proxy grace while feed
          // refills; soft-reopen only if still dead after grace.
          debugPrint(
            '[IPTV Proxy] empty cache on reconnect — grace refill '
            '(cache=${cacheSecs.toStringAsFixed(1)}s avsync=$avsync '
            'fps=$fps, no drop-buffers)',
          );
        }
        if (_s._userPlayWhenReady && !_s._playing && !_recoveryInFlight) {
          await _enginePlay();
        }
        // +2s / +5s samples for ATV smoke (issue 199 / adaptive skip).
        unawaited(_logProxyReconnectFollowUp(p, after: const Duration(seconds: 2)));
        unawaited(_logProxyReconnectFollowUp(p, after: const Duration(seconds: 5)));
      } catch (e) {
        debugPrint('[IPTV Proxy] reconnect handoff failed: $e');
      }
    }());
  }

  Future<void> _logProxyReconnectFollowUp(
    NativePlayer p, {
    required Duration after,
  }) async {
    await Future<void>.delayed(after);
    if (_s._disposed || !_s._playerAlive) return;
    try {
      final aheadRaw = await p.getProperty('demuxer-cache-duration');
      final avRaw = await p.getProperty('avsync');
      final fpsRaw = await p.getProperty('estimated-vf-fps');
      debugPrint(
        '[IPTV Proxy] reconnect+${after.inSeconds}s '
        'cache=$aheadRaw avsync=$avRaw fps=$fpsRaw',
      );
    } catch (_) {}
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
    // Cover one adaptive skip (≤8 MiB) plus several seconds of play so ATV
    // MediaKit/Exo keep reading during CDN reopen (issue 199 / 233).
    return iptvContinuityProxyMaxQueueBytes(
      videoHeight: _s._lastVideoHeight,
      videoBitrate: _s._lastVideoBitrate,
    );
  }

}
