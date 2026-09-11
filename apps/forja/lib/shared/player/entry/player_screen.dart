import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/foundation/blocks/play/play_hooks.dart';
import 'package:forja/shared/player/platform/external_player_service.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';
import 'package:forja/shared/player/entry/external_player_handoff_screen.dart';
import 'package:forja/shared/player/screens/exo_player_screen.dart';
import 'package:forja/shared/player/screens/mobile_player_screen.dart';
import 'package:forja/shared/player/screens/tv_player_screen.dart';
import 'package:forja/shared/player/screens/desktop_player_screen.dart';

import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/foundation/components/playback/stream_provider_probe.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/player/platform/mpv_exclusive_session.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:forja/shared/shell/loading_overlay.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_theme.dart';
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String? audioUrl;
  final String title;
  final String? magnetLink;
  final Map<String, String>? headers;
  final Movie? movie;
  final Map<String, dynamic>? providers;
  final String? activeProvider;
  final int? selectedSeason;
  final int? selectedEpisode;
  final Duration? startPosition;
  final List<StreamSource>? sources;
  final int? fileIndex;
  final List<Map<String, dynamic>>? externalSubtitles;
  final String? stremioId;
  final String? stremioAddonBaseUrl;

  /// External next-episode handler. When provided, the in-player "Next
  /// Episode" button will route through this callback instead of running the
  /// built-in TMDB / torrent / webstreaming resolution. Used by anime so the
  /// resolver can re-race all sources for the next episode.
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;

  /// Hub players (anime, Asian drama): flat episode list + switch handler.
  final List<PlayerKitEpisode>? episodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerKitEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;

  /// Forja Auto session — next/prev reuses [switchEpisodeViaEngineAutoPlay].
  final EnginePlaySession? enginePlaySession;

  /// Optional progress save hook. Called by the inner player when the
  /// watch history should be persisted (lifecycle pause, periodic tick,
  /// player exit). Used by anime / arabic flows that own their own
  /// per-source history store and don't go through `WatchHistoryService`.
  final Future<void> Function(Duration position, Duration duration)?
  onSaveProgress;
  final Future<void> Function(String sourceUrl, String sourceTitle)?
  onSourcePinned;
  final bool pinSource;
  /// Sources were probed before open (RFC-038 simple resolve) - skip re-probe
  /// and do not Auto re-race when the list is exhausted.
  final bool streamsPrevalidated;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final ValueNotifier<List<StreamSource>>? sourcesListNotifier;
  final ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    this.audioUrl,
    required this.title,
    this.magnetLink,
    this.headers,
    this.movie,
    this.providers,
    this.activeProvider,
    this.selectedSeason,
    this.selectedEpisode,
    this.startPosition,
    this.sources,
    this.fileIndex,
    this.externalSubtitles,
    this.stremioId,
    this.stremioAddonBaseUrl,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.episodes,
    this.hubEpisodeNumber,
    this.onHubEpisodeSelected,
    this.episodeOverview,
    this.enginePlaySession,
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
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _useExternalPlayer = false;
  bool _externalLaunched = false;
  bool _checkingPlayer = true;
  String _externalPlayerName = '';
  String? _externalStreamUrl;
  Map<String, String>? _externalHeaders;
  BuiltInPlayerEngine _builtInEngine = BuiltInPlayerEngine.platformDefault();
  /// True while MediaKit is unmounted and Exo (or the reverse) is not ready —
  /// avoids mounting Exo over a live `mediacodec_embed` surface (issue 129).
  bool _switchingBuiltInEngine = false;
  Duration? _resumePosition;

  /// Live playback session - updated when the user switches server/source in-player
  /// or hands off to an external app. Survives external ↔ built-in toggles.
  late String _sessionStreamUrl;
  String? _sessionActiveProvider;
  List<StreamSource>? _sessionSources;
  Map<String, String>? _sessionHeaders;

  Duration get _effectiveStartPosition =>
      _resumePosition ?? widget.startPosition ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    ShellBus.enterPlayerSurface();
    _sessionStreamUrl = widget.streamUrl;
    _sessionActiveProvider = widget.activeProvider;
    _sessionSources = widget.sources;
    _sessionHeaders = widget.headers;
    _checkPlayerSettings();
  }

  void _applyPlaybackSession({
    String? streamUrl,
    Map<String, String>? headers,
    String? activeProvider,
    List<StreamSource>? sources,
  }) {
    if (streamUrl != null && streamUrl.isNotEmpty) {
      _sessionStreamUrl = streamUrl;
    }
    if (headers != null) _sessionHeaders = headers;
    if (activeProvider != null && activeProvider.isNotEmpty) {
      _sessionActiveProvider = activeProvider;
    }
    if (sources != null && sources.isNotEmpty) {
      _sessionSources = sources;
    }
  }

  Future<void> _checkPlayerSettings() async {
    var engine = await SettingsService().getBuiltInPlayerEngine(
      context: BuiltInPlayerContext.vod,
    );
    // DRM streams need Android Exo Widevine — force Exo when any session source
    // (or the primary URL row) carries a license config (RFC-101).
    if (Platform.isAndroid && _sessionNeedsWidevine()) {
      engine = BuiltInPlayerEngine.exoPlayer;
    }

    if (!mounted) return;

    setState(() {
      _useExternalPlayer = false;
      _builtInEngine = engine;
      _checkingPlayer = false;
    });
  }

  bool _sessionNeedsWidevine() {
    final sources = _sessionSources;
    if (sources != null) {
      for (final s in sources) {
        if (s.hasDrm) return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    ShellBus.leavePlayerSurface();
    site111477_proxy.retainForExternalHandoff = false;
    TorrentStreamService().retainForExternalHandoff = false;
    if (site111477_proxy.is111477ProxyRunning) {
      unawaited(site111477_proxy.stop111477Proxy(force: true));
    }
    final torrentId = widget.magnetLink ?? _sessionStreamUrl;
    if (widget.magnetLink != null ||
        isLocalTorrentStreamUrl(_sessionStreamUrl)) {
      TorrentStreamService().removeTorrent(torrentId);
    }
    // LAN close is fired from [_exitPlayer] / deferred helper — not here.
    // Starting prefs+HTTP in the same dispose as MediaKit teardown ANRs ATV.
    super.dispose();
  }

  Future<bool> _launchExternal() async {
    if (_externalPlayerName.isEmpty) return false;

    final success = await ExternalPlayerService.launch(
      url: _externalStreamUrl ?? _sessionStreamUrl,
      title: widget.title,
      headers: _externalHeaders ?? _sessionHeaders,
      context: context,
      playerName: _externalPlayerName,
    );

    if (!mounted) return false;

    if (success) {
      setState(() => _externalLaunched = true);
      return true;
    }
    // Player not found - fall back to built-in player
    ForjaToast.warning(
      '$_externalPlayerName not found. Using built-in player.',
    );
    setState(() {
      _useExternalPlayer = false;
      _externalLaunched = false;
    });
    return false;
  }

  Future<void> _persistHandoffProgress(
    Duration position, {
    String? streamUrl,
    String? activeProvider,
  }) async {
    final movie = widget.movie;
    if (movie == null || position.inMilliseconds < 5000) return;
    if (!usesHomeWatchHistory(
      movie: movie,
      episodes: widget.episodes,
      onSaveProgress: widget.onSaveProgress,
      playSession: widget.enginePlaySession,
    )) {
      return;
    }
    final url = streamUrl ?? _externalStreamUrl ?? _sessionStreamUrl;
    if (url.isEmpty) return;
    final provider = activeProvider ?? _sessionActiveProvider;
    await WatchHistoryService().saveProgress(
      tmdbId: movie.id,
      imdbId: movie.imdbId,
      title: widget.title,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      method: provider != null && provider != 'amri' ? 'stream' : 'amri',
      sourceId: provider ?? url,
      position: position.inMilliseconds,
      duration: 0,
      season: widget.selectedSeason,
      episode: widget.selectedEpisode,
      streamUrl: url,
      mediaType: movie.mediaType,
    );
  }

  Future<void> _switchPlayer(
    Duration resumePosition, {
    BuiltInPlayerEngine? builtInEngine,
    String? externalPlayer,
    String? streamUrl,
    Map<String, String>? headers,
    String? activeProvider,
    List<StreamSource>? sources,
  }) async {
    if (resumePosition > Duration.zero) {
      _resumePosition = resumePosition;
    }
    _applyPlaybackSession(
      streamUrl: streamUrl,
      headers: headers,
      activeProvider: activeProvider,
      sources: sources,
    );

    if (externalPlayer != null) {
      final handoffUrl = streamUrl ?? _sessionStreamUrl;
      if (widget.magnetLink != null || isLocalTorrentStreamUrl(handoffUrl)) {
        TorrentStreamService().retainForExternalHandoff = true;
      }
      site111477_proxy.retainForExternalHandoff = true;
      if (!mounted) return;
      setState(() {
        _useExternalPlayer = true;
        _externalPlayerName = externalPlayer;
        _externalLaunched = false;
        _externalStreamUrl = handoffUrl;
        _externalHeaders = headers ?? _sessionHeaders;
      });
      final launched = await _launchExternal();
      if (launched) {
        await _persistHandoffProgress(
          resumePosition,
          streamUrl: streamUrl ?? _externalStreamUrl,
          activeProvider: activeProvider ?? _sessionActiveProvider,
        );
      }
      return;
    }

    site111477_proxy.retainForExternalHandoff = false;
    TorrentStreamService().retainForExternalHandoff = false;
    if (site111477_proxy.is111477ProxyRunning) {
      await site111477_proxy.stop111477Proxy(force: true);
    }

    if (builtInEngine == null) return;
    if (builtInEngine == _builtInEngine && !_useExternalPlayer) return;

    await SettingsService().setBuiltInPlayerEngine(
      builtInEngine,
      context: BuiltInPlayerContext.vod,
    );
    if (!mounted) return;

    // Unmount the current engine (spinner), cool down the surface, then mount
    // the new one. Instant MediaKit→Exo left Exo TextureView zoomed/cropped
    // (issue 129). Awaiting full MediaKit dispose on the UI isolate ANRs
    // physical ATV (issue 128) — cap that wait on Android for both directions.
    setState(() {
      _useExternalPlayer = false;
      _switchingBuiltInEngine = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      // Android: never wait past the ~5s input ANR window. Dart timeouts do not
      // fire while FFI is stuck, so keep the wait short and always remount.
      // MediaKit mounts used to wait 5s (issue 128 T07); stuck stop/dispose still
      // froze on `[LAN] release skip` → SIGQUIT (T09). Cap both directions.
      final prepareTimeout = Platform.isAndroid
          ? const Duration(milliseconds: 1200)
          : (builtInEngine == BuiltInPlayerEngine.mediaKit
              ? const Duration(seconds: 5)
              : const Duration(milliseconds: 1200));
      try {
        await MpvExclusiveSession.instance
            .prepareForVideoPlayer(timeout: prepareTimeout)
            .timeout(prepareTimeout + const Duration(milliseconds: 300));
      } catch (_) {}
      // Wall-clock only — do not await MediaKit FFI (ANR, issue 128). Gives
      // MediaCodec time to detach before Exo TextureView binds (issue 129).
      if (builtInEngine == BuiltInPlayerEngine.exoPlayer &&
          Platform.isAndroid) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      if (builtInEngine == BuiltInPlayerEngine.mediaKit &&
          !Platform.isAndroid) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      if (mounted) {
        setState(() {
          _builtInEngine = builtInEngine;
          _switchingBuiltInEngine = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking settings, or mid MediaKit↔Exo swap (surface must be gone).
    if (_checkingPlayer || _switchingBuiltInEngine) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = Navigator.of(context, rootNavigator: true);
          dismissActiveLoadingOverlayRoute(nav);
          if (nav.canPop()) nav.pop();
        },
        child: Scaffold(
          backgroundColor: DesignTokens.bgDark,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: ForjaShellColors.brandGreen),
                if (_switchingBuiltInEngine) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Switching player…',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // External player mode - show a "playing externally" screen
    if (_useExternalPlayer) {
      return ExternalPlayerHandoffScreen(
        title: widget.title,
        playerName: _externalPlayerName,
        launched: _externalLaunched,
        builtInEngine: _builtInEngine,
        onRelaunch: _launchExternal,
        onSwitchBuiltIn: () async {
          site111477_proxy.retainForExternalHandoff = false;
          TorrentStreamService().retainForExternalHandoff = false;
          if (site111477_proxy.is111477ProxyRunning) {
            unawaited(site111477_proxy.stop111477Proxy(force: true));
          }
          final movie = widget.movie;
          if (movie != null) {
            final progress = await WatchHistoryService().getProgress(
              movie.id,
              season: widget.selectedSeason,
              episode: widget.selectedEpisode,
            );
            final posMs = progress?['position'] as int? ?? 0;
            if (posMs > 0) {
              _resumePosition = Duration(milliseconds: posMs);
            }
          }
          if (!mounted) return;
          setState(() {
            _useExternalPlayer = false;
            _externalLaunched = false;
            _externalStreamUrl = null;
            _externalHeaders = null;
          });
        },
        onSelectPlayer: ({builtInEngine, externalPlayer}) => _switchPlayer(
          Duration.zero,
          builtInEngine: builtInEngine,
          externalPlayer: externalPlayer,
          streamUrl: _externalStreamUrl ?? _sessionStreamUrl,
          headers: _externalHeaders ?? _sessionHeaders,
          activeProvider: _sessionActiveProvider,
          sources: _sessionSources,
        ),
      );
    }

    // Built-in player - Android defaults to ExoPlayer; MediaKit is optional.
    if (Platform.isAndroid && PlatformInfo.isAndroidTv) {
      if (_builtInEngine == BuiltInPlayerEngine.exoPlayer) {
        return ExoPlayerScreen(
          key: ValueKey(
            'exo_tv_${_builtInEngine.name}_${_sessionActiveProvider}_${_sessionStreamUrl.hashCode}',
          ),
          mediaPath: _sessionStreamUrl,
          title: widget.title,
          audioUrl: widget.audioUrl,
          headers: _sessionHeaders,
          movie: widget.movie,
          selectedSeason: widget.selectedSeason,
          selectedEpisode: widget.selectedEpisode,
          magnetLink: widget.magnetLink,
          activeProvider: _sessionActiveProvider,
          startPosition: _effectiveStartPosition,
          sources: _sessionSources,
          fileIndex: widget.fileIndex,
          externalSubtitles: widget.externalSubtitles,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          episodes: widget.episodes,
          hubEpisodeNumber: widget.hubEpisodeNumber,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          episodeOverview: widget.episodeOverview,
          enginePlaySession: widget.enginePlaySession,
          providers: widget.providers,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          onSaveProgress: widget.onSaveProgress,
          onPlaybackStarted: widget.onPlaybackStarted,
          onAllSourcesExhausted: widget.onAllSourcesExhausted,
          pinSource: widget.pinSource,
          streamsPrevalidated: widget.streamsPrevalidated,
          onReloadStreams: widget.onReloadStreams,
          builtInEngine: _builtInEngine,
          onSwitchPlayer: _switchPlayer,
        );
      }
      return TvPlayerScreen(
        key: ValueKey(
          'mk_tv_${_builtInEngine.name}_${_sessionActiveProvider}_${_sessionStreamUrl.hashCode}',
        ),
        mediaPath: _sessionStreamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: _sessionHeaders,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: _sessionActiveProvider,
        startPosition: _effectiveStartPosition,
        sources: _sessionSources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        episodes: widget.episodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
          enginePlaySession: widget.enginePlaySession,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
        streamsPrevalidated: widget.streamsPrevalidated,
        onPlaybackStarted: widget.onPlaybackStarted,
        onAllSourcesExhausted: widget.onAllSourcesExhausted,
        onReloadStreams: widget.onReloadStreams,
        sourcesListNotifier: widget.sourcesListNotifier,
        providerSourcesCache: widget.providerSourcesCache,
        providerProbesNotifier: widget.providerProbesNotifier,
        builtInEngine: _builtInEngine,
        onSwitchPlayer: _switchPlayer,
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid &&
          _builtInEngine == BuiltInPlayerEngine.exoPlayer) {
        return ExoPlayerScreen(
          key: ValueKey(
            'exo_${_builtInEngine.name}_${_sessionActiveProvider}_${_sessionStreamUrl.hashCode}',
          ),
          mediaPath: _sessionStreamUrl,
          title: widget.title,
          audioUrl: widget.audioUrl,
          headers: _sessionHeaders,
          movie: widget.movie,
          selectedSeason: widget.selectedSeason,
          selectedEpisode: widget.selectedEpisode,
          magnetLink: widget.magnetLink,
          activeProvider: _sessionActiveProvider,
          startPosition: _effectiveStartPosition,
          sources: _sessionSources,
          fileIndex: widget.fileIndex,
          externalSubtitles: widget.externalSubtitles,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          episodes: widget.episodes,
          hubEpisodeNumber: widget.hubEpisodeNumber,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          episodeOverview: widget.episodeOverview,
          enginePlaySession: widget.enginePlaySession,
          providers: widget.providers,
          stremioId: widget.stremioId,
          stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
          onSaveProgress: widget.onSaveProgress,
          onPlaybackStarted: widget.onPlaybackStarted,
          onAllSourcesExhausted: widget.onAllSourcesExhausted,
          pinSource: widget.pinSource,
          streamsPrevalidated: widget.streamsPrevalidated,
          onReloadStreams: widget.onReloadStreams,
          builtInEngine: _builtInEngine,
          onSwitchPlayer: _switchPlayer,
        );
      }
      return MobilePlayerScreen(
        key: ValueKey(
          'mk_${_builtInEngine.name}_${_sessionActiveProvider}_${_sessionStreamUrl.hashCode}',
        ),
        mediaPath: _sessionStreamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: _sessionHeaders,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: _sessionActiveProvider,
        startPosition: _effectiveStartPosition,
        sources: _sessionSources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        episodes: widget.episodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
          enginePlaySession: widget.enginePlaySession,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
        streamsPrevalidated: widget.streamsPrevalidated,
        onPlaybackStarted: widget.onPlaybackStarted,
        onAllSourcesExhausted: widget.onAllSourcesExhausted,
        onReloadStreams: widget.onReloadStreams,
        sourcesListNotifier: widget.sourcesListNotifier,
        providerSourcesCache: widget.providerSourcesCache,
        providerProbesNotifier: widget.providerProbesNotifier,
        builtInEngine: _builtInEngine,
        onSwitchPlayer: _switchPlayer,
      );
    } else {
      return DesktopPlayerScreen(
        key: ValueKey(
          'desktop_${_builtInEngine.name}_${_sessionActiveProvider}_${_sessionStreamUrl.hashCode}',
        ),
        mediaPath: _sessionStreamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: _sessionHeaders,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: _sessionActiveProvider,
        startPosition: _effectiveStartPosition,
        sources: _sessionSources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        episodes: widget.episodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
          enginePlaySession: widget.enginePlaySession,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
        streamsPrevalidated: widget.streamsPrevalidated,
        onPlaybackStarted: widget.onPlaybackStarted,
        onAllSourcesExhausted: widget.onAllSourcesExhausted,
        onReloadStreams: widget.onReloadStreams,
        sourcesListNotifier: widget.sourcesListNotifier,
        providerSourcesCache: widget.providerSourcesCache,
        providerProbesNotifier: widget.providerProbesNotifier,
        builtInEngine: _builtInEngine,
        onSwitchPlayer: _switchPlayer,
      );
    }
  }
}
