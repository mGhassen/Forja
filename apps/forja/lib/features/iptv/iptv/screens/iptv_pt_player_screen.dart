import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/platform/platform_info.dart';
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

/// Dedicated IPTV player. Android TV uses native ExoPlayer (Media3); all other
/// platforms use libmpv (media_kit). Includes:
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
  }) => IptvPtPlayerScreen(
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
  State<IptvPtPlayerScreen> createState() => _IptvPtPlayerScreenState();
}

class _IptvPtPlayerScreenState extends State<IptvPtPlayerScreen>
    with WidgetsBindingObserver, _IptvPtPlayerEngine, _IptvPtPlayerUi {
  static int _nextExoViewId = 1;

  /// MediaKit EGL surfaces fail on Android TV (audio OK, black video) — use Exo.
  late final bool _exoBackend =
      !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;
  int? _exoViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _exoEventSub;

  Player? _player;
  VideoController? _controller;
  bool _playerReady = false;
  int _videoEpoch = 0;
  bool _softwareDecodeForced = false;

  /// Android MediaKit uses software decode — HW surfaces fail on many devices
  /// and ATV emulators (EGL_BAD_ATTRIBUTE, audio OK / black frame).
  bool _androidMediaKitSafeMode = false;

  /// Windows D3D11 / ANGLE + live IPTV: HW decode plays ~15–20s then sticks
  /// the last frame with no reconnect banner. Force software from boot.
  bool get _windowsSoftwareDecode => !kIsWeb && Platform.isWindows;

  /// Probed after each open — pure-live feeds must never be seek()'d.
  bool _streamSeekable = false;

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
  final FocusNode _playerTvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'iptv-player-seek');

  bool _guideVisible = false;
  bool _searchVisible = false;
  late String _selectedGroupId;
  late String _currentChannelId;
  IptvGuideEpgCache? _epgCache;
  bool _iptvEpgEnabled = true;

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
  bool _volumeHovering = false;
  Timer? _hideVolumeTimer;

  // Fullscreen state (desktop only — mobile is permanently immersive)
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
  // probing every N seconds forever — live IPTV channels routinely come
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
    _sources = List<IptvPlaySource>.from(widget.sources);
    _title = widget.title;
    _subtitle = widget.subtitle;
    _logoUrl = widget.logoUrl;
    final guide = widget.channelGuide;
    _selectedGroupId = guide?.initialGroupId ?? '';
    _currentChannelId = guide?.initialChannelId ?? '';
    final portal = guide?.xtreamPortal;
    if (portal != null) _epgCache = IptvGuideEpgCache(portal);
    _iptvEpgEnabled = SettingsService.iptvEpgEnabledNotifier.value;
    SettingsService.iptvEpgEnabledNotifier.addListener(_onIptvEpgPrefChanged);
    unawaited(_loadIptvEpgPref());
    WidgetsBinding.instance.addObserver(this);
    if (!_exoBackend && !kIsWeb && Platform.isAndroid) {
      _androidMediaKitSafeMode = true;
    }
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

  Future<void> _bootWithCachedVolume() async {
    final v = await IptvStore.loadPlayerVolume();
    if (_disposed || !mounted) return;
    _volume = v;
    _volumeBeforeMute = v > 0 ? v : 100.0;
    _muted = v == 0;
    if (_exoBackend) {
      await _bootExoPlayer();
    } else {
      await _bootPlayer();
    }
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
    ShellBus.leavePlayerSurface();
    _disposed = true;
    SettingsService.iptvEpgEnabledNotifier.removeListener(
      _onIptvEpgPrefChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
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
