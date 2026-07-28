import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_guide_epg.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide_panel.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_search_overlay.dart';
import 'package:forja/features/iptv/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/channel_guide/iptv_player_stats_panel.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/features/iptv/iptv/providers/iptv_player_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shell/shell_bus.dart';

part 'iptv_pt_player_engine.dart';
part 'iptv_pt_player_ui.dart';
part 'iptv_pt_player_widgets.dart';

/// True for live IPTV URLs (Xtream `/live/…`, M3U, unknown). False for Xtream VOD.
@visibleForTesting
bool iptvExoUrlLooksLive(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('/movie/') || lower.contains('/series/')) return false;
  return true;
}

/// Single source for the IPTV player.
class IptvPlaySource {
  final String url;
  final String label;
  const IptvPlaySource({required this.url, required this.label});
}

/// Dedicated IPTV player. Android uses Settings → Built-in engine (ExoPlayer or
/// MediaKit); other platforms use libmpv (media_kit). Includes:
///   • Watchdog (3 detectors): long buffering, frozen position, ready-but-not-playing
///   • Tiered recovery: seek-zero → reload → stop+open → recreate
///   • Multi-source rotation
///   • Backoff retries with healthy-streak reset
///   • Pretty responsive overlay UI
class IptvPtPlayerScreen extends ConsumerStatefulWidget {
  final List<IptvPlaySource> sources;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final IptvChannelGuide? channelGuide;
  /// Fired when the in-player guide tunes a different Xtream channel.
  final ValueChanged<IptvStream>? onChannelChanged;
  /// When set on Android, boot with this engine instead of Settings.
  /// Live Matches handoff forces Exo so MediaKit is not stuck on proxy HTML.
  final BuiltInPlayerEngine? forceBuiltInEngine;

  const IptvPtPlayerScreen({
    super.key,
    required this.sources,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.channelGuide,
    this.onChannelChanged,
    this.forceBuiltInEngine,
  });

  /// Convenience: build for a single Xtream stream.
  factory IptvPtPlayerScreen.singleStream({
    Key? key,
    required String url,
    required IptvStream stream,
    String? portalName,
    IptvChannelGuide? channelGuide,
    ValueChanged<IptvStream>? onChannelChanged,
  }) => IptvPtPlayerScreen(
    key: key,
    sources: [IptvPlaySource(url: url, label: portalName ?? 'Source 1')],
    title: stream.name,
    subtitle: portalName,
    logoUrl: stream.icon.isEmpty ? null : stream.icon,
    channelGuide: channelGuide,
    onChannelChanged: onChannelChanged,
  );

  /// Convenience: build for a list of channel hits (multi-source).
  factory IptvPtPlayerScreen.fromHits({
    Key? key,
    required List<ChannelHit> hits,
    required String title,
    String? logoUrl,
  }) => IptvPtPlayerScreen(
    key: key,
    title: title,
    logoUrl: logoUrl,
    sources: hits
        .asMap()
        .entries
        .map(
          (e) => IptvPlaySource(
            url: e.value.streamUrl,
            label: e.value.portal.displayLabel,
          ),
        )
        .toList(),
  );

  @override
  ConsumerState<IptvPtPlayerScreen> createState() =>
      _IptvPtPlayerScreenState();
}

class _IptvPtPlayerScreenState extends ConsumerState<IptvPtPlayerScreen>
    with WidgetsBindingObserver, _IptvPtPlayerEngine, _IptvPtPlayerUi {
  static int _nextExoViewId = 1;

  /// When true, IPTV uses Media3 ExoPlayer; otherwise media_kit.
  /// Android reads [SettingsService.getBuiltInPlayerEngine] at boot / Player menu.
  bool _exoBackend = false;
  int? _exoViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _exoEventSub;

  Player? _player;
  VideoController? _controller;
  bool _playerReady = false;
  int _videoEpoch = 0;
  bool _softwareDecodeForced = false;

  /// Phone MediaKit: software decode (some MediaCodec paths flake).
  /// Android TV MediaKit: keep HW + [vo=mediacodec_embed] (Impeller off in app).
  bool _androidMediaKitSafeMode = false;

  bool get _atvMediaKit =>
      !_exoBackend && !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;

  /// Windows D3D11 / ANGLE + live IPTV: HW decode plays ~15–20s then sticks
  /// the last frame with no reconnect banner. Force software from boot.
  bool get _windowsSoftwareDecode => !kIsWeb && Platform.isWindows;

  /// Probed after each open - pure-live feeds must never be seek()'d.
  bool _streamSeekable = false;

  StreamSubscription? _posSub, _playingSub, _bufferingSub, _errorSub, _logSub;
  StreamSubscription? _durSub, _bufferSub;

  // VOD seekbar state - duration is 0 for live streams, > 0 for VOD.
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
  final FocusNode _playerTvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'iptv-player-seek');

  bool _guideVisible = false;
  bool _searchVisible = false;
  /// First TV Back focused the Back control — next Back exits even before
  /// the post-frame [requestFocus] lands.
  bool _tvBackExitArmed = false;
  late String _selectedGroupId;
  late String _currentChannelId;
  IptvGuideEpgCache? _epgCache;

  // Watchdog state
  Timer? _watchdog;
  Duration _lastPos = Duration.zero;
  DateTime _lastPosChange = DateTime.now();
  DateTime? _bufferingSince;
  DateTime? _readyNotPlayingSince;
  // When the current source was last opened. Used by detector 4 to find
  // "playing=true but never produced a first frame" - the classic
  // CDN-dropped-mid-handshake hang where mpv neither buffers nor errors.
  DateTime _openedAt = DateTime.now();

  // Audio state — desktop/phone chrome has mute + hover slider; TV uses
  // hardware volume keys only (no volume button in the transport row).
  double _volume = 100.0; // 0..100 (mpv scale)
  double _volumeBeforeMute = 100.0;
  bool _muted = false;
  bool _showVolumeSlider = false;
  bool _volumeHovering = false;
  Timer? _hideVolumeTimer;

  // Fullscreen state (desktop only - mobile is permanently immersive)
  bool _isFullscreen = false;
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // Picture-in-picture (same PipService as the movie player)
  bool _isPipMode = false;
  bool _pipHover = false;
  StreamSubscription<bool>? _pipSub;

  // Retry state
  int _retryAttempt = 0;
  DateTime? _lastRecoveryAt;
  /// One-shot Exo ↔ MediaKit swap after unrecognized-format errors.
  bool _formatEngineSwapped = false;
  // When the user explicitly paused (so play-after-pause can rejoin live edge)
  // ignore: unused_field
  DateTime? _pausedAt;
  final List<int> _backoffMs = const [
    500,
    1000,
    2000,
    3000,
    4000,
    6000,
    8000,
    8000,
  ];
  static const int _maxRetries = 8;
  static const Duration _healthyStreakNeeded = Duration(seconds: 6);
  // After exhausting per-source retries on a single-source stream, keep
  // probing every N seconds forever - live IPTV channels routinely come
  // back from short outages, so we don't want to give up.
  static const Duration _coldRetryInterval = Duration(seconds: 15);

  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  static bool _isBenignMpvError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('cannot seek') ||
        lower.contains('force-seekable') ||
        lower.contains("expected '=' and a value");
  }

  bool _disposed = false;
  bool _playerAlive = false;

  static const _playerConfiguration = PlayerConfiguration(
    bufferSize: 64 * 1024 * 1024,
    logLevel: MPVLogLevel.warn,
    libass: true,
  );

  static String _fmtDur(Duration d) {
    final s = d.inSeconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    PlayerBackExitGate.setTryFocusBack(() {
      if (_disposed || !mounted) return false;
      if (_isPipMode) return false;
      // Guide / search own Back first (HardwareKeyboard steals Focus onKey).
      if (_guideVisible) {
        setState(() {
          _guideVisible = false;
          _controlsVisible = true;
        });
        _tvBackExitArmed = false;
        _hideControlsTimer?.cancel();
        _scheduleHideControls();
        _focusPlayerBack();
        return true;
      }
      if (_searchVisible) {
        setState(() {
          _searchVisible = false;
          _controlsVisible = true;
        });
        _tvBackExitArmed = false;
        _hideControlsTimer?.cancel();
        _scheduleHideControls();
        _focusPlayerBack();
        return true;
      }
      if (_isPlayerBackFocused() || _tvBackExitArmed) {
        _tvBackExitArmed = false;
        return false;
      }
      _tvBackExitArmed = true;
      setState(() => _controlsVisible = true);
      _hideControlsTimer?.cancel();
      _scheduleHideControls();
      _focusPlayerBack();
      return true;
    });
    // First Back focuses Back; second (Back focused / armed) exits.
    _sources = List<IptvPlaySource>.from(widget.sources);
    _title = widget.title;
    _subtitle = widget.subtitle;
    _logoUrl = widget.logoUrl;
    final guide = widget.channelGuide;
    _selectedGroupId = guide?.initialGroupId ?? '';
    _currentChannelId = guide?.initialChannelId ?? '';
    final portal = guide?.xtreamPortal;
    if (portal != null) _epgCache = IptvGuideEpgCache(portal);
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onRemoteControlsActivity);
    if (_windowsSoftwareDecode) {
      _softwareDecodeForced = true;
    }
    _initOrientationAndChrome();
    WakelockPlus.enable();
    void onPipChanged(bool inPip) {
      if (_disposed || !mounted) return;
      setState(() {
        _isPipMode = inPip;
        if (inPip) {
          _controlsVisible = false;
          _guideVisible = false;
          _searchVisible = false;
          _hideControlsTimer?.cancel();
        }
      });
      if (inPip && !_playing) {
        _userPlayWhenReady = true;
        unawaited(_enginePlay());
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      _pipSub = PipService.instance.androidPipChanges.listen(onPipChanged);
    } else if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      _pipSub = PipService.instance.desktopPipChanges.listen(onPipChanged);
    }
    unawaited(_bootWithCachedVolume());
  }

  /// D-pad / remote keys while chrome is up count as activity. Row focus
  /// handlers often return [KeyEventResult.handled], so [PlayerTvKeyScope]
  /// alone never sees them - without this, controls hide mid-navigation.
  bool _onRemoteControlsActivity(KeyEvent event) {
    if (!shellTvIsNavigationKey(event)) return false;
    if (_disposed || !mounted) return false;
    if (!_controlsVisible || _guideVisible || _searchVisible || _isPipMode) {
      return false;
    }
    _scheduleHideControls();
    return false;
  }

  /// Boot prefs (engine choice + last volume + EPG toggle) come from
  /// [iptvPlayerBootPrefsProvider] — Settings playback snapshot + cached volume.
  Future<void> _bootWithCachedVolume() async {
    // Same contract as VOD [waitForRouteTransition]: do not open Exo/MediaKit
    // while a shell slide is still compositing (jank on weak Android 7 TVs).
    // On ATV slides are Duration.zero — this returns immediately.
    await waitForRouteTransition(context);
    if (_disposed || !mounted) return;
    final prefs = await ref.read(iptvPlayerBootPrefsProvider.future);
    if (_disposed || !mounted) return;
    final forced = widget.forceBuiltInEngine;
    if (forced != null && !kIsWeb && Platform.isAndroid) {
      _exoBackend = forced == BuiltInPlayerEngine.exoPlayer;
    } else {
      _exoBackend = prefs.useExoBackend;
    }
    // Phone MediaKit: software-friendly. ATV MediaKit: HW + mediacodec_embed.
    _androidMediaKitSafeMode =
        !_exoBackend && !kIsWeb && Platform.isAndroid && !PlatformInfo.isAndroidTv;
    _volume = prefs.volume;
    _volumeBeforeMute = prefs.volume > 0 ? prefs.volume : 100.0;
    _muted = prefs.volume == 0;
    if (_exoBackend) {
      await _bootExoPlayer();
    } else {
      await _bootPlayer();
    }
  }

  /// Hot-swap Exo ↔ MediaKit from the in-player Player menu (Android).
  /// Set [persist] false for one-shot recovery so IPTV Settings stay unchanged.
  Future<void> _switchBuiltInEngine(
    BuiltInPlayerEngine engine, {
    bool persist = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final wantExo = engine == BuiltInPlayerEngine.exoPlayer;
    if (persist) {
      await SettingsService().setBuiltInPlayerEngine(engine);
    }
    if (_disposed || !mounted) return;
    if (wantExo == _exoBackend) return;

    if (mounted) {
      setState(() {
        _playerReady = false;
        _statusBanner = 'Switching player…';
      });
    }
    await _disposePlayer();
    if (_disposed || !mounted) return;

    _exoBackend = wantExo;
    _androidMediaKitSafeMode = !_exoBackend && !PlatformInfo.isAndroidTv;
    _softwareDecodeForced = _windowsSoftwareDecode;
    _player = null;
    _controller = null;
    _exoViewId = null;
    _retryAttempt = 0;

    if (_exoBackend) {
      await _bootExoPlayer();
    } else {
      await _bootPlayer();
    }
    if (mounted) setState(() => _statusBanner = null);
  }

  static bool _isUnrecognizedFormatError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('failed to recognize file format') ||
        lower.contains('unrecognizedinputformat') ||
        lower.contains('none of the available extractors') ||
        (lower.contains('source error') && lower.contains('m3u8'));
  }

  /// After format errors on `/hls-proxy`, try the other Android engine once.
  Future<void> _autoSwapEngineForFormatError(String reason) async {
    if (_disposed || _formatEngineSwapped || kIsWeb || !Platform.isAndroid) {
      return;
    }
    _formatEngineSwapped = true;
    final next = _exoBackend
        ? BuiltInPlayerEngine.mediaKit
        : BuiltInPlayerEngine.exoPlayer;
    debugPrint('[IPTV] format error → auto-swap to $next ($reason)');
    if (mounted) {
      setState(() => _statusBanner = 'Trying ${next.displayName}…');
    }
    await _switchBuiltInEngine(next, persist: false);
  }

  /// Apply volume to the engine and persist for the next IPTV player open.
  void _setCachedVolume(double volume) {
    final v = volume.clamp(0.0, 100.0);
    _volume = v;
    _muted = v == 0;
    if (v > 0) _volumeBeforeMute = v;
    _engineSetVolume(v);
    unawaited(IptvStore.savePlayerVolume(v));
  }

  @override
  void dispose() {
    PlayerBackExitGate.setTryFocusBack(null);
    ShellBus.leavePlayerSurface();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onRemoteControlsActivity);
    _pipSub?.cancel();
    _watchdog?.cancel();
    _hideControlsTimer?.cancel();
    _hideVolumeTimer?.cancel();
    _playerTvKeyFocus.dispose();
    _seekFocus.dispose();
    unawaited(_finalizeExit());
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_isDesktop) {
      // Restore a normal (non-fullscreen, non-maximized) window when leaving.
      // If we tear down while in PiP, restore window chrome so the next
      // screen is not stuck in a frameless always-on-top box.
      Future.microtask(() async {
        try {
          if (PipService.instance.isDesktopActive) {
            await PipService.instance.leave();
          }
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
}
