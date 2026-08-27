import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logging/logging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:forja/shared/audio/audiobook_player_service.dart';
import 'package:forja/shared/audio/music_player_service.dart';
import 'package:rust/rust.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/services/tracker_sync.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/services/player_pool_service.dart';
import 'package:forja/shared/utils/webview_cleanup.dart';

import 'package:forja/shared/navigation/back_navigation_scope.dart';
import 'package:forja/shell/main_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/app/boot_catalog.dart';
import 'package:forja/app/boot_needs.dart';
import 'package:forja/app/profile_engine_warm.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/services/splash_sound.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/app_update_progress_banner.dart';
import 'package:forja/shared/widgets/desktop_window_geometry.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_back_handler.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_remote_debug.dart';
import 'package:forja/shared/lan/lan.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/catalog/tmdb_user_region.dart';
import 'package:forja/shared/network/legacy_android_tls.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:forja/app/desktop_startup_gate.dart';
import 'package:forja/shell/macos_shell_channel.dart';

bool _appShutdownStarted = false;

/// Stop all media_kit (MPV) players before native teardown.
/// Without this, mpv core threads segfault on macOS/Windows close.
Future<void> _shutdownMediaKitPlayers() async {
  try {
    await MpvExclusiveSession.instance.shutdownAllPlayers();
  } catch (_) {}
  try {
    await MusicPlayerService().dispose();
  } catch (_) {}
  try {
    await AudiobookPlayerService().dispose();
  } catch (_) {}
  try {
    await PlayerPoolService().dispose();
  } catch (_) {}
}

/// Shared desktop quit: red-X ([WindowListener.onWindowClose]) and macOS ⌘Q
/// ([MacOsShellChannel] `prepareQuit` from `applicationShouldTerminate`).
Future<void> _runDesktopQuit() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
  if (_appShutdownStarted) {
    // ⌘Q while red-X teardown is already running - still unblock AppKit.
    if (Platform.isMacOS) {
      await MacOsShellChannel.replyReadyToTerminate();
    }
    return;
  }
  _appShutdownStarted = true;

  try {
    await DesktopWindowGeometry.saveNow();
  } catch (_) {}

  try {
    await windowManager.hide();
  } catch (_) {}

  final mediaTimeout =
      Platform.isMacOS ? const Duration(seconds: 5) : const Duration(seconds: 3);
  try {
    await _shutdownMediaKitPlayers().timeout(mediaTimeout);
  } catch (_) {}
  try {
    await Engine.shutdown().timeout(const Duration(seconds: 2));
  } catch (_) {}

  try {
    unawaited(WebViewCleanup.cleanupWebView2Cache());
  } catch (_) {}

  // macOS needs longer settle - demux msg_wakeup UAF if we terminate mid-join.
  await Future.delayed(
    Duration(milliseconds: Platform.isMacOS ? 400 : 150),
  );

  if (Platform.isMacOS) {
    // Allow AppKit to close the window during terminate (preventClose blocks it).
    try {
      await windowManager.setPreventClose(false);
    } catch (_) {}
    // AppKit owns terminate (⌘Q already in terminateLater; red-X calls terminate).
    await MacOsShellChannel.replyReadyToTerminate();
    return;
  }

  try {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  } catch (_) {
    exit(0);
  }
}

Future<void> bootstrapForja({String title = 'Forja'}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before any CachedNetworkImage / TMDB poster fetch (Android ≤7.0 LE trust).
  installLegacyAndroidTlsTrust();
  initTmdbUserRegion();
  EpisodeWatchedService().syncHandler = syncEpisodeWatchedToTrackers;
  MyListService().syncAddHandler = syncMyListAddToTrackers;
  MyListService().syncRemoveHandler = syncMyListRemoveFromTrackers;
  unawaited(AppVersion.instance.load());
  debugPrint('[Boot] Flutter binding initialized');
  await ForjaPlatformSecureStore.ensureConsentLoaded();
  await ForjaSupabase.ensureInitialized();
  // Always rotate the access JWT on cold start when a session exists. Skew /
  // gotrue discard can leave a locally "valid" AT that PostgREST rejects.
  await SyncService.instance.refreshSession(force: true);
  unawaited(ProviderRuntimeConfig.instance.ensureLoaded());
  unawaited(SettingsService().getAnimeTitleLanguage());
  if (Platform.isAndroid) {
    TvRemoteDebug.install();
  }
  ShellTvBackHandler.install();

  // TV profile must be set before any WebView warm-up (native workaround in
  // ForjaApplication.onCreate; Dart patch uses PlatformInfo).
  await PlatformChannel.initialize();
  ShellTvFocusCoordinator.tvBackPolicyEnabled =
      PlatformInfo.isAndroidTv || PlatformChannel.forceAndroidTv;

  // Configure InAppWebView (Android only - not supported on iOS)
  if (Platform.isAndroid) {
    try {
      if (PlatformInfo.isAndroidTv) {
        await PlatformChannel.prepareWebViewForTv();
        debugPrint('[Boot] TV WebView software warm-up OK');
      } else {
        debugPrint('[Boot] Setting up InAppWebView...');
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
        debugPrint('[Boot] InAppWebView OK');
      }
    } catch (e) {
      debugPrint('[Boot] InAppWebView setup failed (non-fatal): $e');
    }
  }

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((e) {
    // youtube_explode spam: countdown every tick while a token is cached
    if (e.message.contains('Access token expires in')) return;
    // explode retry() dumps VideoUnplayableException 5× with async stacks.
    // Bot-check is the message; the stacks are not a Flutter crash.
    if (e.loggerName.startsWith('YoutubeExplode')) return;
    // supabase_flutter logs PostgREST failures via this logger before the
    // caller catch; iat-skew is retried with the same token (SyncService).
    if (SyncService.isJwtIssuedAtFutureError(e.message) ||
        SyncService.isJwtIssuedAtFutureError(e.error)) {
      return;
    }
    debugPrint('[YT] ${e.message}');
    if (e.error != null) {
      debugPrint('[YT ERROR] ${e.error}');
      debugPrint('[YT STACK] ${e.stackTrace}');
    }
  });

  if (Platform.isAndroid) {
    // Follow system rotation setting - no forced lock.
    // auto_orientation_v2 is gone, so this respects the user's
    // rotation-lock toggle in Android quick-settings.
    SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Restore last windowed size/place when present; otherwise clamp a
    // default to the primary display work area (issue 196).
    final startup = await DesktopWindowGeometry.loadStartup();

    final WindowOptions windowOptions = WindowOptions(
      size: startup.size,
      minimumSize: const Size(640, 480),
      center: startup.position == null,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
      title: kDebugMode ? 'Forja Dev' : null,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // macOS dock: text badge only - no alternate .icns / generated logo.
      if (kDebugMode && Platform.isMacOS) {
        try {
          await windowManager.setBadgeLabel('DEV');
        } catch (_) {}
      }
      final pos = startup.position;
      if (pos != null) {
        try {
          await windowManager.setPosition(pos);
        } catch (_) {}
      }
      await windowManager.show();
      await windowManager.focus();
      if (startup.maximized) {
        try {
          await windowManager.maximize();
        } catch (_) {}
      }
    });
  }

  debugPrint('[Boot] Initializing MediaKit...');
  MediaKit.ensureInitialized();
  debugPrint('[Boot] MediaKit OK');

  // Music / Audiobooks AudioService stays off while those tabs are on hold.
  // Profile-gated engines (WebStreamr, Nuvio, LocalServer, TorrentStream, TMDB)
  // warm after profile settings are known - see ProfileEngineWarm / SplashScreen.

  // Hydrate theme preset before first frame
  await Engine.init();
  _warnIfRustMissing();
  ProviderRuntimeConfig.instance.pushToRust();
  await PlatformChannel.seedPlatformDefaultsAfterEngine();
  _wireLanPlaybackBridge();
  // LAN restore waits for post-splash torrent/proxy warm — see ProfileEngineWarm.

  await AppTheme.initTheme();

  // After Engine.init so crash-reporting opt-in is readable (RFC-043).
  await Telemetry.ensureInitialized();

  PlayerPoolService().warmUp();
  debugPrint('[Boot] Preloading splash sound...');
  await SplashSound.instance.preload();
  debugPrint('[Boot] Splash sound ready');
  debugPrint('[Boot] All init complete - launching app');

  runApp(
    ProviderScope(
      child: App(title: title),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key, this.title = 'Forja'});

  final String title;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver, WindowListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      SyncService.instance.startDesktopSessionKeepAlive();
    }
    // ⌘Q / Quit menu never hits onWindowClose - AppKit calls prepareQuit.
    MacOsShellChannel.listenPrepareQuit(_runDesktopQuit);
    // Mobile/TV often launch already in [AppLifecycleState.resumed], so
    // [didChangeAppLifecycleState] never fires for the first frame. Desktop
    // StartupGate still does a forced pull for restored sessions; this covers
    // mid-session returns and any race where resume was missed.
    if (Platform.isAndroid || Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(SyncService.instance.refreshSession());
        unawaited(SyncDomainBridge.instance.syncFromCloud(force: true));
        unawaited(Telemetry.syncAnalyticsIdentity());
      });
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
      SyncService.instance.stopDesktopSessionKeepAlive();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    final bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) return;
    // Graceful shutdown - timed media_kit + engine teardown before destroy /
    // AppKit terminate. See issue 062 (Windows freeze) and 081 (macOS demux
    // SIGSEGV on ⌘Q / close while mpv alive).
    await _runDesktopQuit();
  }

  @override
  void onWindowFocus() {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    unawaited(SyncService.instance.refreshSession());
    unawaited(SyncDomainBridge.instance.syncFromCloud());
    unawaited(Telemetry.syncAnalyticsIdentity());
  }

  @override
  void onWindowRestore() {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    unawaited(SyncService.instance.refreshSession());
    unawaited(SyncDomainBridge.instance.syncFromCloud());
    unawaited(Telemetry.syncAnalyticsIdentity());
  }

  @override
  void onWindowResize() => DesktopWindowGeometry.scheduleSave();

  @override
  void onWindowMove() => DesktopWindowGeometry.scheduleSave();

  @override
  void onWindowMaximize() => DesktopWindowGeometry.scheduleSave();

  @override
  void onWindowUnmaximize() => DesktopWindowGeometry.scheduleSave();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncService.instance.refreshSession());
      // Cloud is master — pull full profile_settings (Stremio, nav, …) into
      // local cache, not only account feature flags.
      unawaited(SyncDomainBridge.instance.syncFromCloud());
      unawaited(Telemetry.syncAnalyticsIdentity());
      return;
    }
    if (state == AppLifecycleState.detached) {
      if (_appShutdownStarted) return;
      _appShutdownStarted = true;
      unawaited(_shutdownMediaKitPlayers());
      unawaited(Engine.shutdown());
      TorrentStreamService().cleanup();
      WebViewCleanup.cleanupWebView2Cache();
      site111477_proxy.purge111477Cache();
    }
  }

  /// True on Windows, Linux, macOS - used to disable the accessibility
  /// bridge that causes AXTree crashes on Windows.
  static final bool _isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, preset, _) {
        Widget app = MaterialApp(
          title: widget.title,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          navigatorObservers: [
            PosthogObserver(nameExtractor: ProductAnalytics.routeScreenName),
          ],
          home: const DesktopStartupGate(splash: SplashScreen()),
          builder: (context, child) {
            Widget content = ShellScopeBuilder(
              builder: (context, _) {
                final body = ForjaToastHost(
                  child: AppUpdateProgressBannerHost(
                    child: BackNavigationScope(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
                final policy = ShellScope.inputPolicyOf(context);
                final wrapped = policy.scaleOnHover && policy.scaleOnFocus
                    ? ShellKeyboardFocusHost(child: body)
                    : body;
                return ShellInputPolicy.maybeWrapFocusTraversal(
                  enabled: policy.wrapAppFocusTraversal,
                  child: wrapped,
                );
              },
            );
            if (ShellTokens.isAndroidTvDevice) {
              final mq = MediaQuery.of(context);
              content = MediaQuery(
                data: mq.copyWith(padding: EdgeInsets.zero),
                child: content,
              );
            }
            return content;
          },
        );
        // PostHog replay root (no-op on desktop; required on Android/iOS).
        app = PostHogWidget(child: app);
        if (_isDesktop) {
          app = ExcludeSemantics(child: app);
        }
        return app;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// User-facing hold line after boot work finishes early (min-splash wait).
String _splashOpeningStatus(BootNeeds needs) {
  final nav = needs.visibleNavIds;
  final liveIptv =
      !needs.vodTab &&
      (nav.contains('iptv') || nav.contains('live_matches'));
  if (liveIptv) return 'Opening Live & IPTV…';
  if (needs.homeTab || needs.tmdb) return 'Opening Home…';
  return 'Just a moment…';
}

class _SplashScreenState extends State<SplashScreen> {
  /// Hold the splash at least this long so MainScreen / Home can warm up.
  /// Also the hard cap - if boot work is still running past this, dismiss
  /// and toast; catalog/services keep loading in the background.
  static const Duration _minSplashDuration = Duration(seconds: 8);

  /// Built once and kept alive in the widget tree behind the splash overlay
  /// so its element (and all child State objects) survive the transition
  /// without being re-created.
  final Widget _mainScreen = const MainScreen();

  /// True while the splash overlay should still be drawn on top.
  bool _showOverlay = true;

  /// Live boot step shown above the version on the splash.
  final ValueNotifier<String> _bootStatus =
      ValueNotifier<String>('Getting things ready…');

  @override
  void initState() {
    super.initState();
    // ProfileSwitchSplash already warmed engines - open MainScreen immediately.
    if (ShellBus.splashDismissed.value) {
      _showOverlay = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startPostSplashServices());
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initEngine();
    });
  }

  @override
  void dispose() {
    _bootStatus.dispose();
    super.dispose();
  }

  void _setBootStatus(String status) {
    if (!mounted) return;
    _bootStatus.value = status;
  }

  void _skipSplash() {
    if (!mounted || !_showOverlay) return;
    setState(() => _showOverlay = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifySplashDismissed();
    });
  }

  void _notifySplashDismissed() {
    if (ShellBus.splashDismissed.value) return;
    ShellBus.splashDismissed.value = true;
    unawaited(_startPostSplashServices());
  }

  Future<void> _startPostSplashServices() async {
    // Let the slide-away and first interactive frames finish before Rust/network burst.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final needs = await BootNeeds.resolve();
    // Sources engines (proxy, WebStreamr, Nuvio, torrent) — not splash work.
    await ProfileEngineWarm.warm(
      needs,
      startTorrent: true,
      startPlaySources: true,
      reason: 'post-splash',
    );
  }

  void _dismissSplash({bool showSlowBootToast = false}) {
    if (!mounted || !_showOverlay) return;
    setState(() => _showOverlay = false);
    _notifySplashDismissed();
    if (showSlowBootToast) {
      ForjaToast.warning(
        'Loading catalog services is taking longer than expected.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Rotate hold lines while waiting out the remaining min-splash time.
  Future<void> _awaitMinSplashWithHoldStatus(Future<void> minSplashFuture) async {
    final opening = _bootStatus.value.trim().isEmpty
        ? 'Just a moment…'
        : _bootStatus.value;
    final steps = <String>[
      opening,
      'Warming up the shell…',
      'Almost ready…',
    ];
    var index = 0;

    while (mounted && _showOverlay) {
      final finished = await Future.any<bool>([
        minSplashFuture.then((_) => true),
        Future<void>.delayed(const Duration(milliseconds: 1800)).then((_) => false),
      ]);
      if (finished) return;
      index = (index + 1) % steps.length;
      _setBootStatus(steps[index]);
    }
  }

  /// Dismiss when the min splash timer elapses. If [bootFuture] is still
  /// running, show the slow-boot toast; otherwise wait out any remaining
  /// min time after boot finishes early.
  Future<void> _dismissWhenReady(Future<void> bootFuture) async {
    final minSplashFuture = Future<void>.delayed(_minSplashDuration);
    final bootFinishedFirst = await Future.any<bool>([
      bootFuture.then((_) => true),
      minSplashFuture.then((_) => false),
    ]);

    if (!mounted) return;

    if (bootFinishedFirst) {
      debugPrint(
        '[Boot] Step 4: Waiting for minimum splash time so the '
        'pre-built MainScreen / HomeScreen finishes its first paints...',
      );
      await _awaitMinSplashWithHoldStatus(minSplashFuture);
      if (!mounted) return;
      debugPrint(
        '[Boot] Step 5: Dismissing splash overlay (MainScreen '
        'already mounted underneath)',
      );
      _dismissSplash();
    } else {
      _setBootStatus('Finishing up…');
      debugPrint(
        '[Boot] Step 4: Min splash elapsed - boot still running; '
        'dismissing overlay and continuing in background',
      );
      _dismissSplash(showSlowBootToast: true);
      await bootFuture;
    }

    if (!mounted) return;
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[Boot] ✓✓✓ ENGINE INITIALIZATION COMPLETE ✓✓✓');
    debugPrint('═══════════════════════════════════════════════════════════');
  }

  Future<void> _initOfflineBoot() async {
    debugPrint('[Init] offline boot - skip network catalog');
    final needs = await BootNeeds.resolve();
    // Play-source engines start post-splash (same as online).
    debugPrint('[Init] offline boot complete ($needs)');
    _setBootStatus(_splashOpeningStatus(needs));
  }

  Future<void> _initOnlineBoot() async {
    debugPrint('[Init] resolving profile boot needs...');
    _setBootStatus('Loading your profile…');
    final needs = await BootNeeds.resolve();
    debugPrint('[Init] $needs');

    // Splash floor: TMDB only. LocalServer / WebStreamr / Nuvio / torrent
    // start after dismiss (Sources / details), not during the animation.
    await ProfileEngineWarm.warm(
      needs,
      startTorrent: false,
      startPlaySources: false,
      reason: 'intro-splash',
      onStatus: _setBootStatus,
    );

    if (!needs.tmdb) {
      debugPrint('[Init] TMDB skip (home/search/mylist not visible)');
      _setBootStatus(_splashOpeningStatus(needs));
      return;
    }

    _setBootStatus('Loading your home feed…');
    await BootCatalog.prefetchTmdb(onStatus: _setBootStatus);
    _setBootStatus(_splashOpeningStatus(needs));
  }

  Future<void> _initEngine() async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[Boot] Starting engine initialization...');
    debugPrint('═══════════════════════════════════════════════════════════');

    _setBootStatus('Checking connection…');
    debugPrint('[Boot] Step 1: Checking network connectivity...');
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    debugPrint('[Boot] Network status: ${isOffline ? "OFFLINE" : "ONLINE"}');

    final bootFuture = isOffline ? _initOfflineBoot() : _initOnlineBoot();
    await _dismissWhenReady(bootFuture);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.bgDark,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Offstage(offstage: _showOverlay, child: _mainScreen),
          if (_showOverlay)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skipSplash,
                child: _buildSplashOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSplashOverlay() {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppTheme.bgDark,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _skipSplash,
          child: ValueListenableBuilder<String>(
            valueListenable: _bootStatus,
            builder: (context, status, _) {
              return SplashOverlayContent(statusLabel: status);
            },
          ),
        ),
      ),
    );
  }
}

void _wireLanPlaybackBridge() {
  LanPlaybackBridge.openMagnetOnDesktop = ({
    required String magnet,
    int? season,
    int? episode,
    int? fileIdx,
  }) async {
    if (!await LanPlaybackRouter.shouldPreferDesktop(
      PlatformPlayback.capabilities,
    )) {
      return null;
    }
    final url = await LanClientService.instance.openStream(
      kind: 'torrent',
      magnet: magnet,
      season: season,
      episode: episode,
      fileIdx: fileIdx,
    );
    if (url == null || url.isEmpty) return null;
    return TorrentPlaybackUrl(
      url,
      fileIndex: fileIdx,
      source: TorrentPlaybackSource.localEngine,
      sourceLabel: 'LAN Server',
    );
  };
}

void _warnIfRustMissing() {
  if (!kDebugMode || Engine.isReady) return;

  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  final buildHint = isDesktop
      ? './scripts/build_rust.sh (or melos run rust:build)'
      : './scripts/build_rust_mobile.sh (or melos run rust:build:mobile)';

  const msg =
      '[Boot] Rust engine NOT loaded - engine features unavailable. '
      'From repo root run: ';
  final full =
      '$msg$buildHint. '
      'Override: RUST_LIB=/path/to/libffi.dylib|.so. '
      'Strict fail: RUST_STRICT=1';

  debugPrint(full);
  if (Platform.environment['RUST_STRICT'] == '1') {
    throw StateError(full);
  }
}
