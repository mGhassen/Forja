part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerRecovery on _IptvPtPlayerEngineCore {
  Future<void> _openCurrent({bool hardRecreate = false});
  Future<void> _engineOpenSource(IptvPlaySource src);
  Future<void> _probeStreamCapabilities();
  bool _giveUpDeadStalkerStream();
  void _initPlayerInstances();
  Future<void> _applyMpvTunables();
  Future<void> _enginePlay();
  void _armTransientHwDecodeIgnore();
  void _logHealthyHold(String reason);
  void _resetDemuxerProbe();
  bool get _streamWorking;
  bool get _livePlaybackProfile;
  bool get _bufferedRecovery;
  bool get _atvHardReseatStreams;
  bool get _playheadRecentlyMoved;
  void _noteStalkerHardOpenFail();
  void _invalidatePendingLiveEdgeSnaps();

  void _scheduleJumpToLive({bool force = false}) {
    if (_s._exoBackend) return;
    if (!_livePlaybackProfile) return;
    // Classic: seekable-only open snap (1.3.114). Never force drop-buffers.
    final allowForce = _bufferedRecovery && force;
    if (!allowForce && !_s._streamSeekable) return;
    final epoch = _s._liveEdgeSnapEpoch;
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted || _s._disposed) return;
      if (_s._liveEdgeSnapEpoch != epoch) return;
      if (_recoveryInFlight || !_s._playerAlive) return;
      if (!allowForce && !_s._streamSeekable) return;
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        debugPrint('[IPTV Player] live-edge snap (force=$allowForce)');
        // Drop any data that piled up while paused / mid-recovery, then
        // jump to the live edge of the DVR window.
        _armTransientHwDecodeIgnore();
        await p.command(['drop-buffers']);
        if (_s._liveEdgeSnapEpoch != epoch || _recoveryInFlight) return;
        if (_s._streamSeekable) {
          await p.command(['seek', '99999', 'absolute']);
        }
        if (allowForce && _s._userPlayWhenReady && !_s._playing) {
          await _enginePlay();
        }
      } catch (_) {
        // Best-effort - ignore.
      }
    });
  }

  /// Reopen / recreate only when the stream is **not** working.
  ///
  /// Working = enough demuxer/buffer cache (≥ [_minHealthyCacheSecs]), or
  /// feed still advancing, or playhead recently moved. That is the rule —
  /// not "never recover" and not "timer expired ⇒ dead".
  Future<void> _triggerRecovery({
    required String reason,
    bool forceHard = false,
    bool userInitiated = false,
  }) async {
    if (_s._disposed || _recoveryInFlight) return;
    if (_giveUpDeadStalkerStream()) return;
    // Stable cache/feed hold is live-only — VOD must not skip recovery after a
    // false "video alive" / open fail (issue 163). Hard format/open death
    // must never be held as "working".
    if (!userInitiated &&
        _livePlaybackProfile &&
        _playbackStarted &&
        _streamWorking &&
        !iptvIsHardOpenFail(reason)) {
      _logHealthyHold(reason);
      return;
    }
    // VOD Exo extractor/HTTP death → MediaKit once (don't reopen Exo forever).
    if (!userInitiated &&
        !_livePlaybackProfile &&
        _s._exoBackend &&
        !_s._formatEngineSwapped &&
        iptvIsHardOpenFail(reason)) {
      unawaited(_s._autoSwapEngineForFormatError(reason));
      return;
    }
    if (!userInitiated &&
        !_livePlaybackProfile &&
        _s._exoBackend &&
        _s._formatEngineSwapped &&
        iptvIsHardOpenFail(reason)) {
      if (mounted) {
        setState(() => _s._statusBanner = 'Playback failed');
      }
      return;
    }
    final now = DateTime.now();
    if (_s._lastRecoveryAt != null &&
        now.difference(_s._lastRecoveryAt!) <
            const Duration(milliseconds: 1500)) {
      return;
    }
    // Cancel delayed drop-buffers / seek so they cannot race stop+open.
    _invalidatePendingLiveEdgeSnaps();
    if (!userInitiated && iptvIsHardOpenFail(reason)) {
      _noteStalkerHardOpenFail();
      if (_giveUpDeadStalkerStream()) return;
    }
    _recoveryInFlight = true;
    _s._lastRecoveryAt = now;
    _s._streamSeekable = false;
    debugPrint(
      '[IPTV Watchdog] recovery (#${_s._retryAttempt + 1}, hard=$forceHard'
      '${userInitiated ? ', user' : ''}): $reason '
      '(cache=${_s._cacheAheadSecs.toStringAsFixed(1)}s)',
    );

    try {
      if (_s._disposed) return;

      // Multi-source: dead TCP/open → next source immediately. Burning 8
      // retries on skybeyondplus timeouts leaves the user on Buffering forever.
      if (!userInitiated &&
          _s._sources.length > 1 &&
          _s._sourceIdx < _s._sources.length - 1 &&
          iptvIsDeadEndpointFail(reason)) {
        _s._sourceIdx++;
        _s._retryAttempt = 0;
        _s._syncTitleToActiveSource();
        if (mounted) {
          setState(
            () => _s._statusBanner =
                'Switching to ${_s._sources[_s._sourceIdx].pickerTitle}…',
          );
        }
        await _openCurrent(hardRecreate: _atvHardReseatStreams);
        return;
      }

      if (_s._retryAttempt >= _IptvPtPlayerScreenState._maxRetries) {
        // Rotate to the next source if we have one.
        if (_s._sourceIdx < _s._sources.length - 1) {
          _s._sourceIdx++;
          _s._retryAttempt = 0;
          _s._syncTitleToActiveSource();
          if (mounted) {
            setState(
              () => _s._statusBanner =
                  'Switching to ${_s._sources[_s._sourceIdx].label}…',
            );
          }
          await _openCurrent(hardRecreate: _atvHardReseatStreams);
          return;
        }
        // Movies/series: stop after the ladder (no forever cold-retry).
        if (!_livePlaybackProfile) {
          if (mounted) {
            setState(() => _s._statusBanner = 'Playback failed');
          }
          return;
        }
        // Single-source channel that won't connect. Don't give up - live
        // streams come back. Wipe the player completely and try again on a
        // long interval so we're not hammering a dead endpoint.
        if (mounted) {
          setState(
            () => _s._statusBanner =
                'Stream offline - retrying every ${_IptvPtPlayerScreenState._coldRetryInterval.inSeconds}s…',
          );
        }
        await Future.delayed(_IptvPtPlayerScreenState._coldRetryInterval);
        if (_s._disposed) return;
        try {
          if (!await _recreatePlayer()) return;
        } catch (e) {
          debugPrint('[IPTV] cold-retry recreate failed: $e');
        }
        // Reset the retry ladder so the next ladder run gets fresh backoff.
        _s._retryAttempt = 0;
        if (_s._disposed || (!_s._exoBackend && !_s._playerAlive)) return;
        try {
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
        } catch (e) {
          debugPrint('[IPTV] cold-retry open failed: $e');
        }
        if (mounted) setState(() {});
        _s._bufferingSince = null;
        _s._bufferingClearAt = null;
        _s._readyNotPlayingSince = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        _s._playbackBannerSnapshot = null;
        _resetDemuxerProbe();
        return;
      }

      _s._retryAttempt++;
      final delayIdx = (_s._retryAttempt - 1).clamp(
        0,
        _s._backoffMs.length - 1,
      );
      final delay = _s._backoffMs[delayIdx];
      // Show what we're doing so the user isn't staring at a frozen spinner.
      if (mounted) {
        setState(
          () => _s._statusBanner =
              'Reconnecting\u2026 (attempt ${_s._retryAttempt}/${_IptvPtPlayerScreenState._maxRetries})',
        );
      }

      await Future.delayed(Duration(milliseconds: delay));
      if (_s._disposed) return;

      // Hard recreate is expensive and fragile on Windows (unbounded mpv
      // dispose - issue 062) and ANRs ATV (issue 128). Prefer soft reopen for
      // early stalls; only recreate after several soft failures.
      final allowHardRecreate =
          forceHard &&
          _s._retryAttempt > 2 &&
          (!_s._windowsSoftwareDecode || _s._retryAttempt > 4);
      // Busy live mpv: Player.open / stop ANRs ATV (issue 128 T08). Snap first;
      // later attempts get a new Player via [_recreatePlayer] then open.
      final atvMkLive =
          !_s._exoBackend && _s._atvMediaKit && _livePlaybackProfile;
      final voFreeze = reason.contains('live vo freeze');

      if (atvMkLive && voFreeze) {
        if (!_s._voFreezeSnapAttempted) {
          _s._voFreezeSnapAttempted = true;
          _scheduleJumpToLive(force: true);
          try {
            await _enginePlay().timeout(const Duration(milliseconds: 400));
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 2));
          if (_s._disposed) return;
          if (_playheadRecentlyMoved) {
            _s._bufferingSince = null;
            _s._bufferingClearAt = null;
            _s._readyNotPlayingSince = null;
            _s._playbackBannerSnapshot = null;
            if (mounted) setState(() => _s._statusBanner = null);
            return;
          }
        }
        try {
          if (!await _recreatePlayer()) return;
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] VO-freeze recreate failed: $e');
        }
        _s._bufferingSince = null;
        _s._bufferingClearAt = null;
        _s._readyNotPlayingSince = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        _s._playbackBannerSnapshot = null;
        _resetDemuxerProbe();
        return;
      }

      if (atvMkLive && _s._retryAttempt <= 2) {
        _scheduleJumpToLive(force: true);
        try {
          await _enginePlay().timeout(const Duration(milliseconds: 400));
        } catch (_) {}
      } else if (allowHardRecreate || (atvMkLive && _s._retryAttempt > 2)) {
        try {
          if (!await _recreatePlayer()) return;
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] hard recreate failed: $e');
        }
      } else if (_s._retryAttempt <= 2 || forceHard) {
        // Soft reopen — never seek(0) on live (anchors to DVR start / spam).
        // forceHard on attempt 1–2 also soft-reopens (ATV ANR if we recreate).
        try {
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          await _enginePlay();
        } catch (_) {}
      } else if (_s._retryAttempt <= 4) {
        try {
          if (!_s._exoBackend) {
            await _s._player!.stop();
          } else {
            await ExoPlayerBridge.stop(_s._exoViewId!);
          }
        } catch (_) {}
        try {
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
        } catch (_) {}
      } else {
        try {
          if (!await _recreatePlayer()) return;
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] recreate failed: $e');
        }
      }
      _s._bufferingSince = null;
      _s._bufferingClearAt = null;
      _s._readyNotPlayingSince = null;
      _s._lastPos = Duration.zero;
      _s._lastPosChange = DateTime.now();
      _s._openedAt = DateTime.now();
      _s._playbackBannerSnapshot = null;
      _resetDemuxerProbe();
      unawaited(_probeStreamCapabilities());
      // Soft recovery skips [_openCurrent]'s delayed clear — schedule one here
      // so a successful reopen does not leave "Reconnecting…" up forever.
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted || _s._disposed) return;
        if (_s._statusBanner == null) return;
        if (_s._playing &&
            _s._lastPos > Duration.zero &&
            DateTime.now().difference(_s._lastPosChange) <
                const Duration(milliseconds: 2000)) {
          setState(() => _s._statusBanner = null);
        }
      });
    } finally {
      _recoveryInFlight = false;
    }
  }

  Future<void> _forceSoftwareDecode() async {
    if (_s._disposed || _s._exoBackend || _s._softwareDecodeForced) return;
    if (_streamWorking) {
      _logHealthyHold('hw→sw');
      return;
    }
    // ATV MediaKit must stay on MediaCodec. Software decode of FHD/UHD on
    // leanback OOMs / ANRs the process (looks like a 4K-only crash — issue 155).
    // Soft-reopen keeps hwdec=mediacodec; never flip safe-mode / hwdec=no.
    if (_s._atvMediaKit) {
      debugPrint(
        '[IPTV Player] ATV MediaKit: ignore hw→sw — soft reopen on MediaCodec',
      );
      if (_recoveryInFlight) return;
      await _triggerRecovery(
        reason: 'hardware decode failed (ATV keep MediaCodec)',
      );
      return;
    }
    _s._softwareDecodeForced = true;
    _s._retryAttempt = 0;
    if (mounted) {
      setState(() => _s._statusBanner = 'Switching to software decode…');
    }
    if (_recoveryInFlight) return;
    await _triggerRecovery(reason: 'hardware decode failed', forceHard: true);
  }

  Future<bool> _recreatePlayer() async {
    if (_s._exoBackend) {
      try {
        await ExoPlayerBridge.stop(_s._exoViewId!);
      } catch (_) {}
      return !_s._disposed;
    }
    if (mounted) setState(() => _s._playerReady = false);
    await WidgetsBinding.instance.endOfFrame;
    if (_s._disposed) return false;
    if (!kIsWeb && Platform.isAndroid) {
      await _releaseEngineForHotSwap();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_s._disposed) return false;
      await MpvExclusiveSession.instance.prepareForVideoPlayer(
        timeout: const Duration(milliseconds: 1200),
      );
    } else {
      await _disposePlayer();
      if (_s._disposed) return false;
      await MpvExclusiveSession.instance.prepareForVideoPlayer();
    }
    if (_s._disposed) return false;
    _initPlayerInstances();
    await _applyMpvTunables();
    if (_s._disposed) return false;
    if (mounted) setState(() => _s._playerReady = true);
    return true;
  }

  Future<void> _cancelPlayerSubscriptions() async {
    await _s._posSub?.cancel();
    await _s._durSub?.cancel();
    await _s._playingSub?.cancel();
    await _s._bufferingSub?.cancel();
    await _s._errorSub?.cancel();
    await _s._logSub?.cancel();
    await _s._bufferSub?.cancel();
    _s._posSub = null;
    _s._durSub = null;
    _s._playingSub = null;
    _s._bufferingSub = null;
    _s._errorSub = null;
    _s._logSub = null;
    _s._bufferSub = null;
  }

  /// Player-menu Exo ↔ MediaKit: release the current engine after the surface
  /// is unmounted. MediaKit stop+dispose is tracked and **not** awaited here —
  /// same as VOD widget dispose — so the UI isolate is not stuck in FFI past
  /// the ATV ANR window. When switching **to** MediaKit the caller awaits
  /// [MpvExclusiveSession.prepareForVideoPlayer] before create.
  Future<void> _releaseEngineForHotSwap() async {
    if (_s._exoBackend) {
      await _s._exoEventSub?.cancel();
      _s._exoEventSub = null;
      _s._exoSurfaceFallback?.dispose();
      _s._exoSurfaceFallback = null;
      final id = _s._exoViewId;
      _s._exoViewId = null;
      if (id == null) return;
      try {
        await ExoPlayerBridge.pause(id);
      } catch (_) {}
      try {
        await ExoPlayerBridge.dispose(id);
      } catch (_) {}
      return;
    }
    if (!_s._playerAlive) return;
    _s._playerAlive = false;
    _s._uhdDiag?.cancel();
    _s._uhdDiag = null;
    unawaited(PlatformChannel.clearDisplayFrameRate());
    _s._displayFrameRateApplied = false;
    await _cancelPlayerSubscriptions();
    final player = _s._player;
    _s._player = null;
    _s._controller = null;
    if (player == null) return;
    MpvExclusiveSession.instance.untrackPlayer(player);
    // Kill audio immediately; full stop+dispose continues tracked in background.
    await silenceMediaKitPlayer(player);
    final disposeFuture = teardownMediaKitPlayer(player);
    MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
  }

  Future<void> _disposePlayer() async {
    _invalidatePendingLiveEdgeSnaps();
    if (_s._exoBackend) {
      await _s._exoEventSub?.cancel();
      _s._exoEventSub = null;
      _s._exoSurfaceFallback?.dispose();
      _s._exoSurfaceFallback = null;
      if (_s._exoViewId != null) {
        try {
          await ExoPlayerBridge.dispose(_s._exoViewId!);
        } catch (_) {}
      }
      _s._exoViewId = null;
      return;
    }
    if (!_s._playerAlive) return;
    _s._playerAlive = false;
    _s._uhdDiag?.cancel();
    _s._uhdDiag = null;
    unawaited(PlatformChannel.clearDisplayFrameRate());
    _s._displayFrameRateApplied = false;
    await _cancelPlayerSubscriptions();
    final player = _s._player;
    if (player == null) return;
    MpvExclusiveSession.instance.untrackPlayer(player);
    // Timed stop/dispose - unbounded media_kit teardown freezes Windows.
    // [fast]: Android / ATV **exit** path only — MediaCodec + mpv stop/dispose
    // on the UI isolate can exceed the 5s input ANR window (issue 128). Prefer
    // silence + short timeouts after the Video surface is already unmounted.
    // Do **not** use fast for hot-swap / recreate: aborting early leaves a
    // zombie that breaks the next MediaKit open.
    final fast = _s._exitInProgress && !kIsWeb && Platform.isAndroid;
    final disposeFuture = teardownMediaKitPlayer(player, fast: fast);
    MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
    await disposeFuture;
    _s._player = null;
    _s._controller = null;
  }
}
