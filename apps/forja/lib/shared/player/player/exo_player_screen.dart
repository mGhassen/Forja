import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/player_source_resolve.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_loading_card.dart';
import 'package:forja/shared/player/controls/player_episode_menu.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/features/settings/widgets/lan_p2p_required_dialog.dart';
import 'package:forja/shared/player/controls/player_server_stream_dialog.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/parental_guide/parental_guide_overlay.dart';
import 'package:forja/shared/player/controls/player_subtitle_dialog.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_touch_seekbar.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';
import 'package:forja/shared/player/exo/exo_atv_surface_fallback.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_menus.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/player/player/post_seek_stall_watchdog.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'exo_player_sources.dart';
part 'exo_player_tracks.dart';

/// Android built-in player using native Media3 ExoPlayer.
class ExoPlayerScreen extends ConsumerStatefulWidget {
  const ExoPlayerScreen({
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
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.hubEpisodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.providers,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.onSaveProgress,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.builtInEngine = BuiltInPlayerEngine.exoPlayer,
    this.onSwitchPlayer,
  });

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
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;
  final List<PlayerHubEpisode>? hubEpisodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerHubEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final Map<String, dynamic>? providers;
  final String? stremioId;
  final String? stremioAddonBaseUrl;
  final Future<void> Function(Duration position, Duration duration)? onSaveProgress;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  ConsumerState<ExoPlayerScreen> createState() => _ExoPlayerScreenState();
}

class _ExoPlayerScreenState extends ConsumerState<ExoPlayerScreen>
    with WidgetsBindingObserver, _ExoPlayerSources, _ExoPlayerTracks {
  static int _nextViewId = 1;

  late final int _viewId = _nextViewId++;
  late final PlayerStatusController _statusController = PlayerStatusController();
  late final ValueNotifier<bool> _isBufferingNotifier =
      ValueNotifier<bool>(false);
  late final ValueNotifier<Map<String, List<StreamSource>>>
      _providerSourcesCache =
      ValueNotifier<Map<String, List<StreamSource>>>(const {});

  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  // VOD always TextureView — SurfaceView HC audio-only black on physical ATV
  // (issue 133). Watchdog stays for IPTV SurfaceView only.
  late final ExoAtvSurfaceFallback _surfaceFallback = ExoAtvSurfaceFallback(
    enabled: false,
    onFallback: _reopenAfterSurfaceFallback,
  );
  late final PostSeekStallWatchdog _postSeekStall = PostSeekStallWatchdog(
    onRemount: _remountCurrentStreamAt,
  );

  bool _disposed = false;
  /// Prefer boot-time [PlatformInfo] so TV key scope / ExcludeFocus work on the
  /// first frame; [_boot] still refreshes via the Exo bridge.
  bool _isTv = PlatformInfo.isAndroidTv;
  bool _exitInProgress = false;
  bool _showControls = true;
  bool _isPlaying = false;
  /// Paused because app left foreground — resume only if set (issue 134).
  bool _pausedByLifecycle = false;
  /// ATV: hide dead MediaCodec texture after veille while still paused (issue 182).
  bool _coverDeadSurface = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _playbackStartedNotified = false;
  bool _opening = false;
  bool _startPositionApplied = false;
  bool _loadingNextEp = false;
  String _episodeLoadingLabel = 'Next episode';
  String _episodeLoadingStatus = 'Loading next episode…';
  bool _episodeLoadingFailed = false;
  double _volume = 100;
  double _rate = 1.0;
  String _resizeMode = 'fit';
  ExoTracksSnapshot _tracks = ExoTracksSnapshot.empty;
  bool _preferredSubtitleApplied = false;
  /// True after Media3 STATE_READY. Selecting text tracks (or soft-reloading
  /// sideloads) before ready races MergingMediaPeriod / ProgressiveMediaPeriod
  /// and can throw IllegalStateException → player pops (issue 132).
  bool _exoReady = false;
  List<Map<String, dynamic>> _externalSubtitles = [];
  final Map<String, String> _externalSubFileCache = {};
  /// Sideloaded Media3 payloads (`url` file://, `lang`, `label`, `sourceUrl`).
  List<Map<String, String>> _sideloadedSubtitles = [];
  String? _selectedExternalSubUrl;
  bool _isFetchingSubs = false;
  double _subtitleSize = 24;
  double _subtitleDelay = 0;
  Color _subtitleColor = Colors.white;
  double _subtitleBgOpacity = 0;
  double _subtitleBottomPadding = 0;
  bool _subtitleBold = false;
  String _subtitleFont = 'Default';

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _nearEndOfEpisode = false;

  late List<_ExoSource> _sources;
  int _sourceIndex = 0;
  String? _currentProvider;
  String? _currentUrl;
  String? _activeMagnet;
  String? _catalogSourceKind;
  String? _catalogAddonBaseUrl;
  List<StreamSource>? _currentSources;
  final Map<String, int> _providerLoadGens = {};
  int _fallbackGen = 0;
  final FocusNode _playFocus = FocusNode(debugLabel: 'exo-player-play');
  final FocusNode _rewindFocus = FocusNode(debugLabel: 'exo-player-rewind');
  final FocusNode _forwardFocus = FocusNode(debugLabel: 'exo-player-forward');
  final FocusNode _transportSourcesFocus =
      FocusNode(debugLabel: 'exo-player-transport-sources');
  final FocusNode _transportStreamFocus =
      FocusNode(debugLabel: 'exo-player-transport-stream');
  final FocusNode _transportEpisodesFocus =
      FocusNode(debugLabel: 'exo-player-transport-episodes');
  final FocusNode _transportAudioFocus =
      FocusNode(debugLabel: 'exo-player-transport-audio');
  final FocusNode _transportSubsFocus =
      FocusNode(debugLabel: 'exo-player-transport-subs');
  final FocusNode _transportQualityFocus =
      FocusNode(debugLabel: 'exo-player-transport-quality');
  final FocusNode _transportSettingsFocus =
      FocusNode(debugLabel: 'exo-player-transport-settings');
  final FocusNode _backFocus = FocusNode(debugLabel: 'exo-player-back');
  final FocusNode _seekFocus = FocusNode(debugLabel: 'exo-player-seek');
  final FocusNode _playerMenuFocus = FocusNode(debugLabel: 'exo-player-menu');
  final FocusNode _retryFocus = FocusNode(debugLabel: 'exo-player-retry');
  final FocusNode _streamActionFocus =
      FocusNode(debugLabel: 'exo-player-stream-action');
  final FocusNode _tvKeyFocus = FocusNode(debugLabel: 'exo-player-tv-keys');
  /// First TV Back hid chrome (or armed while hidden) — next Back exits.
  bool _tvBackExitArmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    PlayerBackExitGate.setTryFocusBack(() {
      if (!mounted || _disposed) return false;
      return PlayerBackExitGate.consumeChromeOrArmExit(
        chromeVisible: _showControls,
        armed: _tvBackExitArmed,
        hideChrome: () {
          _hideTimer?.cancel();
          setState(() => _showControls = false);
        },
        setArmed: (v) => _tvBackExitArmed = v,
      );
    });
    _sources = [];
    _activeMagnet = widget.magnetLink;
    _catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    _catalogSourceKind = _initialCatalogSourceKind();
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ForjaToast.info(
          'Separate audio track not supported in ExoPlayer - use MediaKit in Settings.',
        );
      });
    }
    unawaited(_boot());
    unawaited(_loadSubtitlePrefs());
  }

  Future<List<_ExoSource>> _buildRankedSources() async {
    List<StreamSource> raw;
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      raw = await PlaybackSelection.rankAndDedupe(
        sources: widget.sources!,
        providerId: widget.activeProvider ?? '',
      );
    } else {
      raw = [
        StreamSource(
          url: widget.mediaPath,
          title: widget.title,
          type: 'video',
          headers: widget.headers,
        ),
      ];
    }
    return raw
        .map(
          (s) => _ExoSource(
            url: s.url,
            title: s.title,
            headers: s.headers ?? widget.headers,
          ),
        )
        .toList();
  }

  Future<void> _boot() async {
    // Wait for any MediaKit teardown from a Player-menu engine swap so Exo
    // does not attach over a half-dead mediacodec_embed surface (issue 129).
    // Cap on Android — full stop+dispose can exceed the ATV ANR window (128).
    await MpvExclusiveSession.instance.prepareForVideoPlayer(
      timeout: Platform.isAndroid
          ? const Duration(milliseconds: 1200)
          : const Duration(seconds: 5),
    );
    if (!mounted || _disposed) return;
    final wasTv = _isTv;
    _isTv = await ExoPlayerBridge.isTelevision();
    if (mounted && _isTv != wasTv) setState(() {});
    if (_isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _claimPlayFocus());
    }
    _sources = await _buildRankedSources();
    _seedSourceSession(_sources);
    if (mounted) setState(() {});
    _eventSub = ExoPlayerBridge.eventsFor(_viewId).listen(_onNativeEvent);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _disposed) return;
    await _openCurrentSource();
    unawaited(_fetchSubtitles());

    _progressSaveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_disposed && _isPlaying) unawaited(_saveProgress());
    });
  }

  Future<void> _reopenAfterSurfaceFallback() async {
    if (_disposed || !mounted || _sources.isEmpty) return;
    final pos = _position;
    // Let ValueListenableBuilder remount TextureView PlatformView first.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || !mounted) return;
    final source = _sources[_sourceIndex];
    final caps = exoVodCapsForMaxPlaybackHeight(
      await SettingsService().getMaxPlaybackHeight(),
    );
    final subs = _sideloadedSubtitles
        .map(
          (s) => {
            'url': s['url']!,
            'lang': s['lang'] ?? 'und',
            'label': s['label'] ?? s['lang'] ?? 'und',
          },
        )
        .toList();
    try {
      await ExoPlayerBridge.stop(_viewId);
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: source.url,
        headers: source.headers,
        startPosition: pos,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
      );
      await ExoPlayerBridge.setVolume(_viewId, _volume / 100.0);
      if (_rate != 1.0) {
        await ExoPlayerBridge.setRate(_viewId, _rate);
      }
      await ExoPlayerBridge.setResizeMode(_viewId, _resizeMode);
      await _applySubtitleStyle();
    } catch (e) {
      debugPrint('[ExoPlayer] surface fallback reopen failed: $e');
    }
  }

  Future<void> _openCurrentSource() async {
    if (_opening || _disposed) return;
    _opening = true;
    _preferredSubtitleApplied = false;
    _exoReady = false;
    _selectedExternalSubUrl = null;
    _surfaceFallback.resetForNewOpen();
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    final source = _sources[_sourceIndex];
    _statusController.upsert(
      'source-$_sourceIndex',
      source.title,
      kind: StatusRouletteKind.loading,
    );
    debugPrint(
      '[ExoPlayer] Trying source ${_sourceIndex + 1}/${_sources.length}: ${source.title}',
    );
    final rawSubs = (widget.externalSubtitles ?? [])
        .where((s) => (s['url'] ?? '').toString().isNotEmpty)
        .toList();
    final prepared = await _prepareOpenSubtitles(rawSubs);
    _sideloadedSubtitles = prepared;
    if (mounted) {
      // Keep Wyzie / online rows across failover reopen — only refresh provider.
      final providerUrls = {
        for (final s in rawSubs) (s['url'] ?? '').toString(),
      }..remove('');
      final preservedOnline = [
        for (final s in _externalSubtitles)
          if (!providerUrls.contains((s['url'] ?? '').toString())) s,
      ];
      setState(
        () => _externalSubtitles = [...rawSubs, ...preservedOnline],
      );
    }
    final subs = prepared
        .map(
          (s) => {
            'url': s['url']!,
            'lang': s['lang'] ?? 'und',
            'label': s['label'] ?? s['lang'] ?? 'und',
          },
        )
        .toList();
    try {
      final start = !_startPositionApplied
          ? (widget.startPosition ?? Duration.zero)
          : Duration.zero;
      _startPositionApplied = true;
      final maxH = await SettingsService().getMaxPlaybackHeight();
      final caps = exoVodCapsForMaxPlaybackHeight(maxH);
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: source.url,
        headers: source.headers,
        startPosition: start,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
      );
      await ExoPlayerBridge.setVolume(_viewId, _volume / 100.0);
      if (_rate != 1.0) {
        await ExoPlayerBridge.setRate(_viewId, _rate);
      }
      // Always re-apply fit after open — engine switch / PlatformView remount
      // can leave SurfaceView painted zoomed until resize mode is set again.
      await ExoPlayerBridge.setResizeMode(_viewId, _resizeMode);
      await _applySubtitleStyle();
    } catch (e) {
      debugPrint('[ExoPlayer] open failed: $e');
      await _failCurrentSource('Failed to open stream');
    } finally {
      _opening = false;
    }
  }

  Future<void> _failCurrentSource(String message) async {
    if (_sourceIndex < _sources.length) {
      PlaybackSelection.recordFailedUrl(_sources[_sourceIndex].url);
      _statusController.upsert(
        'source-$_sourceIndex',
        _sources[_sourceIndex].title,
        kind: StatusRouletteKind.failed,
      );
    }
    if (!_playbackStartedNotified && _sourceIndex + 1 < _sources.length) {
      _sourceIndex++;
      await ExoPlayerBridge.stop(_viewId);
      await _openCurrentSource();
      return;
    }
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = _playbackStartedNotified
          ? 'Playback stopped. Tap Retry to reload this server.'
          : message;
      _showControls = true;
    });
    if (!_playbackStartedNotified) {
      widget.onAllSourcesExhausted?.call();
    }
  }

  void _onNativeEvent(Map<dynamic, dynamic> event) {
    if (_disposed) return;
    if (_surfaceFallback.handleNativeEvent(event)) {
      // Surface attach failure — TextureView remount in progress; do not
      // hop to the next source.
      return;
    }
    final type = event['type']?.toString() ?? '';
    switch (type) {
      case 'ready':
        _isBufferingNotifier.value = false;
        _statusController.complete();
        _exoReady = true;
        if (!_playbackStartedNotified) {
          setState(() => _playbackStartedNotified = true);
          widget.onPlaybackStarted?.call();
        }
        // Apply preferred text track only after READY — earlier selectTrack
        // races MergingMediaPeriod when sideloads are present (issue 132).
        unawaited(_maybeApplyPreferredSubtitle());
        if (_selectedExternalSubUrl != null) {
          unawaited(_selectSideloadedMatchingSelection());
        }
        break;
      case 'playing':
        setState(() {
          _isPlaying = event['value'] == true;
        });
        _postSeekStall.onPlaying(_isPlaying);
        if (_isPlaying) {
          _clearDeadSurfaceCover();
          _isBufferingNotifier.value = false;
          _startHideTimer();
          _scrobbleStart();
        } else {
          unawaited(_saveProgress());
          _scrobblePause();
        }
        break;
      case 'buffering':
        final buffering = event['value'] == true;
        _isBufferingNotifier.value = buffering;
        _postSeekStall.onBuffering(buffering);
        break;
      case 'progress':
        final posMs = (event['position'] as num?)?.toInt() ?? 0;
        final durMs = (event['duration'] as num?)?.toInt() ?? 0;
        final bufMs = (event['buffered'] as num?)?.toInt() ?? 0;
        final pos = Duration(milliseconds: posMs);
        final dur = durMs > 0 ? Duration(milliseconds: durMs) : _duration;
        final nearEnd = widget.hasNextEpisode &&
            widget.onNextEpisode != null &&
            isNearEndOfEpisode(pos, dur);
        // The controls overlay is always built (hidden via AnimatedOpacity, not
        // removed), so an unconditional setState here re-laid-out the whole
        // player tree twice a second over the platform view (issue 151).
        final needsRepaint = _showControls || nearEnd != _nearEndOfEpisode;
        _position = pos;
        _postSeekStall.onPosition(pos);
        if (durMs > 0) _duration = Duration(milliseconds: durMs);
        _buffered = Duration(milliseconds: bufMs);
        _nearEndOfEpisode = nearEnd;
        if (needsRepaint) setState(() {});
        break;
      case 'ended':
        setState(() {
          _isPlaying = false;
          _showControls = true;
        });
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'Playback error';
        if (_opening) {
          debugPrint('[ExoPlayer] error during open/switch (ignored): $msg');
          return;
        }
        if (isVideoDecoderError(msg)) {
          debugPrint('[ExoPlayer] decoder error: $msg');
        }
        unawaited(_failCurrentSource(msg));
        break;
      case 'tracksChanged':
        if (!mounted) return;
        setState(() {
          _tracks = ExoTracksSnapshot.fromMap(event);
          _rate = _tracks.rate;
        });
        // Defer auto-select until READY (see ready handler). Re-apply only if
        // we have not locked a preference yet and playback is already ready.
        if (_exoReady && !_preferredSubtitleApplied) {
          unawaited(_maybeApplyPreferredSubtitle());
        }
        if (_exoReady && _selectedExternalSubUrl != null) {
          unawaited(_selectSideloadedMatchingSelection());
        }
        break;
      case 'renderedFirstFrame':
        break;
    }
  }

  void _scrobbleStart() {
    final movie = widget.movie;
    if (movie == null) return;
    TraktService().scrobbleStart(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      progressPercent: _scrobblePercent,
    );
    SimklService().scrobbleStart(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
  }

  void _scrobblePause() {
    final movie = widget.movie;
    if (movie == null) return;
    TraktService().scrobblePause(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      progressPercent: _scrobblePercent,
    );
    SimklService().scrobblePause(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
  }

  void _scrobbleStop() {
    final movie = widget.movie;
    if (movie == null) return;
    TraktService().scrobbleStop(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      progressPercent: _scrobblePercent,
    );
    SimklService().scrobbleStop(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
  }

  double get _scrobblePercent {
    final dur = _duration.inMilliseconds;
    if (dur <= 0) return 0.0;
    return _position.inMilliseconds / dur * 100;
  }

  Future<void> _saveProgress() async {
    if (widget.onSaveProgress == null || _duration.inMilliseconds <= 0) return;
    await widget.onSaveProgress!(_position, _duration);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_saveProgress());
      _pauseForAppBackground();
    } else if (state == AppLifecycleState.inactive) {
      if (!_disposed &&
          !SettingsService.keepsPlayingInBackground &&
          _isPlaying) {
        _pausedByLifecycle = true;
      }
      unawaited(_saveProgress());
    } else if (state == AppLifecycleState.resumed) {
      _armDeadSurfaceCoverIfNeeded();
      _resumeAfterAppBackground();
    }
  }

  void _pauseForAppBackground() {
    if (_disposed) return;
    if (SettingsService.keepsPlayingInBackground) return;
    if (_isPlaying) {
      _pausedByLifecycle = true;
      unawaited(ExoPlayerBridge.pause(_viewId));
    }
  }

  void _resumeAfterAppBackground() {
    if (_disposed || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    unawaited(ExoPlayerBridge.play(_viewId));
  }

  /// Veille kills the TextureView; paused decode leaves green YUV. Cover until play.
  void _armDeadSurfaceCoverIfNeeded() {
    if (_disposed || !_isTv || _pausedByLifecycle || _isPlaying) return;
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

  Future<void> _seekRelative(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration.inMilliseconds > 0 && target > _duration)
            ? _duration
            : target;
    await _seekTo(clamped);
  }

  Future<void> _seekTo(Duration target) async {
    await ExoPlayerBridge.seekTo(_viewId, target);
    _position = target;
    _armPostSeekStall(target);
    _startHideTimer();
  }

  void _armPostSeekStall(Duration target) {
    final url = _currentUrl ??
        (_sources.isNotEmpty ? _sources[_sourceIndex].url : null);
    _postSeekStall.enabled = url != null &&
        !isLocalTorrentStreamUrl(url) &&
        !isLocalLoopbackPlayUrl(url);
    _postSeekStall.noteSeek(target);
  }

  Future<bool> _remountCurrentStreamAt(Duration target) async {
    if (_disposed || !mounted || _opening) return false;
    if (_sources.isEmpty) return false;
    final source = _sources[_sourceIndex];
    if (isLocalTorrentStreamUrl(source.url) ||
        isLocalLoopbackPlayUrl(source.url)) {
      return false;
    }
    _opening = true;
    _exoReady = false;
    _statusController.upsert(
      'post-seek-remount',
      'Reconnecting…',
      kind: StatusRouletteKind.loading,
    );
    try {
      final maxH = await SettingsService().getMaxPlaybackHeight();
      final caps = exoVodCapsForMaxPlaybackHeight(maxH);
      final subs = _sideloadedSubtitles
          .map(
            (s) => {
              'url': s['url']!,
              'lang': s['lang'] ?? 'und',
              'label': s['label'] ?? s['lang'] ?? 'und',
            },
          )
          .toList();
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: source.url,
        headers: source.headers,
        startPosition: target,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
      );
      await ExoPlayerBridge.setVolume(_viewId, _volume / 100.0);
      if (_rate != 1.0) {
        await ExoPlayerBridge.setRate(_viewId, _rate);
      }
      await ExoPlayerBridge.setResizeMode(_viewId, _resizeMode);
      await _applySubtitleStyle();
      if (!_disposed && mounted) {
        _position = target;
        _statusController.complete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ExoPlayer] Post-seek remount failed: $e');
      if (!_disposed && mounted) {
        _statusController.upsert(
          'post-seek-remount',
          'Reconnect failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1500),
        );
      }
      return false;
    } finally {
      _opening = false;
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      unawaited(ExoPlayerBridge.pause(_viewId));
    } else {
      unawaited(ExoPlayerBridge.play(_viewId));
    }
    // Do not force chrome — Space / media keys pause with chrome hidden.
    if (_showControls) _startHideTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
      if (_isTv) _claimPlayFocus();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _claimPlayFocus() {
    if (!_isTv) return;
    _tvBackExitArmed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playFocus.canRequestFocus) return;
      // Menu/panel owns the remote - don't yank focus back to Play.
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _playFocus.requestFocus();
    });
  }

  void _claimBackFocus() {
    if (!_isTv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_backFocus.canRequestFocus) return;
      if (playerChromeOverlayBlocksFocusClaim()) return;
      _backFocus.requestFocus();
    });
  }

  void _focusDownFromTopBar() {
    if (!_isTv) return;
    _tvBackExitArmed = false;
    if (_seekFocus.canRequestFocus) {
      _seekFocus.requestFocus();
      return;
    }
    _claimPlayFocus();
  }

  void _focusDownFromSeekbar() => _claimPlayFocus();

  void _focusLeftFromSeekbar() => _claimPlayFocus();

  void _focusRightFromSeekbar() => _focusFirstRightTransport();

  void _focusUpFromSeekbar() {
    if (_backFocus.canRequestFocus) {
      _backFocus.requestFocus();
    }
  }

  VoidCallback? _backOnRightEdge() {
    if (!_isTv) return null;
    if (_hasError) return () => _retryFocus.requestFocus();
    if (widget.onSwitchPlayer != null) {
      return () => _playerMenuFocus.requestFocus();
    }
    return null;
  }

  void _focusFirstRightTransport() {
    final nodes = <FocusNode>[
      if (_usesCatalogSourcesPanel) _transportSourcesFocus,
      if (_hasStreamPicker) _transportStreamFocus,
      if (_hasEpisodePicker) _transportEpisodesFocus,
      _transportAudioFocus,
    ];
    for (final node in nodes) {
      if (node.canRequestFocus) {
        node.requestFocus();
        return;
      }
    }
  }

  void _focusLeftOfRightTransport() {
    _forwardFocus.requestFocus();
  }

  bool _fallbackAborted(int gen) =>
      _disposed || !mounted || gen != _fallbackGen;

  void _beginEpisodeLoading({
    required String label,
    String status = 'Loading episode info…',
  }) {
    if (!mounted) return;
    setState(() {
      _loadingNextEp = true;
      _episodeLoadingLabel = label;
      _episodeLoadingStatus = status;
      _episodeLoadingFailed = false;
    });
  }

  void _setEpisodeLoadingStatus(String status, {bool failed = false}) {
    if (!mounted || !_loadingNextEp) return;
    setState(() {
      _episodeLoadingStatus = status;
      _episodeLoadingFailed = failed;
    });
  }

  Future<void> _failEpisodeLoading(String status) async {
    _setEpisodeLoadingStatus(status, failed: true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _loadingNextEp = false;
      _episodeLoadingFailed = false;
    });
  }

  void _focusSeekFromTransport() {
    if (_seekFocus.canRequestFocus) {
      _seekFocus.requestFocus();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isPlaying) return;
    if (playerChromeOverlayBlocksSeek()) return;
    final hideAfter =
        _isTv ? const Duration(seconds: 10) : const Duration(seconds: 4);
    _hideTimer = Timer(hideAfter, () {
      if (!mounted || _disposed || !_isPlaying) return;
      if (playerChromeOverlayBlocksSeek()) {
        _startHideTimer();
        return;
      }
      // D-pad still on chrome — do not strip ExcludeFocus mid-traversal
      // (leaves focus on Play with no ←/→ neighbors until Select).
      if (_isTv && playerTvChromeHasFocus(_tvKeyFocus)) {
        _startHideTimer();
        return;
      }
      setState(() => _showControls = false);
    });
  }

  Future<void> _setVolume(double volume) async {
    final v = volume.clamp(0.0, 150.0);
    setState(() => _volume = v);
    await ExoPlayerBridge.setVolume(_viewId, v / 100.0);
    _startHideTimer();
  }

  Future<ExoTracksSnapshot> _refreshTracks() async {
    try {
      final snap = await ExoPlayerBridge.getTracks(_viewId);
      if (mounted) {
        setState(() {
          _tracks = snap;
          _rate = snap.rate;
        });
      }
      return snap;
    } catch (_) {
      return _tracks;
    }
  }

  Future<void> _showEpisodesMenu(BuildContext anchorContext) async {
    if (widget.hubEpisodes != null &&
        widget.hubEpisodes!.isNotEmpty &&
        widget.onHubEpisodeSelected != null) {
      PlayerPopupPanel.dismiss();
      await PlayerHubEpisodePanel.show(
        context: context,
        episodes: widget.hubEpisodes!,
        currentEpisode: widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: (ep) async {
          setState(() {
            _loadingNextEp = true;
            _episodeLoadingLabel = 'Episode ${ep.displayNumber}';
            _episodeLoadingStatus = 'Loading episode info…';
            _episodeLoadingFailed = false;
          });
          try {
            await widget.onHubEpisodeSelected!(ep);
            if (mounted) {
              setState(() {
                _loadingNextEp = false;
                _episodeLoadingFailed = false;
              });
            }
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _episodeLoadingStatus = 'Could not load this episode';
              _episodeLoadingFailed = true;
            });
            await Future<void>.delayed(const Duration(seconds: 2));
            if (mounted) {
              setState(() {
                _loadingNextEp = false;
                _episodeLoadingFailed = false;
              });
            }
          }
        },
        fallbackBackdropPath: widget.movie?.backdropPath,
        fallbackPosterPath: widget.movie?.posterPath,
      );
      // TV: opener (Episodes) restored by playerMenuRestoreReturnFocus.
      return;
    }
    final movie = widget.movie;
    if (movie == null || movie.mediaType != 'tv') return;
    await PlayerEpisodeMenu.show(
      context,
      movie: movie,
      currentSeason: widget.selectedSeason ?? 1,
      currentEpisode: widget.selectedEpisode ?? 1,
      onEpisodeSelected: _switchToEpisode,
      anchorContext: anchorContext,
    );
    // TV: opener restored by playerMenuRestoreReturnFocus.
  }

  Future<void> _switchToEpisode(int season, int episode) async {
    if (widget.movie == null) return;
    if (season == widget.selectedSeason && episode == widget.selectedEpisode) {
      return;
    }
    setState(() {
      _loadingNextEp = true;
      _episodeLoadingLabel = 'Season $season · Episode $episode';
      _episodeLoadingStatus = 'Loading episode info…';
      _episodeLoadingFailed = false;
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      await _saveProgress();
      _scrobbleStop();
      setState(() => _episodeLoadingStatus = 'Checking sources…');

      final chain = episodeProviderChain(
        providers: widget.providers,
        activeProvider: widget.activeProvider,
        currentProvider: widget.activeProvider,
        magnetLink: widget.magnetLink,
      );
      if (chain.isEmpty) {
        throw Exception('No provider available for S${season}E$episode');
      }

      EpisodeSwitchResult? resolved;
      for (final key in chain) {
        if (!mounted) return;
        setState(() {
          _episodeLoadingStatus = key == 'torrent'
              ? 'Resolving torrent…'
              : key == 'stremio_direct'
                  ? 'Checking Stremio…'
                  : 'Checking sources…';
        });
        resolved = await resolveEpisodeForProvider(
          providerKey: key,
          movie: widget.movie!,
          season: season,
          episode: episode,
          providers: widget.providers,
          magnetLink: widget.magnetLink,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        );
        if (resolved != null) break;
      }
      if (resolved == null || resolved.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }
      if (!mounted) return;
      setState(() => _episodeLoadingStatus = 'Opening stream…');

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      if (resolved.magnetLink != null && resolved.magnetLink!.isNotEmpty) {
        TorrentStreamService().retainForExternalHandoff = true;
      }
      try {
        await ExoPlayerBridge.stop(_viewId);
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushReplacement(
        AppRouter.slideRoute(
          (_) => PlayerScreen(
            streamUrl: resolved!.streamUrl,
            title: nextTitle,
            headers: catalog ? null : resolved.headers,
            movie: widget.movie,
            selectedSeason: season,
            selectedEpisode: episode,
            magnetLink: resolved.magnetLink,
            fileIndex: resolved.fileIndex,
            activeProvider: resolved.activeProvider,
            stremioId: widget.stremioId,
            stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
            providers: catalog ? null : widget.providers,
            sources: catalog ? null : resolved.sources,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ExoPlayer] episode switch failed: $e');
      if (!mounted) return;
      setState(() {
        _episodeLoadingStatus = 'Could not find a stream for this episode';
        _episodeLoadingFailed = true;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _loadingNextEp = false;
          _episodeLoadingFailed = false;
        });
      }
    }
  }

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    final tracks = await _refreshTracks();
    if (!mounted) return;
    await ExoPlayerMenus.showAudio(
      context: context,
      tracks: tracks,
      anchorContext: anchorContext,
      onSelect: (id) => ExoPlayerBridge.selectTrack(
        _viewId,
        type: 'audio',
        trackId: id,
      ),
    );
    // TV: opener restored by playerMenuRestoreReturnFocus.
  }

  Future<void> _showSubtitlesMenu(BuildContext anchorContext) async {
    final tracks = await _refreshTracks();
    if (!mounted) return;
    await ExoPlayerMenus.showSubtitles(
      context: context,
      tracks: tracks,
      anchorContext: anchorContext,
      externalSubtitles: _externalSubtitles,
      selectedExternalSubUrl: _selectedExternalSubUrl,
      isFetchingSubs: _isFetchingSubs,
      onOff: _turnOffSubtitles,
      onSubtitleSettings: _showSubtitleSettings,
      onLoadFromFile: ({required String path, required String name}) async {
        await _loadOnlineSubtitle({
          'url': Uri.file(path).toString(),
          'language': 'und',
          'lang': 'und',
          'display': name,
        });
      },
      onSelectExternal: (sub) async {
        final settings = SettingsService();
        final resolved = resolvePreferredLanguageDisplayName(
          language: (sub['language'] ?? sub['lang'])?.toString(),
          title: sub['display']?.toString(),
        );
        if (resolved != null) {
          await settings.setPreferredSubtitleLanguage(resolved);
        }
        await _loadOnlineSubtitle(sub);
      },
      onSelectEmbedded: (track) async {
        final settings = SettingsService();
        if (track == null) {
          await _turnOffSubtitles();
          return;
        }
        _selectedExternalSubUrl = null;
        final resolved = resolvePreferredLanguageDisplayName(
          language: track.language,
          title: track.label,
        );
        if (resolved != null) {
          await settings.setPreferredSubtitleLanguage(resolved);
        }
        await ExoPlayerBridge.selectTrack(
          _viewId,
          type: 'text',
          trackId: track.id,
        );
        if (mounted) setState(() {});
      },
    );
    // TV: opener restored by playerMenuRestoreReturnFocus.
  }

  Future<void> _loadSubtitlePrefs() async {
    final prefs = await ref.read(playerSubtitlePrefsProvider(false).future);
    if (!mounted) return;
    setState(() {
      _subtitleSize = prefs.size;
      _subtitleColor = Color(prefs.colorArgb);
      _subtitleBgOpacity = prefs.bgOpacity;
      _subtitleBold = prefs.bold;
      _subtitleBottomPadding = prefs.bottomPadding;
      _subtitleFont = prefs.font;
    });
    await _applySubtitleStyle();
  }

  Future<void> _applySubtitleStyle() async {
    if (_disposed) return;
    try {
      await ExoPlayerBridge.setSubtitleStyle(
        _viewId,
        sizeSp: _subtitleSize,
        textColorArgb: _subtitleColor.toARGB32(),
        backgroundOpacity: _subtitleBgOpacity,
        bottomPaddingPx: _subtitleBottomPadding,
        bold: _subtitleBold,
        font: _subtitleFont,
      );
    } catch (e) {
      debugPrint('[ExoPlayer] setSubtitleStyle failed: $e');
    }
  }

  void _showSubtitleSettings() {
    PlayerSubtitleSettingsDialog.show(
      context,
      initial: PlayerSubtitleSettingsValues(
        size: _subtitleSize,
        delay: _subtitleDelay,
        color: _subtitleColor,
        bgOpacity: _subtitleBgOpacity,
        bottomPadding: _subtitleBottomPadding,
        bold: _subtitleBold,
        font: _subtitleFont,
      ),
      onChanged: (values) {
        setState(() {
          _subtitleSize = values.size;
          _subtitleDelay = values.delay;
          _subtitleColor = values.color;
          _subtitleBgOpacity = values.bgOpacity;
          _subtitleBottomPadding = values.bottomPadding;
          _subtitleBold = values.bold;
          _subtitleFont = values.font;
        });
        unawaited(_applySubtitleStyle());
      },
    );
  }

  Future<void> _maybeApplyPreferredSubtitle() async {
    if (_disposed || _preferredSubtitleApplied) return;
    // Wait for STATE_READY before selectTrack / setSubtitles (issue 132).
    if (!_exoReady) return;
    // Prefer external catalog when Media3 text tracks are still empty.
    if (_tracks.text.isEmpty) {
      await _maybeAutoPickExternalSubtitle();
      return;
    }
    final preferred = await SettingsService().getPreferredSubtitleLanguage();
    if (_disposed || _preferredSubtitleApplied) return;
    if (preferred == 'None' || preferred.isEmpty) return;

    ExoTrackInfo? preferredMatch;
    ExoTrackInfo? englishMatch;
    for (final t in _tracks.text) {
      if (matchesPreferredLanguage(
        preferred,
        language: t.language,
        title: t.label,
      )) {
        preferredMatch ??= t;
      } else if (preferred != 'English' &&
          matchesPreferredLanguage(
            'English',
            language: t.language,
            title: t.label,
          )) {
        englishMatch ??= t;
      }
    }
    final match = preferredMatch ?? englishMatch;
    if (match == null) {
      await _maybeAutoPickExternalSubtitle();
      return;
    }

    final onPreferred = preferredMatch != null &&
        preferredMatch.selected &&
        !_tracks.textOff;
    if (onPreferred) {
      _preferredSubtitleApplied = true;
      return;
    }
    // Already on English fallback with preferred still missing — stop.
    if (preferredMatch == null &&
        englishMatch != null &&
        englishMatch.selected &&
        !_tracks.textOff) {
      _preferredSubtitleApplied = true;
      return;
    }

    // Lock before await so concurrent tracksChanged cannot re-enter selectTrack.
    _preferredSubtitleApplied = true;
    await ExoPlayerBridge.selectTrack(
      _viewId,
      type: 'text',
      trackId: match.id,
    );
    debugPrint(
      '[ExoPlayer] auto subtitle → ${match.label.isNotEmpty ? match.label : match.language}',
    );
  }

  Future<void> _showQualityMenu(BuildContext anchorContext) async {
    final tracks = await _refreshTracks();
    if (!mounted) return;
    await ExoPlayerMenus.showQuality(
      context: context,
      tracks: tracks,
      anchorContext: anchorContext,
      onSelect: (id) => ExoPlayerBridge.selectTrack(
        _viewId,
        type: 'video',
        trackId: id,
      ),
    );
    // TV: opener restored by playerMenuRestoreReturnFocus.
  }

  void _showSettingsMenu(BuildContext anchorContext) {
    ExoPlayerMenus.showSettings(
      context: context,
      anchorContext: anchorContext,
      rateOf: () => _rate,
      resizeModeOf: () => _resizeMode,
      onRate: (rate) async {
        await ExoPlayerBridge.setRate(_viewId, rate);
        if (mounted) setState(() => _rate = rate);
      },
      onResize: (mode) async {
        await ExoPlayerBridge.setResizeMode(_viewId, mode);
        if (mounted) setState(() => _resizeMode = mode);
      },
    );
  }

  Future<void> _exit() async {
    if (_exitInProgress || _disposed) return;
    if (ShellTvFocusCoordinator.consumeOverlayBack()) {
      // Opener chrome button is refocused by playerMenuRestoreReturnFocus.
      return;
    }
    _exitInProgress = true;
    // Capture before awaits - unmount must not skip loading dismiss (I101).
    final nav = Navigator.of(context, rootNavigator: true);
    await _saveProgress();
    _scrobbleStop();
    // Stop Exo before pop - dispose alone is unawaited and can leave audio
    // after the route is gone (issue 059).
    try {
      await ExoPlayerBridge.stop(_viewId);
    } catch (_) {}
    _popPlayerRoute(nav: nav);
  }

  void _popPlayerRoute({NavigatorState? nav}) {
    final navigator =
        nav ??
        (mounted ? Navigator.of(context, rootNavigator: true) : null);
    // Strip loading under the player first — pop-then-dismiss paints resolve UI.
    dismissActiveLoadingOverlayRoute(navigator);
    if (navigator != null && navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _showPlayerMenu(BuildContext anchorContext) async {
    final handler = widget.onSwitchPlayer;
    if (handler == null) return;
    await _saveProgress();
    if (!mounted || !anchorContext.mounted) return;
    PlayerAppMenu.show(
      context,
      anchorContext: anchorContext,
      centered: _isTv,
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) async {
        await handler(
          _position,
          builtInEngine: builtInEngine,
          externalPlayer: externalPlayer,
          streamUrl: _currentUrl ??
              (_sources.isNotEmpty ? _sources[_sourceIndex].url : null),
          headers: _sources.isNotEmpty
              ? _sources[_sourceIndex].headers
              : widget.headers,
          activeProvider: _currentProvider ?? widget.activeProvider,
          sources: _currentSources ?? widget.sources,
        );
      },
    );
    _startHideTimer();
  }

  Future<void> _nextEpisode() async {
    final handler = widget.onNextEpisode;
    if (handler == null || _loadingNextEp) return;
    setState(() {
      _loadingNextEp = true;
      _episodeLoadingLabel = 'Next episode';
      _episodeLoadingStatus = 'Loading next episode…';
      _episodeLoadingFailed = false;
    });
    try {
      await handler();
      if (mounted) {
        setState(() {
          _loadingNextEp = false;
          _episodeLoadingFailed = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _episodeLoadingStatus = 'Could not load the next episode';
        _episodeLoadingFailed = true;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _loadingNextEp = false;
          _episodeLoadingFailed = false;
        });
      }
    }
  }

  String? get _episodeLine {
    if (widget.hubEpisodeNumber != null) {
      return 'Episode ${widget.hubEpisodeNumber}';
    }
    if (widget.selectedEpisode != null && widget.selectedSeason != null) {
      return 'S${widget.selectedSeason} E${widget.selectedEpisode}';
    }
    return null;
  }

  String _streamPickerLabel() => _activeServerLabel();

  bool get _hasStreamPicker => _hasStreamPickerSources;

  bool get _hasEpisodePicker {
    final isTv = widget.movie?.mediaType == 'tv';
    return (isTv && widget.movie != null) ||
        (widget.hubEpisodes != null && widget.hubEpisodes!.isNotEmpty);
  }

  @override
  void dispose() {
    _disposed = true;
    PlayerBackExitGate.setTryFocusBack(null);
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    PlayerServerStreamDialog.dismiss();
    PlayerSubtitleDialog.dismiss();
    PlayerSubtitleSettingsDialog.dismissIfShowing();
    LanP2pRequiredDialog.dismissIfShowing();
    _playFocus.dispose();
    _rewindFocus.dispose();
    _forwardFocus.dispose();
    _transportSourcesFocus.dispose();
    _transportStreamFocus.dispose();
    _transportEpisodesFocus.dispose();
    _transportAudioFocus.dispose();
    _transportSubsFocus.dispose();
    _transportQualityFocus.dispose();
    _transportSettingsFocus.dispose();
    _backFocus.dispose();
    _seekFocus.dispose();
    _playerMenuFocus.dispose();
    _retryFocus.dispose();
    _streamActionFocus.dispose();
    _tvKeyFocus.dispose();
    _statusController.dispose();
    _isBufferingNotifier.dispose();
    _providerSourcesCache.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _postSeekStall.dispose();
    _surfaceFallback.dispose();
    _eventSub?.cancel();
    unawaited(_teardownExoPlayer());
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _teardownExoPlayer() async {
    try {
      await ExoPlayerBridge.stop(_viewId);
    } catch (_) {}
    try {
      await ExoPlayerBridge.dispose(_viewId);
    } catch (_) {}
  }

  Widget _buildControlsOverlay() {
    const btnSize = 38.0;
    const iconSz = 20.0;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final tvFocus = _isTv;
    final hasTorrentSources = _usesCatalogSourcesPanel;
    final topBarHeight = PlayerTopBar.totalHeight(
      context,
      hasStatusActions: _hasError,
    );
    final showCenterActions = !playerStatusOverlayVisible(
      _statusController,
      _isBufferingNotifier.value,
    );

    final overlay = Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: PlayerOverlayGradient(isTop: true),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: PlayerOverlayGradient(isTop: false),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: tvFocus
              ? FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: PlayerTopBar(
                    title: widget.title,
                    season: widget.hubEpisodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.hubEpisodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeLine: _episodeLine,
                    statusActions: _hasError
                        ? PlayerTopStatusActions(
                            onRetry: () {
                              setState(() {
                                _hasError = false;
                                _errorMessage = '';
                              });
                              unawaited(_openCurrentSource());
                            },
                            onStream: _hasStreamPicker
                                ? () => unawaited(_showSourcesDialog(context))
                                : null,
                            tvFocusable: true,
                            retryFocusNode: _retryFocus,
                            streamFocusNode: _streamActionFocus,
                            onRetryLeftEdge: () => _backFocus.requestFocus(),
                            onRetryRightEdge: _hasStreamPicker ||
                                    widget.onSwitchPlayer != null
                                ? () {
                                    if (_hasStreamPicker) {
                                      _streamActionFocus.requestFocus();
                                    } else {
                                      _playerMenuFocus.requestFocus();
                                    }
                                  }
                                : null,
                            onStreamLeftEdge: () => _retryFocus.requestFocus(),
                            onStreamRightEdge: widget.onSwitchPlayer != null
                                ? () => _playerMenuFocus.requestFocus()
                                : null,
                          )
                        : null,
                    onBack: () => unawaited(_exit()),
                    tvFocusable: true,
                    backFocusNode: _backFocus,
                    backOnRightEdge: _backOnRightEdge(),
                    backOnDownEdge: _focusDownFromTopBar,
                    trailing: PlayerTopBarActions(
                      tvFocusable: true,
                      showPlayer: widget.onSwitchPlayer != null,
                      playerFocusNode: _playerMenuFocus,
                      playerOnLeftEdge: _hasError
                          ? () {
                              if (_hasStreamPicker) {
                                _streamActionFocus.requestFocus();
                              } else {
                                _retryFocus.requestFocus();
                              }
                            }
                          : null,
                      onPlayer: widget.onSwitchPlayer != null
                          ? (anchorContext) =>
                              unawaited(_showPlayerMenu(anchorContext))
                          : null,
                    ),
                  ),
                )
              : PlayerTopBar(
                  title: widget.title,
                  season: widget.hubEpisodes != null
                      ? null
                      : widget.selectedSeason,
                  episode: widget.hubEpisodes != null
                      ? null
                      : widget.selectedEpisode,
                  episodeLine: _episodeLine,
                  statusActions: _hasError
                      ? PlayerTopStatusActions(
                          onRetry: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                            });
                            unawaited(_openCurrentSource());
                          },
                          onStream: _hasStreamPicker
                              ? () => unawaited(_showSourcesDialog(context))
                              : null,
                        )
                      : null,
                  onBack: () => unawaited(_exit()),
                  tvFocusable: tvFocus,
                  trailing: PlayerTopBarActions(
                    tvFocusable: tvFocus,
                    showPlayer: widget.onSwitchPlayer != null,
                    onPlayer: widget.onSwitchPlayer != null
                        ? (anchorContext) =>
                            unawaited(_showPlayerMenu(anchorContext))
                        : null,
                  ),
                ),
        ),
        if (widget.movie != null)
          Positioned(
            left: 0,
            top: topBarHeight,
            bottom: 110,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isBufferingNotifier,
              builder: (context, buffering, _) {
                final showHero = !_isPlaying || buffering;
                return AnimatedOpacity(
                  opacity: showHero ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !showHero,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PlayerPausedHero(
                        movie: widget.movie!,
                        season: widget.hubEpisodes != null
                            ? null
                            : widget.selectedSeason,
                        episode: widget.hubEpisodes != null
                            ? null
                            : widget.selectedEpisode,
                        episodeLine: _episodeLine,
                        episodeOverview: widget.episodeOverview,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (showCenterActions && !tvFocus)
          Positioned.fill(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: Icons.replay_10_rounded,
                    onPressed: () =>
                        unawaited(_seekRelative(const Duration(seconds: -10))),
                  ),
                  const SizedBox(width: 24),
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 80,
                    iconSize: 44,
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 24),
                  PlayerCenterActionButton(
                    tvFocusable: tvFocus,
                    icon: Icons.forward_10_rounded,
                    onPressed: () =>
                        unawaited(_seekRelative(const Duration(seconds: 10))),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  tvFocus
                      ? FocusTraversalOrder(
                          order: const NumericFocusOrder(2),
                          child: CustomSeekbar(
                            duration: _duration,
                            position: _position,
                            bufferedPosition: _buffered,
                            tvFocusable: true,
                            focusNode: _seekFocus,
                            tvFocusUpNode: _backFocus,
                            onTvFocusUp: _focusUpFromSeekbar,
                            onTvFocusDown: _focusDownFromSeekbar,
                            onTvFocusLeft: _focusLeftFromSeekbar,
                            onTvFocusRight: _focusRightFromSeekbar,
                            onSeek: (t) {
                              unawaited(_seekTo(t));
                            },
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: PlayerTouchSeekBar(
                                duration: _duration,
                                position: _position,
                                bufferedPosition: _buffered,
                                onSeek: (t) {
                                  unawaited(_seekTo(t));
                                },
                                onDragStart: () => _hideTimer?.cancel(),
                                onDragEnd: _startHideTimer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            PlayerTimeRange(
                              position: _position,
                              duration: _duration,
                              fontSize: 11,
                            ),
                          ],
                        ),
                  const SizedBox(height: 8),
                  if (tvFocus)
                    _buildTvExoTransportRow(
                      btnSize: btnSize,
                      iconSz: iconSz,
                      hasTorrentSources: hasTorrentSources,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            PlayerFlatIconButton(
                              icon: _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressed: _togglePlayPause,
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.replay_10_rounded,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressed: () => unawaited(
                                _seekRelative(const Duration(seconds: -10)),
                              ),
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.forward_10_rounded,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressed: () => unawaited(
                                _seekRelative(const Duration(seconds: 10)),
                              ),
                            ),
                            PlayerVolumeControl(
                              volume: _volume,
                              maxVolume: 150,
                              size: btnSize,
                              iconSize: iconSz,
                              compact: compact,
                              onVolumeChanged: (v) => unawaited(_setVolume(v)),
                              onInteraction: _startHideTimer,
                              onDragStart: () => _hideTimer?.cancel(),
                              onDragEnd: _startHideTimer,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (hasTorrentSources)
                              PlayerFlatIconButton(
                                icon: Icons.link_rounded,
                                size: btnSize,
                                iconSize: iconSz,
                                tooltip: 'Sources',
                                onPressed: () =>
                                    unawaited(_showTorrentSourcesPanel()),
                              ),
                            if (_hasStreamPicker)
                              PlayerStreamPickerButton(
                                size: btnSize,
                                iconSize: iconSz - 2,
                                label: _streamPickerLabel(),
                                onPressedWithContext: (ctx) =>
                                    unawaited(_showSourcesDialog(ctx)),
                              ),
                            if (_hasEpisodePicker)
                              PlayerFlatIconButton(
                                icon: Icons.video_library_outlined,
                                size: btnSize,
                                iconSize: iconSz,
                                onPressedWithContext: (ctx) =>
                                    unawaited(_showEpisodesMenu(ctx)),
                              ),
                            PlayerFlatIconButton(
                              icon: Icons.audiotrack_rounded,
                              size: btnSize,
                              iconSize: iconSz,
                              tooltip: 'Audio',
                              onPressedWithContext: (ctx) =>
                                  unawaited(_showAudioMenu(ctx)),
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.subtitles_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressedWithContext: (ctx) =>
                                  unawaited(_showSubtitlesMenu(ctx)),
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.hd_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              tooltip: 'Quality',
                              onPressedWithContext: (ctx) =>
                                  unawaited(_showQualityMenu(ctx)),
                            ),
                            PlayerFlatIconButton(
                              icon: Icons.settings_outlined,
                              size: btnSize,
                              iconSize: iconSz,
                              onPressedWithContext: _showSettingsMenu,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!tvFocus) return overlay;
    return SizedBox.expand(
      child: FocusScope(
        debugLabel: 'exo-player-chrome',
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: overlay,
        ),
      ),
    );
  }

  Widget _buildTvExoTransportRow({
    required double btnSize,
    required double iconSz,
    required bool hasTorrentSources,
  }) {
    Widget ordered(int order, Widget child) => FocusTraversalOrder(
          order: NumericFocusOrder(order.toDouble()),
          child: child,
        );

    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ordered(
                3,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _playFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onRightEdge: () {
                    if (_rewindFocus.canRequestFocus) {
                      _rewindFocus.requestFocus();
                    }
                  },
                  icon: _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                4,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _rewindFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () => _playFocus.requestFocus(),
                  onRightEdge: () => _forwardFocus.requestFocus(),
                  icon: Icons.replay_10_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: () =>
                      unawaited(_seekRelative(const Duration(seconds: -10))),
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                5,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _forwardFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () => _rewindFocus.requestFocus(),
                  onRightEdge: _focusFirstRightTransport,
                  icon: Icons.forward_10_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressed: () =>
                      unawaited(_seekRelative(const Duration(seconds: 10))),
                ),
              ),
              const SizedBox(width: 6),
              ExcludeFocus(
                child: PlayerTimeRange(
                  position: _position,
                  duration: _duration,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTorrentSources)
                ordered(
                  6,
                  PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: _transportSourcesFocus,
                    onUpEdge: _focusSeekFromTransport,
                    onLeftEdge: _focusLeftOfRightTransport,
                    onRightEdge: () {
                      if (_hasStreamPicker &&
                          _transportStreamFocus.canRequestFocus) {
                        _transportStreamFocus.requestFocus();
                      } else if (_hasEpisodePicker &&
                          _transportEpisodesFocus.canRequestFocus) {
                        _transportEpisodesFocus.requestFocus();
                      } else {
                        _transportAudioFocus.requestFocus();
                      }
                    },
                    icon: Icons.link_rounded,
                    size: btnSize,
                    iconSize: iconSz,
                    tooltip: 'Sources',
                    onPressed: () => unawaited(_showTorrentSourcesPanel()),
                  ),
                ),
              if (hasTorrentSources) const SizedBox(width: 2),
              if (_hasStreamPicker)
                ordered(
                  7,
                  PlayerStreamPickerButton(
                    tvFocusable: true,
                    focusNode: _transportStreamFocus,
                    onUpEdge: _focusSeekFromTransport,
                    onLeftEdge: () {
                      if (hasTorrentSources &&
                          _transportSourcesFocus.canRequestFocus) {
                        _transportSourcesFocus.requestFocus();
                      } else {
                        _focusLeftOfRightTransport();
                      }
                    },
                    onRightEdge: () {
                      if (_hasEpisodePicker &&
                          _transportEpisodesFocus.canRequestFocus) {
                        _transportEpisodesFocus.requestFocus();
                      } else {
                        _transportAudioFocus.requestFocus();
                      }
                    },
                    size: btnSize,
                    iconSize: iconSz - 2,
                    label: _streamPickerLabel(),
                    onPressedWithContext: (ctx) =>
                        unawaited(_showSourcesDialog(ctx)),
                  ),
                ),
              if (_hasStreamPicker) const SizedBox(width: 2),
              if (_hasEpisodePicker)
                ordered(
                  8,
                  PlayerFlatIconButton(
                    tvFocusable: true,
                    focusNode: _transportEpisodesFocus,
                    onUpEdge: _focusSeekFromTransport,
                    onLeftEdge: () {
                      if (_hasStreamPicker &&
                          _transportStreamFocus.canRequestFocus) {
                        _transportStreamFocus.requestFocus();
                      } else if (hasTorrentSources &&
                          _transportSourcesFocus.canRequestFocus) {
                        _transportSourcesFocus.requestFocus();
                      } else {
                        _focusLeftOfRightTransport();
                      }
                    },
                    onRightEdge: () => _transportAudioFocus.requestFocus(),
                    icon: Icons.video_library_outlined,
                    size: btnSize,
                    iconSize: iconSz,
                    onPressedWithContext: (ctx) =>
                        unawaited(_showEpisodesMenu(ctx)),
                  ),
                ),
              if (_hasEpisodePicker) const SizedBox(width: 2),
              ordered(
                9,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _transportAudioFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () {
                    if (_hasEpisodePicker &&
                        _transportEpisodesFocus.canRequestFocus) {
                      _transportEpisodesFocus.requestFocus();
                    } else if (_hasStreamPicker &&
                        _transportStreamFocus.canRequestFocus) {
                      _transportStreamFocus.requestFocus();
                    } else if (hasTorrentSources &&
                        _transportSourcesFocus.canRequestFocus) {
                      _transportSourcesFocus.requestFocus();
                    } else {
                      _focusLeftOfRightTransport();
                    }
                  },
                  onRightEdge: () => _transportSubsFocus.requestFocus(),
                  icon: Icons.audiotrack_rounded,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Audio',
                  onPressedWithContext: (ctx) =>
                      unawaited(_showAudioMenu(ctx)),
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                10,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _transportSubsFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () => _transportAudioFocus.requestFocus(),
                  onRightEdge: () => _transportQualityFocus.requestFocus(),
                  icon: Icons.subtitles_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressedWithContext: (ctx) =>
                      unawaited(_showSubtitlesMenu(ctx)),
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                11,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _transportQualityFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () => _transportSubsFocus.requestFocus(),
                  onRightEdge: () => _transportSettingsFocus.requestFocus(),
                  icon: Icons.hd_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  tooltip: 'Quality',
                  onPressedWithContext: (ctx) =>
                      unawaited(_showQualityMenu(ctx)),
                ),
              ),
              const SizedBox(width: 2),
              ordered(
                12,
                PlayerFlatIconButton(
                  tvFocusable: true,
                  focusNode: _transportSettingsFocus,
                  onUpEdge: _focusSeekFromTransport,
                  onLeftEdge: () => _transportQualityFocus.requestFocus(),
                  icon: Icons.settings_outlined,
                  size: btnSize,
                  iconSize: iconSz,
                  onPressedWithContext: _showSettingsMenu,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerResolveStatusProvider, (previous, next) {
      if (!mounted || _disposed) return;
      switch (next.status) {
        case PlayerResolveStatus.loading:
          _statusController.upsert(
            'resolve',
            'Loading sources…',
            kind: StatusRouletteKind.loading,
          );
        case PlayerResolveStatus.ready:
          _statusController.complete();
        case PlayerResolveStatus.error:
          _statusController.upsert(
            'resolve',
            next.message ?? 'Failed to load sources',
            kind: StatusRouletteKind.failed,
            dismissAfter: const Duration(seconds: 2),
          );
        case PlayerResolveStatus.idle:
          break;
      }
    });
    ref.watch(playerResolveStatusProvider);
    final body = PopScope(
      // Always false - exit via [_exit] manual pop + loading dismiss.
      // canPop:true raced a deferred system pop and skipped dismiss (I101).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Forced pops (episode handoff / sources exhausted) must NOT strip the
        // loading host - those flows keep it for pushReplacement / reload UI.
        if (didPop) return;
        // HW may already have dismissed Sources / pair dialog on this press.
        if (ShellTvFocusCoordinator.consumeOverlayBack()) return;
        if (_isTv &&
            ShellTvFocusCoordinator.tvBackPolicyEnabled &&
            PlayerBackExitGate.tryFocusBackStay()) {
          return;
        }
        await _exit();
      },
      child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Positioned.fill: same as MediaKit / IPTV — loose Stack children
              // can get a zero or undersized PlatformView on Android after an
              // engine remount (MediaKit → Exo), which looks like a zoomed crop.
              Positioned.fill(
                child: ExcludeFocus(
                  child: ExoPlayerView(
                    key: ValueKey<int>(_viewId),
                    viewId: _viewId,
                  ),
                ),
              ),
              if (_coverDeadSurface)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Colors.black),
                  ),
                ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                ),
              ),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ExcludeFocus(
                  excluding: _isTv && !_showControls,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _buildControlsOverlay(),
                  ),
                ),
              ),
              if (widget.hasNextEpisode &&
                  widget.onNextEpisode != null &&
                  _nearEndOfEpisode &&
                  !_loadingNextEp)
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => unawaited(_nextEpisode()),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Next Episode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_loadingNextEp)
                Positioned(
                  bottom: 120,
                  right: 16,
                  child: PlayerEpisodeLoadingCard(
                    episodeLabel: _episodeLoadingLabel,
                    status: _episodeLoadingStatus,
                    failed: _episodeLoadingFailed,
                  ),
                ),
              if (!_loadingNextEp)
                PlayerStatusOverlay(
                  controller: _statusController,
                  bufferingListenable: _isBufferingNotifier,
                  header: 'CHECKING SOURCES',
                ),
              ParentalGuideLayer(
                imdbId: widget.movie?.imdbId,
                playbackStarted: _playbackStartedNotified,
              ),
            ],
          ),
        ),
      ),
    );

    if (!_isTv) return body;
    return PlayerTvKeyScope(
      enabled: true,
      focusNode: _tvKeyFocus,
      showControls: _showControls,
      onBack: () {
        if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
          ShellTvFocusCoordinator.handleShellBackKey();
        } else {
          unawaited(_exit());
        }
      },
      onPlayPause: _togglePlayPause,
      onShowControls: () {
        setState(() => _showControls = true);
        _startHideTimer();
        _claimPlayFocus();
      },
      onSeekBack: () =>
          unawaited(_seekRelative(const Duration(seconds: -10))),
      onSeekForward: () =>
          unawaited(_seekRelative(const Duration(seconds: 10))),
      onVolumeUp: () => unawaited(_setVolume(_volume + 10)),
      onVolumeDown: () => unawaited(_setVolume(_volume - 10)),
      onToggleControls: _toggleControls,
      onFocusBack: () {
        setState(() => _showControls = true);
        _startHideTimer();
        _claimBackFocus();
      },
      onFocusPlay: () {
        setState(() => _showControls = true);
        _startHideTimer();
        _claimPlayFocus();
      },
      onControlsActivity: _startHideTimer,
      child: body,
    );
  }
}

class _ExoSource {
  const _ExoSource({
    required this.url,
    required this.title,
    this.headers,
  });

  final String url;
  final String title;
  final Map<String, String>? headers;
}
