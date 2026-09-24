import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/nav/open_catalog_search.dart';
import 'package:forja/shared/engine/runtime/kit/pack_layout_host.dart';
import 'package:forja/shell/chrome/plugin_kit_top_bar.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/shell/adapters/shell_host.dart';
import 'package:forja/shell/frame/shell_empty_features_screen.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/platform/shell_find_shortcut.dart';
import 'package:forja/shell/platform/macos_shell_channel.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shell/routing/shell_tab_refresh.dart';

import 'package:forja/shared/engine/cache/engine_cache.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shared/engine/runtime/vm/service.dart';
import 'package:forja/shared/services/update/app_update_auto_check.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';
import 'package:forja/shell/core/forja_shell_platform.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/home_loading_skeleton.dart';
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
  /// Drop stale navbar loads when toggles fire faster than async reloads.
  int _navbarLoadGen = 0;
  /// When every feature tab is hidden, show [ShellEmptyFeaturesScreen] until
  /// the user opens Settings from the rail or an empty-state CTA.
  bool _emptyFeaturesBodyDismissed = false;
  BuildContext? _shellScopedContext;

  bool get _hasFeatureTabs =>
      _visibleIds.any((id) => id != 'settings');

  bool get _showEmptyFeaturesGate =>
      _initialNavResolved && !_hasFeatureTabs && !_emptyFeaturesBodyDismissed;

  void _syncEmptyFeaturesGate() {
    final gate = _showEmptyFeaturesGate;
    if (ShellBus.emptyFeaturesGate.value == gate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ShellBus.emptyFeaturesGate.value != gate) {
        ShellBus.emptyFeaturesGate.value = gate;
      }
    });
  }

  String? get _currentTabId =>
      _visibleIds.isEmpty || _selectedIndex >= _visibleIds.length
          ? null
          : _visibleIds[_selectedIndex];

  Widget _tabFor(String id) {
    final builder = navTabBuilders[id];
    if (builder == null) {
      // Ghost / mid-refresh — do NOT cache shrink (would blank the hub forever).
      if (kDebugMode) {
        debugPrint('[MainScreen] No tab builder for $id — neutral wait');
      }
      return Builder(
        builder: (ctx) => hubNeutralLoadingSkeleton(ctx, tabId: id),
      );
    }
    final isNew = !_tabCache.containsKey(id);
    final tab = _tabCache.putIfAbsent(id, () {
      final key = _keyForTab(id);
      final child = builder();
      // PackLayoutHost keyed mount — keyed mount for ShellTabRefresh.
      if (child is PackLayoutHost) {
        return _tabWithKey(key, child);
      }
      if (key != null) {
        return KeyedSubtree(key: key, child: child);
      }
      return child;
    });
    if (isNew && kDebugMode) {
      debugPrint('[MainScreen] Built tab: $id');
    }
    return tab;
  }

  /// Hub [PackLayoutHost] must own the tab [GlobalKey] so [ShellTabRefresh] works.
  Widget _tabWithKey(GlobalKey<State<StatefulWidget>>? key, Widget child) {
    if (key == null) return child;
    if (child is PackLayoutHost) {
      return PackLayoutHost(
        key: key,
        pluginId: child.pluginId,
        tabId: child.tabId,
        packSourceUrl: child.packSourceUrl,
        pageAction: child.pageAction,
        pageParams: child.pageParams,
      );
    }
    return KeyedSubtree(key: key, child: child);
  }

  void _touchTab(String id) {
    _tabLru.remove(id);
    _tabLru.add(id);
  }

  void _evictTab(String id) {
    final current = _currentTabId;
    if (current != null && id == current) return;
    if (_tabBlocksEviction(id)) return;

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
  /// tabs that normally block LRU — so decode gets max RAM/GPU.
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
        if (id != current && !_tabBlocksEviction(id)) {
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
    // Cloud Features / profile settings: soft pull on side-nav use so web
    // changes land (debounced 15s). Local toggles push only — syncFromCloud
    // flushes dirty nav before applying cloud as SoT (224).
    if (SyncService.instance.isSignedIn) {
      unawaited(SyncDomainBridge.instance.syncFromCloud());
    }
    final previousId = _currentTabId;
    final id = _visibleIds[index];
    final sameTab = previousId == id;
    if (previousId != null && previousId != id) {
      _notifyTabHidden(previousId);
      VerticalFiltersRegistry.onLeaveTab(previousId);
    } else if (sameTab) {
      VerticalFiltersRegistry.onNavRepress(id);
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
      // Re-tap active tab = force reload (hubs / IPTV / …).
      _refreshTabIfStale(id, force: sameTab);
    });
  }

  bool _musicUsesOwnSidebar(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
  }

  void _applyTabShellChrome(String tabId) {
    // Overlays / tabs set [ShellBus.hideGlobalNav] themselves; clear on switch.
    // Music desktop sidebar still needs its own rail hide while that tab is active.
    if (tabId == 'music') {
      ShellBus.hideGlobalNav.value = _musicUsesOwnSidebar(context);
      ShellBus.notifyShellChromeChanged();
      return;
    }
    ShellBus.clearHideGlobalNav();
    ShellBus.notifyShellChromeChanged();
  }

  @override
  void initState() {
    super.initState();
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
    SettingsService.navbarChangeNotifier.addListener(_onNavbarConfigChanged);
    ShellBus.completeNavbarReloadRevision.addListener(_onCompleteNavbarReload);

    unawaited(_refreshHubNavThenLoad());
    _syncCurrentNavTab();
    _updateAutoCheck.start(() => _shellScopedContext ?? context);
  }

  void _onEnginePackChanged() {
    unawaited(_refreshHubNavThenLoad());
  }

  void _onCompleteNavbarReload() {
    unawaited(_forceCompleteNavbarReload());
  }

  Future<void>? _completeNavbarReloadInFlight;

  /// Hold-nav gesture: remount every hub, re-read Features rail, wipe pack caches.
  Future<void> _forceCompleteNavbarReload() async {
    if (_completeNavbarReloadInFlight != null) {
      await _completeNavbarReloadInFlight;
      return;
    }
    final run = () async {
      // Name the toast after the held rail item — not the selected tab.
      final tabId = ShellBus.takeCompleteNavbarReloadTabId() ?? _currentTabId;
      final tabName =
          (tabId != null ? navDestinationFor(tabId)?.label : null)?.trim();
      final name = (tabName != null && tabName.isNotEmpty) ? tabName : 'Navbar';
      ForjaToast.info('Reloading $name…');
      // Abort in-flight hub catalog / flutter_js forks before wipe + remount so
      // the new painter's layout is not stuck behind dead Stremio rail work
      // (blank hub after hold-to-reload).
      EngineService.instance.cancelCatalog();
      EngineService.instance.cancelLiveCatalog();
      for (final hubTabId in PluginNavRegistry.destinations.keys) {
        final id = PluginNavRegistry.pluginIdForTabSync(hubTabId);
        if (id != null && id.isNotEmpty) {
          EngineCache.instance.wipePlugin(id);
        }
      }
      _invalidateHubTabsAfterPackChange(remountBuilders: true);
      await PluginNavRegistry.refresh();
      if (!mounted) return;
      await _loadNavbarConfig(force: true);
      if (!mounted) return;
      _ensureSelectedKitTabMounted(forceRefresh: true);
      PluginRegistry.bumpHubFeedEpoch(all: true);
      if (!mounted) return;
      ForjaToast.success('$name reloaded');
    }();
    _completeNavbarReloadInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_completeNavbarReloadInFlight, run)) {
        _completeNavbarReloadInFlight = null;
      }
    }
  }

  Future<void>? _hubNavReloadInFlight;
  bool _hubNavReloadQueued = false;

  Future<void> _refreshHubNavThenLoad() async {
    if (_hubNavReloadInFlight != null) {
      // Bulk Reload notifies per pack — finish current pass, then run again so
      // later packs still invalidate hub layout (not navbar-only).
      _hubNavReloadQueued = true;
      return;
    }
    do {
      _hubNavReloadQueued = false;
      final run = () async {
        final changed = await PluginNavRegistry.refresh();
        if (!mounted) return;
        // Only remount / hard-refresh hubs when nav shape changed. Lean sync and
        // unrelated pack notifies used to mark every hub stale → soft return
        // wiped rails while the hero kept slides. Script/install wipes go through
        // [PluginRegistry.hubFeedEpoch] → PackLayoutHost.
        if (changed) {
          _invalidateHubTabsAfterPackChange(remountBuilders: true);
        }
        await _loadNavbarConfig();
        if (!mounted) return;
        // Invalidate drops hubs from [_mountedTabIds]; navbar reload may early-return
        // when ids are unchanged (post-install promote already painted). Without
        // remounting the selected hub, the rail stays on it but the body is empty
        // until the user taps the tab again. forceRefresh when we wiped cache.
        _ensureSelectedKitTabMounted(forceRefresh: changed);
      }();
      _hubNavReloadInFlight = run;
      try {
        await run;
      } finally {
        if (identical(_hubNavReloadInFlight, run)) {
          _hubNavReloadInFlight = null;
        }
      }
    } while (_hubNavReloadQueued && mounted);
  }

  void _invalidateHubTabsAfterPackChange({required bool remountBuilders}) {
    // Contributed hubs only — seed + last refresh; no frozen official-id list.
    final hubIds = PluginNavRegistry.destinations.keys.toSet();
    final selected = _currentTabId;
    for (final id in hubIds) {
      _refreshStateFor(id)?.markShellTabStale();
      if (!remountBuilders) continue;
      _tabCache.remove(id);
      _mountedTabIds.remove(id);
      _tabLru.remove(id);
      // Drop GlobalKey so a new PackLayoutHost State is created (same key would
      // reparent and keep the old memoized rails).
      _tabKeys.remove(id);
    }
    // Keep the open hub in [_mountedTabIds] so [ShellBody] never paints
    // SizedBox.shrink for the selected slot (blank — no loading, no structure)
    // between this wipe and [_ensureSelectedKitTabMounted].
    if (selected != null && hubIds.contains(selected)) {
      _mountedTabIds.add(selected);
      _touchTab(selected);
    }
    // Selected hub remount / show notify still runs after [_loadNavbarConfig]
    // via [_ensureSelectedKitTabMounted] (promote / index must settle first).
  }

  /// Keep the selected hub body mounted after pack-nav invalidate.
  ///
  /// [ShellBody] only builds tabs in [_mountedTabIds]. Invalidate clears that
  /// set; a no-op navbar reload must not leave the rail on an empty slot.
  /// When [forceRefresh] is true (cache wiped), notify + force-refresh even if
  /// the selected hub stayed mounted to avoid a blank shrink frame.
  void _ensureSelectedKitTabMounted({bool forceRefresh = false}) {
    final current = _currentTabId;
    if (current == null || !PluginNavRegistry.isKitTab(current)) return;
    final alreadyMounted = _mountedTabIds.contains(current);
    if (alreadyMounted && !forceRefresh) return;
    if (!alreadyMounted) {
      setState(() {
        _mountedTabIds.add(current);
        _touchTab(current);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentTabId != current) return;
      _notifyTabShown(current);
      _refreshTabIfStale(current, force: true);
    });
  }

  Future<void> _loadNavbarConfig({bool force = false}) async {
    final gen = ++_navbarLoadGen;
    var visible = await SettingsService().getNavbarConfig();
    final defaultTab = await SettingsService().getDefaultNavTab();
    if (!mounted || gen != _navbarLoadGen) return;
    final addonFeatures = await SettingsService().listAvailableAddonFeatureNavIds();
    if (!mounted || gen != _navbarLoadGen) return;
    final addonSet = addonFeatures.toSet();
    final beforeFilter = List<String>.from(visible);
    // Trust Features `visibleIds`. Do not filter with [isContributed] — that
    // dropped Anime on the rail while KV still had it and Features showed ON
    // (load raced mid-refresh / empty dest map → silent no-op skip). Pack-off
    // cleanup is [PluginNavRegistry] sync only.
    visible = visible
        .where((id) => !archivedNavIds.contains(id))
        .where(
          (id) =>
              !SettingsService.addonGatedNavIds.contains(id) ||
              addonSet.contains(id),
        )
        .toList();
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      visible = visible
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
    }
    if (!mounted || gen != _navbarLoadGen) return;
    final nextIds = [...visible, 'settings'];
    // Skip no-op reloads — notifier storms were reprinting visible=[] forever.
    // Compare against what we would paint (post-filter), not raw KV.
    if (!force &&
        _initialNavResolved &&
        listEquals(_visibleIds, nextIds) &&
        !ShellBus.selectDefaultTabOnNextNavLoad) {
      if (kDebugMode && !listEquals(beforeFilter, visible)) {
        debugPrint(
          '[MainScreen] navbar skipped paint $beforeFilter → $visible '
          '(already $_visibleIds)',
        );
      }
      return;
    }
    if (kDebugMode && !listEquals(beforeFilter, visible)) {
      debugPrint(
        '[MainScreen] navbar filter $beforeFilter → $visible '
        '(addons=$addonSet)',
      );
    } else if (kDebugMode) {
      debugPrint('[MainScreen] navbar visible=$visible');
    }
    final applyDefaultTab = ShellBus.selectDefaultTabOnNextNavLoad;
    setState(() {
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      final hadFeatureTabs = _visibleIds.any((id) => id != 'settings');
      // Stay in real Settings when the last feature tab is unchecked while
      // already there. Do not clear dismissed mid-edit (that flashed the
      // get-started empty shell over Settings). Cold empty + logo return
      // still use dismissed=false.
      if (visible.isEmpty && currentId == 'settings' && hadFeatureTabs) {
        _emptyFeaturesBodyDismissed = true;
      } else if (visible.isNotEmpty && currentId != 'settings') {
        _emptyFeaturesBodyDismissed = false;
      }
      _visibleIds = nextIds;
      // Cold start can paint Settings-only (guest scope / empty cache / hub
      // builders not ready) before the real Features rail lands. When feature
      // tabs appear while still on Settings, apply the starred default once
      // (same as profile switch) — issue 253.
      // Do not promote when the user already opened Settings (pack remove /
      // install must not yank Forja Packs → Home / IPTV).
      final promoteFromSettingsOnly = !hadFeatureTabs &&
          visible.isNotEmpty &&
          currentId == 'settings' &&
          defaultTab != 'settings' &&
          !_emptyFeaturesBodyDismissed;
      if (!_initialNavResolved || applyDefaultTab || promoteFromSettingsOnly) {
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
        _selectedIndex = SettingsService.resolveBuildableShellTabIndex(
          _visibleIds,
          defaultTabId: defaultTab,
          hasBuilder: navTabBuilders.containsKey,
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
          // Keep the arm until we land on the starred tab (or the star is
          // Settings). Empty-rail / late cloud default used to clear the flag
          // while still on Settings, then preserve Settings forever.
          if (applyDefaultTab) {
            final matched = tabId == defaultTab;
            final starMissing = defaultTab != 'settings' &&
                !visible.contains(defaultTab) &&
                tabId != 'settings';
            if (matched || defaultTab == 'settings' || starMissing) {
              ShellBus.selectDefaultTabOnNextNavLoad = false;
            }
          }
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

  Timer? _navbarReloadDebounce;

  void _onNavbarConfigChanged() {
    _navbarReloadDebounce?.cancel();
    _navbarReloadDebounce = Timer(const Duration(milliseconds: 32), () {
      if (!mounted) return;
      unawaited(_loadNavbarConfig());
    });
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
      target = featureIds.isNotEmpty ? featureIds.first : 'settings';
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

  void _openAddonsFromEmptyState() {
    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;
    final tv = ShellScope.metricsOf(ctx).usesTvDensity;
    ShellBus.openSettings(
      categoryId: SettingsCategoryId.addons,
      enterDetail: tv,
    );
  }

  void _openPluginsFromEmptyState() {
    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;
    final tv = ShellScope.metricsOf(ctx).usesTvDensity;
    // Always land on Forja Packs (manifest URL / community). Batch prompt only
    // fires when profile packs still need download — without this fallback the
    // CTA was a silent no-op on an empty or fully-downloaded profile.
    ShellBus.openSettings(
      categoryId: SettingsCategoryId.forjaPacks,
      enterDetail: tv,
    );
    unawaited(PluginInstallCoordinator.instance.requestBatchInstallPrompt());
  }

  Widget _shellTabFor(String id) {
    if (id == 'settings' && _showEmptyFeaturesGate) {
      return ShellEmptyFeaturesScreen(
        onOpenAddons: _openAddonsFromEmptyState,
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
    if (tabId == null || !PluginNavRegistry.isKitTab(tabId)) return;

    final ctx = _shellScopedContext;
    if (ctx == null || !ctx.mounted) return;

    final pluginId = await PluginNavRegistry.pluginIdForTab(tabId);
    if (pluginId == null || !ctx.mounted) return;

    final label = PluginNavRegistry.destinations[tabId]?.label;
    await openKitSearch(
      ctx,
      pluginId: pluginId,
      tabId: tabId,
      hintText: label == null || label.isEmpty ? 'Search…' : 'Search $label…',
    );
  }

  @override
  void dispose() {
    _navbarReloadDebounce?.cancel();
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
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarConfigChanged);
    ShellBus.completeNavbarReloadRevision.removeListener(_onCompleteNavbarReload);
    ShellBus.clearOverlayShellTabId();
    ShellBus.activeShellTabId = null;
    ShellBus.clearHideGlobalNav();
    ShellBus.clearMaskShellUnderPlayer();
    ShellBus.emptyFeaturesGate.value = false;
    MacOsShellChannel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncEmptyFeaturesGate();
    return ShellScopeBuilder(
      builder: (shellContext, profile) {
        _shellScopedContext = shellContext;
        final config = shellPlatformConfigFor(profile);
        final showKitTopBar = config.showKitTopBar &&
            !ShellBus.shellOverlayHasPage.value;
        final Widget? shellTopBar;
        if (!showKitTopBar) {
          shellTopBar = null;
        } else {
          shellTopBar = switch (_currentTabId) {
            null => null,
            // ValueKey: do not reuse State across hubs (Home caps ≠ Live Sports).
            final id when PluginNavRegistry.isKitTab(id) =>
              PluginKitTopBar(key: ValueKey(id), tabId: id),
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
            // Root fullscreen players (movies, trailers, Live Sports) leave
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
