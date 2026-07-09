import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide_panel.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_search_overlay.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_player_stats_panel.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';

/// Single source for the IPTV player.
class IptvPlaySource {
  final String url;
  final String label;
  const IptvPlaySource({required this.url, required this.label});
}

/// Dedicated IPTV player using libmpv (media_kit). Includes:
///   • Watchdog (3 detectors): long buffering, frozen position, ready-but-not-playing
///   • Tiered recovery: seek-zero → reload → stop+open → recreate
///   • Multi-source rotation
///   • Backoff retries with healthy-streak reset
///   • Pretty responsive overlay UI
class IptvPtPlayerScreen extends StatefulWidget {
  final List<IptvPlaySource> sources;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final IptvChannelGuide? channelGuide;

  const IptvPtPlayerScreen({
    super.key,
    required this.sources,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.channelGuide,
  });

  /// Convenience: build for a single Xtream stream.
  factory IptvPtPlayerScreen.singleStream({
    Key? key,
    required String url,
    required IptvStream stream,
    String? portalName,
    IptvChannelGuide? channelGuide,
  }) =>
      IptvPtPlayerScreen(
        key: key,
        sources: [IptvPlaySource(url: url, label: portalName ?? 'Source 1')],
        title: stream.name,
        subtitle: portalName,
        logoUrl: stream.icon.isEmpty ? null : stream.icon,
        channelGuide: channelGuide,
      );

  /// Convenience: build for a list of channel hits (multi-source).
  factory IptvPtPlayerScreen.fromHits({
    Key? key,
    required List<ChannelHit> hits,
    required String title,
    String? logoUrl,
  }) =>
      IptvPtPlayerScreen(
        key: key,
        title: title,
        logoUrl: logoUrl,
        sources: hits
            .asMap()
            .entries
            .map((e) => IptvPlaySource(
                  url: e.value.streamUrl,
                  label: e.value.portal.name.isNotEmpty
                      ? e.value.portal.name
                      : 'Source ${e.key + 1}',
                ))
            .toList(),
      );

  @override
  State<IptvPtPlayerScreen> createState() => _IptvPtPlayerScreenState();
}

class _IptvPtPlayerScreenState extends State<IptvPtPlayerScreen>
    with WidgetsBindingObserver {
  late Player _player;
  late VideoController _controller;

  StreamSubscription? _posSub, _playingSub, _bufferingSub, _errorSub, _logSub;
  StreamSubscription? _durSub, _bufferSub;

  // VOD seekbar state — duration is 0 for live streams, > 0 for VOD.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _isSeeking = false;
  double _seekPreview = 0.0;
  bool get _isVod => _duration.inSeconds > 1;

  late List<IptvPlaySource> _sources;
  late String _title;
  String? _subtitle;
  String? _logoUrl;

  int _sourceIdx = 0;
  bool _playing = false;
  bool _buffering = false;
  bool _userPlayWhenReady = true;
  String? _statusBanner;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  bool _guideVisible = false;
  bool _searchVisible = false;
  late String _selectedGroupId;
  late String _currentChannelId;
  double _subtitleDelay = 0;

  // Watchdog state
  Timer? _watchdog;
  Duration _lastPos = Duration.zero;
  DateTime _lastPosChange = DateTime.now();
  DateTime? _bufferingSince;
  DateTime? _readyNotPlayingSince;
  // When the current source was last opened. Used by detector 4 to find
  // "playing=true but never produced a first frame" — the classic
  // CDN-dropped-mid-handshake hang where mpv neither buffers nor errors.
  DateTime _openedAt = DateTime.now();

  // Audio state
  double _volume = 100.0; // 0..100 (mpv scale)
  double _volumeBeforeMute = 100.0;
  bool _muted = false;
  bool _showVolumeSlider = false;
  Timer? _hideVolumeTimer;

  // Fullscreen state (desktop only — mobile is permanently immersive)
  bool _isFullscreen = false;
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // Retry state
  int _retryAttempt = 0;
  DateTime? _lastRecoveryAt;
  // When the user explicitly paused (so play-after-pause can rejoin live edge)
  // ignore: unused_field
  DateTime? _pausedAt;
  final List<int> _backoffMs = const [500, 1000, 2000, 3000, 4000, 6000, 8000, 8000];
  static const int _maxRetries = 8;
  static const Duration _healthyStreakNeeded = Duration(seconds: 6);
  // After exhausting per-source retries on a single-source stream, keep
  // probing every N seconds forever — live IPTV channels routinely come
  // back from short outages, so we don't want to give up.
  static const Duration _coldRetryInterval = Duration(seconds: 15);

  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  bool _disposed = false;
  bool _playerAlive = false;

  static const _playerConfiguration = PlayerConfiguration(
    bufferSize: 64 * 1024 * 1024,
    logLevel: MPVLogLevel.warn,
    libass: true,
  );

  void _initPlayerInstances() {
    _player = Player(configuration: _playerConfiguration);
    _controller = VideoController(_player);
    _playerAlive = true;
    _bind();
  }

  @override
  void initState() {
    super.initState();
    _sources = List<IptvPlaySource>.from(widget.sources);
    _title = widget.title;
    _subtitle = widget.subtitle;
    _logoUrl = widget.logoUrl;
    final guide = widget.channelGuide;
    _selectedGroupId = guide?.initialGroupId ?? '';
    _currentChannelId = guide?.initialChannelId ?? '';
    WidgetsBinding.instance.addObserver(this);
    _initOrientationAndChrome();
    WakelockPlus.enable();
    _initPlayerInstances();
    _applyMpvTunables();
    _openCurrent();
    _startWatchdog();
    _scheduleHideControls();
  }

  /// Set libmpv/FFmpeg properties that turn media_kit into a real IPTV player.
  /// Sources: mpv issue #5793, char101 reload-on-stall pattern, FFmpeg
  /// reconnect_* options. Tested for HLS / MPEG-TS / RTSP / Xtream live.
  Future<void> _applyMpvTunables() async {
    try {
      final p = _player.platform;
      if (p is! NativePlayer) return;

      // Network: fail fast so the watchdog can step in
      await p.setProperty('network-timeout', '15');

      // Cache: prioritise SMOOTHNESS over live-edge latency. We aggressively
      // pre-buffer ~30 s of forward data and let mpv hold up to 150 MB so
      // brief upstream hiccups never reach the screen. cache-pause stays
      // OFF — we'd rather let the decoder skip frames than show a spinner.
      await p.setProperty('cache', 'yes');
      await p.setProperty('cache-secs', '30');
      await p.setProperty('demuxer-readahead-secs', '20');
      await p.setProperty('demuxer-max-bytes', '150000000');
      await p.setProperty('demuxer-max-back-bytes', '25000000');
      await p.setProperty('cache-pause', 'no');
      await p.setProperty('cache-pause-initial', 'no');
      // Larger audio buffer too — audio underruns are the most jarring
      // form of buffering on IPTV feeds.
      await p.setProperty('audio-buffer', '1.0');

      await p.setProperty('sub-auto', 'all');
      await p.setProperty('sub-visibility', 'no');

      // Don't quit on EOF / brief disconnect — let us recover
      await p.setProperty('keep-open', 'yes');
      await p.setProperty('keep-open-pause', 'no');

      // HLS: pick best variant
      await p.setProperty('hls-bitrate', 'max');

      // RTSP over TCP — way more reliable on flaky networks
      await p.setProperty('rtsp-transport', 'tcp');

      // Many Xtream panels gate streams on a VLC user-agent
      await p.setProperty('user-agent', _ua);

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
      //   probesize=5MB, analyzeduration=5s — big enough for ffmpeg to
      //                                       detect real codec params.
      //   discardcorrupt                    — drop junk packets silently.
      // We deliberately DO NOT set fflags=+nobuffer here. +nobuffer tells
      // ffmpeg to push frames the instant they arrive, which is great for
      // sub-second-latency live but means any upstream jitter ⇒ visible
      // buffer underrun. For IPTV we'd rather have ~1–2 s of demuxer
      // smoothing than a spinner every 30 s.
      // HLS-only options (live_start_index, m3u8_hold_counters, etc.) are
      // intentionally not set — when the stream isn't HLS, libavformat
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
    // Don't auto-enter fullscreen or force landscape — the player opens in a
    // normal window/portrait, and the user enters fullscreen explicitly via
    // the fullscreen button.
    _isFullscreen = false;
  }

  Future<void> _toggleFullscreen() async {
    if (_isDesktop) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (isFull) {
          // Leaving fullscreen — also drop maximize so the user gets a real window.
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
        if (mounted) setState(() => _isFullscreen = !isFull);
      } catch (_) {}
    } else {
      final goFull = !_isFullscreen;
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
      if (mounted) setState(() => _isFullscreen = goFull);
    }
    _scheduleHideControls();
  }

  void _bind() {
    _posSub = _player.stream.position.listen((pos) {
      if (!mounted || _disposed) return;
      if (!_isSeeking && pos != _position) {
        // Don't pump setState on every tick if duration is 0 (pure live).
        if (_isVod) {
          setState(() => _position = pos);
        } else {
          _position = pos;
        }
      }
      if (pos != _lastPos) {
        _lastPos = pos;
        _lastPosChange = DateTime.now();
        // Healthy streak — reset retry count if we've been ticking smoothly
        if (_retryAttempt > 0 &&
            DateTime.now().difference(_lastPosChange) <
                const Duration(milliseconds: 200) &&
            _statusBanner == null) {
          // we'll evaluate streak in watchdog
        }
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (!mounted || _disposed) return;
      if (dur != _duration) setState(() => _duration = dur);
    });
    _bufferSub = _player.stream.buffer.listen((buf) {
      if (!mounted || _disposed) return;
      _buffered = buf;
    });
    _playingSub = _player.stream.playing.listen((p) {
      if (!mounted || _disposed) return;
      setState(() => _playing = p);
      if (p) {
        _readyNotPlayingSince = null;
      } else if (_userPlayWhenReady) {
        // libmpv silently went paused while the user wants playback. On a
        // live IPTV stream this is the classic "feed died, mpv hit EOF and
        // toggled pause=yes" symptom. Poke play() once immediately — if it
        // takes, great; if it doesn't, the watchdog will hard-reload us.
        _readyNotPlayingSince = DateTime.now();
        Future.microtask(() async {
          if (!mounted || !_userPlayWhenReady || _playing) return;
          try {
            await _player.play();
          } catch (_) {}
        });
      }
    });
    _bufferingSub = _player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
      if (b) {
        _bufferingSince ??= DateTime.now();
      } else {
        _bufferingSince = null;
      }
    });
    _errorSub = _player.stream.error.listen((err) {
      final msg = err.toString();
      debugPrint('[IPTV Player] error: $msg');
      // Benign mpv chatter we don't want to restart the stream over:
      //  - "Cannot seek in this stream" / "force-seekable=yes"  → pure-live
      //    stream, the live-edge seek failed (harmless).
      //  - "Expected '=' and a value"                          → libav option
      //    parser warning for HLS-only opts on a non-HLS stream.
      final lower = msg.toLowerCase();
      if (lower.contains('cannot seek') ||
          lower.contains('force-seekable') ||
          lower.contains("expected '=' and a value")) {
        return;
      }
      // "Stream ends prematurely" / "End of file" on a live HTTP feed means
      // the CDN dropped the TCP connection mid-stream. mpv's reconnect_at_eof
      // only fires on clean EOF, not on premature close, so we have to force
      // a full player recreation to get a fresh socket — gentle seek/reopen
      // attempts will just keep failing on the same dead connection.
      if (lower.contains('ends prematurely') ||
          lower.contains('end of file') ||
          lower.contains('connection reset')) {
        _triggerRecovery(reason: 'connection dropped: $msg', forceHard: true);
        return;
      }
      _triggerRecovery(reason: 'error: $msg');
    });
    // mpv log stream catches conditions that don't surface as `error`
    // events — most importantly, ffmpeg's "http: Stream ends prematurely"
    // (CDN dropped the TCP connection mid-stream). Without this, the
    // watchdog only sees the resulting position freeze and tries gentle
    // recoveries that can't fix a dead socket.
    _logSub = _player.stream.log.listen((l) {
      if (l.level != 'error' && l.level != 'fatal' && l.level != 'warn') {
        return;
      }
      final text = l.text.toLowerCase();
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

  Future<void> _openCurrent() async {
    final src = _sources[_sourceIdx];
    // Connect silently — no banner. The buffering indicator (if any) will
    // appear naturally while the stream loads.
    try {
      await _player.open(
        Media(src.url, httpHeaders: const {'User-Agent': _ua}),
      );
      await _player.play();
      _userPlayWhenReady = true;
      _pausedAt = null;
      _lastPos = Duration.zero;
      _lastPosChange = DateTime.now();
      _openedAt = DateTime.now();
      // For HLS streams that DO expose a DVR window, jump to the live edge
      // shortly after open so we never replay stale buffered packets.
      _scheduleJumpToLive();
      // Clear banner after a short successful run
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (_playing && !_buffering) {
          setState(() => _statusBanner = null);
        }
      });
    } catch (e) {
      _triggerRecovery(reason: 'open failed: $e');
    }
  }

  /// Best-effort jump to the live edge after a (re)open.
  /// Only fires when the stream actually exposes a DVR window (seekable=yes
  /// AND a finite duration). On pure-live streams seeking emits a noisy
  /// "Cannot seek in this stream / force-seekable=yes" error that the
  /// watchdog would otherwise treat as a failure.
  void _scheduleJumpToLive() {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      try {
        final p = _player.platform;
        if (p is! NativePlayer) return;

        final seekableRaw = await p.getProperty('seekable');
        final durRaw = await p.getProperty('duration');
        final isSeekable = seekableRaw.toString().toLowerCase() == 'yes';
        final dur = double.tryParse(durRaw.toString()) ?? 0.0;
        if (!isSeekable || dur <= 0) {
          // Pure live — nothing to seek to.
          return;
        }

        // Drop any data that piled up while paused / mid-recovery, then
        // jump to the live edge of the DVR window.
        await p.command(['drop-buffers']);
        await p.command(['seek', '99999', 'absolute']);
      } catch (_) {
        // Best-effort — ignore.
      }
    });
  }

  void _startWatchdog() {
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _disposed) return;
      final now = DateTime.now();

      // Healthy streak resets retry counter
      if (_retryAttempt > 0 &&
          _playing &&
          !_buffering &&
          now.difference(_lastPosChange) < const Duration(milliseconds: 1500) &&
          _lastRecoveryAt != null &&
          now.difference(_lastRecoveryAt!) > _healthyStreakNeeded) {
        debugPrint('[IPTV Watchdog] healthy streak — resetting retries');
        _retryAttempt = 0;
        _lastRecoveryAt = null;
        if (mounted) setState(() => _statusBanner = null);
      }

      // Detector 1: long buffering. Mid-stream stalls with a 30 s buffer
      // shouldn't last more than ~10 s; before the first frame, the slow
      // initial connect to a remote `.ts` feed needs more grace.
      final bufferGrace = _lastPos > Duration.zero
          ? const Duration(milliseconds: 12000)
          : const Duration(milliseconds: 25000);
      if (_userPlayWhenReady &&
          _bufferingSince != null &&
          now.difference(_bufferingSince!) > bufferGrace) {
        _triggerRecovery(reason: 'buffering > ${bufferGrace.inSeconds}s');
        return;
      }
      // Detector 2: position frozen while playing.
      // CRITICAL gates to avoid false positives on initial connect:
      //  • !_buffering — if mpv reports buffering, position-not-advancing is
      //    expected and detector 1 is the right signal.
      //  • _lastPos > 0 — we must have received at least one decoded frame
      //    since the last open. Until first frame, mpv flips playing=true
      //    on play() but the position stream is silent; on slow streams
      //    the initial connect easily exceeds 8 s.
      if (_playing &&
          !_buffering &&
          _lastPos > Duration.zero &&
          now.difference(_lastPosChange) > const Duration(milliseconds: 8000)) {
        _triggerRecovery(reason: 'position frozen > 8s');
        return;
      }
      // Detector 3: should be playing but isn't. For LIVE IPTV, a sustained
      // self-pause (mpv flipped to pause=yes on its own) almost always means
      // the upstream feed ended — live TV doesn't end, ever, so this is
      // dead. Skip the gradual seek→reload backoff and go straight to a hard
      // reopen (forceHard:true).
      if (_userPlayWhenReady &&
          !_playing &&
          _readyNotPlayingSince != null &&
          now.difference(_readyNotPlayingSince!) >
              const Duration(milliseconds: 3000)) {
        _triggerRecovery(reason: 'silent self-pause > 3s', forceHard: true);
        return;
      }
      // Detector 4: opened but never produced a first frame. The classic
      // "CDN dropped the connection mid-handshake" hang where mpv keeps
      // playing=true, never flips buffering, never errors, just sits there
      // with position=0 forever. None of detectors 1-3 catch this:
      //   • detector 1 needs buffering=true (mpv may not set it)
      //   • detector 2 is gated on _lastPos > 0
      //   • detector 3 needs playing=false (mpv stays true)
      // 30 s is well past the 25 s initial-connect grace in detector 1.
      if (_userPlayWhenReady &&
          _lastPos == Duration.zero &&
          now.difference(_openedAt) > const Duration(seconds: 30)) {
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
    if (_disposed || _recoveryInFlight) return;
    final now = DateTime.now();
    if (_lastRecoveryAt != null &&
        now.difference(_lastRecoveryAt!) <
            const Duration(milliseconds: 1500)) {
      return; // throttle
    }
    _recoveryInFlight = true;
    _lastRecoveryAt = now;
    debugPrint(
        '[IPTV Watchdog] recovery (#${_retryAttempt + 1}, hard=$forceHard): $reason');

    try {
      if (_disposed) return;

      if (_retryAttempt >= _maxRetries) {
        // Rotate to the next source if we have one.
        if (_sourceIdx < _sources.length - 1) {
          _sourceIdx++;
          _retryAttempt = 0;
          if (mounted) {
            setState(() =>
                _statusBanner = 'Switching to ${_sources[_sourceIdx].label}…');
          }
          await _openCurrent();
          return;
        }
        // Single-source channel that won't connect. Don't give up — live
        // streams come back. Wipe the player completely and try again on a
        // long interval so we're not hammering a dead endpoint.
        if (mounted) {
          setState(() => _statusBanner =
              'Stream offline — retrying every ${_coldRetryInterval.inSeconds}s…');
        }
        await Future.delayed(_coldRetryInterval);
        if (_disposed) return;
        try {
          if (!await _recreatePlayer()) return;
        } catch (e) {
          debugPrint('[IPTV] cold-retry recreate failed: $e');
        }
        // Reset the retry ladder so the next ladder run gets fresh backoff.
        _retryAttempt = 0;
        if (_disposed || !_playerAlive) return;
        try {
          await _player.open(
            Media(_sources[_sourceIdx].url,
                httpHeaders: const {'User-Agent': _ua}),
          );
          await _player.play();
        } catch (e) {
          debugPrint('[IPTV] cold-retry open failed: $e');
        }
        if (mounted) setState(() {});
        _bufferingSince = null;
        _readyNotPlayingSince = null;
        _lastPos = Duration.zero;
        _lastPosChange = DateTime.now();
        _openedAt = DateTime.now();
        return;
      }

      _retryAttempt++;
      final delayIdx = (_retryAttempt - 1).clamp(0, _backoffMs.length - 1);
      final delay = _backoffMs[delayIdx];
      // Show what we're doing so the user isn't staring at a frozen spinner.
      if (mounted) {
        setState(() => _statusBanner =
            'Reconnecting\u2026 (attempt $_retryAttempt/$_maxRetries)');
      }

      await Future.delayed(Duration(milliseconds: delay));
      if (_disposed) return;

      // Fast path: silent self-pause on a live stream means the feed is
      // gone. A seek/reload won't bring it back — jump straight to the
      // "recreate the player" tier so we get a fully fresh socket.
      if (forceHard) {
        try {
          if (!await _recreatePlayer()) return;
          await _player.open(
            Media(_sources[_sourceIdx].url,
                httpHeaders: const {'User-Agent': _ua}),
          );
          await _player.play();
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] hard recreate failed: $e');
        }
      } else if (_retryAttempt <= 2) {
        try {
          await _player.seek(Duration.zero);
        } catch (_) {}
        try {
          await _player.open(
            Media(_sources[_sourceIdx].url,
                httpHeaders: const {'User-Agent': _ua}),
          );
          await _player.play();
        } catch (_) {}
      } else if (_retryAttempt <= 4) {
        try {
          await _player.stop();
        } catch (_) {}
        try {
          await _player.open(
            Media(_sources[_sourceIdx].url,
                httpHeaders: const {'User-Agent': _ua}),
          );
          await _player.play();
        } catch (_) {}
      } else {
        // Recreate
        try {
          if (!await _recreatePlayer()) return;
          await _player.open(
            Media(_sources[_sourceIdx].url,
                httpHeaders: const {'User-Agent': _ua}),
          );
          await _player.play();
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[IPTV] recreate failed: $e');
        }
      }
      _bufferingSince = null;
      _readyNotPlayingSince = null;
      _lastPos = Duration.zero;
      _lastPosChange = DateTime.now();
      _openedAt = DateTime.now();
    } finally {
      _recoveryInFlight = false;
    }
  }

  Future<bool> _recreatePlayer() async {
    await _disposePlayer();
    if (_disposed) return false;
    _initPlayerInstances();
    await _applyMpvTunables();
    return true;
  }

  Future<void> _cancelPlayerSubscriptions() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _playingSub?.cancel();
    await _bufferingSub?.cancel();
    await _errorSub?.cancel();
    await _logSub?.cancel();
    await _bufferSub?.cancel();
    _posSub = null;
    _durSub = null;
    _playingSub = null;
    _bufferingSub = null;
    _errorSub = null;
    _logSub = null;
    _bufferSub = null;
  }

  Future<void> _disposePlayer() async {
    if (!_playerAlive) return;
    _playerAlive = false;
    await _cancelPlayerSubscriptions();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
  }

  Future<void> _finalizeExit() async {
    while (_recoveryInFlight) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    await _disposePlayer();
  }

  void _switchSource(int idx) async {
    if (idx == _sourceIdx) return;
    setState(() {
      _sourceIdx = idx;
      _retryAttempt = 0;
    });
    await _openCurrent();
  }

  Future<void> _switchChannel(IptvGuideChannel ch) async {
    if (ch.id == _currentChannelId) return;
    final guide = widget.channelGuide;
    if (guide == null) return;

    String url;
    String label;
    if (ch.xtreamStream != null && guide.xtreamPortal != null) {
      url = IptvClient.streamUrl(guide.xtreamPortal!.portal, ch.xtreamStream!);
      label = guide.xtreamPortal!.name;
    } else if (ch.playUrl != null && ch.playUrl!.isNotEmpty) {
      url = ch.playUrl!;
      label = _sources.isNotEmpty ? _sources.first.label : 'M3U';
    } else {
      return;
    }

    final groupName = guide.groupById(ch.groupId)?.name;

    setState(() {
      _currentChannelId = ch.id;
      _selectedGroupId = ch.groupId;
      _sources = [IptvPlaySource(url: url, label: label)];
      _sourceIdx = 0;
      _retryAttempt = 0;
      _title = ch.name;
      _logoUrl = ch.logoUrl;
      _subtitle = groupName;
    });
    await _openCurrent();
  }

  void _toggleGuide() {
    if (widget.channelGuide == null) return;
    setState(() {
      _guideVisible = !_guideVisible;
      if (_guideVisible) {
        _searchVisible = false;
        _controlsVisible = true;
        _hideControlsTimer?.cancel();
      } else {
        _scheduleHideControls();
      }
    });
  }

  void _toggleSearch() {
    if (widget.channelGuide == null) return;
    setState(() {
      _searchVisible = !_searchVisible;
      if (_searchVisible) {
        _guideVisible = false;
        _controlsVisible = true;
        _hideControlsTimer?.cancel();
      } else {
        _scheduleHideControls();
      }
    });
  }

  void _onSearchChannelSelected(IptvGuideChannel ch) {
    setState(() => _searchVisible = false);
    _switchChannel(ch);
    _scheduleHideControls();
  }

  void _updateSubVisibility(SubtitleTrack track) {
    if (_player.platform is! NativePlayer) return;
    final on = track.id != 'no';
    (_player.platform as NativePlayer)
        .setProperty('sub-visibility', on ? 'yes' : 'no');
  }

  void _showAudioMenu(BuildContext anchorContext) {
    _scheduleHideControls();
    PlayerAudioMenu.show(
      context,
      player: _player,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
    );
  }

  void _showStatsMenu(BuildContext anchorContext) {
    _scheduleHideControls();
    IptvPlayerStatsPanel.show(
      context,
      player: _player,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
      snapshot: () => IptvPlayerStatsSnapshot(
        playing: _playing,
        buffering: _buffering,
        sourceLabel: _sources[_sourceIdx].label,
        retryAttempt: _retryAttempt,
        volume: _volume,
        buffered: _buffered,
      ),
    );
  }

  void _showSubtitleMenu(BuildContext anchorContext) {
    _scheduleHideControls();
    PlayerSubtitleMenu.show(
      context,
      player: _player,
      anchorContext: anchorContext,
      externalSubtitles: const [],
      selectedExternalSubUrl: null,
      isFetchingSubs: false,
      updateSubVisibility: _updateSubVisibility,
      onExternalUrlChanged: (_) {},
      onNativeSubtitleChanged: (_) {},
      loadOnlineSubtitle: (_) async {},
      onSubtitleSettings: _showSubtitleSettings,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
    );
  }

  void _showSubtitleSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Subtitle delay',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: Colors.white70),
                onPressed: () {
                  setDialog(() {
                    _subtitleDelay =
                        double.parse((_subtitleDelay - 0.1).toStringAsFixed(1));
                  });
                  if (_player.platform is NativePlayer) {
                    (_player.platform as NativePlayer).setProperty(
                      'sub-delay',
                      _subtitleDelay.toString(),
                    );
                  }
                },
              ),
              Text(
                '${_subtitleDelay.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              IconButton(
                icon: Icon(Icons.add, color: Colors.white70),
                onPressed: () {
                  setDialog(() {
                    _subtitleDelay =
                        double.parse((_subtitleDelay + 0.1).toStringAsFixed(1));
                  });
                  if (_player.platform is NativePlayer) {
                    (_player.platform as NativePlayer).setProperty(
                      'sub-delay',
                      _subtitleDelay.toString(),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (_guideVisible || _searchVisible) return;
    _hideControlsTimer =
        Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _hideControlsTimer?.cancel();
    _hideVolumeTimer?.cancel();
    unawaited(_finalizeExit());
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_isDesktop) {
      // Restore a normal (non-fullscreen, non-maximized) window when leaving.
      Future.microtask(() async {
        try {
          if (await windowManager.isFullScreen()) {
            await windowManager.setFullScreen(false);
          }
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          }
        } catch (_) {}
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.shortestSide < 600;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Center(
              child: Video(
                controller: _controller,
                fit: BoxFit.contain,
                controls: NoVideoControls,
              ),
            ),
            // Reconnect/buffering banner
            if (_buffering || _statusBanner != null) _buildBanner(),
            // Top bar + bottom controls (below guide when open)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _controlsVisible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_controlsVisible || _guideVisible || _searchVisible,
                child: _buildOverlay(compact),
              ),
            ),
            if (_searchVisible && widget.channelGuide != null)
              IptvChannelSearchOverlay(
                guide: widget.channelGuide!,
                currentChannelId: _currentChannelId,
                onChannelSelected: _onSearchChannelSelected,
                onClose: () => setState(() {
                  _searchVisible = false;
                  _scheduleHideControls();
                }),
              ),
            if (_guideVisible && widget.channelGuide != null)
              IptvChannelGuidePanel(
                guide: widget.channelGuide!,
                selectedGroupId: _selectedGroupId,
                currentChannelId: _currentChannelId,
                onGroupSelected: (id) {
                  setState(() => _selectedGroupId = id);
                },
                onChannelSelected: _switchChannel,
                onClose: () => setState(() => _guideVisible = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IptvShellStyle.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IptvShellStyle.accent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _statusBanner ?? 'Buffering…',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(bool compact) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0, 0.25, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(compact),
            const Spacer(),
            if (_isVod) _buildSeekbar(compact),
            _buildBottomBar(compact),
          ],
        ),
      ),
    );
  }

  double _topBarTopPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 8;
    }
    return 8;
  }

  double _topBarLeftPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop && Platform.isMacOS) {
      return DesktopWindowChrome.leadingInset(context) + 4;
    }
    return 8;
  }

  Widget _buildTopBar(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _topBarLeftPadding(context),
        _topBarTopPadding(context),
        16,
        0,
      ),
      child: Row(
        children: [
          ForjaPlainIcon(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
            color: Colors.white,
            size: 26,
            hoverScale: 1.15,
            tooltip: 'Back',
          ),
          if ((_logoUrl ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _logoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.overlayTitle.copyWith(
                    fontSize: compact ? 18 : 22,
                  ),
                ),
                if ((_subtitle ?? '').isNotEmpty)
                  Text(
                    _subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (_sources.length > 1) ...[
            const SizedBox(width: 8),
            _SourceChip(
              label: _sources[_sourceIdx].label,
              onTap: _showSourcePicker,
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  //  VOD SEEKBAR — only shown when duration > 0 (Xtream movies / series)
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildSeekbar(bool compact) {
    final totalMs = _duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();
    final currentMs = _isSeeking
        ? _seekPreview
        : _position.inMilliseconds.toDouble().clamp(0.0, totalMs);
    final shownPos = Duration(milliseconds: currentMs.toInt());

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 2 : 4,
      ),
      child: Row(
        children: [
          // Current time
          SizedBox(
            width: compact ? 56 : 64,
            child: Text(
              _fmtDur(shownPos),
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [
                  Shadow(blurRadius: 6, color: Colors.black87),
                ],
              ),
            ),
          ),
          // Slider
          Expanded(
            child: SliderTheme(
              data: IptvShellStyle.sliderTheme(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 3,
                ),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: currentMs.clamp(0.0, totalMs),
                min: 0,
                max: totalMs,
                onChangeStart: (v) {
                  setState(() {
                    _isSeeking = true;
                    _seekPreview = v;
                  });
                  _hideControlsTimer?.cancel();
                },
                onChanged: (v) {
                  setState(() => _seekPreview = v);
                },
                onChangeEnd: (v) async {
                  final target = Duration(milliseconds: v.toInt());
                  setState(() {
                    _isSeeking = false;
                    _position = target;
                  });
                  try {
                    await _player.seek(target);
                  } catch (_) {}
                  _scheduleHideControls();
                },
              ),
            ),
          ),
          // Total time
          SizedBox(
            width: compact ? 56 : 64,
            child: Text(
              _fmtDur(_duration),
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                color: Colors.white70,
                fontSize: compact ? 12 : 13,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [
                  Shadow(blurRadius: 6, color: Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDur(Duration d) {
    final s = d.inSeconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  Widget _buildBottomBar(bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24, vertical: compact ? 12 : 18),
      child: Row(
        children: [
          _RoundIcon(
            icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            big: true,
            onTap: () async {
              if (_playing) {
                _userPlayWhenReady = false;
                _pausedAt = DateTime.now();
                await _player.pause();
              } else {
                _userPlayWhenReady = true;
                _pausedAt = null;
                // Always just resume — never throw away buffered data on
                // play. If the user paused specifically to *let the stream
                // buffer*, blowing the cache and reopening would be the
                // exact opposite of what they want. If the buffer is too
                // stale to play, the watchdog will recover us.
                await _player.play();
              }
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 14),
          _RoundIcon(
            icon: Icons.replay_rounded,
            onTap: () async {
              _retryAttempt = 0;
              await _openCurrent();
              _scheduleHideControls();
            },
          ),
          const SizedBox(width: 14),
          // Mute toggle
          _RoundIcon(
            icon: _muted || _volume == 0
                ? Icons.volume_off_rounded
                : (_volume < 40
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded),
            onTap: _toggleMute,
            onLongPress: () {
              setState(() => _showVolumeSlider = !_showVolumeSlider);
              _scheduleHideVolumeSlider();
              _scheduleHideControls();
            },
          ),
          // Volume slider (responsive: shrinks on small screens)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: SizedBox(
              width: _showVolumeSlider ? (compact ? 110 : 160) : 0,
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SliderTheme(
                    data: IptvShellStyle.sliderTheme(context).copyWith(
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _volume.clamp(0.0, 100.0),
                      min: 0,
                      max: 100,
                      onChanged: (v) {
                        setState(() {
                          _volume = v;
                          _muted = v == 0;
                        });
                        _player.setVolume(v);
                        _scheduleHideVolumeSlider();
                        _scheduleHideControls();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Builder(
            builder: (btnCtx) => _RoundIcon(
              icon: Icons.subtitles_outlined,
              onTap: () => _showSubtitleMenu(btnCtx),
            ),
          ),
          const SizedBox(width: 14),
          Builder(
            builder: (btnCtx) => _RoundIcon(
              icon: Icons.audiotrack_rounded,
              onTap: () => _showAudioMenu(btnCtx),
            ),
          ),
          const SizedBox(width: 14),
          Builder(
            builder: (btnCtx) => _RoundIcon(
              icon: Icons.monitor_heart_outlined,
              onTap: () => _showStatsMenu(btnCtx),
            ),
          ),
          const Spacer(),
          if (widget.channelGuide != null) ...[
            _RoundIcon(
              icon: Icons.search_rounded,
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 14),
            _RoundIcon(
              icon: Icons.grid_view_rounded,
              onTap: _toggleGuide,
            ),
            const SizedBox(width: 14),
          ],
          if (_sources.length > 1)
            _RoundIcon(
              icon: Icons.swap_horiz_rounded,
              onTap: _showSourcePicker,
            ),
          if (_sources.length > 1) const SizedBox(width: 14),
          _RoundIcon(
            icon: _isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            onTap: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      if (_muted || _volume == 0) {
        _muted = false;
        _volume = _volumeBeforeMute > 0 ? _volumeBeforeMute : 100.0;
      } else {
        _volumeBeforeMute = _volume;
        _muted = true;
        _volume = 0;
      }
      _showVolumeSlider = true;
    });
    _player.setVolume(_volume);
    _scheduleHideVolumeSlider();
    _scheduleHideControls();
  }

  void _scheduleHideVolumeSlider() {
    _hideVolumeTimer?.cancel();
    _hideVolumeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showVolumeSlider = false);
    });
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: IptvShellStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Choose source',
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 22),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sources.length,
                  itemBuilder: (_, i) {
                    final s = _sources[i];
                    final active = i == _sourceIdx;
                    return ListTile(
                      leading: Icon(
                        active ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: active ? IptvShellStyle.accent : Colors.white54,
                      ),
                      title: Text(
                        s.label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        s.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _switchSource(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool big;
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 44.0;
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: big ? 32 : 22),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SourceChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: IptvShellStyle.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded,
                color: IptvShellStyle.accent, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}