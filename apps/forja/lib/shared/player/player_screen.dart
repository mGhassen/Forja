import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/services/external_player_service.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player/exo_player_screen.dart';
import 'package:forja/shared/player/player/mobile_player_screen.dart';
import 'package:forja/shared/player/player/tv_player_screen.dart';
import 'package:forja/shared/player/player/desktop_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:google_fonts/google_fonts.dart';

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
  /// built-in TMDB / torrent / WebStreamr resolution. Used by anime so the
  /// resolver can re-race all sources for the next episode.
  final Future<void> Function()? onNextEpisode;
  final bool hasNextEpisode;

  /// Hub players (anime, Asian drama): flat episode list + switch handler.
  final List<PlayerHubEpisode>? hubEpisodes;
  final num? hubEpisodeNumber;
  final Future<void> Function(PlayerHubEpisode episode)? onHubEpisodeSelected;
  final String? episodeOverview;

  /// Optional progress save hook. Called by the inner player when the
  /// watch history should be persisted (lifecycle pause, periodic tick,
  /// player exit). Used by anime / arabic flows that own their own
  /// per-source history store and don't go through `WatchHistoryService`.
  final Future<void> Function(Duration position, Duration duration)? onSaveProgress;
  final Future<void> Function(String sourceUrl, String sourceTitle)? onSourcePinned;
  final bool pinSource;
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
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _useExternalPlayer = false;
  bool _externalLaunched = false;
  bool _checkingPlayer = true;
  String _externalPlayerName = '';
  BuiltInPlayerEngine _builtInEngine = BuiltInPlayerEngine.platformDefault();
  Duration? _resumePosition;

  Duration get _effectiveStartPosition =>
      _resumePosition ?? widget.startPosition ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkPlayerSettings();
  }

  Future<void> _checkPlayerSettings() async {
    final playerName = await SettingsService().getExternalPlayer();
    final engine = await SettingsService().getBuiltInPlayerEngine();
    final isExternal = playerName != 'Built-in Player';

    if (!mounted) return;

    if (isExternal) {
      setState(() {
        _useExternalPlayer = true;
        _externalPlayerName = playerName;
        _builtInEngine = engine;
        _checkingPlayer = false;
      });
      _launchExternal();
    } else {
      setState(() {
        _useExternalPlayer = false;
        _builtInEngine = engine;
        _checkingPlayer = false;
      });
    }
  }

  Future<void> _launchExternal() async {
    final success = await ExternalPlayerService.launch(
      url: widget.streamUrl,
      title: widget.title,
      headers: widget.headers,
      context: context,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _externalLaunched = true);
    } else {
      // Player not found — fall back to built-in player
      ForjaToast.warning('$_externalPlayerName not found. Using built-in player.');
      setState(() {
        _useExternalPlayer = false;
        _externalLaunched = false;
      });
    }
  }

  Future<void> _switchPlayer(
    Duration resumePosition, {
    BuiltInPlayerEngine? builtInEngine,
    String? externalPlayer,
  }) async {
    if (resumePosition > Duration.zero) {
      _resumePosition = resumePosition;
    }

    if (externalPlayer != null) {
      await SettingsService().setExternalPlayer(externalPlayer);
      if (!mounted) return;
      setState(() {
        _useExternalPlayer = true;
        _externalPlayerName = externalPlayer;
      });
      await _launchExternal();
      return;
    }

    if (builtInEngine == null) return;

    await SettingsService().setExternalPlayer('Built-in Player');
    await SettingsService().setBuiltInPlayerEngine(builtInEngine);
    if (!mounted) return;
    setState(() {
      _useExternalPlayer = false;
      _builtInEngine = builtInEngine;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Still checking settings
    if (_checkingPlayer) {
      return Scaffold(
        backgroundColor: DesignTokens.bgDark,
        body: Center(
          child: CircularProgressIndicator(
            color: ForjaShellColors.brandGreen,
          ),
        ),
      );
    }

    // External player mode — show a "playing externally" screen
    if (_useExternalPlayer) {
      return _ExternalPlayerWaitScreen(
        title: widget.title,
        playerName: _externalPlayerName,
        streamUrl: widget.streamUrl,
        launched: _externalLaunched,
        onRelaunch: _launchExternal,
        onSwitchBuiltIn: () {
          setState(() {
            _useExternalPlayer = false;
            _externalLaunched = false;
          });
        },
        onChangePlayer: () {
          PlayerAppMenu.show(
            context,
            usingBuiltIn: false,
            builtInEngine: _builtInEngine,
            externalPlayerName: _externalPlayerName,
            onSelect: ({builtInEngine, externalPlayer}) => _switchPlayer(
              Duration.zero,
              builtInEngine: builtInEngine,
              externalPlayer: externalPlayer,
            ),
          );
        },
      );
    }

    // Built-in player — Android TV defaults to ExoPlayer (media_kit EGL fails on TV).
    if (Platform.isAndroid && PlatformInfo.isAndroidTv) {
      if (_builtInEngine == BuiltInPlayerEngine.exoPlayer) {
        return ExoPlayerScreen(
          key: ValueKey('exo_tv_${_builtInEngine.name}'),
          mediaPath: widget.streamUrl,
          title: widget.title,
          audioUrl: widget.audioUrl,
          headers: widget.headers,
          movie: widget.movie,
          selectedSeason: widget.selectedSeason,
          selectedEpisode: widget.selectedEpisode,
          magnetLink: widget.magnetLink,
          activeProvider: widget.activeProvider,
          startPosition: _effectiveStartPosition,
          sources: widget.sources,
          fileIndex: widget.fileIndex,
          externalSubtitles: widget.externalSubtitles,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          hubEpisodes: widget.hubEpisodes,
          hubEpisodeNumber: widget.hubEpisodeNumber,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          episodeOverview: widget.episodeOverview,
          onSaveProgress: widget.onSaveProgress,
          onPlaybackStarted: widget.onPlaybackStarted,
          onAllSourcesExhausted: widget.onAllSourcesExhausted,
          builtInEngine: _builtInEngine,
          onSwitchPlayer: _switchPlayer,
        );
      }
      return TvPlayerScreen(
        mediaPath: widget.streamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: widget.headers,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: widget.activeProvider,
        startPosition: _effectiveStartPosition,
        sources: widget.sources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        hubEpisodes: widget.hubEpisodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
        onPlaybackStarted: widget.onPlaybackStarted,
        onAllSourcesExhausted: widget.onAllSourcesExhausted,
        onReloadStreams: widget.onReloadStreams,
        sourcesListNotifier: widget.sourcesListNotifier,
        providerSourcesCache: widget.providerSourcesCache,
        providerProbesNotifier: widget.providerProbesNotifier,
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid &&
          _builtInEngine == BuiltInPlayerEngine.exoPlayer) {
        return ExoPlayerScreen(
          key: ValueKey('exo_${_builtInEngine.name}'),
          mediaPath: widget.streamUrl,
          title: widget.title,
          audioUrl: widget.audioUrl,
          headers: widget.headers,
          movie: widget.movie,
          selectedSeason: widget.selectedSeason,
          selectedEpisode: widget.selectedEpisode,
          magnetLink: widget.magnetLink,
          activeProvider: widget.activeProvider,
          startPosition: _effectiveStartPosition,
          sources: widget.sources,
          fileIndex: widget.fileIndex,
          externalSubtitles: widget.externalSubtitles,
          onNextEpisode: widget.onNextEpisode,
          hasNextEpisode: widget.hasNextEpisode,
          hubEpisodes: widget.hubEpisodes,
          hubEpisodeNumber: widget.hubEpisodeNumber,
          onHubEpisodeSelected: widget.onHubEpisodeSelected,
          episodeOverview: widget.episodeOverview,
          onSaveProgress: widget.onSaveProgress,
          onPlaybackStarted: widget.onPlaybackStarted,
          onAllSourcesExhausted: widget.onAllSourcesExhausted,
          builtInEngine: _builtInEngine,
          onSwitchPlayer: _switchPlayer,
        );
      }
      return MobilePlayerScreen(
        key: ValueKey('mk_${_builtInEngine.name}'),
        mediaPath: widget.streamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: widget.headers,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: widget.activeProvider,
        startPosition: _effectiveStartPosition,
        sources: widget.sources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        hubEpisodes: widget.hubEpisodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
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
        key: ValueKey('desktop_${_builtInEngine.name}'),
        mediaPath: widget.streamUrl,
        title: widget.title,
        audioUrl: widget.audioUrl,
        headers: widget.headers,
        movie: widget.movie,
        selectedSeason: widget.selectedSeason,
        selectedEpisode: widget.selectedEpisode,
        magnetLink: widget.magnetLink,
        activeProvider: widget.activeProvider,
        startPosition: _effectiveStartPosition,
        sources: widget.sources,
        fileIndex: widget.fileIndex,
        externalSubtitles: widget.externalSubtitles,
        stremioId: widget.stremioId,
        stremioAddonBaseUrl: widget.stremioAddonBaseUrl,
        providers: widget.providers,
        onNextEpisode: widget.onNextEpisode,
        hasNextEpisode: widget.hasNextEpisode,
        hubEpisodes: widget.hubEpisodes,
        hubEpisodeNumber: widget.hubEpisodeNumber,
        onHubEpisodeSelected: widget.onHubEpisodeSelected,
        episodeOverview: widget.episodeOverview,
        onSaveProgress: widget.onSaveProgress,
        onSourcePinned: widget.onSourcePinned,
        pinSource: widget.pinSource,
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

// ─────────────────────────────────────────────────────────────────────────────
//  EXTERNAL PLAYER WAIT SCREEN
//
//  Shown while the video is playing in an external app. Keeps the app alive
//  (and the torrent engine streaming) while the user watches elsewhere.
// ─────────────────────────────────────────────────────────────────────────────

class _ExternalPlayerWaitScreen extends StatelessWidget {
  final String title;
  final String playerName;
  final String streamUrl;
  final bool launched;
  final VoidCallback onRelaunch;
  final VoidCallback onSwitchBuiltIn;
  final VoidCallback? onChangePlayer;

  const _ExternalPlayerWaitScreen({
    required this.title,
    required this.playerName,
    required this.streamUrl,
    required this.launched,
    required this.onRelaunch,
    required this.onSwitchBuiltIn,
    this.onChangePlayer,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return Scaffold(
      backgroundColor: DesignTokens.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: isDesktop ? 16 : 8,
              left: 16,
              child: ForjaPlainIcon(
                icon: Icons.chevron_left_rounded,
                size: 28,
                color: ForjaShellColors.textPrimary,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ForjaShellColors.sectionIconBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: ForjaShellColors.borderSubtle),
                        ),
                        child: launched
                            ? Icon(
                                Icons.open_in_new_rounded,
                                color: ForjaShellColors.iconActive,
                                size: 32,
                              )
                            : Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: ForjaShellColors.brandGreen,
                                ),
                              ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        launched
                            ? 'Playing in $playerName'
                            : 'Launching $playerName…',
                        style: GoogleFonts.inter(
                          color: ForjaShellColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        launched
                            ? 'The stream is being kept alive.\nYou can go back when you\'re done watching.'
                            : 'Opening the video in the external player…',
                        style: GoogleFonts.inter(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.85),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (launched) ...[
                        const SizedBox(height: 36),
                        Center(
                          child: HeroPillPlayButton(
                            label: 'Re-launch in $playerName',
                            icon: Icons.refresh_rounded,
                            tone: HeroPillPlayTone.secondary,
                            onTap: onRelaunch,
                          ),
                        ),
                        if (onChangePlayer != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: HeroPillPlayButton(
                              label: 'Change player',
                              icon: Icons.smart_display_outlined,
                              tone: HeroPillPlayTone.secondary,
                              onTap: onChangePlayer,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ForjaGhostButton(
                          label: 'Use built-in player instead',
                          icon: Icons.play_circle_outline_rounded,
                          onTap: onSwitchBuiltIn,
                        ),
                      ],
                      const SizedBox(height: 28),
                      Center(
                        child: HeroPillPlayButton(
                          label: 'Go back',
                          icon: Icons.arrow_back_rounded,
                          primary: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
