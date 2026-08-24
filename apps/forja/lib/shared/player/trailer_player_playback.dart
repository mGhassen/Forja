part of 'trailer_player_screen.dart';

mixin _TrailerPlayerPlayback on State<TrailerPlayerScreen> {
  _TrailerPlayerScreenState get _s => this as _TrailerPlayerScreenState;

  /// Leanback MediaKit path — same knobs as main VOD / IPTV ATV.
  bool get _atvMediaKit => PlatformInfo.isAndroidTv;

  Future<void> _ensurePlayer() async {
    if (_s._player != null) return;
    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    if (!mounted) return;
    final atv = _atvMediaKit;
    final player = MpvExclusiveSession.instance.trackPlayer(
      Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
        ),
      ),
    );
    _s._player = player;
    // ATV: vo=gpu needs EGL (black / audio-only). mediacodec_embed paints
    // MediaCodec into the Flutter Surface — matches TvPlayerScreen / IPTV.
    _s._controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: atv ? 'mediacodec_embed' : null,
        enableHardwareAcceleration: true,
        hwdec: atv ? 'mediacodec' : null,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    _s._playingSub = player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (_s._playing == playing && !_s._ended) return;
      setState(() {
        _s._playing = playing;
        if (playing) _s._ended = false;
      });
      if (playing) {
        _s._cancelAutoNext();
        _s._startHideTimer();
      }
    });
    _s._positionSub = player.stream.position.listen((pos) {
      if (!mounted) return;
      if (_s._position == pos) return;
      final wasNearEnd = _s._showNextTrailerChip;
      setState(() => _s._position = pos);
      if (!wasNearEnd && _s._showNextTrailerChip) {
        _s._hideTimer?.cancel();
        if (!_s._showControls) {
          setState(() => _s._showControls = true);
        }
        _s._focusNextTrailerIfNeeded();
      }
    });
    _s._durationSub = player.stream.duration.listen((dur) {
      if (!mounted) return;
      if (_s._duration == dur) return;
      setState(() => _s._duration = dur);
    });
    _s._completedSub = player.stream.completed.listen((done) {
      if (!mounted || !done) return;
      setState(() {
        _s._ended = true;
        _s._playing = false;
        _s._showControls = true;
      });
      _s._hideTimer?.cancel();
      _s._maybeStartAutoNext();
    });
    await _applyTrailerMpvTunables(atv: atv);
  }

  Future<void> _applyTrailerMpvTunables({required bool atv}) async {
    final platform = _s._player?.platform;
    if (platform is! NativePlayer) return;
    if (!await mediaKitPlayerHandleReady(platform)) return;

    Future<void> safeSet(String key, String val) async {
      try {
        await platform.setProperty(key, val);
      } catch (e) {
        debugPrint('[Trailer] failed mpv $key=$val: $e');
      }
    }

    if (atv) {
      await safeSet('hwdec', 'mediacodec');
      // OpenSLES misconfigures on some ATV images (0 frames).
      await safeSet('ao', 'audiotrack');
      // VOD clock — display-resample is for IPTV live edge.
      await safeSet('video-sync', 'audio');
    }

    await safeSet('cache', 'yes');
    await safeSet('cache-secs', atv ? '30' : '45');
    await safeSet('demuxer-readahead-secs', '20');
    await safeSet('demuxer-max-bytes', atv ? '150000000' : '100MiB');
    await safeSet('demuxer-max-back-bytes', atv ? '25000000' : '30MiB');
    await safeSet('cache-pause', 'no');
    await safeSet('cache-pause-initial', 'no');
    await safeSet('network-timeout', '30');
    await safeSet('ytdl', 'no');
    await safeSet('keep-open', 'yes');
  }

  Future<void> _teardownPlayer() async {
    _s._playingSub?.cancel();
    _s._positionSub?.cancel();
    _s._durationSub?.cancel();
    _s._completedSub?.cancel();
    _s._playingSub = null;
    _s._positionSub = null;
    _s._durationSub = null;
    _s._completedSub = null;
    final player = _s._player;
    _s._player = null;
    _s._controller = null;
    if (player == null) return;
    MpvExclusiveSession.instance.untrackPlayer(player);
    final disposeFuture = teardownMediaKitPlayer(player);
    MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
    await disposeFuture;
  }

  /// Resolve + open the current trailer. Always re-resolves (URLs expire).
  Future<void> _loadCurrentTrailer({Duration? resumeAt}) async {
    final loadId = ++_s._loadGeneration;
    final videoId = _s._trailer.key;
    setState(() {
      _s._ready = false;
      _s._resolving = true;
      _s._resolveError = null;
      _s._playing = false;
      _s._ended = false;
      _s._position = Duration.zero;
      _s._duration = Duration.zero;
      _s._streams = null;
      _s._selectedQualityHeight = null;
      _s._activeCaptionCode = null;
      _s._captionsFetched = false;
      _s._captionsLoading = false;
    });

    YoutubeResolvedStreams? streams;
    try {
      // Lean resolve (no captions / metadata) — captions load when CC opens.
      streams = await YoutubeStreamService.resolveStreams(videoId);
    } catch (e) {
      debugPrint('Trailer resolve failed: $e');
      streams = null;
    }
    if (!mounted || loadId != _s._loadGeneration) return;

    if (streams == null || !streams.hasPlayable) {
      setState(() {
        _s._resolving = false;
        _s._resolveError = 'Could not load this trailer';
      });
      return;
    }

    try {
      await _ensurePlayer();
      if (!mounted || loadId != _s._loadGeneration) return;
      final opened = await _openResolved(
        streams,
        resumeAt: resumeAt,
        allowMuxedFallback: true,
      );
      if (!mounted || loadId != _s._loadGeneration) return;
      if (opened == null) throw StateError('trailer stream open failed');
      setState(() {
        _s._streams = opened;
        _s._resolving = false;
        _s._ready = true;
        _s._selectedQualityHeight = _qualityMenuHeightFor(opened);
      });
      _s._claimPlayFocus();
      _s._startHideTimer();
    } catch (e) {
      debugPrint('Trailer open failed: $e');
      if (!mounted || loadId != _s._loadGeneration) return;
      setState(() {
        _s._resolving = false;
        _s._ready = false;
        _s._resolveError = 'Could not play this trailer';
      });
    }
  }

  /// Menu highlight for the stream currently open (muxed URL ≠ adaptive URLs).
  int? _qualityMenuHeightFor(YoutubeResolvedStreams streams) {
    final playUrl = streams.playUrl;
    if (playUrl == null) return null;
    final byUrl = streams.qualities
        .where((q) => q.videoUrl == playUrl)
        .map((q) => q.height)
        .firstOrNull;
    if (byUrl != null) return byUrl;

    final h = streams.playHeight;
    if (h == null || streams.qualities.isEmpty) return null;
    if (streams.qualities.any((q) => q.height == h)) return h;
    // Muxed height missing from ladder — nearest rung at or below.
    return streams.qualities
        .where((q) => q.height <= h)
        .map((q) => q.height)
        .firstOrNull;
  }

  /// True when [videoUrl] is adaptive video-only (needs [streams.audioUrl]).
  bool _needsExternalAudio(YoutubeResolvedStreams streams, String videoUrl) {
    final audio = streams.audioUrl;
    if (audio == null || audio.isEmpty) return false;
    return streams.qualities.any((q) => q.videoUrl == videoUrl);
  }

  bool _hasSelectableAudio(Player player) {
    return player.state.tracks.audio.any(
      (t) => t.id != 'no' && t.id != 'auto',
    );
  }

  Future<bool> _waitForSelectableAudio(Player player) async {
    if (_hasSelectableAudio(player)) return true;
    try {
      await player.stream.tracks
          .firstWhere(
            (t) => t.audio.any((a) => a.id != 'no' && a.id != 'auto'),
          )
          .timeout(const Duration(milliseconds: 1500));
      return true;
    } catch (_) {
      return _hasSelectableAudio(player);
    }
  }

  /// Opens [streams]. Returns the streams actually playing (may be muxed
  /// fallback), or null on failure.
  Future<YoutubeResolvedStreams?> _openResolved(
    YoutubeResolvedStreams streams, {
    Duration? resumeAt,
    /// Quality hot-swap: never trust leftover tracks after reopen.
    bool forceAudioAdd = false,
    /// First open only: if adaptive stays silent, fall back to muxed.
    bool allowMuxedFallback = false,
  }) async {
    final player = _s._player;
    if (player == null) return null;
    final videoUrl = streams.playUrl!;
    final audioUrl = streams.audioUrl;
    final needsExternalAudio = _needsExternalAudio(streams, videoUrl);
    final atv = _atvMediaKit;

    // Stop first so mediacodec / demuxer drop the prior googlevideo URL.
    try {
      await resetPlayerForOpen(player);
    } catch (e) {
      debugPrint('[Trailer] reset before open failed: $e');
    }

    final platform = player.platform;
    if (platform is NativePlayer) {
      if (!await mediaKitPlayerHandleReady(platform)) return null;
      try {
        await platform.setProperty('mute', 'no');
      } catch (_) {}
      try {
        await platform.setProperty('audio-file', '');
      } catch (_) {}
      // ATV first open: bind AAC before open. Quality switch always audio-adds.
      if (needsExternalAudio && atv && audioUrl != null && !forceAudioAdd) {
        try {
          await platform.setProperty('audio-file', audioUrl);
        } catch (e) {
          debugPrint('[Trailer] audio-file bind failed: $e');
        }
      }
    }

    await player.setVolume(_s._volume);
    await openPlayerStream(player, url: videoUrl);

    // Do NOT use waitForPlayerStreamOpen here: stop() abort noise often emits
    // "HTTP error" / "Failed to open" that settles that waiter false before the
    // new googlevideo URL is ready (quality switch stuck on muxed 360p).
    final opened = await _waitTrailerOpenReady(player);
    if (!opened) {
      debugPrint(
        '[Trailer] stream open did not become ready '
        '(playing=${player.state.playing} '
        'dur=${player.state.duration.inMilliseconds}ms '
        'vp=${player.state.videoParams.w}x${player.state.videoParams.h})',
      );
      return null;
    }

    if (needsExternalAudio && audioUrl != null && audioUrl.isNotEmpty) {
      // Desktop: always audio-add. ATV first open: only if audio-file missed.
      // Quality switch: always audio-add (stale tracks after stop).
      final needAudioAdd =
          !atv || forceAudioAdd || !await _waitForSelectableAudio(player);
      if (needAudioAdd) {
        try {
          await player.setAudioTrack(AudioTrack.uri(audioUrl));
        } catch (e) {
          debugPrint('[Trailer] audio-add failed: $e');
        }
      }
      // Adaptive silent → muxed progressive (Debrify fallback).
      if (allowMuxedFallback &&
          streams.muxedUrl != null &&
          streams.muxedUrl!.isNotEmpty &&
          streams.muxedUrl != videoUrl &&
          !await _waitForSelectableAudio(player)) {
        debugPrint('[Trailer] adaptive silent — falling back to muxed');
        final muxed = YoutubeResolvedStreams(
          playUrl: streams.muxedUrl,
          playHeight: streams.muxedHeight,
          // Keep AAC for later quality switches even though muxed has audio.
          audioUrl: streams.audioUrl,
          muxedUrl: streams.muxedUrl,
          muxedHeight: streams.muxedHeight,
          title: streams.title,
          thumbnailUrl: streams.thumbnailUrl,
          durationSeconds: streams.durationSeconds,
          qualities: streams.qualities,
          captions: streams.captions,
        );
        return _openResolved(
          muxed,
          resumeAt: resumeAt,
          forceAudioAdd: false,
          allowMuxedFallback: false,
        );
      }
    }

    if (resumeAt != null && resumeAt > Duration.zero) {
      await player.seek(resumeAt);
    }
    await player.play();
    return streams;
  }

  /// Poll readiness only — ignore error stream (stop() abort is not fatal).
  Future<bool> _waitTrailerOpenReady(Player player) async {
    if (isMediaOpenReady(player.state)) return true;
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (isMediaOpenReady(player.state)) return true;
    }
    return isMediaOpenReady(player.state);
  }

  Future<void> _switchQuality(YoutubeQuality quality) async {
    final streams = _s._streams;
    final player = _s._player;
    if (streams == null || player == null || !_s._ready) return;
    final resumeAt = _s._position;
    final prevHeight = _s._selectedQualityHeight;
    setState(() {
      _s._selectedQualityHeight = quality.height;
      _s._ready = false;
    });
    final swapped = streams.copyWith(
      playUrl: quality.videoUrl,
      playHeight: quality.height,
    );
    // Always remux AAC after quality swap (desktop + ATV).
    final opened = await _openResolved(
      swapped,
      resumeAt: resumeAt,
      forceAudioAdd: true,
    );
    if (!mounted) return;
    if (opened == null) {
      debugPrint('Trailer quality switch failed: open');
      final recovered = await _openResolved(
        streams,
        resumeAt: resumeAt,
        forceAudioAdd: true,
      );
      if (mounted) {
        setState(() {
          _s._selectedQualityHeight = prevHeight;
          _s._ready = recovered != null;
          if (recovered != null) _s._streams = recovered;
        });
      }
      return;
    }
    setState(() {
      _s._streams = opened;
      _s._ready = true;
    });
    if (_s._activeCaptionCode != null) {
      await _applyCaptionTrack(_s._activeCaptionCode);
    }
  }

  Future<void> _ensureCaptionsLoaded() async {
    final streams = _s._streams;
    if (streams == null || _s._captionsFetched || streams.captions.isNotEmpty) {
      return;
    }
    if (_s._captionsLoading) return;
    _s._captionsLoading = true;
    try {
      final captions = await YoutubeStreamService.fetchCaptions(
        _s._trailer.key,
      );
      if (!mounted) return;
      if (_s._streams == null) return;
      setState(() {
        _s._streams = _s._streams!.copyWith(captions: captions);
        _s._captionsFetched = true;
      });
    } finally {
      _s._captionsLoading = false;
    }
  }

  Future<void> _applyCaptionTrack(String? languageCode) async {
    final player = _s._player;
    if (player == null) return;
    if (languageCode == null || languageCode.isEmpty) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      if (mounted) setState(() => _s._activeCaptionCode = null);
      return;
    }
    await _ensureCaptionsLoaded();
    if (!mounted) return;
    final track = _s._streams?.captions
        .where((c) => c.langCode == languageCode)
        .firstOrNull;
    if (track == null) return;
    await player.setSubtitleTrack(
      SubtitleTrack.uri(track.url, title: track.langName, language: track.langCode),
    );
    if (mounted) setState(() => _s._activeCaptionCode = languageCode);
  }

  Future<void> _togglePlayPause() async {
    _s._cancelAutoNext();
    final player = _s._player;
    if (player == null || !_s._ready) return;
    if (_s._ended) {
      setState(() => _s._ended = false);
      await player.seek(Duration.zero);
      await player.play();
      return;
    }
    if (_s._playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _toggleMute() async {
    final next = !_s._muted;
    setState(() {
      _s._muted = next;
      if (next) {
        if (_s._volume > 0) _s._volumeBeforeMute = _s._volume;
        _s._volume = 0;
      } else {
        _s._volume = _s._volumeBeforeMute > 0 ? _s._volumeBeforeMute : 100;
      }
    });
    await _s._player?.setVolume(_s._volume);
  }

  Future<void> _setVolume(double volume) async {
    final next = volume.clamp(0.0, 100.0);
    setState(() {
      _s._volume = next;
      _s._muted = next <= 0;
      if (next > 0) _s._volumeBeforeMute = next;
    });
    await _s._player?.setVolume(next);
  }

  Future<void> _seek(Duration position) async {
    if (!_s._ready || _s._player == null) return;
    _s._cancelAutoNext();
    if (_s._ended) setState(() => _s._ended = false);
    await _s._player!.seek(position);
  }

  Future<void> _skip(int seconds) async {
    if (!_s._ready || _s._player == null) return;
    _s._cancelAutoNext();
    final next = _s._position + Duration(seconds: seconds);
    final clamped = next < Duration.zero
        ? Duration.zero
        : (_s._duration > Duration.zero && next > _s._duration
            ? _s._duration
            : next);
    await _s._player!.seek(clamped);
  }

  Future<void> _setRate(double rate) async {
    await _s._player?.setRate(rate);
    if (mounted) setState(() => _s._playbackRate = rate);
  }

  void _playTrailerAt(int index) {
    if (index < 0 || index >= widget.trailers.length) return;
    // Same trailer already up — restart from the beginning (center play / replay).
    if (index == _s._currentIndex && !_s._ended && _s._ready) {
      _s._cancelAutoNext();
      unawaited(() async {
        await _s._seek(Duration.zero);
        await _s._player?.play();
      }());
      return;
    }
    PlayerPopupPanel.dismiss();
    _s._cancelAutoNext(rebuild: false);
    setState(() {
      _s._currentIndex = index;
      // Keep the More videos picker on the trailer just started — chevrons
      // alone advance the preview (do not jump to "next" on play).
      _s._pickerIndex = index;
      _s._autoNextSecondsLeft = null;
      _s._playing = false;
      _s._ended = false;
      _s._ready = false;
      _s._muted = false;
      _s._volume = 100;
      _s._volumeBeforeMute = 100;
      _s._playbackRate = 1.0;
      _s._position = Duration.zero;
      _s._duration = Duration.zero;
      _s._showControls = true;
    });
    unawaited(_loadCurrentTrailer());
  }
}
