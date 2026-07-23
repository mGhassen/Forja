import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/media/details/details_screen.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shared/player/controls/player_hub_episode.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/player/trailer_player_screen.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';

/// Central navigation for cross-feature routes (details, player).
class AppRouter {
  AppRouter._();

  /// [RouteSettings.name] for [openPlayer] — used to replace an existing
  /// player instead of stacking two [PlayerScreen] routes on macOS.
  static const playerRouteName = 'player';

  static Route<T> slideRoute<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: _slideTransition,
    );
  }

  /// Shell overlay routes — blocks TV system-back from bypassing the coordinator.
  static Route<T> slideShellRoute<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _tvBackGuardPage(builder(context));
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: _slideTransition,
    );
  }

  static Widget _tvBackGuardPage(Widget child) {
    if (!ShellTvFocusCoordinator.tvBackPolicyEnabled) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ShellTvFocusCoordinator.handleShellBackKey();
      },
      child: child,
    );
  }

  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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
  }

  static Route<T> fadeRoute<T>(
    WidgetBuilder builder, {
    Duration duration = const Duration(milliseconds: 1000),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
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
      slideShellRoute(
        (_) => DetailsScreen(
          movie: movie,
          stremioItem: stremioItem,
          initialSeason: initialSeason,
          initialEpisode: initialEpisode,
          startPosition: startPosition,
          autoPlay: autoPlay,
        ),
        settings: const RouteSettings(name: 'media_details'),
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
      slideShellRoute(
        (_) => const SearchScreen(overlay: true),
        settings: const RouteSettings(name: 'search_overlay'),
      ),
    );
  }

  static Future<T?> openTrailerPlayer<T>(
    BuildContext context, {
    required List<MediaTrailer> trailers,
    required int initialIndex,
    Movie? movie,
    String? languageCode,
  }) {
    final hostContext = context;
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        settings: const RouteSettings(name: 'trailer'),
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            ShellScope.rehost(
          hostContext,
          TrailerPlayerScreen(
            trailers: trailers,
            initialIndex: initialIndex,
            movie: movie,
            languageCode: languageCode,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: _slideTransition,
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
    bool streamsPrevalidated = false,
    VoidCallback? onPlaybackStarted,
    VoidCallback? onAllSourcesExhausted,
    Future<List<StreamSource>?> Function()? onReloadStreams,
    ValueNotifier<List<StreamSource>>? sourcesListNotifier,
    ValueNotifier<Map<String, List<StreamSource>>>? providerSourcesCache,
    ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier,
    bool fadeTransition = false,
  }) {
    final routeBuilder = fadeTransition ? fadeRoute<T> : slideRoute<T>;
    const settings = RouteSettings(name: playerRouteName);
    // Capture shell tokens now — loading dialogs / hosts may unmount while the
    // player route still rebuilds its pageBuilder.
    final existing = ShellScope.maybeOf(context);
    final profile = existing?.profile ?? resolveShellProfile(context);
    final config = existing?.config ?? shellPlatformConfigFor(profile);
    final navigator = Navigator.of(context, rootNavigator: true);
    return navigator.pushAndRemoveUntil<T>(
      routeBuilder(
        (_) => ShellScope(
          profile: profile,
          config: config,
          child: PlayerScreen(
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
            streamsPrevalidated: streamsPrevalidated,
            onPlaybackStarted: onPlaybackStarted,
            onAllSourcesExhausted: onAllSourcesExhausted,
            onReloadStreams: onReloadStreams,
            sourcesListNotifier: sourcesListNotifier,
            providerSourcesCache: providerSourcesCache,
            providerProbesNotifier: providerProbesNotifier,
          ),
        ),
        settings: settings,
      ),
      (route) => route.isFirst || route.settings.name != playerRouteName,
    );
  }
}
