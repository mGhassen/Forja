part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerWatchdog on _IptvPtPlayerEngineCore {
  Future<void> _triggerRecovery({
    required String reason,
    bool forceHard = false,
  });
  bool get _livePlaybackProfile;
  void _syncPlaybackBannerVisibility();

  /// Sample cache health every watchdog tick (MediaKit).
  ///
  /// `demuxer-cache-duration` = seconds of media already downloaded ahead of
  /// the playhead — when mpv reports a sane value. Live MPEG-TS PTS jumps can
  /// spike this into hours; those samples are discarded so Stable recovery
  /// does not treat a dead socket as "working".
  void _sampleDemuxerProgress() {
    if (_s._exoBackend) return;

    if (_mediaKitLiveProfile && _s._playing && _shouldSampleLiveFramePulse()) {
      unawaited(_sampleLiveFramePulse());
    }

    if (!_bufferedRecovery || _s._cacheProbeInFlight) return;
    if (!_shouldSampleDemuxerCache()) return;

    final p = _s._player?.platform;
    if (p is! NativePlayer) return;
    _s._cacheProbeInFlight = true;
    _s._lastDemuxerSampleAt = DateTime.now();
    unawaited(
      () async {
        try {
          final aheadRaw = await p.getProperty('demuxer-cache-duration');
          final ahead = double.tryParse(aheadRaw.toString());
          if (ahead != null && ahead.isFinite && ahead >= 0) {
            _applyCacheAheadSample(ahead, source: 'demuxer-cache-duration');
          }
          final timeRaw = await p.getProperty('demuxer-cache-time');
          final t = double.tryParse(timeRaw.toString());
          if (t != null && t.isFinite) {
            _noteFeedProgress((t * 1000).round());
          }
        } catch (_) {
        } finally {
          _s._cacheProbeInFlight = false;
        }
      }().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          _s._cacheProbeInFlight = false;
        },
      ),
    );
  }

  bool _shouldSampleDemuxerCache() {
    final cache = _s._cacheAheadSecs;
    final paintOk = _playheadRecentlyMoved;
    final last = _s._lastDemuxerSampleAt;
    final now = DateTime.now();

    if (_s._buffering || cache < 2 || !paintOk) {
      return true;
    }
    if (cache >= 5 && paintOk) {
      final gap = _s._atvMediaKit
          ? const Duration(seconds: 8)
          : const Duration(seconds: 3);
      if (last != null && now.difference(last) < gap) {
        return false;
      }
      return true;
    }
    if (cache >= 2 && cache < 5 && paintOk) {
      if (last != null && now.difference(last) < const Duration(seconds: 2)) {
        return false;
      }
      return true;
    }
    return true;
  }

  bool _shouldSampleLiveFramePulse() {
    if (!_mediaKitLiveProfile || !_s._playing) return false;
    final frozenFor = DateTime.now().difference(_s._lastPosChange);
    if (frozenFor > const Duration(milliseconds: 1500)) return true;
    if (_s._buffering || _s._cacheAheadSecs < 2) return true;
    if (_s._cacheAheadSecs >= 5 && _playheadRecentlyMoved) return false;
    return false;
  }

  /// Bump playhead-alive only when mpv is still emitting frames.
  ///
  /// Do **not** use `video-bitrate` — it can stay >0 on a frozen VO while
  /// demuxer cache is full (ATV MediaKit silent freeze with ~30s cache).
  Future<void> _sampleLiveFramePulse() async {
    final p = _s._player?.platform;
    if (p is! NativePlayer) return;
    try {
      final fpsRaw = await p.getProperty('estimated-vf-fps');
      final fps = double.tryParse(fpsRaw.toString());
      if (fps != null && fps.isFinite && fps >= 1.0) {
        _s._livePaintMissStreak = 0;
        _noteLivePaintPulse();
      } else {
        _s._livePaintMissStreak++;
      }
    } catch (_) {
      _s._livePaintMissStreak++;
    }
  }

  Future<void> _checkPaintFalseNegative() async {
    if (!_mediaKitLiveProfile || !_s._playing) return;
    final frozenFor = DateTime.now().difference(_s._lastPosChange);
    if (frozenFor < const Duration(seconds: 5)) {
      _s._stallPaintWatchSince = null;
      _s._stallFrameDropBaseline = -1;
      return;
    }
    _s._stallPaintWatchSince ??= DateTime.now();
    final p = _s._player?.platform;
    if (p is! NativePlayer) return;
    try {
      final dropRaw = await p.getProperty('frame-drop-count');
      final drops = int.tryParse(dropRaw.toString()) ?? 0;
      if (_s._stallFrameDropBaseline < 0) {
        _s._stallFrameDropBaseline = drops;
        return;
      }
      if (drops > _s._stallFrameDropBaseline + 2 &&
          _s._cacheAheadSecs >= _IptvPtPlayerScreenState._minHealthyCacheSecs) {
        _s._livePaintMissStreak = 2;
      }
    } catch (_) {}
  }

  void _noteLivePaintPulse() {
    _playbackStarted = true;
    _s._lastPosChange = DateTime.now();
    if (_s._lastPos == Duration.zero) {
      _s._lastPos = const Duration(milliseconds: 1);
    }
    _syncPlaybackBannerVisibility();
  }

  /// Accept only plausible ahead values (see [_maxSaneCacheAheadSecs]).
  void _applyCacheAheadSample(double aheadSecs, {required String source}) {
    if (aheadSecs > _IptvPtPlayerScreenState._maxSaneCacheAheadSecs) {
      debugPrint(
        '[IPTV] ignore absurd $source=${aheadSecs.toStringAsFixed(1)}s '
        '(PTS discontinuity) — not counting as healthy cache',
      );
      // Do not leave a stale healthy cushion after a discontinuity spike.
      _s._cacheAheadSecs = 0;
      return;
    }
    _s._cacheAheadSecs = aheadSecs;
  }

  /// Exo / mpv buffer stream: keep feed mark + approximate ahead when possible.
  ///
  /// [markMs] from media_kit `stream.buffer` is an **absolute** buffer-end
  /// timestamp, not seconds ahead — only derive ahead when [positionMs] is set.
  void _noteFeedProgress(int markMs, {int? positionMs}) {
    if (!_bufferedRecovery) return;
    if (markMs <= 0) return;
    if (_s._feedMarkMs != markMs) {
      _s._feedMarkMs = markMs;
      _s._feedAdvancedAt = DateTime.now();
      // Never bump [_lastPosChange] from feed ticks — demuxer / proxy
      // keepalives advance while mediacodec_embed holds a frozen frame.
    }
    // Exo often reports absolute buffered end; ahead ≈ buffered - position.
    if (positionMs != null && markMs > positionMs) {
      _applyCacheAheadSample(
        (markMs - positionMs) / 1000.0,
        source: 'buffer-end',
      );
    }
  }

  void _resetDemuxerProbe() {
    _s._feedMarkMs = null;
    _s._feedAdvancedAt = null;
    _s._cacheAheadSecs = 0;
    _s._livePaintMissStreak = 0;
    _s._stallFrameDropBaseline = -1;
    _s._stallPaintWatchSince = null;
    _s._lastDemuxerSampleAt = null;
  }

  bool get _networkStillFeeding {
    final at = _s._feedAdvancedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <
        _IptvPtPlayerScreenState._networkAliveWindow;
  }

  /// Stream is working: enough cache to play, or still downloading, or
  /// frames advancing. Auto-recovery must not fire in any of these cases.
  /// Classic mode always returns false so stall timers reopen like 1.3.114.
  /// Stall-reopen (test): ignore cache/feed when buffering/freeze stalled
  /// with no recent playhead — demuxer can still look "healthy" while idle.
  bool get _bufferedRecovery =>
      _s._liveRecoveryMode != SettingsService.iptvLiveRecoveryClassic;

  bool get _stallReopenRecovery =>
      _s._liveRecoveryMode == SettingsService.iptvLiveRecoveryStall;

  /// Live Matches / Forja Live on MediaKit — playhead often stuck at 0 while
  /// HLS paints; do not treat idle position as a frozen feed.
  bool get _mediaKitLiveProfile => _livePlaybackProfile && !_s._exoBackend;

  bool get _playheadRecentlyMoved {
    if (!_s._playing) return false;
    // Position ticks and/or estimated-vf-fps pulse only — never demuxer
    // cache / feed. VO can freeze with a full 30s cushion on ATV MediaKit.
    return DateTime.now().difference(_s._lastPosChange) <
        const Duration(seconds: 2);
  }

  /// 12s Buffering + frozen paint ⇒ treat as dead.
  ///
  /// Stall ON (Xtream Auto): ignore healthy demuxer — VO can freeze with a
  /// full cushion on ATV MediaKit.
  /// Stall OFF (Stalker Auto): healthy cushion still blocks the hard wall.
  bool get _bufferingHardWall {
    final since = _s._bufferingSince;
    if (since == null) return false;
    if (_playheadRecentlyMoved) return false;
    if ((!_mediaKitLiveProfile || !_stallReopenRecovery) &&
        _s._cacheAheadSecs >= _IptvPtPlayerScreenState._minHealthyCacheSecs) {
      return false;
    }
    return DateTime.now().difference(since) >=
        _IptvPtPlayerScreenState._bufferingHardWallDuration;
  }

  void _armTransientHwDecodeIgnore() {
    _s._ignoreHwDecodeFailUntil = DateTime.now().add(
      _IptvPtPlayerScreenState._transientHwDecodeIgnore,
    );
  }

  void _ensureBufferingChrome(DateTime now) {
    if (_s._buffering) {
      _s._bufferingSince ??= now;
      _syncPlaybackBannerVisibility();
      return;
    }
    if (!mounted) return;
    _s._buffering = true;
    _s._bufferingClearAt = null;
    _s._bufferingSince ??= now;
    if (_s._playbackBannerSnapshot != true) {
      _s._playbackBannerSnapshot = null;
      _syncPlaybackBannerVisibility();
    }
  }

  void _logHold(String reason, {required bool healthy}) {
    debugPrint(
      '[IPTV] ${healthy ? 'skip recovery' : 'hold'} ($reason) — '
      '${healthy ? 'working' : 'empty'} '
      '(cache=${_s._cacheAheadSecs.toStringAsFixed(1)}s '
      'feeding=$_networkStillFeeding)',
    );
  }

  void _logHealthyHold(String reason) {
    _logHold(reason, healthy: true);
  }

  /// Sustained underrun / freeze without playhead — treat as dead for stall mode.
  bool get _stallWithoutPlayhead {
    if (!_stallReopenRecovery) return false;
    if (_playheadRecentlyMoved) return false;
    final since = _s._bufferingSince;
    if (since != null) {
      final grace = _s._lastPos > Duration.zero
          ? const Duration(milliseconds: 12000)
          : const Duration(milliseconds: 25000);
      if (DateTime.now().difference(since) > grace) return true;
    }
    if (_s._lastPos > Duration.zero &&
        DateTime.now().difference(_s._lastPosChange) >
            const Duration(milliseconds: 8000)) {
      return true;
    }
    return false;
  }

  bool get _streamWorking {
    if (!_bufferedRecovery) return false;
    if (_stallWithoutPlayhead) return false;
    if (_bufferingHardWall) return false;
    // After cold open: empty demuxer + no feed = dead even if VO still pulses
    // (MediaKit live can keep estimated-fps / playhead ticks while S3 TLS
    // resets and cache sits at 0 — web keeps refetching; we must reopen).
    final openedAt = _s._openedAt;
    final pastColdOpen =
        openedAt != null &&
        DateTime.now().difference(openedAt) >= const Duration(seconds: 8);
    if (pastColdOpen &&
        _s._cacheAheadSecs < 0.5 &&
        !_networkStillFeeding) {
      return false;
    }
    // MediaKit live + stall ON: paint/playhead only (VO freeze with full cache).
    // Stall OFF (Stalker Auto): healthy demuxer still counts — playhead often
    // sits at 0 while TS paints; ignoring cache made Auto feel like stall ON.
    if (_mediaKitLiveProfile) {
      if (_playheadRecentlyMoved) return true;
      if (!_stallReopenRecovery &&
          _s._cacheAheadSecs >=
              _IptvPtPlayerScreenState._minHealthyCacheSecs) {
        return true;
      }
      return false;
    }
    if (_s._cacheAheadSecs >= _IptvPtPlayerScreenState._minHealthyCacheSecs) {
      return true;
    }
    if (_playheadRecentlyMoved) return true;
    return false;
  }

  void _finalizeBufferingClearIfNeeded(DateTime now) {
    final clearAt = _s._bufferingClearAt;
    if (clearAt == null || _s._buffering || _s._bufferingSince == null) {
      return;
    }
    if (now.difference(clearAt) <
        _IptvPtPlayerScreenState._bufferingClearHold) {
      return;
    }
    final since = _s._bufferingSince;
    _s._bufferingSince = null;
    _s._bufferingClearAt = null;
    if (since != null) {
      final ms = now.difference(since).inMilliseconds;
      if (ms >= 500) debugPrint('[IPTV Player] buffering window ${ms}ms');
    }
  }

  void _startWatchdog() {
    _s._watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _s._disposed) return;
      final now = DateTime.now();
      _finalizeBufferingClearIfNeeded(now);
      _sampleDemuxerProgress();
      if (_mediaKitLiveProfile && _s._playing) {
        unawaited(_checkPaintFalseNegative());
      }

      if (_s._statusBanner != null &&
          _s._playing &&
          _s._lastPos > Duration.zero &&
          now.difference(_s._lastPosChange) <
              const Duration(milliseconds: 1500) &&
          _s._lastRecoveryAt != null &&
          now.difference(_s._lastRecoveryAt!) > const Duration(seconds: 2)) {
        if (mounted) setState(() => _s._statusBanner = null);
      }

      if (_s._retryAttempt > 0 &&
          _s._playing &&
          now.difference(_s._lastPosChange) <
              const Duration(milliseconds: 1500) &&
          _s._lastRecoveryAt != null &&
          now.difference(_s._lastRecoveryAt!) >
              _IptvPtPlayerScreenState._healthyStreakNeeded) {
        debugPrint('[IPTV Watchdog] healthy streak - resetting retries');
        _s._retryAttempt = 0;
        _s._lastRecoveryAt = null;
        if (mounted && _s._statusBanner != null) {
          setState(() => _s._statusBanner = null);
        }
      }

      if (_s._socketTroublePending && _bufferedRecovery) return;

      // Detector 1: long buffering — only if cache is empty / not working.
      final bufferGrace = _s._lastPos > Duration.zero
          ? const Duration(milliseconds: 12000)
          : const Duration(milliseconds: 25000);
      if (_s._userPlayWhenReady &&
          _s._bufferingSince != null &&
          now.difference(_s._bufferingSince!) > bufferGrace) {
        if (_streamWorking) {
          _logHealthyHold('buffering');
          return;
        }
        _triggerRecovery(
          reason:
              'buffering ${now.difference(_s._bufferingSince!).inSeconds}s, '
              'cache empty',
        );
        return;
      }
      // Detector 2: position frozen — Exo/VOD only. MediaKit live playhead is
      // often idle at 0 while HLS/TS paints (liveEngine false reopen loops).
      if (!_mediaKitLiveProfile) {
        final frozenFor = now.difference(_s._lastPosChange);
        if (_s._userPlayWhenReady &&
            _s._lastPos > Duration.zero &&
            frozenFor > const Duration(milliseconds: 8000)) {
          if (_streamWorking) {
            _logHealthyHold('frozen');
            return;
          }
          _triggerRecovery(
            reason: 'position frozen ${frozenFor.inSeconds}s, cache empty',
          );
          return;
        }
      } else if (_s._userPlayWhenReady && _s._playing) {
        // Detector 2b: MediaKit live paint stall while still "playing".
        // Stall ON: also reopen on VO freeze with a full demuxer cushion.
        // Stall OFF (Stalker Auto): only empty-cache underrun — do not wipe a
        // healthy cushion when playhead sits at 0.
        if (_playheadRecentlyMoved) {
          _s._livePaintMissStreak = 0;
          return;
        }
        final frozenFor = now.difference(_s._lastPosChange);
        if (frozenFor > const Duration(milliseconds: 1500)) {
          _ensureBufferingChrome(now);
          if (frozenFor >= _IptvPtPlayerScreenState._liveEmptyPauseReopen) {
            if (_s._livePaintMissStreak < 2) return;
            final empty =
                _s._cacheAheadSecs <
                _IptvPtPlayerScreenState._minHealthyCacheSecs;
            if (!empty && !_stallReopenRecovery) {
              _logHealthyHold('paint idle, cache hold');
              return;
            }
            _triggerRecovery(
              reason: empty
                  ? 'live underrun, cache empty'
                  : 'live vo freeze, paint stalled '
                        '(cache=${_s._cacheAheadSecs.toStringAsFixed(1)}s)',
            );
            return;
          }
        }
      }
      // Detector 3: silent self-pause.
      // Live Stable: playing=false with empty cache → Buffering, soft-reopen at 5s.
      // Feed ticks alone must not hold — proxy keepalives fake "alive".
      // (cache-pause refill path removed in I199-T05 — play-through reconnect.)
      if (_s._userPlayWhenReady &&
          !_s._playing &&
          _s._readyNotPlayingSince != null) {
        final pausedFor = now.difference(_s._readyNotPlayingSince!);
        if (_livePlaybackProfile && _bufferedRecovery) {
          if (_streamWorking) {
            if (!_s._buffering) _logHealthyHold('self-pause');
            return;
          }
          // Stall OFF: healthy demuxer still holds (MediaKit Stalker included).
          if (!_stallReopenRecovery &&
              _s._cacheAheadSecs >=
                  _IptvPtPlayerScreenState._minHealthyCacheSecs) {
            if (!_s._buffering) _logHealthyHold('self-pause');
            return;
          }
          _ensureBufferingChrome(now);
          if (pausedFor < _IptvPtPlayerScreenState._liveEmptyPauseReopen) {
            if (pausedFor.inMilliseconds < 1200) {
              _logHold('self-pause refill', healthy: false);
            }
            return;
          }
          _triggerRecovery(reason: 'silent self-pause, cache empty');
          return;
        }
        if (!_s._buffering && pausedFor > const Duration(milliseconds: 3000)) {
          if (_streamWorking) {
            _logHealthyHold('self-pause');
            return;
          }
          _triggerRecovery(
            reason: 'silent self-pause, cache empty',
            forceHard: true,
          );
          return;
        }
      }
      // Detector 4: cold open hang.
      if (_s._userPlayWhenReady &&
          !_playbackStarted &&
          _s._lastPos == Duration.zero &&
          now.difference(_s._openedAt) > const Duration(seconds: 30)) {
        _triggerRecovery(reason: 'no first frame after 30s', forceHard: true);
      }
    });
  }
}
