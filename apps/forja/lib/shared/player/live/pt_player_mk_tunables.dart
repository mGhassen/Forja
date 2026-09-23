part of 'pt_player_screen.dart';

// Implementations satisfy abstracts on sibling player mixins.
// ignore_for_file: unused_element

mixin _PtPlayerMkTunables on _PtPlayerEngineCore {
  void _engineSetVolume(double volume);
  Future<void> _applyStreamLavfReconnect(
    NativePlayer p, {
    String? streamUrl,
    bool sportsDirect = false,
  });
  bool get _livePlaybackProfile;
  bool get _liveSportsSurface;
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

  /// Height-probe demuxer window after open.
  ///
  /// Live Sports (`_liveSportsSurface`): pre–RFC-113 / v1.5.36 ATV tiers,
  /// `demuxer-max-back-bytes=0`. IPTV: RFC-113 `live/forja` (untouched).
  Future<void> _applyAtvLiveCacheProfile(
    NativePlayer p, {
    required int height,
    double videoBitrate = 0,
  }) async {
    if (_s.widget.vodPlayback) return;
    if (!_livePlaybackProfile) return;
    if (_s._liveCacheTierApplied && height == _s._lastVideoHeight) return;

    if (_liveSportsSurface) {
      await _applySportsAtvLiveCacheProfile(
        p,
        height: height,
        videoBitrate: videoBitrate,
      );
      return;
    }

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
      '[IPTV Player] MediaKit cache profile=live/forja '
      'height=$height bitrate=${videoBitrate > 0 ? (videoBitrate / 1e6).toStringAsFixed(1) : "?"}Mbps '
      'cache=${secs}s bytes=$demuxerMaxBytes',
    );
  }

  /// Live Sports ATV only — v1.5.36 height tiers + back-bytes=0.
  Future<void> _applySportsAtvLiveCacheProfile(
    NativePlayer p, {
    required int height,
    double videoBitrate = 0,
  }) async {
    final overrideSecs = await SettingsService().getIptvLiveBufferSecs();
    late ({
      String tier,
      int cacheSecs,
      int readaheadSecs,
      int demuxerMaxBytes,
    }) profile;

    if (overrideSecs > 0) {
      final forced = SettingsService.iptvLiveBufferProfileForSecs(overrideSecs);
      profile = (
        tier: forced.tier,
        cacheSecs: forced.cacheSecs,
        readaheadSecs: forced.readaheadSecs,
        demuxerMaxBytes: forced.demuxerMaxBytes,
      );
      if (videoBitrate > 0) {
        final needBytes = (videoBitrate / 8) * profile.cacheSecs;
        if (needBytes > profile.demuxerMaxBytes * 0.9) {
          debugPrint(
            '[IPTV Player] live/sports/${profile.tier} demuxer may byte-bind at '
            '${(videoBitrate / 1e6).toStringAsFixed(1)}Mbps '
            '(override ${profile.cacheSecs}s)',
          );
        }
      }
    } else {
      profile = height > 0
          ? liveSportsAtvCacheTierForHeight(height)
          : liveSportsAtvCacheTierForHeight(1080);

      if (videoBitrate > 0) {
        final needBytes = (videoBitrate / 8) * profile.cacheSecs;
        if (needBytes > profile.demuxerMaxBytes * 0.9) {
          final bumped = liveSportsBumpAtvCacheTier(profile);
          if (bumped.tier != profile.tier) {
            profile = bumped;
          } else if (profile.tier == 'uhd' || profile.tier == 'fhd') {
            debugPrint(
              '[IPTV Player] live/sports/uhd demuxer may still byte-bind at '
              '${(videoBitrate / 1e6).toStringAsFixed(1)}Mbps',
            );
          }
        }
      }
    }

    await p.setProperty('cache-secs', '${profile.cacheSecs}');
    await p.setProperty('demuxer-readahead-secs', '${profile.readaheadSecs}');
    await p.setProperty('demuxer-max-bytes', '${profile.demuxerMaxBytes}');
    await p.setProperty('demuxer-max-back-bytes', '0');
    await p.setProperty('cache-pause', 'no');
    await p.setProperty('cache-pause-initial', 'no');
    if (_s._atvMediaKit) {
      await p.setProperty('cache-on-disk', 'no');
    }

    _s._liveCacheTierApplied = true;
    debugPrint(
      '[IPTV Player] MediaKit cache profile=live/sports/${profile.tier} '
      'height=$height bitrate=${videoBitrate > 0 ? (videoBitrate / 1e6).toStringAsFixed(1) : "?"}Mbps '
      'cache=${profile.cacheSecs}s bytes=${profile.demuxerMaxBytes}',
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
        // Forja ATV vo=mediacodec_embed needs mediacodec.
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
      } else if (_liveSportsSurface) {
        // Live Sports desktop = v1.5.36: pin hwdec / vd-lavc.
        await p.setProperty('hwdec', _useSoftwareDecode ? 'no' : 'auto-safe');
        await restoreMediaKitAudioOutput(p);
        await p.setProperty(
          'vd-lavc-dr',
          _useSoftwareDecode ? 'no' : 'yes',
        );
      } else {
        // IPTV Forja live desktop/phone/Windows: no hwdec / vd-lavc-dr pins.
        await restoreMediaKitAudioOutput(p);
      }

      final liveMk = _livePlaybackProfile && !_s.widget.vodPlayback;
      final sportsMk = liveMk && _liveSportsSurface;
      if (!liveMk || sportsMk) {
        await p.setProperty('vd-lavc-threads', '0');
      }

      // Sports: 15s (v1.5.36). IPTV Forja live: 30s for lavf reconnect.
      await p.setProperty('network-timeout', sportsMk ? '15' : '30');

      // Cache: sports = pre–RFC-113 cushion; IPTV = RFC-113 live/forja.
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
      } else if (sportsMk) {
        // Live Sports / Stremio / liveEngine — exact v1.5.36 cushion.
        var coldSecs = 30;
        var coldReadahead = 20;
        var coldBytes = 150000000;
        var coldLabel = 'live/sports';
        if (_s._atvMediaKit) {
          final fhd = liveSportsAtvCacheTierForHeight(1080);
          coldSecs = fhd.cacheSecs;
          coldReadahead = fhd.readaheadSecs;
          coldBytes = fhd.demuxerMaxBytes;
          coldLabel = 'live/sports (fhd-safe)';
          final overrideSecs = await SettingsService().getIptvLiveBufferSecs();
          if (overrideSecs > 0) {
            final forced =
                SettingsService.iptvLiveBufferProfileForSecs(overrideSecs);
            coldSecs = forced.cacheSecs;
            coldReadahead = forced.readaheadSecs;
            coldBytes = forced.demuxerMaxBytes;
            coldLabel = 'live/sports (${forced.tier})';
          }
        }
        debugPrint('[IPTV Player] MediaKit cache profile=$coldLabel');
        await p.setProperty('cache-secs', '$coldSecs');
        await p.setProperty('demuxer-readahead-secs', '$coldReadahead');
        await p.setProperty('demuxer-max-bytes', '$coldBytes');
        await p.setProperty('demuxer-max-back-bytes', '0');
        await p.setProperty('audio-buffer', '1.0');
        await p.setProperty('cache-pause', 'no');
        await p.setProperty('cache-pause-initial', 'no');
      } else {
        // IPTV Forja live: 30s / 8s readahead / 128MiB / 64MiB back / cache-pause=no.
        const coldSecs = 30;
        const coldReadahead = 8;
        const coldBytes = 128 * 1024 * 1024;
        const coldBackBytes = 64 * 1024 * 1024;
        debugPrint('[IPTV Player] MediaKit cache profile=live/forja');
        await p.setProperty('cache-secs', '$coldSecs');
        await p.setProperty('demuxer-readahead-secs', '$coldReadahead');
        await p.setProperty('demuxer-max-bytes', '$coldBytes');
        await p.setProperty('demuxer-max-back-bytes', '$coldBackBytes');
        await p.setProperty('cache-pause', 'no');
        await p.setProperty('cache-pause-initial', 'no');
        await p.setProperty('cache-pause-wait', '0');
        // ATV memory-only; desktop/phone disk cache for track swaps.
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
        // Live seek/sync (scrub + keep-open EOF during seek).
        await p.setProperty('force-seekable', 'yes');
        await p.setProperty('initial-audio-sync', 'yes');
        await p.setProperty('hr-seek', 'yes');
      }

      await p.setProperty('sub-auto', 'all');
      await p.setProperty('sub-visibility', 'no');

      // Sports: keep-open=yes (v1.5.36). IPTV Forja: always so brief EOF survives.
      await p.setProperty('keep-open', sportsMk ? 'yes' : 'always');
      if (!liveMk || sportsMk) {
        await p.setProperty('keep-open-pause', 'no');
      }

      // Live Sports = v1.5.36: VLC UA + hls-bitrate + rtsp.
      // IPTV Forja live: no UA / hls / rtsp pins. VOD still sets them.
      if (sportsMk) {
        await p.setProperty(
          'hls-bitrate',
          _useSoftwareDecode ? '3500000' : 'max',
        );
        await p.setProperty('rtsp-transport', 'tcp');
        await p.setProperty('user-agent', _PtPlayerScreenState._ua);
      } else if (!liveMk) {
        await p.setProperty('hls-bitrate', 'max');
        await p.setProperty('rtsp-transport', 'tcp');
        if (_s.widget.vodPlayback || !_livePlaybackProfile) {
          await p.setProperty('user-agent', _PtPlayerScreenState._ua);
        }
      }

      // FFmpeg reconnect — applied after open for VOD; live sets around open.
      if (_s.widget.vodPlayback) {
        final vodUrl = _s._sources.isEmpty
            ? null
            : _s._sources[_s._sourceIdx.clamp(0, _s._sources.length - 1)].url;
        await _applyStreamLavfReconnect(p, streamUrl: vodUrl);
      }

      // Sports = v1.5.36 (no +igndts). IPTV / VOD keep +igndts (issue 273).
      await p.setProperty(
        'demuxer-lavf-o',
        sportsMk
            ? 'fflags=+discardcorrupt+genpts,'
                'probesize=5000000,'
                'analyzeduration=5000000'
            : 'fflags=+discardcorrupt+genpts+igndts,'
                'probesize=5000000,'
                'analyzeduration=5000000',
      );
    } catch (e) {
      debugPrint('[IPTV Player] tunables failed: $e');
    }
  }

}
