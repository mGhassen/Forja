part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _PtPlayerMkTunables on _PtPlayerEngineCore {
  void _engineSetVolume(double volume);
  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    String? streamUrl,
  });
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
        // Forja ATV vo=mediacodec_embed needs mediacodec (ipdigi leaves default).
        await p.setProperty('hwdec', 'mediacodec');
        await p.setProperty('ao', 'audiotrack');
        await p.setProperty('mute', 'no');
        await p.setProperty('volume-max', '150');
        await p.setProperty('video-sync', 'display-resample');
        await p.setProperty('framedrop', 'vo');
        await p.setProperty('vd-lavc-dr', 'no');
      } else if (_s.widget.vodPlayback || !_livePlaybackProfile) {
        await p.setProperty('hwdec', _useSoftwareDecode ? 'no' : 'auto-safe');
        await restoreMediaKitAudioOutput(p);
        await p.setProperty(
          'vd-lavc-dr',
          _useSoftwareDecode ? 'no' : 'yes',
        );
      } else {
        // ipdigi live desktop/phone/Windows: no hwdec / vd-lavc-dr pins.
        await restoreMediaKitAudioOutput(p);
      }

      final liveMk = _livePlaybackProfile && !_s.widget.vodPlayback;
      if (!liveMk) {
        await p.setProperty('vd-lavc-threads', '0');
      }

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
      if (!liveMk) {
        await p.setProperty('keep-open-pause', 'no');
        await p.setProperty('hls-bitrate', 'max');
        await p.setProperty('rtsp-transport', 'tcp');
      }

      // Panel UA — VOD / non-live only. ipdigi live opens with no UA.
      if (_s.widget.vodPlayback || !_livePlaybackProfile) {
        await p.setProperty('user-agent', _PtPlayerScreenState._ua);
      }

      // FFmpeg reconnect — applied after open for VOD; live sets before open.
      if (_s.widget.vodPlayback) {
        final vodUrl = _s._sources.isEmpty
            ? null
            : _s._sources[_s._sourceIdx.clamp(0, _s._sources.length - 1)].url;
        await _applyStreamLavfReconnect(p, streamUrl: vodUrl);
      }

      // VOD / non-live only — ipdigi does not set demuxer-lavf-o.
      if (!liveMk) {
        await p.setProperty(
          'demuxer-lavf-o',
          'fflags=+discardcorrupt+genpts+igndts,'
              'probesize=5000000,'
              'analyzeduration=5000000',
        );
      }
    } catch (e) {
      debugPrint('[IPTV Player] tunables failed: $e');
    }
  }

}
