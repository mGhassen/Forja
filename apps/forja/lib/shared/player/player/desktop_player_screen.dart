import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'utils.dart';
import 'menus.dart';

import 'package:rust/rust.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/extractors/stream_extractor.dart';
import 'package:forja/shared/playback/stream_provider_resolver.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/extractors/arabic_service.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/player_metadata.dart';
import 'package:forja/shared/player/controls/seek_bar_with_preview.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_episode_menu.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_stats_card.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_quality_menu.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';
import 'package:forja/shell/app_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY WIDGET PRIMITIVES  (MPVEx-style frosted black glass)
// ─────────────────────────────────────────────────────────────────────────────

/// A rounded glassy container – the visual base for every button / chip.
/// [hovered] brightens the glass slightly for Windows hover feedback.
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool hovered;

  const _Glass({
    required this.child,
    this.radius = 12,
    this.padding,
    this.tint,
    this.hovered = false,
  });

  @override
  Widget build(BuildContext context) {
    // Base fill: 0.55 so the glass reads clearly even on pure black.
    // On hover bump to 0.72 for a crisp lift effect.
    final fillOpacity = hovered ? 0.72 : 0.55;
    final borderOpacity = hovered ? 0.30 : 0.16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (tint ?? const Color(0xFF1C1C1E)).withValues(alpha: fillOpacity),
              (tint ?? Colors.black).withValues(alpha: fillOpacity - 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.55 : 0.35),
              blurRadius: hovered ? 12 : 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Glassy icon button with hover + press feedback (Windows-friendly).
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool active;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 18,
    this.iconColor,
    this.active = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _tint {
    if (widget.active) return const Color(0xFF6A0DAD);
    if (_pressed)      return const Color(0xFF2A2A2E);
    return const Color(0xFF1C1C1E);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:   (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: _Glass(
            radius: widget.size / 2,
            tint: _tint,
            hovered: _hovered,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.iconColor ??
                    (widget.active
                        ? Colors.white
                        : _hovered
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.80)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy pill / chip button with hover + press feedback.
class GlassPillButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color? accent;

  const GlassPillButton({
    super.key,
    required this.text,
    required this.onTap,
    this.accent,
  });

  @override
  State<GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<GlassPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: _Glass(
            radius: 20,
            tint: widget.accent ?? const Color(0xFF1C1C1E),
            hovered: _hovered,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.accent != null
                    ? Colors.white
                    : _hovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Center play/pause big button with hover + press feedback.
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
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isBuffering) {
      return _Glass(
        radius: 40,
        hovered: false,
        child: const SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() { _hovered = false; _pressed = false; }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp:     (_) => setState(() => _pressed = false),
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : (_hovered ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: _Glass(
            radius: 40,
            hovered: _hovered,
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
      ),
    );
  }
}

/// Gradient overlay at top or bottom of the video
class _OverlayGradient extends StatelessWidget {
  final bool isTop;
  const _OverlayGradient({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HARDWARE DECODE MODE
// ─────────────────────────────────────────────────────────────────────────────

enum _HwDecMode {
  /// auto-safe: whitelisted GPU decoders, safe fallback chain. Best for most users.
  autoSafe,

  /// auto-copy: GPU decodes → copies back to RAM. Compatible with video filters.
  autoCopy,

  /// no: pure software/CPU decoding. Always works, highest CPU, most compatible.
  software,
}

extension _HwDecModeX on _HwDecMode {
  String get mpvValue => switch (this) {
        _HwDecMode.autoSafe => 'auto-safe',
        _HwDecMode.autoCopy => 'auto-copy',
        _HwDecMode.software => 'no',
      };

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
        _HwDecMode.software => Colors.white24,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  DESKTOP PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DesktopPlayerScreen extends StatefulWidget {
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

  const DesktopPlayerScreen({
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
  });

  @override
  State<DesktopPlayerScreen> createState() => _DesktopPlayerScreenState();
}

class _DesktopPlayerScreenState extends State<DesktopPlayerScreen>
    with WindowListener, WidgetsBindingObserver {
  // ── Player ──────────────────────────────────────────────────────────────
  late Player _player;
  late VideoController _controller;
  bool _playerReady = false;
  bool _disposed = false;
  int _fallbackGen = 0;
  bool _historySaved = false;
  bool _hasError = false;
  String _errorMessage = '';

  // ── UI State ─────────────────────────────────────────────────────────────
  bool _showControls = true;
  Timer? _hideTimer;
  bool _showTorrentStatsOverlay = false;
  StreamSubscription<TorrentStats>? _torrentStatsSub;
  TorrentStats? _torrentStats;
  Movie? _heroMovie;
  String? _episodeOverview;
  bool _isFullscreen = false;
  BoxFit _videoFit = BoxFit.contain;
  bool _isPipMode = false;
  bool _pipHover = false;
  StreamSubscription<bool>? _pipSub;

  // ── Resume State ─────────────────────────────────────────────────────────
  bool _hasInitialSeek = false;

  // ── Stream Subscriptions ─────────────────────────────────────────────────
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Tracks>? _tracksSub;
  bool _autoTracksAppliedForSource = false;
  // ── Value Notifiers (rebuild only what's needed, no full setState) ────────
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _bufferedNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _volumeNotifier = ValueNotifier(100.0);

  // ── Subtitles ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _externalSubtitles = [];
  bool _isFetchingSubs = false;
  /// When true, the current subtitle is ASS/SSA or an image-based format (PGS/VobSub).
  /// mpv renders it directly on the video frame, so the custom Flutter overlay is hidden.
  bool _isNativeSubtitle = false;
  String? _selectedExternalSubUrl;

  // ── Provider switching ────────────────────────────────────────────────────
  String? _currentProvider;
  List<StreamSource>? _currentSources;
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

  // ── Feature State ────────────────────────────────────────────────────────
  _HwDecMode _hwDecMode = _HwDecMode.autoSafe;
  bool _loopEnabled = false;
  double _subtitleDelay = 0.0;
  double _subtitleSize = 44.0;
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
  String? _activeSkipLabel;   // e.g. 'Skip Intro', 'Skip Recap', etc.
  Duration? _activeSkipTarget; // where to seek when the user taps
  bool _skipDismissed = false; // user dismissed the current segment button

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
    _currentUrl = widget.mediaPath;
    _activeMagnet = widget.magnetLink;
    if (_currentProvider == 'service111477' &&
        widget.sources != null &&
        widget.sources!.isNotEmpty) {
      _current111477FileUrl = widget.sources!.first.url;
    }
    widget.sourcesListNotifier?.addListener(_onLiveSourcesUpdated);
    
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);

    // Track desktop PiP state so we can hide all controls when active.
    _pipSub = PipService.instance.desktopPipChanges.listen((on) {
      if (!mounted) return;
      setState(() => _isPipMode = on);
    });

    _loadHeroMetadata();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    unawaited(_createPlayer());
  }

  Future<void> _createPlayer() async {
    await MpvExclusiveSession.instance.prepareForVideoPlayer();
    if (!mounted || _disposed) return;

    _player = MpvExclusiveSession.instance.trackPlayer(
      Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          libass: true,
          libassAndroidFont: 'assets/fonts/Roboto-Regular.ttf',
          libassAndroidFontName: 'Roboto',
        ),
      ),
    );

    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    if (!mounted || _disposed) {
      MpvExclusiveSession.instance.untrackPlayer(_player);
      final disposeFuture = _player.dispose();
      MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
      await disposeFuture;
      return;
    }

    _playerReady = true;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_playerReady) return;
      await waitForRouteTransition(context);
      if (!mounted || !_playerReady) return;
      _loadSubtitlePrefs();
      _loadTorrentStatsPref();
      _initPlayback();
      _startHideTimer();
      _fetchSubtitles();
      if (widget.movie != null && widget.hubEpisodes == null) {
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
      _fetchIntroDbTimestamps();
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
    _saveWatchHistory();

    _fallbackGen++;
    WebStreamrService().cancelPending();
    VidsrcExtractor.cancelPending();
    NuvioService.instance.cancelPending();

    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _pipSub?.cancel();
    _torrentStatsSub?.cancel();
    PlayerTorrentFilePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    // If we tear down while in PiP, restore window chrome so the next
    // screen doesn't inherit a tiny frameless 480x270 window.
    if (PipService.instance.isDesktopActive) {
      PipService.instance.leave();
    }

    // Cancel all subscriptions
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _volumeSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();

    // Dispose value notifiers
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _bufferedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _isBufferingNotifier.dispose();
    _hlsQualitiesNotifier.dispose();
    _volumeNotifier.dispose();
    _statusController.dispose();
    _sourceMenuRevision.dispose();
    _isReloadingStreams.dispose();

    if (_playerReady) {
      MpvExclusiveSession.instance.untrackPlayer(_player);
      final disposeFuture = _player.dispose().catchError((_) {});
      MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
      unawaited(disposeFuture);
    }

    // Remove torrent from engine on player exit (use magnetLink for hash,
    // fall back to mediaPath which may be a stream URL).
    final torrentId = widget.magnetLink ?? widget.mediaPath;
    TorrentStreamService().removeTorrent(torrentId);

    // Tear down the 111477 proxy and delete its on-disk cache.
    if (site111477_proxy.is111477ProxyRunning) {
      site111477_proxy.stop111477Proxy();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Save progress when app goes to background or is paused
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveWatchHistory(isBgPause: true);
    } else if (state == AppLifecycleState.resumed) {
      _historySaved = false;
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
    if (_historySaved && !isBgPause) return;
    _historySaved = true;
    final pos = _positionNotifier.value.inMilliseconds;
    final dur = _durationNotifier.value.inMilliseconds;

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
      // Extract animeId from the activeProvider or match by title
      // The most recent entry at index 0 is the currently playing anime
      // (addToWatchHistory inserts at 0 before playback starts)
      if (list.isNotEmpty) {
        final entry = jsonDecode(list[0]) as Map<String, dynamic>;
        entry['position'] = posMs;
        entry['duration'] = durMs;
        list[0] = jsonEncode(entry);
        prefs.setStringList('anime_watch_history', list);
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

      if (_currentProvider == 'arabic' && source.type == 'arabic_embed') {
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

        var openUrl = source.url;
        if (_currentProvider == 'service111477') {
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

        final srcHeaders = source.headers ?? widget.headers;
        await resetPlayerForOpen(_player);
        await applyMediaHttpHeaders(_player, srcHeaders);
        await _player.open(Media(openUrl, httpHeaders: srcHeaders));
        _player.setVolume(_volumeNotifier.value);
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
            dismissAfter: const Duration(milliseconds: 500),
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
            dismissAfter: const Duration(milliseconds: 500),
          );
          _markSourceFailed(i);
          _currentFallbackSourceIndex++;
          continue;
        }
        if (needsDuration && !await waitForSeekableDuration(_player)) {
          debugPrint('[Player] Source $i opened without duration: $openUrl');
          await _player.stop();
          _statusController.upsert(
            'source-$i',
            source.title,
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(milliseconds: 500),
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
        _detectHlsQualities(openUrl, source.headers ?? widget.headers);
        setState(() {
          _currentUrl = openUrl;
        });
        _playbackConfirmed = true;
        _statusController.complete();
        _markSourceActive(i);
        widget.onPlaybackStarted?.call();
        return true;
      } catch (e) {
        debugPrint('[Player] Source $i catch error: $e');
        await _player.stop();
        _statusController.upsert(
          'source-$i',
          source.title,
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 500),
        );
        _markSourceFailed(i);
        _currentFallbackSourceIndex++;
      }
    }
    return false;
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
          _player.setVolume(_volumeNotifier.value);
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
    final providerKeys = widget.providers!.keys.toList();
    int currentIndex = providerKeys.indexOf(_currentProvider ?? '');
    
    for (int i = currentIndex + 1; i < providerKeys.length; i++) {
      if (_fallbackAborted(chainGen)) return;
      final nextKey = providerKeys[i];
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

      if (newProvider == 'service111477' && widget.movie != null) {
        final svc = Site111477Service();
        List<Site111477Match> hits;
        if (widget.movie!.mediaType == 'tv') {
          hits = await svc.findEpisodeSources(
            showTitle: widget.movie!.title,
            season: widget.selectedSeason ?? 1,
            episode: widget.selectedEpisode ?? 1,
          );
        } else {
          final year = widget.movie!.releaseDate.length >= 4
              ? widget.movie!.releaseDate.substring(0, 4)
              : null;
          hits = await svc.findMovieSources(title: widget.movie!.title, year: year);
        }
        if (_fallbackAborted(gen)) return false;
        if (hits.isNotEmpty) {
          if (site111477_proxy.is111477ProxyRunning) {
            await site111477_proxy.stop111477Proxy();
          }
          streamUrl = await site111477_proxy.start111477Proxy(hits.first.fileUrl);
          sources = Site111477Service.toStreamSources(hits);
          _current111477FileUrl = hits.first.fileUrl;
        }
      } else if (newProvider == 'webstreamr' && widget.movie?.imdbId != null) {
        final webStreamr = WebStreamrService();
        final webStreamrSources = await webStreamr.getStreams(
          imdbId: widget.movie!.imdbId!,
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (_fallbackAborted(gen)) return false;
        if (webStreamrSources.isNotEmpty) {
          streamUrl = webStreamrSources.first.url;
          sources = webStreamrSources;
        }
      } else if (newProvider == 'videasy' && widget.movie != null) {
        final ve = VideasyExtractor(onLog: (m) => debugPrint(m));
        final result = await ve.extract(
          tmdbId: widget.movie!.id.toString(),
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return false;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
        }
      } else if (newProvider == 'vidsrc' && widget.movie != null) {
        final ve = VidsrcExtractor();
        final result = await ve.extract(
          tmdbId: widget.movie!.id.toString(),
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (_fallbackAborted(gen)) return false;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
        }
      } else if (newProvider.startsWith('nuvio:') && widget.movie != null) {
        final scraperId = newProvider.substring(6);
        final results = await NuvioService.instance.runOneScraper(
          scraperId: scraperId,
          tmdbId: widget.movie!.id.toString(),
          type: widget.movie!.mediaType == 'tv' ? 'tv' : 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (_fallbackAborted(gen)) return false;
        if (results.isNotEmpty) {
          final first = results.first;
          streamUrl = first.url;
          headers = first.headers.isEmpty ? null : first.headers;
          sources = results.map((r) => StreamSource(
                url: r.url,
                title: r.title.isNotEmpty ? r.title : r.name,
                type: r.url.toLowerCase().contains('.m3u8')
                    ? 'hls'
                    : r.url.toLowerCase().contains('.mpd')
                        ? 'dash'
                        : 'mp4',
                headers: r.headers.isEmpty ? null : r.headers,
              )).toList();
        }
      } else if (provider['movie'] != null && provider['tv'] != null) {
        final String providerUrl;
        if (widget.movie!.mediaType == 'tv') {
          providerUrl = provider['tv'](
            widget.movie!.id.toString(),
            widget.selectedSeason,
            widget.selectedEpisode,
          );
        } else {
          providerUrl = provider['movie'](widget.movie!.id.toString());
        }
        
        final extractor = StreamExtractor();
        final result = await extractor.extract(
          providerUrl,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return false;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
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
    _volumeSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _autoTracksAppliedForSource = false;

    // Position – drives seekbar & watch-history
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

    // Duration – triggers auto-resume on first valid duration
    _durationSub = _player.stream.duration.listen((dur) {
      if (_disposed) return;
      _durationNotifier.value = dur;
      if (!_hasInitialSeek && dur.inSeconds > 0 && widget.startPosition != null) {
        _hasInitialSeek = true;
        _player.seek(widget.startPosition!);
      }
    });

    // Buffered position – shows how far ahead is cached
    _bufferSub = _player.stream.buffer.listen((buf) {
      if (_disposed) return;
      _bufferedNotifier.value = buf;
    });

    // Playing state
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

    // Buffering spinner
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (_disposed) return;
      _isBufferingNotifier.value = buffering;
    });

    // Volume sync (e.g. hardware media keys)
    _volumeSub = _player.stream.volume.listen((vol) {
      if (_disposed) return;
      _volumeNotifier.value = vol;
    });

    // Error recovery – log & surface to UI
    _errorSub = _player.stream.error.listen((err) {
      if (_disposed || err.isEmpty) return;
      if (isIgnorablePlayerError(err)) {
        if (err.contains('subtitle') ||
            err.toLowerCase().contains('sub-add') ||
            err.toLowerCase().contains('external file')) {
          debugPrint('🟡 Sub error (ignored): $err');
        }
        return;
      }

      debugPrint('🔴 Player error: $err');

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

    // Completion – could trigger next-episode logic here in the future
    _completedSub = _player.stream.completed.listen((completed) {
      if (_disposed || !completed) return;
      if (!_playbackConfirmed || _isInitPlaybackRunning) return;
      if (isNaturalPlaybackEnd(_player.state)) {
        debugPrint('✅ Playback completed');
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
      final hasAudio = tracks.audio.any((t) => t.id != 'no' && t.id != 'auto');
      if (!hasAudio) return;
      _autoTracksAppliedForSource = true;
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
      debugPrint('[DesktopPlayer] track auto-select failed: $e');
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
    // auto-safe: tries whitelisted GPU decoders, falls back gracefully.
    // This is the officially recommended hwdec mode by mpv developers.
    await safeSet('hwdec', _hwDecMode.mpvValue);

    // Zero-copy direct rendering from decoder to GPU texture when possible.
    // Reduces RAM usage and improves throughput, especially on 4K/HEVC.
    await safeSet('vd-lavc-dr', 'yes');

    // Let mpv pick the optimal thread count automatically (0 = auto).
    await safeSet('vd-lavc-threads', '0');

    // ── Audio Codec Fallback ──────────────────────────────────────────────
    // Continue playback even if audio codec is unsupported (e.g., TrueHD).
    // User can switch to alternate audio track from the menu.
    await safeSet('ad-lavc-downmix', 'no');
    await safeSet('audio-fallback-to-null', 'yes');

    // Disable built-in OSD / subtitle rendering – Flutter renders them.
    await safeSet('sub-visibility', 'no');
    await safeSet('sub-auto', 'all');

    // ── Video Sync & Smoothness ───────────────────────────────────────────
    // display-resample: syncs to the monitor's refresh rate, eliminates judder.
    // This is the best sync mode for desktop displays.
    await safeSet('video-sync', 'display-resample');

    // Temporal interpolation to smooth out frame pacing between display frames.
    // Significantly reduces judder on 24fps content on 60Hz+ monitors.
    await safeSet('interpolation', 'yes');
    await safeSet('tscale', 'oversample'); // lightweight interpolation

    // ── Network / Streaming ───────────────────────────────────────────────
    await safeSet('network-timeout', '30');
    await safeSet('tls-verify', 'no'); // for self-signed / CDN certs

    // Don't freeze on brief cache drain — keep decoding through HLS hiccups.
    await safeSet('cache-pause', 'no');
    await safeSet('cache-pause-initial', 'no');

    final isTorrent = widget.magnetLink != null;
    if (isTorrent) {
      // Torrent engine feeds bytes from disk as pieces complete — a small
      // forward window is enough and keeps memory pressure low.
      // Long network-timeout: first pieces can stall while peers connect.
      await safeSet('cache', 'yes');
      await safeSet('network-timeout', '60');
      await safeSet('demuxer-readahead-secs', '20');
      await safeSet('force-seekable', 'yes');
      await safeSet('hr-seek', 'yes');
      await safeSet('hr-seek-framedrop', 'no');
    } else {
      // Cache: 300 MB in memory, read 120 s ahead.
      // This dramatically reduces rebuffering on variable-bitrate streams.
      await safeSet('cache', 'yes');
      await safeSet('cache-secs', '120');
      await safeSet('demuxer-max-bytes', '300MiB');
      await safeSet('demuxer-readahead-secs', '120');

      // How far back the demuxer keeps decoded data (for backward seeks).
      await safeSet('demuxer-max-back-bytes', '50MiB');

      // Let mpv adapt HLS bitrate to network conditions (not locked to max).
      await safeSet('hls-bitrate', 'no');
    }

    // Prevent yt-dlp from being invoked (we supply our own URL).
    await safeSet('ytdl', 'no');

    // ── Volume ────────────────────────────────────────────────────────────
    // Allow boosting volume above 100% (up to 150%) for quiet sources.
    await safeSet('volume-max', '150');

    // ── External Audio Track ──────────────────────────────────────────────
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
    // position. This is more reliable than seeking after open, because the
    // post-open seek can be silently dropped before the demuxer is fully
    // initialised.
    if (widget.startPosition != null && !_hasInitialSeek) {
      final secs = widget.startPosition!.inMilliseconds / 1000.0;
      await safeSet('start', '+${secs.toStringAsFixed(3)}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HARDWARE DECODE CYCLE
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
  //  SUBTITLE MANAGEMENT
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
      // Many subtitle CDNs (megacloud, vid-cdn, lostproject.club, etc.) gate
      // on a browser UA and the embed-host Referer (NOT the sub URL's own
      // host). Prefer the referer/origin the extractor passed through;
      // otherwise fall back to the sub URL's own origin.
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

  /// If the user has a preferred subtitle language but the embedded tracks
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
      builder: (context) => StatefulBuilder(builder: (context, setDialog) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('Subtitle Settings',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Size ─────────────────────────────────────────────
              _subRow('Size', Expanded(child: Slider(
                value: _subtitleSize, min: 20, max: 80,
                thumbColor: const Color(0xFF7C3AED),
                onChanged: (v) { setDialog(() => _subtitleSize = v); setState(() {}); },
              )), '${_subtitleSize.toInt()}'),

              // ── Delay (arrow buttons) ──────────────────────────
              _subRow('Delay', Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white70, size: 20),
                  onPressed: () {
                    final v = _subtitleDelay - 0.1;
                    setDialog(() => _subtitleDelay = double.parse(v.toStringAsFixed(1)));
                    if (_player.platform is NativePlayer) {
                      (_player.platform as NativePlayer).setProperty('sub-delay', _subtitleDelay.toString());
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                  onPressed: () {
                    final v = _subtitleDelay + 0.1;
                    setDialog(() => _subtitleDelay = double.parse(v.toStringAsFixed(1)));
                    if (_player.platform is NativePlayer) {
                      (_player.platform as NativePlayer).setProperty('sub-delay', _subtitleDelay.toString());
                    }
                  },
                ),
              ]), '${_subtitleDelay.toStringAsFixed(1)}s'),

              // ── Text Color ─────────────────────────────────────
              _subLabel('Text Color'),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 8, children: colorOptions.entries.map((e) {
                final selected = _subtitleColor.toARGB32() == e.value.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setDialog(() => _subtitleColor = e.value);
                    setState(() {});
                    SettingsService().setSubColor(e.value.toARGB32());
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? const Color(0xFF7C3AED) : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),

              // ── Background Opacity ─────────────────────────────
              _subRow('BG Opacity', Expanded(child: Slider(
                value: _subtitleBgOpacity, min: 0.0, max: 1.0,
                thumbColor: const Color(0xFF7C3AED),
                onChanged: (v) { setDialog(() => _subtitleBgOpacity = v); setState(() {}); },
              )), '${(_subtitleBgOpacity * 100).toInt()}%'),

              // ── Position (bottom padding) ──────────────────────
              _subRow('Position', Expanded(child: Slider(
                value: _subtitleBottomPadding, min: 0, max: 120,
                thumbColor: const Color(0xFF7C3AED),
                onChanged: (v) { setDialog(() => _subtitleBottomPadding = v); setState(() {}); },
              )), '${_subtitleBottomPadding.toInt()}'),

              // ── Bold ───────────────────────────────────────────
              Row(children: [
                const SizedBox(width: 70, child: Text('Bold', style: TextStyle(color: Colors.white70, fontSize: 13))),
                const Spacer(),
                Switch(
                  value: _subtitleBold,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (v) { setDialog(() => _subtitleBold = v); setState(() {}); SettingsService().setSubBold(v); },
                ),
              ]),

              // ── Font ───────────────────────────────────────────
              _subLabel('Font'),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: fonts.map((f) {
                final selected = _subtitleFont == f;
                return GestureDetector(
                  onTap: () { setDialog(() => _subtitleFont = f); setState(() {}); SettingsService().setSubFont(f); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? const Color(0xFF7C3AED) : Colors.white12),
                    ),
                    child: Text(f, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12)),
                  ),
                );
              }).toList()),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SettingsService().setSubSize(_subtitleSize);
                SettingsService().setSubBgOpacity(_subtitleBgOpacity);
                SettingsService().setSubBottomPadding(_subtitleBottomPadding);
                Navigator.pop(context);
              },
              child: const Text('Close', style: TextStyle(color: Color(0xFF7C3AED))),
            ),
          ],
        );
      }),
    );
  }

  Widget _subRow(String label, Widget middle, String trailing) {
    return Row(children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      if (middle is Expanded) middle else middle,
      SizedBox(width: 44, child: Text(trailing, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.right)),
    ]);
  }

  Widget _subLabel(String label) {
    return Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)));
  }

  Future<void> _loadSubtitlePrefs() async {
    final s = SettingsService();
    final size = await s.getSubSize(isDesktop: true);
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

  Future<void> _loadTorrentStatsPref() async {
    final show = await SettingsService().getShowTorrentStatsOverlay();
    if (!mounted) return;
    setState(() => _showTorrentStatsOverlay = show);
    _syncTorrentStatsSubscription();
  }

  void _syncTorrentStatsSubscription() {
    _torrentStatsSub?.cancel();
    _torrentStatsSub = null;
    final magnet = widget.magnetLink;
    if (!_showTorrentStatsOverlay || magnet == null || magnet.isEmpty) {
      if (_torrentStats != null && mounted) {
        setState(() => _torrentStats = null);
      } else {
        _torrentStats = null;
      }
      return;
    }
    _torrentStatsSub =
        TorrentStreamService().statsStream(magnet).listen((stats) {
      if (!mounted) return;
      setState(() => _torrentStats = stats);
    });
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
  //  AUDIO
  // ─────────────────────────────────────────────────────────────────────────

  void _showAudioMenu(BuildContext anchorContext) {
    PlayerAudioMenu.show(
      context,
      player: _player,
      audioPinned: _audioPinned,
      onSelectAuto: _selectAutoAudio,
      onManualSelect: () => setState(() => _audioPinned = true),
      anchorContext: anchorContext,
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
    final existing = _hlsQualitiesNotifier.value;
    if (existing != null && existing.any((q) => q.url == url)) return;

    _hlsMasterUrl = url;
    _hlsMasterHeaders = headers;
    _hlsQualitiesNotifier.value = null;
    fetchHlsQualities(url, headers: headers).then((qs) {
      if (_disposed) return;
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
    _onMouseMove();
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
    if (_disposed || !mounted) return;
    final live = widget.sourcesListNotifier?.value;
    if (live == null || live.isEmpty) return;
    final merged = dedupeStreamSources(live);
    final prevLen = _currentSources?.length ?? 0;
    if (merged.length <= prevLen &&
        (_currentSources == null ||
            identical(merged, _currentSources) ||
            (merged.length == prevLen &&
                merged.every((s) =>
                    _currentSources!.any((c) => c.url == s.url))))) {
      return;
    }
    setState(() => _currentSources = merged);
    _notifySourceMenuChanged();
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

  void _showSourcesMenu([BuildContext? anchorContext]) {
    if (_currentSources == null || _currentSources!.isEmpty) return;
    PlayerStreamMenu.show(
      context,
      readState: _streamMenuState,
      onSelectProvider: _switchProvider,
      onSelectAutoProvider: _selectAutoProvider,
      onSelectAutoSource: _selectAutoSource,
      onSelectSource: _switchToStreamSource,
      sourcesOnly: true,
      anchorContext: anchorContext,
      refreshListenable:
          Listenable.merge([_statusController, _sourceMenuRevision, _isReloadingStreams]),
      onReload: _reloadStreamMenu,
      isReloading: _isReloadingStreams,
    );
    _onMouseMove();
  }

  void _showProviderMenu([BuildContext? anchorContext]) {
    if (widget.providers == null ||
        widget.providers!.isEmpty ||
        widget.movie == null ||
        widget.magnetLink != null ||
        widget.activeProvider == 'stremio_direct') {
      return;
    }
    PlayerStreamMenu.show(
      context,
      providers: widget.providers,
      readState: _streamMenuState,
      onSelectProvider: _switchProvider,
      onSelectAutoProvider: _selectAutoProvider,
      onSelectAutoSource: _selectAutoSource,
      onSelectSource: _switchToStreamSource,
      providersEnabled: !_isSwitchingProvider,
      anchorContext: anchorContext,
      refreshListenable:
          Listenable.merge([_statusController, _sourceMenuRevision, _isReloadingStreams]),
      onReload: _reloadStreamMenu,
      isReloading: _isReloadingStreams,
    );
    _onMouseMove();
  }

  Future<void> _selectAutoProvider() async {
    if (!_providerPinned) return;
    setState(() {
      _providerPinned = false;
      _sourcePinned = false;
      _currentFallbackSourceIndex = 0;
    });
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
      await _player.open(
        Media(source.url, httpHeaders: source.headers ?? widget.headers),
      );
      setState(() {
        _currentUrl = source.url;
        _currentFallbackSourceIndex = 0;
        _hasError = false;
        _errorMessage = '';
      });
      _detectHlsQualities(source.url, source.headers ?? widget.headers);
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

  Future<Uint8List?> _captureSeekPreview(Duration position) async {
    try {
      if (!_isPlayingNotifier.value) {
        await _player.seek(position);
        await Future.delayed(const Duration(milliseconds: 150));
      }
      return await _player.screenshot(format: 'image/jpeg');
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MISC CONTROLS
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleLoop() {
    setState(() => _loopEnabled = !_loopEnabled);
    _player.setPlaylistMode(
        _loopEnabled ? PlaylistMode.single : PlaylistMode.none);
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SKIP SEGMENTS (IntroDB)
  // ───────────────────────────────────────────────────────────────────────────

  void _updateActiveSkipSegment(Duration pos) {
    if (_introDbData == null) return;

    final posMs = pos.inMilliseconds;
    String? label;
    Duration? target;

    // Check each segment type – first match wins
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

    // Only setState when needed – avoid per-frame rebuilds
    if (label != _activeSkipLabel) {
      setState(() {
        _activeSkipLabel = label;
        _activeSkipTarget = target;
        _skipDismissed = false; // reset dismiss when segment changes
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

  // ───────────────────────────────────────────────────────────────────────────
  //  NEXT EPISODE
  // ───────────────────────────────────────────────────────────────────────────

  bool get _isNextEpisodeAvailable =>
      (widget.onNextEpisode != null && widget.hasNextEpisode) ||
      (widget.movie != null &&
          widget.movie!.mediaType == 'tv' &&
          widget.selectedSeason != null &&
          widget.selectedEpisode != null);

  bool get _showNextEpButton =>
      _isNextEpisodeAvailable && (_nearEndOfEpisode || _isLoadingNextEp);

  /// Extra space under the torrent stats card so it sits above Skip / Next.
  double get _torrentStatsLift {
    final skipVisible = _activeSkipLabel != null && !_skipDismissed;
    if (skipVisible && _showNextEpButton) return 110;
    if (skipVisible || _showNextEpButton) return 55;
    return 0;
  }

  Future<void> _nextEpisode() async {
    if (!_isNextEpisodeAvailable || _isLoadingNextEp) return;

    setState(() => _isLoadingNextEp = true);

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
    final frame = await _capturePanelFrostFrame();
    if (!mounted) return;
    if (widget.hubEpisodes != null &&
        widget.hubEpisodes!.isNotEmpty &&
        widget.onHubEpisodeSelected != null) {
      PlayerPopupPanel.dismiss();
      PlayerHubEpisodePanel.show(
        context: context,
        episodes: widget.hubEpisodes!,
        currentEpisode:
            widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: widget.onHubEpisodeSelected!,
        frozenFrame: frame,
      );
      return;
    }
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
    _player.setVolume(_volumeNotifier.value);

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
    _onMouseMove();
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
    _player.setVolume(_volumeNotifier.value);

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
    _onMouseMove();
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
                        GlassPillButton(
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
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
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
              if (widget.magnetLink != null && widget.magnetLink!.isNotEmpty)
                PlayerPopupListTile(
                  label: 'Torrent stats',
                  subtitle: _showTorrentStatsOverlay ? 'On' : 'Off',
                  selected: _showTorrentStatsOverlay,
                  onTap: () async {
                    final next = !_showTorrentStatsOverlay;
                    setState(() => _showTorrentStatsOverlay = next);
                    setPanelState(() {});
                    await SettingsService().setShowTorrentStatsOverlay(next);
                    _syncTorrentStatsSubscription();
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

      if (newProvider == 'service111477' && widget.movie != null) {
        final svc = Site111477Service();
        List<Site111477Match> hits;
        if (widget.movie!.mediaType == 'tv') {
          hits = await svc.findEpisodeSources(
            showTitle: widget.movie!.title,
            season: widget.selectedSeason ?? 1,
            episode: widget.selectedEpisode ?? 1,
          );
        } else {
          final year = widget.movie!.releaseDate.length >= 4
              ? widget.movie!.releaseDate.substring(0, 4)
              : null;
          hits = await svc.findMovieSources(title: widget.movie!.title, year: year);
        }
        if (_fallbackAborted(gen)) return null;
        if (hits.isNotEmpty) {
          if (site111477_proxy.is111477ProxyRunning) {
            await site111477_proxy.stop111477Proxy();
          }
          streamUrl = await site111477_proxy.start111477Proxy(hits.first.fileUrl);
          sources = Site111477Service.toStreamSources(hits);
          _current111477FileUrl = hits.first.fileUrl;
        }
      } else if (newProvider == 'webstreamr' && widget.movie?.imdbId != null) {
        final webStreamr = WebStreamrService();
        final webStreamrSources = await webStreamr.getStreams(
          imdbId: widget.movie!.imdbId!,
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (webStreamrSources.isNotEmpty) {
          streamUrl = webStreamrSources.first.url;
          sources = webStreamrSources;
        }
        if (_fallbackAborted(gen)) return null;
      } else if (newProvider == 'videasy' && widget.movie != null) {
        final ve = VideasyExtractor(onLog: (m) => debugPrint(m));
        final result = await ve.extract(
          tmdbId: widget.movie!.id.toString(),
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return null;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
        }
      } else if (newProvider == 'vidsrc' && widget.movie != null) {
        final ve = VidsrcExtractor();
        final result = await ve.extract(
          tmdbId: widget.movie!.id.toString(),
          isMovie: widget.movie!.mediaType == 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (_fallbackAborted(gen)) return null;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
        }
      } else if (newProvider.startsWith('nuvio:') && widget.movie != null) {
        final scraperId = newProvider.substring(6);
        final results = await NuvioService.instance.runOneScraper(
          scraperId: scraperId,
          tmdbId: widget.movie!.id.toString(),
          type: widget.movie!.mediaType == 'tv' ? 'tv' : 'movie',
          season: widget.selectedSeason,
          episode: widget.selectedEpisode,
        );
        if (_fallbackAborted(gen)) return null;
        if (results.isNotEmpty) {
          final first = results.first;
          streamUrl = first.url;
          headers = first.headers.isEmpty ? null : first.headers;
          sources = results.map((r) => StreamSource(
                url: r.url,
                title: r.title.isNotEmpty ? r.title : r.name,
                type: r.url.toLowerCase().contains('.m3u8')
                    ? 'hls'
                    : r.url.toLowerCase().contains('.mpd')
                        ? 'dash'
                        : 'mp4',
                headers: r.headers.isEmpty ? null : r.headers,
              )).toList();
        }
      } else if (provider['movie'] != null && provider['tv'] != null) {
        final String providerUrl;
        if (widget.movie!.mediaType == 'tv') {
          providerUrl = provider['tv'](
            widget.movie!.id.toString(),
            widget.selectedSeason,
            widget.selectedEpisode,
          );
        } else {
          providerUrl = provider['movie'](widget.movie!.id.toString());
        }
        
        final extractor = StreamExtractor();
        final result = await extractor.extract(
          providerUrl,
          isCancelled: () => _fallbackAborted(gen),
        );
        if (_fallbackAborted(gen)) return null;
        if (result != null && result.url.isNotEmpty) {
          streamUrl = result.url;
          headers = result.headers;
          sources = result.sources;
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
  //  UI AUTO-HIDE
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

  void _onMouseMove() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
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

  // ─────────────────────────────────────────────────────────────────────────
  //  FULLSCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleFullscreen() async {
    final isFull = await windowManager.isFullScreen();
    if (!isFull && await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setFullScreen(!isFull);
    if (mounted) setState(() => _isFullscreen = !isFull);
  }

  Future<void> _exitPlayer() async {
    if (PlayerPopupPanel.isShowing) {
      PlayerPopupPanel.dismiss();
      return;
    }
    if (_isFullscreen) {
      await windowManager.setFullScreen(false);
      if (mounted) setState(() => _isFullscreen = false);
    }
    _saveWatchHistory();
    if (mounted) Navigator.of(context).pop(_positionNotifier.value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KEYBOARD SHORTCUTS
  // ─────────────────────────────────────────────────────────────────────────

  bool _handleKeyEvent(KeyEvent event) {
    if (!_playerReady) return false;
    if (event is! KeyDownEvent) return false;
    _onMouseMove();

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _player.playOrPause();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: -30)
          : const Duration(seconds: -10);
      var newPos = _positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _durationNotifier.value) newPos = _durationNotifier.value;
      _player.seek(newPos);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final delta = HardwareKeyboard.instance.isShiftPressed
          ? const Duration(seconds: 30)
          : const Duration(seconds: 10);
      var newPos = _positionNotifier.value + delta;
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _durationNotifier.value) newPos = _durationNotifier.value;
      _player.seek(newPos);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _player.setVolume((_volumeNotifier.value + 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _player.setVolume((_volumeNotifier.value - 5).clamp(0, 150));
    } else if (key == LogicalKeyboardKey.keyM) {
      _player.setVolume(_volumeNotifier.value > 0 ? 0.0 : 100.0);
    } else if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (key == LogicalKeyboardKey.escape) {
      unawaited(_exitPlayer());
    } else if (key == LogicalKeyboardKey.keyL) {
      _toggleLoop();
    } else {
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ASPECT RATIO CYCLE
  // ─────────────────────────────────────────────────────────────────────────

  /// Short label shown on the pill button for the current fit mode.
  String get _videoFitLabel => switch (_videoFit) {
        BoxFit.contain => 'FIT',
        BoxFit.cover   => 'CROP',
        BoxFit.fill    => 'FILL',
        _              => 'FIT',
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
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_playerReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      );
    }

    return Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _onMouseMove(),
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Video ────────────────────────────────────────────────
                Video(
                  controller: _controller,
                  controls: NoVideoControls,
                  fit: _videoFit,
                  fill: Colors.black,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    visible: false,
                  ),
                ),

                // Double-click empty video area → toggle fullscreen
                // (controls chrome sits above and keeps its own hit targets).
                if (!_isPipMode)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => unawaited(_toggleFullscreen()),
                      child: const SizedBox.expand(),
                    ),
                  ),

                // ── Custom subtitle overlay ──────────────────────────────
                // Auto-scales relative to the rendered window height so
                // the text stays readable in normal mode, fullscreen, AND
                // shrinks proportionally when in PiP (480x270).
                // Custom subtitle overlay — hidden when mpv natively handles
                // ASS/SSA or image-based subtitles (they render on the video frame instead).
                if (!_isNativeSubtitle)
                  StreamBuilder<List<String>>(
                    stream: _player.stream.subtitle,
                    initialData: _player.state.subtitle,
                    builder: (context, snap) {
                      final lines = snap.data ?? [];
                      final text = lines.where((l) => l.trim().isNotEmpty).join('\n');
                      if (text.isEmpty) return const SizedBox.shrink();
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

                // ── Controls Overlay ─────────────────────────────────────
                // Hidden entirely while PiP is active — replaced by the
                // floating revert button below.
                if (!_isPipMode)
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _buildControlsOverlay(),
                    ),
                  ),

                // ── PiP revert button (hover-only) ───────────────────────
                if (_isPipMode) _buildPipRevertOverlay(),

                PlayerStatusOverlay(
                  controller: _statusController,
                  bufferingListenable: _isBufferingNotifier,
                ),
              ],
            ),
          ),
        ),
    );
  }

  /// Floating revert button shown only while desktop PiP is active.
  /// Transparent hover region across the whole window; the button itself
  /// fades in only when the cursor is over the PiP, so the picture stays
  /// clean otherwise. Click exits PiP and restores the window chrome.
  Widget _buildPipRevertOverlay() {
    return MouseRegion(
      opaque: false,
      onEnter: (_) {
        if (mounted && !_pipHover) setState(() => _pipHover = true);
      },
      onExit: (_) {
        if (mounted && _pipHover) setState(() => _pipHover = false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-window drag handle so the user can click+drag the
          // frameless PiP window around the desktop. DragToMoveArea
          // listens for primary-button drags and forwards them to the
          // OS via window_manager.
          const Positioned.fill(
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: _pipHover ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_pipHover,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await PipService.instance.leave();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusMessage: _hasError,
      hasStatusActions: _hasError,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
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
          onBack: () async {
            if (_isFullscreen) {
              await windowManager.setFullScreen(false);
              setState(() => _isFullscreen = false);
            }
            _saveWatchHistory();
            if (mounted) Navigator.of(context).pop(_positionNotifier.value);
          },
          trailing: PlayerTopBarActions(
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
              _onMouseMove();
            },
            showPip: PipService.instance.isSupported,
            pipActive: PipService.instance.isDesktopActive,
            onPip: () async {
              await PipService.instance.toggle();
              if (mounted) setState(() {});
              _onMouseMove();
            },
          ),
        ),
      ),

      if (_displayMovie != null)
        Positioned(
          left: 0,
          top: topBarHeight,
          bottom: 120,
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
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerCenterActionButton(
                    icon: Icons.replay_10_rounded,
                    onPressed: () {
                      final pos =
                          _positionNotifier.value - const Duration(seconds: 10);
                      _player.seek(pos < Duration.zero ? Duration.zero : pos);
                      _onMouseMove();
                    },
                  ),
                  const SizedBox(width: 28),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, playing, _) => PlayerCenterActionButton(
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 80,
                      iconSize: 44,
                      onPressed: () {
                        _player.playOrPause();
                        _onMouseMove();
                      },
                    ),
                  ),
                  const SizedBox(width: 28),
                  PlayerCenterActionButton(
                    icon: Icons.forward_10_rounded,
                    onPressed: () {
                      final dur = _durationNotifier.value;
                      final pos =
                          _positionNotifier.value + const Duration(seconds: 10);
                      _player.seek(pos > dur ? dur : pos);
                      _onMouseMove();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),

      if (_activeSkipLabel != null && !_skipDismissed)
        Positioned(
          bottom: _showNextEpButton ? 155 : 100,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: _performSkip,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.skip_next_rounded,
                        color: Colors.white, size: 20),
                  ]),
                ),
              ),
            ]),
          ),
        ),

      if (_showNextEpButton)
        Positioned(
          bottom: 100,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoadingNextEp ? null : _nextEpisode,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_isLoadingNextEp)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Text(
                      'Next Episode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ]),
              ),
            ),
          ),
        ),

      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_showTorrentStatsOverlay &&
                _torrentStats != null &&
                widget.magnetLink != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  // Lift above Skip Intro / Next Episode when those sit bottom-right.
                  padding: EdgeInsets.only(bottom: 8 + _torrentStatsLift),
                  child: PlayerTorrentStatsCard(stats: _torrentStats!),
                ),
              ),
            ValueListenableBuilder<Duration>(
              valueListenable: _durationNotifier,
              builder: (context, duration, _) =>
                  ValueListenableBuilder<Duration>(
                valueListenable: _positionNotifier,
                builder: (context, position, _) =>
                    ValueListenableBuilder<Duration>(
                  valueListenable: _bufferedNotifier,
                  builder: (context, buffered, _) => SeekBarWithPreview(
                    duration: duration,
                    position: position,
                    bufferedPosition: buffered,
                    captureFrame: _captureSeekPreview,
                    onSeek: (t) {
                      _player.seek(t);
                      _onMouseMove();
                    },
                    onDragStart: () => _hideTimer?.cancel(),
                    onDragEnd: _startHideTimer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, playing, _) => PlayerFlatIconButton(
                      icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      tooltip: playing ? 'Pause' : 'Play',
                      onPressed: () {
                        _player.playOrPause();
                        _onMouseMove();
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  PlayerFlatIconButton(
                    icon: Icons.replay_10_rounded,
                    tooltip: 'Back 10s',
                    onPressed: () {
                      final pos = _positionNotifier.value - const Duration(seconds: 10);
                      _player.seek(pos < Duration.zero ? Duration.zero : pos);
                      _onMouseMove();
                    },
                  ),
                  const SizedBox(width: 2),
                  PlayerFlatIconButton(
                    icon: Icons.forward_10_rounded,
                    tooltip: 'Forward 10s',
                    onPressed: () {
                      final dur = _durationNotifier.value;
                      final pos = _positionNotifier.value + const Duration(seconds: 10);
                      _player.seek(pos > dur ? dur : pos);
                      _onMouseMove();
                    },
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<double>(
                    valueListenable: _volumeNotifier,
                    builder: (context, vol, _) => PlayerVolumeControl(
                      volume: vol,
                      maxVolume: 150,
                      onVolumeChanged: _player.setVolume,
                      onInteraction: _onMouseMove,
                      onDragStart: () => _hideTimer?.cancel(),
                      onDragEnd: _startHideTimer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _positionNotifier,
                    builder: (context, pos, _) =>
                        ValueListenableBuilder<Duration>(
                      valueListenable: _durationNotifier,
                      builder: (context, dur, _) => PlayerTimeRange(
                        position: pos,
                        duration: dur,
                      ),
                    ),
                  ),
                ]),
                Row(children: [
                  if (hasTorrentSources) ...[
                    PlayerFlatIconButton(
                      icon: Icons.link_rounded,
                      tooltip: 'Sources',
                      onPressed: _showTorrentSourcesPanel,
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (hasSources) ...[
                    PlayerFlatIconButton(
                      icon: Icons.dns_outlined,
                      tooltip: 'Sources',
                      onPressedWithContext: (ctx) => _showSourcesMenu(ctx),
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (hasProviders) ...[
                    PlayerFlatIconButton(
                      icon: Icons.cloud_outlined,
                      tooltip: 'Servers',
                      onPressedWithContext: _isSwitchingProvider
                          ? null
                          : (ctx) => _showProviderMenu(ctx),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (hasEpisodePicker) ...[
                    PlayerFlatIconButton(
                      icon: Icons.video_library_outlined,
                      tooltip: 'Episodes',
                      onPressedWithContext: _showEpisodesMenu,
                    ),
                    const SizedBox(width: 2),
                  ],
                  PlayerFlatIconButton(
                    icon: Icons.audiotrack_rounded,
                    tooltip: 'Audio',
                    onPressedWithContext: _showAudioMenu,
                  ),
                  const SizedBox(width: 2),
                  PlayerFlatIconButton(
                    icon: Icons.subtitles_outlined,
                    tooltip: 'Subtitles',
                    onPressedWithContext: _showSubtitlesMenu,
                  ),
                  const SizedBox(width: 2),
                  ValueListenableBuilder<List<HlsQuality>?>(
                    valueListenable: _hlsQualitiesNotifier,
                    builder: (context, qs, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerFlatIconButton(
                          icon: Icons.hd_outlined,
                          tooltip: 'Quality',
                          onPressedWithContext: _showQualityMenu,
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                  ),
                  PlayerFlatIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressedWithContext: _showSettingsMenu,
                  ),
                  const SizedBox(width: 2),
                  PlayerFlatIconButton(
                    icon: _isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: 'Fullscreen',
                    onPressed: _toggleFullscreen,
                  ),
                ]),
              ],
            ),
          ]),
        ),
      ),
    ]);
  }

}

// ─────────────────────────────────────────────────────────────────────────────
//  GLASSY SEEKBAR  — hover tooltip + preview line + smooth thumb
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSeekbar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final void Function(Duration) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _GlassSeekbar({
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  State<_GlassSeekbar> createState() => _GlassSeekbarState();
}

class _GlassSeekbarState extends State<_GlassSeekbar> {
  bool   _isDragging  = false;
  bool   _hovering    = false;
  double _dragFrac    = 0.0; // 0..1 fraction while dragging
  double _hoverFrac   = 0.0; // 0..1 fraction of cursor position
  double _trackWidth  = 0.0; // cached from LayoutBuilder

  // ── Fractions ───────────────────────────────────────────────────────────
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

  // ── Time at hover position ───────────────────────────────────────────────
  Duration get _hoverTime {
    final total = widget.duration.inMilliseconds.toDouble();
    return Duration(milliseconds: (_hoverFrac * total).round());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  double _fracFromLocal(double dx) =>
      (dx / _trackWidth).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (e) => setState(() {
        _hovering  = true;
        _hoverFrac = _fracFromLocal(e.localPosition.dx);
      }),
      onHover: (e) => setState(() {
        _hoverFrac = _fracFromLocal(e.localPosition.dx);
      }),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          widget.onDragStart();
          setState(() {
            _isDragging = true;
            _dragFrac   = _fracFromLocal(d.localPosition.dx);
            _hoverFrac  = _dragFrac;
          });
        },
        onHorizontalDragUpdate: (d) => setState(() {
          _dragFrac  = _fracFromLocal(d.localPosition.dx);
          _hoverFrac = _dragFrac;
        }),
        onHorizontalDragEnd: (_) {
          final total = widget.duration.inMilliseconds.toDouble();
          widget.onSeek(Duration(milliseconds: (_dragFrac * total).round()));
          widget.onDragEnd();
          setState(() => _isDragging = false);
        },
        onTapUp: (d) {
          final total = widget.duration.inMilliseconds.toDouble();
          final frac  = _fracFromLocal(d.localPosition.dx);
          widget.onSeek(Duration(milliseconds: (frac * total).round()));
        },
        // Extra vertical hit area so the thin bar is easy to grab
        child: SizedBox(
          height: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(builder: (context, constraints) {
                _trackWidth = constraints.maxWidth;

                // ── track height animates from 3 → 6 on active ────────────
                final trackH = active ? 6.0 : 3.0;
                // ── thumb radius: 0 → 7 on active, centred on playhead ────
                final thumbR = active ? 7.0 : 0.0;
                // ── playhead + hover pixel positions ─────────────────────
                final playPx  = (_playFrac  * _trackWidth).clamp(0.0, _trackWidth);
                final hoverPx = (_hoverFrac * _trackWidth).clamp(0.0, _trackWidth);

                // ── Tooltip horizontal clamp so it never overflows ─────────
                const tipW     = 72.0;
                final tipLeft  = (hoverPx - tipW / 2).clamp(0.0, _trackWidth - tipW);

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // ── Background track ────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      height: trackH,
                      width: _trackWidth,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(trackH),
                      ),
                    ),

                    // ── Buffered ─────────────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      height: trackH,
                      width: (_bufFrac * _trackWidth).clamp(0.0, _trackWidth),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(trackH),
                      ),
                    ),

                    // ── Played ───────────────────────────────────────────
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

                    // ── Hover preview line (ghosted, thin) ───────────────
                    if (active)
                      Positioned(
                        left: hoverPx - 1,
                        child: AnimatedOpacity(
                          opacity: active ? 0.45 : 0.0,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            width: 1.5,
                            height: trackH + 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),

                    // ── Playhead thumb dot ───────────────────────────────
                    Positioned(
                      left: playPx - thumbR,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        width:  thumbR * 2,
                        height: thumbR * 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: active
                              ? [BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                )]
                              : [],
                        ),
                      ),
                    ),

                    // ── Hover tooltip: glassy pill above cursor ──────────
                    if (active && widget.duration.inMilliseconds > 0)
                      Positioned(
                        top: -38,
                        left: tipLeft,
                        child: AnimatedOpacity(
                          opacity: active ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            width: tipW,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                                  formatDuration(_hoverTime),
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
        ),
      ),
    );
  }
}
