import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:logging/logging.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:forja/shared/audio/audio_handler.dart';
import 'package:forja/shared/audio/audiobook_player_service.dart';
import 'package:forja/shared/audio/music_player_service.dart';
import 'package:rust/rust.dart';
import 'package:rust/rust.dart' as site111477_proxy;
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/services/tracker_sync.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';
import 'package:forja/shared/services/player_pool_service.dart';
import 'package:forja/shared/utils/webview_cleanup.dart';

import 'package:forja/shared/navigation/back_navigation_scope.dart';
import 'package:forja/shell/main_screen.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/app/boot_cache.dart';
import 'package:forja/shared/widgets/animated_logo.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/services/splash_sound.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/app_update_progress_banner.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_back_handler.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/tv_remote_debug.dart';
import 'package:forja/shared/platform/platform_channel.dart';
import 'package:forja/shared/platform/platform_info.dart';

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

Future<void> bootstrapForja({String title = 'Forja'}) async {
  WidgetsFlutterBinding.ensureInitialized();
  EpisodeWatchedService().syncHandler = syncEpisodeWatchedToTrackers;
  MyListService().syncAddHandler = syncMyListAddToTrackers;
  MyListService().syncRemoveHandler = syncMyListRemoveFromTrackers;
  unawaited(AppVersion.instance.load());
  debugPrint('[Boot] Flutter binding initialized');
  if (Platform.isAndroid) {
    TvRemoteDebug.install();
  }
  ShellTvBackHandler.install();

  // TV profile must be set before any WebView warm-up (native workaround in
  // ForjaApplication.onCreate; Dart patch uses PlatformInfo).
  await PlatformChannel.initialize();
  ShellTvFocusCoordinator.tvBackPolicyEnabled =
      PlatformInfo.isAndroidTv || PlatformChannel.forceAndroidTv;

  // Configure InAppWebView (Android only — not supported on iOS)
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
    debugPrint('[YT] ${e.message}');
    if (e.error != null) {
      debugPrint('[YT ERROR] ${e.error}');
      debugPrint('[YT STACK] ${e.stackTrace}');
    }
  });

  if (Platform.isAndroid) {
    // Follow system rotation setting — no forced lock.
    // auto_orientation_v2 is gone, so this respects the user's
    // rotation-lock toggle in Android quick-settings.
    SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Size the window to fit the user's primary display. On a 1366×768
    // laptop the old fixed 1600×1000 was bigger than the screen, so the
    // title bar / close button / fullscreen toggle fell off-screen.
    // We clamp the default to the display's work area minus a small
    // margin, and set a reasonable minimum so tiny screens still work.
    const double desiredWidth = 1600;
    const double desiredHeight = 1000;
    const double screenMargin = 80; // leaves room for taskbar + title bar
    final display = WidgetsBinding.instance.platformDispatcher.displays.first;
    final logicalScreen = display.size / display.devicePixelRatio;
    final double maxW = (logicalScreen.width - screenMargin).clamp(
      640.0,
      double.infinity,
    );
    final double maxH = (logicalScreen.height - screenMargin).clamp(
      480.0,
      double.infinity,
    );
    final Size windowSize = Size(
      desiredWidth.clamp(640.0, maxW),
      desiredHeight.clamp(480.0, maxH),
    );

    final WindowOptions windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: const Size(640, 480),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
      title: kDebugMode ? 'Forja Dev' : null,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // macOS dock: text badge only — no alternate .icns / generated logo.
      if (kDebugMode && Platform.isMacOS) {
        try {
          await windowManager.setBadgeLabel('DEV');
        } catch (_) {}
      }
      await windowManager.show();
      await windowManager.focus();
    });
  }

  debugPrint('[Boot] Initializing MediaKit...');
  MediaKit.ensureInitialized();
  debugPrint('[Boot] MediaKit OK');

  debugPrint('[Boot] Initializing AudioService...');
  final audioHandler = await AudioService.init(
    builder: () => AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.forja.app.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
    ),
  );
  debugPrint('[Boot] AudioService OK');

  MusicPlayerService().setHandler(audioHandler);
  AudiobookPlayerService().init(audioHandler);

  // Hydrate theme preset before first frame
  await Engine.init();
  _warnIfRustMissing();
  await PlatformChannel.seedPlatformDefaultsAfterEngine();

  await AppTheme.initTheme();

  PlayerPoolService().warmUp();
  // Pre-initialise the local WebStreamr pipeline so the first call is fast.
  // Errors here are non-fatal — the service init() is also called lazily.
  unawaited(
    WebStreamrService.init().catchError((e) {
      debugPrint('[Boot] WebStreamrService.init failed (non-fatal): $e');
    }),
  );
  // Refresh every installed Nuvio addon's manifest in the background so new
  // upstream providers / fixes flow in without the user reinstalling.
  // Non-fatal — offline launches just keep the previously cached manifests.
  unawaited(
    NuvioService.instance.refreshAllInstalled().catchError((e) {
      debugPrint('[Boot] Nuvio refresh failed (non-fatal): $e');
    }),
  );
  debugPrint('[Boot] Preloading splash sound...');
  await SplashSound.instance.preload();
  debugPrint('[Boot] Splash sound ready');
  debugPrint('[Boot] All init complete — launching app');

  runApp(App(title: title));
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
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    final bool isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) return;
    if (_appShutdownStarted) return;
    _appShutdownStarted = true;

    // Hide first so a slow teardown does not look like a frozen close button.
    // (Windows 1.2.192 still froze here when media_kit stop/dispose hung.)
    try {
      await windowManager.hide();
    } catch (_) {}

    // Graceful shutdown — calling exit(0) while media_kit (mpv)
    // / WebView2 native threads are still running races their teardown and
    // produces the Windows "system error unknown hard error" dialog
    // (STATUS_ASSERTION_FAILURE in ntdll). Dispose the heavy native plugins
    // first, then ask windowManager to destroy the window which lets Flutter
    // shut down its engine cleanly.
    //
    // Every step is timed: unbounded awaits (stuck Player.dispose / pending
    // video teardown) previously kept setPreventClose(true) forever.
    try {
      await _shutdownMediaKitPlayers().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await Engine.shutdown().timeout(const Duration(seconds: 2));
    } catch (_) {}

    // Torrent engine stop is sync FFI (block_on) — must not run on this isolate
    // before destroy, or a stuck librqbit session freezes quit with no timeout.
    // Process exit reclaims the engine; cache wipe is best-effort after destroy.
    try {
      // Fire-and-forget — WebView2 cache wipe must not block close.
      unawaited(WebViewCleanup.cleanupWebView2Cache());
    } catch (_) {}

    // Small grace period so mpv threads can unwind after timed dispose.
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      // Last-resort fallback if windowManager is in a bad state.
      exit(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  /// True on Windows, Linux, macOS — used to disable the accessibility
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
          home: const SplashScreen(),
          builder: (context, child) {
            Widget content = ShellScopeBuilder(
              builder: (context, _) => ForjaToastHost(
                child: AppUpdateProgressBannerHost(
                  child: BackNavigationScope(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
            if (ShellTokens.isAndroidTvDevice) {
              final mq = MediaQuery.of(context);
              content = MediaQuery(
                data: mq.copyWith(padding: EdgeInsets.zero),
                child: content,
              );
            }
            return ShellInputPolicy.maybeWrapFocusTraversal(
              enabled: ShellTokens.isAndroidTvDevice,
              child: content,
            );
          },
        );
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

class _SplashScreenState extends State<SplashScreen> {
  /// Minimum time the splash overlay stays visible. Engine starts almost
  /// instantly, so we hold the splash a bit longer to let MainScreen /
  /// HomeScreen build, layout, paint and prefetch in the background. That
  /// way, when the overlay slides away, the first frames of the real UI are
  /// already warm and scrolling is smooth instead of janky.
  static Duration get _minSplashDuration => kDebugMode
      ? const Duration(milliseconds: 800)
      : const Duration(seconds: 8);

  /// Built once and kept alive in the widget tree behind the splash overlay
  /// so its element (and all child State objects) survive the transition
  /// without being re-created.
  final Widget _mainScreen = const MainScreen();

  /// True while the splash overlay should still be drawn on top.
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initEngine();
    });
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

    final profile = PlatformPlayback.capabilities;
    if (!profile.localTorrentEngine) return;

    debugPrint('[Boot] Post-splash: Starting TorrentStream engine...');
    final ok = await TorrentStreamService()
        .start()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('[Boot] Post-splash: TorrentStream timed out after 10s');
            return false;
          },
        )
        .catchError((e, st) {
          debugPrint('[Boot] Post-splash: TorrentStream error: $e');
          debugPrint('[Boot] Stack trace: $st');
          return false;
        });
    debugPrint(
      '[Boot] Post-splash: TorrentStream ${ok ? "✓ READY" : "✗ FAILED"}',
    );
  }

  void _dismissSplash() {
    if (!mounted || !_showOverlay) return;
    setState(() => _showOverlay = false);
    _notifySplashDismissed();
  }

  Future<void> _initEngine() async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[Boot] Starting engine initialization...');
    debugPrint('═══════════════════════════════════════════════════════════');

    // Start the minimum-display timer in parallel with all init work so
    // the splash never flashes by too quickly even when the engine is hot.
    final minSplashFuture = Future<void>.delayed(_minSplashDuration);

    debugPrint('[Boot] Step 1: Checking network connectivity...');
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    debugPrint('[Boot] Network status: ${isOffline ? "OFFLINE" : "ONLINE"}');

    if (isOffline) {
      debugPrint('[Boot] Device is offline, initializing local services only');
      debugPrint('[Boot] Initializing MusicPlayer...');
      await MusicPlayerService().init().catchError((e) {
        debugPrint('[Boot] ✗ MusicPlayer error: $e');
        return null;
      });
      debugPrint('[Boot] ✓ Local services initialized');
      await minSplashFuture;
      if (mounted) {
        debugPrint('[Boot] Dismissing splash (offline mode)');
        _dismissSplash();
      }
      return;
    }

    debugPrint('[Boot] Step 2: Initializing splash-critical services...');
    final api = TmdbApi();

    debugPrint('[Boot]   - Starting LocalServer...');
    debugPrint('[Boot]   - Initializing MusicPlayer...');
    debugPrint(
      '[Boot]   - Fetching TMDB data (trending, popular, top rated, now playing)...',
    );

    final results = await Future.wait([
      LocalServerService().start().catchError((e) {
        debugPrint('[Boot] ✗ LocalServer error: $e');
      }),
      MusicPlayerService().init().catchError((e) {
        debugPrint('[Boot] ✗ MusicPlayer error: $e');
      }),
      api.getTrending().catchError((e) {
        debugPrint('[Boot] ✗ TMDB trending error: $e');
        return <Movie>[];
      }),
      api.getPopular().catchError((e) {
        debugPrint('[Boot] ✗ TMDB popular error: $e');
        return <Movie>[];
      }),
      api.getTopRated().catchError((e) {
        debugPrint('[Boot] ✗ TMDB top rated error: $e');
        return <Movie>[];
      }),
      api.getNowPlaying().catchError((e) {
        debugPrint('[Boot] ✗ TMDB now playing error: $e');
        return <Movie>[];
      }),
    ]);

    final trendingList = results[2] as List<Movie>;
    final popularList = results[3] as List<Movie>;
    final topRatedList = results[4] as List<Movie>;
    final nowPlayingList = results[5] as List<Movie>;

    BootCache.setTmdb(
      trendingList: trendingList,
      popularList: popularList,
      topRatedList: topRatedList,
      nowPlayingList: nowPlayingList,
    );

    debugPrint('[Boot] Step 3: Service initialization results:');
    debugPrint('[Boot]   LocalServer: ✓ READY');
    debugPrint('[Boot]   MusicPlayer: ✓ READY');
    debugPrint(
      '[Boot]   TMDB Trending: ${trendingList.isNotEmpty ? "✓ ${trendingList.length} items" : "✗ Empty"}',
    );
    debugPrint(
      '[Boot]   TMDB Popular: ${popularList.isNotEmpty ? "✓ ${popularList.length} items" : "✗ Empty"}',
    );
    debugPrint(
      '[Boot]   TMDB Top Rated: ${topRatedList.isNotEmpty ? "✓ ${topRatedList.length} items" : "✗ Empty"}',
    );
    debugPrint(
      '[Boot]   TMDB Now Playing: ${nowPlayingList.isNotEmpty ? "✓ ${nowPlayingList.length} items" : "✗ Empty"}',
    );

    debugPrint(
      '[Boot] Step 4: Waiting for minimum splash time so the '
      'pre-built MainScreen / HomeScreen finishes its first paints...',
    );
    await minSplashFuture;

    if (mounted) {
      debugPrint(
        '[Boot] Step 5: Dismissing splash overlay (MainScreen '
        'already mounted underneath)',
      );
      _dismissSplash();
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[Boot] ✓✓✓ ENGINE INITIALIZATION COMPLETE ✓✓✓');
      debugPrint('═══════════════════════════════════════════════════════════');
    }
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
          child: const SplashOverlayContent(),
        ),
      ),
    );
  }
}

void _warnIfRustMissing() {
  if (!kDebugMode || Engine.isReady) return;

  final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  final buildHint = isDesktop
      ? './scripts/build_rust.sh (or melos run rust:build)'
      : './scripts/build_rust_mobile.sh (or melos run rust:build:mobile)';

  const msg =
      '[Boot] Rust engine NOT loaded — engine features unavailable. '
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
