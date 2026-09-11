import 'package:flutter/material.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_screen.dart';
import 'package:forja/shared/foundation/services/nav/plugin_nav.dart';
import 'package:forja/shared/foundation/blocks/shell/legacy_movie_meta.dart';
import 'package:forja/features/archive/search/search_screen.dart';
import 'package:forja/shared/playback/open/engine_auto_play.dart';
import 'package:forja/shared/player/controls/episodes/player_kit_episode.dart';
import 'package:forja/shared/player/entry/player_screen.dart';
import 'package:forja/shared/foundation/components/playback/stream_provider_probe.dart';
import 'package:forja/shared/player/trailer/trailer_player_screen.dart';

import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_aware_page_route.dart';
import 'package:forja/shared/player/in_app_mini/in_app_mini_player_controller.dart';
import 'package:forja/shared/shell/loading_overlay.dart';
import 'package:forja/shared/shell/forja_shell_platform.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_profile.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
/// Central navigation for cross-feature routes (details, player).
class AppRouter {
  AppRouter._();

  /// [RouteSettings.name] for [openPlayer] - used to replace an existing
  /// player instead of stacking two [PlayerScreen] routes on macOS.
  static const playerRouteName = 'player';

  /// Opaque slide / fade pushes fight decode + layout on weak Android TV
  /// SoCs (API 24) — cut them to zero so initState work is not concurrent
  /// with a compositor slide.
  static Duration get _pushTransitionDuration => ShellTokens.isAndroidTvDevice
      ? Duration.zero
      : const Duration(milliseconds: 350);

  static Duration get _popTransitionDuration => ShellTokens.isAndroidTvDevice
      ? Duration.zero
      : const Duration(milliseconds: 300);

  static Route<T> slideRoute<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: _pushTransitionDuration,
      reverseTransitionDuration: _popTransitionDuration,
      transitionsBuilder: _slideTransition,
    );
  }

  /// Shell overlay routes - blocks TV system-back from bypassing the coordinator.
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
      transitionDuration: _pushTransitionDuration,
      reverseTransitionDuration: _popTransitionDuration,
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
    final push = ShellTokens.isAndroidTvDevice ? Duration.zero : duration;
    final pop = ShellTokens.isAndroidTvDevice
        ? Duration.zero
        : const Duration(milliseconds: 500);
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: push,
      reverseTransitionDuration: pop,
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

  static Future<T?> openStremioSearchResult<T>(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final resolved = await PluginNavRegistry.resolveKitPluginId(
      tabId: await SettingsService().getDefaultNavTab(),
    );
    if (resolved == null || !context.mounted) return null;
    return openKitDetails<T>(
      context,
      pluginId: resolved,
      item: metaItemFromStremioSearchResult(item),
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
    String? pluginId,
    String? shellTabId,
  }) async {
    final resolved = await PluginNavRegistry.resolveKitPluginId(
      pluginId: pluginId,
      tabId: shellTabId ?? await SettingsService().getDefaultNavTab(),
    );
    if (resolved == null || !context.mounted) return null;
    final meta = stremioItem != null
        ? metaItemFromStremioItem(stremioItem, movie)
        : metaItemFromMovie(movie);
    return openKitDetails<T>(
      context,
      pluginId: resolved,
      item: meta,
      shellTabId: shellTabId,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
    );
  }

  /// Legacy alias - all titles use [openDetails].
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
    String? shellTabId,
  }) {
    return openDetails<T>(
      context,
      movie: movie,
      stremioItem: stremioItem,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
      startPosition: startPosition,
      autoPlay: autoPlay,
      shellTabId: shellTabId,
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
        transitionDuration: AppRouter._pushTransitionDuration,
        reverseTransitionDuration: AppRouter._popTransitionDuration,
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
    List<PlayerKitEpisode>? episodes,
    num? hubEpisodeNumber,
    Future<void> Function(PlayerKitEpisode episode)? onHubEpisodeSelected,
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
    EnginePlaySession? enginePlaySession,
    bool fadeTransition = false,
  }) async {
    await InAppMiniPlayerController.instance.stopForNewPlay();
    if (!context.mounted) return null;
    const settings = RouteSettings(name: playerRouteName);
    // Capture shell tokens now - loading dialogs / hosts may unmount while the
    // player route still rebuilds its pageBuilder.
    final existing = ShellScope.maybeOf(context);
    final profile = existing?.profile ?? resolveShellProfile(context);
    final config = existing?.config ?? shellPlatformConfigFor(profile);
    final navigator = Navigator.of(context, rootNavigator: true);
    // In-player next/episode switch calls openPlayer from a player route while a
    // Forja Auto loading *dialog* sits on top. pushAndRemoveUntil must not stop
    // on that dialog (or the hub loading host) — otherwise Back returns to the
    // previous episode instead of details.
    final replacingPlayer =
        ModalRoute.of(context)?.settings.name == playerRouteName;
    final RouteTransitionsBuilder transitions = fadeTransition
        ? (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          }
        : _slideTransition;
    return navigator.pushAndRemoveUntil<T>(
      InAppMiniAwarePageRoute<T>(
        settings: settings,
        transitionDuration: fadeTransition
            ? (ShellTokens.isAndroidTvDevice
                ? Duration.zero
                : const Duration(milliseconds: 1000))
            : _pushTransitionDuration,
        reverseTransitionDuration: fadeTransition
            ? (ShellTokens.isAndroidTvDevice
                ? Duration.zero
                : const Duration(milliseconds: 500))
            : _popTransitionDuration,
        fullscreenDialog: fadeTransition,
        transitionsBuilder: transitions,
        builder: (_) => ShellScope(
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
            episodes: episodes,
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
            enginePlaySession: enginePlaySession,
          ),
        ),
      ),
      (route) {
        if (route.isFirst) return true;
        final name = route.settings.name;
        if (name == playerRouteName) return false;
        if (name == 'iptv_player') return false;
        if (name == loadingOverlayRouteName) {
          // Always strip Auto loading dialogs above the old player.
          if (route is PopupRoute) return false;
          // Episode switch from in-player: also strip the hub loading host so
          // Back lands on details, not the previous episode's resolve screen.
          if (replacingPlayer) return false;
        }
        return true;
      },
    );
  }
}
