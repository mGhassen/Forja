part of 'iptv_pt_player_screen.dart';

mixin _IptvPtPlayerEngine on ConsumerState<IptvPtPlayerScreen> {
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
    // Tunables wait for libmpv create. Do not mark ready before that —
    // Player menu → Exo switch would silence with null ctx (issue 115).
    await _applyMpvTunables();
    if (_s._disposed) return;
    if (mounted) setState(() => _s._playerReady = true);
    await _openCurrent();
    _startWatchdog();
    _s._scheduleHideControls();
    _s._focusPlayerChrome();
  }

  Future<void> _bootExoPlayer() async {
    _s._exoViewId = _IptvPtPlayerScreenState._nextExoViewId++;
    _s._exoSurfaceFallback?.dispose();
    _s._exoSurfaceFallback = ExoAtvSurfaceFallback(
      // IPTV Exo is TextureView now (issue 133) — TextureView cannot bind dead,
      // so the SurfaceView watchdog would only fire pointless reopens on a slow
      // first frame. Kept wired for a possible per-device SurfaceView opt-in.
      enabled: false,
      onFallback: _reopenAfterExoSurfaceFallback,
    );
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

  Future<void> _reopenAfterExoSurfaceFallback() async {
    if (_s._disposed || !mounted || _s._sources.isEmpty) return;
    final pos = _s._position;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (_s._disposed || !mounted) return;
    try {
      await _engineOpenSource(_s._sources[_s._sourceIdx]);
      if (pos > Duration.zero && _s._streamSeekable) {
        await ExoPlayerBridge.seekTo(_s._exoViewId!, pos);
      }
    } catch (e) {
      debugPrint('[IPTV Exo] surface fallback reopen failed: $e');
    }
  }

  void _onExoEvent(Map<dynamic, dynamic> event) {
    if (_s._disposed || !mounted) return;
    if (_s._exoSurfaceFallback?.handleNativeEvent(event) == true) {
      return;
    }
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'ready':
        if (_s._buffering || _s._statusBanner != null) {
          setState(() {
            _s._buffering = false;
            // Soft reopen succeeded — drop reconnect UI even if the watchdog
            // healthy streak has not elapsed yet (live isLoading used to block it).
            if (_s._retryAttempt > 0 || _s._lastRecoveryAt != null) {
              _s._statusBanner = null;
            }
          });
        } else {
          _s._buffering = false;
        }
        _s._bufferingSince = null;
        _noteVideoFrame(reason: 'exo ready');
        break;
      case 'playing':
        final playing = event['value'] == true;
        if (playing != _s._playing ||
            (playing && _s._statusBanner != null)) {
          setState(() {
            _s._playing = playing;
            if (playing &&
                (_s._retryAttempt > 0 || _s._lastRecoveryAt != null)) {
              _s._statusBanner = null;
            }
          });
        }
        if (playing) {
          _s._readyNotPlayingSince = null;
          _s._bufferingSince = null;
          // Live Exo often reports position 0 forever while frames paint —
          // keep the watchdog heartbeat alive.
          _noteVideoFrame(reason: 'exo playing');
        } else if (_s._userPlayWhenReady) {
          _s._readyNotPlayingSince = DateTime.now();
        }
        break;
      case 'buffering':
        final buffering = event['value'] == true;
        // Skip no-op setState (ATV Texture/Surface churn hurt perceived FPS).
        if (buffering == _s._buffering) return;
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
        final bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        // Straight off the event: `_buffered` below is only assigned when
        // duration > 0, and live streams never report one.
        _noteFeedProgress(bufMs);
        final pos = Duration(milliseconds: posMs);
        final durChanged =
            durMs > 0 && durMs != _s._duration.inMilliseconds;
        final posChanged = !_s._isSeeking && pos != _s._position;
        if (posChanged || durChanged) {
          if (durMs > 0) {
            // Rebuild when chrome is up, or when duration first arrives so the
            // VOD seekbar mounts (do not gate duration on position — Exo often
            // reports duration while still at 0:00).
            final needUi = _s._controlsVisible || durChanged;
            if (needUi) {
              setState(() {
                if (posChanged) _s._position = pos;
                _s._duration = Duration(milliseconds: durMs);
                if (bufMs > 0) {
                  _s._buffered = Duration(milliseconds: bufMs);
                }
              });
            } else {
              if (posChanged) _s._position = pos;
              _s._duration = Duration(milliseconds: durMs);
              if (bufMs > 0) {
                _s._buffered = Duration(milliseconds: bufMs);
              }
            }
          } else if (posChanged) {
            _s._position = pos;
          }
        }
        if (pos != _s._lastPos) {
          _s._lastPos = pos;
          _s._lastPosChange = DateTime.now();
          if (!_playbackStarted && pos > Duration.zero) {
            _playbackStarted = true;
          }
        } else if (_playbackStarted || _s._playing) {
          // Live Exo: position often stuck at 0 while frames flow — progress
          // ticks still prove the pipeline is alive.
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
        if (!_s._formatEngineSwapped &&
            _IptvPtPlayerScreenState._isUnrecognizedFormatError(msg)) {
          unawaited(_s._autoSwapEngineForFormatError(msg));
          return;
        }
        _triggerRecovery(reason: 'exo error: $msg', forceHard: true);
        break;
      case 'renderedFirstFrame':
        _noteVideoFrame(reason: 'exo first frame');
        break;
      case 'tracksChanged':
        break;
    }
  }

  bool _playbackStarted = false;

  /// Live IPTV (especially Exo) often keeps demuxer position at 0 while video
  /// paints. Mark the stream alive so detector 4 does not hard-recreate after
  /// 30s and ANR the ATV process.
  void _noteVideoFrame({String reason = 'frame'}) {
    final wasCold = !_playbackStarted || _s._lastPos == Duration.zero;
    _playbackStarted = true;
    _s._lastPosChange = DateTime.now();
    if (_s._lastPos == Duration.zero) {
      _s._lastPos = const Duration(milliseconds: 1);
    }
    if (wasCold) {
      debugPrint('[IPTV] video alive ($reason)');
    }
  }

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
      // Soft reopen on the Kotlin side — do not stop+release before open (ANR).
      final live = iptvExoUrlLooksLive(src.url);
      // Opt-in only (Settings → IPTV live max quality). Default 0 = full quality.
      var maxHeight = 0;
      var maxBitrate = 0;
      if (live) {
        maxHeight = await SettingsService().getIptvLiveMaxHeight();
        if (maxHeight > 0) {
          maxBitrate = maxHeight <= 720 ? 3_500_000 : 5_000_000;
        }
      }
      final headers = <String, String>{
        'User-Agent': _IptvPtPlayerScreenState._ua,
        ...src.headers,
      };
      await ExoPlayerBridge.open(
        viewId: _s._exoViewId!,
        url: src.url,
        headers: headers,
        live: live,
        maxVideoHeight: maxHeight,
        maxVideoBitrate: maxBitrate,
      );
    } else {
      final player = _s._player;
      if (player == null) return;
      // Do NOT stop() before first open — virgin mpv stop hangs the UI isolate
      // on ATV (ANR). Live reload uses [_reloadCurrent] (live-edge snap).
      final headers = <String, String>{
        'User-Agent': _IptvPtPlayerScreenState._ua,
        ...src.headers,
      };
      await player.open(
        Media(src.url, httpHeaders: headers),
      );
      await player.play();
      if (_s._atvMediaKit) {
        unawaited(_tuneAtvMediaKitAfterOpen());
      }
    }
    // Re-apply after every open/recreate - media_kit resets to 100, and
    // mute is volume=0 in Dart state only.
    _engineSetVolume(_s._volume);
  }

  /// ATV MediaKit: restore ao/mute, pick a real audio track, and on UHD switch
  /// video-sync to audio-clock so 4K@50 does not starve sound (HD keeps
  /// display-resample from [_applyMpvTunables]).
  Future<void> _tuneAtvMediaKitAfterOpen() async {
    if (_s._disposed || _s._exoBackend || !_s._atvMediaKit) return;
    final player = _s._player;
    final p = player?.platform;
    if (player == null || p is! NativePlayer) return;

    try {
      await p.setProperty('ao', 'audiotrack');
      await p.setProperty('mute', 'no');
      _engineSetVolume(_s._volume);
    } catch (e) {
      debugPrint('[IPTV Player] ATV ao restore failed: $e');
    }

    for (var i = 0; i < 24; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_s._disposed || _s._exoBackend || !_s._atvMediaKit) return;
      if (!identical(_s._player, player)) return;

      try {
        final tracks = player.state.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
        final current = player.state.track.audio;
        if (tracks.isNotEmpty &&
            (current.id == 'auto' || current.id == 'no')) {
          await player.setAudioTrack(tracks.first);
        }

        final h = int.tryParse((await p.getProperty('height')).toString()) ?? 0;
        final w = int.tryParse((await p.getProperty('width')).toString()) ?? 0;
        if (h <= 0 && w <= 0) continue;

        final isUhd = h >= 2160 || w >= 3840;
        if (isUhd) {
          // Audio clock on 4K — display-resample + framedrop=vo can leave
          // picture OK with silent / starved ao on leanback.
          await p.setProperty('video-sync', 'audio');
          await p.setProperty('framedrop', 'decoder');
          await p.setProperty('mute', 'no');
          _engineSetVolume(_s._volume);
          debugPrint('[IPTV Player] ATV MediaKit UHD → video-sync=audio');
          _startUhdDiagnostics();
        }
        return;
      } catch (e) {
        debugPrint('[IPTV Player] ATV post-open tune failed: $e');
        return;
      }
    }
  }

  /// Periodic UHD telemetry for issue 150 (4K stutter on ATV MediaKit).
  ///
  /// The UHD branch above swaps in `video-sync=audio` + `framedrop=decoder` to
  /// keep audio alive (issue 138), and both cost motion smoothness. These
  /// counters say which one is actually hurting: pre-decode drops show up in
  /// `decoder-frame-drop-count`, VO drops in `frame-drop-count`, and a cadence
  /// mismatch shows as `container-fps` ≠ `display-fps` with both counts flat.
  ///
  /// Debug builds only — this polls nine properties every 5 s.
  void _startUhdDiagnostics() {
    if (!kDebugMode || _s._uhdDiag != null) return;
    const props = <String>[
      'container-fps',
      'display-fps',
      'estimated-vf-fps',
      'avsync',
      'frame-drop-count',
      'decoder-frame-drop-count',
      'video-bitrate',
      'demuxer-cache-duration',
      'hwdec-current',
    ];
    _s._uhdDiag = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!mounted || _s._disposed || _s._exoBackend) {
        t.cancel();
        _s._uhdDiag = null;
        return;
      }
      final p = _s._player?.platform;
      if (p is! NativePlayer) return;
      final out = <String>[];
      for (final k in props) {
        try {
          out.add('$k=${await p.getProperty(k)}');
        } catch (_) {
          // Property missing on this build — keep the rest of the line.
        }
      }
      if (out.isNotEmpty) debugPrint('[IPTV UHD] ${out.join(' ')}');
    });
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
        // Default audio device — silenceMediaKitPlayer sets ao=null on exit;
        // a soft reopen must not stay muted/null. audiotrack is Android's ao.
        await p.setProperty('ao', 'audiotrack');
        await p.setProperty('mute', 'no');
        // Match display refresh — smoother than audio-clock sync on leanback.
        // UHD overrides to audio-clock in [_tuneAtvMediaKitAfterOpen] (issue 138).
        await p.setProperty('video-sync', 'display-resample');
        await p.setProperty('framedrop', 'vo');
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

  bool get _currentSourceIsLive {
    if (_s._sources.isEmpty) return true;
    return iptvExoUrlLooksLive(_s._sources[_s._sourceIdx].url);
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
        if (!_playbackStarted && pos > Duration.zero) {
          _playbackStarted = true;
        }
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
      _noteFeedProgress(buf.inMilliseconds);
    });
    _s._playingSub = player.stream.playing.listen((p) {
      if (!mounted || _s._disposed) return;
      setState(() {
        _s._playing = p;
        if (p &&
            _s._statusBanner != null &&
            (_s._retryAttempt > 0 || _s._lastRecoveryAt != null)) {
          _s._statusBanner = null;
        }
      });
      if (p) {
        _s._readyNotPlayingSince = null;
      } else if (_s._userPlayWhenReady) {
        // libmpv silently went paused while the user wants playback. On a
        // live IPTV stream this is the classic "feed died, mpv hit EOF and
        // toggled pause=yes" symptom. Skip while buffering — cache-pause
        // legitimately pauses on underrun; fighting it with play() just
        // churns. Poke play() once when not buffering; if it doesn't take,
        // the watchdog will hard-reload us.
        _s._readyNotPlayingSince = DateTime.now();
        if (_s._buffering) return;
        Future.microtask(() async {
          if (!mounted || !_s._userPlayWhenReady || _s._playing) return;
          if (_s._buffering) return;
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
        final since = _s._bufferingSince;
        _s._bufferingSince = null;
        if (since != null) {
          final ms = DateTime.now().difference(since).inMilliseconds;
          if (ms >= 500) debugPrint('[IPTV Player] buffering window ${ms}ms');
        }
        if (!_playbackStarted) {
          _noteVideoFrame(reason: 'buffering done');
        }
        // No mid-stream live-edge snap here. Flushing the cache on every
        // underrun exit throws away the cushion that absorbs the next hiccup,
        // and mpv's own reconnect handles a dropped socket.
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
      if (!_s._formatEngineSwapped &&
          _IptvPtPlayerScreenState._isUnrecognizedFormatError(msg)) {
        unawaited(_s._autoSwapEngineForFormatError(msg));
        return;
      }
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
        final until = _s._ignoreHwDecodeFailUntil;
        if (until != null && DateTime.now().isBefore(until)) {
          debugPrint(
            '[IPTV Player] ignoring transient hw fail after live-edge snap',
          );
          return;
        }
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

  Future<void>? _openInFlight;

  Future<void> _openCurrent() async {
    // Serialize opens — Player-menu switch sets _playerReady before the first
    // open finishes; a second open (reload) on a busy mpv ANRs ATV.
    final existing = _openInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final gate = Completer<void>();
    _openInFlight = gate.future;
    try {
      final src = _s._sources[_s._sourceIdx];
      _playbackStarted = false;
      _s._exoSurfaceFallback?.resetForNewOpen();
      // Connect silently - no banner. The buffering indicator (if any) will
      // appear naturally while the stream loads.
      try {
        await _engineOpenSource(src);
        _s._userPlayWhenReady = true;
        _s._pausedAt = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        _resetDemuxerProbe();
        unawaited(_probeStreamCapabilities().then((_) {
          if (mounted) _scheduleJumpToLive();
        }));
        // Clear banner after a short successful run (do not require !_buffering —
        // Exo live prefetch used to keep isLoading true and leave reconnect UI up).
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (_s._statusBanner == null) return;
          if (_s._playing &&
              (_s._lastPos > Duration.zero || !_s._buffering)) {
            setState(() => _s._statusBanner = null);
          }
        });
      } catch (e) {
        _triggerRecovery(reason: 'open failed: $e');
      }
    } finally {
      gate.complete();
      if (identical(_openInFlight, gate.future)) {
        _openInFlight = null;
      }
    }
  }

  /// Manual reload control: live MediaKit rejoins the edge first, then falls
  /// back to a real reopen only if that did not restore frames.
  ///
  /// An unconditional [Player.open] here ANRs ATV (issue 128 T08) and a
  /// pre-open `stop()` hangs a virgin player (T08 follow-up), so the reopen is
  /// deferred behind [_reloadEscalateAfter] and routed through the recovery
  /// ladder — the same path the watchdog would take on a stalled feed.
  Future<void> _reloadCurrent() async {
    _s._retryAttempt = 0;
    if (!_s._exoBackend && _s._playerAlive && _currentSourceIsLive) {
      final inFlight = _openInFlight;
      if (inFlight != null) await inFlight;
      if (_s._disposed || !_s._playerAlive) return;
      _scheduleJumpToLive(force: true);
      try {
        await _enginePlay();
      } catch (_) {}
      await _escalateReloadIfStalled();
      return;
    }
    await _openCurrent();
  }

  /// The live-edge flush cannot revive a feed whose socket is gone. Give it a
  /// beat, and if the position stream is still frozen, escalate to the reopen
  /// tier of [_triggerRecovery] so the user's Reload actually reconnects.
  Future<void> _escalateReloadIfStalled() async {
    final before = _s._lastPos;
    await Future<void>.delayed(_IptvPtPlayerScreenState._reloadEscalateAfter);
    if (!mounted || _s._disposed || !_s._playerAlive) return;
    if (!_s._userPlayWhenReady) return;
    if (_s._playing && _s._lastPos != before) return;
    debugPrint('[IPTV Player] manual reload did not restore frames - reopening');
    await _triggerRecovery(reason: 'manual reload stalled', forceHard: true);
  }

  /// Best-effort jump to the live edge after a (re)open.
  /// Only fires when [_s._streamSeekable] — pure-live MPEG-TS / direct HTTP
  /// feeds must not be seek()'d (mpv prints noisy errors and it can't help).
  ///
  /// [force] is the Reload button only. Automatic recovery must never flush
  /// mid-stream: dropping the demuxer cache on a realtime feed costs more than
  /// the stall it tries to fix.
  void _scheduleJumpToLive({bool force = false}) {
    if (_s._exoBackend) return;
    if (!force && !_s._streamSeekable) return;
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted || _s._disposed) return;
      if (!force && !_s._streamSeekable) return;
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        debugPrint('[IPTV Player] live-edge snap (force=$force)');
        // Drop any data that piled up while paused / mid-recovery, then
        // jump to the live edge of the DVR window.
        _s._ignoreHwDecodeFailUntil =
            DateTime.now().add(const Duration(seconds: 3));
        await p.command(['drop-buffers']);
        if (_s._streamSeekable) {
          await p.command(['seek', '99999', 'absolute']);
        }
        if (force && _s._userPlayWhenReady && !_s._playing) {
          await _enginePlay();
        }
      } catch (_) {
        // Best-effort - ignore.
      }
    });
  }

  /// Sample mpv's `demuxer-cache-time` so the stall detectors can tell a dead
  /// socket from a feed that is still delivering.
  ///
  /// Fire-and-forget: the watchdog is a synchronous tick and must not await a
  /// property read (a wedged mpv can leave that pending indefinitely). The
  /// detectors read the last sample instead, which is at most one tick stale.
  void _sampleDemuxerProgress() {
    if (_s._exoBackend || _s._cacheProbeInFlight) return;
    final p = _s._player?.platform;
    if (p is! NativePlayer) return;
    _s._cacheProbeInFlight = true;
    unawaited(() async {
      try {
        final raw = await p.getProperty('demuxer-cache-time');
        final t = double.tryParse(raw.toString());
        if (!mounted || _s._disposed || t == null || !t.isFinite) return;
        _noteFeedProgress((t * 1000).round());
      } catch (_) {
        // Property unavailable (Exo, torn-down player) — leave the last sample.
      } finally {
        _s._cacheProbeInFlight = false;
      }
    }()
        // A wedged mpv can leave a property read pending forever. Without this
        // the in-flight guard would latch and the probe would go permanently
        // blind — the exact condition the detectors need it most.
        .timeout(const Duration(seconds: 4), onTimeout: () {
      _s._cacheProbeInFlight = false;
    }));
  }

  /// Record that the buffered end moved, from whichever backend reported it.
  ///
  /// Movement in either direction counts: the mark only changes when the
  /// demuxer is being fed, and a live stream re-anchors it on discontinuities.
  void _noteFeedProgress(int markMs) {
    if (markMs <= 0) return;
    if (_s._feedMarkMs != markMs) {
      _s._feedMarkMs = markMs;
      _s._feedAdvancedAt = DateTime.now();
      _s._everSawFeed = true;
    }
  }

  /// Clear the probe across a (re)open. A sample carried over from the previous
  /// socket would otherwise vouch for a feed that no longer exists.
  void _resetDemuxerProbe() {
    _s._feedMarkMs = null;
    _s._feedAdvancedAt = null;
    _s._everSawFeed = false;
  }

  /// Whether the feed advanced recently enough to be called alive.
  bool get _networkStillFeeding {
    final at = _s._feedAdvancedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <
        _IptvPtPlayerScreenState._networkAliveWindow;
  }

  /// How long a frozen picture is tolerated before recovery. When the probe has
  /// never reported (blind backend), stay patient enough to outlast a refill of
  /// the 30 s cache rather than falling back to the old 8 s trigger.
  Duration get _freezeGrace => _s._everSawFeed
      ? const Duration(milliseconds: 8000)
      : _IptvPtPlayerScreenState._blindFreezeGrace;

  /// Trace a suppressed recovery once every 5 s so a stall that rides through
  /// is visible in logs — without this the gate is indistinguishable from a
  /// detector that simply never fired.
  void _logStallSuppressed(String kind, Duration held) {
    if (held.inSeconds % 5 != 0) return;
    debugPrint('[IPTV Watchdog] $kind ${held.inSeconds}s - feed alive, '
        'holding (mark=${_s._feedMarkMs}ms)');
  }

  void _startWatchdog() {
    _s._watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _s._disposed) return;
      final now = DateTime.now();
      _sampleDemuxerProgress();

      // Drop reconnect UI as soon as frames are moving again. Do not gate on
      // !_buffering — Exo live used to report isLoading=true while playing,
      // which left "Reconnecting… (1/8)" stuck forever.
      if (_s._statusBanner != null &&
          _s._playing &&
          _s._lastPos > Duration.zero &&
          now.difference(_s._lastPosChange) <
              const Duration(milliseconds: 1500) &&
          _s._lastRecoveryAt != null &&
          now.difference(_s._lastRecoveryAt!) >
              const Duration(seconds: 2)) {
        if (mounted) setState(() => _s._statusBanner = null);
      }

      // Healthy streak resets retry counter (banner may already be cleared)
      if (_s._retryAttempt > 0 &&
          _s._playing &&
          now.difference(_s._lastPosChange) < const Duration(milliseconds: 1500) &&
          _s._lastRecoveryAt != null &&
          now.difference(_s._lastRecoveryAt!) > _IptvPtPlayerScreenState._healthyStreakNeeded) {
        debugPrint('[IPTV Watchdog] healthy streak - resetting retries');
        _s._retryAttempt = 0;
        _s._lastRecoveryAt = null;
        if (mounted && _s._statusBanner != null) {
          setState(() => _s._statusBanner = null);
        }
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
        // Refilling is not failing. With cache-secs=30 a deep underrun can
        // legitimately buffer past this grace, and reopening mid-refill throws
        // away the data already pulled — the reopen then underruns again.
        final bufferingFor = now.difference(_s._bufferingSince!);
        if (_networkStillFeeding &&
            bufferingFor < _IptvPtPlayerScreenState._feedingWedgeCeiling) {
          _logStallSuppressed('buffering', bufferingFor);
          return;
        }
        _triggerRecovery(
            reason: 'buffering ${bufferingFor.inSeconds}s, feed stalled');
        return;
      }
      // Detector 2: position frozen while user wants playback.
      // Do NOT gate on !_buffering alone - Windows live feeds often flicker
      // buffering true/false while the last frame is stuck, which resets
      // detector 1's timer and previously left the stream dead forever
      // with no "Reconnecting…" banner.
      // Gate: _lastPos > 0 - avoid false positives before first frame
      // (detector 4 covers that hang).
      // Live MediaKit: snap to the edge first — soft reopen looks like a
      // long freeze (desktop) and can ANR on ATV.
      final frozenFor = now.difference(_s._lastPosChange);
      if (_s._userPlayWhenReady &&
          _s._lastPos > Duration.zero &&
          frozenFor > _freezeGrace) {
        // A frozen position is not evidence of a dead stream: mpv is allowed to
        // buffer 30 s, so any upstream hiccup longer than the grace used to
        // force a reopen and raise "Reconnecting…" on a feed that was
        // recovering on its own. Only recover once the feed has actually gone
        // quiet, or it keeps flowing while the picture stays stuck (wedged
        // decoder — a reopen is the only thing that clears that).
        if (_networkStillFeeding &&
            frozenFor < _IptvPtPlayerScreenState._feedingWedgeCeiling) {
          _logStallSuppressed('frozen', frozenFor);
          return;
        }
        _triggerRecovery(
          reason: _networkStillFeeding
              ? 'picture frozen ${frozenFor.inSeconds}s while feed alive'
              : 'position frozen ${frozenFor.inSeconds}s, feed stalled',
        );
        return;
      }
      // Detector 3: should be playing but isn't. For LIVE IPTV, a sustained
      // self-pause (mpv flipped to pause=yes on its own) almost always means
      // the upstream feed ended - live TV doesn't end, ever, so this is
      // dead. Skip while buffering (cache-pause underrun is not a dead feed).
      // Skip the gradual reopen backoff and go straight to a hard
      // reopen (forceHard:true).
      if (_s._userPlayWhenReady &&
          !_s._playing &&
          !_s._buffering &&
          _s._readyNotPlayingSince != null &&
          now.difference(_s._readyNotPlayingSince!) >
              const Duration(milliseconds: 3000)) {
        // A feed that is still delivering has not "ended" — Exo reports
        // playing=false during a rebuffer and does not always raise its
        // buffering event in time, which turned a routine stall into a hard
        // reconnect three seconds later.
        final pausedFor = now.difference(_s._readyNotPlayingSince!);
        if (_networkStillFeeding &&
            pausedFor < _IptvPtPlayerScreenState._feedingWedgeCeiling) {
          _logStallSuppressed('self-pause', pausedFor);
          return;
        }
        _triggerRecovery(
            reason: 'silent self-pause ${pausedFor.inSeconds}s, feed stalled',
            forceHard: true);
        return;
      }
      // Detector 4: opened but never produced a first frame. The classic
      // "CDN dropped the connection mid-handshake" hang where mpv keeps
      // playing=true, never flips buffering, never errors, just sits there
      // with position=0 forever. None of detectors 1-3 catch this:
      //   • detector 1 needs buffering=true (mpv may not set it)
      //   • detector 2 is gated on _s._lastPos > 0
      //   • detector 3 needs playing=false (mpv stays true)
      // Gate on !_playbackStarted — live Exo often keeps position at 0 while
      // actually painting (ready / renderedFirstFrame / progress heartbeat).
      // 30 s is well past the 25 s initial-connect grace in detector 1.
      if (_s._userPlayWhenReady &&
          !_playbackStarted &&
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
        _resetDemuxerProbe();
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
      // dispose - issue 062) and ANRs ATV (issue 128). Prefer soft reopen for
      // early stalls; only recreate after several soft failures.
      final allowHardRecreate = forceHard &&
          _s._retryAttempt > 2 &&
          (!_s._windowsSoftwareDecode || _s._retryAttempt > 4);
      if (allowHardRecreate) {
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
      final resolved = await IptvClient.resolvePlayUrl(
        guide.xtreamPortal!.portal,
        ch.xtreamStream!,
        section: 'live',
      );
      if (resolved == null || resolved.isEmpty) return;
      url = resolved;
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
    final xtream = ch.xtreamStream;
    if (xtream != null) {
      widget.onChannelChanged?.call(xtream);
    }
    await _openCurrent();
  }
}
