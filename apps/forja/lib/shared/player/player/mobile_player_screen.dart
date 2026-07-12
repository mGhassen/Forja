import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/player_source_resolve.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/extractors/arabic_service.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'utils.dart';
import 'menus.dart';
import 'playback_recovery.dart';
import 'playable_source_bridge.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_tv_remote.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/player_metadata.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_episode_menu.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_quality_menu.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';
import 'package:forja/shell/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASS PRIMITIVES  (mobile — press feedback only, no hover)
// ─────────────────────────────────────────────────────────────────────────────

// ── _BlurGlass ──────────────────────────────────────────────────────────────
// Used for ALL buttons/pills. No BackdropFilter — zero extra GPU layers.
// Slightly higher base opacity (0.72) so it reads clearly on black without
// needing blur to give it body.
class _BlurGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool pressed;

  const _BlurGlass({
    required this.child,
    this.radius = 12,
    this.padding,
    this.tint,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? const Color(0xFF1C1C1E);
    final fillOpacity = pressed ? 0.88 : 0.72;
    final borderOpacity = pressed ? 0.32 : 0.18;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: fillOpacity),
            base.withValues(alpha: fillOpacity - 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Glass icon button — touch-friendly 44px default, press animation.
class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool active;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.iconColor,
    this.active = false,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  Color get _tint {
    if (widget.active) return const Color(0xFF6A0DAD);
    if (_pressed) return const Color(0xFF2A2A2E);
    return const Color(0xFF1C1C1E);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: _BlurGlass(                          // ← no blur
          radius: widget.size / 2,
          tint: _tint,
          pressed: _pressed,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor ??
                  (widget.active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass pill button — used for HW badge and aspect ratio label.
class _GlassPillButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color? accent;

  const _GlassPillButton({
    required this.text,
    required this.onTap,
    this.accent,
  });

  @override
  State<_GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<_GlassPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: _BlurGlass(                          // ← no blur
          radius: 20,
          tint: widget.accent ?? const Color(0xFF1C1C1E),
          pressed: _pressed,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            widget.text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: _pressed ? 1.0 : 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Center play/pause button with press animation.
class _GlassPlayPause extends StatefulWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  const _GlassPlayPause({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  @override
  State<_GlassPlayPause> createState() => _GlassPlayPauseState();
}

class _GlassPlayPauseState extends State<_GlassPlayPause> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isBuffering) {
      return _BlurGlass(                             // ← blur OK, only 1 on screen
        radius: 40,
        child: const SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: _BlurGlass(                           // ← blur OK, only 1 on screen
          radius: 40,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Icon(
              widget.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient vignette at top / bottom edges.
class _OverlayGradient extends StatelessWidget {
  final bool isTop;
  const _OverlayGradient({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE  (3-mode cycle)
// ─────────────────────────────────────────────────────────────────────────────

enum _HwDecMode { autoSafe, autoCopy, software }

extension _HwDecModeX on _HwDecMode {
  /// The mpv property value for this mode.
  String get mpvValue => switch (this) {
        _HwDecMode.autoSafe => 'auto-safe',
        _HwDecMode.autoCopy => 'auto-copy',
        _HwDecMode.software => 'no',
      };

  /// Short label shown on the badge pill.
  String get label => switch (this) {
        _HwDecMode.autoSafe => 'HW+',
        _HwDecMode.autoCopy => 'COPY',
        _HwDecMode.software => 'SW',
      };

  String get description => switch (this) {
        _HwDecMode.autoSafe => 'Hardware Decoding: ON (GPU, safe)',
        _HwDecMode.autoCopy => 'Hardware Decoding: ON (copy-back)',
        _HwDecMode.software => 'Hardware Decoding: OFF (CPU)',
      };

  _HwDecMode get next => switch (this) {
        _HwDecMode.autoSafe => _HwDecMode.autoCopy,
        _HwDecMode.autoCopy => _HwDecMode.software,
        _HwDecMode.software => _HwDecMode.autoSafe,
      };

  Color get accent => switch (this) {
        _HwDecMode.autoSafe => const Color(0xFF7C3AED),
        _HwDecMode.autoCopy => const Color(0xFF0EA5E9),
        _HwDecMode.software => const Color(0xFF3A3A3C),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MobilePlayerScreen extends StatefulWidget {
  final String mediaPath;
  final String title;
  final String? audioUrl;
  final Map<String, String>? headers;
  final Movie? movie;
  final int? selectedSeason;
  final int? selectedEpisode;
  final String? magnetLink;
  final String? activeProvider;
  final Duration? startPosition;
  final List<StreamSource>? sources;
  final int? fileIndex;
  final List<Map<String, dynamic>>? externalSubtitles;
  final String? stremioId;
  final String? stremioAddonBaseUrl;
  final Map<String, dynamic>? providers;
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;
  final List<PlayerHubEpisode>? hubEpisodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerHubEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final Future<void> Function(Duration position, Duration duration)? onSaveProgress;
  final Future<void> Function(String sourceUrl, String sourceTitle)? onSourcePinned;
  final bool pinSource;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final ValueNotifier<List<StreamSource>>? sourcesListNotifier;
  final ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final bool tvRemoteEnabled;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

  const MobilePlayerScreen({
    super.key,
    required this.mediaPath,
    required this.title,
    this.audioUrl,
    this.headers,
    this.movie,
    this.selectedSeason,
    this.selectedEpisode,
    this.magnetLink,
    this.activeProvider,
    this.startPosition,
    this.sources,
    this.fileIndex,
    this.externalSubtitles,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.providers,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.hubEpisodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.onSaveProgress,
    this.onSourcePinned,
    this.pinSource = false,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.onReloadStreams,
    this.sourcesListNotifier,
    this.providerSourcesCache,
    this.providerProbesNotifier,
    this.tvRemoteEnabled = false,
    this.builtInEngine = BuiltInPlayerEngine.mediaKit,
    this.onSwitchPlayer,
  });

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Player ──────────────────────────────────────────────────────────────
  late final Player _player;
  late final VideoController _controller;
  bool _disposed = false;
  int _fallbackGen = 0;
  bool _historySaved = false;
  bool _hasError = false;
  String _errorMessage = '';

  // ── UI State ─────────────────────────────────────────────────────────────
  bool _showControls = true;
  final FocusNode _playerTvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
  Movie? _heroMovie;
  String? _episodeOverview;
  bool _isLocked = false;
  Timer? _hideTimer;
  BoxFit _videoFit = BoxFit.contain;

  // ── Resume ────────────────────────────────────────────────────────────────
  bool _hasInitialSeek = false;

  // ── Stream Subscriptions ──────────────────────────────────────────────────
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<PlayerLog>? _logSub;
  PlaybackRecovery? _playbackRecovery;
  StreamSubscription<bool>? _pipSub;
  bool _autoTracksAppliedForSource = false;
  bool _androidMediaKitSafeMode = false;
  bool _isAndroidTv = false;

  // ── PiP State ─────────────────────────────────────────────────────────────
  bool _isPipMode = false;

  // ── Value Notifiers ───────────────────────────────────────────────────────
  final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _bufferedNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);

  // ── Gesture State ─────────────────────────────────────────────────────────
  double _volume = 50.0;       // 0–150 (mpv supports >100%)
  double _brightness = 0.5;    // 0.0..1.0 (screen brightness)
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorHideTimer;

  // ── Double-tap ripple ─────────────────────────────────────────────────────
  late final AnimationController _rippleController;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;
  bool _showRipple = false;
  bool _isForward = true;
  Offset _ripplePosition = Offset.zero;

  // ── Subtitles ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _externalSubtitles = [];
  /// When true, the current subtitle is ASS/SSA or an image-based format (PGS/VobSub).
  /// mpv renders it directly on the video frame, so the custom Flutter overlay is hidden.
  bool _isNativeSubtitle = false;

  // ── Provider switching ────────────────────────────────────────────────────
  String? _currentProvider;
  List<StreamSource>? _currentSources;
  List<PlayableSource>? _playableSources;
  String? _currentUrl;
  String? _activeMagnet;
  // ── HLS Quality Selector ─────────────────────────────────────────────────
  // Populated when the playing URL is a master HLS playlist with 2+
  // variants. The gear button in the top control bar is hidden until this
  // notifier holds a non-empty list.
  final ValueNotifier<List<HlsQuality>?> _hlsQualitiesNotifier = ValueNotifier(null);
  String? _hlsMasterUrl;
  Map<String, String>? _hlsMasterHeaders;
  String? _currentQualityUrl;
  /// For provider == 'service111477', the upstream fileUrl currently playing
  /// (the menu compares against this rather than the localhost proxy URL).
  String? _current111477FileUrl;
  int _currentFallbackSourceIndex = 0;
  bool _providerPinned = false;
  bool _sourcePinned = false;
  bool _audioPinned = false;
  bool _subtitlePinned = false;
  final PlayerStatusController _statusController = PlayerStatusController();
  final Set<int> _failedSourceIndices = {};
  final Set<int> _checkingSourceIndices = {};
  final ValueNotifier<int> _sourceMenuRevision = ValueNotifier(0);
  final ValueNotifier<bool> _isReloadingStreams = ValueNotifier(false);
  bool _isSwitchingProvider = false;
  bool _isInitPlaybackRunning = false;
  bool _allSourcesExhaustedNotified = false;
  bool _playbackConfirmed = false;
  bool _isFetchingSubs = false;
  String? _selectedExternalSubUrl;

  // ── Feature State ─────────────────────────────────────────────────────────
  _HwDecMode _hwDecMode = _HwDecMode.autoSafe;
  bool _loopEnabled = false;
  double _subtitleDelay = 0.0;
  double _subtitleSize = 24.0;
  double _subtitleBottomPadding = 24.0;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0.67;
  bool _subtitleBold = false;
  String _subtitleFont = 'Default';

  // ── Next Episode State ────────────────────────────────────────────────────
  bool _isLoadingNextEp = false;
  bool _nearEndOfEpisode = false;

  // ── Skip Segments (IntroDB) ───────────────────────────────────────────────
  IntroDbResponse? _introDbData;
  String? _activeSkipLabel;
  Duration? _activeSkipTarget;
  bool _skipDismissed = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // ── Provider initialization ──────────────────────────────────────────
    _currentProvider = widget.activeProvider;
    _sourcePinned = widget.pinSource;
    _currentSources = widget.sources == null
        ? null
        : dedupeStreamSources(widget.sources!);
    unawaited(_initPlayableSources());
    _currentUrl = widget.mediaPath;
    _activeMagnet = widget.magnetLink;
    if (_currentProvider == 'service111477' &&
        widget.sources != null &&
        widget.sources!.isNotEmpty) {
      _current111477FileUrl = widget.sources!.first.url;
    }
    widget.sourcesListNotifier?.addListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.addListener(_onLiveSourcesUpdated);
    if (widget.tvRemoteEnabled) {
      _hwDecMode = _HwDecMode.software;
    }

    // ── Lifecycle Observer ───────────────────────────────────────────────
    WidgetsBinding.instance.addObserver(this);
    if (widget.tvRemoteEnabled) {
      HardwareKeyboard.instance.addHandler(_handleTvKeyEvent);
    }

    _loadHeroMetadata();

    // ── PiP status listener (Android system PiP) ─────────────────────────
    // When entering PiP we hide all UI and force-resume playback if
    // currently paused. When leaving PiP we show controls again.
    _pipSub = PipService.instance.androidPipChanges.listen((inPip) {
      if (_disposed || !mounted) return;
      setState(() {
        _isPipMode = inPip;
        if (inPip) {
          _showControls = false;
          _hideTimer?.cancel();
        }
      });
      if (inPip) {
        // Auto-resume if paused so PiP isn't a static frame.
        if (!_player.state.playing) {
          _player.play();
        }
      }
    });

    // ── System UI ────────────────────────────────────────────────────────
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Orientation is set in addPostFrameCallback below — after the
    // first frame renders — to avoid fighting the portrait lock while
    // the widget tree is still building.
    WakelockPlus.enable();

    // Android MediaKit fallback: software-friendly decode (user chose MediaKit
    // over ExoPlayer in Settings).
    if (Platform.isAndroid) {
      _androidMediaKitSafeMode = true;
      _hwDecMode = _HwDecMode.software;
    }

    // ── Player ───────────────────────────────────────────────────────────
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
        // libass enabled so ASS/SSA subtitles render natively on the video.
        // For SRT/VTT we dynamically set sub-visibility=no so our custom
        // Flutter overlay still handles those.
        libass: true,
        // On Android, libass cannot access system fonts via fontconfig.
        // We must bundle a default font in assets and provide it here.
        libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
        libassAndroidFontName: 'Roboto',
      ),
    );

    // androidAttachSurfaceAfterVideoParameters: false fixes a blank-screen
    // race condition on some Android devices where the surface is attached
    // before mpv has negotiated video dimensions.
    // ATV emulators often lack a working GLES stack — HW decode + GPU
    // surface fails with EGL_BAD_ATTRIBUTE right after the first frame.
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration:
            !widget.tvRemoteEnabled && !_androidMediaKitSafeMode,
        hwdec: (widget.tvRemoteEnabled || _androidMediaKitSafeMode)
            ? 'no'
            : null,
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );

    // ── Ripple animation ─────────────────────────────────────────────────
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _rippleScale = Tween<double>(begin: 0.4, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showRipple = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (Platform.isAndroid) {
        _isAndroidTv = await ExoPlayerBridge.isTelevision();
      }
      await waitForRouteTransition(context);
      if (!mounted) return;
      if (!widget.tvRemoteEnabled && !_isAndroidTv) {
        // Lock to landscape and wait for the rotation to physically
        // complete before starting heavy media work.  Starting codec
        // initialization while the surface is still rotating causes
        // BLASTBufferQueue saturation and orientation ping-pong.
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
        ]);
        // Let Android finish the rotation & surface resize.
        // MediaTek/Transsion devices need a longer wait — the
        // fbcNotifyBufferUX storm can last several seconds.
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
      }

      _loadSubtitlePrefs();
      _initPlayback();
      _startHideTimer();
      _fetchSubtitles();
      // Initialize brightness from current screen level.
      // ScreenBrightness only works reliably on mobile — on desktop it
      // spams "Problem getting monitor brightness" errors because most
      // external monitors lack DDC/CI support.
      if (Platform.isAndroid || Platform.isIOS) {
        ScreenBrightness().application.then((b) {
          if (mounted) setState(() => _brightness = b);
        }).catchError((_) {
          ScreenBrightness().system.then((b) {
            if (mounted) setState(() => _brightness = b);
          }).catchError((_) {});
        });
      }
      // Trakt scrobble start
      if (widget.movie != null) {
        TraktService().scrobbleStart(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: 0,
        );
        SimklService().scrobbleStart(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
      }
      // Fetch skip segments from IntroDB
      _fetchIntroDbTimestamps();
    });
  }

  Future<void> _initPlayableSources() async {
    if (widget.sources == null || widget.sources!.isEmpty) return;
    final ranked = await PlayableSourceBridge.rankWidgetSources(
      sources: widget.sources,
      providerId: _currentProvider,
    );
    if (_disposed || !mounted) return;
    setState(() {
      _playableSources = ranked;
      _currentSources = playableSourcesToStreamSources(ranked);
    });
  }

  Future<void> _fetchIntroDbTimestamps() async {
    if (widget.movie == null) return;
    final data = await IntroDbService().getTimestamps(
      tmdbId: widget.movie!.id,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      imdbId: widget.movie!.imdbId,
    );
    if (mounted && data != null && data.hasAnySegments) {
      setState(() => _introDbData = data);
    }
  }

  @override
  void dispose() {
    widget.sourcesListNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onLiveSourcesUpdated);
    _saveWatchHistory();

    _fallbackGen++;
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    NuvioService.instance.cancelPending();

    // Restore screen brightness to system default (mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      try { ScreenBrightness().resetApplicationScreenBrightness(); } catch (_) {}
    }

    // Don't set orientation here — _exitPlayer() already locks portrait
    // BEFORE popping.  Changing orientation during dispose while
    // media_kit's surface is being torn down causes BLASTBufferQueue
    // errors and hundreds of dropped frames.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _disposed = true;
    if (widget.tvRemoteEnabled) {
      HardwareKeyboard.instance.removeHandler(_handleTvKeyEvent);
    }
    _playerTvKeyFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _indicatorHideTimer?.cancel();
    PlayerTorrentFilePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    _rippleController.dispose();

    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _logSub?.cancel();
    _pipSub?.cancel();

    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _bufferedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    _hlsQualitiesNotifier.dispose();
    _statusController.dispose();
    _sourceMenuRevision.dispose();
    _isReloadingStreams.dispose();

    _player.dispose();

    // Remove torrent from engine on player exit (use magnetLink for hash,
    // fall back to mediaPath which may be a stream URL).
    final torrentId = widget.magnetLink ?? widget.mediaPath;
    TorrentStreamService().removeTorrent(torrentId);

    // Tear down the 111477 proxy and delete its on-disk cache.
    if (site111477_proxy.is111477ProxyRunning) {
      // Fire-and-forget — dispose() can't be async.
      site111477_proxy.stop111477Proxy();
    }

    WakelockPlus.disable();

    super.dispose();
  }

  /// Rotate back to portrait & restore system UI BEFORE popping,
  /// so the details page never sees stale landscape dimensions.
  Future<void> _exitPlayer() async {
    _saveWatchHistory();
    // Unlock orientation so the rest of the app follows system settings.
    await SystemChrome.setPreferredOrientations([]);
    // Let the rotation finish before popping — avoids BLASTBufferQueue
    // errors from media_kit surface teardown during an active rotation.
    await Future.delayed(const Duration(milliseconds: 300));
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (mounted) Navigator.of(context).pop(_positionNotifier.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // Save local history + send scrobblePause (not stop — user may return)
      _saveWatchHistory(isBgPause: true);
    } else if (state == AppLifecycleState.resumed) {
      // Tell Trakt we're back
      _historySaved = false; // allow re-save on next exit
      if (widget.movie != null && _isPlayingNotifier.value) {
        final pos = _positionNotifier.value.inMilliseconds;
        final dur = _durationNotifier.value.inMilliseconds;
        final pct = dur > 0 ? (pos / dur * 100) : 0.0;
        TraktService().scrobbleStart(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: pct,
        );
      }
    }
  }

  void _saveWatchHistory({bool isBgPause = false}) {
    if (_historySaved && !isBgPause) return; // prevent double stop
    _historySaved = true;
    final pos = _positionNotifier.value.inMilliseconds;
    final dur = _durationNotifier.value.inMilliseconds;

    // External progress hook (anime / arabic flows persist their own
    // per-source history). Always fire while we have a real position so
    // the resume rail picks up where we left off.
    if (widget.onSaveProgress != null && pos > 5000) {
      widget.onSaveProgress!(
        Duration(milliseconds: pos),
        Duration(milliseconds: dur),
      );
    }

    // Save anime watch position
    if (widget.activeProvider != null &&
        widget.activeProvider!.startsWith('anime_') &&
        pos > 10000 && dur > 0) {
      _saveAnimeWatchPosition(pos, dur);
    }

    if (widget.movie == null || widget.hubEpisodes != null) return;
    if (pos > 10000 && dur > 0) {
      final isTorrent = widget.magnetLink != null;
      final isStremioDirect = widget.activeProvider == 'stremio_direct';
      final String method;
      final String sourceId;
      if (isTorrent) {
        method = 'torrent';
        sourceId = widget.magnetLink!;
      } else if (isStremioDirect) {
        method = 'stremio_direct';
        sourceId = widget.mediaPath;
      } else if (widget.activeProvider == 'amri') {
        method = 'amri';
        sourceId = widget.mediaPath;
      } else if (widget.activeProvider != null) {
        method = 'stream';
        sourceId = widget.activeProvider!;
      } else {
        method = 'amri';
        sourceId = widget.mediaPath;
      }
      WatchHistoryService().saveProgress(
        tmdbId: widget.movie!.id,
        imdbId: widget.movie!.imdbId,
        title: _displayTitle,
        posterPath: widget.movie!.posterPath,
        backdropPath: widget.movie!.backdropPath,
        method: method,
        sourceId: sourceId,
        position: pos,
        duration: dur,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
        episodeTitle: widget.selectedEpisode != null
            ? 'Episode ${widget.selectedEpisode}'
            : null,
        magnetLink: widget.magnetLink,
        fileIndex: widget.fileIndex,
        streamUrl: isStremioDirect ? widget.mediaPath : null,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        stremioType: widget.movie!.mediaType == 'tv' ? 'series' : 'movie',
        mediaType: widget.movie!.mediaType,
      );

      // Trakt + Simkl scrobble — fire and forget
      final progressPercent = dur > 0 ? (pos / dur * 100) : 0.0;
      if (isBgPause) {
        // App backgrounded — pause, don't stop (user may return)
        TraktService().scrobblePause(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: progressPercent,
        );
      } else {
        TraktService().scrobbleStop(
          tmdbId: widget.movie!.id,
          mediaType: widget.movie!.mediaType,
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          progressPercent: progressPercent,
        );
      }
      SimklService().scrobbleStop(
        tmdbId: widget.movie!.id,
        mediaType: widget.movie!.mediaType,
        season: widget.selectedSeason,
        episode: widget.selectedEpisode,
      );
    }
  }

  void _saveAnimeWatchPosition(int posMs, int durMs) {
    SharedPreferences.getInstance().then((prefs) {
      final list = prefs.getStringList('anime_watch_history') ?? [];
      for (int i = 0; i < list.length; i++) {
        final entry = jsonDecode(list[i]) as Map<String, dynamic>;
        // Match by title which contains the anime name + episode
        // The most recent entry (index 0) is the one currently playing
        if (i == 0) {
          entry['position'] = posMs;
          entry['duration'] = durMs;
          list[i] = jsonEncode(entry);
          prefs.setStringList('anime_watch_history', list);
          break;
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PLAYBACK INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _trySourcesFromIndex(
    int startIndex, {
    int? chainGen,
    Duration? seekAfterOpen,
  }) async {
    if (_currentSources == null || _currentSources!.isEmpty) return false;

    final triedUrls = <String>{};
    _currentFallbackSourceIndex = startIndex;

    while (_currentFallbackSourceIndex < _currentSources!.length) {
      if (chainGen != null && _fallbackAborted(chainGen)) return false;

      final i = _currentFallbackSourceIndex;
      var source = _currentSources![i];

      if (triedUrls.contains(source.url)) {
        debugPrint('[Player] Skipping duplicate URL at index $i');
        _currentFallbackSourceIndex++;
        continue;
      }
      triedUrls.add(source.url);

      debugPrint(
        '[Player] Trying source ${i + 1}/${_currentSources!.length}: ${source.title}',
      );
      _markSourceChecking(i);
      _statusController.upsert(
        'source-$i',
        source.title,
        kind: StatusRouletteKind.loading,
      );

      if (PlayableSourceBridge.isArabicEmbed(_playableSources, i, source)) {
        debugPrint('[Player] Extracting arabic embed: ${source.title}');
        final result = await ArabicService.extractStreamUrl(source.url);
        if (result == null) {
          debugPrint('[Player] Arabic extract failed for ${source.title}');
          _statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 1200),
          );
          _markSourceFailed(i);
          _currentFallbackSourceIndex++;
          continue;
        }
        source = StreamSource(
          url: result.url,
          title: source.title,
          type: result.url.contains('.m3u8')
              ? 'hls'
              : result.url.contains('.mpd')
                  ? 'dash'
                  : 'mp4',
        );
        _currentSources![i] = source;
      }

      try {
        _durationNotifier.value = Duration.zero;
        _positionNotifier.value = Duration.zero;
        _bufferedNotifier.value = Duration.zero;
        await _configureMpvProperties();
        final srcHeaders = source.headers ?? widget.headers;

        var openUrl = source.url;
        if (PlayableSourceBridge.requiresProxy(_playableSources, i, _currentProvider)) {
          if (!site111477_proxy.is111477ProxyRunning ||
              _current111477FileUrl != source.url) {
            if (site111477_proxy.is111477ProxyRunning) {
              await site111477_proxy.stop111477Proxy();
            }
            openUrl = await site111477_proxy.start111477Proxy(source.url);
            _current111477FileUrl = source.url;
          } else {
            openUrl = site111477_proxy.site111477ProxyUrl!;
          }
        }

        await resetPlayerForOpen(_player);
        await applyMediaHttpHeaders(_player, srcHeaders);
        await _player.open(Media(openUrl, httpHeaders: srcHeaders));
        _player.setVolume(_volume);
        final opened = await waitForMediaOpen(
          _player,
          streamUrl: openUrl,
          timeout: isLocalTorrentStreamUrl(openUrl)
              ? const Duration(seconds: 45)
              : const Duration(seconds: 12),
        );
        if (!opened) {
          debugPrint('[Player] Source $i failed to open: $openUrl');
          await _player.stop();
          _statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 1200),
          );
          _markSourceFailed(i);
          _currentFallbackSourceIndex++;
          continue;
        }
        final needsDuration =
            sourceExpectsDuration(openUrl, type: source.type);
        if (sourceRequiresVideoDecode(openUrl, type: source.type) &&
            !await waitForVideoDecode(_player)) {
          debugPrint('[Player] Source $i opened without video: $openUrl');
          await _player.stop();
          _statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 1200),
          );
          _markSourceFailed(i);
          _currentFallbackSourceIndex++;
          continue;
        }
        if (needsDuration &&
            !await waitForSeekableDuration(
              _player,
              timeout: widget.tvRemoteEnabled
                  ? const Duration(seconds: 15)
                  : const Duration(seconds: 5),
            )) {
          debugPrint('[Player] Source $i opened without duration: $openUrl');
          await _player.stop();
          _statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 1200),
          );
          _markSourceFailed(i);
          _currentFallbackSourceIndex++;
          continue;
        }
        syncPlayerProgressNotifiers(
          _player,
          duration: _durationNotifier,
          position: _positionNotifier,
          buffered: _bufferedNotifier,
        );
        if (seekAfterOpen != null && seekAfterOpen.inSeconds > 0) {
          await _player.seek(seekAfterOpen);
        }
        _detectHlsQualities(openUrl, srcHeaders);
        setState(() {
          _currentUrl = openUrl;
        });
        _playbackConfirmed = true;
        _statusController.complete();
        _markSourceActive(i);
        widget.onPlaybackStarted?.call();
        await _ensureTvPlaybackStarted();
        return true;
      } catch (e) {
        debugPrint('[Player] Source $i catch error: $e');
        await _player.stop();
        _statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        _markSourceFailed(i);
        _currentFallbackSourceIndex++;
      }
    }
    return false;
  }

  Future<void> _ensureTvPlaybackStarted() async {
    if (!widget.tvRemoteEnabled || _disposed) return;
    if (_player.state.playing) return;
    try {
      await _player.play();
    } catch (e) {
      debugPrint('[Player] TV play() failed: $e');
    }
  }

  Future<void> _initPlayback({int sourceStartIndex = 0}) async {
    if (_disposed) return;
    if (_isInitPlaybackRunning) return; // Prevent re-entrant calls during async extraction
    _isInitPlaybackRunning = true;
    _playbackConfirmed = false;
    
    try {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    if (_currentSources != null && _currentSources!.isNotEmpty) {
      _subscribeToStreams();
      final played = await _trySourcesFromIndex(sourceStartIndex);
      if (played) return;

      if (!_providerPinned) {
        await _autoFallbackToNextProvider();
      } else if (mounted) {
        notifyNoServerAvailable(_statusController);
        setState(() {
          _hasError = true;
          _showControls = true;
          _errorMessage = 'All sources on this server failed.';
        });
        _notifyAllSourcesExhausted();
      }
    } else {
      // No sources list — primary mediaPath (torrent localhost or direct URL).
      final openUrl = widget.mediaPath;
      final isTorrent = isLocalTorrentStreamUrl(openUrl) ||
          widget.magnetLink != null;
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount < maxRetries) {
        try {
          _subscribeToStreams();
          await _configureMpvProperties();
          await resetPlayerForOpen(_player);
          await applyMediaHttpHeaders(_player, widget.headers);
          await _player.open(Media(openUrl, httpHeaders: widget.headers));
          _player.setVolume(_volume);
          final opened = await waitForMediaOpen(
            _player,
            streamUrl: openUrl,
            timeout: isTorrent
                ? const Duration(seconds: 45)
                : const Duration(seconds: 12),
          );
          if (!opened) {
            throw Exception('Failed to open media');
          }
          _detectHlsQualities(openUrl, widget.headers);
          _playbackConfirmed = true;
          widget.onPlaybackStarted?.call();
          await _ensureTvPlaybackStarted();
          return;
        } catch (e) {
          retryCount++;
          debugPrint('[Player] Primary open failed ($retryCount/$maxRetries): $e');
          if (retryCount >= maxRetries) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _showControls = true;
                _errorMessage = isTorrent
                    ? 'Torrent stream failed to open.'
                    : 'Playback failed.';
              });
            }
            await _autoFallbackToNextProvider();
            return;
          }
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }
    }
    } finally {
      _isInitPlaybackRunning = false;
    }
  }

  Future<void> _autoFallbackToNextProvider() async {
    if (widget.providers == null || widget.providers!.isEmpty) {
      notifyNoServerAvailable(_statusController);
      setState(() {
        _hasError = true;
        _showControls = true;
        _errorMessage = 'All sources and providers failed.';
      });
      _notifyAllSourcesExhausted();
      return;
    }

    final chainGen = _fallbackGen;
    final providerKeys = PlayerSourceResolve.failoverChain(
      movie: widget.movie,
      providers: widget.providers!,
      currentProviderId: _currentProvider,
    );
    
    for (final nextKey in providerKeys) {
      if (_fallbackAborted(chainGen)) return;
      debugPrint('[Player] Auto-falling back to provider: $nextKey');
      
      final success = await _silentSwitchProvider(nextKey, chainGen: chainGen);
      if (success) return;
    }

    if (mounted && !_fallbackAborted(chainGen)) {
      notifyNoServerAvailable(_statusController);
      setState(() {
        _hasError = true;
        _showControls = true;
        _errorMessage = 'Could not find any working stream from any provider.';
      });
      _notifyAllSourcesExhausted();
    }
  }

  void _notifyAllSourcesExhausted() {
    if (widget.onAllSourcesExhausted == null || _allSourcesExhaustedNotified) {
      return;
    }
    _allSourcesExhaustedNotified = true;
    widget.onAllSourcesExhausted!();
  }

  bool _fallbackAborted(int chainGen) =>
      !mounted || _disposed || chainGen != _fallbackGen;

  /// Switches provider without showing full error UI on failure, returns success
  Future<bool> _silentSwitchProvider(String newProvider, {int? chainGen}) async {
    final gen = chainGen ?? _fallbackGen;
    if (_fallbackAborted(gen)) return false;
    final provider = widget.providers![newProvider];
    final providerLabel = PlayerProviderMenu.snackbarLabel(newProvider, provider);
    _statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.loading,
    );
    try {
      String? streamUrl;
      Map<String, String>? headers;
      List<StreamSource>? sources;

      final movie = widget.movie;
      final providers = widget.providers;
      if (movie != null && providers != null) {
        if (newProvider == 'service111477' &&
            site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        final hit = await PlayerSourceResolve.resolvePinned(
          movie: movie,
          providers: providers,
          providerId: newProvider,
          season: widget.selectedSeason ?? 1,
          episode: widget.selectedEpisode ?? 1,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return false;
        if (hit != null) {
          streamUrl = hit.streamUrl;
          headers = hit.headers;
          sources = hit.streamSources;
        }
      }
      
      if (_fallbackAborted(gen)) return false;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        final resolvedSources = sources != null && sources.isNotEmpty
            ? dedupeStreamSources(sources)
            : [
                StreamSource(
                  url: streamUrl,
                  title: providerLabel,
                  type: streamUrl.toLowerCase().contains('.m3u8')
                      ? 'hls'
                      : streamUrl.toLowerCase().contains('.mpd')
                          ? 'dash'
                          : 'mp4',
                  headers: headers,
                ),
              ];

        _statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.success,
        );

        setState(() {
          _currentProvider = newProvider;
          _currentSources = resolvedSources;
          _currentFallbackSourceIndex = 0;
          _hasError = false;
          _errorMessage = '';
          if (newProvider == 'service111477' && resolvedSources.isNotEmpty) {
            _current111477FileUrl = resolvedSources.first.url;
          }
        });

        final currentPos = _positionNotifier.value;
        final played = await _trySourcesFromIndex(
          0,
          chainGen: gen,
          seekAfterOpen: currentPos,
        );
        if (played) return true;

        _statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1200),
        );
        return false;
      }
    } catch (e) {
      debugPrint('[Player] Silent fallback to $newProvider failed: $e');
    }
    _statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.failed,
      dismissAfter: const Duration(milliseconds: 1200),
    );
    return false;
  }

  void _subscribeToStreams() {
    // Cancel any existing subscriptions to prevent duplicate listeners
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _logSub?.cancel();
    _autoTracksAppliedForSource = false;

    if (widget.builtInEngine == BuiltInPlayerEngine.mediaKit) {
      _playbackRecovery = PlaybackRecovery(
        player: _player,
        onRetryNextSource: () {
          final next = _currentFallbackSourceIndex + 1;
          if (_currentSources != null && next < _currentSources!.length) {
            _initPlayback(sourceStartIndex: next);
          } else if (!_providerPinned) {
            _autoFallbackToNextProvider();
          }
        },
        onForceSoftwareDecode: () async {
          if (_player.platform is! NativePlayer) return;
          await (_player.platform as NativePlayer).setProperty('hwdec', 'no');
        },
      );
    }

    _positionSub = _player.stream.position.listen((pos) {
      if (_disposed) return;
      _positionNotifier.value = pos;

      // Near-end detection for next episode button
      if (_isNextEpisodeAvailable && !_nearEndOfEpisode) {
        final dur = _durationNotifier.value;
        if (dur.inSeconds > 0) {
          final remaining = dur - pos;
          final threshold = dur.inMinutes < 10
              ? Duration(seconds: (dur.inSeconds * 0.05).round())
              : const Duration(minutes: 2);
          if (remaining <= threshold) {
            setState(() => _nearEndOfEpisode = true);
          }
        }
      }

      // Skip segment detection (IntroDB)
      _updateActiveSkipSegment(pos);
    });

    _durationSub = _player.stream.duration.listen((dur) {
      if (_disposed) return;
      _durationNotifier.value = dur;
      if (!_hasInitialSeek &&
          dur.inSeconds > 0 &&
          widget.startPosition != null) {
        _hasInitialSeek = true;
        // mpv 'start' property handles the initial seek natively (set in
        // _configureMpvProperties). Fire a deferred seek as a safety net in
        // case the property was ignored (e.g. live streams, non-seekable src).
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed) return;
          final currentPos = _positionNotifier.value;
          // Only seek if the player didn't already land near the target
          // (i.e. the 'start' property worked).
          final target = widget.startPosition!;
          if ((currentPos - target).abs() > const Duration(seconds: 5)) {
            _player.seek(target);
          }
        });
      }
    });

    _bufferSub = _player.stream.buffer.listen((buf) {
      if (_disposed) return;
      _bufferedNotifier.value = buf;
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (_disposed) return;
      _isPlayingNotifier.value = playing;
      if (playing) {
        _startHideTimer();
        // Scrobble resume
        if (widget.movie != null) {
          final pos = _positionNotifier.value.inMilliseconds;
          final dur = _durationNotifier.value.inMilliseconds;
          final pct = dur > 0 ? (pos / dur * 100) : 0.0;
          TraktService().scrobbleStart(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
            progressPercent: pct,
          );
          SimklService().scrobbleStart(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
          );
        }
      } else {
        if (mounted) setState(() => _showControls = true);
        // Scrobble pause
        if (widget.movie != null) {
          final pos = _positionNotifier.value.inMilliseconds;
          final dur = _durationNotifier.value.inMilliseconds;
          final pct = dur > 0 ? (pos / dur * 100) : 0.0;
          TraktService().scrobblePause(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
            progressPercent: pct,
          );
          SimklService().scrobblePause(
            tmdbId: widget.movie!.id,
            mediaType: widget.movie!.mediaType,
            season: widget.selectedSeason,
            episode: widget.selectedEpisode,
          );
        }
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (_disposed) return;
      _isBufferingNotifier.value = buffering;
    });

    // Surface only fatal errors — transient network blips are handled by mpv
    _errorSub = _player.stream.error.listen((err) {
      if (_disposed || err.isEmpty) return;
      final currentUrl = _currentSources != null &&
              _currentFallbackSourceIndex < _currentSources!.length
          ? _currentSources![_currentFallbackSourceIndex].url
          : null;
      if (isVideoDecoderError(err)) {
        debugPrint('🔴 [MobilePlayer] video decoder error: $err');
        _playbackRecovery?.handlePlayerError(err, currentUrl: currentUrl);
        return;
      }
      if (isIgnorablePlayerError(err)) {
        if (err.toLowerCase().contains('subtitle') ||
            err.toLowerCase().contains('sub-add')) {
          debugPrint('🟡 [MobilePlayer] sub error (ignored): $err');
        }
        return;
      }

      debugPrint('🔴 [MobilePlayer] $err');

      if (!isFatalPlayerOpenError(err)) return;
      if (_hasError || _isInitPlaybackRunning) {
        if (_isInitPlaybackRunning) {
          debugPrint('[Player] Ignoring stale error — _initPlayback already running');
        }
        return;
      }
      if (!_playbackConfirmed) {
        debugPrint('[Player] Ignoring open error — probe handles fallback');
        return;
      }
      _playbackConfirmed = false;
      if (_sourcePinned) {
        setState(() {
          _hasError = true;
          _showControls = true;
          _errorMessage = 'Playback failed on the selected source.';
        });
        return;
      }
      final next = _currentFallbackSourceIndex + 1;
      if (_currentSources != null && next < _currentSources!.length) {
        debugPrint(
          '[Player] Fatal error on source $_currentFallbackSourceIndex, trying $next...',
        );
        _initPlayback(sourceStartIndex: next);
        return;
      }
      if (!_providerPinned) {
        debugPrint('[Player] Fatal error — no more sources, trying next provider...');
        _autoFallbackToNextProvider();
        return;
      }
      setState(() {
        _hasError = true;
        _showControls = true;
        _errorMessage = 'Playback failed on all sources.';
      });
    });

    _logSub = _player.stream.log.listen((l) {
      if (_disposed) return;
      _playbackRecovery?.handleMpvLog(l.text);
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (_disposed || !completed) return;
      if (!_playbackConfirmed || _isInitPlaybackRunning) return;
      if (isNaturalPlaybackEnd(_player.state)) {
        if (mounted) setState(() => _showControls = true);
        return;
      }
      final pos = _player.state.position.inMilliseconds;
      if (_sourcePinned || pos > 10000) return;
      final next = _currentFallbackSourceIndex + 1;
      if (_currentSources == null || next >= _currentSources!.length) return;
      debugPrint(
        '[Player] Abortive end at ${pos}ms on source '
        '${_currentFallbackSourceIndex + 1}/${_currentSources!.length} — trying next',
      );
      _playbackConfirmed = false;
      _initPlayback(sourceStartIndex: next);
    });

    _tracksSub = _player.stream.tracks.listen((tracks) {
      if (_disposed || _autoTracksAppliedForSource) return;
      // Only run once we have at least one real audio track to choose from.
      final hasAudio = tracks.audio.any((t) => t.id != 'no' && t.id != 'auto');
      if (!hasAudio) return;
      _autoTracksAppliedForSource = true;
      // Defer slightly so mpv has finished probing all tracks/metadata.
      Future.delayed(const Duration(milliseconds: 600), _applyTrackAutoSelect);
    });
  }

  Future<void> _applyTrackAutoSelect() async {
    if (_disposed) return;
    try {
      final settings = SettingsService();
      final audioLang = await settings.getPreferredAudioLanguage();
      final avoidUnsupported = await settings.getAvoidUnsupportedAudio();
      if (audioLang == 'None' && !avoidUnsupported) return;

      final result = computeAutoSelect(
        audioTracks: _player.state.tracks.audio,
        subtitleTracks: _player.state.tracks.subtitle,
        currentAudio: _player.state.track.audio,
        currentSubtitle: _player.state.track.subtitle,
        preferredAudioLang: audioLang,
        preferredSubtitleLang: 'None',
        avoidUnsupportedAudio: avoidUnsupported,
      );
      if (!result.hasAny) return;
      if (result.audio != null) {
        await _player.setAudioTrack(result.audio!);
      }
    } catch (e) {
      debugPrint('[Player] track auto-select failed: $e');
    }
  }

  /// Checks if [track] is an ASS/SSA or image-based subtitle (PGS/VobSub) and toggles mpv's
  /// `sub-visibility` accordingly. Native tracks render directly onto the video frame,
  /// so the custom Flutter overlay hides itself. For SRT/VTT, sub-visibility is turned off
  /// so only the Flutter overlay draws text.
  void _updateSubVisibility(SubtitleTrack track) {
    final codec = track.codec?.toLowerCase() ?? '';
    final isNativeCodec = codec.contains('ass') || codec.contains('ssa') ||
        codec.contains('pgs') || codec.contains('dvd') || codec.contains('dvb') || codec.contains('vobsub');
    // Also check the track title/id for .ass/.ssa extension (file picker)
    final title = (track.title ?? track.id).toLowerCase();
    final looksAss = title.endsWith('.ass') || title.endsWith('.ssa');
    final shouldUseNative = isNativeCodec || looksAss;

    if (shouldUseNative != _isNativeSubtitle) {
      setState(() => _isNativeSubtitle = shouldUseNative);
    }
    if (_player.platform is NativePlayer) {
      (_player.platform as NativePlayer)
          .setProperty('sub-visibility', shouldUseNative ? 'yes' : 'no');
    }
  }

  Future<void> _configureMpvProperties() async {
    if (_player.platform is! NativePlayer) return;
    final mpv = _player.platform as NativePlayer;

    Future<void> safeSet(String key, String val) async {
      try {
        await mpv.setProperty(key, val);
      } catch (e) {
        debugPrint('[Player] Warning: failed to set mpv property $key=$val: $e');
      }
    }

    // ── Decoding ─────────────────────────────────────────────────────────
    // auto-safe on mobile: uses MediaCodec (Android) / VideoToolbox (iOS),
    // whitelisted to formats each platform reliably supports.
    // TV: full software path — GLES/EGL is unreliable on leanback emulators.
    await safeSet('hwdec', _hwDecMode.mpvValue);
    final mediaKitSafeMode =
        widget.tvRemoteEnabled || _androidMediaKitSafeMode;
    await safeSet('vd-lavc-dr', mediaKitSafeMode ? 'no' : 'yes');
    if (mediaKitSafeMode && Platform.isAndroid) {
      // OpenSLES misconfigures on some ATV images (0 frames delivered).
      await safeSet('ao', 'audiotrack');
    }

    // Auto thread count (0 = let mpv decide). On mobile 4–8 cores typical.
    await safeSet('vd-lavc-threads', '0');

    // ── Audio Codec Fallback ──────────────────────────────────────────────
    // Continue playback even if audio codec is unsupported (e.g., TrueHD).
    // User can switch to alternate audio track from the menu.
    await safeSet('ad-lavc-downmix', 'no');
    await safeSet('audio-fallback-to-null', 'yes');

    // Flutter renders subtitles — kill mpv's own OSD overlay.
    await safeSet('sub-visibility', 'no');
    await safeSet('sub-auto', 'all');

    // ── Video Sync ────────────────────────────────────────────────────────
    // On mobile we use audio sync (not display-resample).
    // display-resample requires a stable vsync signal from the display driver
    // which is unreliable on Android and drains battery unnecessarily.
    // audio sync gives smooth playback tied to the audio clock instead.
    await safeSet('video-sync', 'audio');

    // ── Network / Cache ───────────────────────────────────────────────────
    await safeSet('network-timeout', '30');
    await safeSet('tls-verify', 'no');

    await safeSet('cache-pause', 'no');
    await safeSet('cache-pause-initial', 'no');

    final isTorrent = widget.magnetLink != null;
    if (isTorrent) {
      // Torrent engine feeds bytes from disk as pieces complete — a small
      // forward window is enough and keeps memory pressure low.
      await safeSet('cache', 'yes');
      await safeSet('network-timeout', '60');
      await safeSet('demuxer-readahead-secs', '20');
      await safeSet('force-seekable', 'yes');
      await safeSet('hr-seek', 'yes');
      await safeSet('hr-seek-framedrop', 'no');
    } else {
      // 150 MiB forward cache (less than desktop's 300 MiB — spare mobile RAM).
      await safeSet('cache', 'yes');
      await safeSet('cache-secs', '120');
      await safeSet('demuxer-max-bytes', '150MiB');
      await safeSet('demuxer-readahead-secs', '120');

      // 30 MiB back-buffer so backward seeks don't require a full rebuffer.
      await safeSet('demuxer-max-back-bytes', '30MiB');

      await safeSet('hls-bitrate', 'no');
    }

    // We supply our own URL — no yt-dlp needed.
    await safeSet('ytdl', 'no');

    // Allow volume boosting up to 150% for quiet sources.
    await safeSet('volume-max', '150');

    // ── External Audio ────────────────────────────────────────────────────
    if (widget.audioUrl != null) {
      await safeSet('audio-file', widget.audioUrl!);
    }

    // ── HTTP Headers ──────────────────────────────────────────────────────
    if (widget.headers != null) {
      final referer =
          widget.headers!['Referer'] ?? widget.headers!['referer'];
      if (referer != null) await safeSet('referrer', referer);

      final ua =
          widget.headers!['User-Agent'] ?? widget.headers!['user-agent'];
      if (ua != null) await safeSet('user-agent', ua);
    }

    // ── Resume Position ──────────────────────────────────────────────────
    // Set mpv's native 'start' property so it begins playback at the saved
    // position. This is far more reliable on Android than seeking after open,
    // because the post-open seek can be silently dropped before the demuxer
    // is fully initialised.
    if (widget.startPosition != null && !_hasInitialSeek) {
      final secs = widget.startPosition!.inMilliseconds / 1000.0;
      await mpv.setProperty('start', '+${secs.toStringAsFixed(3)}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HW DECODE CYCLE
  // ─────────────────────────────────────────────────────────────────────────

  void _cycleHwDec() {
    final next = _hwDecMode.next;
    setState(() => _hwDecMode = next);
    if (_player.platform is NativePlayer) {
      (_player.platform as NativePlayer)
          .setProperty('hwdec', next.mpvValue);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UI HIDE TIMER
  // ─────────────────────────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlayingNotifier.value) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_disposed && !_hasError) {
        setState(() => _showControls = false);
      }
    });
  }

  Movie? get _displayMovie => _heroMovie ?? widget.movie;

  String get _displayTitle => _displayMovie?.title ?? widget.title;

  String? get _hubEpisodeLine {
    if (widget.hubEpisodes == null) return null;
    final n = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (n == null) return null;
    return 'Episode ${n == n.truncateToDouble() ? n.toInt() : n}';
  }

  String? get _pausedEpisodeOverview =>
      widget.episodeOverview ?? _episodeOverview;

  Future<void> _loadHeroMetadata() async {
    if (widget.hubEpisodes != null) return;
    final movie = widget.movie;
    if (movie == null) return;
    final metadata = await loadPlayerHeroMetadata(
      movie: movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted || metadata == null) return;
    setState(() {
      _heroMovie = metadata.movie;
      _episodeOverview = metadata.episodeOverview;
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  bool _handleTvKeyEvent(KeyEvent event) {
    if (!widget.tvRemoteEnabled || _disposed || _hasError) return false;
    if (_isLocked) return false;
    if (_showControls && playerTvChromeHasFocus(_playerTvKeyFocus)) {
      return false;
    }

    return _playerTvHandler().handle(event, showControls: _showControls);
  }

  PlayerTvRemoteKeyHandler _playerTvHandler() => PlayerTvRemoteKeyHandler(
        onBack: () => unawaited(_exitPlayer()),
        onPlayPause: () {
          _player.playOrPause();
          _startHideTimer();
        },
        onShowControls: () {
          setState(() => _showControls = true);
          _startHideTimer();
        },
        onSeekBack: () {
          var newPos = _positionNotifier.value - const Duration(seconds: 10);
          if (newPos < Duration.zero) newPos = Duration.zero;
          _player.seek(newPos);
          _startHideTimer();
        },
        onSeekForward: () {
          final dur = _durationNotifier.value;
          var newPos = _positionNotifier.value + const Duration(seconds: 10);
          if (newPos > dur) newPos = dur;
          _player.seek(newPos);
          _startHideTimer();
        },
        onVolumeUp: () {
          _player.setVolume(
            (_volume.clamp(0, 150) + 5).clamp(0, 150).toDouble(),
          );
        },
        onVolumeDown: () {
          _player.setVolume(
            (_volume.clamp(0, 150) - 5).clamp(0, 150).toDouble(),
          );
        },
        onToggleControls: _toggleControls,
      );

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _showControls = !_isLocked;
    });
    if (!_isLocked) _startHideTimer();
  }

  void _toggleRotation() async {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
      ]);
    }
    // Wait for the rotation to settle before triggering a rebuild.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    // Force a rebuild so controls adjust to the new orientation.
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GESTURE HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  void _handleDoubleTap(TapDownDetails details, bool isRight) {
    if (_isLocked) return;
    setState(() {
      _showRipple = true;
      _isForward = isRight;
      _ripplePosition = details.localPosition;
    });
    _rippleController.forward(from: 0.0);
    
    // Calculate new position and clamp to valid range
    final currentPos = _positionNotifier.value;
    final duration = _durationNotifier.value;
    final delta = isRight ? const Duration(seconds: 10) : const Duration(seconds: -10);
    var newPos = currentPos + delta;
    
    // Clamp to valid range [0, duration]
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (newPos > duration) {
      newPos = duration;
    }
    
    _player.seek(newPos);
    _startHideTimer();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double width) {
    if (_isLocked) return;

    final isRight = details.localPosition.dx > width / 2;
    // delta is inverted: drag up = positive = increase
    final delta = -details.primaryDelta! / 3;

    if (isRight) {
      _volume = (_volume + delta).clamp(0.0, 150.0);
      _player.setVolume(_volume);
      setState(() {
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      });
    } else {
      _brightness = (_brightness + delta / 300).clamp(0.0, 1.0);
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          ScreenBrightness().setApplicationScreenBrightness(_brightness);
        } catch (_) {}
      }
      setState(() {
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      });
    }

    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ASPECT RATIO
  // ─────────────────────────────────────────────────────────────────────────

  String get _videoFitLabel => switch (_videoFit) {
        BoxFit.contain => 'FIT',
        BoxFit.cover => 'CROP',
        BoxFit.fill => 'FILL',
        _ => 'FIT',
      };

  void _cycleAspectRatio() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUBTITLES
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  //  ONLINE SUBTITLE LOADER (download → temp file → SubtitleTrack.uri)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadOnlineSubtitle(Map<String, dynamic> s) async {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) return;
    final isTranslated = s['translated'] == true ||
        url.contains('/subtitlecat-translate');

    // Already-local subtitle (e.g. kisskh decrypted) — feed straight to libmpv.
    if (url.startsWith('file://') || url.startsWith('/')) {
      try {
        _player.setSubtitleTrack(SubtitleTrack.uri(
          url.startsWith('file://') ? url : Uri.file(url).toString(),
          title: s['display'],
          language: s['language'],
        ));
        if (mounted) setState(() => _selectedExternalSubUrl = url);
      } catch (e) {
        if (!mounted) return;
        setState(() => _selectedExternalSubUrl = null);
        _statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
      return;
    }

    try {
      // Many subtitle CDNs (megacloud, vid-cdn, etc.) gate on a browser UA
      // and the embed-host Referer (NOT the sub URL's own host). Prefer the
      // referer/origin the extractor passed through; otherwise fall back to
      // the sub URL's own origin.
      final subUri = Uri.parse(url);
      final selfOrigin = '${subUri.scheme}://${subUri.host}';
      final ref = (s['referer'] as String?)?.trim();
      final org = (s['origin'] as String?)?.trim();
      final headers = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Referer': (ref != null && ref.isNotEmpty) ? ref : '$selfOrigin/',
        'Origin': (org != null && org.isNotEmpty) ? org : selfOrigin,
      };
      final res = await http
          .get(subUri, headers: headers)
          .timeout(Duration(minutes: isTranslated ? 5 : 1));
      if (!mounted) return;
      if (res.statusCode != 200) {
        if (mounted) {
          setState(() => _selectedExternalSubUrl = null);
        }
        _statusController.upsert(
          'subtitle',
          'Subtitle failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final safeLang = (s['language'] ?? 'sub')
          .toString()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File(
          '${dir.path}/forja_sub_${DateTime.now().millisecondsSinceEpoch}_$safeLang.srt');
      await file.writeAsBytes(res.bodyBytes);
      final uri = Uri.file(file.path).toString();
      final track = SubtitleTrack.uri(
        uri,
        title: s['display'],
        language: s['language'],
      );
      _player.setSubtitleTrack(track);
      _updateSubVisibility(track);
      if (mounted) {
        setState(() => _selectedExternalSubUrl = url);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedExternalSubUrl = null);
      _statusController.upsert(
        'subtitle',
        'Subtitle failed',
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _fetchSubtitles() async {
    // Pre-populate with Jellyfin subtitles if provided
    final jellyfinSubs = widget.externalSubtitles ?? [];
    if (jellyfinSubs.isNotEmpty) {
      if (mounted) setState(() => _externalSubtitles = List<Map<String, dynamic>>.from(jellyfinSubs));
    }

    if (widget.movie == null || widget.movie!.id <= 0) return;
    if (mounted) setState(() => _isFetchingSubs = true);

    final stream = SubtitleApi.fetchSubtitlesStream(
      tmdbId: widget.movie!.id,
      imdbId: widget.movie!.imdbId,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      title: widget.movie!.title,
      year: widget.movie!.releaseDate.length >= 4
          ? int.tryParse(widget.movie!.releaseDate.substring(0, 4))
          : null,
    );

    stream.listen(
      (subs) {
        if (mounted) {
          setState(() => _externalSubtitles = [...jellyfinSubs, ...subs]);
          _maybeAutoPickExternalSubtitle();
        }
      },
      onDone: () {
        if (mounted) setState(() => _isFetchingSubs = false);
        _maybeAutoPickExternalSubtitle();
      },
    );
  }

  /// Subtitle auto-pick was removed (the user explicitly disabled the
  /// preferred-subtitle setting). Kept as a no-op so existing call sites
  /// don't have to be re-plumbed.
  Future<void> _maybeAutoPickExternalSubtitle() async {}

  void _showSubtitlesMenu(BuildContext anchorContext) {
    PlayerSubtitleMenu.show(
      context,
      player: _player,
      anchorContext: anchorContext,
      externalSubtitles: _externalSubtitles,
      selectedExternalSubUrl: _selectedExternalSubUrl,
      isFetchingSubs: _isFetchingSubs,
      subtitlePinned: _subtitlePinned,
      updateSubVisibility: _updateSubVisibility,
      onExternalUrlChanged: (url) => setState(() => _selectedExternalSubUrl = url),
      onNativeSubtitleChanged: (v) => setState(() => _isNativeSubtitle = v),
      loadOnlineSubtitle: _loadOnlineSubtitle,
      onSubtitleSettings: _showSubtitleSettings,
      onSelectAuto: _selectAutoSubtitle,
      onManualSelect: () => setState(() => _subtitlePinned = true),
      excludeKnownExternalEmbedded: true,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
    );
  }

  Future<void> _selectAutoSubtitle() async {
    setState(() {
      _subtitlePinned = false;
      _selectedExternalSubUrl = null;
    });
    await _player.setSubtitleTrack(SubtitleTrack.auto());
    _updateSubVisibility(SubtitleTrack.auto());
  }

  void _showSubtitleSettings() {
    final fonts = ['Default', 'Poppins', 'Roboto', 'Roboto Mono', 'Montserrat', 'Open Sans', 'Lato'];
    final colorOptions = <String, Color>{
      'White': Colors.white,
      'Yellow': const Color(0xFFFFEB3B),
      'Cyan': const Color(0xFF00E5FF),
      'Green': const Color(0xFF69F0AE),
      'Orange': const Color(0xFFFFAB40),
      'Pink': const Color(0xFFFF80AB),
    };

    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        final screenW = MediaQuery.of(context).size.width;
        final dialogW = (screenW * 0.9).clamp(280.0, 420.0);
        return StatefulBuilder(builder: (context, setDialog) {
          return Dialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogW, maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF7C3AED), size: 20),
                    const SizedBox(width: 8),
                    const Text('Subtitle Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        SettingsService().setSubSize(_subtitleSize);
                        SettingsService().setSubBgOpacity(_subtitleBgOpacity);
                        SettingsService().setSubBottomPadding(_subtitleBottomPadding);
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.close, color: Colors.white38, size: 20),
                    ),
                  ]),
                ),
                const Divider(color: Colors.white10, height: 1),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Size
                      _subSlider('Size', _subtitleSize, 10, 50, '${_subtitleSize.toInt()}', (v) {
                        setDialog(() => _subtitleSize = v); setState(() {});
                      }),
                      const SizedBox(height: 8),

                      // Delay
                      Row(children: [
                        const Text('Delay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white70, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final v = _subtitleDelay - 0.1;
                            setDialog(() => _subtitleDelay = double.parse(v.toStringAsFixed(1)));
                            if (_player.platform is NativePlayer) {
                              (_player.platform as NativePlayer).setProperty('sub-delay', _subtitleDelay.toString());
                            }
                          },
                        ),
                        SizedBox(
                          width: 54,
                          child: Text('${_subtitleDelay.toStringAsFixed(1)}s',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final v = _subtitleDelay + 0.1;
                            setDialog(() => _subtitleDelay = double.parse(v.toStringAsFixed(1)));
                            if (_player.platform is NativePlayer) {
                              (_player.platform as NativePlayer).setProperty('sub-delay', _subtitleDelay.toString());
                            }
                          },
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Text Color
                      const Text('Text Color', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 10, runSpacing: 10, children: colorOptions.entries.map((e) {
                        final selected = _subtitleColor.toARGB32() == e.value.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialog(() => _subtitleColor = e.value);
                            setState(() {});
                            SettingsService().setSubColor(e.value.toARGB32());
                          },
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? const Color(0xFF7C3AED) : Colors.white24,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected ? const Icon(Icons.check, size: 16, color: Color(0xFF7C3AED)) : null,
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 16),

                      // BG Opacity
                      _subSlider('BG Opacity', _subtitleBgOpacity, 0.0, 1.0, '${(_subtitleBgOpacity * 100).toInt()}%', (v) {
                        setDialog(() => _subtitleBgOpacity = v); setState(() {});
                      }),
                      const SizedBox(height: 8),

                      // Position
                      _subSlider('Position', _subtitleBottomPadding, 0, 120, '${_subtitleBottomPadding.toInt()}', (v) {
                        setDialog(() => _subtitleBottomPadding = v); setState(() {});
                      }),
                      const SizedBox(height: 8),

                      // Bold
                      Row(children: [
                        const Text('Bold', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        Switch(
                          value: _subtitleBold,
                          activeThumbColor: const Color(0xFF7C3AED),
                          onChanged: (v) { setDialog(() => _subtitleBold = v); setState(() {}); SettingsService().setSubBold(v); },
                        ),
                      ]),
                      const SizedBox(height: 8),

                      // Font
                      const Text('Font', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: fonts.map((f) {
                        final selected = _subtitleFont == f;
                        return GestureDetector(
                          onTap: () { setDialog(() => _subtitleFont = f); setState(() {}); SettingsService().setSubFont(f); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF7C3AED).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: selected ? const Color(0xFF7C3AED) : Colors.white12),
                            ),
                            child: Text(f, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                          ),
                        );
                      }).toList()),
                    ]),
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  Widget _subSlider(String label, double value, double min, double max, String trailing, ValueChanged<double> onChanged) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(trailing, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: const Color(0xFF7C3AED),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          thumbColor: const Color(0xFF7C3AED),
        ),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
    ]);
  }

  Future<void> _loadSubtitlePrefs() async {
    final s = SettingsService();
    final size = await s.getSubSize();
    final color = await s.getSubColor();
    final bgOp = await s.getSubBgOpacity();
    final bold = await s.getSubBold();
    final padding = await s.getSubBottomPadding();
    final font = await s.getSubFont();
    if (mounted) {
      setState(() {
        _subtitleSize = size;
        _subtitleColor = Color(color);
        _subtitleBgOpacity = bgOp;
        _subtitleBold = bold;
        _subtitleBottomPadding = padding;
        _subtitleFont = font;
      });
    }
  }

  TextStyle _buildSubtitleTextStyle({double scale = 1.0}) {
    final base = TextStyle(
      height: 1.4,
      fontSize: _subtitleSize * scale,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
      color: _subtitleColor,
      fontWeight: _subtitleBold ? FontWeight.bold : FontWeight.normal,
      backgroundColor: Colors.black.withValues(alpha: _subtitleBgOpacity),
      shadows: [
        Shadow(blurRadius: 10 * scale, color: Colors.black, offset: Offset.zero),
      ],
    );
    if (_subtitleFont == 'Default') return base;
    final fontMap = <String, TextStyle Function({TextStyle? textStyle})>{
      'Poppins': GoogleFonts.poppins,
      'Roboto': GoogleFonts.roboto,
      'Roboto Mono': GoogleFonts.robotoMono,
      'Montserrat': GoogleFonts.montserrat,
      'Open Sans': GoogleFonts.openSans,
      'Lato': GoogleFonts.lato,
    };
    final fn = fontMap[_subtitleFont];
    if (fn != null) return fn(textStyle: base);
    return base;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AUDIO MENU
  // ─────────────────────────────────────────────────────────────────────────

  void _showAudioMenu(BuildContext anchorContext) {
    PlayerAudioMenu.show(
      context,
      player: _player,
      audioPinned: _audioPinned,
      onSelectAuto: _selectAutoAudio,
      onManualSelect: () => setState(() => _audioPinned = true),
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
    );
  }

  Future<void> _selectAutoAudio() async {
    setState(() => _audioPinned = false);
    await _player.setAudioTrack(AudioTrack.auto());
    await _applyTrackAutoSelect();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HLS QUALITY SELECTOR
  // ─────────────────────────────────────────────────────────────────────────

  /// Probe [url] as a master HLS playlist. Populates the quality notifier
  /// when 2+ variants are present, otherwise clears it (hiding the gear).
  void _detectHlsQualities(String url, Map<String, String>? headers) {
    _currentQualityUrl = url;
    if (!url.contains('.m3u8')) {
      _hlsMasterUrl = null;
      _hlsMasterHeaders = null;
      _hlsQualitiesNotifier.value = null;
      return;
    }
    // If the user just picked a variant from the same master, keep the list.
    final existing = _hlsQualitiesNotifier.value;
    if (existing != null && existing.any((q) => q.url == url)) return;

    // New stream — clear any prior quality state immediately so the gear
    // doesn't expose stale variants while the new master loads.
    _hlsMasterUrl = url;
    _hlsMasterHeaders = headers;
    _hlsQualitiesNotifier.value = null;
    fetchHlsQualities(url, headers: headers).then((qs) {
      if (_disposed) return;
      // Only apply if a newer URL didn't take over while we were fetching.
      if (_hlsMasterUrl != url) return;
      _hlsQualitiesNotifier.value = qs;
    });
  }

  void _showQualityMenu(BuildContext anchorContext) {
    final qs = _hlsQualitiesNotifier.value ?? const <HlsQuality>[];
    PlayerQualityMenu.show(
      context,
      qualities: qs,
      currentQualityUrl: _currentQualityUrl,
      masterUrl: _hlsMasterUrl,
      playerState: _player.state,
      playbackQualityLabel: playbackQualityLabel(_player.state),
      playbackQualityDetail: playbackQualityDetail(_player.state),
      onSelect: _switchQuality,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(
        left: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 76,
      ),
    );
  }

  Future<void> _switchQuality(HlsQuality q) async {
    final pos = _positionNotifier.value;
    _currentQualityUrl = q.url;
    if (mounted) setState(() {});
    if (_hlsMasterHeaders != null && _player.platform is NativePlayer) {
      final ref = _hlsMasterHeaders!['Referer'] ??
          _hlsMasterHeaders!['referer'];
      if (ref != null) {
        await (_player.platform as NativePlayer)
            .setProperty('referrer', ref);
      }
    }
    await _player.open(
      Media(q.url, httpHeaders: _hlsMasterHeaders),
    );
    if (pos.inSeconds > 0) await _player.seek(pos);
    _startHideTimer();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SOURCE SELECTION (for Amri provider)
  // ─────────────────────────────────────────────────────────────────────────

  void _notifySourceMenuChanged() {
    _sourceMenuRevision.value++;
  }

  void _markSourceChecking(int index) {
    _checkingSourceIndices
      ..clear()
      ..add(index);
    _notifySourceMenuChanged();
  }

  void _markSourceFailed(int index) {
    _failedSourceIndices.add(index);
    _checkingSourceIndices.remove(index);
    _notifySourceMenuChanged();
  }

  void _markSourceActive(int index) {
    _failedSourceIndices.remove(index);
    _checkingSourceIndices.remove(index);
    _notifySourceMenuChanged();
  }

  bool _isCurrentSourceIndex(int index) {
    final sources = _currentSources;
    if (sources == null || index < 0 || index >= sources.length) return false;
    final source = sources[index];
    return _currentProvider == 'service111477'
        ? source.url == _current111477FileUrl
        : source.url == _currentUrl;
  }

  Future<void> _reloadStreamMenu() async {
    if (_isReloadingStreams.value) return;
    _isReloadingStreams.value = true;
    try {
      if (widget.onReloadStreams != null) {
        final fresh = await widget.onReloadStreams!();
        if (!mounted) return;
        if (fresh != null && fresh.isNotEmpty) {
          setState(() {
            _currentSources = fresh;
            _failedSourceIndices.clear();
            _checkingSourceIndices.clear();
          });
          _notifySourceMenuChanged();
        }
      }
      await _probeAllSourcesInBackground();
    } finally {
      if (mounted) _isReloadingStreams.value = false;
    }
  }

  void _onLiveSourcesUpdated() {
    unawaited(_rankLiveSources());
  }

  Future<void> _rankLiveSources() async {
    if (_disposed || !mounted) return;
    final live = widget.sourcesListNotifier?.value;
    if (live == null || live.isEmpty) return;
    final merged = await dedupeStreamSourcesAsync(
      live,
      providerId: _currentProvider ?? '',
    );
    if (_disposed || !mounted) return;
    final prevLen = _currentSources?.length ?? 0;
    if (merged.length <= prevLen &&
        (_currentSources == null ||
            (merged.length == prevLen &&
                merged.every((s) =>
                    _currentSources!.any((c) => c.url == s.url))))) {
      return;
    }
    setState(() => _currentSources = merged);
    _notifySourceMenuChanged();
    unawaited(_probeAllSourcesInBackground());
  }

  Future<void> _probeAllSourcesInBackground() async {
    final sources = _currentSources;
    if (sources == null || sources.isEmpty) return;

    final toCheck = <int>[];
    for (var i = 0; i < sources.length; i++) {
      if (_isCurrentSourceIndex(i) && _playbackConfirmed) continue;
      toCheck.add(i);
    }
    if (toCheck.isEmpty) return;

    _failedSourceIndices.removeAll(toCheck);
    _checkingSourceIndices.addAll(toCheck);
    _notifySourceMenuChanged();

    for (final i in toCheck) {
      if (!mounted) return;
      final source = sources[i];
      final ok = await probeStreamSourceUrl(source.url, source.headers);
      if (!mounted) return;
      _checkingSourceIndices.remove(i);
      if (!ok) _failedSourceIndices.add(i);
      _notifySourceMenuChanged();
    }
  }

  List<PlayerSourceStatus> _buildSourceStatuses() {
    final sources = _currentSources ?? const [];
    return List.generate(sources.length, (i) {
      if (_checkingSourceIndices.contains(i)) {
        return PlayerSourceStatus.checking;
      }
      final source = sources[i];
      final isCurrent = _currentProvider == 'service111477'
          ? source.url == _current111477FileUrl
          : source.url == _currentUrl;
      if (isCurrent && _playbackConfirmed) return PlayerSourceStatus.active;
      if (_failedSourceIndices.contains(i)) return PlayerSourceStatus.failed;
      return PlayerSourceStatus.ready;
    });
  }

  PlayerStreamMenuState _streamMenuState() {
    String? activeSourceTitle;
    final sources = _currentSources;
    if (sources != null && sources.isNotEmpty) {
      for (final source in sources) {
        final isCurrent = _currentProvider == 'service111477'
            ? source.url == _current111477FileUrl
            : source.url == _currentUrl;
        if (isCurrent) {
          activeSourceTitle = source.title;
          break;
        }
      }
    }

    String? activeProviderLabel;
    final providerId = _currentProvider;
    final providers = widget.providers;
    if (providerId != null && providers != null && providers.containsKey(providerId)) {
      activeProviderLabel = PlayerProviderMenu.snackbarLabel(
        providerId,
        providers[providerId],
      );
    }

    return PlayerStreamMenuState(
      currentProviderId: _currentProvider,
      sources: _currentSources,
      currentUrl: _currentUrl,
      current111477FileUrl: _current111477FileUrl,
      is111477: _currentProvider == 'service111477',
      providerAuto: !_providerPinned,
      sourceAuto: !_sourcePinned,
      activeProviderLabel: activeProviderLabel,
      activeSourceTitle: activeSourceTitle,
      sourceStatuses: _buildSourceStatuses(),
    );
  }

  Listenable? _streamMenuRefreshListenable() {
    final listenables = <Listenable>[
      _statusController,
      _sourceMenuRevision,
      _isReloadingStreams,
    ];
    final probes = widget.providerProbesNotifier;
    if (probes != null) listenables.add(probes);
    return Listenable.merge(listenables);
  }

  void _showSourcesMenu([BuildContext? anchorContext]) {
    if (_currentSources == null || _currentSources!.isEmpty) return;
    final bottom = MediaQuery.paddingOf(context).bottom + 76;
    PlayerStreamMenu.show(
      context,
      readState: _streamMenuState,
      onSelectProvider: _switchProvider,
      onSelectAutoProvider: _selectAutoProvider,
      onSelectAutoSource: _selectAutoSource,
      onSelectSource: _switchToStreamSource,
      sourcesOnly: true,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(right: 12, bottom: bottom),
      refreshListenable: _streamMenuRefreshListenable(),
      onReload: _reloadStreamMenu,
      isReloading: _isReloadingStreams,
    );
    _startHideTimer();
  }

  void _showProviderMenu([BuildContext? anchorContext]) {
    if (widget.providers == null ||
        widget.providers!.isEmpty ||
        widget.movie == null ||
        widget.magnetLink != null ||
        widget.activeProvider == 'stremio_direct') {
      return;
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 76;
    PlayerStreamMenu.show(
      context,
      providers: widget.providers,
      providerProbesNotifier: widget.providerProbesNotifier,
      readState: _streamMenuState,
      onSelectProvider: _switchProvider,
      onSelectAutoProvider: _selectAutoProvider,
      onSelectAutoSource: _selectAutoSource,
      onSelectSource: _switchToStreamSource,
      providersEnabled: !_isSwitchingProvider,
      anchorContext: anchorContext,
      margin: EdgeInsets.only(right: 12, bottom: bottom),
      refreshListenable: _streamMenuRefreshListenable(),
      onReload: _reloadStreamMenu,
      isReloading: _isReloadingStreams,
    );
    _startHideTimer();
  }

  Future<void> _selectAutoProvider() async {
    if (!_providerPinned) return;
    setState(() {
      _providerPinned = false;
      _sourcePinned = false;
      _currentFallbackSourceIndex = 0;
    });
    final movie = widget.movie;
    final providers = widget.providers;
    if (movie != null && providers != null && providers.isNotEmpty) {
      final gen = ++_fallbackGen;
      WebStreamrService().cancelPending();
      VidsrcExtractor.cancelPending();
      NuvioService.instance.cancelPending();
      final hit = await PlayerSourceResolve.resolveAuto(
        movie: movie,
        providers: providers,
        season: widget.selectedSeason ?? 1,
        episode: widget.selectedEpisode ?? 1,
        isCancelled: () => _fallbackAborted(gen),
        onHitsUpdated: (hits) {
          if (!mounted || _fallbackAborted(gen)) return;
          widget.providerSourcesCache?.value =
              PlaybackEngine.hitsToProviderCache(hits);
        },
      );
      if (_fallbackAborted(gen)) return;
      if (hit != null) {
        setState(() {
          _currentProvider = hit.providerId;
          _currentSources = hit.streamSources;
          _currentUrl = hit.streamUrl;
          _currentFallbackSourceIndex = 0;
          _hasError = false;
          _errorMessage = '';
          if (hit.providerId == 'service111477' &&
              hit.streamSources.isNotEmpty) {
            _current111477FileUrl = hit.streamSources.first.url;
          }
        });
        final played = await _trySourcesFromIndex(
          0,
          chainGen: gen,
          seekAfterOpen: _positionNotifier.value,
        );
        if (played) return;
      }
    }
    await _initPlayback();
  }

  Future<void> _selectAutoSource() async {
    if (!_sourcePinned) return;
    setState(() {
      _sourcePinned = false;
      _currentFallbackSourceIndex = 0;
      _failedSourceIndices.clear();
      _checkingSourceIndices.clear();
    });
    _notifySourceMenuChanged();
    await _initPlayback();
  }

  Future<void> _switchToStreamSource(StreamSource source, int index) async {
    final isCurrent = _currentProvider == 'service111477'
        ? source.url == _current111477FileUrl
        : source.url == _currentUrl;
    if (isCurrent && _sourcePinned) return;

    if (isCurrent && !_sourcePinned) {
      setState(() => _sourcePinned = true);
      unawaited(widget.onSourcePinned?.call(source.url, source.title));
      _startHideTimer();
      return;
    }

    _sourcePinned = true;
    _markSourceChecking(index);

    final currentPos = _positionNotifier.value;
    final statusId = 'source-switch-$index';
    _statusController.upsert(
      statusId,
      source.title,
      kind: StatusRouletteKind.loading,
    );

    if (_currentProvider == 'service111477') {
      try {
        if (site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        final newProxied = await site111477_proxy.start111477Proxy(source.url);
        if (!mounted) return;
        await _player.open(Media(newProxied));
        setState(() {
          _currentUrl = newProxied;
          _current111477FileUrl = source.url;
          _currentFallbackSourceIndex = 0;
          _hasError = false;
          _errorMessage = '';
        });
        _detectHlsQualities(newProxied, null);
        if (currentPos.inSeconds > 0) await _player.seek(currentPos);
        _playbackConfirmed = true;
        _statusController.complete();
        _markSourceActive(index);
      } catch (e) {
        if (!mounted) return;
        _statusController.upsert(
          statusId,
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        _markSourceFailed(index);
      }
      return;
    }

    if (_currentProvider == 'arabic' && source.type == 'arabic_embed') {
      final result = await ArabicService.extractStreamUrl(source.url);
      if (!mounted) return;
      if (result == null) {
        _statusController.upsert(
          statusId,
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        _markSourceFailed(index);
        return;
      }
      await _player.open(Media(result.url, httpHeaders: result.headers));
      _currentSources![index] = StreamSource(
        url: result.url,
        title: source.title,
        type: result.url.contains('.m3u8')
            ? 'hls'
            : result.url.contains('.mpd')
                ? 'dash'
                : 'mp4',
      );
      setState(() {
        _currentUrl = result.url;
        _currentFallbackSourceIndex = 0;
        _hasError = false;
        _errorMessage = '';
      });
      _detectHlsQualities(result.url, result.headers);
    } else {
      final srcHeaders = source.headers ?? widget.headers;
      if (source.headers != null && _player.platform is NativePlayer) {
        final ref = source.headers!['Referer'] ?? source.headers!['referer'];
        if (ref != null) {
          await (_player.platform as NativePlayer).setProperty('referrer', ref);
        }
      }
      await _player.open(Media(source.url, httpHeaders: srcHeaders));
      setState(() {
        _currentUrl = source.url;
        _currentFallbackSourceIndex = 0;
        _hasError = false;
        _errorMessage = '';
      });
      _detectHlsQualities(source.url, srcHeaders);
    }

    if (currentPos.inSeconds > 0) await _player.seek(currentPos);
    syncPlayerProgressNotifiers(
      _player,
      duration: _durationNotifier,
      position: _positionNotifier,
      buffered: _bufferedNotifier,
    );
    _playbackConfirmed = true;
    _statusController.complete();
    _markSourceActive(index);
    unawaited(widget.onSourcePinned?.call(source.url, source.title));
  }

  Future<({int season, int episode})?> _computeNextEpisode() async {
    if (widget.movie == null ||
        widget.selectedSeason == null ||
        widget.selectedEpisode == null) {
      return null;
    }
    final tmdb = TmdbService();
    final tvId = widget.movie!.id;
    var nextSeason = widget.selectedSeason!;
    var nextEpisode = widget.selectedEpisode! + 1;

    final seasonData = await tmdb.getTvSeasonDetails(tvId, nextSeason);
    final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
    final maxEp = episodes.isNotEmpty
        ? episodes.map((e) => e['episode_number'] as int).reduce((a, b) => a > b ? a : b)
        : 0;

    if (nextEpisode > maxEp) {
      final totalSeasons = await tmdb.getTvSeasonCount(tvId);
      if (nextSeason < totalSeasons) {
        nextSeason++;
        nextEpisode = 1;
      } else {
        if (mounted) {
          _statusController.upsert(
            'episode',
            'No more episodes',
            kind: StatusRouletteKind.info,
            dismissAfter: const Duration(seconds: 2),
          );
        }
        return null;
      }
    }
    return (season: nextSeason, episode: nextEpisode);
  }

  String _episodeSwitchStatusLabel(int season, int episode, {String? providerKey}) {
    final key = providerKey ?? _currentProvider ?? widget.activeProvider;
    if (key != null) {
      return PlayerProviderMenu.snackbarLabel(key, widget.providers?[key]);
    }
    if (widget.magnetLink != null) return 'Torrents';
    return 'S$season E$episode';
  }

  void _showEpisodeSwitchStatus(int season, int episode, {String? providerKey}) {
    _statusController.upsert(
      'episode-switch',
      _episodeSwitchStatusLabel(season, episode, providerKey: providerKey),
      kind: StatusRouletteKind.loading,
    );
  }

  Future<void> _switchToEpisode(int season, int episode) async {
    if (widget.movie == null) return;
    if (!_isLoadingNextEp && mounted) setState(() => _isLoadingNextEp = true);
    _showEpisodeSwitchStatus(season, episode);

    try {
      debugPrint('[EpSwitch] Playing S${season}E$episode');
      _saveWatchHistory();

      final chain = episodeProviderChain(
        providers: widget.providers,
        activeProvider: widget.activeProvider,
        currentProvider: _currentProvider,
        magnetLink: widget.magnetLink,
      );
      if (chain.isEmpty) {
        throw Exception('No provider available for S${season}E$episode');
      }

      final resolver = StreamProviderResolver();
      EpisodeSwitchResult? resolved;
      Object? lastError;

      for (final providerKey in chain) {
        _showEpisodeSwitchStatus(season, episode, providerKey: providerKey);
        debugPrint('[EpSwitch] Trying provider: $providerKey');
        try {
          resolved = await resolveEpisodeForProvider(
            providerKey: providerKey,
            movie: widget.movie!,
            season: season,
            episode: episode,
            providers: widget.providers,
            magnetLink: widget.magnetLink,
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
            providerResolver: resolver,
          );
          if (resolved != null && resolved.streamUrl.isNotEmpty) break;
        } catch (e) {
          lastError = e;
          debugPrint('[EpSwitch] $providerKey failed: $e');
        }
      }

      if (resolved == null || resolved.streamUrl.isEmpty) {
        if (lastError != null) throw lastError;
        throw Exception('Could not find stream for S${season}E$episode');
      }

      if (!mounted) return;

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved!.streamUrl,
            title: nextTitle,
            headers: resolved.headers,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: resolved.magnetLink,
            fileIndex: resolved.fileIndex,
            activeProvider: resolved.activeProvider,
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
            providers: widget.providers,
            sources: resolved.sources,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[EpSwitch] Error: $e');
      if (mounted) {
        _statusController.upsert(
          'episode-switch',
          _episodeSwitchStatusLabel(season, episode),
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
        setState(() => _isLoadingNextEp = false);
      }
    }
  }

  Future<void> _goToEpisode(int season, int episode) async {
    if (season == widget.selectedSeason && episode == widget.selectedEpisode) return;
    await _switchToEpisode(season, episode);
  }

  Future<Uint8List?> _capturePanelFrostFrame() async {
    try {
      final jpeg = await _player.screenshot(format: 'image/jpeg');
      if (jpeg != null && jpeg.isNotEmpty) return jpeg;
    } catch (_) {}
    try {
      final png = await _player.screenshot(format: 'image/png');
      if (png != null && png.isNotEmpty) return png;
    } catch (_) {}
    return null;
  }

  Future<void> _showEpisodesMenu(BuildContext anchorContext) async {
    if (widget.hubEpisodes != null &&
        widget.hubEpisodes!.isNotEmpty &&
        widget.onHubEpisodeSelected != null) {
      if (!mounted) return;
      PlayerPopupPanel.dismiss();
      PlayerHubEpisodePanel.show(
        context: context,
        episodes: widget.hubEpisodes!,
        currentEpisode:
            widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: widget.onHubEpisodeSelected!,
      );
      return;
    }
    final frame = await _capturePanelFrostFrame();
    if (!mounted) return;
    final movie = widget.movie;
    if (movie == null || movie.mediaType != 'tv') return;
    final season = widget.selectedSeason ?? 1;
    final episode = widget.selectedEpisode ?? 1;
    PlayerEpisodeMenu.show(
      context,
      movie: movie,
      currentSeason: season,
      currentEpisode: episode,
      onEpisodeSelected: _goToEpisode,
      anchorContext: anchorContext,
      frozenFrame: frame,
    );
  }

  Future<void> _showTorrentSourcesPanel() async {
    final movie = widget.movie;
    if (movie == null) return;
    _hideTimer?.cancel();
    PlayerSourcesPanel.show(
      context: context,
      movie: movie,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      currentMagnet: _activeMagnet ?? widget.magnetLink,
      onTorrentSelected: _switchTorrentSource,
      onStremioSelected: _switchStremioSource,
    );
  }

  Future<void> _switchStremioSource(Map<String, dynamic> stream) async {
    final title =
        (stream['title'] ?? stream['name'] ?? 'Stremio stream').toString();
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-stremio-${stream.hashCode}';
    _playbackConfirmed = false;
    _statusController.upsert(
      statusId,
      title,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _player.stop();

    final resolved = await resolveStremioStream(
      stream: stream,
      profile: PlatformPlayback.capabilities,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;

    if (resolved is! StremioPlayable) {
      final msg = resolved is StremioResolveFailure
          ? resolved.message
          : 'Failed to resolve stream';
      _statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception(msg);
    }

    await _configureMpvProperties();
    await resetPlayerForOpen(_player);
    await _player.open(
      Media(resolved.streamUrl, httpHeaders: resolved.headers),
    );
    _player.setVolume(_volume);

    final opened = await waitForMediaOpen(
      _player,
      streamUrl: resolved.streamUrl,
      timeout: isLocalTorrentStreamUrl(resolved.streamUrl)
          ? const Duration(seconds: 45)
          : const Duration(seconds: 12),
    );
    if (!mounted) return;
    if (!opened) {
      _statusController.upsert(
        statusId,
        title,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Stream failed to open');
    }

    setState(() {
      _currentUrl = resolved.streamUrl;
      _activeMagnet = resolved.magnetLink;
      _hasError = false;
      _errorMessage = '';
      _currentSources = null;
    });
    _playbackConfirmed = true;
    _statusController.complete();
    widget.onPlaybackStarted?.call();
    _startHideTimer();
  }

  Future<void> _switchTorrentSource(TorrentResult result) async {
    // `source-` prefix → CHECKING SOURCES roulette (not a top toast).
    final statusId = 'source-torrent-${result.magnet.hashCode}';
    _playbackConfirmed = false;
    _statusController.upsert(
      statusId,
      result.name,
      kind: StatusRouletteKind.loading,
    );
    // Let the overlay paint before heavy resolve work.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _player.stop();

    final settings = SettingsService();
    final useDebrid = await settings.useDebridForStreams();
    final debridService = await settings.getDebridService();
    final localEngine = PlatformPlayback.capabilities.localTorrentEngine;

    final playback = await resolveMagnetForPlayback(
      magnet: result.magnet,
      useDebrid: useDebrid,
      debridService: debridService,
      localTorrentEngine: localEngine,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    if (!mounted) return;
    if (playback == null) {
      _statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Failed to resolve torrent');
    }

    await _configureMpvProperties();
    await resetPlayerForOpen(_player);
    await _player.open(Media(playback.url));
    _player.setVolume(_volume);

    final opened = await waitForMediaOpen(
      _player,
      streamUrl: playback.url,
      timeout: const Duration(seconds: 45),
    );
    if (!mounted) return;
    if (!opened) {
      _statusController.upsert(
        statusId,
        result.name,
        kind: StatusRouletteKind.failed,
        dismissAfter: const Duration(seconds: 2),
      );
      throw Exception('Torrent failed to open');
    }

    setState(() {
      _currentUrl = playback.url;
      _activeMagnet = result.magnet;
      _hasError = false;
      _errorMessage = '';
      _currentSources = null;
    });
    _playbackConfirmed = true;
    _statusController.complete();
    widget.onPlaybackStarted?.call();
    _startHideTimer();
  }

  Future<void> _persistProgressForSwitch() async {
    if (widget.onSaveProgress == null) return;
    final pos = _positionNotifier.value;
    final dur = _durationNotifier.value;
    if (pos.inMilliseconds <= 0 || dur.inMilliseconds <= 0) return;
    await widget.onSaveProgress!(pos, dur);
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _persistProgressForSwitch();
    if (!mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) => handler(
        _positionNotifier.value,
        builtInEngine: builtInEngine,
        externalPlayer: externalPlayer,
      ),
    );
    _startHideTimer();
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    PlayerPopupPanel.show(
      context: context,
      title: 'Settings',
      anchorContext: anchorContext,
      child: StatefulBuilder(
        builder: (context, setPanelState) {
          return ListView(
            padding: const EdgeInsets.all(8),
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video decode',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _GlassPillButton(
                          text: _hwDecMode.label,
                          accent: _hwDecMode.accent,
                          onTap: () {
                            _cycleHwDec();
                            setPanelState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hwDecMode.description,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
              const SizedBox(height: 4),
              PlayerPopupListTile(
                label: 'Playback speed',
                subtitle: '${_player.state.rate}x',
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  showSpeedMenu(context, _player.state.rate, (s) => _player.setRate(s));
                },
              ),
              PlayerPopupListTile(
                label: 'Aspect ratio',
                subtitle: _videoFitLabel,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _cycleAspectRatio();
                },
              ),
              PlayerPopupListTile(
                label: 'Loop',
                subtitle: _loopEnabled ? 'On' : 'Off',
                selected: _loopEnabled,
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _toggleLoop();
                },
              ),
              PlayerPopupListTile(
                label: 'Subtitle style',
                onTap: () {
                  PlayerPopupPanel.dismiss();
                  _showSubtitleSettings();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<StreamSource>?> _switchProvider(String newProvider) async {
    if (_isSwitchingProvider) return null;

    _providerPinned = true;
    _sourcePinned = false;

    final gen = ++_fallbackGen;
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    NuvioService.instance.cancelPending();

    setState(() => _isSwitchingProvider = true);
    
    final currentPos = _positionNotifier.value;
    final provider = widget.providers![newProvider];
    final providerLabel = PlayerProviderMenu.snackbarLabel(newProvider, provider);
    _statusController.upsert(
      'provider-$newProvider',
      providerLabel,
      kind: StatusRouletteKind.loading,
    );
    
    try {
      String? streamUrl;
      Map<String, String>? headers;
      List<StreamSource>? sources;

      final cached = widget.providerSourcesCache?.value[newProvider];
      if (cached != null && cached.isNotEmpty) {
        streamUrl = cached.first.url;
        headers = cached.first.headers;
        sources = cached;
      } else if (widget.movie != null && widget.providers != null) {
        if (newProvider == 'service111477' &&
            site111477_proxy.is111477ProxyRunning) {
          await site111477_proxy.stop111477Proxy();
        }
        final hit = await PlayerSourceResolve.resolvePinned(
          movie: widget.movie!,
          providers: widget.providers!,
          providerId: newProvider,
          season: widget.selectedSeason ?? 1,
          episode: widget.selectedEpisode ?? 1,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return null;
        if (hit != null) {
          streamUrl = hit.streamUrl;
          headers = hit.headers;
          sources = hit.streamSources;
        }
      }
      
      if (_fallbackAborted(gen)) return null;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        // Reset any stale mpv referrer set by the previous provider/quality
        // selection — then re-apply from the new headers if present.
        if (_player.platform is NativePlayer) {
          final ref = headers?['Referer'] ?? headers?['referer'] ?? '';
          await (_player.platform as NativePlayer).setProperty('referrer', ref);
        }
        await _player.open(
          Media(streamUrl, httpHeaders: headers),
        );
        if (_fallbackAborted(gen)) return null;
        
        if (currentPos.inSeconds > 0) {
          await _player.seek(currentPos);
        }
        _detectHlsQualities(streamUrl, headers);
        
        setState(() {
          _currentProvider = newProvider;
          _currentSources = sources == null ? null : dedupeStreamSources(sources);
          _currentUrl = streamUrl;
          _currentFallbackSourceIndex = 0; // Reset index on manual switch
          _hasError = false;
          _errorMessage = '';
          if (newProvider == 'service111477' &&
              _currentSources != null &&
              _currentSources!.isNotEmpty) {
            _current111477FileUrl = _currentSources!.first.url;
          }
        });
        
        _statusController.complete();
        return _currentSources;
      } else {
        if (mounted && !_fallbackAborted(gen)) {
          _statusController.upsert(
            'provider-$newProvider',
            providerLabel,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted && !_fallbackAborted(gen)) {
        _statusController.upsert(
          'provider-$newProvider',
          providerLabel,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitchingProvider = false);
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MISC
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleLoop() {
    setState(() => _loopEnabled = !_loopEnabled);
    _player.setPlaylistMode(
        _loopEnabled ? PlaylistMode.single : PlaylistMode.none);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SKIP SEGMENTS (IntroDB)
  // ─────────────────────────────────────────────────────────────────────────

  void _updateActiveSkipSegment(Duration pos) {
    if (_introDbData == null) return;

    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    for (final seg in _introDbData!.recap) {
      final s = seg.startMs ?? 0;
      final e = seg.endMs;
      if (e != null && posMs >= s && posMs < e) {
        label = 'Skip Recap';
        target = Duration(milliseconds: e);
        break;
      }
    }
    if (label == null) {
      for (final seg in _introDbData!.intro) {
        final s = seg.startMs ?? 0;
        final e = seg.endMs;
        if (e != null && posMs >= s && posMs < e) {
          label = 'Skip Intro';
          target = Duration(milliseconds: e);
          break;
        }
      }
    }
    if (label == null) {
      for (final seg in _introDbData!.credits) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _durationNotifier.value.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Credits';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }
    if (label == null) {
      for (final seg in _introDbData!.preview) {
        final s = seg.startMs;
        final e = seg.endMs;
        if (s != null && posMs >= s) {
          final end = e ?? _durationNotifier.value.inMilliseconds;
          if (posMs < end) {
            label = 'Skip Preview';
            target = Duration(milliseconds: end);
            break;
          }
        }
      }
    }

    if (label != _activeSkipLabel) {
      setState(() {
        _activeSkipLabel = label;
        _activeSkipTarget = target;
        _skipDismissed = false;
      });
    }
  }

  void _performSkip() {
    if (_activeSkipTarget == null) return;
    _player.seek(_activeSkipTarget!);
    setState(() {
      _activeSkipLabel = null;
      _activeSkipTarget = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NEXT EPISODE
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isNextEpisodeAvailable =>
      (widget.onNextEpisode != null && widget.hasNextEpisode) ||
      (widget.movie != null &&
          widget.movie!.mediaType == 'tv' &&
          widget.selectedSeason != null &&
          widget.selectedEpisode != null);

  bool get _showNextEpButton =>
      _isNextEpisodeAvailable && (_nearEndOfEpisode || _isLoadingNextEp);

  Future<void> _nextEpisode() async {
    if (!_isNextEpisodeAvailable || _isLoadingNextEp) return;

    setState(() => _isLoadingNextEp = true);

    // Anime / external resolver path — the caller knows how to fetch the
    // next episode and will navigate themselves. Save history first so the
    // current position isn't lost.
    if (widget.onNextEpisode != null) {
      try {
        _saveWatchHistory();
        await widget.onNextEpisode!();
      } catch (e) {
        if (mounted) {
          _statusController.upsert(
            'episode',
            'Next episode failed',
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
          setState(() => _isLoadingNextEp = false);
        }
      }
      return;
    }

    final next = await _computeNextEpisode();
    if (next == null) {
      if (mounted) setState(() => _isLoadingNextEp = false);
      return;
    }
    await _switchToEpisode(next.season, next.episode);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _exitPlayer();
      },
      child: PlayerTvKeyScope(
        enabled: widget.tvRemoteEnabled,
        focusNode: _playerTvKeyFocus,
        showControls: _showControls,
        onBack: () => unawaited(_exitPlayer()),
        onPlayPause: () {
          _player.playOrPause();
          _startHideTimer();
        },
        onShowControls: () {
          setState(() => _showControls = true);
          _startHideTimer();
        },
        onSeekBack: () {
          var newPos = _positionNotifier.value - const Duration(seconds: 10);
          if (newPos < Duration.zero) newPos = Duration.zero;
          _player.seek(newPos);
          _startHideTimer();
        },
        onSeekForward: () {
          final dur = _durationNotifier.value;
          var newPos = _positionNotifier.value + const Duration(seconds: 10);
          if (newPos > dur) newPos = dur;
          _player.seek(newPos);
          _startHideTimer();
        },
        onVolumeUp: () {
          _player.setVolume(
            (_volume.clamp(0, 150) + 5).clamp(0, 150).toDouble(),
          );
        },
        onVolumeDown: () {
          _player.setVolume(
            (_volume.clamp(0, 150) - 5).clamp(0, 150).toDouble(),
          );
        },
        onToggleControls: _toggleControls,
        child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Video ─────────────────────────────────────────────────
              Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: _videoFit,
                fill: Colors.black,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  visible: false,
                ),
              ),

              // ── 1b. Custom subtitle overlay ─────────────────────────────
              // Auto-scales relative to the rendered window height so
              // it shrinks proportionally when in PiP.
              // Custom subtitle overlay — hidden when libass is handling
              // ASS/SSA subtitles (they render on the video frame instead).
              if (!_isNativeSubtitle)
                StreamBuilder<List<String>>(
                  stream: _player.stream.subtitle,
                  initialData: _player.state.subtitle,
                  builder: (context, snap) {
                    final lines = snap.data ?? [];
                    final text = lines.where((l) => l.trim().isNotEmpty).join('\n');
                    if (text.isEmpty) return const SizedBox.shrink();
                    // Reference height = 720p. PiP windows are ~108px tall
                    // so scale clamps to a readable minimum.
                    const refHeight = 720.0;
                    final winH = MediaQuery.of(context).size.height;
                    final scale = (winH / refHeight).clamp(0.35, 1.0);
                    final hSidePad = 24.0 * scale;
                    return Positioned(
                      left: hSidePad,
                      right: hSidePad,
                      bottom: _subtitleBottomPadding * scale,
                      child: IgnorePointer(
                        child: Text(
                          text,
                          style: _buildSubtitleTextStyle(scale: scale),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),

              // ── 2. Gesture layer ─────────────────────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTapDown: (d) {
                    _handleDoubleTap(
                        d, d.localPosition.dx > constraints.maxWidth / 2);
                  },
                  onVerticalDragUpdate: (d) =>
                      _onVerticalDragUpdate(d, constraints.maxWidth),
                  onLongPressStart: (_) {
                    if (!_isLocked) _player.setRate(2.0);
                  },
                  onLongPressEnd: (_) {
                    if (!_isLocked) _player.setRate(1.0);
                  },
                  child: Container(color: Colors.transparent),
                );
              }),

              // ── 3. Double-tap ripple ──────────────────────────────────────
              if (_showRipple)
                Positioned(
                  left: _isForward
                      ? null
                      : _ripplePosition.dx - 50,
                  right: _isForward
                      ? (MediaQuery.of(context).size.width -
                              _ripplePosition.dx) -
                          50
                      : null,
                  top: _ripplePosition.dy - 50,
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _rippleOpacity,
                      child: ScaleTransition(
                        scale: _rippleScale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _isForward ? '+10s' : '-10s',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 4. Controls overlay ───────────────────────────────────────
              // Hidden entirely while Android system PiP is active so the
              // floating window shows only the video frame.
              AnimatedOpacity(
                opacity: (_showControls && !_isLocked && !_isPipMode) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ExcludeFocus(
                  excluding: widget.tvRemoteEnabled &&
                      !(_showControls && !_isLocked && !_isPipMode),
                  child: IgnorePointer(
                  ignoring: !(_showControls && !_isLocked) || _isPipMode,
                  child: _buildControlsOverlay(),
                ),
                ),
              ),

              // ── 5. Lock button (always visible when locked + controls shown)
              if (_isLocked)
                Positioned(
                  bottom:
                      MediaQuery.of(context).padding.bottom + 72,
                  left: 12,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _GlassIconButton(
                      icon: Icons.lock_rounded,
                      onPressed: _toggleLock,
                      iconColor: Colors.amber,
                    ),
                  ),
                ),

              // ── 6. Volume indicator ───────────────────────────────────────
              if (_showVolumeIndicator)
                Positioned(
                  right: 20,
                  top: 0, bottom: 0,
                  child: Center(
                      child: _SideIndicator(
                          icon: Icons.volume_up_rounded,
                          value: _volume / 150.0)),
                ),

              // ── 7. Brightness indicator ───────────────────────────────────
              if (_showBrightnessIndicator)
                Positioned(
                  left: 20,
                  top: 0, bottom: 0,
                  child: Center(
                      child: _SideIndicator(
                          icon: Icons.light_mode_rounded,
                          value: _brightness)),
                ),

              // ── 7.5 Skip Segment Overlay (IntroDB) ─────────────────────
              if (_activeSkipLabel != null && !_skipDismissed)
                Positioned(
                  bottom: _showNextEpButton ? 170 : 120,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _performSkip,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                            _activeSkipLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 18),
                        ]),
                      ),
                    ),
                  ),
                ),

              // ── 8. Next Episode Overlay ──────────────────────────────
              if (_showNextEpButton)
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoadingNextEp ? null : _nextEpisode,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_isLoadingNextEp)
                            const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Text(
                              'Next Episode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ]),
                      ),
                    ),
                  ),
                ),

              PlayerStatusOverlay(
                controller: _statusController,
                bufferingListenable: _isBufferingNotifier,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildControlsOverlay() {
    final isTv = widget.movie?.mediaType == 'tv';
    final hasEpisodePicker = (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
    final hasProviders = widget.providers != null && widget.providers!.isNotEmpty &&
        widget.magnetLink == null && widget.activeProvider != 'stremio_direct';
    final hasSources = _currentSources != null && _currentSources!.isNotEmpty;
    final hasTorrentSources = widget.movie != null &&
        ((_activeMagnet ?? widget.magnetLink)?.isNotEmpty ?? false);
    final btnSize = 38.0;
    final iconSz = 20.0;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusMessage: _hasError,
      hasStatusActions: _hasError,
    );
    final tvFocus = widget.tvRemoteEnabled;

    final overlay = Stack(children: [
      const Positioned(
          top: 0, left: 0, right: 0,
          child: PlayerOverlayGradient(isTop: true)),
      const Positioned(
          bottom: 0, left: 0, right: 0,
          child: PlayerOverlayGradient(isTop: false)),

      Positioned(
        top: 0, left: 0, right: 0,
        child: PlayerTopBar(
          title: _displayTitle,
          season: widget.hubEpisodes != null ? null : widget.selectedSeason,
          episode: widget.hubEpisodes != null
              ? null
              : widget.selectedEpisode,
          episodeLine: _hubEpisodeLine,
          statusMessage: _hasError ? _errorMessage : null,
          statusActions: _hasError
              ? PlayerTopStatusActions(
                  onRetry: _initPlayback,
                  onSources: hasSources ? _showSourcesMenu : null,
                  onServers: hasProviders ? _showProviderMenu : null,
                  serversEnabled: !_isSwitchingProvider,
                )
              : null,
          onBack: _exitPlayer,
          tvFocusable: tvFocus,
          trailing: PlayerTopBarActions(
            showPlayer: widget.onSwitchPlayer != null,
            onPlayer: widget.onSwitchPlayer != null
                ? () => unawaited(_showPlayerMenu(context))
                : null,
            showCast: CastingService.instance.isAirPlayAvailable ||
                CastingService.instance.isChromecastAvailable,
            onCast: () {
              showPlayerCastPicker(
                context,
                streamUrl: _currentUrl,
                title: widget.title,
                headers: widget.headers,
                statusController: _statusController,
              );
              _startHideTimer();
            },
            showPip: PipService.instance.isSupported,
            onPip: () async {
              await PipService.instance.enter();
              _startHideTimer();
            },
          ),
        ),
      ),

      if (_displayMovie != null)
        Positioned(
          left: 0,
          top: topBarHeight,
          bottom: 110,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isPlayingNotifier,
            builder: (context, playing, _) => AnimatedOpacity(
              opacity: playing ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: playing,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlayerPausedHero(
                    movie: _displayMovie!,
                    season: widget.hubEpisodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.hubEpisodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeLine: _hubEpisodeLine,
                    episodeOverview: _pausedEpisodeOverview,
                  ),
                ),
              ),
            ),
          ),
        ),

      if (!_isLocked)
        ListenableBuilder(
          listenable: playerStatusOverlayListenable(
            _statusController,
            _isBufferingNotifier,
          ),
          builder: (context, _) {
            if (playerStatusOverlayVisible(
              _statusController,
              _isBufferingNotifier.value,
            )) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: IgnorePointer(
                ignoring: _isLocked,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerCenterActionButton(
                        tvFocusable: tvFocus,
                        icon: Icons.replay_10_rounded,
                        onPressed: () {
                          final pos = _positionNotifier.value -
                              const Duration(seconds: 10);
                          _player.seek(
                              pos < Duration.zero ? Duration.zero : pos);
                          _startHideTimer();
                        },
                      ),
                      const SizedBox(width: 24),
                      ValueListenableBuilder<bool>(
                        valueListenable: _isPlayingNotifier,
                        builder: (context, playing, _) =>
                            PlayerCenterActionButton(
                          tvFocusable: tvFocus,
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 80,
                          iconSize: 44,
                          onPressed: () {
                            playing ? _player.pause() : _player.play();
                            _startHideTimer();
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      PlayerCenterActionButton(
                        tvFocusable: tvFocus,
                        icon: Icons.forward_10_rounded,
                        onPressed: () {
                          final dur = _durationNotifier.value;
                          final pos = _positionNotifier.value +
                              const Duration(seconds: 10);
                          _player.seek(pos > dur ? dur : pos);
                          _startHideTimer();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _durationNotifier,
                builder: (context, duration, _) =>
                    ValueListenableBuilder<Duration>(
                  valueListenable: _positionNotifier,
                  builder: (context, position, _) =>
                      ValueListenableBuilder<Duration>(
                    valueListenable: _bufferedNotifier,
                    builder: (context, buffered, _) => _MobileSeekbar(
                      duration: duration,
                      position: position,
                      bufferedPosition: buffered,
                      onSeek: (t) {
                        _player.seek(t);
                        _startHideTimer();
                      },
                      onDragStart: () => _hideTimer?.cancel(),
                      onDragEnd: _startHideTimer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _isPlayingNotifier,
                      builder: (context, playing, _) => PlayerFlatIconButton(
                        tvFocusable: tvFocus,
                        icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: btnSize,
                        iconSize: iconSz,
                        onPressed: () {
                          playing ? _player.pause() : _player.play();
                          _startHideTimer();
                        },
                      ),
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.replay_10_rounded,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressed: () {
                        final pos = _positionNotifier.value - const Duration(seconds: 10);
                        _player.seek(pos < Duration.zero ? Duration.zero : pos);
                        _startHideTimer();
                      },
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.forward_10_rounded,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressed: () {
                        final dur = _durationNotifier.value;
                        final pos = _positionNotifier.value + const Duration(seconds: 10);
                        _player.seek(pos > dur ? dur : pos);
                        _startHideTimer();
                      },
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.volume_up_rounded,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressed: () {
                        _player.setVolume(_volume > 0 ? 0.0 : 100.0);
                        _startHideTimer();
                      },
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<Duration>(
                      valueListenable: _positionNotifier,
                      builder: (context, pos, _) =>
                          ValueListenableBuilder<Duration>(
                        valueListenable: _durationNotifier,
                        builder: (context, dur, _) => PlayerTimeRange(
                          position: pos,
                          duration: dur,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ]),
                  Row(children: [
                    if (hasTorrentSources)
                      PlayerFlatIconButton(
                        tvFocusable: tvFocus,
                        icon: Icons.link_rounded,
                        size: btnSize,
                        iconSize: iconSz,
                        tooltip: 'Sources',
                        onPressed: _showTorrentSourcesPanel,
                      ),
                    if (hasSources) ...[
                      PlayerFlatIconButton(
                        tvFocusable: tvFocus,
                        icon: Icons.dns_outlined,
                        size: btnSize,
                        iconSize: iconSz,
                        tooltip: 'Sources',
                        onPressedWithContext: (ctx) => _showSourcesMenu(ctx),
                      ),
                    ],
                    if (hasProviders) ...[
                      PlayerFlatIconButton(
                        tvFocusable: tvFocus,
                        icon: Icons.cloud_outlined,
                        size: btnSize,
                        iconSize: iconSz,
                        tooltip: 'Servers',
                        onPressedWithContext: _isSwitchingProvider
                            ? null
                            : (ctx) => _showProviderMenu(ctx),
                        onPressed: () {},
                      ),
                    ],
                    if (hasEpisodePicker)
                      PlayerFlatIconButton(
                        tvFocusable: tvFocus,
                        icon: Icons.video_library_outlined,
                        size: btnSize,
                        iconSize: iconSz,
                        onPressedWithContext: _showEpisodesMenu,
                      ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.audiotrack_rounded,
                      size: btnSize,
                      iconSize: iconSz,
                      tooltip: 'Audio',
                      onPressedWithContext: _showAudioMenu,
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.subtitles_outlined,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressedWithContext: _showSubtitlesMenu,
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.hd_outlined,
                      size: btnSize,
                      iconSize: iconSz,
                      tooltip: 'Quality',
                      onPressedWithContext: _showQualityMenu,
                    ),
                    if (widget.onSwitchPlayer != null)
                      PlayerFlatIconButton(
                        icon: Icons.smart_display_outlined,
                        size: btnSize,
                        iconSize: iconSz,
                        tooltip: 'Player',
                        onPressedWithContext: _showPlayerMenu,
                      ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: Icons.settings_outlined,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressedWithContext: _showSettingsMenu,
                    ),
                    PlayerFlatIconButton(
                      tvFocusable: tvFocus,
                      icon: _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      active: _isLocked,
                      size: btnSize,
                      iconSize: iconSz,
                      onPressed: _toggleLock,
                    ),
                  ]),
                ],
              ),
            ]),
          ),
        ),
      ),
    ]);
    if (!tvFocus) return overlay;
    return FocusScope(
      debugLabel: 'player-chrome',
      child: FocusTraversalGroup(child: overlay),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE SEEKBAR  — touch-friendly, no tooltip (no hover on mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _MobileSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _MobileSeekbar({
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_MobileSeekbar> createState() => _MobileSeekbarState();
}

class _MobileSeekbarState extends State<_MobileSeekbar> {
  bool _isDragging = false;
  double _dragFrac = 0.0;
  double _trackWidth = 0.0;

  double get _playFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    if (_isDragging) return _dragFrac;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get _bufFrac {
    final total = widget.duration.inMilliseconds.toDouble();
    if (total <= 0) return 0;
    return (widget.bufferedPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get _dragTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_dragFrac * total).round());
  }

  double _fracFromLocal(double dx) =>
      (dx / _trackWidth).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) {
        widget.onDragStart();
        setState(() {
          _isDragging = true;
          _dragFrac = _fracFromLocal(d.localPosition.dx);
        });
      },
      onHorizontalDragUpdate: (d) => setState(() {
        _dragFrac = _fracFromLocal(d.localPosition.dx);
      }),
      onHorizontalDragEnd: (_) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(
            Duration(milliseconds: (_dragFrac * total).round()));
        widget.onDragEnd();
        setState(() => _isDragging = false);
      },
      onTapUp: (d) {
        final total = widget.duration.inMilliseconds.toDouble();
        widget.onSeek(Duration(
            milliseconds:
                (_fracFromLocal(d.localPosition.dx) * total).round()));
      },
      // 32px tall hit area — much easier to grab on touch
      child: SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.center,
          child: LayoutBuilder(builder: (context, constraints) {
            _trackWidth = constraints.maxWidth;

            final trackH = _isDragging ? 6.0 : 3.5;
            final thumbR = _isDragging ? 8.0 : 5.5;
            final playPx =
                (_playFrac * _trackWidth).clamp(0.0, _trackWidth);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Background
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  height: trackH,
                  width: _trackWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Buffered
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: trackH,
                  width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Played
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut,
                  height: trackH,
                  width: playPx,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(trackH),
                  ),
                ),
                // Thumb dot
                Positioned(
                  left: playPx - thumbR,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    curve: Curves.easeOut,
                    width: thumbR * 2,
                    height: thumbR * 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: _isDragging
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 8,
                              )
                            ]
                          : [],
                    ),
                  ),
                ),
                // Drag time label — floats above thumb while dragging
                if (_isDragging &&
                    widget.duration.inMilliseconds > 0)
                  Positioned(
                    left: (playPx - 36).clamp(
                        0.0, _trackWidth - 72),
                    top: -34,
                    child: _BlurGlass(           // ← blur OK, only while dragging
                      radius: 8,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: SizedBox(
                        width: 56,
                        child: Text(
                          formatDuration(_dragTime),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIDE INDICATOR  (volume / brightness vertical pill)
// ─────────────────────────────────────────────────────────────────────────────

/// Replaces VolumeBrightnessIndicator from shared_widgets — self-contained.
class _SideIndicator extends StatelessWidget {
  final IconData icon;
  final double value; // 0.0 – 1.0

  const _SideIndicator({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return _BlurGlass(                               // ← blur OK, shown 1 at a time
      radius: 20,
      child: SizedBox(
        width: 44,
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      minHeight: 4,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}