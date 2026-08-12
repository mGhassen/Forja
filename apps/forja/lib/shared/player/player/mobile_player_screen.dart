import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/extractors/providers/vidsrc/vidsrc_extractor.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
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
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/extractors/providers/arabic/arabic_service.dart';
import 'package:forja/shared/player/track_auto_select.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/lan/lan_client_service.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'utils.dart';
import 'package:forja/shared/player/controls/player_menus.dart';
import 'playback_recovery.dart';
import 'playable_source_bridge.dart';
import 'package:forja/shared/services/pip_service.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/parental_guide/parental_guide_overlay.dart';
import 'package:forja/shared/player/controls/player_tv_key_scope.dart';
import 'package:forja/shared/player/controls/player_subtitle_settings_dialog.dart';
import 'package:forja/shared/player/player_metadata.dart';
import 'package:forja/shared/player/player/shared_widgets.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_provider_menu.dart';
import 'package:forja/shared/player/controls/player_episode_menu.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/controls/player_episode_loading_card.dart';
import 'package:forja/shared/player/controls/player_subtitle_menu.dart';
import 'package:forja/shared/player/controls/player_audio_menu.dart';
import 'package:forja/shared/player/controls/player_quality_menu.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_back_exit_gate.dart';
import 'package:forja/shared/player/episode_switch_resolver.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/loading_overlay.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/player/providers/player_prefs_providers.dart';
import 'package:forja/shared/player/providers/player_resolve_providers.dart';

part 'mobile_player_glass.dart';
part 'mobile_player_lifecycle.dart';
part 'mobile_player_playback.dart';
part 'mobile_player_ui.dart';
part 'mobile_player_tracks.dart';
part 'mobile_player_sources.dart';
part 'mobile_player_sources_alt.dart';
part 'mobile_player_sources_settings.dart';
part 'mobile_player_sources_provider.dart';
part 'mobile_player_episodes.dart';
part 'mobile_player_build.dart';
part 'mobile_player_seekbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE PLAYER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MobilePlayerScreen extends ConsumerStatefulWidget {
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
    this.streamsPrevalidated = false,
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
  ConsumerState<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}
class _MobilePlayerScreenState extends ConsumerState<MobilePlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver,
        _MobilePlayerLifecycle,
        _MobilePlayerPlayback,
        _MobilePlayerUi,
        _MobilePlayerTracks,
        _MobilePlayerSources,
        _MobilePlayerSourcesAlt,
        _MobilePlayerSourcesSettings,
        _MobilePlayerSourcesProvider,
        _MobilePlayerEpisodes,
        _MobilePlayerBuild {
  // ── Player ──────────────────────────────────────────────────────────────
  late final Player _player;
  late final VideoController _controller;
  bool _disposed = false;
  bool _playbackStopped = false;
  int _fallbackGen = 0;
  final Map<String, int> _providerLoadGens = {};
  final ValueNotifier<Set<String>> _providerLoadFailures =
      ValueNotifier<Set<String>>({});
  late final ValueNotifier<Map<String, List<StreamSource>>>
      _ownedProviderSourcesCache;
  bool _historySaved = false;
  bool _hasError = false;
  String _errorMessage = '';

  // ── UI State ─────────────────────────────────────────────────────────────
  bool _showControls = true;
  /// Guards re-entrant Back while [_exitPlayer] awaits stop/orientation.
  bool _exitInProgress = false;
  /// MediaKit [Video] mounted — cleared before pop on Android so MediaCodec
  /// surface teardown is not interleaved with route dispose (issue 128 ANR).
  bool _showVideoSurface = true;
  final FocusNode _playFocus = FocusNode(debugLabel: 'player-play');
  final FocusNode _rewindFocus = FocusNode(debugLabel: 'player-rewind');
  final FocusNode _forwardFocus = FocusNode(debugLabel: 'player-forward');
  final FocusNode _seekbarFocus = FocusNode(debugLabel: 'player-seekbar');
  final FocusNode _transportSourcesFocus =
      FocusNode(debugLabel: 'player-transport-sources');
  final FocusNode _transportStreamFocus =
      FocusNode(debugLabel: 'player-transport-stream');
  final FocusNode _transportPrevEpFocus =
      FocusNode(debugLabel: 'player-transport-prev-ep');
  final FocusNode _transportNextEpFocus =
      FocusNode(debugLabel: 'player-transport-next-ep');
  final FocusNode _transportEpisodesFocus =
      FocusNode(debugLabel: 'player-transport-episodes');
  final FocusNode _transportAudioFocus =
      FocusNode(debugLabel: 'player-transport-audio');
  final FocusNode _transportSubsFocus =
      FocusNode(debugLabel: 'player-transport-subs');
  final FocusNode _transportQualityFocus =
      FocusNode(debugLabel: 'player-transport-quality');
  final FocusNode _transportSettingsFocus =
      FocusNode(debugLabel: 'player-transport-settings');
  final FocusNode _backFocus = FocusNode(debugLabel: 'player-back');
  /// First TV Back focused the Back control — next Back exits even before
  /// the post-frame [requestFocus] lands.
  bool _tvBackExitArmed = false;

  void _onTvBackFocusChanged() {
    if (_backFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_backFocus.hasFocus) _tvBackExitArmed = false;
    });
  }

  final FocusNode _playerMenuFocus = FocusNode(debugLabel: 'player-menu');
  final FocusNode _retryFocus = FocusNode(debugLabel: 'player-retry');
  final FocusNode _streamActionFocus = FocusNode(debugLabel: 'player-stream-action');
  final FocusNode _skipChipFocus = FocusNode(debugLabel: 'player-skip-chip');
  final FocusNode _nextEpChipFocus = FocusNode(debugLabel: 'player-next-ep-chip');
  final FocusNode _tvKeyFocus = FocusNode(debugLabel: 'player-tv-keys');
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
  /// Deferred track/subtitle auto-select - cancel on exit so it cannot
  /// touch State after the route is gone.
  Timer? _trackAutoSelectTimer;
  PlaybackRecovery? _playbackRecovery;
  StreamSubscription<bool>? _pipSub;
  bool _autoTracksAppliedForSource = false;
  bool _androidMediaKitSafeMode = false;
  bool _isAndroidTv = false;

  // ── PiP State ─────────────────────────────────────────────────────────────
  bool _isPipMode = false;

  /// True when we paused because the app left the foreground (not user pause).
  /// Resume only if this is set — keeps manual pause across app switch.
  bool _pausedByLifecycle = false;

  // ── Value Notifiers ───────────────────────────────────────────────────────
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

  /// MediaKit on leanback — `vo=mediacodec_embed`, `ao=audiotrack`, softvol
  /// gain. `tvRemoteEnabled` covers [TvPlayerScreen] before the async
  /// `isTelevision` probe lands.
  bool get _tvMediaKit =>
      Platform.isAndroid && (widget.tvRemoteEnabled || PlatformInfo.isAndroidTv);

  // ── Gesture State ─────────────────────────────────────────────────────────
  double _volume = 100.0; // 0–150 (mpv supports >100%; 100 = full)
  double _brightness = 0.5; // 0.0..1.0 (screen brightness)
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorHideTimer;

  /// mpv softvol for [_volume] — boosted on TV so MediaKit matches Exo
  /// loudness (issue 152).
  double get _mpvVolume => mpvVolumeForUi(_volume, atvMediaKit: _tvMediaKit);

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
      // Media open resets mpv subtitle - re-apply preferred after the wipe.
      unawaited(_reapplyPreferredSubtitle());
    } else {
      // Keep session mid / first-confirm across source switches for credits
      // re-open; open mid stays cleared above.
      _playbackConfirmedAt = null;
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
  bool _isFetchingSubs = false;
  String? _selectedExternalSubUrl;
  /// Downloaded external subtitle file URIs keyed by source URL - reused when
  /// mpv wipes the track on media open (auto-pick race).
  final Map<String, String> _externalSubFileCache = {};

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
  String _episodeLoadingLabel = '';
  String _episodeLoadingStatus = '';
  bool _episodeLoadingFailed = false;
  bool _nearEndOfEpisode = false;
  bool _hasPrevEpisodeAdjacent = false;
  bool _hasNextEpisodeAdjacent = false;

  // ── Skip Segments (IntroDB) ───────────────────────────────────────────────
  IntroDbResponse? _introDbData;
  String? _activeSkipLabel;
  Duration? _activeSkipTarget;
  bool _skipDismissed = false;

  @override
  void dispose() {
    widget.sourcesListNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onLiveSourcesUpdated);
    widget.providerProbesNotifier?.removeListener(_onProbeScoringChanged);
    // Mark disposed before cancelling/disposing notifiers so in-flight
    // `_initPlayback` / mark-failed paths bail out instead of writing
    // to a disposed ValueNotifier.
    _disposed = true;
    PlayerBackExitGate.setTryFocusBack(null);
    _cancelPendingStreamWork();
    _providerLoadFailures.dispose();
    if (widget.providerSourcesCache == null) {
      _ownedProviderSourcesCache.dispose();
    }
    _saveWatchHistory();

    // Restore screen brightness to system default (mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        ScreenBrightness().resetApplicationScreenBrightness();
      } catch (_) {}
    }

    // Don't set orientation here - _exitPlayer() already locks portrait
    // BEFORE popping.  Changing orientation during dispose while
    // media_kit's surface is being torn down causes BLASTBufferQueue
    // errors and hundreds of dropped frames.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _playFocus.dispose();
    _rewindFocus.dispose();
    _forwardFocus.dispose();
    _seekbarFocus.dispose();
    _transportSourcesFocus.dispose();
    _transportStreamFocus.dispose();
    _transportPrevEpFocus.dispose();
    _transportNextEpFocus.dispose();
    _transportEpisodesFocus.dispose();
    _transportAudioFocus.dispose();
    _transportSubsFocus.dispose();
    _transportQualityFocus.dispose();
    _transportSettingsFocus.dispose();
    _backFocus.removeListener(_onTvBackFocusChanged);
    _backFocus.dispose();
    _playerMenuFocus.dispose();
    _retryFocus.dispose();
    _streamActionFocus.dispose();
    _skipChipFocus.dispose();
    _nextEpChipFocus.dispose();
    _tvKeyFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _indicatorHideTimer?.cancel();
    _trackAutoSelectTimer?.cancel();
    _trackAutoSelectTimer = null;
    PlayerSubtitleSettingsDialog.dismissIfShowing();
    PlayerTorrentFilePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    playerMenuClearReturnFocus();
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

    unawaited(_teardownMediaKitPlayer());

    // Remove torrent from engine on player exit (use magnetLink for hash,
    // fall back to mediaPath which may be a stream URL).
    if (!TorrentStreamService().retainForExternalHandoff) {
      final torrentId = widget.magnetLink ?? widget.mediaPath;
      TorrentStreamService().removeTorrent(torrentId);
      // [_exitPlayer] already scheduled LAN close; this covers forced pops.
      if (!_exitInProgress) {
        LanClientService.instance.releaseLanTorrentIfNeeded(
          playUrl: _currentUrl ?? widget.mediaPath,
          magnet: _activeMagnet ?? widget.magnetLink,
        );
      }
    }

    // Tear down the 111477 proxy and delete its on-disk cache.
    if (site111477_proxy.is111477ProxyRunning) {
      // Fire-and-forget - dispose() can't be async.
      site111477_proxy.stop111477Proxy();
    }

    WakelockPlus.disable();

    super.dispose();
  }

  /// Instant silence before orientation / route pop.
  Future<void> _stopPlaybackForExit() async {
    if (_playbackStopped) return;
    _playbackStopped = true;
    await silenceMediaKitPlayer(_player);
  }

  /// Full stop+dispose with timeouts after the route is gone.
  Future<void> _teardownMediaKitPlayer() async {
    _playbackStopped = true;
    MpvExclusiveSession.instance.untrackPlayer(_player);
    // Exit-only fast path on Android — full timeouts on hot-swap (issue 128).
    final disposeFuture = teardownMediaKitPlayer(
      _player,
      fast: _exitInProgress && Platform.isAndroid,
    );
    MpvExclusiveSession.instance.trackVideoDispose(disposeFuture);
    await disposeFuture;
  }
}
