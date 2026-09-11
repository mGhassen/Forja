import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';

import 'package:forja/shared/playback/open/stream_loading.dart';
import 'package:forja/shared/playback/sources/stremio_external_link.dart';
import 'package:forja/shared/playback/probe/playback_stream_guards.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/cache/player_stream_extract_cache.dart';
import 'package:forja/shared/playback/open/player_source_resolve.dart';
import 'package:forja/shared/player/controls/menus/player_app_menu.dart';
import 'package:forja/shared/player/controls/chrome/player_back_exit_gate.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/chrome/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/chrome/player_escape_exit_hint.dart';
import 'package:forja/shared/player/controls/chrome/player_vod_tv_transport.dart';
import 'package:forja/shared/player/controls/episodes/player_episode_menu.dart';
import 'package:forja/shared/player/controls/episodes/player_episode_panel.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/controls/menus/player_provider_menu.dart';
import 'package:forja/shared/lan/lan_p2p_playback.dart';
import 'package:forja/features/settings/widgets/lan_p2p_required_dialog.dart';
import 'package:forja/shared/player/controls/sources/player_server_stream_dialog.dart';
import 'package:forja/shared/player/controls/sources/player_sources_panel.dart';
import 'package:forja/shared/player/controls/sources/player_stream_menu.dart';
import 'package:forja/shared/player/controls/chrome/player_status_roulette.dart';
import 'package:forja/shared/player/parental_guide/parental_guide_overlay.dart';
import 'package:forja/shared/player/controls/menus/player_subtitle_dialog.dart';
import 'package:forja/shared/player/controls/menus/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/seek/player_touch_seekbar.dart';
import 'package:forja/shared/player/controls/seek/seek_bar_zones.dart';
import 'package:forja/shared/player/controls/tv/player_tv_key_scope.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/player/resolvers/episode_switch_resolver.dart';
import 'package:forja/shared/player/exo/exo_atv_surface_fallback.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/exo/exo_player_menus.dart';
import 'package:forja/shared/player/exo/exo_player_view.dart';
import 'package:forja/shared/player/screens/network_playback_recovery.dart';
import 'package:forja/shared/player/screens/post_seek_stall_watchdog.dart';
import 'package:forja/shared/player/screens/shared_widgets.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/player/resolvers/track_auto_select.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/host/lists/list_follow_from_watched.dart';
import 'package:forja/shared/player/platform/mpv_exclusive_session.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:forja/shared/shell/loading_overlay.dart';
import 'package:forja/shared/shell/forja_toast.dart';
part 'exo_player_sources.dart';
part 'exo_player_tracks.dart';
part 'exo_player_failover.dart';

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
    this.episodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.enginePlaySession,
    this.providers,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.onSaveProgress,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.pinSource = false,
    this.streamsPrevalidated = false,
    this.onReloadStreams,
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
  final List<PlayerKitEpisode>? episodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerKitEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;
  final EnginePlaySession? enginePlaySession;
  final Map<String, dynamic>? providers;
  final String? stremioId;
  final String? stremioAddonBaseUrl;
  final Future<void> Function(Duration position, Duration duration)? onSaveProgress;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final bool pinSource;
  final bool streamsPrevalidated;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  ConsumerState<ExoPlayerScreen> createState() => _ExoPlayerScreenState();
}

class _ExoPlayerScreenState extends ConsumerState<ExoPlayerScreen>
    with
        WidgetsBindingObserver,
        _ExoPlayerSources,
        _ExoPlayerTracks,
        _ExoPlayerFailover {
  static int _nextViewId = 1;

  late final int _viewId = _nextViewId++;
  late final PlayerStatusController _statusController = PlayerStatusController();
  late final ValueNotifier<bool> _isBufferingNotifier =
      ValueNotifier<bool>(false);
  late final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  late final ValueNotifier<Duration> _positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  late final ValueNotifier<Duration> _durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  late final ValueNotifier<Map<String, List<StreamSource>>>
      _providerSourcesCache =
      ValueNotifier<Map<String, List<StreamSource>>>(const {});
  late final ValueNotifier<Set<String>> _providerLoadFailures =
      ValueNotifier<Set<String>>(const {});
  late final ValueNotifier<int> _streamMenuRefreshTick =
      ValueNotifier<int>(0);

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
  bool _playbackStartedNotified = false;
  bool _opening = false;
  bool _failoverInFlight = false;
  bool _allSourcesExhaustedNotified = false;
  /// Native error while `_opening` / mid-failover open — drained by failover.
  String? _pendingOpenError;
  /// Mid-watch Auto hop resume seek consumed by [_openCurrentSource].
  Duration? _pendingOpenSeek;
  bool _networkRemountInFlight = false;
  bool _startPositionApplied = false;
  bool _loadingNextEp = false;
  double _volume = 100;
  double _rate = 1.0;
  String _resizeMode = 'fit';
  /// Bumps [ExoPlayerView] key so TextureView remounts after MediaKit→Exo
  /// (issue 129 zoomed crop when MediaCodec was still detaching).
  int _platformMountGen = 0;
  bool _fitRemountAfterMediaKit = false;
  bool _fitRemountDone = false;
  ExoTracksSnapshot _tracks = ExoTracksSnapshot.empty;
  bool _preferredSubtitleApplied = false;
  /// True after Media3 STATE_READY. Selecting text tracks (or soft-reloading
  /// sideloads) before ready races MergingMediaPeriod / ProgressiveMediaPeriod
  /// and can throw IllegalStateException → player pops (issue 132).
  bool _exoReady = false;
  DateTime? _playbackConfirmedAt;
  List<Map<String, dynamic>> _externalSubtitles = [];
  Set<String> _providerExternalSubUrls = {};
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
  /// Media3 cues painted in Flutter — native SubtitleView is GONE (issue 230).
  final ValueNotifier<List<String>> _cueTexts = ValueNotifier<List<String>>(
    const [],
  );

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _nearEndOfEpisode = false;

  late List<_ExoSource> _sources;
  int _sourceIndex = 0;
  String? _currentProvider;
  String? _currentUrl;
  String? _currentPlayingCatalogUrl;
  String? _catalogStreamRowKey;
  String? _activeMagnet;
  String? _catalogSourceKind;
  String? _catalogAddonBaseUrl;

  /// Last catalog row `_addonName` / `name` (e.g. `VidRock · Astra`) for chrome.
  String? _catalogAddonName;
  List<StreamSource>? _currentSources;
  final Map<String, int> _providerLoadGens = {};
  int _fallbackGen = 0;
  final FocusNode _playFocus = FocusNode(debugLabel: 'exo-player-play');
  final FocusNode _rewindFocus = FocusNode(debugLabel: 'exo-player-rewind');
  final FocusNode _forwardFocus = FocusNode(debugLabel: 'exo-player-forward');
  final FocusNode _transportPrevEpFocus =
      FocusNode(debugLabel: 'exo-player-transport-prev-ep');
  final FocusNode _transportNextEpFocus =
      FocusNode(debugLabel: 'exo-player-transport-next-ep');
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
  /// TV Back / Exit: hide chrome → arm (+ hint) → leave (desktop Escape parity).
  bool _tvBackExitArmed = false;
  bool _hasPrevEpisodeAdjacent = false;
  bool _hasNextEpisodeAdjacent = false;
  bool _providerPinned = false;
  bool _sourcePinned = false;
  bool _audioPinned = false;
  bool _subtitlePinned = false;

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
        setArmed: (v) {
          if (!mounted || _disposed) return;
          if (_tvBackExitArmed == v) return;
          setState(() => _tvBackExitArmed = v);
        },
      );
    });
    _sources = [];
    _activeMagnet = widget.magnetLink;
    _catalogAddonBaseUrl = widget.stremioAddonBaseUrl;
    String? seedAddon;
    for (final s in widget.sources ?? const <StreamSource>[]) {
      final t = s.title.trim();
      if (t.isEmpty) continue;
      final lines = splitSourceButtonLines(t);
      if (lines.server != null) {
        seedAddon = '${lines.label} · ${lines.server}';
        break;
      }
    }
    _catalogAddonName = seedAddon;
    _catalogSourceKind = _initialCatalogSourceKind();
    _currentPlayingCatalogUrl = widget.mediaPath;
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
    unawaited(_loadPlayerAutoPins());
    unawaited(_refreshAdjacentEpisodeFlags());
    playerChromeOnOverlayDismissed = () {
      if (mounted) _syncChromeHideTimer();
    };
    _statusController.addListener(_onPlayerStatusForChromeHide);
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
            drm: s.drm?.toJson(),
          ),
        )
        .toList();
  }

  Future<void> _boot() async {
    // Wait for any MediaKit teardown from a Player-menu engine swap so Exo
    // does not attach over a half-dead mediacodec_embed surface (issue 129).
    // Cap on Android — full stop+dispose can exceed the ATV ANR window (128).
    // When MediaKit was disposing, remount TextureView after first paint —
    // the 1.2s cap still leaves zoomed frames (user switch-away/back fixes it).
    _fitRemountAfterMediaKit =
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
        url: normalizePlaybackStreamUrl(source.url),
        headers: source.headers,
        startPosition: pos,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
        drm: source.drm,
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

  /// MediaKit→Exo with ANR-capped prepare: first TextureView paint can be
  /// zoomed (bigger than screen). Remount once — same as switching away and
  /// back to Exo, which already fixed it for users (issue 129).
  void _maybeRemountFitAfterMediaKit() {
    if (!_fitRemountAfterMediaKit || _fitRemountDone || _disposed) return;
    _fitRemountDone = true;
    _fitRemountAfterMediaKit = false;
    MpvExclusiveSession.instance.acknowledgeExoFitRemount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      debugPrint('[ExoPlayer] remount TextureView after MediaKit surface race');
      setState(() => _platformMountGen++);
      unawaited(ExoPlayerBridge.setResizeMode(_viewId, _resizeMode));
    });
  }

  Future<void> _openCurrentSource() async {
    if (_opening || _disposed) return;
    // Capture gen — manual Sources switch bumps `_fallbackGen` and must keep
    // `_opening` true; do not clear the fence in finally after being superseded.
    final openGen = _fallbackGen;
    _opening = true;
    _preferredSubtitleApplied = false;
    _exoReady = false;
    _selectedExternalSubUrl = null;
    _cueTexts.value = const [];
    _surfaceFallback.resetForNewOpen();
    setState(() {
      _hasError = false;
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
    if (_fallbackAborted(openGen)) return;
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
      final pendingSeek = _pendingOpenSeek;
      _pendingOpenSeek = null;
      final Duration start;
      if (pendingSeek != null) {
        start = pendingSeek;
        _startPositionApplied = true;
      } else if (!_startPositionApplied) {
        start = widget.startPosition ?? Duration.zero;
        _startPositionApplied = true;
      } else {
        start = Duration.zero;
      }
      final maxH = await SettingsService().getMaxPlaybackHeight();
      if (_fallbackAborted(openGen)) return;
      final caps = exoVodCapsForMaxPlaybackHeight(maxH);
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: normalizePlaybackStreamUrl(source.url),
        headers: source.headers,
        startPosition: start,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
        drm: source.drm,
      );
      if (_fallbackAborted(openGen)) return;
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
      if (_fallbackAborted(openGen)) return;
      // Drop the fence so failover `_openCurrentSource` can re-enter.
      _opening = false;
      if (_failoverInFlight) {
        _pendingOpenError = 'Failed to open stream';
      } else {
        await _failCurrentSource('Failed to open stream');
      }
    } finally {
      if (openGen == _fallbackGen) {
        _opening = false;
        final pending = _pendingOpenError;
        if (pending != null && !_failoverInFlight) {
          _pendingOpenError = null;
          unawaited(_failCurrentSource(pending));
        }
      }
    }
  }

  Future<bool> _tryNetworkRemount(String err) async {
    if (_disposed ||
        !mounted ||
        _networkRemountInFlight ||
        _opening ||
        _hasError) {
      return false;
    }
    if (!shouldAttemptNetworkRemount(err)) return false;
    if (_sources.isEmpty) return false;
    final source = _sources[_sourceIndex];
    if (isLocalTorrentStreamUrl(source.url) ||
        isLocalLoopbackPlayUrl(source.url)) {
      return false;
    }

    _networkRemountInFlight = true;
    final resumeAt = _position;
    _statusController.upsert(
      'network-remount',
      'Reconnecting…',
      kind: StatusRouletteKind.loading,
    );
    debugPrint(
      '[ExoPlayer] Network remount @${resumeAt.inSeconds}s ($err)',
    );
    try {
      final ok = await attemptNetworkPlaybackRemount(
        isCancelled: () => _disposed || !mounted || _hasError,
        remount: () => _remountCurrentStreamAt(resumeAt),
      );
      if (ok) {
        _statusController.complete();
        debugPrint('[ExoPlayer] Network remount resumed');
        return true;
      }
      _statusController.remove('network-remount');
      return false;
    } finally {
      _networkRemountInFlight = false;
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
        _playbackConfirmedAt = DateTime.now();
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
        final playing = event['value'] == true;
        _isPlaying = playing;
        _isPlayingNotifier.value = playing;
        if (_showControls) setState(() {});
        _postSeekStall.onPlaying(_isPlaying);
        if (_isPlaying) {
          _clearDeadSurfaceCover();
          _isBufferingNotifier.value = false;
          _startHideTimer();
          _scrobbleStart();
          // Parity with MediaKit Video — re-hold on every playing=true so ATV
          // Ambient/screensaver cannot start mid-watch (issue 201).
          unawaited(WakelockPlus.enable());
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
        _positionNotifier.value = pos;
        _postSeekStall.onPosition(pos);
        if (durMs > 0) {
          _duration = Duration(milliseconds: durMs);
          _durationNotifier.value = _duration;
        }
        _buffered = Duration(milliseconds: bufMs);
        _nearEndOfEpisode = nearEnd;
        if (needsRepaint) setState(() {});
        break;
      case 'ended':
        _isPlaying = false;
        _isPlayingNotifier.value = false;
        setState(() {
          _showControls = true;
        });
        break;
      case 'error':
        final msg = event['message']?.toString() ?? 'Playback error';
        if (_opening || _failoverInFlight) {
          // Queue — never swallow. Failover loop / open finally drains this.
          _pendingOpenError = msg;
          debugPrint('[ExoPlayer] error during open/failover (queued): $msg');
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
        _maybeRemountFitAfterMediaKit();
        break;
      case 'cues':
        // Avoid setState — ValueListenableBuilder only (issue 151 / 230).
        final raw = event['texts'];
        if (raw is! List) {
          _cueTexts.value = const [];
          break;
        }
        _cueTexts.value = [
          for (final e in raw)
            if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
        ];
        break;
    }
  }

  void _scrobbleStart() {
    final movie = widget.movie;
    if (movie == null) return;
    SimklService().scrobbleStart(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
    unawaited(ListFollowFromWatched.markMovieWatchingOnPlay(movie));
  }

  void _scrobblePause() {
    final movie = widget.movie;
    if (movie == null) return;
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
    SimklService().scrobbleStop(
      tmdbId: movie.id,
      mediaType: movie.mediaType,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
    );
  }

  Future<void> _saveProgress() async {
    if (_duration.inMilliseconds <= 0) return;
    if (widget.onSaveProgress != null) {
      await widget.onSaveProgress!(_position, _duration);
    }
    final movie = widget.movie;
    if (movie != null && movie.mediaType == 'movie') {
      unawaited(
        ListFollowFromWatched.markMovieCompletedIfFinished(
          movie,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds,
        ),
      );
    }
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
    if (shouldSkipPostSeekStallArm(
      target: target,
      resumeStartPosition: widget.startPosition,
      playbackConfirmedAt: _playbackConfirmedAt,
    )) {
      return;
    }
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
    final remountGen = _fallbackGen;
    _opening = true;
    _exoReady = false;
    _statusController.upsert(
      'post-seek-remount',
      'Reconnecting…',
      kind: StatusRouletteKind.loading,
    );
    try {
      final maxH = await SettingsService().getMaxPlaybackHeight();
      if (_fallbackAborted(remountGen)) return false;
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
      final playUrl = normalizePlaybackStreamUrl(source.url);
      final headers = resolvePlaybackHttpHeaders(
        source.headers,
        streamUrl: playUrl,
        providerId: widget.activeProvider,
      );
      await ExoPlayerBridge.open(
        viewId: _viewId,
        url: playUrl,
        headers: headers,
        startPosition: target,
        subtitles: subs,
        maxVideoHeight: caps.maxVideoHeight,
        maxVideoBitrate: caps.maxVideoBitrate,
        drm: source.drm,
      );
      if (_fallbackAborted(remountGen)) return false;
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
      if (!_disposed && mounted && remountGen == _fallbackGen) {
        _statusController.upsert(
          'post-seek-remount',
          'Reconnect failed',
          kind: StatusRouletteKind.failed,
          dismissAfter: const Duration(milliseconds: 1500),
        );
      }
      return false;
    } finally {
      if (remountGen == _fallbackGen) {
        _opening = false;
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      unawaited(ExoPlayerBridge.pause(_viewId));
    } else {
      unawaited(ExoPlayerBridge.play(_viewId));
    }
    // Do not force chrome — Space / media keys pause with chrome hidden.
    if (_showControls) _syncChromeHideTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _syncChromeHideTimer();
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
    if (_hasNextEpisodeAdjacent && _transportNextEpFocus.canRequestFocus) {
      _transportNextEpFocus.requestFocus();
      return;
    }
    if (_hasPrevEpisodeAdjacent && _transportPrevEpFocus.canRequestFocus) {
      _transportPrevEpFocus.requestFocus();
      return;
    }
    _forwardFocus.requestFocus();
  }

  void _focusRightOfForward() {
    if (_hasPrevEpisodeAdjacent && _transportPrevEpFocus.canRequestFocus) {
      _transportPrevEpFocus.requestFocus();
      return;
    }
    if (_hasNextEpisodeAdjacent && _transportNextEpFocus.canRequestFocus) {
      _transportNextEpFocus.requestFocus();
      return;
    }
    _focusFirstRightTransport();
  }

  bool _fallbackAborted(int gen) =>
      _disposed || !mounted || gen != _fallbackGen;

  void _focusSeekFromTransport() {
    if (_seekFocus.canRequestFocus) {
      _seekFocus.requestFocus();
      return;
    }
    _claimBackFocus();
  }

  void _revealChrome() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _syncChromeHideTimer();
  }

  void _syncChromeHideTimer() {
    if (!_showControls) {
      _hideTimer?.cancel();
      return;
    }
    _startHideTimer();
  }

  void _onPlayerStatusForChromeHide() {
    _syncChromeHideTimer();
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
      setState(() => _showControls = false);
      if (_isTv) {
        playerTvClaimVideoKeyFocusAfterHide(
          _tvKeyFocus,
          mounted: () => mounted,
        );
      }
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
    if (widget.episodes != null &&
        widget.episodes!.isNotEmpty &&
        widget.onHubEpisodeSelected != null) {
      PlayerPopupPanel.dismiss();
      await PlayerKitEpisodePanel.show(
        context: context,
        episodes: widget.episodes!,
        currentEpisode: widget.hubEpisodeNumber ?? widget.selectedEpisode ?? 1,
        onEpisodeSelected: (ep) async {
          setState(() => _loadingNextEp = true);
          try {
            await widget.onHubEpisodeSelected!(ep);
            if (mounted) {
              setState(() => _loadingNextEp = false);
            }
          } catch (_) {
            if (!mounted) return;
            await Future<void>.delayed(const Duration(seconds: 2));
            if (mounted) {
              setState(() => _loadingNextEp = false);
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
    if (isEnginePlayerSession(widget.activeProvider)) {
      await _saveProgress();
      _scrobbleStop();
      if (!mounted) return;
      setState(() => _loadingNextEp = true);
      try {
        await ExoPlayerBridge.stop(_viewId);
      } catch (_) {}
      if (!mounted) return;
      try {
        debugPrint('[ExoPlayer] Engine Auto S${season}E$episode');
        await switchEpisodeViaEngineAutoPlay(
          context: context,
          movie: widget.movie!,
          season: season,
          episode: episode,
          stremioId: widget.stremioId,
          session: widget.enginePlaySession,
          episodes: widget.episodes,
        );
      } finally {
        if (mounted) {
          setState(() => _loadingNextEp = false);
        }
      }
      return;
    }

    setState(() => _loadingNextEp = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      await _saveProgress();
      _scrobbleStop();

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
        resolved = await resolveEpisodeForProvider(
          providerKey: key,
          movie: widget.movie!,
          season: season,
          episode: episode,
          providers: widget.providers,
          magnetLink: widget.magnetLink,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          torrentEp: metaOpenTorrentEp(
            widget.enginePlaySession?.effectiveOpen,
          ),
        );
        if (resolved != null) break;
      }
      if (resolved == null || resolved.streamUrl.isEmpty) {
        throw Exception('Could not find stream for S${season}E$episode');
      }
      if (!mounted) return;

      final nextTitle = '${widget.movie!.title} - S$season E$episode';
      final catalog = isCatalogSourcesMode(resolved.activeProvider);
      if (resolved.magnetLink != null && resolved.magnetLink!.isNotEmpty) {
        TorrentStreamService().retainForExternalHandoff = true;
      }
      try {
        await ExoPlayerBridge.stop(_viewId);
      } catch (_) {}
      if (!mounted) return;
      // openPlayer (not pushReplacement): clears old player + loading dialogs /
      // hub host so Back returns to details, not the previous episode.
      unawaited(
        AppRouter.openPlayer(
          context,
          streamUrl: resolved.streamUrl,
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
          enginePlaySession: widget.enginePlaySession,
          episodes: widget.episodes,
          hubEpisodeNumber: widget.episodes != null ? episode : null,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          onSaveProgress: widget.onSaveProgress,
        ),
      );
    } catch (e) {
      debugPrint('[ExoPlayer] episode switch failed: $e');
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _loadingNextEp = false);
      }
    }
  }

  Future<void> _showAudioMenu(BuildContext anchorContext) async {
    final tracks = await _refreshTracks();
    if (!mounted || !anchorContext.mounted) return;
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
    if (!mounted || !anchorContext.mounted) return;
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
    // Appearance is Flutter-only now (issue 230). Still push to native for
    // API parity / future remounts; Kotlin stores and ignores paint.
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
    // Rebuild cue overlay with new style without waiting for next cue.
    if (mounted) setState(() {});
  }

  Widget _buildCueOverlay(List<String> texts) {
    if (texts.isEmpty) return const SizedBox.shrink();
    final bgAlpha = (_subtitleBgOpacity * 255).round().clamp(0, 255);
    final fontFamily = switch (_subtitleFont) {
      'Roboto Mono' => 'monospace',
      'Default' || '' => null,
      _ => _subtitleFont,
    };
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          // Mirror Media3 bottomPaddingFraction mapping (~2%–22% of height).
          bottom: 24 + _subtitleBottomPadding.clamp(0, 120),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgAlpha == 0
                ? Colors.transparent
                : Colors.black.withAlpha(bgAlpha),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: bgAlpha == 0 ? 0 : 10,
              vertical: bgAlpha == 0 ? 0 : 4,
            ),
            child: Text(
              texts.join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subtitleColor,
                fontSize: _subtitleSize,
                fontWeight: _subtitleBold ? FontWeight.bold : FontWeight.w500,
                fontFamily: fontFamily,
                height: 1.25,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    if (_providerExternalSubUrls.isEmpty &&
        (widget.externalSubtitles ?? const []).isNotEmpty) {
      _providerExternalSubUrls = providerExternalSubtitleUrls(
        widget.externalSubtitles!,
      );
    }
    // Provider sideloads (KissKh Sub API) win over HLS mux.
    if (_providerExternalSubUrls.isNotEmpty) {
      await _maybeAutoPickExternalSubtitle();
      return;
    }
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
      // Anonymous CEA-608/708 ("CC 1") often decodes empty on VOD HLS — never
      // auto-pick it; fall through to Wyzie/Levrx like MediaKit (issue 230).
      if (t.isAnonymousClosedCaption) continue;
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
    // Language match only — same contract as pickEmbeddedSubtitleWithFallback.
    // Do not fall back to first text track (that was empty CEA "Track 1").
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
    if (!mounted || !anchorContext.mounted) return;
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
    final hasProviders = widget.providers != null &&
        widget.providers!.isNotEmpty &&
        widget.movie != null &&
        !_usesCatalogSourcesPanel;
    final hasSources =
        _currentSources != null && _currentSources!.isNotEmpty;
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
      showAutoServer: hasProviders,
      showAutoSource: hasSources,
      providerPinnedOf: () => _providerPinned,
      sourcePinnedOf: () => _sourcePinned,
      audioPinnedOf: () => _audioPinned,
      subtitlePinnedOf: () => _subtitlePinned,
      onAutoServer: (on) async {
        final settings = SettingsService();
        if (on) {
          await settings.setPlayerAutoServer(true);
          if (mounted) setState(() => _providerPinned = false);
        } else {
          await settings.setPlayerAutoServer(false);
          if (mounted) setState(() => _providerPinned = true);
        }
      },
      onAutoSource: (on) async {
        final settings = SettingsService();
        if (on) {
          await settings.setPlayerAutoSource(true);
          if (mounted) setState(() => _sourcePinned = false);
        } else {
          await settings.setPlayerAutoSource(false);
          if (mounted) setState(() => _sourcePinned = true);
        }
      },
      onAutoAudio: (on) async {
        final settings = SettingsService();
        if (on) {
          await settings.setPlayerAutoAudio(true);
          if (mounted) setState(() => _audioPinned = false);
        } else {
          await settings.setPlayerAutoAudio(false);
          if (mounted) setState(() => _audioPinned = true);
        }
      },
      onAutoSubtitles: (on) async {
        final settings = SettingsService();
        if (on) {
          await settings.setPlayerAutoSubtitle(true);
          if (mounted) setState(() => _subtitlePinned = false);
          _preferredSubtitleApplied = false;
          unawaited(_maybeApplyPreferredSubtitle());
        } else {
          await settings.setPlayerAutoSubtitle(false);
          if (mounted) setState(() => _subtitlePinned = true);
        }
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
      usingBuiltIn: true,
      builtInEngine: widget.builtInEngine,
      onSelect: ({builtInEngine, externalPlayer}) async {
        // Soft-stop before parent unmounts us — MediaCodec release in dispose
        // mid-switch ANRs ATV (issue 128). stop() keeps the player instance.
        if (externalPlayer == null && builtInEngine != null) {
          try {
            await ExoPlayerBridge.stop(_viewId)
                .timeout(const Duration(milliseconds: 400));
          } catch (_) {}
        }
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

  Future<void> _loadPlayerAutoPins() async {
    final settings = SettingsService();
    final autoServer = await settings.getPlayerAutoServer();
    final autoSource = await settings.getPlayerAutoSource();
    final autoAudio = await settings.getPlayerAutoAudio();
    final autoSub = await settings.getPlayerAutoSubtitle();
    if (!mounted) return;
    setState(() {
      _providerPinned = !autoServer;
      _sourcePinned = !autoSource;
      _audioPinned = !autoAudio;
      _subtitlePinned = !autoSub;
    });
  }

  Future<void> _refreshAdjacentEpisodeFlags() async {
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      final flags = adjacentHubEpisodeFlags(widget.episodes, current);
      if (!mounted) return;
      setState(() {
        _hasPrevEpisodeAdjacent = flags.hasPrev;
        _hasNextEpisodeAdjacent = flags.hasNext;
      });
      return;
    }

    if (widget.onNextEpisode != null) {
      if (!mounted) return;
      setState(() {
        _hasNextEpisodeAdjacent = widget.hasNextEpisode;
        _hasPrevEpisodeAdjacent = current != null && current > 1;
      });
      return;
    }

    if (widget.movie?.mediaType == 'tv' &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      if (!mounted) return;
      setState(() {
        _hasPrevEpisodeAdjacent = widget.selectedEpisode! > 1 ||
            (widget.selectedSeason ?? 1) > 1;
        _hasNextEpisodeAdjacent = true;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasPrevEpisodeAdjacent = false;
      _hasNextEpisodeAdjacent = false;
    });
  }

  Future<void> _previousEpisode() async {
    if (_loadingNextEp) return;
    final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
    if (widget.episodes != null &&
        widget.onHubEpisodeSelected != null &&
        current != null) {
      final idx = hubEpisodeIndex(widget.episodes!, current);
      if (idx == null || idx <= 0) return;
      final prev = widget.episodes![idx - 1];
      setState(() => _loadingNextEp = true);
      try {
        try {
          await ExoPlayerBridge.stop(_viewId);
        } catch (_) {}
        await widget.onHubEpisodeSelected!(prev);
        if (mounted) setState(() => _loadingNextEp = false);
      } catch (_) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _loadingNextEp = false);
      }
      return;
    }

    if (widget.movie?.mediaType == 'tv' &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      var season = widget.selectedSeason!;
      var episode = widget.selectedEpisode! - 1;
      if (episode < 1) {
        if (season <= 1) return;
        season -= 1;
        episode = 1;
      }
      await _switchToEpisode(season, episode);
      return;
    }
  }

  Future<void> _nextEpisode() async {
    if (_loadingNextEp) return;

    if (widget.onNextEpisode != null) {
      if (!widget.hasNextEpisode) return;
      setState(() => _loadingNextEp = true);
      try {
        try {
          await ExoPlayerBridge.stop(_viewId);
        } catch (_) {}
        await widget.onNextEpisode!();
        if (mounted) {
          setState(() => _loadingNextEp = false);
        }
      } catch (_) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() => _loadingNextEp = false);
        }
      }
      return;
    }

    if (widget.episodes != null &&
        widget.onHubEpisodeSelected != null) {
      final current = widget.hubEpisodeNumber ?? widget.selectedEpisode;
      if (current == null) return;
      final idx = hubEpisodeIndex(widget.episodes!, current);
      if (idx == null || idx >= widget.episodes!.length - 1) return;
      final next = widget.episodes![idx + 1];
      setState(() => _loadingNextEp = true);
      try {
        try {
          await ExoPlayerBridge.stop(_viewId);
        } catch (_) {}
        await widget.onHubEpisodeSelected!(next);
        if (mounted) setState(() => _loadingNextEp = false);
      } catch (_) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _loadingNextEp = false);
      }
      return;
    }

    if (widget.movie?.mediaType == 'tv' &&
        widget.selectedSeason != null &&
        widget.selectedEpisode != null) {
      await _switchToEpisode(
        widget.selectedSeason!,
        widget.selectedEpisode! + 1,
      );
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

  bool get _hasStreamPicker => _hasStreamPickerSources;

  bool get _hasEpisodePicker {
    final isTv = widget.movie?.mediaType == 'tv';
    return (isTv && widget.movie != null) ||
        (widget.episodes != null && widget.episodes!.isNotEmpty);
  }

  @override
  void dispose() {
    _disposed = true;
    PlayerBackExitGate.setTryFocusBack(null);
    PlayerSourcesPanel.dismiss(cancelEngine: false);
    PlayerServerStreamDialog.dismiss();
    PlayerStreamMenu.dismiss();
    PlayerSubtitleDialog.dismiss();
    PlayerPopupPanel.dismiss();
    PlayerSubtitleSettingsDialog.dismissIfShowing();
    LanP2pRequiredDialog.dismissIfShowing();
    _playFocus.dispose();
    _rewindFocus.dispose();
    _forwardFocus.dispose();
    _transportPrevEpFocus.dispose();
    _transportNextEpFocus.dispose();
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
    playerChromeOnOverlayDismissed = null;
    _statusController.removeListener(_onPlayerStatusForChromeHide);
    playerMenuClearReturnFocus();
    _statusController.dispose();
    _isBufferingNotifier.dispose();
    _isPlayingNotifier.dispose();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _providerSourcesCache.dispose();
    _providerLoadFailures.dispose();
    _streamMenuRefreshTick.dispose();
    _cueTexts.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _postSeekStall.dispose();
    _surfaceFallback.dispose();
    _eventSub?.cancel();
    // Defer MediaCodec release off the dispose frame (issue 128). Track so
    // Player-menu MediaKit mount can wait briefly via prepareForVideoPlayer.
    final teardown = Platform.isAndroid
        ? Future<void>.delayed(
            const Duration(milliseconds: 50),
            _teardownExoPlayer,
          )
        : _teardownExoPlayer();
    MpvExclusiveSession.instance.trackVideoDispose(teardown);
    unawaited(teardown);
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _teardownExoPlayer() async {
    try {
      await ExoPlayerBridge.stop(_viewId)
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {}
    try {
      await ExoPlayerBridge.dispose(_viewId)
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  Widget _buildControlsOverlay() {
    const btnSize = 38.0;
    const iconSz = 20.0;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final tvFocus = _isTv;
    final hasTorrentSources = _usesCatalogSourcesPanel;
    final catalogSourceLines =
        hasTorrentSources ? _catalogSourcesButtonLabels() : null;
    final streamPickerLines =
        _hasStreamPicker ? _streamPickerLabels() : null;
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
                    season: widget.episodes != null
                        ? null
                        : widget.selectedSeason,
                    episode: widget.episodes != null
                        ? null
                        : widget.selectedEpisode,
                    episodeLine: _episodeLine,
                    statusActions: _hasError
                        ? PlayerTopStatusActions(
                            onRetry: () {
                              setState(() {
                                _hasError = false;
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
                          : () => _backFocus.requestFocus(),
                      playerOnDownEdge: _focusDownFromTopBar,
                      onPlayer: widget.onSwitchPlayer != null
                          ? (anchorContext) =>
                              unawaited(_showPlayerMenu(anchorContext))
                          : null,
                    ),
                  ),
                )
              : PlayerTopBar(
                  title: widget.title,
                  season: widget.episodes != null
                      ? null
                      : widget.selectedSeason,
                  episode: widget.episodes != null
                      ? null
                      : widget.selectedEpisode,
                  episodeLine: _episodeLine,
                  statusActions: _hasError
                      ? PlayerTopStatusActions(
                          onRetry: () {
                            setState(() {
                              _hasError = false;
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
                        season: widget.episodes != null
                            ? null
                            : widget.selectedSeason,
                        episode: widget.episodes != null
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
                            zones: buildSeekBarZones(
                              duration: _duration,
                              hasNextEpisode: widget.hasNextEpisode,
                            ),
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
                                zones: buildSeekBarZones(
                                  duration: _duration,
                                  hasNextEpisode: widget.hasNextEpisode,
                                ),
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
                    PlayerVodTvTransportRow(
                      btnSize: btnSize,
                      iconSz: iconSz,
                      isPlayingListenable: _isPlayingNotifier,
                      positionListenable: _positionNotifier,
                      durationListenable: _durationNotifier,
                      playFocus: _playFocus,
                      rewindFocus: _rewindFocus,
                      forwardFocus: _forwardFocus,
                      transportPrevEpFocus: _transportPrevEpFocus,
                      transportNextEpFocus: _transportNextEpFocus,
                      transportSourcesFocus: _transportSourcesFocus,
                      transportStreamFocus: _transportStreamFocus,
                      transportEpisodesFocus: _transportEpisodesFocus,
                      transportAudioFocus: _transportAudioFocus,
                      transportSubsFocus: _transportSubsFocus,
                      transportQualityFocus: _transportQualityFocus,
                      transportSettingsFocus: _transportSettingsFocus,
                      hasPrevEpisode: _hasPrevEpisodeAdjacent,
                      hasNextEpisode: _hasNextEpisodeAdjacent,
                      hasTorrentSources: hasTorrentSources,
                      hasStreamPicker: _hasStreamPicker,
                      hasEpisodePicker: _hasEpisodePicker,
                      catalogSourceLines: catalogSourceLines,
                      streamPickerLines: streamPickerLines,
                      onPlayPause: _togglePlayPause,
                      onRewind10: () => unawaited(
                        _seekRelative(const Duration(seconds: -10)),
                      ),
                      onForward10: () => unawaited(
                        _seekRelative(const Duration(seconds: 10)),
                      ),
                      onPreviousEpisode: () {
                        if (_loadingNextEp) return;
                        unawaited(_previousEpisode());
                      },
                      onNextEpisode: () {
                        if (_loadingNextEp) return;
                        unawaited(_nextEpisode());
                      },
                      onUpFromTransport: _focusSeekFromTransport,
                      onFocusFirstRightTransport: _focusFirstRightTransport,
                      onFocusLeftOfRightTransport: _focusLeftOfRightTransport,
                      onFocusRightOfForward: _focusRightOfForward,
                      onOpenTorrentSources: () =>
                          unawaited(_showTorrentSourcesPanel()),
                      onOpenStreamPicker: (ctx) =>
                          unawaited(_showSourcesDialog(ctx)),
                      onOpenEpisodes: (ctx) =>
                          unawaited(_showEpisodesMenu(ctx)),
                      onOpenAudio: (ctx) => unawaited(_showAudioMenu(ctx)),
                      onOpenSubtitles: (ctx) =>
                          unawaited(_showSubtitlesMenu(ctx)),
                      onOpenQuality: (ctx) =>
                          unawaited(_showQualityMenu(ctx)),
                      onOpenSettings: _showSettingsMenu,
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
                            if (_hasPrevEpisodeAdjacent)
                              PlayerFlatIconButton(
                                icon: Icons.skip_previous_rounded,
                                size: btnSize,
                                iconSize: iconSz,
                                tooltip: 'Previous Episode',
                                onPressed: () {
                                  if (_loadingNextEp) return;
                                  unawaited(_previousEpisode());
                                },
                              ),
                            if (_hasNextEpisodeAdjacent)
                              PlayerFlatIconButton(
                                icon: Icons.skip_next_rounded,
                                size: btnSize,
                                iconSize: iconSz,
                                tooltip: 'Next Episode',
                                onPressed: () {
                                  if (_loadingNextEp) return;
                                  unawaited(_nextEpisode());
                                },
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
                              PlayerSourcesPanelButton(
                                size: btnSize,
                                iconSize: iconSz,
                                label: catalogSourceLines!.label,
                                server: catalogSourceLines.server,
                                onPressed: () =>
                                    unawaited(_showTorrentSourcesPanel()),
                              ),
                            if (_hasStreamPicker)
                              PlayerStreamPickerButton(
                                size: btnSize,
                                iconSize: iconSz - 2,
                                label: streamPickerLines!.label,
                                server: streamPickerLines.server,
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
        debugLabel: 'player-chrome',
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: overlay,
        ),
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
                    key: ValueKey<String>('exo-$_viewId-$_platformMountGen'),
                    viewId: _viewId,
                  ),
                ),
              ),
              // Flutter cue paint — native SubtitleView is GONE inside the
              // PlatformView (issue 230 / Xiaomi ATV VirtualDisplay).
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: _cueTexts,
                    builder: (context, texts, _) => _buildCueOverlay(texts),
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
              if (_tvBackExitArmed) const PlayerEscapeExitHint.tv(),
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
              if (!isStreamLoadingOverlayActive && !_loadingNextEp)
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
        _revealChrome();
        _claimPlayFocus();
      },
      onSeekBack: () =>
          unawaited(_seekRelative(const Duration(seconds: -10))),
      onSeekForward: () =>
          unawaited(_seekRelative(const Duration(seconds: 10))),
      onToggleControls: _toggleControls,
      onFocusBack: () {
        _revealChrome();
        _claimBackFocus();
      },
      onFocusPlay: () {
        _revealChrome();
        _claimPlayFocus();
      },
      onClaimPlayFocus: _claimPlayFocus,
      onControlsActivity: _syncChromeHideTimer,
      child: body,
    );
  }
}

class _ExoSource {
  const _ExoSource({
    required this.url,
    required this.title,
    this.headers,
    this.drm,
  });

  final String url;
  final String title;
  final Map<String, String>? headers;
  final Map<String, dynamic>? drm;
}
