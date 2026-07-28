import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_app_menu.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player/mobile_player_screen.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:rust/rust.dart';

/// Android TV player - [MobilePlayerScreen] with D-pad focus traversal on chrome.
class TvPlayerScreen extends StatelessWidget {
  const TvPlayerScreen({
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
  final bool streamsPrevalidated;
  final VoidCallback? onPlaybackStarted;
  final VoidCallback? onAllSourcesExhausted;
  final Future<List<StreamSource>?> Function()? onReloadStreams;
  final ValueNotifier<List<StreamSource>>? sourcesListNotifier;
  final ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final BuiltInPlayerEngine builtInEngine;
  final PlayerSwitchHandler? onSwitchPlayer;

  @override
  Widget build(BuildContext context) {
    return MobilePlayerScreen(
      mediaPath: mediaPath,
      title: title,
      audioUrl: audioUrl,
      headers: headers,
      movie: movie,
      selectedSeason: selectedSeason,
      selectedEpisode: selectedEpisode,
      magnetLink: magnetLink,
      activeProvider: activeProvider,
      startPosition: startPosition,
      sources: sources,
      fileIndex: fileIndex,
      externalSubtitles: externalSubtitles,
      stremioId: stremioId,
      stremioAddonBaseUrl: stremioAddonBaseUrl,
      providers: providers,
      onNextEpisode: onNextEpisode,
      hasNextEpisode: hasNextEpisode,
      hubEpisodes: hubEpisodes,
      hubEpisodeNumber: hubEpisodeNumber,
      onHubEpisodeSelected: onHubEpisodeSelected,
      episodeOverview: episodeOverview,
      onSaveProgress: onSaveProgress,
      onSourcePinned: onSourcePinned,
      pinSource: pinSource,
      streamsPrevalidated: streamsPrevalidated,
      onPlaybackStarted: onPlaybackStarted,
      onAllSourcesExhausted: onAllSourcesExhausted,
      onReloadStreams: onReloadStreams,
      sourcesListNotifier: sourcesListNotifier,
      providerSourcesCache: providerSourcesCache,
      providerProbesNotifier: providerProbesNotifier,
      builtInEngine: builtInEngine,
      onSwitchPlayer: onSwitchPlayer,
      tvRemoteEnabled: true,
    );
  }
}
