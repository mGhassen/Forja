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
            // Also clear ATV source/channel reseat "Switching to …".
            if (_s._retryAttempt > 0 ||
                _s._lastRecoveryAt != null ||
                (_s._statusBanner?.startsWith('Switching to') ?? false)) {
              _s._statusBanner = null;
            }
          });
        } else {
          _s._buffering = false;
        }
        _s._bufferingSince = null;
        _s._bufferingClearAt = null;
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
          _s._clearDeadSurfaceCover();
          _s._readyNotPlayingSince = null;
          _s._bufferingSince = null;
          _s._bufferingClearAt = null;
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
          _s._bufferingClearAt = null;
          _s._bufferingSince ??= DateTime.now();
        } else {
          // Don't zero the 12s wall on a one-tick false — same as MediaKit.
          _s._bufferingClearAt ??= DateTime.now();
        }
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        // Straight off the event: `_buffered` is only assigned when duration > 0.
        _noteFeedProgress(bufMs, positionMs: posMs);
        final pos = Duration(milliseconds: posMs);
        final durChanged =
            durMs > 0 && durMs != _s._duration.inMilliseconds;
        final posChanged = !_s._isSeeking && pos != _s._position;
        if (posChanged || durChanged) {
          if (durMs > 0) {
            // Rebuild when chrome is up, PiP scrubber is shown, or duration
            // first arrives so the VOD seekbar mounts (do not gate duration on
            // position — Exo often reports duration while still at 0:00).
            final needUi =
                _s._controlsVisible || _s._isPipMode || durChanged;
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
        // Gated by cache/feed health inside [_triggerRecovery].
        _triggerRecovery(reason: 'exo ended', forceHard: true);
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'Playback error';
        debugPrint('[IPTV Exo] error: $msg');
        // VOD: Media3 AAC/MP4 extractor deaths ("Source error") are not fixed by
        // reopening Exo — swap to MediaKit once, never hard-loop Exo.
        if (!_livePlaybackProfile &&
            (iptvIsHardOpenFail(msg) ||
                _IptvPtPlayerScreenState._isUnrecognizedFormatError(msg))) {
          if (!_s._formatEngineSwapped) {
            unawaited(_s._autoSwapEngineForFormatError(msg));
            return;
          }
          if (mounted) {
            setState(() => _s._statusBanner = 'Playback failed');
          }
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
      _s._player!.setVolume(
        mpvVolumeForUi(volume, atvMediaKit: _s._atvMediaKit),
      );
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
      // New open may have a different container fps — allow one mode switch.
      _s._displayFrameRateApplied = false;
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

  /// ATV MediaKit: restore ao/mute, pick a real audio track, and ask the TV
  /// for a refresh rate that matches the stream fps (issue 150).
  ///
  /// Do **not** retune `video-sync` / `framedrop` for UHD — known-good 4K
  /// playback (≤v1.3.80) kept `display-resample` + `framedrop=vo` for all
  /// resolutions. The I138 mid-open `video-sync=audio` (+ `framedrop=decoder`)
  /// path is the regression window for 4K process death (issue 155).
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

        // 50/25 fps on a fixed 60 Hz panel judders even when decode is fine.
        // Same window mode switch Exo already uses (ForjaDisplayFrameRate).
        await _applyAtvMediaKitDisplayFrameRate(p);

        if (h >= 2160 || w >= 3840) {
          _startUhdDiagnostics();
        }
        return;
      } catch (e) {
        debugPrint('[IPTV Player] ATV post-open tune failed: $e');
        return;
      }
    }
  }

  /// One HDMI / panel mode switch per open when container fps is known.
  /// Gated by Settings → IPTV match display refresh (default off).
  Future<void> _applyAtvMediaKitDisplayFrameRate(NativePlayer p) async {
    if (_s._displayFrameRateApplied) return;
    final enabled = await SettingsService().getIptvMatchDisplayRefresh();
    if (!enabled) return;
    try {
      final raw = await p.getProperty('container-fps');
      final fps = double.tryParse(raw.toString());
      if (fps == null || fps <= 0 || fps > 130) return;
      _s._displayFrameRateApplied = true;
      await PlatformChannel.applyDisplayFrameRate(fps);
      debugPrint(
        '[IPTV Player] ATV MediaKit display match for ${fps.toStringAsFixed(2)}fps',
      );
    } catch (e) {
      debugPrint('[IPTV Player] ATV display frame-rate match failed: $e');
    }
  }

  /// Periodic UHD telemetry for issue 150 (4K stutter on ATV MediaKit).
  ///
  /// Observe-only while UHD plays with known-good `video-sync=display-resample`
  /// + `framedrop=vo` (issue 155 restored ≤v1.3.80). Debug builds only.
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
        // Headroom for [kAtvMediaKitVolumeGain] — UI 100 asks mpv for 130.
        await p.setProperty('volume-max', '150');
        // Match display refresh — same for HD and UHD (known-good ≤v1.3.80).
        // Do not override to audio-clock on 4K (issue 155 / I138 regression).
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

      // Cache: Live keeps the 30 s / 150 MB window (4K ATV MediaKit ≤v1.3.80).
      // Movies/Series must NOT inherit that — progressive VOD + MediaCodec
      // buffer pools OOM/ANR the process (issue 163 series crash).
      await p.setProperty('cache', 'yes');
      if (_s.widget.vodPlayback) {
        debugPrint('[IPTV Player] MediaKit cache profile=vod (32MiB)');
        await p.setProperty('cache-secs', '10');
        await p.setProperty('demuxer-readahead-secs', '5');
        await p.setProperty('demuxer-max-bytes', '33554432');
        await p.setProperty('demuxer-max-back-bytes', '8388608');
        await p.setProperty('audio-buffer', '0.4');
        // VOD: do not pause-on-empty — progressive + MediaCodec pools (issue 163).
        await p.setProperty('cache-pause', 'no');
        await p.setProperty('cache-pause-initial', 'no');
      } else {
        // Live: pause-to-refill when ahead cache drains — freeze last frame +
        // Buffering instead of chewing demuxer-max-back-bytes (silent replay).
        debugPrint('[IPTV Player] MediaKit cache profile=live (pause-on-empty)');
        await p.setProperty('cache-secs', '30');
        await p.setProperty('demuxer-readahead-secs', '20');
        await p.setProperty('demuxer-max-bytes', '150000000');
        await p.setProperty('demuxer-max-back-bytes', '25000000');
        await p.setProperty('audio-buffer', '1.0');
        await p.setProperty('cache-pause', 'yes');
        await p.setProperty('cache-pause-wait', '3');
        await p.setProperty('cache-pause-initial', 'yes');
      }

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

  /// Live recovery / live-edge profile. Catalog `vodPlayback` wins over URL so
  /// Stalker/M3U movie URLs without `/movie/` still skip live-only paths.
  bool get _livePlaybackProfile {
    if (_s.widget.vodPlayback) return false;
    return _currentSourceIsLive;
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
            (_s._retryAttempt > 0 ||
                _s._lastRecoveryAt != null ||
                (_s._statusBanner?.startsWith('Switching to') ?? false))) {
          _s._statusBanner = null;
        }
      });
      if (p) {
        _s._clearDeadSurfaceCover();
        _s._readyNotPlayingSince = null;
      } else if (_s._userPlayWhenReady) {
        // Soft poke only — live mid-stream never auto-reopens.
        _s._readyNotPlayingSince = DateTime.now();
        if (_s._buffering) return;
        // Live Stable + cache-pause: mpv pauses for refill with playing=false.
        // Do not fight paused-for-cache with play() — detector 3 soft-reopens
        // if the cushion never comes back.
        if (_livePlaybackProfile && _bufferedRecovery) {
          _armTransientHwDecodeIgnore();
          return;
        }
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
        _s._bufferingClearAt = null;
        _s._bufferingSince ??= DateTime.now();
        // Pause-to-refill / underrun: VT often one-shots while demuxer refills.
        if (_playbackStarted && _livePlaybackProfile) {
          _armTransientHwDecodeIgnore();
        }
      } else {
        // media_kit `core-idle` flickers. Zeroing [_bufferingSince] here
        // never let the 12s wall (or reconnect 1/8) fire — spinner forever,
        // then MediaCodec ANR. Watchdog finalizes after [_bufferingClearHold].
        _s._bufferingClearAt ??= DateTime.now();
        if (!_playbackStarted && _livePlaybackProfile) {
          _noteVideoFrame(reason: 'buffering done');
        }
        // No mid-stream live-edge snap here. Flushing the cache on every
        // underrun exit throws away the cushion that absorbs the next hiccup,
        // and mpv's own reconnect handles a dropped socket.
      }
    });
    _s._errorSub = player.stream.error.listen((err) {
      final msg = err.toString();
      if (_IptvPtPlayerScreenState._isBenignMpvError(msg)) {
        return;
      }
      debugPrint('[IPTV Player] error: $msg');
      final lower = msg.toLowerCase();
      if (!_s._formatEngineSwapped &&
          !_livePlaybackProfile &&
          iptvIsHardOpenFail(msg)) {
        unawaited(_s._autoSwapEngineForFormatError(msg));
        return;
      }
      if (!_s._formatEngineSwapped &&
          _IptvPtPlayerScreenState._isUnrecognizedFormatError(msg)) {
        unawaited(_s._autoSwapEngineForFormatError(msg));
        return;
      }
      if (lower.contains('ends prematurely') ||
          lower.contains('end of file') ||
          lower.contains('connection reset')) {
        // Cache/feed gate inside recovery — do not reopen if still working.
        _noteSocketTrouble(msg);
        return;
      }
      _triggerRecovery(reason: 'error: $msg');
    });
    _s._logSub = player.stream.log.listen((l) {
      final text = l.text.toLowerCase();
      if (!_s._softwareDecodeForced &&
          (text.contains('hardware accelerator failed') ||
              text.contains('vt decoder cb') ||
              text.contains('output image buffer is null'))) {
        final until = _s._ignoreHwDecodeFailUntil;
        if (until != null && DateTime.now().isBefore(until)) {
          debugPrint(
            '[IPTV Player] ignoring transient hw fail '
            '(socket blip / live-edge / pause-refill)',
          );
          return;
        }
        // Live Stable: CDN chunk close → corrupt TS → VT one-shot is normal.
        // Never hard-fallback to software. Soft reopen still runs if cache
        // stays empty (do not pretend that is "working").
        if (_livePlaybackProfile && _bufferedRecovery) {
          _armTransientHwDecodeIgnore();
          if (_streamWorking) {
            _logHealthyHold('hw decode fail (live hold)');
          } else {
            _logHold('hw decode fail (live hold)', healthy: false);
          }
          return;
        }
        if (_streamWorking) {
          _logHealthyHold('hw decode fail');
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
        _noteSocketTrouble(l.text);
      }
    });
  }

  /// Socket blip: recover only if cache/feed says the stream is dead.
  void _noteSocketTrouble(String what) {
    // VT often one-shots while ffmpeg reconnects after CDN chunk close.
    _armTransientHwDecodeIgnore();
    if (!_bufferedRecovery) {
      _triggerRecovery(reason: 'connection dropped: $what', forceHard: true);
      return;
    }
    if (_streamWorking) {
      _logHealthyHold('socket $what');
      return;
    }
    if (_s._socketTroublePending) return;
    _s._socketTroublePending = true;
    final openedAt = _s._openedAt;
    debugPrint('[IPTV Player] socket trouble ($what) - '
        'allowing ${_IptvPtPlayerScreenState._ffmpegReconnectGrace.inSeconds}s');
    Future.delayed(_IptvPtPlayerScreenState._ffmpegReconnectGrace, () async {
      _s._socketTroublePending = false;
      if (!mounted || _s._disposed || !_s._userPlayWhenReady) return;
      if (_s._openedAt != openedAt) return;
      if (_streamWorking) {
        _logHealthyHold('socket after grace');
        return;
      }
      await _triggerRecovery(
          reason: 'socket dead, cache empty: $what', forceHard: true);
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
  int _openEpoch = 0;

  bool get _atvHardReseatStreams =>
      !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;

  Future<void> _openCurrent({
    bool hardRecreate = false,
    String? switchingLabel,
  }) async {
    // Serialize opens — Player-menu switch sets _playerReady before the first
    // open finishes; a second open (reload) on a busy mpv ANRs ATV.
    // Latest epoch wins: waiting for an in-flight open must still apply the
    // newest source/channel (rapid Source taps used to drop the new URL).
    final epoch = ++_openEpoch;
    final existing = _openInFlight;
    if (existing != null) {
      await existing;
    }
    if (_s._disposed || epoch != _openEpoch) return;

    final gate = Completer<void>();
    _openInFlight = gate.future;
    try {
      if (hardRecreate && _atvHardReseatStreams) {
        await _reseatAtvPlayerForNewStream(switchingLabel: switchingLabel);
        if (_s._disposed || epoch != _openEpoch) return;
      }
      final src = _s._sources[_s._sourceIdx];
      _playbackStarted = false;
      _s._exoSurfaceFallback?.resetForNewOpen();
      // Soft path: silent connect (buffering chrome only). Hard ATV reseat
      // already set "Switching to …" on the loading scaffold.
      try {
        await _engineOpenSource(src);
        if (_s._disposed || epoch != _openEpoch) return;
        _s._userPlayWhenReady = true;
        _s._pausedAt = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        _resetDemuxerProbe();
        unawaited(_probeStreamCapabilities().then((_) {
          if (mounted && _livePlaybackProfile) _scheduleJumpToLive();
        }));
        // Clear banner after a short successful run (do not require !_buffering —
        // Exo live prefetch used to keep isLoading true and leave reconnect UI up).
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || epoch != _openEpoch) return;
          if (_s._statusBanner == null) return;
          if (_s._playing &&
              (_s._lastPos > Duration.zero || !_s._buffering)) {
            setState(() => _s._statusBanner = null);
          }
        });
      } catch (e) {
        if (epoch != _openEpoch) return;
        _triggerRecovery(reason: 'open failed: $e');
      }
    } finally {
      gate.complete();
      if (identical(_openInFlight, gate.future)) {
        _openInFlight = null;
      }
    }
  }

  /// ATV source/channel change: full surface unmount + same-engine boot.
  /// Soft [ExoPlayerBridge.open] / [Player.open] alone often leaves MediaCodec
  /// black until the user switches Player (which already reseats).
  ///
  /// UI: existing `!_playerReady` loading scaffold + status banner — same as
  /// Player-menu engine switch, not a separate loading route.
  /// [switchingLabel] overrides the banner (channel name on zap; default =
  /// source/portal label for Source menu + failover).
  Future<void> _reseatAtvPlayerForNewStream({String? switchingLabel}) async {
    final trimmed = switchingLabel?.trim();
    final label = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : (_s._sources.isNotEmpty
            ? _s._sources[_s._sourceIdx].label
            : 'stream');
    if (mounted) {
      setState(() {
        _s._playerReady = false;
        _s._statusBanner = 'Switching to $label…';
      });
    }
    await WidgetsBinding.instance.endOfFrame;
    if (_s._disposed || !mounted) return;

    await _releaseEngineForHotSwap();
    if (_s._disposed || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_s._disposed || !mounted) return;

    if (_s._exoBackend) {
      await MpvExclusiveSession.instance.prepareForVideoPlayer(
        timeout: const Duration(milliseconds: 1200),
      );
      if (_s._disposed || !mounted) return;
      _s._exoViewId = _IptvPtPlayerScreenState._nextExoViewId++;
      _s._exoSurfaceFallback?.dispose();
      _s._exoSurfaceFallback = ExoAtvSurfaceFallback(
        enabled: false,
        onFallback: _reopenAfterExoSurfaceFallback,
      );
      _s._exoEventSub =
          ExoPlayerBridge.eventsFor(_s._exoViewId!).listen(_onExoEvent);
      if (mounted) setState(() => _s._playerReady = true);
      await Future<void>.delayed(Duration.zero);
      return;
    }

    await MpvExclusiveSession.instance.prepareForVideoPlayer(
      timeout: !kIsWeb && Platform.isAndroid
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 5),
    );
    if (_s._disposed || !mounted) return;
    _initPlayerInstances();
    await _applyMpvTunables();
    if (_s._disposed || !mounted) return;
    if (mounted) setState(() => _s._playerReady = true);
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
    // Classic (1.3.114): soft reopen only — no mid-stream drop-buffers.
    if (!_bufferedRecovery) {
      await _openCurrent();
      return;
    }
    if (!_s._exoBackend && _s._playerAlive && _livePlaybackProfile) {
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
    await _triggerRecovery(
      reason: 'manual reload stalled',
      forceHard: true,
      userInitiated: true,
    );
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
    if (!_livePlaybackProfile) return;
    // Classic: seekable-only open snap (1.3.114). Never force drop-buffers.
    final allowForce = _bufferedRecovery && force;
    if (!allowForce && !_s._streamSeekable) return;
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted || _s._disposed) return;
      if (!allowForce && !_s._streamSeekable) return;
      try {
        final p = _s._player?.platform;
        if (p is! NativePlayer) return;

        debugPrint('[IPTV Player] live-edge snap (force=$allowForce)');
        // Drop any data that piled up while paused / mid-recovery, then
        // jump to the live edge of the DVR window.
        _armTransientHwDecodeIgnore();
        await p.command(['drop-buffers']);
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

  /// Sample cache health every watchdog tick (MediaKit).
  ///
  /// `demuxer-cache-duration` = seconds of media already downloaded ahead of
  /// the playhead — when mpv reports a sane value. Live MPEG-TS PTS jumps can
  /// spike this into hours; those samples are discarded so Stable recovery
  /// does not treat a dead socket as "working".
  void _sampleDemuxerProgress() {
    if (!_bufferedRecovery) return;
    if (_s._exoBackend || _s._cacheProbeInFlight) return;
    final p = _s._player?.platform;
    if (p is! NativePlayer) return;
    _s._cacheProbeInFlight = true;
    unawaited(() async {
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
    }().timeout(const Duration(seconds: 4), onTimeout: () {
      _s._cacheProbeInFlight = false;
    }));
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

  bool get _playheadRecentlyMoved =>
      _s._playing &&
      DateTime.now().difference(_s._lastPosChange) < const Duration(seconds: 2);

  /// 12s Buffering + frozen playhead + weak cache ⇒ treat as dead for Stable.
  /// Do **not** trip while demuxer still has a healthy ahead cushion — that is
  /// normal `cache-pause` refill (freeze frame + Buffering), not a dead feed.
  bool get _bufferingHardWall {
    final since = _s._bufferingSince;
    if (since == null) return false;
    if (_playheadRecentlyMoved) return false;
    if (_s._cacheAheadSecs >=
        _IptvPtPlayerScreenState._minHealthyCacheSecs) {
      return false;
    }
    if (_networkStillFeeding) return false;
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
      return;
    }
    if (!mounted) return;
    setState(() {
      _s._buffering = true;
      _s._bufferingClearAt = null;
      _s._bufferingSince ??= now;
    });
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
    if (_s._cacheAheadSecs >=
        _IptvPtPlayerScreenState._minHealthyCacheSecs) {
      return true;
    }
    if (_networkStillFeeding) return true;
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

      if (_s._retryAttempt > 0 &&
          _s._playing &&
          now.difference(_s._lastPosChange) < const Duration(milliseconds: 1500) &&
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
            reason: 'buffering ${now.difference(_s._bufferingSince!).inSeconds}s, '
                'cache empty');
        return;
      }
      // Detector 2: position frozen — only if no cache and not feeding.
      final frozenFor = now.difference(_s._lastPosChange);
      if (_s._userPlayWhenReady &&
          _s._lastPos > Duration.zero &&
          frozenFor > const Duration(milliseconds: 8000)) {
        if (_streamWorking) {
          _logHealthyHold('frozen');
          return;
        }
        _triggerRecovery(
            reason: 'position frozen ${frozenFor.inSeconds}s, cache empty');
        return;
      }
      // Detector 3: silent self-pause.
      // Live Stable + cache-pause: playing=false is normal while refilling.
      // Empty cache → show Buffering, soft-reopen at 5s (no fake "working").
      if (_s._userPlayWhenReady &&
          !_s._playing &&
          _s._readyNotPlayingSince != null) {
        final pausedFor = now.difference(_s._readyNotPlayingSince!);
        if (_livePlaybackProfile && _bufferedRecovery) {
          if (_streamWorking ||
              _networkStillFeeding ||
              _s._cacheAheadSecs >=
                  _IptvPtPlayerScreenState._minHealthyCacheSecs) {
            if (!_s._buffering) _logHealthyHold('self-pause');
            return;
          }
          _ensureBufferingChrome(now);
          if (pausedFor <
              _IptvPtPlayerScreenState._liveEmptyPauseReopen) {
            if (pausedFor.inMilliseconds < 1200) {
              _logHold('self-pause refill', healthy: false);
            }
            return;
          }
          _triggerRecovery(
            reason: 'silent self-pause, cache empty',
          );
          return;
        }
        if (!_s._buffering &&
            pausedFor > const Duration(milliseconds: 3000)) {
          if (_streamWorking) {
            _logHealthyHold('self-pause');
            return;
          }
          _triggerRecovery(
              reason: 'silent self-pause, cache empty', forceHard: true);
          return;
        }
      }
      // Detector 4: cold open hang.
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
    // Stable cache/feed hold is live-only — VOD must not skip recovery after a
    // false "video alive" / open fail (issue 163).
    if (!userInitiated &&
        _livePlaybackProfile &&
        _playbackStarted &&
        _streamWorking) {
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
    _recoveryInFlight = true;
    _s._lastRecoveryAt = now;
    _s._streamSeekable = false;
    debugPrint(
        '[IPTV Watchdog] recovery (#${_s._retryAttempt + 1}, hard=$forceHard'
        '${userInitiated ? ', user' : ''}): $reason '
        '(cache=${_s._cacheAheadSecs.toStringAsFixed(1)}s)');

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
          setState(() => _s._statusBanner =
              'Switching to ${_s._sources[_s._sourceIdx].pickerTitle}…');
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
            setState(() =>
                _s._statusBanner = 'Switching to ${_s._sources[_s._sourceIdx].label}…');
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
        _s._bufferingClearAt = null;
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
      // Busy live mpv: Player.open / stop ANRs ATV (issue 128 T08). Snap first;
      // later attempts get a new Player via [_recreatePlayer] then open.
      final atvMkLive =
          !_s._exoBackend && _s._atvMediaKit && _livePlaybackProfile;
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
      _s._syncTitleToActiveSource();
      final logo = _s._sources[idx].logoUrl?.trim();
      if (logo != null && logo.isNotEmpty) {
        _s._logoUrl = logo;
      }
    });
    await _openCurrent(hardRecreate: _atvHardReseatStreams);
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
    await _openCurrent(
      hardRecreate: _atvHardReseatStreams,
      switchingLabel: ch.name,
    );
  }
}
