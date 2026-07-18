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
import 'package:forja/shared/catalog/tmdb_user_region.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
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
    // ⌘Q while red-X teardown is already running — still unblock AppKit.
    if (Platform.isMacOS) {
      await MacOsShellChannel.replyReadyToTerminate();
    }
    return;
  }
  _appShutdownStarted = true;

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

  // macOS needs longer settle — demux msg_wakeup UAF if we terminate mid-join.
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
  initTmdbUserRegion();
  EpisodeWatchedService().syncHandler = syncEpisodeWatchedToTrackers;
  MyListService().syncAddHandler = syncMyListAddToTrackers;
  MyListService().syncRemoveHandler = syncMyListRemoveFromTrackers;
  unawaited(AppVersion.instance.load());
  debugPrint('[Boot] Flutter binding initialized');
  await ForjaSupabase.ensureInitialized();
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
    // youtube_explode spam: countdown every tick while a token is cached
    if (e.message.contains('Access token expires in')) return;
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
    // ⌘Q / Quit menu never hits onWindowClose — AppKit calls prepareQuit.
    MacOsShellChannel.listenPrepareQuit(_runDesktopQuit);
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
    // Graceful shutdown — timed media_kit + engine teardown before destroy /
    // AppKit terminate. See issue 062 (Windows freeze) and 081 (macOS demux
    // SIGSEGV on ⌘Q / close while mpv alive).
    await _runDesktopQuit();
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
          home: const DesktopStartupGate(splash: SplashScreen()),
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

/// Boot TMDB lists — retry a few times on transient "error sending request"
/// failures (common when four calls race at splash).
Future<List<Movie>> _bootTmdbFetch(
  String label,
  Future<List<Movie>> Function() fetch, {
  void Function(String status)? onRetryStatus,
}) async {
  const attempts = 3;
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    if (i > 0) {
      onRetryStatus?.call('Retrying $label (${i + 1}/$attempts)…');
    }
    try {
      final list = await fetch();
      if (list.isNotEmpty) return list;
      lastError = 'empty results';
    } catch (e) {
      lastError = e;
      debugPrint('[Boot] ✗ TMDB $label attempt ${i + 1}/$attempts: $e');
    }
    if (i < attempts - 1) {
      await Future<void>.delayed(Duration(milliseconds: 350 * (i + 1)));
    }
  }
  debugPrint(
    '[Boot] ✗ TMDB $label failed after $attempts attempts: $lastError',
  );
  return const <Movie>[];
}

class _SplashScreenState extends State<SplashScreen> {
  /// Hold the splash at least this long so MainScreen / Home can warm up.
  /// Also the hard cap — if boot work is still running past this, dismiss
  /// and toast; catalog/services keep loading in the background.
  static Duration get _minSplashDuration => kDebugMode
      ? const Duration(milliseconds: 800)
      : const Duration(seconds: 8);

  /// Built once and kept alive in the widget tree behind the splash overlay
  /// so its element (and all child State objects) survive the transition
  /// without being re-created.
  final Widget _mainScreen = const MainScreen();

  /// True while the splash overlay should still be drawn on top.
  bool _showOverlay = true;

  /// Live boot step shown above the version on the splash.
  final ValueNotifier<String> _bootStatus = ValueNotifier<String>('Starting…');

  @override
  void initState() {
    super.initState();
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
      _setBootStatus('Almost ready…');
      debugPrint(
        '[Boot] Step 4: Waiting for minimum splash time so the '
        'pre-built MainScreen / HomeScreen finishes its first paints...',
      );
      await minSplashFuture;
      if (!mounted) return;
      debugPrint(
        '[Boot] Step 5: Dismissing splash overlay (MainScreen '
        'already mounted underneath)',
      );
      _dismissSplash();
    } else {
      debugPrint(
        '[Boot] Step 4: Min splash elapsed — boot still running; '
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
    debugPrint('[Boot] Device is offline, initializing local services only');
    _setBootStatus('Starting music player…');
    debugPrint('[Boot] Initializing MusicPlayer...');
    await MusicPlayerService().init().catchError((e) {
      debugPrint('[Boot] ✗ MusicPlayer error: $e');
      return null;
    });
    debugPrint('[Boot] ✓ Local services initialized');
  }

  Future<void> _initOnlineBoot() async {
    debugPrint('[Boot] Step 2: Initializing splash-critical services...');
    final api = TmdbApi();

    _setBootStatus('Loading catalog & services…');
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
      _bootTmdbFetch(
        'trending',
        api.getTrending,
        onRetryStatus: _setBootStatus,
      ),
      _bootTmdbFetch('popular', api.getPopular, onRetryStatus: _setBootStatus),
      _bootTmdbFetch(
        'top rated',
        api.getTopRated,
        onRetryStatus: _setBootStatus,
      ),
      _bootTmdbFetch(
        'now playing',
        api.getNowPlaying,
        onRetryStatus: _setBootStatus,
      ),
    ]);

    var trendingList = results[2] as List<Movie>;
    final popularList = results[3] as List<Movie>;
    final topRatedList = results[4] as List<Movie>;
    final nowPlayingList = results[5] as List<Movie>;

    // Hero uses trending — if that one call kept failing, seed from popular
    // so Home is not an empty shimmer after splash.
    if (trendingList.isEmpty && popularList.isNotEmpty) {
      debugPrint(
        '[Boot] TMDB trending empty after retries — using popular for hero',
      );
      trendingList = popularList;
    }

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
    _setBootStatus('Catalog ready');
  }

  Future<void> _initEngine() async {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('[Boot] Starting engine initialization...');
    debugPrint('═══════════════════════════════════════════════════════════');

    _setBootStatus('Checking network…');
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
