import 'package:flutter/material.dart';
import 'package:api/models/movie.dart';
import 'package:api/models/stream_source.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/home/details_screen.dart';
import 'package:forja/features/home/streaming_details_screen.dart';
import 'package:forja/shared/player/player_screen.dart';

/// Central navigation for cross-feature routes (details, player).
class AppRouter {
  AppRouter._();

  static Future<T?> openDetails<T>(
    BuildContext context, {
    required Movie movie,
    Map<String, dynamic>? stremioItem,
    int? initialSeason,
    int? initialEpisode,
    Duration? startPosition,
  }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsScreen(
          movie: movie,
          stremioItem: stremioItem,
          initialSeason: initialSeason,
          initialEpisode: initialEpisode,
          startPosition: startPosition,
        ),
      ),
    );
  }

  static Future<T?> openStreamingDetails<T>(
    BuildContext context, {
    required Movie movie,
    int? initialSeason,
    int? initialEpisode,
    Duration? startPosition,
  }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => StreamingDetailsScreen(
          movie: movie,
          initialSeason: initialSeason,
          initialEpisode: initialEpisode,
          startPosition: startPosition,
        ),
      ),
    );
  }

  static Future<T?> openMovie<T>(
    BuildContext context, {
    required Movie movie,
    Map<String, dynamic>? stremioItem,
    int? initialSeason,
    int? initialEpisode,
    Duration? startPosition,
  }) async {
    final streaming = await SettingsService().isStreamingModeEnabled();
    if (!context.mounted) return null;
    if (streaming) {
      return openStreamingDetails<T>(
        context,
        movie: movie,
        initialSeason: initialSeason,
        initialEpisode: initialEpisode,
        startPosition: startPosition,
      );
    }
    return openDetails<T>(
      context,
      movie: movie,
      stremioItem: stremioItem,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
    );
  }

  static Future<T?> openPlayer<T>(
    BuildContext context, {
    required String streamUrl,
    String? audioUrl,
    required String title,
    String? magnetLink,
    Map<String, String>? headers,
    Movie? movie,
    Map<String, dynamic>? providers,
    String? activeProvider,
    int? selectedSeason,
    int? selectedEpisode,
    Duration? startPosition,
    List<StreamSource>? sources,
    int? fileIndex,
    List<Map<String, dynamic>>? externalSubtitles,
    String? stremioId,
    String? stremioAddonBaseUrl,
    Future<void> Function()? onNextEpisode,
    bool hasNextEpisode = false,
    Future<void> Function(Duration position, Duration duration)? onSaveProgress,
  }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: streamUrl,
          audioUrl: audioUrl,
          title: title,
          magnetLink: magnetLink,
          headers: headers,
          movie: movie,
          providers: providers,
          activeProvider: activeProvider,
          selectedSeason: selectedSeason,
          selectedEpisode: selectedEpisode,
          startPosition: startPosition,
          sources: sources,
          fileIndex: fileIndex,
          externalSubtitles: externalSubtitles,
          stremioId: stremioId,
          stremioAddonBaseUrl: stremioAddonBaseUrl,
          onNextEpisode: onNextEpisode,
          hasNextEpisode: hasNextEpisode,
          onSaveProgress: onSaveProgress,
        ),
      ),
    );
  }
}
