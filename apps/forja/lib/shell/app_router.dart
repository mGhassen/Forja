import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/home/details_screen.dart';
import 'package:forja/features/home/streaming_details_screen.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/player/trailer_player_screen.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Central navigation for cross-feature routes (details, player).
class AppRouter {
  AppRouter._();

  static Route<T> slideRoute<T>(WidgetBuilder builder) =>
      CupertinoPageRoute<T>(builder: builder);

  static Future<T?> openDetails<T>(
    BuildContext context, {
    required Movie movie,
    Map<String, dynamic>? stremioItem,
    int? initialSeason,
    int? initialEpisode,
    Duration? startPosition,
    bool autoPlay = false,
  }) {
    return pushShellRoute<T>(
      context,
      slideRoute(
        (_) => DetailsScreen(
          movie: movie,
          stremioItem: stremioItem,
          initialSeason: initialSeason,
          initialEpisode: initialEpisode,
          startPosition: startPosition,
          autoPlay: autoPlay,
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
    bool autoPlay = false,
  }) {
    return pushShellRoute<T>(
      context,
      slideRoute(
        (_) => StreamingDetailsScreen(
          movie: movie,
          initialSeason: initialSeason,
          initialEpisode: initialEpisode,
          startPosition: startPosition,
          autoPlay: autoPlay,
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
    bool autoPlay = false,
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
        autoPlay: autoPlay,
      );
    }
    return openDetails<T>(
      context,
      movie: movie,
      stremioItem: stremioItem,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
    );
  }

  static Future<T?> openTrailerPlayer<T>(
    BuildContext context, {
    required String youtubeKey,
    required String title,
    Movie? movie,
    String? languageCode,
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      slideRoute(
        (_) => TrailerPlayerScreen(
          youtubeKey: youtubeKey,
          title: title,
          movie: movie,
          languageCode: languageCode,
        ),
      ),
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
    return Navigator.of(context, rootNavigator: true).push<T>(
      slideRoute(
        (_) => PlayerScreen(
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
