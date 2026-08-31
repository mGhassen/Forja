part of 'iptv_pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _IptvPtPlayerMkTunables on _IptvPtPlayerEngineCore {
  void _engineSetVolume(double volume);
  Future<void> _applyStreamLavfReconnect(NativePlayer p, {required bool continuityProxy});
  bool get _livePlaybackProfile;
  bool get _useSoftwareDecode;

  Future<void> _tuneDesktopMediaKitAfterOpen() async {
    if (_s._disposed || _s._exoBackend || _s._atvMediaKit) return;
    final player = _s._player;
    final p = player?.platform;
    if (player == null || p is! NativePlayer) return;

    try {
      await restoreMediaKitAudioOutput(p);
      _engineSetVolume(_s._volume);
    } catch (e) {
      debugPrint('[IPTV Player] desktop ao restore failed: $e');
    }

    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_s._disposed || _s._exoBackend) return;
      if (!identical(_s._player, player)) return;

      try {
        final tracks = concreteAudioTracks(player.state.tracks.audio);
        if (tracks.isNotEmpty) {
          final target = tracks.first;
          if (player.state.track.audio.id != target.id) {
            await selectPlayerAudioTrack(player, target);
            debugPrint(
              '[IPTV Player] desktop auto audio → '
              '${target.title ?? target.language ?? target.id}',
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('[IPTV Player] desktop post-open tune failed: $e');
        return;
      }
    }
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
        final tracks = concreteAudioTracks(player.state.tracks.audio);
        if (tracks.isNotEmpty) {
          final target = tracks.first;
          if (player.state.track.audio.id != target.id) {
            await selectPlayerAudioTrack(player, target);
          }
        }

        final h = int.tryParse((await p.getProperty('height')).toString()) ?? 0;
        final w = int.tryParse((await p.getProperty('width')).toString()) ?? 0;
        if (h <= 0 && w <= 0) continue;

        final maxDim = h > w ? h : w;
        _s._lastVideoHeight = maxDim;
        var bitrate = 0.0;
        try {
          final brRaw = await p.getProperty('video-bitrate');
          bitrate = double.tryParse(brRaw.toString()) ?? 0;
          if (bitrate.isFinite && bitrate > 0) {
            _s._lastVideoBitrate = bitrate.round();
          }
        } catch (_) {}

        if (_livePlaybackProfile && !_s.widget.vodPlayback) {
          await _applyAtvLiveCacheProfile(p, height: maxDim, videoBitrate: bitrate);
        }

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
  /// Gated by Settings → IPTV match display refresh (default on; admin-only).
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

  ({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes})
      _atvLiveCacheTierForHeight(int height) {
    if (height >= 2160) {
      return (
        tier: 'uhd',
        cacheSecs: 30,
        readaheadSecs: 20,
        demuxerMaxBytes: 150000000,
      );
    }
    if (height >= 1080) {
      return (
        tier: 'fhd',
        cacheSecs: 20,
        readaheadSecs: 15,
        demuxerMaxBytes: 96 * 1024 * 1024,
      );
    }
    return (
      tier: 'hd',
      cacheSecs: 15,
      readaheadSecs: 10,
      demuxerMaxBytes: 48 * 1024 * 1024,
    );
  }

  ({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes})
      _bumpAtvLiveCacheTier(
    ({String tier, int cacheSecs, int readaheadSecs, int demuxerMaxBytes}) t,
  ) {
    switch (t.tier) {
      case 'hd':
        return _atvLiveCacheTierForHeight(1080);
      case 'fhd':
        return _atvLiveCacheTierForHeight(2160);
      default:
        return t;
    }
  }

  /// Height + bitrate aware live demuxer window (I150-T05). VOD must never call.
  Future<void> _applyAtvLiveCacheProfile(
    NativePlayer p, {
    required int height,
    double videoBitrate = 0,
  }) async {
    if (_s.widget.vodPlayback) return;
    if (!_s._atvMediaKit || !_livePlaybackProfile) return;
    if (_s._liveCacheTierApplied && height == _s._lastVideoHeight) return;

    var profile = height > 0
        ? _atvLiveCacheTierForHeight(height)
        : _atvLiveCacheTierForHeight(2160);

    if (videoBitrate > 0) {
      final needBytes = (videoBitrate / 8) * profile.cacheSecs;
      if (needBytes > profile.demuxerMaxBytes * 0.9) {
        final bumped = _bumpAtvLiveCacheTier(profile);
        if (bumped.tier != profile.tier) {
          profile = bumped;
        } else if (profile.tier == 'uhd') {
          debugPrint(
            '[IPTV Player] live/uhd demuxer may still byte-bind at '
            '${(videoBitrate / 1e6).toStringAsFixed(1)}Mbps',
          );
        }
      }
    }

    await p.setProperty('cache-secs', '${profile.cacheSecs}');
    await p.setProperty('demuxer-readahead-secs', '${profile.readaheadSecs}');
    await p.setProperty('demuxer-max-bytes', '${profile.demuxerMaxBytes}');
    await p.setProperty('demuxer-max-back-bytes', '0');
    await p.setProperty('cache-pause', 'no');
    await p.setProperty('cache-pause-initial', 'no');

    _s._liveCacheTierApplied = true;
    debugPrint(
      '[IPTV Player] MediaKit cache profile=live/${profile.tier} '
      'height=$height bitrate=${videoBitrate > 0 ? (videoBitrate / 1e6).toStringAsFixed(1) : "?"}Mbps',
    );
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
        await restoreMediaKitAudioOutput(p);
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
        // Live: continuity proxy absorbs CDN HTTP closes before mpv (I148-T21).
        // cache-pause=yes turned every ~5–6s CDN reopen (3MiB overlap skip) into a
        // hard micro-pause — clockwork stutter, no Buffering chrome (issue 199).
        // Play through demuxer cushion; watchdog still shows Buffering + soft-reopen
        // when cache is truly empty (I199-T03/T04).
        debugPrint('[IPTV Player] MediaKit cache profile=live/cold (uhd-safe)');
        await p.setProperty('cache-secs', '30');
        await p.setProperty('demuxer-readahead-secs', '20');
        await p.setProperty('demuxer-max-bytes', '150000000');
        // No past cushion — underrun freezes; proxy read-ahead absorbs CDN closes.
        await p.setProperty('demuxer-max-back-bytes', '0');
        await p.setProperty('audio-buffer', '1.0');
        await p.setProperty('cache-pause', 'no');
        await p.setProperty('cache-pause-initial', 'no');
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

      // FFmpeg reconnect — applied after open (proxy vs direct). VOD keeps direct.
      if (_s.widget.vodPlayback) {
        await _applyStreamLavfReconnect(p, continuityProxy: false);
      }

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

}
