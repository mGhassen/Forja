import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/shell/catalog_shell.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shell/adapters/shell_host.dart';
import 'package:forja/shell/shell_empty_features_screen.dart';
import 'package:forja/shared/catalog/shell/hub_catalog_top_bar.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_find_shortcut.dart';
import 'package:forja/shell/macos_shell_channel.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'package:forja/shell/shell_tab_refresh.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/service.dart';
import 'package:forja/shared/services/app_update_auto_check.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  static ConsumerState<MainScreen>? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  /// Prefer home until the first async navbar load resolves — do not paint the
  /// full platform-default rail (all Features tabs) before the real config.
  int _selectedIndex = 0;
  Timer? _metricsDebounce;
  Timer? _metricsSafety;
  final AppUpdateAutoCheck _updateAutoCheck = AppUpdateAutoCheck();

  final Map<String, GlobalKey<State<StatefulWidget>>> _tabKeys = {};

  GlobalKey<State<StatefulWidget>> _ensureTabKey(String id) {
    return _tabKeys.putIfAbsent(id, GlobalKey<State<StatefulWidget>>.new);
  }

  GlobalKey<State<StatefulWidget>>? _keyForTab(String id) {
    // Settings must not use a GlobalKey: shell churn on resume was disposing
    // the keyed State while the cached widget stayed, then remounting → Profile.
    if (id == 'settings') return null;
    return _ensureTabKey(id);
  }

  ShellTabRefresh? _refreshStateFor(String id) {
    final state = _keyForTab(id)?.currentState;
    return state is ShellTabRefresh ? state : null;
  }

  bool _tabBlocksEviction(String id) {
    return _refreshStateFor(id)?.shellBlocksEviction ?? false;
  }

  final Map<String, Widget> _tabCache = {};
  /// Empty until [_loadNavbarConfig] mounts the profile default tab.
  final Set<String> _mountedTabIds = {};
  final List<String> _tabLru = [];
  /// Empty until first [getNavbarConfig] — avoids all-tabs → filtered flash.
  List<String> _visibleIds = const [];
  bool _initialNavResolved = false;
  /// When every feature tab is hidden, show [ShellEmptyFeaturesScreen] until
  /// the user opens Settings from the rail or an empty-state CTA.
  bool _emptyFeaturesBodyDismissed = false;
  BuildContext? _shellScopedContext;

  bool get _hasFeatureTabs =>
      _visibleIds.any((id) => id != 'settings');

  bool get _showEmptyFeaturesGate =>
      _initialNavResolved && !_hasFeatureTabs && !_emptyFeaturesBodyDismissed;

  String? get _currentTabId =>
      _visibleIds.isEmpty || _selectedIndex >= _visibleIds.length
          ? null
          : _visibleIds[_selectedIndex];

  Widget _tabFor(String id) {
    assert(navTabBuilders.containsKey(id), 'No tab builder for $id');
    final isNew = !_tabCache.containsKey(id);
    final tab = _tabCache.putIfAbsent(id, () {
      final builder = navTabBuilders[id];
      if (builder == null) {
        return const SizedBox.shrink();
      }
      final key = _keyForTab(id);
      final child = builder();
      if (child is CatalogShell) {
        return _tabWithKey(key, child);
      }
      if (key != null &&
          (id == 'iptv' || id == 'live_matches')) {
        return KeyedSubtree(key: key, child: child);
      }
      return child;
    });
    if (isNew && kDebugMode) {
      debugPrint('[MainScreen] Built tab: $id');
    }
    return tab;
  }

  /// Hub [CatalogShell] must own the tab [GlobalKey] so [ShellTabRefresh] works.
  Widget _tabWithKey(GlobalKey<State<StatefulWidget>>? key, Widget child) {
    if (key == null) return child;
    if (child is CatalogShell) {
      return CatalogShell(
        key: key,
        pluginId: child.pluginId,
        tabId: child.tabId,
      );
    }
    return KeyedSubtree(key: key, child: child);
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

  /// Player-surface purge: keep only the shell tab under the player (the
  /// screen that opened it). Force-evict every other mounted tab — including
  /// [home] and tabs that normally block LRU — so decode gets max RAM/GPU.
  void _forceEvictSiblingTab(String id) {
    final current = _currentTabId;
    if (current != null && id == current) return;
    if (!_mountedTabIds.contains(id)) return;

    _mountedTabIds.remove(id);
    _tabCache.remove(id);
    _tabLru.remove(id);
    _tabKeys.remove(id);
    if (kDebugMode) {
      debugPrint('[MainScreen] Force-evicted sibling tab for player: $id');
    }
  }

  void _purgeMountedTabsForPlayer() {
    final victims = List<String>.from(_mountedTabIds);
    var changed = false;
    for (final id in victims) {
      final before = _mountedTabIds.length;
      _forceEvictSiblingTab(id);
      if (_mountedTabIds.length < before) changed = true;
    }
    if (!changed || !mounted) return;
    // Defer — purge runs while the player route is mounting; syncing mounted
    // tabs in the same frame disposes hub widgets still handling focus events.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPlayerResourcePurge() {
    _purgeMountedTabsForPlayer();
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

  void _notifyTabHidden(String id) {
    _refreshStateFor(id)?.onShellTabHidden();
  }

  void _notifyTabShown(String id) {
    _refreshStateFor(id)?.onShellTabShown();
  }

  Widget? _shellHeader() => null;

  void _syncCurrentNavTab() {
    ShellBus.activeShellTabId = _currentTabId;
    ShellTvFocus.currentNavTabId = _currentTabId;
  }

  void _selectTab(int index) {
    // Match nav-rail taps: dismiss details / hub overlays so the tab is visible
    // (e.g. Who's watching → Account settings via [ShellBus.requestTab]).
    popShellOverlayUntilRoot();
    // Cloud Features / profile settings: pull on side-nav use (not a timer).
    // Debounced to 15s inside syncFromCloud so rapid tab clicks do not spam.
    if (SyncService.instance.isSignedIn) {
      unawaited(SyncDomainBridge.instance.syncFromCloud());
    }
    final previousId = _currentTabId;
    final id = _visibleIds[index];
    if (previousId != null && previousId != id) {
      _notifyTabHidden(previousId);
      CatalogVerticalFiltersRegistry.onLeaveTab(previousId);
    } else if (previousId == id) {
      CatalogVerticalFiltersRegistry.onNavRepress(id);
    }
    // Same-tab Home re-select must not dismiss the provider panel.
    setState(() {
      if (id == 'settings') _emptyFeaturesBodyDismissed = true;
      _mountedTabIds.add(id);
      _selectedIndex = index;
    });
    _syncCurrentNavTab();
    _touchTab(id);
    _enforceTabCap();
    _applyTabShellChrome(id);
    unawaited(ProductAnalytics.screenTab(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Rapid tab switches queue multiple callbacks; only the still-selected
      // tab may run show/refresh (avoids setState/invalidate on a deactivated
      // keep-alive element → Riverpod ancestor lookup / inactive-elements assert).
      if (_currentTabId != id) return;
      _notifyTabShown(id);
      _refreshTabIfStale(id);
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
    ShellBus.homeProviderMenuVisible.value = false;
    WidgetsBinding.instance.addObserver(this);
    ShellBus.stremioSearchNotifier.addListener(_onStremioSearch);
    ShellBus.requestTab.addListener(_onRequestTab);
    ShellBus.shellLogoTapRevision.addListener(_onShellLogoTap);
    ShellBus.shellChromeRevision.addListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.addListener(_onShellChromeChanged);
    ShellBus.maskShellUnderPlayer.addListener(_onShellChromeChanged);
    ShellBus.playerResourcePurgeRevision.addListener(_onPlayerResourcePurge);
    MacOsShellChannel.listen(onFind: _onFindShortcut);
    EngineService.changeNotifier.addListener(_onEnginePackChanged);

    unawaited(_refreshHubNavThenLoad());
    _syncCurrentNavTab();
    _updateAutoCheck.start(() => _shellScopedContext ?? context);
  }

  void _onEnginePackChanged() {
    unawaited(_refreshHubNavThenLoad());
  }

  Future<void> _refreshHubNavThenLoad() async {
    final changed = await PluginNavRegistry.refresh();
    if (!mounted) return;
    // Pack scripts can change without nav shape changes. Hub CatalogShell is
    // keep-alive + 15m stale window — mark stale (and remount builders when
    // nav actually changed) so returning to Home / Anime / … reloads rails.
    _invalidateHubTabsAfterPackChange(remountBuilders: changed);
    await _loadNavbarConfig();
  }

  void _invalidateHubTabsAfterPackChange({required bool remountBuilders}) {
    // Contributed hubs only — seed + last refresh; no frozen official-id list.
    final hubIds = PluginNavRegistry.destinations.keys.toSet();
    for (final id in hubIds) {
      _refreshStateFor(id)?.markShellTabStale();
      if (!remountBuilders) continue;
      _tabCache.remove(id);
      _mountedTabIds.remove(id);
      _tabLru.remove(id);
      // Drop GlobalKey so a new CatalogShell State is created (same key would
      // reparent and keep the old memoized rails).
      _tabKeys.remove(id);
    }
    final current = _currentTabId;
    if (current != null && PluginNavRegistry.isHubTab(current)) {
      _refreshTabIfStale(current, force: true);
    }
  }

  Future<void> _loadNavbarConfig() async {
    var visible = await SettingsService().getNavbarConfig();
    final defaultTab = await SettingsService().getDefaultNavTab();
    visible = visible
        .where((id) => !archivedNavIds.contains(id))
        .where(PluginNavRegistry.isContributed)
        .toList();
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      visible = visible
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
    }
    if (!mounted) return;
    final applyDefaultTab = ShellBus.selectDefaultTabOnNextNavLoad;
    if (applyDefaultTab) {
      ShellBus.selectDefaultTabOnNextNavLoad = false;
    }
    setState(() {
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      if (visible.isNotEmpty) {
        _emptyFeaturesBodyDismissed = false;
      }
      _visibleIds = [...visible, 'settings'];
      if (!_initialNavResolved || applyDefaultTab) {
        if (applyDefaultTab) {
          // Fresh tab trees for the incoming profile's settings/portals.
          _tabCache.clear();
          _mountedTabIds.clear();
          _tabLru.clear();
          // Drop GlobalKeys so remounted tabs cannot reparent a deactivated
          // element mid-frame (Riverpod ancestor lookup / inactive-elements).
          _tabKeys.clear();
        }
        _initialNavResolved = true;
        _selectedIndex = SettingsService.initialShellTabIndex(
          _visibleIds,
          defaultTabId: defaultTab,
        );
        if (_selectedIndex < _visibleIds.length) {
          final tabId = _visibleIds[_selectedIndex];
          _mountedTabIds.add(tabId);
          _touchTab(tabId);
          _applyTabShellChrome(tabId);
          unawaited(ProductAnalytics.screenTab(tabId));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _currentTabId != tabId) return;
            _notifyTabShown(tabId);
          });
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

  bool _shellChromeRebuildPending = false;

  void _onShellChromeChanged() {
    if (!mounted) return;
    // Overlay players set [hideGlobalNav] from initState (mid-build). Same
    // deferral as [ShellBus.enterPlayerSurface] so we never mark dirty now.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    if (_shellChromeRebuildPending) return;
    _shellChromeRebuildPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shellChromeRebuildPending = false;
      if (mounted) setState(() {});
    });
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
      _updateAutoCheck.onResumed();
      if (Platform.isAndroid) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  void _onStremioSearch() {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final ctx = _shellScopedContext;
    if (ctx != null && ctx.mounted) {
      unawaited(AppRouter.openSearch(ctx));
    }
  }

  void _onRequestTab() {
    final id = ShellBus.requestTab.value;
    if (id == null) return;
    final idx = _visibleIds.indexOf(id);
    if (idx != -1 && mounted) _selectTab(idx);
    ShellBus.requestTab.value = null;
  }

  void _onShellLogoTap() {
    if (!mounted) return;
    popShellOverlayUntilRoot();
    if (!_hasFeatureTabs) {
      _returnToEmptyFeaturesHome();
      return;
    }
    unawaited(_selectDefaultFeatureTab());
  }

  void _returnToEmptyFeaturesHome() {
    final idx = _visibleIds.indexOf('settings');
    if (idx < 0) return;
    setState(() {
      _emptyFeaturesBodyDismissed = false;
      _selectedIndex = idx;
      _mountedTabIds.add('settings');
    });
    _syncCurrentNavTab();
  }

  Future<void> _selectDefaultFeatureTab() async {
    if (!mounted) return;
    final defaultTab = await SettingsService().getDefaultNavTab();
    if (!mounted) return;
    final featureIds =
        _visibleIds.where((id) => id != 'settings').toList(growable: false);
    var target = defaultTab;
    if (!featureIds.contains(target)) {
      target = featureIds.isNotEmpty ? featureIds.first : 'home';
    }
    final idx = _visibleIds.indexOf(target);
    if (idx >= 0) _selectTab(idx);
  }

  void _openFeaturesFromEmptyState() {
    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;
    final tv = ShellScope.metricsOf(ctx).usesTvDensity;
    ShellBus.openSettings(
      categoryId: SettingsCategoryId.navigation,
      enterDetail: tv,
    );
  }

  void _openPluginsFromEmptyState() {
    unawaited(PluginInstallCoordinator.instance.requestBatchInstallPrompt());
  }

  Widget _shellTabFor(String id) {
    if (id == 'settings' && _showEmptyFeaturesGate) {
      return ShellEmptyFeaturesScreen(
        onOpenFeatures: _openFeaturesFromEmptyState,
        onInstallPlugins: _openPluginsFromEmptyState,
      );
    }
    return _tabFor(id);
  }

  void searchComics(String query) {}

  void searchManga(String query) {}

  void _onFindShortcut() {
    unawaited(_handleFindShortcut());
  }

  Future<void> _handleFindShortcut() async {
    if (ShellBus.invokeFindShortcut()) return;
    if (ShellBus.shellOverlayHasPage.value) return;

    final tabId = _currentTabId;
    if (tabId == null || !PluginNavRegistry.isHubTab(tabId)) return;

    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;

    final pluginId = await PluginNavRegistry.pluginIdForTab(tabId);
    if (pluginId == null || !ctx.mounted) return;

    final label = PluginNavRegistry.destinations[tabId]?.label;
    await openHubCatalogSearch(
      ctx,
      pluginId: pluginId,
      tabId: tabId,
      hintText: label == null || label.isEmpty ? 'Search…' : 'Search $label…',
    );
  }

  @override
  void dispose() {
    _metricsDebounce?.cancel();
    _metricsSafety?.cancel();
    _updateAutoCheck.dispose();
    WidgetsBinding.instance.removeObserver(this);
    ShellBus.stremioSearchNotifier.removeListener(_onStremioSearch);
    ShellBus.requestTab.removeListener(_onRequestTab);
    ShellBus.shellLogoTapRevision.removeListener(_onShellLogoTap);
    ShellBus.shellChromeRevision.removeListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.removeListener(_onShellChromeChanged);
    ShellBus.maskShellUnderPlayer.removeListener(_onShellChromeChanged);
    ShellBus.playerResourcePurgeRevision.removeListener(_onPlayerResourcePurge);
    EngineService.changeNotifier.removeListener(_onEnginePackChanged);
    ShellBus.clearOverlayShellTabId();
    ShellBus.activeShellTabId = null;
    ShellBus.clearHideGlobalNav();
    ShellBus.clearMaskShellUnderPlayer();
    MacOsShellChannel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navbarRevisionProvider, (_, _) {
      _onNavbarConfigChanged();
    });
    return ShellScopeBuilder(
      builder: (shellContext, profile) {
        _shellScopedContext = shellContext;
        final config = shellPlatformConfigFor(profile);
        final showCatalogTopBar = config.showHomeTopBar &&
            !ShellBus.shellOverlayHasPage.value;
        final Widget? shellTopBar;
        if (!showCatalogTopBar) {
          shellTopBar = null;
        } else {
          shellTopBar = switch (_currentTabId) {
            null => null,
            final id when PluginNavRegistry.isHubTab(id) =>
              PluginHubCatalogTopBar(tabId: id),
            _ => null,
          };
        }

        final shell = ShellFindShortcutScope(
          enabled: profile == ShellProfile.desktop,
          onFind: _onFindShortcut,
          child: ShellHost(
            visibleIds: _visibleIds,
            selectedIndex: _selectedIndex,
            mountedTabIds: _mountedTabIds,
            onDestinationSelected: _selectTab,
            tabFor: _shellTabFor,
            shellHeader: _shellHeader(),
            shellTopBar: shellTopBar,
            // Root fullscreen players (movies, trailers, Live Matches) leave
            // the rail mounted/painted under the opaque route. IPTV sets
            // [ShellBus.maskShellUnderPlayer] so the catalog is not visible
            // under the slide. Overlay Music still uses [hideGlobalNav].
            hideGlobalNav: ShellBus.hideGlobalNav.value,
            maskUnderPlayer: ShellBus.maskShellUnderPlayer.value,
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
