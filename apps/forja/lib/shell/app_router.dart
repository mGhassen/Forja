import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/home/details_screen.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/player/trailer_player_screen.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Central navigation for cross-feature routes (details, player).
class AppRouter {
  AppRouter._();

  static Route<T> slideRoute<T>(WidgetBuilder builder) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  static Route<T> fadeRoute<T>(
    WidgetBuilder builder, {
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    return PageRouteBuilder<T>(
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

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

  /// Legacy alias — all titles use [openDetails].
  static Future<T?> openStreamingDetails<T>(
    BuildContext context, {
    required Movie movie,
    int? initialSeason,
    int? initialEpisode,
    Duration? startPosition,
    bool autoPlay = false,
  }) {
    return openDetails<T>(
      context,
      movie: movie,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
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
  }) {
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

  static Future<T?> openSearch<T>(BuildContext context) {
    return pushShellRoute<T>(
      context,
      slideRoute((_) => const SearchScreen(overlay: true)),
    );
  }

  static Future<T?> openTrailerPlayer<T>(
    BuildContext context, {
    required List<MediaTrailer> trailers,
    required int initialIndex,
    Movie? movie,
    String? languageCode,
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      slideRoute(
        (_) => TrailerPlayerScreen(
          trailers: trailers,
          initialIndex: initialIndex,
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
    List<PlayerHubEpisode>? hubEpisodes,
    num? hubEpisodeNumber,
    Future<void> Function(PlayerHubEpisode episode)? onHubEpisodeSelected,
    String? episodeOverview,
    Future<void> Function(Duration position, Duration duration)? onSaveProgress,
    Future<void> Function(String sourceUrl, String sourceTitle)? onSourcePinned,
    bool pinSource = false,
    bool fadeTransition = false,
  }) {
    final routeBuilder = fadeTransition ? fadeRoute : slideRoute;
    return Navigator.of(context, rootNavigator: true).push<T>(
      routeBuilder(
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
          hubEpisodes: hubEpisodes,
          hubEpisodeNumber: hubEpisodeNumber,
          onHubEpisodeSelected: onHubEpisodeSelected,
          episodeOverview: episodeOverview,
          onSaveProgress: onSaveProgress,
          onSourcePinned: onSourcePinned,
          pinSource: pinSource,
        ),
      ),
    );
  }
}
