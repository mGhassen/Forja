import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:forja_foundation/utils/title_clean.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:forja/shared/player/platform/mpv_exclusive_session.dart';
import 'package:forja/shared/player/platform/external_player_service.dart';
import 'package:forja/shared/player/platform/pip_service.dart';
import 'package:forja/shared/player/screens/shared_widgets.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_chrome.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_aware_page_route.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/engine/portals/guide/guide.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart'
    show
        LivePlaySource,
        PortalLiveSourceKind,
        PortalLiveEngineResolveSource,
        iptvUrlLooksLikeHls,
        iptvHlsColdOpenHold,
        iptvIsHardOpenFail,
        iptvIsDeadEndpointFail,
        iptvLiveEnginePlayUrlReady,
        iptvLiveEngineUrlVolatile,
        iptvLiveEngineCanForceRefresh,
        iptvLiveEngineShouldForceRefreshOnRecovery,
        iptvIsLiveResolveStatusBanner,
        iptvLiveSourceProbeKey,
        iptvLiveSourceCanHoverProbe,
        iptvLiveSourceRunHoverProbe,
        iptvExoUrlLooksLive,
        portalLiveSourceKindForPortal;
import 'package:forja/shared/player/live_sports/live_sports_atv_cache.dart';
import 'package:forja/shared/player/live/player_stats_panel.dart';
import 'package:forja/shared/player/live/lazy_url_health.dart';
import 'package:forja/shared/player/live/tv_focus.dart';
import 'package:forja_foundation/widgets/guide/channel_guide_panel.dart';
import 'package:forja_foundation/widgets/guide/channel_search_overlay.dart';
import 'package:forja/shared/player/live/player_chrome_profile.dart';
import 'package:forja/shared/engine/unlock/live_plugin_engine.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';

import 'package:forja/shared/player/sources/torrent/torrent_source_tiles.dart';
import 'package:forja/shared/player/controls/menus/player_app_menu.dart';
import 'package:forja/shared/player/controls/menus/player_audio_menu.dart';
import 'package:forja/shared/player/controls/chrome/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/chrome/player_escape_exit_hint.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/chrome/desktop_pip_overlay.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/episodes/player_episode_panel.dart';
import 'package:forja/shared/player/controls/episodes/catalog_episode.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/menus/hls_instream_subtitles.dart';
import 'package:forja/shared/player/controls/menus/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/menus/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/tv/player_tv_key_scope.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/player/exo/exo_atv_surface_fallback.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_menus.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/player/avplayer/av_player_bridge.dart';
import 'package:forja/shared/player/avplayer/av_player_view.dart';
import 'package:forja/shared/player/vlc/vlc_player_bridge.dart';
import 'package:forja/shared/player/vlc/vlc_player_view.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/desktop/desktop_window_geometry.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

part 'live_sports_player_engine_core.dart';
part 'live_sports_player_mk_tunables.dart';
part 'live_sports_player_lavf.dart';
part 'live_sports_player_watchdog.dart';
part 'live_sports_player_recovery.dart';
part 'live_sports_player_engine.dart';
part 'live_sports_player_ui.dart';

/// Live Sports MediaKit `stream-lavf-o` — exact v1.5.36 direct reconnect.
@visibleForTesting
String liveSportsStreamLavfO() {
  return 'reconnect=1,'
      'reconnect_at_eof=1,'
      'reconnect_streamed=1,'
      'reconnect_delay_max=30,'
      'reconnect_on_network_error=1,'
      'reconnect_on_http_error=4xx\\,5xx';
}


/// Live Sports native player (v1.5.36 MediaKit stack — independent of IPTV).
class LiveSportsPlayerScreen extends ConsumerStatefulWidget {
  final List<LivePlaySource> sources;
  final String title;
  final String? subtitle;
  final String? logoUrl;
  final ChannelGuide? channelGuide;

  /// Fired when the in-player guide tunes a different Xtream channel.
  final ValueChanged<PortalStream>? onChannelChanged;

  /// Catalog stream marked dead (Stalker create_link / format fail) → red status.
  final ValueChanged<String>? onStreamDead;

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
  final List<PortalEpisode>? seriesEpisodes;
  final Portal? seriesPortal;

  /// Show name for chrome / episode switch titles.
  final String? seriesShowTitle;

  /// When true, top chrome **subtitle** follows the active [LivePlaySource]
  /// (My IPTV sports — title stays the match; each source is a different channel).
  final bool titleTracksSource;

  /// Default live profile when sources omit [LivePlaySource.liveSourceKind].
  final PortalLiveSourceKind? liveSourceKind;

  /// Live Sports: unlock catalog embed rows on source switch.
  final PortalLiveEngineResolveSource? liveEngineResolveSource;

  const LiveSportsPlayerScreen({
    super.key,
    required this.sources,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.channelGuide,
    this.onChannelChanged,
    this.onStreamDead,
    this.engineContext = BuiltInPlayerContext.live,
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
    this.titleTracksSource = false,
    this.liveSourceKind,
    this.liveEngineResolveSource,
  });

  /// Convenience: build for a single catalog stream (Xtream / Stalker / M3U).
  factory LiveSportsPlayerScreen.singleStream({
    Key? key,
    required String url,
    required PortalStream stream,
    String? portalName,
    PortalPlatform? portalPlatform,
    ChannelGuide? channelGuide,
    ValueChanged<PortalStream>? onChannelChanged,
    ValueChanged<String>? onStreamDead,
    BuiltInPlayerContext? engineContext,
    BuiltInPlayerEngine? forceBuiltInEngine,
  }) {
    final vod = stream.kind == 'vod' || stream.kind == 'series';
    final kind = vod || portalPlatform == null
        ? null
        : portalLiveSourceKindForPortal(portalPlatform);
    return LiveSportsPlayerScreen(
      key: key,
      sources: [
        LivePlaySource(
          url: url,
          label: portalName ?? 'Source 1',
          logoUrl: stream.icon.isEmpty ? null : stream.icon,
          streamId: stream.streamId,
          epgChannelId: stream.epgChannelId.isEmpty
              ? null
              : stream.epgChannelId,
          liveSourceKind: kind,
        ),
      ],
      title: stream.name,
      subtitle: portalName,
      logoUrl: stream.icon.isEmpty ? null : stream.icon,
      channelGuide: channelGuide,
      onChannelChanged: onChannelChanged,
      onStreamDead: onStreamDead,
      // Movies/Series share Settings → Movies; Live keeps IPTV.
      engineContext:
          engineContext ??
          (vod ? BuiltInPlayerContext.vod : BuiltInPlayerContext.iptv),
      forceBuiltInEngine: forceBuiltInEngine,
      vodPlayback: vod,
      onlineSubtitles: vod,
      subtitleSearchTitle: stream.name,
      liveSourceKind: kind,
    );
  }

  /// Convenience: build for a list of channel hits (multi-source).
  factory LiveSportsPlayerScreen.fromHits({
    Key? key,
    required List<ChannelHit> hits,
    required String title,
    String? logoUrl,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.live,
  }) {
    final kinds = hits
        .map((h) => portalLiveSourceKindForPortal(h.portal.portal.platform))
        .toList();
    return LiveSportsPlayerScreen(
      key: key,
      title: title,
      logoUrl: logoUrl,
      engineContext: engineContext,
      liveSourceKind: kinds.isEmpty ? null : kinds.first,
      sources: [
        for (var i = 0; i < hits.length; i++)
          LivePlaySource(
            url: hits[i].streamUrl,
            label: hits[i].portal.displayLabel,
            liveSourceKind: kinds[i],
          ),
      ],
    );
  }

  /// Root-navigator push — same full-window cover + Back slide as movies.
  /// Masks the shell underlay (no catalog peek during the slide) without
  /// Offstage/reflow of the rail.
  ///
  /// [player] is usually [LiveSportsPlayerScreen]; wrappers (deferred channel guide)
  /// are allowed so playback can start before the guide catalog is ready.
  static Future<T?> open<T>(
    BuildContext context,
    Widget player,
  ) async {
    await InAppMiniPlayerController.instance.stopForNewPlay();
    if (!context.mounted) return null;
    final hostContext = context;
    ShellBus.maskShellUnderPlayer.value = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!hostContext.mounted) {
      ShellBus.clearMaskShellUnderPlayer();
      return null;
    }
    return Navigator.of(hostContext, rootNavigator: true).push<T>(
      InAppMiniAwarePageRoute<T>(
        settings: const RouteSettings(name: 'live_sports_player'),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
        builder: (_) => ShellScope.rehost(hostContext, player),
      ),
    );
  }

  @override
  ConsumerState<LiveSportsPlayerScreen> createState() => _LiveSportsPlayerScreenState();
}

class _LiveSportsPlayerScreenState extends ConsumerState<LiveSportsPlayerScreen>
    with
        WidgetsBindingObserver,
        _LiveSportsPlayerEngineCore,
        _LiveSportsPlayerMkTunables,
        _LiveSportsPlayerLavf,
        _LiveSportsPlayerWatchdog,
        _LiveSportsPlayerRecovery,
        _LiveSportsPlayerEngine,
        _LiveSportsPlayerUi
    implements InAppMiniPlayerSession {
  static int _nextExoViewId = 1;
  static int _nextNativeViewId = 1;

  /// Active built-in decoder for this player session.
  BuiltInPlayerEngine _playerEngine = BuiltInPlayerEngine.mediaKit;

  bool get _exoBackend => _playerEngine == BuiltInPlayerEngine.exoPlayer;
  bool get _avPlayerBackend => _playerEngine == BuiltInPlayerEngine.avPlayer;
  bool get _vlcBackend => _playerEngine == BuiltInPlayerEngine.vlc;
  bool get _mediaKitBackend => _playerEngine == BuiltInPlayerEngine.mediaKit;

  /// One automatic engine hop after hard open / no first frame (IPTV HLS).
  bool _engineFailoverUsed = false;

  int? _exoViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _exoEventSub;
  ExoAtvSurfaceFallback? _exoSurfaceFallback;

  int? _avViewId;
  StreamSubscription<Map<dynamic, dynamic>>? _avEventSub;

  int? _vlcViewId;
  int? _vlcTextureId;
  StreamSubscription<Map<dynamic, dynamic>>? _vlcEventSub;

  Player? _player;
  VideoController? _controller;
  bool _playerReady = false;
  int _videoEpoch = 0;
  /// MediaKit→Exo: remount Exo TextureView once after first paint (issue 129).
  bool _exoFitRemountAfterMediaKit = false;
  bool _exoFitRemountDone = false;
  bool _softwareDecodeForced = false;

  /// Phone MediaKit: software decode (some MediaCodec paths flake).
  /// Android TV MediaKit: keep HW + [vo=mediacodec_embed] (Impeller OpenGLES).
  bool _androidMediaKitSafeMode = false;

  bool get _atvMediaKit =>
      !_exoBackend && !kIsWeb && Platform.isAndroid && PlatformInfo.isAndroidTv;

  /// Windows D3D11 / ANGLE + live IPTV: HW decode plays ~15–20s then sticks
  /// the last frame with no reconnect banner. Force software from boot.
  bool get _windowsSoftwareDecode => !kIsWeb && Platform.isWindows;

  /// Retired (RFC-113): macOS/Linux Xtream no longer forces TextureSW.
  /// Was: software decode after CDN socket close + continuity proxy era.
  bool get _desktopLiveSoftwareDecode => false;

  /// Probed after each open - pure-live feeds must never be seek()'d.
  bool _streamSeekable = false;

  StreamSubscription? _posSub, _playingSub, _bufferingSub, _errorSub, _logSub;
  StreamSubscription? _durSub, _bufferSub;
  StreamSubscription? _completedSub;

  // Seekbar: duration > 1s ⇒ VOD scrubber; live always shows EPG / live-edge bar.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _isSeeking = false;
  double _seekPreview = 0.0;
  /// Catalog VOD, or live with a real DVR window — not mpv's ~2–6s HLS artifact.
  bool get _isVod {
    if (widget.vodPlayback) return _duration.inSeconds > 1;
    if (_duration.inSeconds <= 6) return false;
    return _duration.inSeconds > 1;
  }

  /// Live vs Movies/Series chrome (tracks / episodes / engine persist).
  LivePlayerChromeProfile get _chrome =>
      LivePlayerChromeProfile.fromVodPlayback(widget.vodPlayback);

  late List<LivePlaySource> _sources;
  late String _title;
  String? _subtitle;
  String? _logoUrl;

  int _sourceIdx = 0;
  bool _playing = false;
  bool _buffering = false;
  bool _userPlayWhenReady = true;
  String? _statusBanner;

  /// Debounce live position ticks — see [_syncPlaybackBannerVisibility].
  bool? _playbackBannerSnapshot;

  /// Reconnect / switch messages always; raw "Buffering…" only when stalled.
  bool get _showPlaybackBanner {
    if (_statusBanner != null) return true;
    if (!_buffering) return false;
    return !_videoAdvancing;
  }

  /// Playhead or real frame pulse moved recently — picture not frozen.
  ///
  /// MediaKit live must not treat demuxer feed / healthy cache as painting —
  /// VO can freeze with ~30s cache while proxy keepalives still advance.
  bool get _videoAdvancing {
    if (!_playing) return false;
    return DateTime.now().difference(_lastPosChange) <
        const Duration(milliseconds: 1500);
  }

  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  final FocusNode _playerTvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
  final FocusNode _backFocus = FocusNode(debugLabel: 'iptv-player-back');
  final FocusNode _playFocus = FocusNode(debugLabel: 'iptv-player-play');
  final FocusNode _rewind10Focus = FocusNode(debugLabel: 'iptv-player-rewind10');
  final FocusNode _forward10Focus =
      FocusNode(debugLabel: 'iptv-player-forward10');
  final FocusNode _replayFocus = FocusNode(debugLabel: 'iptv-player-replay');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'iptv-player-seek');

  /// Top-right Player menu (Exo ↔ MediaKit). Explicit FocusNode so D-pad →
  /// from Back can claim it — [FocusScope.focusInDirection] often fails across
  /// the wide title gap on Android TV (issue 110).
  final FocusNode _playerMenuFocus = FocusNode(debugLabel: 'iptv-player-menu');
  final FocusNode _statsFocus = FocusNode(debugLabel: 'iptv-player-stats');

  /// Bottom-row TV FocusNodes — explicit ←/→ like the top bar (Spacer gap
  /// breaks geometric [focusInDirection] on Android TV).
  final FocusNode _subtitleFocus = FocusNode(
    debugLabel: 'iptv-player-subtitles',
  );
  final FocusNode _audioFocus = FocusNode(debugLabel: 'iptv-player-audio');
  final FocusNode _episodesFocus = FocusNode(
    debugLabel: 'iptv-player-episodes',
  );
  final FocusNode _searchChromeFocus = FocusNode(
    debugLabel: 'iptv-player-search',
  );

  /// Playing series episode (updated when switching from the in-player panel).
  int? _playingSeason;
  int? _playingEpisode;
  final FocusNode _guideFocus = FocusNode(debugLabel: 'iptv-player-guide');
  final FocusNode _bottomSourceFocus = FocusNode(
    debugLabel: 'iptv-player-bottom-source',
  );

  bool _guideVisible = false;
  bool _searchVisible = false;

  /// First TV Back focused the Back control — next Back exits even before
  /// the post-frame [requestFocus] lands.
  bool _tvBackExitArmed = false;
  late String _selectedGroupId;
  late String _currentChannelId;
  GuideEpgCache? _epgCache;

  /// Armed Forja Sports portal — Stalker create_link without channelGuide.
  VerifiedPortal? _sportsPortal;

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
  /// ValueNotifier — never parent-setState on hover (mouse_tracker assert).
  final ValueNotifier<bool> _volumeHoveringN = ValueNotifier(false);
  Timer? _hideVolumeTimer;
  bool _chromeRevealScheduled = false;

  // Tracks — MediaKit only (same menus as the home movies player).
  bool _isNativeSubtitle = false;
  double _subtitleDelay = 0.0;
  double _subtitleSize = 44.0;
  double _subtitleBottomPadding = 24.0;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.67;
  bool _subtitleBold = false;
  String _subtitleFont = 'Default';
  /// Exo Media3 cues → Flutter overlay (issue 230).
  final ValueNotifier<List<String>> _exoCueTexts =
      ValueNotifier<List<String>>(const []);

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

  /// Desktop Escape ladder (parity with VOD [DesktopPlayerScreen]).
  bool _escapeExitArmed = false;
  DateTime? _escapeHandledAt;
  DateTime? _suppressChromeRevealUntil;

  // Picture-in-picture (same PipService as the movie player)
  bool _isPipMode = false;
  bool _pipHover = false;
  StreamSubscription<bool>? _pipSub;

  Completer<void>? _stopForNewPlayCompleter;
  /// Keep MediaKit/Exo surface across full ↔ in-app mini (no remount).
  final GlobalKey _videoViewKey = GlobalKey(debugLabel: 'iptv-player-video');
  late final FocusNode _miniRootFocus =
      FocusNode(debugLabel: 'iptv-in-app-mini-root');
  late final FocusNode _miniPlayPauseFocus =
      FocusNode(debugLabel: 'iptv-in-app-mini-play');
  late final FocusNode _miniExpandFocus =
      FocusNode(debugLabel: 'iptv-in-app-mini-expand');
  late final FocusNode _miniCloseFocus =
      FocusNode(debugLabel: 'iptv-in-app-mini-close');

  @override
  FocusNode get miniRootFocus => _miniRootFocus;

  @override
  bool get isPlaying => _playing;

  /// Paused because app left foreground — resume only if set (issue 134).
  bool _pausedByLifecycle = false;

  /// ATV: hide dead MediaCodec texture after veille while still paused (issue 182).
  bool _coverDeadSurface = false;

  // Retry state
  int _retryAttempt = 0;
  DateTime? _lastRecoveryAt;

  /// Bumped to cancel in-flight delayed live-edge snaps (recovery / reopen race).
  int _liveEdgeSnapEpoch = 0;

  /// Stalker: consecutive hard format/open fails after fresh create_link.
  int _stalkerHardFailCount = 0;

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

  /// Continuous Buffering + frozen playhead + **empty** cache this long ⇒ dead.
  /// Must not trip while demuxer still has a healthy ahead cushion.
  static const Duration _bufferingHardWallDuration = Duration(seconds: 12);

  /// Ignore one-shot VideoToolbox / hw fails after socket blip or live-edge snap.
  static const Duration _transientHwDecodeIgnore = Duration(seconds: 8);

  /// Soft reopen when live stays paused with empty cache this long.
  static const Duration _liveEmptyPauseReopen = Duration(seconds: 5);

  /// HLS cold open: allow ABR variant probe + first segments before soft-reopen.
  static const Duration _hlsColdOpenGrace = Duration(seconds: 30);

  /// Forja live: silent grace before goLive reopen (desktop / phone).
  static const Duration _liveGraceWindow = Duration(milliseconds: 6000);

  /// ATV: longer grace so lavf reconnect_delay_max=5 can finish.
  static const Duration _liveGraceWindowAtv = Duration(milliseconds: 9000);

  static const Duration _liveGoLivePollWindow = Duration(seconds: 5);
  static const Duration _liveGoLivePollWindowAtv = Duration(seconds: 8);
  static const int _maxLiveGoLiveAttempts = 2;
  static const int _maxLiveGoLiveAttemptsAtv = 1;
  static const Duration _liveGoLiveThrottle = Duration(seconds: 3);
  static const Duration _liveStableWindow = Duration(milliseconds: 1500);

  Timer? _liveGraceTimer;
  Timer? _liveGoLiveTimer;
  Timer? _liveStableTimer;
  int _liveGoLiveAttempt = 0;
  DateTime? _lastGoLiveAt;
  Duration _liveGraceStartPos = Duration.zero;

  /// Sustained Buffering + near-empty demuxer: fps paint pulse alone is not
  /// "working" (Stalker / direct live SW underrun). Soft-reopen can fire.
  static const Duration _liveEmptyBufferingUnderrun = Duration(seconds: 5);

  /// Demuxer ahead below this during Buffering ⇒ empty underrun (not healthy).
  static const double _liveEmptyUnderrunCacheSecs = 0.5;

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

  /// Settings raw mode ([SettingsService.iptvLiveRecoveryAuto] default).
  /// Watchdog uses [_liveRecoveryMode] after Auto resolve.
  String _liveRecoveryModeSetting = SettingsService.iptvLiveRecoveryAuto;

  /// Effective recovery policy for this open (Auto → buffered, etc.).
  String _liveRecoveryMode = SettingsService.iptvLiveRecoveryBuffered;

  void _applyLiveRecoveryModeForCurrentSource({LivePlaySource? src}) {
    final active = src ??
        (_sources.isEmpty
            ? null
            : _sources[_sourceIdx.clamp(0, _sources.length - 1)]);
    final kind = active?.liveSourceKind ?? widget.liveSourceKind;
    _liveRecoveryMode = SettingsService.resolveIptvLiveRecoveryMode(
      _liveRecoveryModeSetting,
      liveSourceKind: kind?.name,
    );
    debugPrint(
      '[IPTV Player] live recovery kind=${kind?.name ?? "null"} '
      'setting=$_liveRecoveryModeSetting effective=$_liveRecoveryMode',
    );
  }

  /// Last decoded height — cache profile re-apply gate (ATV live).
  int _lastVideoHeight = 0;
  bool _liveCacheTierApplied = false;

  /// Paint stall detection (MediaKit live — I199 / perf plan).
  int _livePaintMissStreak = 0;
  bool _voFreezeSnapAttempted = false;
  DateTime? _lastDemuxerSampleAt;
  int _stallFrameDropBaseline = -1;
  DateTime? _stallPaintWatchSince;

  static const _ua = 'VLC/3.0.20 LibVLC/3.0.20';

  /// ATV MediaKit: v1.5.36 32 MiB for Live Sports.
  PlayerConfiguration get _mediaKitPlayerConfiguration {
    if (_atvMediaKit && !widget.vodPlayback) {
      return const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
        libass: true,
      );
    }
    return _playerConfiguration;
  }

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

  /// Late [channelGuide] (open-first stub, then full shelf).
  void _applyChannelGuide(ChannelGuide guide) {
    _selectedGroupId = guide.initialGroupId;
    _currentChannelId = guide.initialChannelId;
    final portal = guide.xtreamPortal;
    if (portal != null) {
      _epgCache ??= GuideEpgCache(portal);
    } else if (widget.titleTracksSource &&
        (widget.liveSourceKind == PortalLiveSourceKind.iptvXtream ||
            widget.liveSourceKind == PortalLiveSourceKind.iptvStalker)) {
      unawaited(_initSportsEpgCache());
    }
  }

  @override
  void didUpdateWidget(covariant LiveSportsPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.channelGuide;
    final prev = oldWidget.channelGuide;
    // Stub → full shelf (or first attach). Reference inequality is enough —
    // ChannelGuide has no == and deferred open always builds a new instance.
    if (next != null && !identical(prev, next)) {
      setState(() => _applyChannelGuide(next));
    }
  }

  @override
  void initState() {
    super.initState();
    InAppMiniPlayerController.instance.attach(this);
    unawaited(InAppMiniPlayerController.readSettingEnabled());
    // Cover catalog/rail under the opaque route (set again from [open] before
    // push so the first slide frame is already masked).
    ShellBus.maskShellUnderPlayer.value = true;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed || !mounted) return;
          _claimPlayFocus();
        });
        return true;
      }
      final stay = PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: _controlsVisible,
        armed: _tvBackExitArmed,
        hideChrome: () {
          _hideControlsTimer?.cancel();
          setState(() => _controlsVisible = false);
        },
        setArmed: (v) {
          if (_disposed || !mounted) return;
          if (_tvBackExitArmed == v) return;
          setState(() => _tvBackExitArmed = v);
        },
      );
      return stay;
    });
    PlayerBackExitGate.setTryConsumePlayerOverlay(() {
      if (_disposed || !mounted || _isPipMode) return false;
      if (!_searchVisible) return false;
      // Results list → search field (HardwareKeyboard steals Focus onKey).
      if (ChannelSearchOverlay.tryConsumeBackToField()) {
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
      return true;
    });
    _sources = List<LivePlaySource>.from(widget.sources);
    if (widget.titleTracksSource && widget.sources.isNotEmpty) {
      _title = widget.title;
      _subtitle = widget.sources.first.pickerTitle;
    } else {
      _title = widget.title;
      _subtitle = widget.subtitle;
    }
    _logoUrl = widget.logoUrl;
    _playingSeason = widget.subtitleSeason;
    _playingEpisode = widget.subtitleEpisode;
    _seedSubtitleQuery();
    final guide = widget.channelGuide;
    if (guide != null) {
      _applyChannelGuide(guide);
    } else {
      _selectedGroupId = '';
      _currentChannelId = '';
      if (widget.titleTracksSource &&
          (widget.liveSourceKind == PortalLiveSourceKind.iptvXtream ||
              widget.liveSourceKind == PortalLiveSourceKind.iptvStalker)) {
        unawaited(_initSportsEpgCache());
      }
    }
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onRemoteControlsActivity);
    // MediaKit live never boots into TextureSW.
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

  /// Space / remote play-pause. Clears [_userPlayWhenReady] so the live
  /// watchdog does not microtask-resume after pause.
  Future<void> _togglePlayPauseFromKey() async {
    if (_playing) {
      _userPlayWhenReady = false;
      _pausedAt = DateTime.now();
      await _enginePause();
    } else {
      _userPlayWhenReady = true;
      final pausedAt = _pausedAt;
      _pausedAt = null;
      await _enginePlay();
      if (pausedAt != null &&
          _chrome == LivePlayerChromeProfile.live &&
          iptvExoUrlLooksLive(
            _sources.isEmpty ? '' : _sources[_sourceIdx].url,
          ) &&
          DateTime.now().difference(pausedAt) >= const Duration(seconds: 2)) {
        _scheduleJumpToLive(force: true);
      }
    }
  }

  /// D-pad / remote keys while chrome is up count as activity. Row focus
  /// handlers often return [KeyEventResult.handled], so [PlayerTvKeyScope]
  /// alone never sees them - without this, controls hide mid-navigation.
  ///
  /// Desktop also handles Space / Escape here — [PlayerTvKeyScope] is TV-only.
  bool _onRemoteControlsActivity(KeyEvent event) {
    if (_disposed || !mounted) return false;

    // Desktop: Space toggles play/pause without revealing chrome.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !liveUseTvFocus(context)) {
      if (_guideVisible || _searchVisible || _isPipMode) return false;
      if (playerChromeOverlayBlocksFocusClaim()) return false;
      unawaited(_togglePlayPauseFromKey());
      return true;
    }

    // Desktop Escape: same hide → leave-fullscreen → arm → leave ladder as VOD.
    // Live sports also uses this player.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isDesktop) {
      if (_isPipMode) return false;
      if (InAppMiniPlayerController.instance.isActive) {
        unawaited(InAppMiniPlayerController.instance.close());
        return true;
      }
      _handleEscapeKey();
      return true;
    }

    if (!shellTvIsNavigationKey(event)) return false;
    if (!_controlsVisible || _guideVisible || _searchVisible || _isPipMode) {
      return false;
    }
    _scheduleHideControls();
    return false;
  }

  /// Boot prefs: engine from [widget.engineContext] KV; volume from portal store.
  Future<void> _bootWithCachedVolume() async {
    // Same contract as VOD [waitForRouteTransition]: do not open Exo/MediaKit
    // while a shell slide is still compositing (jank on weak Android 7 TVs).
    // On ATV slides are Duration.zero — this returns immediately.
    await waitForRouteTransition(context);
    if (_disposed || !mounted) return;
    // Live Sports Streamed keeps an embed WebView under this route for CDN
    // proxy fetches — that platform view steals leanback keys unless blocked.
    if (PlatformInfo.isAndroidTv) {
      await PlatformChannel.releaseUnderlayPlatformViewFocus();
      if (_disposed || !mounted) return;
    }
    final volume = await PortalStore.loadPlayerVolume();
    final recovery = await SettingsService().getIptvLiveRecoveryMode();
    if (_disposed || !mounted) return;
    _playerEngine = await _resolveBootEngine();
    if (_disposed || !mounted) return;
    // Phone MediaKit: software-friendly. ATV MediaKit: HW + mediacodec_embed.
    _androidMediaKitSafeMode =
        _mediaKitBackend &&
        !kIsWeb &&
        Platform.isAndroid &&
        !PlatformInfo.isAndroidTv;
    _volume = volume;
    _volumeBeforeMute = volume > 0 ? volume : 100.0;
    _muted = volume == 0;
    // Leanback has no chrome volume — remote drives system volume. Softvol must
    // stay audible; a prior softvol mute (old HW remap) would look like "dead remote".
    if (PlatformInfo.isAndroidTv && _volume <= 0) {
      _volume = _volumeBeforeMute > 0 ? _volumeBeforeMute : 100.0;
      _muted = false;
      unawaited(PortalStore.savePlayerVolume(_volume));
    }
    _liveRecoveryModeSetting = recovery;
    _applyLiveRecoveryModeForCurrentSource();
    try {
      final subPrefs = await ref.read(playerSubtitlePrefsProvider(true).future);
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
    } else if (_avPlayerBackend) {
      await _bootAvPlayer();
      if (!_disposed && mounted && widget.onlineSubtitles) {
        _fetchOnlineSubtitles();
      }
    } else if (_vlcBackend) {
      await _bootVlcPlayer();
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

  /// Pick engine for this open: prefs + TS→MediaKit + VLC availability.
  Future<BuiltInPlayerEngine> _resolveBootEngine() async {
    final forced = widget.forceBuiltInEngine;
    var engine = forced ??
        await SettingsService().getBuiltInPlayerEngine(
          context: widget.engineContext,
        );
    if (!engine.isAvailableOnCurrentPlatform) {
      engine = BuiltInPlayerEngine.mediaKit;
    }
    final url = _sources.isNotEmpty ? _sources.first.url : '';
    final isHls = iptvUrlLooksLikeHls(url);
    // Progressive MPEG-TS / non-HLS live → MediaKit + continuity proxy only.
    if (!widget.vodPlayback && !isHls) {
      debugPrint(
        '[IPTV Player] engine=mediakit (progressive TS / non-HLS)',
      );
      return BuiltInPlayerEngine.mediaKit;
    }
    if (engine == BuiltInPlayerEngine.vlc &&
        !await VlcPlayerBridge.isAvailable()) {
      debugPrint('[IPTV Player] VLC unavailable → MediaKit');
      engine = BuiltInPlayerEngine.mediaKit;
    }
    debugPrint('[IPTV Player] engine=${engine.storageKey}');
    return engine;
  }

  void _seedSubtitleQuery() {
    if (!widget.onlineSubtitles) return;
    final raw = (widget.subtitleSearchTitle ?? widget.title).trim();
    final cleaned = cleanMediaTitle(raw);
    _subQueryTitle = cleaned.title.isNotEmpty ? cleaned.title : raw;
    _subQueryYear = widget.subtitleYear ?? cleaned.year;
    _subQuerySeason = widget.subtitleSeason ?? cleaned.season;
    _subQueryEpisode = widget.subtitleEpisode ?? cleaned.episode;
  }

  /// Hot-swap built-in engines from the in-player Player menu.
  /// Set [persist] false for one-shot recovery so IPTV Settings stay unchanged.
  Future<void> _switchBuiltInEngine(
    BuiltInPlayerEngine engine, {
    bool persist = true,
  }) async {
    if (kIsWeb) return;
    if (!engine.isAvailableOnCurrentPlatform) return;
    final url = _sources.isNotEmpty ? _sources[_sourceIdx].url : '';
    final unfit = builtInPlayerEngineUnsuitableReason(
      engine,
      surface: widget.vodPlayback
          ? BuiltInPlayerMenuSurface.iptvVod
          : BuiltInPlayerMenuSurface.iptvLive,
      streamUrl: url,
    );
    if (unfit != null) {
      if (mounted) ForjaToast.info(unfit);
      return;
    }
    if (engine == BuiltInPlayerEngine.vlc &&
        !await VlcPlayerBridge.isAvailable()) {
      if (mounted) {
        ForjaToast.warning('VLC not found. Install VLC or use MediaKit.');
      }
      return;
    }
    if (persist) {
      await SettingsService().setBuiltInPlayerEngine(
        engine,
        context: widget.engineContext,
      );
    }
    if (_disposed || !mounted) return;
    if (engine == _playerEngine) return;

    if (mounted) {
      setState(() {
        _playerReady = false;
        _statusBanner = 'Switching player…';
      });
    }
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !mounted) return;

    await _releaseEngineForHotSwap();
    if (_disposed || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_disposed || !mounted) return;

    if (engine == BuiltInPlayerEngine.exoPlayer ||
        engine == BuiltInPlayerEngine.mediaKit) {
      try {
        await MpvExclusiveSession.instance
            .prepareForVideoPlayer(
              timeout: const Duration(milliseconds: 1200),
            )
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
      if (_disposed || !mounted) return;
      if (engine == BuiltInPlayerEngine.exoPlayer) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (_disposed || !mounted) return;
      }
    }

    _playerEngine = engine;
    _androidMediaKitSafeMode = _mediaKitBackend && !PlatformInfo.isAndroidTv;
    // MediaKit live: never force SW. VOD / non-MK may still use Windows SW.
    _softwareDecodeForced =
        _windowsSoftwareDecode && (!_mediaKitBackend || widget.vodPlayback);
    _player = null;
    _controller = null;
    _exoViewId = null;
    _avViewId = null;
    _vlcViewId = null;
    _vlcTextureId = null;
    _retryAttempt = 0;
    _playbackStopped = false;

    debugPrint('[IPTV Player] engine=${engine.storageKey} (switch)');
    if (_exoBackend) {
      await _bootExoPlayer();
    } else if (_avPlayerBackend) {
      await _bootAvPlayer();
    } else if (_vlcBackend) {
      await _bootVlcPlayer();
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
    if (_avPlayerBackend) {
      final id = _avViewId;
      if (id != null) {
        try {
          await AvPlayerBridge.pause(id);
        } catch (_) {}
      }
      return;
    }
    if (_vlcBackend) {
      final id = _vlcViewId;
      if (id != null) {
        try {
          await VlcPlayerBridge.pause(id);
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
    if (ShellTvFocusCoordinator.consumeOverlayBack()) {
      _tvBackExitArmed = false;
      PlayerBackExitGate.exitReady = false;
      return;
    }
    _exitInProgress = true;
    final nav = Navigator.of(context, rootNavigator: true);
    await _stopPlaybackForExit();
    if (!mounted || _disposed) return;
    // Android: unmount MediaCodec before pop (ANR). Desktop keeps the
    // surface so the slide does not flash the underlay mid-transition.
    if (!kIsWeb && Platform.isAndroid && _playerReady) {
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

  /// After format / hard-open errors, try the other engine once.
  /// Live: one failover hop (platform HLS → MediaKit). VOD may still swap Exo↔MK.
  Future<void> _autoSwapEngineForFormatError(String reason) async {
    if (_disposed || _formatEngineSwapped || kIsWeb) return;
    if (!widget.vodPlayback) {
      await _failoverIptvEngineOnce(reason);
      return;
    }
    if (!Platform.isAndroid) return;
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

  /// One-hop live HLS failover then stop (plan R107-A07).
  Future<void> _failoverIptvEngineOnce(String reason) async {
    if (_disposed || _engineFailoverUsed || widget.vodPlayback) return;
    final url = _sources.isNotEmpty ? _sources[_sourceIdx].url : '';
    if (!iptvUrlLooksLikeHls(url)) return;

    BuiltInPlayerEngine? next;
    if (_avPlayerBackend || _vlcBackend || _exoBackend) {
      next = BuiltInPlayerEngine.mediaKit;
    } else if (_mediaKitBackend) {
      if (!kIsWeb && Platform.isMacOS && AvPlayerBridge.isSupported) {
        next = BuiltInPlayerEngine.avPlayer;
      } else if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
          await VlcPlayerBridge.isAvailable()) {
        next = BuiltInPlayerEngine.vlc;
      } else if (!kIsWeb && Platform.isAndroid) {
        next = BuiltInPlayerEngine.exoPlayer;
      }
    }
    if (next == null || next == _playerEngine) return;
    _engineFailoverUsed = true;
    _formatEngineSwapped = true;
    debugPrint(
      '[IPTV Player] failover ${_playerEngine.storageKey}→${next.storageKey} '
      '($reason)',
    );
    if (mounted) {
      setState(() => _statusBanner = 'Trying ${next!.displayName}…');
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
    unawaited(PortalStore.savePlayerVolume(v));
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
          !InAppMiniPlayerController.instance.isActive &&
          !SettingsService.keepsPlayingInBackground &&
          _playing) {
        _pausedByLifecycle = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      _armDeadSurfaceCoverIfNeeded();
      _resumeAfterAppBackground();
    }
  }

  void _pauseForAppBackground() {
    if (_disposed ||
        _isPipMode ||
        PipService.instance.isDesktopActive ||
        InAppMiniPlayerController.instance.isActive) {
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

  /// Veille kills TextureView / mediacodec_embed; paused decode leaves green YUV.
  void _armDeadSurfaceCoverIfNeeded() {
    if (_disposed ||
        !PlatformInfo.isAndroidTv ||
        _pausedByLifecycle ||
        _playing) {
      return;
    }
    if (_coverDeadSurface) return;
    setState(() => _coverDeadSurface = true);
  }

  void _clearDeadSurfaceCover() {
    if (!_coverDeadSurface) return;
    if (mounted) {
      setState(() => _coverDeadSurface = false);
    } else {
      _coverDeadSurface = false;
    }
  }

  /// Last sports-capable portal for in-player short EPG (opaque store pick).
  Future<void> _initSportsEpgCache() async {
    final portals = await PortalStore.load();
    VerifiedPortal? portal;
    final last = await PortalStore.loadLastPortalKey();
    if (last != null && last.trim().isNotEmpty) {
      for (final p in portals) {
        if (p.key == last && p.portal.platform.supportsForjaSports) {
          portal = p;
          break;
        }
      }
    }
    portal ??= () {
      for (final p in portals) {
        if (p.portal.platform.supportsForjaSports) return p;
      }
      return null;
    }();
    if (portal == null || _disposed || !mounted) return;
    final resolved = portal;
    _sportsPortal = resolved;
    if (!resolved.portal.platform.supportsEpg) return;
    setState(() => _epgCache = GuideEpgCache(resolved));
  }

  /// Channel guide id or active sports source stream id — keys floating EPG.
  String get _floatingEpgKey {
    if (_currentChannelId.isNotEmpty) return _currentChannelId;
    if (_sources.isEmpty) return '';
    final id =
        (_sources[_sourceIdx.clamp(0, _sources.length - 1)].streamId ?? '')
            .trim();
    return id;
  }

  PortalStream? _epgStreamForActiveSource() {
    if (_sources.isEmpty) return null;
    final src = _sources[_sourceIdx.clamp(0, _sources.length - 1)];
    final streamId = (src.streamId ?? '').trim();
    if (streamId.isEmpty) return null;
    return PortalStream(
      streamId: streamId,
      name: src.chromeTitle,
      icon: src.logoUrl ?? '',
      categoryId: '',
      containerExt: 'ts',
      kind: 'live',
      epgChannelId: (src.epgChannelId ?? '').trim(),
    );
  }

  /// My IPTV sports: chrome subtitle = active channel; title stays the match.
  void _syncTitleToActiveSource() {
    if (!widget.titleTracksSource || _sources.isEmpty) return;
    final i = _sourceIdx.clamp(0, _sources.length - 1);
    _subtitle = _sources[i].pickerTitle;
  }

  @override
  void dispose() {
    PlayerBackExitGate.setTryFocusBack(null);
    PlayerBackExitGate.setTryConsumePlayerOverlay(null);
    ShellBus.leavePlayerSurface();
    ShellBus.clearMaskShellUnderPlayer();
    _disposed = true;
    InAppMiniPlayerController.instance.detach(this);
    _miniRootFocus.dispose();
    _miniPlayPauseFocus.dispose();
    _miniExpandFocus.dispose();
    _miniCloseFocus.dispose();
    final stopWait = _stopForNewPlayCompleter;
    if (stopWait != null && !stopWait.isCompleted) {
      stopWait.complete();
    }
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onRemoteControlsActivity);
    _backFocus.dispose();
    _playFocus.dispose();
    _rewind10Focus.dispose();
    _forward10Focus.dispose();
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
    _volumeHoveringN.dispose();
    _subtitleFetchSub?.cancel();
    _exoCueTexts.dispose();
    _playerTvKeyFocus.dispose();
    _seekFocus.dispose();
    unawaited(_finalizeExit());
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_isDesktop) {
      // Exit host fullscreen only when this session has a windowed snapshot
      // (issue 196 / already-fullscreen keep). PiP leave still restores its
      // own saved bounds.
      Future.microtask(() async {
        try {
          if (PipService.instance.isDesktopActive) {
            await PipService.instance.leave();
          }
          await DesktopWindowGeometry.leavePlayerChrome();
        } catch (_) {}
      });
    }
    super.dispose();
  }
}
