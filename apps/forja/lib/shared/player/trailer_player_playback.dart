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
    });

    YoutubeResolvedStreams? streams;
    try {
      streams = await YoutubeStreamService.resolveStreams(
        videoId,
        withCaptions: true,
      );
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
      await _openResolved(streams, resumeAt: resumeAt);
      if (!mounted || loadId != _s._loadGeneration) return;
      setState(() {
        _s._streams = streams;
        _s._resolving = false;
        _s._ready = true;
        final playUrl = streams!.playUrl;
        _s._selectedQualityHeight = playUrl == null
            ? null
            : streams.qualities
                .where((q) => q.videoUrl == playUrl)
                .map((q) => q.height)
                .firstOrNull;
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

  Future<void> _openResolved(
    YoutubeResolvedStreams streams, {
    Duration? resumeAt,
    /// Quality hot-swap: never trust leftover tracks after reopen on ATV.
    bool forceAudioAdd = false,
  }) async {
    final player = _s._player;
    if (player == null) return;
    final videoUrl = streams.playUrl!;
    final audioUrl = streams.audioUrl;
    final needsExternalAudio = _needsExternalAudio(streams, videoUrl);
    final atv = _atvMediaKit;

    // ATV mediacodec_embed + googlevideo: open() alone often keeps the old
    // demuxer / tracks. Main player always stop()+wait before source swaps.
    try {
      await resetPlayerForOpen(player);
    } catch (e) {
      debugPrint('[Trailer] reset before open failed: $e');
    }

    final platform = player.platform;
    if (platform is NativePlayer) {
      if (!await mediaKitPlayerHandleReady(platform)) return;
      try {
        await platform.setProperty('mute', 'no');
      } catch (_) {}
      // Clear sticky external audio from a prior adaptive open (muxed path).
      try {
        await platform.setProperty('audio-file', '');
      } catch (_) {}
      // ATV: bind AAC before open to avoid MediaCodec resync hitch.
      // Skip on quality switch — force audio-add after open instead.
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
    final opened = await waitForPlayerStreamOpen(
      player,
      streamUrl: videoUrl,
    );
    if (!opened) {
      debugPrint('[Trailer] stream open did not become ready');
    }

    if (needsExternalAudio && audioUrl != null && audioUrl.isNotEmpty) {
      // Desktop: audio-file is unreliable for googlevideo — always audio-add.
      // ATV first open: audio-add only when audio-file did not attach.
      // ATV quality switch: always audio-add (stale tracks fooled the wait).
      final needAudioAdd =
          !atv || forceAudioAdd || !await _waitForSelectableAudio(player);
      if (needAudioAdd) {
        try {
          await player.setAudioTrack(AudioTrack.uri(audioUrl));
        } catch (e) {
          debugPrint('[Trailer] audio-add failed: $e');
        }
      }
    }

    if (resumeAt != null && resumeAt > Duration.zero) {
      await player.seek(resumeAt);
    }
    await player.play();
  }

  Future<void> _switchQuality(YoutubeQuality quality) async {
    final streams = _s._streams;
    final player = _s._player;
    if (streams == null || player == null || !_s._ready) return;
    final resumeAt = _s._position;
    setState(() {
      _s._selectedQualityHeight = quality.height;
      _s._ready = false;
    });
    try {
      final swapped = YoutubeResolvedStreams(
        playUrl: quality.videoUrl,
        audioUrl: streams.audioUrl,
        title: streams.title,
        thumbnailUrl: streams.thumbnailUrl,
        durationSeconds: streams.durationSeconds,
        qualities: streams.qualities,
        captions: streams.captions,
      );
      await _openResolved(
        swapped,
        resumeAt: resumeAt,
        forceAudioAdd: _atvMediaKit,
      );
      if (!mounted) return;
      setState(() {
        _s._streams = swapped;
        _s._ready = true;
      });
      if (_s._activeCaptionCode != null) {
        await _applyCaptionTrack(_s._activeCaptionCode);
      }
    } catch (e) {
      debugPrint('Trailer quality switch failed: $e');
      if (mounted) setState(() => _s._ready = true);
    }
  }

  Future<void> _applyCaptionTrack(String? languageCode) async {
    final player = _s._player;
    final streams = _s._streams;
    if (player == null) return;
    if (languageCode == null || languageCode.isEmpty) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      if (mounted) setState(() => _s._activeCaptionCode = null);
      return;
    }
    final track = streams?.captions
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
