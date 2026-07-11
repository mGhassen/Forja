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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: Color(0xFF7C3AED),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  launched ? 'Playing in $playerName' : 'Launching $playerName...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Info text
                Text(
                  launched
                      ? 'The stream is being kept alive.\nYou can go back when you\'re done watching.'
                      : 'Opening the video in the external player...',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Action buttons
                if (launched) ...[
                  // Re-launch button
                  SizedBox(
                    width: 260,
                    child: OutlinedButton.icon(
                      onPressed: onRelaunch,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text('Re-launch in $playerName'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (onChangePlayer != null)
                    SizedBox(
                      width: 260,
                      child: OutlinedButton.icon(
                        onPressed: onChangePlayer,
                        icon: const Icon(Icons.smart_display_outlined, size: 20),
                        label: const Text('Change player'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (onChangePlayer != null) const SizedBox(height: 12),

                  // Switch to built-in button
                  SizedBox(
                    width: 260,
                    child: TextButton.icon(
                      onPressed: onSwitchBuiltIn,
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: const Text('Use Built-in Player Instead'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Back button
                SizedBox(
                  width: 260,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
