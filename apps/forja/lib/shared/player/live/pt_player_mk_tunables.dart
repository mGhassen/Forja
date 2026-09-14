part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _PtPlayerMkTunables on _PtPlayerEngineCore {
  void _engineSetVolume(double volume);
  Future<void> _applyStreamLavfReconnect(NativePlayer p);
  bool get _livePlaybackProfile;
  bool get _useSoftwareDecode;

  Future<void> _tuneDesktopMediaKitAfterOpen() async {
    if (_s._disposed || _s._exoBackend || _s._avPlayerBackend || _s._vlcBackend || _s._atvMediaKit) return;
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
      if (_s._disposed || _s._exoBackend || _s._avPlayerBackend || _s._vlcBackend) return;
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
        } catch (_) {}

        if (_livePlaybackProfile && !_s.widget.vodPlayback) {
          await _applyAtvLiveCacheProfile(p, height: maxDim, videoBitrate: bitrate);
        }

        final uhd = h >= 2160 || w >= 3840;
        // HDMI mode switch while MediaCodec is still configuring 4K surfaces
        // force-closes physical ATV (issue 155). Wait for a painted frame.
        if (uhd && !_playbackStarted) continue;

        // 50/25 fps on a fixed 60 Hz panel judders even when decode is fine.
        // Same window mode switch Exo already uses (ForjaDisplayFrameRate).
        await _applyAtvMediaKitDisplayFrameRate(p);

        if (uhd) {
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
  /// Live only — Movies/Series skip (4K MediaCodec + mode switch OOMs).
  /// Gated by Settings → IPTV match display refresh (default on; admin-only).
  Future<void> _applyAtvMediaKitDisplayFrameRate(NativePlayer p) async {
    if (_s._displayFrameRateApplied) return;
    if (_s.widget.vodPlayback) return;
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

  /// Keep ipdigi live demuxer window after height probe (RFC-113).
  /// Admin override still widens cache-secs only; demuxer bytes stay ipdigi.
  Future<void> _applyAtvLiveCacheProfile(
    NativePlayer p, {
    required int height,
    double videoBitrate = 0,
  }) async {
    if (_s.widget.vodPlayback) return;
    if (!_livePlaybackProfile) return;
    if (_s._liveCacheTierApplied && height == _s._lastVideoHeight) return;

    const cacheSecs = 30;
    const readaheadSecs = 8;
    const demuxerMaxBytes = 128 * 1024 * 1024;
    const demuxerMaxBackBytes = 64 * 1024 * 1024;

    final overrideSecs = await SettingsService().getIptvLiveBufferSecs();
    final secs = overrideSecs > 0 ? overrideSecs : cacheSecs;

    await p.setProperty('cache-secs', '$secs');
    await p.setProperty('demuxer-readahead-secs', '$readaheadSecs');
    await p.setProperty('demuxer-max-bytes', '$demuxerMaxBytes');
    await p.setProperty('demuxer-max-back-bytes', '$demuxerMaxBackBytes');
    await p.setProperty('cache-pause', 'no');
    await p.setProperty('cache-pause-initial', 'no');
    await p.setProperty('cache-pause-wait', '0');
    if (_s._atvMediaKit) {
      await p.setProperty('cache-on-disk', 'no');
    }

    _s._liveCacheTierApplied = true;
    debugPrint(
      '[IPTV Player] MediaKit cache profile=live/ipdigi '
      'height=$height bitrate=${videoBitrate > 0 ? (videoBitrate / 1e6).toStringAsFixed(1) : "?"}Mbps '
      'cache=${secs}s bytes=$demuxerMaxBytes',
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
      // mediacodec_embed already owns the surface. lavc DR extra copies on
      // 4K MediaCodec are a physical-ATV OOM vector (issue 155).
      await p.setProperty(
        'vd-lavc-dr',
        (_s._atvMediaKit || _useSoftwareDecode) ? 'no' : 'yes',
      );
      await p.setProperty('vd-lavc-threads', '0');

      // Network: ipdigi uses 30s so lavf reconnect can finish.
      await p.setProperty('network-timeout', '30');

      // Cache: RFC-113 / ipdigi live profile (desktop + ATV same demuxer bytes).
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
        // ipdigi live: 30s / 8s readahead / 128MiB / 64MiB back / cache-pause=no.
        const coldSecs = 30;
        const coldReadahead = 8;
        const coldBytes = 128 * 1024 * 1024;
        const coldBackBytes = 64 * 1024 * 1024;
        debugPrint('[IPTV Player] MediaKit cache profile=live/ipdigi');
        await p.setProperty('cache-secs', '$coldSecs');
        await p.setProperty('demuxer-readahead-secs', '$coldReadahead');
        await p.setProperty('demuxer-max-bytes', '$coldBytes');
        await p.setProperty('demuxer-max-back-bytes', '$coldBackBytes');
        await p.setProperty('audio-buffer', '1.0');
        await p.setProperty('cache-pause', 'no');
        await p.setProperty('cache-pause-initial', 'no');
        await p.setProperty('cache-pause-wait', '0');
        // ipdigi: ATV memory-only; desktop/phone disk cache for track swaps.
        if (_s._atvMediaKit) {
          await p.setProperty('cache-on-disk', 'no');
        } else if (!kIsWeb) {
          try {
            final support = await getApplicationSupportDirectory();
            final dir = Directory('${support.path}/mpv_cache');
            if (!await dir.exists()) await dir.create(recursive: true);
            await p.setProperty('cache-on-disk', 'yes');
            await p.setProperty('cache-dir', dir.path);
          } catch (e) {
            debugPrint('[IPTV Player] cache-on-disk setup failed: $e');
          }
        }
        // ipdigi seek/sync (scrub + keep-open EOF during seek).
        await p.setProperty('force-seekable', 'yes');
        await p.setProperty('initial-audio-sync', 'yes');
        await p.setProperty('hr-seek', 'yes');
      }

      await p.setProperty('sub-auto', 'all');
      await p.setProperty('sub-visibility', 'no');

      // ipdigi: keep-open=always so brief EOF does not tear down the player.
      await p.setProperty('keep-open', 'always');
      await p.setProperty('keep-open-pause', 'no');

      // HLS: pick best variant. Desktop live forces software decode (TextureSW);
      // `max` grabs Brightcove / fat demuxed 1080p50 masters and underruns into
      // the watchdog reopen loop. Soft-cap ~720p when decoding in software.
      await p.setProperty(
        'hls-bitrate',
        (_useSoftwareDecode && !_s.widget.vodPlayback) ? '3500000' : 'max',
      );

      // RTSP over TCP - way more reliable on flaky networks
      await p.setProperty('rtsp-transport', 'tcp');

      // Many Xtream panels gate streams on a VLC user-agent
      await p.setProperty('user-agent', _PtPlayerScreenState._ua);

      // FFmpeg reconnect — applied after open for VOD; live sets before open.
      if (_s.widget.vodPlayback) {
        await _applyStreamLavfReconnect(p);
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
      // +igndts: DAI / SCTE ad-splice HLS often emits pts < dts (CBS News etc.)
      // — without it demuxer stalls with cache=0 while segments still download.
      await p.setProperty(
        'demuxer-lavf-o',
        'fflags=+discardcorrupt+genpts+igndts,'
            'probesize=5000000,'
            'analyzeduration=5000000',
      );
    } catch (e) {
      debugPrint('[IPTV Player] tunables failed: $e');
    }
  }

}
