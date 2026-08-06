import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:forja/shared/player/controls/player_menus.dart';
import 'playback_recovery.dart';
import 'playable_source_bridge.dart';

import 'package:rust/rust.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrc/vidsrc_extractor.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/playback/domain_playback_resolve.dart';
import 'package:forja/shared/playback/playback_engine.dart';
import 'package:forja/shared/playback/playback_service.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/player_source_resolve.dart';
import 'package:forja/shared/playback/provider_score_probe_sync.dart';
import 'package:forja/shared/playback/stream_open_pipeline.dart';
import 'package:forja/shared/playback/stream_open_strategy.dart';
import 'package:forja/shared/playback/webstreaming_stream_cache.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/extractors/providers/arabic/arabic_service.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/desktop_pip_overlay.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
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
import 'package:forja/shared/player/controls/player_episode_loading_card.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_quality_menu.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shell/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';

part 'desktop_player_glass.dart';
part 'desktop_player_lifecycle.dart';
part 'desktop_player_playback.dart';
part 'desktop_player_tracks.dart';
part 'desktop_player_sources.dart';
part 'desktop_player_episodes.dart';
part 'desktop_player_ui.dart';
part 'desktop_player_build.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESKTOP PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DesktopPlayerScreen extends ConsumerStatefulWidget {
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
  final Future<void> Function(Duration position, Duration duration)?
  onSaveProgress;
  final Future<void> Function(String sourceUrl, String sourceTitle)?
  onSourcePinned;
  final bool pinSource;
  final bool streamsPrevalidated;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final ValueNotifier<List<StreamSource>>? sourcesListNotifier;
  final ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

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
    this.streamsPrevalidated = false,
    this.onPlaybackStarted,
    this.onAllSourcesExhausted,
    this.onReloadStreams,
    this.sourcesListNotifier,
    this.providerSourcesCache,
    this.providerProbesNotifier,
    this.builtInEngine = BuiltInPlayerEngine.mediaKit,
    this.onSwitchPlayer,
  });

  @override
  ConsumerState<DesktopPlayerScreen> createState() => _DesktopPlayerScreenState();
}
class _DesktopPlayerScreenState extends ConsumerState<DesktopPlayerScreen>
    with WindowListener, WidgetsBindingObserver,
        _DesktopPlayerLifecycle,
        _DesktopPlayerPlayback,
        _DesktopPlayerTracks,
        _DesktopPlayerSources,
        _DesktopPlayerEpisodes,
        _DesktopPlayerUi,
        _DesktopPlayerBuild {
  // ── Player ──────────────────────────────────────────────────────────────
  late Player _player;
  late VideoController _controller;
  bool _playerReady = false;
  bool _disposed = false;
  bool _playbackStopped = false;
  /// Guards re-entrant Escape / Back while [_exitPlayer] awaits stop.
  bool _exitInProgress = false;
  int _fallbackGen = 0;
  final Map<String, int> _providerLoadGens = {};
  final ValueNotifier<Set<String>> _providerLoadFailures =
      ValueNotifier<Set<String>>({});
  late final ValueNotifier<Map<String, List<StreamSource>>>
      _ownedProviderSourcesCache;
  bool _historySaved = false;
  Timer? _progressSaveTimer;
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

  /// True when we paused because the window left the foreground (not user pause).
  bool _pausedByLifecycle = false;

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
  StreamSubscription<PlayerLog>? _logSub;
  /// Deferred track/subtitle auto-select - cancel on exit so it cannot
  /// touch State after the route is gone.
  Timer? _trackAutoSelectTimer;
  PlaybackRecovery? _playbackRecovery;
  bool _autoTracksAppliedForSource = false;
  // ── Value Notifiers (rebuild only what's needed, no full setState) ────────
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<Duration> _bufferedNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _volumeNotifier = ValueNotifier(100.0);

  /// KissKh: first-frame BUFFERING forever (4K ladder). One soft drop attempt.
  DateTime? _kissKhBufferingSince;
  bool _kissKhBufferStallTried = false;
  Timer? _kissKhBufferWatchdog;

  // ── Subtitles ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _externalSubtitles = [];
  bool _isFetchingSubs = false;

  /// When true, the current subtitle is ASS/SSA or an image-based format (PGS/VobSub).
  /// mpv renders it directly on the video frame, so the custom Flutter overlay is hidden.
  bool _isNativeSubtitle = false;
  String? _selectedExternalSubUrl;
  /// Downloaded external subtitle file URIs keyed by source URL - reused when
  /// mpv wipes the track on media open (auto-pick race).
  final Map<String, String> _externalSubFileCache = {};

  // ── Provider switching ────────────────────────────────────────────────────
  String? _currentProvider;
  List<StreamSource>? _currentSources;
  List<PlayableSource>? _playableSources;
  String? _currentUrl;
  String? _activeMagnet;
  /// Catalog Sources kind for the playing session: `torrents` | `stremio` | `nuvio`.
  String? _catalogSourceKind;
  /// Last Stremio/Nuvio `_addonBaseUrl` (e.g. `nuvio:showbox`) for panel focus.
  String? _catalogAddonBaseUrl;
  // ── HLS Quality Selector ─────────────────────────────────────────────────
  // Populated when the playing URL is a master HLS playlist with 2+
  // variants. The gear button in the top control bar is hidden until this
  // notifier holds a non-empty list.
  final ValueNotifier<List<HlsQuality>?> _hlsQualitiesNotifier = ValueNotifier(
    null,
  );
  String? _hlsMasterUrl;
  Map<String, String>? _hlsMasterHeaders;
  String? _currentQualityUrl;

  /// For provider == 'service111477', the upstream fileUrl currently playing
  /// (the menu compares against this rather than the localhost proxy URL).
  String? _current111477FileUrl;
  int _currentFallbackSourceIndex = 0;
  /// Catalog stream URL selected when playback last confirmed.
  String? _currentPlayingCatalogUrl;
  bool _providerPinned = false;
  bool _sourcePinned = false;
  bool _audioPinned = false;
  bool _subtitlePinned = false;
  bool _allSourcesExhaustedNotified = false;
  final PlayerStatusController _statusController = PlayerStatusController();
  final Set<int> _failedSourceIndices = {};
  final Set<int> _checkingSourceIndices = {};
  final Map<String, PlayerSourceStatus> _urlCheckStatuses = {};
  final ValueNotifier<int> _sourceMenuRevision = ValueNotifier(0);
  bool _isInitPlaybackRunning = false;
  bool _playbackConfirmed = false;
  DateTime? _playbackConfirmedAt;
  /// First confirm of this episode session (survives source switches).
  DateTime? _sessionFirstConfirmedAt;
  /// True once position was observed in the episode body this session.
  bool _hadMidPlayback = false;
  /// Mid-body on the current source open only (resets on every re-open).
  bool _openHadMidPlayback = false;
  /// Latch abortive EOF so repeating `completed` events do not spam / auto-next.
  bool _abortiveCompletedLatched = false;
  /// Wall-clock when the user scrubbed away from EOF (suppresses re-pin).
  DateTime? _seekAwayFromEofAt;
  late final Future<void> _playableSourcesReady;

  void _resetEofSessionGuards() {
    _hadMidPlayback = false;
    _openHadMidPlayback = false;
    _abortiveCompletedLatched = false;
    _sessionFirstConfirmedAt = null;
    _seekAwayFromEofAt = null;
  }

  void _markPlaybackConfirmed(bool confirmed) {
    _playbackConfirmed = confirmed;
    // Each open must re-earn mid / early-EOF grace - session mid alone must
    // not paint a dead CDN as a finished episode.
    _openHadMidPlayback = false;
    if (confirmed) {
      final now = DateTime.now();
      _playbackConfirmedAt = now;
      _sessionFirstConfirmedAt ??= now;
      _kissKhBufferingSince = null;
      _kissKhBufferStallTried = false;
      // Media open resets mpv subtitle - re-apply preferred after the wipe.
      unawaited(_reapplyPreferredSubtitle());
    } else {
      // Keep session mid / first-confirm across source switches for credits
      // re-open; open mid stays cleared above.
      _playbackConfirmedAt = null;
      _kissKhBufferingSince = null;
    }
  }

  Future<void> _seekTo(Duration position) => seekPlayerPreservingProgress(
        _player,
        position: position,
        positionNotifier: _positionNotifier,
        duration: _durationNotifier.value,
        onSeekAwayFromEof: () {
          _seekAwayFromEofAt = DateTime.now();
          _abortiveCompletedLatched = false;
        },
      );

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
  String _episodeLoadingLabel = '';
  String _episodeLoadingStatus = '';
  bool _episodeLoadingFailed = false;
  bool _nearEndOfEpisode = false;
  bool _hasPrevEpisodeAdjacent = false;
  bool _hasNextEpisodeAdjacent = false;

  // ── Skip Segments (IntroDB) ───────────────────────────────────────────────
  IntroDbResponse? _introDbData;
  String? _activeSkipLabel; // e.g. 'Skip Intro', 'Skip Recap', etc.
  Duration? _activeSkipTarget; // where to seek when the user taps
  bool _skipDismissed = false; // user dismissed the current segment button

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    widget.sourcesListNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onProbeScoringChanged);
    // Mark disposed before cancelling/disposing notifiers so in-flight
    // `_initPlayback` / mark-failed paths bail out instead of writing
    // to a disposed ValueNotifier.
    _disposed = true;
    _cancelPendingStreamWork();
    _providerLoadFailures.dispose();
    if (widget.providerSourcesCache == null) {
      _ownedProviderSourcesCache.dispose();
    }
    _saveWatchHistory();

    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _trackAutoSelectTimer?.cancel();
    _trackAutoSelectTimer = null;
    _pipSub?.cancel();
    PipService.instance.unbindAutoEnterOnDesktopSwitch(this);
    _torrentStatsSub?.cancel();
    PlayerSubtitleSettingsDialog.dismissIfShowing();
    PlayerTorrentFilePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    playerMenuClearReturnFocus();
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
    _kissKhBufferWatchdog?.cancel();
    _volumeSub?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _logSub?.cancel();

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

    if (_playerReady) {
      _playerReady = false;
      MpvExclusiveSession.instance.untrackPlayer(_player);
      final disposeFuture = _teardownMediaKitPlayer(_player);
      MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
      unawaited(disposeFuture);
    }

    // Remove torrent from engine on player exit (use magnetLink for hash,
    // fall back to mediaPath which may be a stream URL).
    if (!TorrentStreamService().retainForExternalHandoff) {
      final torrentId = widget.magnetLink ?? widget.mediaPath;
      TorrentStreamService().removeTorrent(torrentId);
    }

    // Tear down the 111477 proxy and delete its on-disk cache.
    if (site111477_proxy.is111477ProxyRunning) {
      site111477_proxy.stop111477Proxy();
    }

    super.dispose();
  }

  /// Instant silence before route pop (native mpv props; no hung init waits).
  Future<void> _stopPlaybackForExit() async {
    if (_playbackStopped || !_playerReady) return;
    _playbackStopped = true;
    await silenceMediaKitPlayer(_player);
  }

  /// Full stop+dispose with timeouts after the route is gone.
  Future<void> _teardownMediaKitPlayer(Player player) async {
    _playbackStopped = true;
    await teardownMediaKitPlayer(player);
  }
}
