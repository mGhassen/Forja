import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/audiobooks/audiobook_screen.dart';
import 'package:forja/features/anime/anime_search_screen.dart';
import 'package:forja/features/asian_drama/asian_drama_search_screen.dart';
import 'package:forja/features/discover/discover_screen.dart';
import 'package:forja/features/home/home_screen.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_screen.dart';
import 'package:forja/features/jellyfin/jellyfin_screen.dart';
import 'package:forja/features/music/music_screen.dart';
import 'package:forja/features/my_list/my_list_screen.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shared/audio/music_player_service.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/adapters/shell_host.dart';
import 'package:forja/shell/home_top_bar.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_find_shortcut.dart';
import 'package:forja/shell/macos_shell_channel.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/services/app_updater_service.dart';
import 'package:forja/shared/widgets/announcement_banner.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static State<MainScreen>? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static List<String> _bootstrapVisibleNavIds() {
    final base = SettingsService.platformProfile == PlatformProfile.androidTv
        ? SettingsService.defaultTvVisibleNavIds
        : SettingsService.defaultVisibleNavIds;
    return [...base, 'settings'];
  }

  int _selectedIndex =
      SettingsService.initialShellTabIndex(_bootstrapVisibleNavIds());
  Timer? _metricsDebounce;
  Timer? _metricsSafety;

  final GlobalKey<SearchScreenState> _searchKey = GlobalKey<SearchScreenState>();
  final Map<String, GlobalKey<State<StatefulWidget>>> _tabKeys = {
    'home': GlobalKey<State<StatefulWidget>>(),
    'audiobooks': GlobalKey<State<StatefulWidget>>(),
    'mylist': GlobalKey<State<StatefulWidget>>(),
    'discover': GlobalKey<State<StatefulWidget>>(),
    'iptv': GlobalKey<State<StatefulWidget>>(),
    'music': GlobalKey<State<StatefulWidget>>(),
    'jellyfin': GlobalKey<State<StatefulWidget>>(),
  };

  GlobalKey<State<StatefulWidget>>? _keyForTab(String id) {
    if (id == 'search') return null;
    return _tabKeys[id];
  }

  ShellTabRefresh? _refreshStateFor(String id) {
    final state = id == 'search'
        ? _searchKey.currentState
        : _keyForTab(id)?.currentState;
    return state is ShellTabRefresh ? state : null;
  }

  bool _tabBlocksEviction(String id) {
    if (id == 'music' && MusicPlayerService().isPlaying.value) return true;
    return _refreshStateFor(id)?.shellBlocksEviction ?? false;
  }

  final Map<String, Widget> _tabCache = {};
  final Set<String> _mountedTabIds = {'home'};
  final List<String> _tabLru = ['home'];
  List<String> _visibleIds = _bootstrapVisibleNavIds();
  bool _initialNavResolved = false;
  UpdateInfo? _pendingUpdate;
  bool _updateDialogShown = false;
  VoidCallback? _splashDismissedForUpdateListener;
  BuildContext? _shellScopedContext;

  String? get _currentTabId =>
      _visibleIds.isEmpty || _selectedIndex >= _visibleIds.length
          ? null
          : _visibleIds[_selectedIndex];

  Widget _tabFor(String id) {
    assert(navTabBuilders.containsKey(id));
    final isNew = !_tabCache.containsKey(id);
    final tab = _tabCache.putIfAbsent(id, () {
      if (id == 'search') {
        return SearchScreen(key: _searchKey);
      }
      final key = _keyForTab(id);
      return switch (id) {
        'home' => HomeScreen(key: key),
        'audiobooks' => AudiobookScreen(key: key),
        'mylist' => MyListScreen(key: key),
        'discover' => DiscoverScreen(key: key),
        'iptv' => IptvPtScreen(key: key),
        'music' => MusicScreen(key: key),
        'jellyfin' => JellyfinScreen(key: key),
        _ => navTabBuilders[id]!(),
      };
    });
    if (isNew && kDebugMode) {
      debugPrint('[MainScreen] Built tab: $id');
    }
    return tab;
  }

  void _touchTab(String id) {
    _tabLru.remove(id);
    _tabLru.add(id);
  }

  void _evictTab(String id) {
    if (id == 'home') return;
    final current = _currentTabId;
    if (current != null && id == current) return;

    if (!_mountedTabIds.contains(id)) return;

    _mountedTabIds.remove(id);
    _tabCache.remove(id);
    _tabLru.remove(id);
    if (kDebugMode) {
      debugPrint('[MainScreen] Evicted tab: $id');
    }
  }

  void _evictTabsNotInNavbar(Iterable<String> visible) {
    final allowed = visible.toSet();
    for (final id in List<String>.from(_mountedTabIds)) {
      if (!allowed.contains(id)) {
        _evictTab(id);
      }
    }
  }

  void _enforceTabCap() {
    while (_mountedTabIds.length > ShellTokens.maxMountedTabs) {
      final current = _currentTabId;
      String? victim;
      for (final id in _tabLru) {
        if (id != 'home' && id != current && !_tabBlocksEviction(id)) {
          victim = id;
          break;
        }
      }
      if (victim == null) break;
      _evictTab(victim);
    }
  }

  void _refreshTabIfStale(String id, {bool force = false}) {
    final refresh = _refreshStateFor(id);
    if (refresh != null) {
      unawaited(refresh.refreshIfStale(force: force));
    }
  }

  Widget? _shellHeader() {
    if (_visibleIds.isEmpty || _selectedIndex >= _visibleIds.length) return null;
    if (_visibleIds[_selectedIndex] != 'search') return null;
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) return null;
    return _searchKey.currentState?.buildShellSearchBar();
  }

  void _syncCurrentNavTab() {
    ShellTvFocus.currentNavTabId = _currentTabId;
  }

  void _selectTab(int index) {
    final id = _visibleIds[index];
    setState(() {
      _mountedTabIds.add(id);
      _selectedIndex = index;
    });
    _syncCurrentNavTab();
    _touchTab(id);
    _enforceTabCap();
    _applyTabShellChrome(id);
    if (id == 'search') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
        _searchKey.currentState?.focusTvBrowseFieldIfEmpty();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshTabIfStale(id);
    });
  }

  bool _musicUsesOwnSidebar(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
  }

  void _applyTabShellChrome(String tabId) {
    if (tabId == 'music') {
      ShellBus.hideGlobalNav.value = _musicUsesOwnSidebar(context);
    } else if (tabId != 'iptv') {
      ShellBus.hideGlobalNav.value = false;
    }
    ShellBus.notifyShellChromeChanged();
  }

  @override
  void initState() {
    super.initState();
    ShellBus.selectedWatchProviderId.value = null;
    WidgetsBinding.instance.addObserver(this);
    ShellBus.stremioSearchNotifier.addListener(_onStremioSearch);
    ShellBus.requestTab.addListener(_onRequestTab);
    ShellBus.shellChromeRevision.addListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.addListener(_onShellChromeChanged);
    SettingsService.navbarChangeNotifier.addListener(_onNavbarConfigChanged);
    MacOsShellChannel.listen(onFind: _onFindShortcut);

    _loadNavbarConfig();
    _syncCurrentNavTab();
    _scheduleStartupUpdateCheck();
  }

  void _scheduleStartupUpdateCheck() {
    unawaited(_loadPendingUpdate());
    if (ShellBus.splashDismissed.value) {
      _presentPendingUpdateIfAny();
      return;
    }
    _splashDismissedForUpdateListener = () {
      if (!ShellBus.splashDismissed.value) return;
      ShellBus.splashDismissed.removeListener(_splashDismissedForUpdateListener!);
      _splashDismissedForUpdateListener = null;
      _presentPendingUpdateIfAny();
    };
    ShellBus.splashDismissed.addListener(_splashDismissedForUpdateListener!);
  }

  Future<void> _loadPendingUpdate() async {
    try {
      final updateInfo = await AppUpdaterService().checkForUpdates();
      if (!mounted) return;
      _pendingUpdate = updateInfo;
      _presentPendingUpdateIfAny();
    } catch (e) {
      debugPrint('[MainScreen] Update check failed: $e');
    }
  }

  void _presentPendingUpdateIfAny() {
    if (_updateDialogShown || _pendingUpdate == null || !mounted) return;
    if (!ShellBus.splashDismissed.value) return;

    _updateDialogShown = true;
    final updateInfo = _pendingUpdate!;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _pendingUpdate == null) return;
      final hostContext = _shellScopedContext ?? context;
      if (!hostContext.mounted) return;
      unawaited(UpdateDialog.show(hostContext, updateInfo));
    });
  }

  Future<void> _loadNavbarConfig() async {
    var visible = await SettingsService().getNavbarConfig();
    final defaultTab = await SettingsService().getDefaultNavTab();
    visible = visible
        .where((id) => !temporarilyHiddenNavIds.contains(id))
        .toList();
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      visible = visible
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
    }
    if (!mounted) return;
    setState(() {
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      _visibleIds = [...visible, 'settings'];
      if (!_initialNavResolved) {
        _initialNavResolved = true;
        _selectedIndex = SettingsService.initialShellTabIndex(
          _visibleIds,
          defaultTabId: defaultTab,
        );
        if (_selectedIndex < _visibleIds.length) {
          final tabId = _visibleIds[_selectedIndex];
          _mountedTabIds.add(tabId);
          _touchTab(tabId);
        }
      } else if (currentId != null) {
        final newIndex = _visibleIds.indexOf(currentId);
        if (newIndex >= 0) {
          _selectedIndex = newIndex;
        } else if (_selectedIndex >= _visibleIds.length) {
          _selectedIndex = _visibleIds.length - 1;
        }
      } else if (_selectedIndex >= _visibleIds.length) {
        _selectedIndex = 0;
      }
      _evictTabsNotInNavbar(_visibleIds);
      _enforceTabCap();
    });
    _syncCurrentNavTab();
  }

  void _onNavbarConfigChanged() {
    _loadNavbarConfig();
  }

  void _onShellChromeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_visibleIds.isNotEmpty && _selectedIndex < _visibleIds.length) {
      _applyTabShellChrome(_visibleIds[_selectedIndex]);
    }
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
    _metricsSafety ??= Timer(const Duration(seconds: 4), () {
      _metricsSafety = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final id = _currentTabId;
      if (id != null) {
        _refreshTabIfStale(id);
      }
      if (Platform.isAndroid) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  void _onStremioSearch() {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final idx = _visibleIds.indexOf('search');
    if (idx != -1) _selectTab(idx);
  }

  void _onRequestTab() {
    final id = ShellBus.requestTab.value;
    if (id == null) return;
    final idx = _visibleIds.indexOf(id);
    if (idx != -1 && mounted) _selectTab(idx);
    ShellBus.requestTab.value = null;
  }

  void searchComics(String query) {
    final idx = _visibleIds.indexOf('comics');
    if (idx != -1) _selectTab(idx);
  }

  void searchManga(String query) {
    final idx = _visibleIds.indexOf('manga');
    if (idx != -1) _selectTab(idx);
  }

  void _onFindShortcut() {
    if (ShellBus.invokeFindShortcut()) return;
    if (ShellBus.shellOverlayHasPage.value) return;

    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;

    switch (_currentTabId) {
      case 'home':
        AppRouter.openSearch(ctx);
      case 'search':
        _searchKey.currentState?.focusFromFindShortcut();
      case 'anime':
        pushShellRoute(
          ctx,
          AppRouter.slideShellRoute((_) => const AnimeSearchScreen()),
        );
      case 'asian_drama':
        pushShellRoute(
          ctx,
          AppRouter.slideShellRoute((_) => const AsianDramaSearchScreen()),
        );
      default:
        break;
    }
  }

  @override
  void dispose() {
    _metricsDebounce?.cancel();
    _metricsSafety?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ShellBus.stremioSearchNotifier.removeListener(_onStremioSearch);
    ShellBus.requestTab.removeListener(_onRequestTab);
    ShellBus.shellChromeRevision.removeListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.removeListener(_onShellChromeChanged);
    ShellBus.clearHideGlobalNav();
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarConfigChanged);
    MacOsShellChannel.dispose();
    if (_splashDismissedForUpdateListener != null) {
      ShellBus.splashDismissed.removeListener(_splashDismissedForUpdateListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellScopeBuilder(
      builder: (shellContext, profile) {
        _shellScopedContext = shellContext;
        final config = shellPlatformConfigFor(profile);
        final showHomeTopBar = _currentTabId == 'home' &&
            config.showHomeTopBar &&
            !ShellBus.shellOverlayHasPage.value;

        final shell = ShellFindShortcutScope(
          enabled: profile == ShellProfile.desktop,
          onFind: _onFindShortcut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AnnouncementBanner(),
              Expanded(
                child: ShellHost(
                  visibleIds: _visibleIds,
                  selectedIndex: _selectedIndex,
                  mountedTabIds: _mountedTabIds,
                  onDestinationSelected: _selectTab,
                  tabFor: _tabFor,
                  shellHeader: _shellHeader(),
                  shellTopBar: showHomeTopBar ? const HomeTopBar() : null,
                  hideGlobalNav: ShellBus.hideGlobalNav.value,
                ),
              ),
            ],
          ),
        );

        if (DesktopWindowChrome.isDesktop) {
          return DesktopWindowChrome.wrapShell(child: shell);
        }
        return shell;
      },
    );
  }
}
