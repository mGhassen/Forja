part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerEngine on _IptvPtPlayerEngineCore {
  Future<void> _applyMpvTunables();
  Future<void> _tuneAtvMediaKitAfterOpen();
  Future<void> _tuneDesktopMediaKitAfterOpen();
  Future<void> _applyStreamLavfReconnect(NativePlayer p, {required bool continuityProxy});
  int _continuityProxyMaxQueueBytes();
  void _onProxyUpstreamReconnected();
  void _startWatchdog();
  void _noteFeedProgress(int markMs, {int? positionMs});
  Future<void> _triggerRecovery({required String reason, bool forceHard = false, bool userInitiated = false});
  void _armTransientHwDecodeIgnore();
  Future<void> _disposePlayer();
  Future<void> _forceSoftwareDecode();
  Future<void> _releaseEngineForHotSwap();
  void _logHealthyHold(String reason);
  void _logHold(String reason, {required bool healthy});
  void _resetDemuxerProbe();
  void _scheduleJumpToLive({bool force = false});
  void _invalidatePendingLiveEdgeSnaps();
  bool get _streamWorking;
  bool get _bufferedRecovery;

  bool get _useSoftwareDecode =>
      _s._softwareDecodeForced ||
      _s._androidMediaKitSafeMode ||
      _s._windowsSoftwareDecode ||
      _s._desktopLiveSoftwareDecode;

  void _initPlayerInstances() {
    _s._videoEpoch++;
    final player = Player(configuration: _s._mediaKitPlayerConfiguration);
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
      await _engineOpenSource(
        _s._sources[_s._sourceIdx],
        refreshLiveEngine: _s._sources[_s._sourceIdx].canRefreshLiveEngine,
      );
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
          // MediaKit Video re-holds wakelock on playing; Exo must too or ATV
          // Ambient starts after idle (issue 201). Native FLAG is primary.
          unawaited(WakelockPlus.enable());
        } else if (_s._userPlayWhenReady) {
          _s._readyNotPlayingSince = DateTime.now();
        }
        break;
      case 'buffering':
        final buffering = event['value'] == true;
        // Skip no-op setState (ATV Texture/Surface churn hurt perceived FPS).
        if (buffering == _s._buffering) return;
        _s._buffering = buffering;
        if (buffering) {
          _s._bufferingClearAt = null;
          _s._bufferingSince ??= DateTime.now();
        } else {
          // Don't zero the 12s wall on a one-tick false — same as MediaKit.
          _s._bufferingClearAt ??= DateTime.now();
        }
        _s._playbackBannerSnapshot = null;
        _syncPlaybackBannerVisibility();
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
          _syncPlaybackBannerVisibility();
        } else if (_playbackStarted || _s._playing) {
          // Live Exo: position often stuck at 0 while frames flow — progress
          // ticks still prove the pipeline is alive.
          _s._lastPosChange = DateTime.now();
          _syncPlaybackBannerVisibility();
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
      _resetStalkerHardFails();
    }
    _syncPlaybackBannerVisibility();
  }

  /// Live skips setState on every position tick — rebuild when banner visibility
  /// changes (e.g. mpv core-idle while frames still advance).
  void _syncPlaybackBannerVisibility() {
    if (!mounted) return;
    final next = _s._showPlaybackBanner;
    if (_s._playbackBannerSnapshot == next) return;
    _s._playbackBannerSnapshot = next;
    setState(() {});
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

  Future<void> _engineOpenSource(
    IptvPlaySource src, {
    bool refreshLiveEngine = false,
  }) async {
    if (refreshLiveEngine) {
      final refreshed = await _refreshLiveEngineSource(src);
      if (refreshed != null) {
        src = refreshed;
      }
    }
    src = await _refreshStalkerPlayUrl(src);
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
      _s._liveCacheTierApplied = false;
      _s._voFreezeSnapAttempted = false;
      _s._livePaintMissStreak = 0;
      _s._stallFrameDropBaseline = -1;
      _s._stallPaintWatchSince = null;
      final headers = <String, String>{
        'User-Agent': _IptvPtPlayerScreenState._ua,
        ...src.headers,
      };
      var playUrl = src.url;
      final kind = _liveSourceKindFor(src);
      // Live MediaKit: Xtream TS uses the localhost continuity relay; Stremio /
      // engine plugins open directly with their own headers + lavf reconnect.
      if (_livePlaybackProfile && kind.useContinuityProxy) {
        final proxy = _s._liveContinuityProxy ??= IptvLiveContinuityProxy(
          onUpstreamReconnected: _onProxyUpstreamReconnected,
        );
        final local = await proxy.start(
          upstreamUrl: src.url,
          headers: headers,
          maxQueueBytes: _continuityProxyMaxQueueBytes(),
        );
        playUrl = local.toString();
        debugPrint('[IPTV Player] continuity proxy ($kind, lavf=off)');
        await player.open(Media(playUrl));
        final np = player.platform;
        if (np is NativePlayer) {
          await _applyStreamLavfReconnect(np, continuityProxy: true);
        }
      } else {
        await _s._liveContinuityProxy?.stop();
        debugPrint('[IPTV Player] direct open ($kind)');
        await player.open(
          Media(playUrl, httpHeaders: headers),
        );
        final np = player.platform;
        if (np is NativePlayer && _livePlaybackProfile) {
          await _applyStreamLavfReconnect(np, continuityProxy: false);
        }
      }
      await player.play();
      if (_s._atvMediaKit) {
        unawaited(_tuneAtvMediaKitAfterOpen());
      } else if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        unawaited(_tuneDesktopMediaKitAfterOpen());
      }
    }
    // Re-apply after every open/recreate - media_kit resets to 100, and
    // mute is volume=0 in Dart state only.
    _engineSetVolume(_s._volume);
  }

  /// Stalker create_link URLs are one-shot / short-lived. Mint a fresh link
  /// before every open when we still have the portal + cmd (streamId).
  Future<IptvPlaySource> _refreshStalkerPlayUrl(IptvPlaySource src) async {
    if (_liveSourceKindFor(src) != IptvLiveSourceKind.iptvStalker) {
      return src;
    }
    var portal = _s.widget.channelGuide?.xtreamPortal?.portal;
    final cmd = (src.streamId ?? '').trim();
    if (cmd.isEmpty) return src;
    if (portal == null) {
      if (_s._sportsPortal == null) {
        await _s._initSportsEpgCache();
      }
      portal = _s._sportsPortal?.portal;
    }
    if (portal == null) return src;
    try {
      final fresh = await IptvClient.createLink(
        portal,
        cmd: cmd,
        section: 'live',
      );
      if (fresh == null || fresh.isEmpty) {
        debugPrint('[IPTV] stalker create_link empty for cmd=$cmd');
        return src;
      }
      if (fresh == src.url) return src;
      debugPrint('[IPTV] stalker create_link refreshed');
      final updated = src.copyWith(url: fresh);
      final i = _s._sourceIdx;
      if (i >= 0 && i < _s._sources.length) {
        _s._sources = List<IptvPlaySource>.from(_s._sources)..[i] = updated;
      }
      return updated;
    } catch (e) {
      debugPrint('[IPTV] stalker create_link failed: $e');
      return src;
    }
  }

  void _noteStalkerHardOpenFail() {
    if (_s._sources.isEmpty) return;
    if (_liveSourceKindFor(_s._sources[_s._sourceIdx]) !=
        IptvLiveSourceKind.iptvStalker) {
      return;
    }
    _s._stalkerHardFailCount++;
  }

  /// After repeated create_link + format fails, stop thrashing and mark red.
  bool _giveUpDeadStalkerStream() {
    if (_s._sources.isEmpty) return false;
    if (_s._stalkerHardFailCount < 2) return false;
    if (_liveSourceKindFor(_s._sources[_s._sourceIdx]) !=
        IptvLiveSourceKind.iptvStalker) {
      return false;
    }
    final id = (_s._sources[_s._sourceIdx].streamId ?? _s._currentChannelId)
        .trim();
    if (id.isNotEmpty) {
      _s.widget.onStreamDead?.call(id);
    }
    debugPrint(
      '[IPTV] stalker stream dead after ${_s._stalkerHardFailCount} '
      'hard fails — stopping recovery',
    );
    _s._userPlayWhenReady = false;
    if (mounted) {
      setState(() => _s._statusBanner = 'Stream offline');
    }
    return true;
  }

  void _resetStalkerHardFails() {
    _s._stalkerHardFailCount = 0;
  }

  bool get _currentSourceIsLive {
    if (_s._sources.isEmpty) return true;
    return iptvExoUrlLooksLive(_s._sources[_s._sourceIdx].url);
  }

  IptvLiveSourceKind _liveSourceKindFor(IptvPlaySource src) {
    return src.liveSourceKind ??
        _s.widget.liveSourceKind ??
        (_s.widget.engineContext == BuiltInPlayerContext.iptv
            ? IptvLiveSourceKind.iptvXtream
            : IptvLiveSourceKind.stremio);
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
        final next = await DesktopWindowGeometry.toggleFullscreen();
        if (mounted) setState(() => _s._isFullscreen = next);
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
        _syncPlaybackBannerVisibility();
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
      if (_s._buffering == b) return;
      _s._buffering = b;
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
        // Do not fake [_lastPosChange] here — that made empty-cache format
        // fails look "working" and skipped recovery until native crash.
        if (!_playbackStarted && _livePlaybackProfile) {
          _noteVideoFrame(reason: 'buffering done');
          return;
        }
        // No mid-stream live-edge snap here. Flushing the cache on every
        // underrun exit throws away the cushion that absorbs the next hiccup,
        // and mpv's own reconnect handles a dropped socket.
      }
      _s._playbackBannerSnapshot = null;
      _syncPlaybackBannerVisibility();
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
      // Live: never auto-swap engines (Reload / empty reopen often throws
      // "failed to recognize file format" and silently flipped MediaKit→Exo).
      if (!_s._formatEngineSwapped &&
          !_livePlaybackProfile &&
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
      // Hard open/format death: always reopen (never "healthy hold"). Soft
      // reopen can race a dead demuxer — escalate hard after early attempts.
      if (_livePlaybackProfile && iptvIsHardOpenFail(msg)) {
        _invalidatePendingLiveEdgeSnaps();
        unawaited(_triggerRecovery(
          reason: 'error: $msg',
          forceHard: _s._retryAttempt >= 1,
        ));
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


  bool get _atvHardReseatStreams =>
      !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;

  Future<IptvPlaySource?> _refreshLiveEngineSource(IptvPlaySource src) async {
    if (!src.canRefreshLiveEngine) return null;
    final pluginId = src.liveEnginePluginId!.trim();
    final params = src.liveEngineResolveParams!;
    debugPrint('[IPTV Player] re-unlock live engine ($pluginId)');
    try {
      final play = await LiveMatchesEngine.resolveToPlayUrl(
        pluginId: pluginId,
        params: params,
      );
      if (play == null || play.url.trim().isEmpty) return null;
      final updated = src.copyWith(url: play.url, headers: play.headers);
      if (_s._sourceIdx >= 0 && _s._sourceIdx < _s._sources.length) {
        _s._sources[_s._sourceIdx] = updated;
      }
      return updated;
    } catch (e) {
      debugPrint('[IPTV Player] live engine re-unlock failed: $e');
      return null;
    }
  }

  Future<void> _openCurrent({
    bool hardRecreate = false,
    String? switchingLabel,
    bool refreshLiveEngine = false,
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
      _invalidatePendingLiveEdgeSnaps();
      _s._exoSurfaceFallback?.resetForNewOpen();
      // Soft path: silent connect (buffering chrome only). Hard ATV reseat
      // already set "Switching to …" on the loading scaffold.
      try {
        await _engineOpenSource(
          src,
          refreshLiveEngine: refreshLiveEngine,
        );
        if (_s._disposed || epoch != _openEpoch) return;
        _s._userPlayWhenReady = true;
        _s._pausedAt = null;
        _s._lastPos = Duration.zero;
        _s._lastPosChange = DateTime.now();
        _s._openedAt = DateTime.now();
        _s._playbackBannerSnapshot = null;
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
  /// Player-menu engine switch, not a separate loading route. Channel zap with
  /// the guide open keeps the Stack mounted (switching surface in the video
  /// slot only) so the rail does not remount (issue 174 T04).
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
    _resetStalkerHardFails();
    _s._userPlayWhenReady = true;
    // Classic (1.3.114): soft reopen only — no mid-stream drop-buffers.
    if (!_bufferedRecovery) {
      await _openCurrent(
        refreshLiveEngine: _s._sources[_s._sourceIdx].canRefreshLiveEngine,
      );
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
    await _openCurrent(
      refreshLiveEngine: _s._sources[_s._sourceIdx].canRefreshLiveEngine,
    );
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

  Future<void> _finalizeExit() async {
    while (_recoveryInFlight) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await _s._liveContinuityProxy?.stop();
    _s._liveContinuityProxy = null;
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
    await _openCurrent(
      hardRecreate: _atvHardReseatStreams,
      refreshLiveEngine: _s._sources[idx].canRefreshLiveEngine,
    );
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
      _s._sources = [
        IptvPlaySource(
          url: url,
          label: label,
          logoUrl: ch.logoUrl,
          streamId: ch.xtreamStream?.streamId,
          epgChannelId: (ch.xtreamStream?.epgChannelId ?? '').isEmpty
              ? null
              : ch.xtreamStream!.epgChannelId,
          liveSourceKind: _s.widget.liveSourceKind,
        ),
      ];
      _s._sourceIdx = 0;
      _s._retryAttempt = 0;
      _s._stalkerHardFailCount = 0;
      _s._userPlayWhenReady = true;
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
