part of 'iptv_pt_player_screen.dart';

mixin _IptvPtPlayerEngine on State<IptvPtPlayerScreen> {
  _IptvPtPlayerScreenState get _s => this as _IptvPtPlayerScreenState;

  bool get _useSoftwareDecode =>
      _s._softwareDecodeForced ||
      _s._androidMediaKitSafeMode ||
      _s._windowsSoftwareDecode;

  void _initPlayerInstances() {
    _s._videoEpoch++;
    final player = Player(configuration: _IptvPtPlayerScreenState._playerConfiguration);
    _s._player = MpvExclusiveSession.instance.trackPlayer(player);
    // ATV: vo=gpu needs EGL (black / audio-only on leanback). mediacodec_embed
    // paints MediaCodec into the Flutter Surface — same as VOD TvPlayerScreen.
    final atv = _s._atvMediaKit;
    _s._controller = VideoController(
      _s._player!,
      configuration: VideoControllerConfiguration(
        vo: atv ? 'mediacodec_embed' : null,
        enableHardwareAcceleration: atv || !_useSoftwareDecode,
        hwdec: atv
            ? 'mediacodec'
            : (_useSoftwareDecode ? 'no' : 'auto-safe'),
        // Avoid blank video when the surface attaches before mpv negotiates
        // dimensions (common on Android / ATV emulators).
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    _s._playerAlive = true;
    _bind();
  }

  Future<void> _bootPlayer() async {
    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    if (_s._disposed) return;
    _initPlayerInstances();
    if (mounted) setState(() => _s._playerReady = true);
    await _applyMpvTunables();
    await _openCurrent();
    _startWatchdog();
    _s._scheduleHideControls();
    _s._focusPlayerChrome();
  }

  Future<void> _bootExoPlayer() async {
    _s._exoViewId = _IptvPtPlayerScreenState._nextExoViewId++;
    _s._exoEventSub = ExoPlayerBridge.eventsFor(_s._exoViewId!).listen(_onExoEvent);
    if (mounted) setState(() => _s._playerReady = true);
    // Let ExoPlayerView attach before open() - same frame-delay as ExoPlayerScreen.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _s._disposed) return;
    await _openCurrent();
    _startWatchdog();
    _s._scheduleHideControls();
    _s._focusPlayerChrome();
  }

  void _onExoEvent(Map<dynamic, dynamic> event) {
    if (_s._disposed || !mounted) return;
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'ready':
        setState(() => _s._buffering = false);
        _s._bufferingSince = null;
        if (!_playbackStarted) {
          _playbackStarted = true;
        }
        break;
      case 'playing':
        final playing = event['value'] == true;
        setState(() => _s._playing = playing);
        if (playing) {
          _s._readyNotPlayingSince = null;
          _s._bufferingSince = null;
        } else if (_s._userPlayWhenReady) {
          _s._readyNotPlayingSince = DateTime.now();
        }
        break;
      case 'buffering':
        final buffering = event['value'] == true;
        setState(() => _s._buffering = buffering);
        if (buffering) {
          _s._bufferingSince ??= DateTime.now();
        } else {
          _s._bufferingSince = null;
        }
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final pos = Duration(milliseconds: posMs);
        if (!_s._isSeeking && pos != _s._position) {
          if (durMs > 0) {
            setState(() {
              _s._position = pos;
              _s._duration = Duration(milliseconds: durMs);
            });
          } else {
            _s._position = pos;
          }
        }
        if (pos != _s._lastPos) {
          _s._lastPos = pos;
          _s._lastPosChange = DateTime.now();
        }
        break;
      case 'ended':
        setState(() => _s._playing = false);
        _triggerRecovery(reason: 'exo ended', forceHard: true);
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'Playback error';
        debugPrint('[IPTV Exo] error: $msg');
        _triggerRecovery(reason: 'exo error: $msg', forceHard: true);
        break;
    }
  }

  bool _playbackStarted = false;

  Future<void> _enginePlay() async {
    if (_s._exoBackend) {
      await ExoPlayerBridge.play(_s._exoViewId!);
    } else {
      await _s._player!.play();
    }
  }

  Future<void> _enginePause() async {
    if (_s._exoBackend) {
      await ExoPlayerBridge.pause(_s._exoViewId!);
    } else {
      await _s._player!.pause();
    }
  }

  Future<void> _engineSeek(Duration target) async {
    if (_s._exoBackend) {
      await ExoPlayerBridge.seekTo(_s._exoViewId!, target);
    } else {
      await _s._player!.seek(target);
    }
  }

  void _engineSetVolume(double volume) {
    if (_s._exoBackend) {
      unawaited(ExoPlayerBridge.setVolume(_s._exoViewId!, volume / 100.0));
    } else {
      _s._player!.setVolume(volume);
    }
  }

  Future<void> _engineOpenSource(IptvPlaySource src) async {
    if (_s._exoBackend) {
      await ExoPlayerBridge.stop(_s._exoViewId!);
      await ExoPlayerBridge.open(
        viewId: _s._exoViewId!,
        url: src.url,
        headers: const {'User-Agent': _IptvPtPlayerScreenState._ua},
        // Live Xtream/M3U: native Exo applies live LoadControl + ATV/API<26 caps.
        // Movies/series VOD keep the default VOD path (Home movies are unchanged).
        live: iptvExoUrlLooksLive(src.url),
      );
    } else {
      await _s._player!.open(
        Media(src.url, httpHeaders: const {'User-Agent': _IptvPtPlayerScreenState._ua}),
      );
      await _s._player!.play();
    }
    // Re-apply after every open/recreate - media_kit resets to 100, and
    // mute is volume=0 in Dart state only.
    _engineSetVolume(_s._volume);
  }

  Future<void> _applyMpvTunables() async {
    try {
      final p = _s._player?.platform;
      if (p is! NativePlayer) return;

      // Prefer safe GPU decode with software fallback - raw `auto` can stick on
      // a broken VideoToolbox session on macOS (black texture, audio OK).
      // ATV MediaKit: pin mediacodec (matches VideoControllerConfiguration).
      if (_s._atvMediaKit) {
        await p.setProperty('hwdec', 'mediacodec');
      } else {
        await p.setProperty('hwdec', _useSoftwareDecode ? 'no' : 'auto-safe');
      }
      // Direct rendering + D3D11 on Windows live feeds can stick the last
      // frame after the readahead window (~20s) with A/V frozen.
      await p.setProperty('vd-lavc-dr', _useSoftwareDecode ? 'no' : 'yes');
      await p.setProperty('vd-lavc-threads', '0');

      // Network: fail fast so the watchdog can step in
      await p.setProperty('network-timeout', '15');

      // Cache: prioritise SMOOTHNESS over live-edge latency. We aggressively
      // pre-buffer ~30 s of forward data and let mpv hold up to 150 MB so
      // brief upstream hiccups never reach the screen. cache-pause stays
      // OFF - we'd rather let the decoder skip frames than show a spinner.
      await p.setProperty('cache', 'yes');
      await p.setProperty('cache-secs', '30');
      await p.setProperty('demuxer-readahead-secs', '20');
      await p.setProperty('demuxer-max-bytes', '150000000');
      await p.setProperty('demuxer-max-back-bytes', '25000000');
      await p.setProperty('cache-pause', 'no');
      await p.setProperty('cache-pause-initial', 'no');
      // Larger audio buffer too - audio underruns are the most jarring
      // form of buffering on IPTV feeds.
      await p.setProperty('audio-buffer', '1.0');

      await p.setProperty('sub-auto', 'all');
      await p.setProperty('sub-visibility', 'no');

      // Don't quit on EOF / brief disconnect - let us recover
      await p.setProperty('keep-open', 'yes');
      await p.setProperty('keep-open-pause', 'no');

      // HLS: pick best variant
      await p.setProperty('hls-bitrate', 'max');

      // RTSP over TCP - way more reliable on flaky networks
      await p.setProperty('rtsp-transport', 'tcp');

      // Many Xtream panels gate streams on a VLC user-agent
      await p.setProperty('user-agent', _IptvPtPlayerScreenState._ua);

      // FFmpeg reconnect knobs (the proven set from gist + alexishuxley)
      await p.setProperty(
        'stream-lavf-o',
        'reconnect=1,'
            'reconnect_at_eof=1,'
            'reconnect_streamed=1,'
            'reconnect_delay_max=5,'
            'reconnect_on_network_error=1,'
            'reconnect_on_http_error=4xx\\,5xx',
      );

      // MPEG-TS / HLS demux tuning.
      //   probesize=5MB, analyzeduration=5s - big enough for ffmpeg to
      //                                       detect real codec params.
      //   discardcorrupt                    - drop junk packets silently.
      // We deliberately DO NOT set fflags=+nobuffer here. +nobuffer tells
      // ffmpeg to push frames the instant they arrive, which is great for
      // sub-second-latency live but means any upstream jitter ⇒ visible
      // buffer underrun. For IPTV we'd rather have ~1–2 s of demuxer
      // smoothing than a spinner every 30 s.
      // HLS-only options (live_start_index, m3u8_hold_counters, etc.) are
      // intentionally not set - when the stream isn't HLS, libavformat
      // rejects them and mpv prints noisy errors the watchdog mistakes
      // for stream failures.
      await p.setProperty(
        'demuxer-lavf-o',
        'fflags=+discardcorrupt+genpts,'
            'probesize=5000000,'
            'analyzeduration=5000000',
      );
    } catch (e) {
      debugPrint('[IPTV Player] tunables failed: $e');
    }
  }

  Future<void> _initOrientationAndChrome() async {
    // Don't auto-enter fullscreen or force landscape - the player opens in a
    // normal window/portrait, and the user enters fullscreen explicitly via
    // the fullscreen button.
    _s._isFullscreen = false;
  }

  Future<void> _toggleFullscreen() async {
    if (_s._isDesktop) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (isFull) {
          // Leaving fullscreen - also drop maximize so the user gets a real window.
          await windowManager.setFullScreen(false);
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          }
        } else {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          }
          await windowManager.setFullScreen(true);
        }
        if (mounted) setState(() => _s._isFullscreen = !isFull);
      } catch (_) {}
    } else {
      final goFull = !_s._isFullscreen;
      await SystemChrome.setEnabledSystemUIMode(
        goFull ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      await SystemChrome.setPreferredOrientations(
        goFull
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : DeviceOrientation.values,
      );
      if (mounted) setState(() => _s._isFullscreen = goFull);
    }
    _s._scheduleHideControls();
  }

  void _bind() {
    final player = _s._player!;
    _s._posSub = player.stream.position.listen((pos) {
      if (!mounted || _s._disposed) return;
      if (!_s._isSeeking && pos != _s._position) {
        // Don't pump setState on every tick if duration is 0 (pure live).
        if (_s._isVod) {
          setState(() => _s._position = pos);
        } else {
          _s._position = pos;
        }
      }
      if (pos != _s._lastPos) {
        _s._lastPos = pos;
        _s._lastPosChange = DateTime.now();
        // Healthy streak - reset retry count if we've been ticking smoothly
        if (_s._retryAttempt > 0 &&
            DateTime.now().difference(_s._lastPosChange) <
                const Duration(milliseconds: 200) &&
            _s._statusBanner == null) {
          // we'll evaluate streak in watchdog
        }
      }
    });
    _s._durSub = player.stream.duration.listen((dur) {
      if (!mounted || _s._disposed) return;
      if (dur != _s._duration) setState(() => _s._duration = dur);
    });
    _s._bufferSub = player.stream.buffer.listen((buf) {
      if (!mounted || _s._disposed) return;
      _s._buffered = buf;
    });
    _s._playingSub = player.stream.playing.listen((p) {
      if (!mounted || _s._disposed) return;
      setState(() => _s._playing = p);
      if (p) {
        _s._readyNotPlayingSince = null;
      } else if (_s._userPlayWhenReady) {
        // libmpv silently went paused while the user wants playback. On a
        // live IPTV stream this is the classic "feed died, mpv hit EOF and
        // toggled pause=yes" symptom. Poke play() once immediately - if it
        // takes, great; if it doesn't, the watchdog will hard-reload us.
        _s._readyNotPlayingSince = DateTime.now();
        Future.microtask(() async {
          if (!mounted || !_s._userPlayWhenReady || _s._playing) return;
          try {
            await _enginePlay();
          } catch (_) {}
        });
      }
    });
    _s._bufferingSub = player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _s._buffering = b);
      if (b) {
        _s._bufferingSince ??= DateTime.now();
      } else {
        _s._bufferingSince = null;
      }
    });
    _s._errorSub = player.stream.error.listen((err) {
      final msg = err.toString();
      // Benign mpv chatter we don't want to restart the stream over:
      //  - "Cannot seek in this stream" / "force-seekable=yes"  → pure-live
      //    stream, the live-edge seek failed (harmless).
      //  - "Expected '=' and a value"                          → libav option
      //    parser warning for HLS-only opts on a non-HLS stream.
      if (_IptvPtPlayerScreenState._isBenignMpvError(msg)) {
        return;
      }
      debugPrint('[IPTV Player] error: $msg');
      // "Stream ends prematurely" / "End of file" on a live HTTP feed means
      // the CDN dropped the TCP connection mid-stream. mpv's reconnect_at_eof
      // only fires on clean EOF, not on premature close, so we have to force
      // a full player recreation to get a fresh socket - gentle seek/reopen
      // attempts will just keep failing on the same dead connection.
      final lower = msg.toLowerCase();
      if (lower.contains('ends prematurely') ||
          lower.contains('end of file') ||
          lower.contains('connection reset')) {
        _triggerRecovery(reason: 'connection dropped: $msg', forceHard: true);
        return;
      }
      _triggerRecovery(reason: 'error: $msg');
    });
    // mpv log stream catches conditions that don't surface as `error`
    // events - most importantly, ffmpeg's "http: Stream ends prematurely"
    // (CDN dropped the TCP connection mid-stream). Without this, the
    // watchdog only sees the resulting position freeze and tries gentle
    // recoveries that can't fix a dead socket.
    _s._logSub = player.stream.log.listen((l) {
      final text = l.text.toLowerCase();
      if (!_s._softwareDecodeForced &&
          (text.contains('hardware accelerator failed') ||
              text.contains('vt decoder cb') ||
              text.contains('output image buffer is null'))) {
        debugPrint('[IPTV Player] hw decode failed - falling back to software');
        unawaited(_forceSoftwareDecode());
        return;
      }
      if (l.level != 'error' && l.level != 'fatal' && l.level != 'warn') {
        return;
      }
      if (text.contains('ends prematurely') ||
          text.contains('end of file') ||
          text.contains('connection reset') ||
          text.contains('connection refused') ||
          text.contains('connection timed out')) {
        debugPrint('[IPTV Player] mpv log: ${l.level} ${l.prefix}: ${l.text}');
        _triggerRecovery(
            reason: 'mpv log: ${l.text}', forceHard: true);
      }
    });
  }

  /// Probe whether mpv reports a seekable DVR window for the current source.
  Future<void> _probeStreamCapabilities() async {
    if (_s._exoBackend) {
      _s._streamSeekable = false;
      return;
    }
    _s._streamSeekable = false;
    try {
      final p = _s._player?.platform;
      if (p is! NativePlayer) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (_s._disposed) return;
      final seekableRaw = await p.getProperty('seekable');
      final durRaw = await p.getProperty('duration');
      final isSeekable = seekableRaw.toString().toLowerCase() == 'yes';
      final dur = double.tryParse(durRaw.toString()) ?? 0.0;
      _s._streamSeekable = isSeekable && dur > 0;
    } catch (_) {
      _s._streamSeekable = false;
    }
  }

  Future<void> _openCurrent() async {
    final src = _s._sources[_s._sourceIdx];
    _playbackStarted = false;
    // Connect silently - no banner. The buffering indicator (if any) will
    // appear naturally while the stream loads.
    try {
      await _engineOpenSource(src);
      _s._userPlayWhenReady = true;
      _s._pausedAt = null;
      _s._lastPos = Duration.zero;
      _s._lastPosChange = DateTime.now();
      _s._openedAt = DateTime.now();
      unawaited(_probeStreamCapabilities().then((_) {
        if (mounted) _scheduleJumpToLive();
      }));
      // Clear banner after a short successful run
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_s._playing && !_s._buffering) {
          setState(() => _s._statusBanner = null);
        }
      });
    } catch (e) {
      _triggerRecovery(reason: 'open failed: $e');
    }
  }

  /// Best-effort jump to the live edge after a (re)open.
  /// Only fires when [_s._streamSeekable] - pure-live MPEG-TS / direct HTTP
  /// feeds must not be seek()'d (mpv prints noisy errors and it can't help).
  void _scheduleJumpToLive() {
    if (_s._exoBackend || !_s._streamSeekable) return;
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted || !_s._streamSeekable) return;
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        // Drop any data that piled up while paused / mid-recovery, then
        // jump to the live edge of the DVR window.
        await p.command(['drop-buffers']);
        await p.command(['seek', '99999', 'absolute']);
      } catch (_) {
        // Best-effort - ignore.
      }
    });
  }

  void _startWatchdog() {
    _s._watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _s._disposed) return;
      final now = DateTime.now();

      // Healthy streak resets retry counter
      if (_s._retryAttempt > 0 &&
          _s._playing &&
          !_s._buffering &&
          now.difference(_s._lastPosChange) < const Duration(milliseconds: 1500) &&
          _s._lastRecoveryAt != null &&
          now.difference(_s._lastRecoveryAt!) > _IptvPtPlayerScreenState._healthyStreakNeeded) {
        debugPrint('[IPTV Watchdog] healthy streak - resetting retries');
        _s._retryAttempt = 0;
        _s._lastRecoveryAt = null;
        if (mounted) setState(() => _s._statusBanner = null);
      }

      // Detector 1: long buffering. Mid-stream stalls with a 30 s buffer
      // shouldn't last more than ~10 s; before the first frame, the slow
      // initial connect to a remote `.ts` feed needs more grace.
      final bufferGrace = _s._lastPos > Duration.zero
          ? const Duration(milliseconds: 12000)
          : const Duration(milliseconds: 25000);
      if (_s._userPlayWhenReady &&
          _s._bufferingSince != null &&
          now.difference(_s._bufferingSince!) > bufferGrace) {
        _triggerRecovery(reason: 'buffering > ${bufferGrace.inSeconds}s');
        return;
      }
      // Detector 2: position frozen while user wants playback.
      // Do NOT gate on !_buffering - Windows live feeds often flicker
      // buffering true/false while the last frame is stuck, which resets
      // detector 1's timer and previously left the stream dead forever
      // with no "Reconnecting…" banner.
      // Gate: _lastPos > 0 - avoid false positives before first frame
      // (detector 4 covers that hang).
      if (_s._userPlayWhenReady &&
          _s._lastPos > Duration.zero &&
          now.difference(_s._lastPosChange) > const Duration(milliseconds: 8000)) {
        _triggerRecovery(reason: 'position frozen > 8s');
        return;
      }
      // Detector 3: should be playing but isn't. For LIVE IPTV, a sustained
      // self-pause (mpv flipped to pause=yes on its own) almost always means
      // the upstream feed ended - live TV doesn't end, ever, so this is
      // dead. Skip the gradual seek→reload backoff and go straight to a hard
      // reopen (forceHard:true).
      if (_s._userPlayWhenReady &&
          !_s._playing &&
          _s._readyNotPlayingSince != null &&
          now.difference(_s._readyNotPlayingSince!) >
              const Duration(milliseconds: 3000)) {
        _triggerRecovery(reason: 'silent self-pause > 3s', forceHard: true);
        return;
      }
      // Detector 4: opened but never produced a first frame. The classic
      // "CDN dropped the connection mid-handshake" hang where mpv keeps
      // playing=true, never flips buffering, never errors, just sits there
      // with position=0 forever. None of detectors 1-3 catch this:
      //   • detector 1 needs buffering=true (mpv may not set it)
      //   • detector 2 is gated on _s._lastPos > 0
      //   • detector 3 needs playing=false (mpv stays true)
      // 30 s is well past the 25 s initial-connect grace in detector 1.
      if (_s._userPlayWhenReady &&
          _s._lastPos == Duration.zero &&
          now.difference(_s._openedAt) > const Duration(seconds: 30)) {
        _triggerRecovery(
            reason: 'no first frame after 30s', forceHard: true);
      }
    });
  }

  bool _recoveryInFlight = false;
  Future<void> _triggerRecovery({
    required String reason,
    bool forceHard = false,
  }) async {
    if (_s._disposed || _recoveryInFlight) return;
    final now = DateTime.now();
    if (_s._lastRecoveryAt != null &&
        now.difference(_s._lastRecoveryAt!) <
            const Duration(milliseconds: 1500)) {
      return; // throttle
    }
    _recoveryInFlight = true;
    _s._lastRecoveryAt = now;
    _s._streamSeekable = false;
    debugPrint(
        '[IPTV Watchdog] recovery (#${_s._retryAttempt + 1}, hard=$forceHard): $reason');

    try {
      if (_s._disposed) return;

      if (_s._retryAttempt >= _IptvPtPlayerScreenState._maxRetries) {
        // Rotate to the next source if we have one.
        if (_s._sourceIdx < _s._sources.length - 1) {
          _s._sourceIdx++;
          _s._retryAttempt = 0;
          if (mounted) {
            setState(() =>
                _s._statusBanner = 'Switching to ${_s._sources[_s._sourceIdx].label}…');
          }
          await _openCurrent();
          return;
        }
        // Single-source channel that won't connect. Don't give up - live
        // streams come back. Wipe the player completely and try again on a
        // long interval so we're not hammering a dead endpoint.
        if (mounted) {
          setState(() => _s._statusBanner =
              'Stream offline - retrying every ${_IptvPtPlayerScreenState._coldRetryInterval.inSeconds}s…');
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
        _s._readyNotPlayingSince = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        return;
      }

      _s._retryAttempt++;
      final delayIdx = (_s._retryAttempt - 1).clamp(0, _s._backoffMs.length - 1);
      final delay = _s._backoffMs[delayIdx];
      // Show what we're doing so the user isn't staring at a frozen spinner.
      if (mounted) {
        setState(() => _s._statusBanner =
            'Reconnecting\u2026 (attempt ${_s._retryAttempt}/${_IptvPtPlayerScreenState._maxRetries})');
      }

      await Future.delayed(Duration(milliseconds: delay));
      if (_s._disposed) return;

      // Hard recreate is expensive and fragile on Windows (unbounded mpv
      // dispose - issue 062). Prefer soft reopen for early stalls; only
      // recreate after several soft failures (or non-Windows forceHard).
      final allowHardRecreate = forceHard &&
          (!_s._windowsSoftwareDecode || _s._retryAttempt > 4);
      if (allowHardRecreate) {
        try {
          if (!await _recreatePlayer()) return;
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] hard recreate failed: $e');
        }
      } else if (_s._retryAttempt <= 2 || (forceHard && _s._windowsSoftwareDecode)) {
        // Seek-to-zero only helps on DVR/HLS windows. Pure-live feeds reject
        // every seek and spam "Cannot seek in this stream" on each recovery.
        if (_s._streamSeekable && !_s._exoBackend) {
          try {
            await _engineSeek(Duration.zero);
          } catch (_) {}
        }
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
        // Recreate
        try {
          if (!await _recreatePlayer()) return;
          await _engineOpenSource(_s._sources[_s._sourceIdx]);
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] recreate failed: $e');
        }
      }
      _s._bufferingSince = null;
      _s._readyNotPlayingSince = null;
      _s._lastPos = Duration.zero;
      _s._lastPosChange = DateTime.now();
      _s._openedAt = DateTime.now();
      unawaited(_probeStreamCapabilities());
    } finally {
      _recoveryInFlight = false;
    }
  }

  Future<void> _forceSoftwareDecode() async {
    if (_s._disposed || _s._exoBackend || _s._softwareDecodeForced) return;
    _s._softwareDecodeForced = true;
    _s._retryAttempt = 0;
    if (mounted) {
      setState(() => _s._statusBanner = 'Switching to software decode…');
    }
    // If a recovery is already running it will pick up the flag on recreate.
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
    await _disposePlayer();
    if (_s._disposed) return false;
    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    if (_s._disposed) return false;
    _initPlayerInstances();
    await _applyMpvTunables();
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

  Future<void> _disposePlayer() async {
    if (_s._exoBackend) {
      await _s._exoEventSub?.cancel();
      _s._exoEventSub = null;
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
    await _cancelPlayerSubscriptions();
    final player = _s._player;
    if (player == null) return;
    MpvExclusiveSession.instance.untrackPlayer(player);
    // Timed stop/dispose - unbounded media_kit teardown freezes Windows.
    final disposeFuture = teardownMediaKitPlayer(player);
    MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
    await disposeFuture;
    _s._player = null;
    _s._controller = null;
  }

  Future<void> _finalizeExit() async {
    while (_recoveryInFlight) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await _disposePlayer();
  }

  void _switchSource(int idx) async {
    if (idx == _s._sourceIdx) return;
    setState(() {
      _s._sourceIdx = idx;
      _s._retryAttempt = 0;
    });
    await _openCurrent();
  }

  Future<void> _switchChannel(IptvGuideChannel ch) async {
    if (ch.id == _s._currentChannelId) return;
    final guide = widget.channelGuide;
    if (guide == null) return;

    String url;
    String label;
    if (ch.xtreamStream != null && guide.xtreamPortal != null) {
      url = IptvClient.streamUrl(guide.xtreamPortal!.portal, ch.xtreamStream!);
      label = guide.xtreamPortal!.displayLabel;
    } else if (ch.playUrl != null && ch.playUrl!.isNotEmpty) {
      url = ch.playUrl!;
      label = _s._sources.isNotEmpty ? _s._sources.first.label : 'M3U';
    } else {
      return;
    }

    final groupName = guide.groupById(ch.groupId)?.name;

    setState(() {
      _s._currentChannelId = ch.id;
      _s._selectedGroupId = ch.groupId;
      _s._sources = [IptvPlaySource(url: url, label: label)];
      _s._sourceIdx = 0;
      _s._retryAttempt = 0;
      _s._title = ch.name;
      _s._logoUrl = ch.logoUrl;
      _s._subtitle = groupName;
    });
    await _openCurrent();
  }
}
