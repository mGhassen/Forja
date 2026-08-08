import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_title_clean.dart';
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
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/desktop_pip_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/player/exo/exo_atv_surface_fallback.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_menus.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shell/shell_bus.dart';

part 'iptv_pt_player_engine.dart';
part 'iptv_pt_player_ui.dart';

/// True for live IPTV URLs (Xtream `/live/…`, M3U, unknown). False for Xtream VOD.
@visibleForTesting
bool iptvExoUrlLooksLive(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('/movie/') || lower.contains('/series/')) return false;
  return true;
}

/// Hard open failure (MediaKit / Exo) — VOD can swap engines once.
@visibleForTesting
bool iptvIsHardOpenFail(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('failed to open') ||
      lower.contains('unable to open') ||
      lower.contains('error opening') ||
      lower.contains('failed to recognize file format') ||
      lower.contains('unrecognizedinputformat') ||
      lower.contains('none of the available extractors') ||
      lower.contains('invalidresponsecode') ||
      lower.contains('response code: 403') ||
      lower.contains('response code: 401') ||
      lower.contains('arrayindexoutofbounds') ||
      lower.contains('unexpectedloaderexception') ||
      // Exo progressive VOD: HTTP death or Media3 AAC/MP4 extractor crash.
      lower.contains('source error');
}

/// Single source for the IPTV player.
class IptvPlaySource {
  final String url;
  final String label;
  /// Optional HTTP headers (Cookie / Referer / Origin) for Exo / MediaKit.
  /// Live Matches Streamed handoff uses these instead of `/hls-proxy`.
  final Map<String, String> headers;
  const IptvPlaySource({
    required this.url,
    required this.label,
    this.headers = const {},
  });
}

/// Dedicated IPTV / Live native player. Android remembers Exo / MediaKit per
/// [engineContext] (IPTV ≠ VOD ≠ Live); other platforms use libmpv. Includes:
///   • Watchdog (3 detectors): long buffering, frozen position, ready-but-not-playing
///   • Tiered recovery: reopen + live-edge → stop+open → recreate
///   • Mid-stream underrun → drop stale buffers / jump live (no silent 15s replay)
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
  /// Which surface preference to read/write (default IPTV).
  final BuiltInPlayerContext engineContext;
  /// When set on Android, boot with this engine for this session only.
  final BuiltInPlayerEngine? forceBuiltInEngine;
  /// Movies/series: no live-edge snap, finite recovery, online subs.
  /// Live channels leave this false so existing live behavior is unchanged.
  final bool vodPlayback;
  /// Movies/series: fetch online subs + Search-by-name (not live).
  final bool onlineSubtitles;
  /// Prefer over [title] for subtitle APIs (e.g. series show name).
  final String? subtitleSearchTitle;
  final int? subtitleSeason;
  final int? subtitleEpisode;
  final int? subtitleYear;
  /// Series: in-player episode list (same panel as hub VOD players).
  final List<IptvEpisode>? seriesEpisodes;
  final IptvPortal? seriesPortal;
  /// Show name for chrome / episode switch titles.
  final String? seriesShowTitle;

  const IptvPtPlayerScreen({
    super.key,
    required this.sources,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.channelGuide,
    this.onChannelChanged,
    this.engineContext = BuiltInPlayerContext.iptv,
    this.forceBuiltInEngine,
    this.vodPlayback = false,
    this.onlineSubtitles = false,
    this.subtitleSearchTitle,
    this.subtitleSeason,
    this.subtitleEpisode,
    this.subtitleYear,
    this.seriesEpisodes,
    this.seriesPortal,
    this.seriesShowTitle,
  });

  /// Convenience: build for a single Xtream stream.
  factory IptvPtPlayerScreen.singleStream({
    Key? key,
    required String url,
    required IptvStream stream,
    String? portalName,
    IptvChannelGuide? channelGuide,
    ValueChanged<IptvStream>? onChannelChanged,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.iptv,
    BuiltInPlayerEngine? forceBuiltInEngine,
  }) {
    final vod = stream.kind == 'vod' || stream.kind == 'series';
    return IptvPtPlayerScreen(
      key: key,
      sources: [IptvPlaySource(url: url, label: portalName ?? 'Source 1')],
      title: stream.name,
      subtitle: portalName,
      logoUrl: stream.icon.isEmpty ? null : stream.icon,
      channelGuide: channelGuide,
      onChannelChanged: onChannelChanged,
      engineContext: engineContext,
      forceBuiltInEngine: forceBuiltInEngine,
      vodPlayback: vod,
      onlineSubtitles: vod,
      subtitleSearchTitle: stream.name,
    );
  }

  /// Convenience: build for a list of channel hits (multi-source).
  factory IptvPtPlayerScreen.fromHits({
    Key? key,
    required List<ChannelHit> hits,
    required String title,
    String? logoUrl,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.iptv,
  }) =>
      IptvPtPlayerScreen(
        key: key,
        title: title,
        logoUrl: logoUrl,
        engineContext: engineContext,
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
  /// Android reads [engineContext] prefs at boot / Player menu.
  bool _exoBackend = false;
  int? _exoViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _exoEventSub;
  ExoAtvSurfaceFallback? _exoSurfaceFallback;

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

  // Seekbar: duration > 1s ⇒ VOD scrubber; live always shows EPG / live-edge bar.
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
  final FocusNode _backFocus = FocusNode(debugLabel: 'iptv-player-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'iptv-player-play');
  final FocusNode _replayFocus = FocusNode(debugLabel: 'iptv-player-replay');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'iptv-player-seek');
  /// Top-right Player menu (Exo ↔ MediaKit). Explicit FocusNode so D-pad →
  /// from Back can claim it — [FocusScope.focusInDirection] often fails across
  /// the wide title gap on Android TV (issue 110).
  final FocusNode _playerMenuFocus =
      FocusNode(debugLabel: 'iptv-player-menu');
  final FocusNode _statsFocus = FocusNode(debugLabel: 'iptv-player-stats');
  /// Bottom-row TV FocusNodes — explicit ←/→ like the top bar (Spacer gap
  /// breaks geometric [focusInDirection] on Android TV).
  final FocusNode _subtitleFocus =
      FocusNode(debugLabel: 'iptv-player-subtitles');
  final FocusNode _audioFocus = FocusNode(debugLabel: 'iptv-player-audio');
  final FocusNode _episodesFocus =
      FocusNode(debugLabel: 'iptv-player-episodes');
  final FocusNode _searchChromeFocus =
      FocusNode(debugLabel: 'iptv-player-search');
  /// Playing series episode (updated when switching from the in-player panel).
  int? _playingSeason;
  int? _playingEpisode;
  final FocusNode _guideFocus = FocusNode(debugLabel: 'iptv-player-guide');
  final FocusNode _bottomSourceFocus =
      FocusNode(debugLabel: 'iptv-player-bottom-source');

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
  /// Stall-reopen mode: when buffering flickers false, wait this long before
  /// clearing [_bufferingSince] so detector 1's grace is not reset by core-idle.
  DateTime? _bufferingClearAt;
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

  // Tracks — MediaKit only (same menus as the home movies player).
  bool _isNativeSubtitle = false;
  double _subtitleDelay = 0.0;
  double _subtitleSize = 44.0;
  double _subtitleBottomPadding = 24.0;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.67;
  bool _subtitleBold = false;
  String _subtitleFont = 'Default';

  List<Map<String, dynamic>> _externalSubtitles = [];
  String? _selectedExternalSubUrl;
  bool _isFetchingSubs = false;
  final Map<String, String> _externalSubFileCache = {};
  StreamSubscription<List<Map<String, dynamic>>>? _subtitleFetchSub;
  String _subQueryTitle = '';
  int? _subQueryYear;
  int? _subQuerySeason;
  int? _subQueryEpisode;

  // Fullscreen state (desktop only - mobile is permanently immersive)
  bool _isFullscreen = false;
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  // Picture-in-picture (same PipService as the movie player)
  bool _isPipMode = false;
  bool _pipHover = false;
  StreamSubscription<bool>? _pipSub;

  /// Paused because app left foreground — resume only if set (issue 134).
  bool _pausedByLifecycle = false;

  // Retry state
  int _retryAttempt = 0;
  DateTime? _lastRecoveryAt;
  /// One-shot Exo ↔ MediaKit swap after unrecognized-format errors.
  bool _formatEngineSwapped = false;
  // When the user explicitly paused (play-after-pause rejoins live edge).
  DateTime? _pausedAt;
  /// After [drop-buffers], VideoToolbox often logs a one-shot hw fail while
  /// re-initing — ignore those so we don't thrash into software decode.
  DateTime? _ignoreHwDecodeFailUntil;
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
  /// How long a manual reload's live-edge flush gets to restore frames before
  /// escalating to a real reopen. Covers the flush's own 700ms delay.
  static const Duration _reloadEscalateAfter = Duration(seconds: 3);

  /// Seconds of demuxer/buffer ahead of the playhead. Updated every watchdog
  /// tick (MediaKit) or from Exo progress. The recovery gate: if this is above
  /// [_minHealthyCacheSecs], the stream is working — do not reopen.
  double _cacheAheadSecs = 0;

  /// Last observed buffered-end mark in ms (Exo / mpv buffer stream).
  int? _feedMarkMs;

  /// When [_feedMarkMs] last moved — socket still delivering.
  DateTime? _feedAdvancedAt;

  bool _cacheProbeInFlight = false;

  /// Debug-only UHD telemetry timer (issue 150).
  Timer? _uhdDiag;

  /// One display-mode switch per MediaKit open (issue 150 — 50 fps on 60 Hz).
  bool _displayFrameRateApplied = false;

  /// Have at least this much cache ⇒ stream is healthy, never auto-recover.
  static const double _minHealthyCacheSecs = 2.0;

  /// Tunables ask for ~30 s readahead. Anything far above that is almost
  /// always a live PTS discontinuity (mpv reports multi-hour "cache"), not
  /// real buffered media — reject for the Stable recovery gate.
  static const double _maxSaneCacheAheadSecs = 90.0;

  /// Feed mark moved within this window ⇒ still downloading.
  static const Duration _networkAliveWindow = Duration(seconds: 3);

  /// How long ffmpeg gets on VOD before app escalates (live uses cache gate).
  static const Duration _ffmpegReconnectGrace = Duration(seconds: 8);

  /// Stall-reopen: require continuous non-buffering this long before resetting
  /// [_bufferingSince] (media_kit `core-idle` flicker).
  static const Duration _bufferingClearHold = Duration(milliseconds: 1500);

  bool _socketTroublePending = false;

  /// [SettingsService.iptvLiveRecoveryBuffered] (default), stall (test), or classic.
  String _liveRecoveryMode = SettingsService.iptvLiveRecoveryBuffered;

  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  static bool _isBenignMpvError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('cannot seek') ||
        lower.contains('force-seekable') ||
        lower.contains("expected '=' and a value");
  }

  bool _disposed = false;
  bool _playerAlive = false;
  /// Instant mute/pause before route pop (mirrors VOD [_stopPlaybackForExit]).
  bool _playbackStopped = false;
  /// Prevents double pop from Back button + remote Back gate.
  bool _exitInProgress = false;

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
      // Menus (Stream stats, Player, …) own Back before the exit ladder.
      if (dismissAnyPlayerChromeOverlay()) {
        _tvBackExitArmed = false;
        return true;
      }
      // Guide owns Back first (HardwareKeyboard steals Focus onKey).
      // Search is handled by [setTryConsumePlayerOverlay] (results → field →
      // close) before this ladder runs.
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
      if (_backFocus.hasFocus || _tvBackExitArmed) {
        _tvBackExitArmed = false;
        // Consume Back and exit ourselves — silence + unmount Video before
        // pop so MediaKit/MediaCodec teardown cannot ANR (issue 128).
        unawaited(_exitIptvPlayer());
        return true;
      }
      _tvBackExitArmed = true;
      setState(() => _controlsVisible = true);
      _hideControlsTimer?.cancel();
      _scheduleHideControls();
      _focusPlayerBack();
      return true;
    });
    PlayerBackExitGate.setTryConsumePlayerOverlay(() {
      if (_disposed || !mounted || _isPipMode) return false;
      if (!_searchVisible) return false;
      // Results list → search field (HardwareKeyboard steals Focus onKey).
      if (IptvChannelSearchOverlay.tryConsumeBackToField()) {
        _tvBackExitArmed = false;
        return true;
      }
      // Field (or empty results) → close overlay; stay in player.
      setState(() {
        _searchVisible = false;
        _controlsVisible = true;
      });
      _tvBackExitArmed = false;
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
    _playingSeason = widget.subtitleSeason;
    _playingEpisode = widget.subtitleEpisode;
    _seedSubtitleQuery();
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
          _pausedByLifecycle = false;
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
      PipService.instance.bindAutoEnterOnDesktopSwitch(
        token: this,
        shouldEnter: () =>
            !_disposed && mounted && (_playing || _pausedByLifecycle),
      );
    }
    // Same as VOD: [waitForRouteTransition] uses ModalRoute.of — illegal in
    // initState. Defer until after the first frame so the modal scope exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      unawaited(_bootWithCachedVolume());
    });
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

  /// Boot prefs: engine from [widget.engineContext] KV; volume/EPG from
  /// [iptvPlayerBootPrefsProvider].
  Future<void> _bootWithCachedVolume() async {
    // Same contract as VOD [waitForRouteTransition]: do not open Exo/MediaKit
    // while a shell slide is still compositing (jank on weak Android 7 TVs).
    // On ATV slides are Duration.zero — this returns immediately.
    await waitForRouteTransition(context);
    if (_disposed || !mounted) return;
    // Live Matches Streamed keeps an embed WebView under this route for CDN
    // proxy fetches — that platform view steals leanback keys unless blocked.
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
      if (_disposed || !mounted) return;
    }
    final prefs = await ref.read(iptvPlayerBootPrefsProvider.future);
    if (_disposed || !mounted) return;
    final forced = widget.forceBuiltInEngine;
    if (forced != null && !kIsWeb && Platform.isAndroid) {
      _exoBackend = forced == BuiltInPlayerEngine.exoPlayer;
    } else if (!kIsWeb && Platform.isAndroid) {
      final engine = await SettingsService().getBuiltInPlayerEngine(
        context: widget.engineContext,
      );
      if (_disposed || !mounted) return;
      _exoBackend = engine == BuiltInPlayerEngine.exoPlayer;
      // Movies/Series: prefer MediaKit when IPTV has no explicit engine yet
      // (legacy VOD inherit of Exo). Media3 dies on many portal MP4 AAC configs.
      if (widget.vodPlayback && _exoBackend) {
        final iptvRaw = await SettingsService().getBuiltInPlayerEngineRaw(
          BuiltInPlayerContext.iptv,
        );
        if (_disposed || !mounted) return;
        if (iptvRaw == null || iptvRaw.isEmpty) {
          _exoBackend = false;
        }
      }
    } else {
      _exoBackend = false;
    }
    // Phone MediaKit: software-friendly. ATV MediaKit: HW + mediacodec_embed.
    _androidMediaKitSafeMode =
        !_exoBackend && !kIsWeb && Platform.isAndroid && !PlatformInfo.isAndroidTv;
    _volume = prefs.volume;
    _volumeBeforeMute = prefs.volume > 0 ? prefs.volume : 100.0;
    _muted = prefs.volume == 0;
    _liveRecoveryMode = prefs.liveRecoveryMode;
    debugPrint('[IPTV Player] live recovery mode=$_liveRecoveryMode');
    try {
      final subPrefs =
          await ref.read(playerSubtitlePrefsProvider(true).future);
      if (!_disposed && mounted) {
        _subtitleSize = subPrefs.size;
        _subtitleColor = Color(subPrefs.colorArgb);
        _subtitleBgOpacity = subPrefs.bgOpacity;
        _subtitleBold = subPrefs.bold;
        _subtitleBottomPadding = subPrefs.bottomPadding;
        _subtitleFont = subPrefs.font;
      }
    } catch (_) {}
    if (_exoBackend) {
      await _bootExoPlayer();
      if (!_disposed && mounted && widget.onlineSubtitles) {
        _fetchOnlineSubtitles();
      }
    } else {
      await _bootPlayer();
      if (!_disposed && mounted && widget.onlineSubtitles) {
        _fetchOnlineSubtitles();
      }
    }
  }

  void _seedSubtitleQuery() {
    if (!widget.onlineSubtitles) return;
    final raw = (widget.subtitleSearchTitle ?? widget.title).trim();
    final cleaned = cleanIptvMediaTitle(raw);
    _subQueryTitle = cleaned.title.isNotEmpty ? cleaned.title : raw;
    _subQueryYear = widget.subtitleYear ?? cleaned.year;
    _subQuerySeason = widget.subtitleSeason ?? cleaned.season;
    _subQueryEpisode = widget.subtitleEpisode ?? cleaned.episode;
  }

  /// Hot-swap Exo ↔ MediaKit from the in-player Player menu (Android).
  /// Set [persist] false for one-shot recovery so IPTV Settings stay unchanged.
  ///
  /// Matches VOD [PlayerScreen] switch: full surface unmount → release without
  /// blocking the UI isolate on MediaKit stop+dispose → cool-down → boot.
  /// Both directions then await [MpvExclusiveSession.prepareForVideoPlayer] —
  /// unbounded for MediaKit, capped at 1.2s for Exo so the MediaCodec detach is
  /// done without crossing the ATV input-ANR window (issue 128).
  Future<void> _switchBuiltInEngine(
    BuiltInPlayerEngine engine, {
    bool persist = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final wantExo = engine == BuiltInPlayerEngine.exoPlayer;
    if (persist) {
      await SettingsService().setBuiltInPlayerEngine(
        engine,
        context: widget.engineContext,
      );
    }
    if (_disposed || !mounted) return;
    if (wantExo == _exoBackend) return;

    if (mounted) {
      setState(() {
        _playerReady = false;
        _statusBanner = 'Switching player…';
      });
    }
    // Let Video / ExoPlayerView unmount before tearing down the engine.
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !mounted) return;

    await _releaseEngineForHotSwap();
    if (_disposed || !mounted) return;

    // mediacodec_embed / Exo surface need a beat after unmount (issues 128/129).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_disposed || !mounted) return;

    if (wantExo) {
      // Exo does not share the mpv handle, but ATV MediaCodec is shared: Exo
      // mounting over a live mediacodec_embed surface plays audio with a black
      // picture (issue 129 / 133). Capped at 1.2s like the VOD switch so the
      // wait cannot cross the ATV input-ANR window (issue 128).
      await MpvExclusiveSession.instance.prepareForVideoPlayer(
        timeout: const Duration(milliseconds: 1200),
      );
      if (_disposed || !mounted) return;
    } else {
      await MpvExclusiveSession.instance.prepareForVideoPlayer();
      if (_disposed || !mounted) return;
    }

    _exoBackend = wantExo;
    _androidMediaKitSafeMode = !_exoBackend && !PlatformInfo.isAndroidTv;
    _softwareDecodeForced = _windowsSoftwareDecode;
    _player = null;
    _controller = null;
    _exoViewId = null;
    _retryAttempt = 0;
    _playbackStopped = false;

    if (_exoBackend) {
      await _bootExoPlayer();
    } else {
      await _bootPlayer();
    }
    if (mounted) setState(() => _statusBanner = null);
  }

  /// Instant mute/pause (native mpv props) — do not await hung stop before pop.
  Future<void> _stopPlaybackForExit() async {
    if (_playbackStopped) return;
    _playbackStopped = true;
    if (_exoBackend) {
      final id = _exoViewId;
      if (id != null) {
        try {
          await ExoPlayerBridge.pause(id);
        } catch (_) {}
      }
      return;
    }
    final player = _player;
    if (player == null) return;
    await silenceMediaKitPlayer(player);
  }

  /// Silence + unmount the video surface, then pop. Matches VOD exit so
  /// MediaKit/MediaCodec teardown is not on the Navigator.pop critical path.
  Future<void> _exitIptvPlayer() async {
    if (_disposed || _exitInProgress) return;
    if (dismissAnyPlayerChromeOverlay()) {
      _tvBackExitArmed = false;
      PlayerBackExitGate.exitReady = false;
      return;
    }
    _exitInProgress = true;
    final nav = Navigator.of(context);
    await _stopPlaybackForExit();
    if (!mounted || _disposed) return;
    if (_playerReady) {
      setState(() => _playerReady = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || _disposed) return;
    if (nav.canPop()) {
      nav.pop();
    }
  }

  static bool _isUnrecognizedFormatError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('failed to recognize file format') ||
        lower.contains('unrecognizedinputformat') ||
        lower.contains('none of the available extractors') ||
        (lower.contains('source error') && lower.contains('m3u8'));
  }

  /// After format / hard-open errors, try the other Android engine once.
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pauseForAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      if (!_disposed &&
          !_isPipMode &&
          !PipService.instance.isDesktopActive &&
          !PipService.instance.autoPipArmed &&
          !SettingsService.keepsPlayingInBackground &&
          _playing) {
        _pausedByLifecycle = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      _resumeAfterAppBackground();
    }
  }

  void _pauseForAppBackground() {
    if (_disposed ||
        _isPipMode ||
        PipService.instance.isDesktopActive) {
      return;
    }
    if (PipService.instance.autoPipArmed && (_playing || _pausedByLifecycle)) {
      unawaited(PipService.instance.enterInsteadOfPause());
      return;
    }
    if (SettingsService.keepsPlayingInBackground) return;
    // Live may report !_playing while buffering — still stop decode/audio.
    if (_playing || _userPlayWhenReady) {
      _pausedByLifecycle = true;
      _userPlayWhenReady = false;
      unawaited(_enginePause());
    }
  }

  void _resumeAfterAppBackground() {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    if (_isPipMode || PipService.instance.isDesktopActive) return;
    _userPlayWhenReady = true;
    unawaited(_enginePlay());
  }

  @override
  void dispose() {
    PlayerBackExitGate.setTryFocusBack(null);
    PlayerBackExitGate.setTryConsumePlayerOverlay(null);
    ShellBus.leavePlayerSurface();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onRemoteControlsActivity);
    _backFocus.dispose();
    _playFocus.dispose();
    _replayFocus.dispose();
    _playerMenuFocus.dispose();
    _statsFocus.dispose();
    _subtitleFocus.dispose();
    _audioFocus.dispose();
    _episodesFocus.dispose();
    _searchChromeFocus.dispose();
    _guideFocus.dispose();
    _bottomSourceFocus.dispose();
    _pipSub?.cancel();
    PipService.instance.unbindAutoEnterOnDesktopSwitch(this);
    _watchdog?.cancel();
    _uhdDiag?.cancel();
    unawaited(PlatformChannel.clearDisplayFrameRate());
    _displayFrameRateApplied = false;
    _hideControlsTimer?.cancel();
    _hideVolumeTimer?.cancel();
    _subtitleFetchSub?.cancel();
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
