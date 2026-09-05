import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_vertical_filters.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';

/// Shell-level event bus - decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

  /// Selected pack chrome menu id for Home (`filters.menus[].id`, null = mixed).
  static ValueNotifier<String?> get homeSelectedMenuId =>
      hubSelectedMenuIdFor('home');

  /// Genre filter for Home top-bar Categories menu (`null` = all genres).
  static ValueNotifier<String?> get homeSelectedGenreId =>
      hubSelectedCategoryIdFor('home');

  /// Pack-declared top-bar menu selection (`filters.menus[].id`, null = none).
  static ValueNotifier<String?> hubSelectedMenuIdFor(String tabId) =>
      _hubSelectedMenuIds.putIfAbsent(tabId, () => ValueNotifier(null));

  /// Categories menu selection for plugin hub top bars (`null` = all).
  static ValueNotifier<String?> hubSelectedCategoryIdFor(String tabId) =>
      _hubSelectedCategoryIds.putIfAbsent(tabId, () => ValueNotifier(null));

  /// TMDB watch-provider filter for Home (`null` = all providers).
  /// Deprecated — use [CatalogVerticalFiltersRegistry] for hub tabs.
  static final ValueNotifier<int?> selectedWatchProviderId = ValueNotifier(
    null,
  );

  /// Floating hub vertical-filter panel (hover/hold nav, or top-logo tap).
  /// Session UI only — not persisted. Hide on leave-tab, tap-outside, or
  /// desktop unhover after [homeProviderMenuHideDelay].
  static ValueNotifier<bool> get homeProviderMenuVisible =>
      CatalogVerticalFiltersRegistry.menuVisibleFor('home');

  /// [TapRegion.groupId] for the panel + top-bar selected-provider mark.
  static const Object homeProviderMenuTapGroup = Object();

  /// Desktop: hover Home nav this long before the provider panel opens.
  static const Duration homeProviderMenuHoverDelay = Duration(seconds: 1);

  /// TV: hold OK on Home this long before the provider panel opens.
  static const Duration homeProviderMenuHoldDelay = Duration(
    milliseconds: 500,
  );

  /// Desktop: hide after pointer leaves Home nav / provider panel.
  static const Duration homeProviderMenuHideDelay = Duration(seconds: 1);

  static void cancelHomeProviderMenuHide() {
    CatalogVerticalFiltersRegistry.cancelMenuHide('home');
  }

  static void scheduleHomeProviderMenuHide() {
    CatalogVerticalFiltersRegistry.scheduleMenuHide('home');
  }

  static void showHomeProviderMenu() {
    CatalogVerticalFiltersRegistry.showMenu('home');
  }

  static void hideHomeProviderMenu() {
    CatalogVerticalFiltersRegistry.hideMenu('home');
  }

  /// Top-bar selected-filter mark: open panel, or clear filter if already open.
  static void onTopProviderLogoTap() {
    CatalogVerticalFiltersRegistry.onTopLogoTap('home');
  }

  /// Leaving a hub tab hides the panel; filter stays until cleared.
  static void onLeaveHomeTab() {
    CatalogVerticalFiltersRegistry.onLeaveTab('home');
  }

  /// Hub feed vertical scroll — catalog top bar hide anchor.
  static ValueNotifier<double> get homeScrollOffset =>
      hubScrollOffsetFor('home');

  static final Map<String, ValueNotifier<double>> _hubScrollOffsets = {};
  static final Map<String, ValueNotifier<double>> _hubHeroHeights = {};
  static final Map<String, ValueNotifier<String?>> _hubSelectedMenuIds = {};
  static final Map<String, ValueNotifier<String?>> _hubSelectedCategoryIds = {};

  /// Per-tab scroll offset for catalog hub tabs.
  static ValueNotifier<double> hubScrollOffsetFor(String tabId) =>
      _hubScrollOffsets.putIfAbsent(tabId, () => ValueNotifier(0));

  /// Per-tab cinematic hero height for catalog hub tabs.
  static ValueNotifier<double> get homeHeroHeight => hubHeroHeightFor('home');

  static ValueNotifier<double> hubHeroHeightFor(String tabId) =>
      _hubHeroHeights.putIfAbsent(tabId, () => ValueNotifier(0));

  /// SearchScreen listens for incoming Stremio search requests.
  /// Value: {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier =
      ValueNotifier<Map<String, String>?>(null);

  /// Switch nav tab from anywhere: `ShellBus.requestTab.value = 'home';`
  static final ValueNotifier<String?> requestTab = ValueNotifier<String?>(null);

  /// Nav-rail Forja logo tap — [MainScreen] returns to get-started or default tab.
  static final ValueNotifier<int> shellLogoTapRevision = ValueNotifier(0);

  static void notifyShellLogoTap() {
    shellLogoTapRevision.value++;
  }

  /// Settings hub category to select on the next Settings show (`lan`, `playback`, …).
  static final ValueNotifier<String?> requestSettingsCategory =
      ValueNotifier<String?>(null);

  /// Plugin pack install from web / deep link / remote profile — FIFO queue.
  static final ValueNotifier<List<PluginInstallPrompt>>
      pendingPluginInstallQueue = ValueNotifier<List<PluginInstallPrompt>>([]);

  /// Head of [pendingPluginInstallQueue] (deep-link + tests).
  static final ValueNotifier<PluginInstallPrompt?> pendingPluginInstall =
      ValueNotifier<PluginInstallPrompt?>(null);

  static void enqueuePluginInstall(PluginInstallPrompt prompt) {
    final url = prompt.manifestUrl.trim();
    if (url.isEmpty) return;
    final next = List<PluginInstallPrompt>.from(pendingPluginInstallQueue.value);
    if (next.any(
      (p) => p.manifestUrl.trim() == url && p.kind == prompt.kind,
    )) {
      return;
    }
    next.add(
      PluginInstallPrompt(
        manifestUrl: url,
        displayName: prompt.displayName,
        source: prompt.source,
        kind: prompt.kind,
      ),
    );
    pendingPluginInstallQueue.value = next;
    pendingPluginInstall.value = next.first;
  }

  static PluginInstallPrompt? takeNextPluginInstall() {
    final next = List<PluginInstallPrompt>.from(pendingPluginInstallQueue.value);
    if (next.isEmpty) {
      pendingPluginInstall.value = null;
      return null;
    }
    final first = next.removeAt(0);
    pendingPluginInstallQueue.value = next;
    pendingPluginInstall.value = next.isEmpty ? null : next.first;
    return first;
  }

  static PluginInstallPrompt? takePendingPluginInstall() =>
      takeNextPluginInstall();

  @visibleForTesting
  static void resetPluginInstallQueueForTest() {
    pendingPluginInstallQueue.value = [];
    pendingPluginInstall.value = null;
    pendingPluginBatchInstall.value = null;
  }

  /// Profile / sync batch install — user picks which packs to download now.
  static final ValueNotifier<PluginBatchInstallPrompt?> pendingPluginBatchInstall =
      ValueNotifier<PluginBatchInstallPrompt?>(null);

  static PluginBatchInstallPrompt? takePendingPluginBatchInstall() {
    final value = pendingPluginBatchInstall.value;
    pendingPluginBatchInstall.value = null;
    return value;
  }

  /// Last Settings hub category. Survives tab remount / resume sync — do not
  /// reset to Profile on cloud pull.
  static final ValueNotifier<String> settingsHubCategoryId =
      ValueNotifier<String>('profile');

  /// When true, the next Settings hub build should D-pad into the category pane.
  static bool _enterSettingsDetail = false;

  /// When an old top-level category (debrid, lan, accounts, iptv_sports) is
  /// requested, this holds the addon ID to open inside the Addons hub.
  static String? pendingAddonDeepLink;

  /// Aliases for categories that were merged into Addons.
  static const _addonCategoryAliases = <String, String>{
    'playback': 'playback',
    'debrid': 'debrid',
    'iptv_sports': 'live_sports',
    'accounts': 'connected_services',
    'lan': 'lan',
  };

  /// Switch to Settings, optionally landing on [categoryId] in the split hub.
  ///
  /// [enterDetail] (TV): after the tab shows, move focus into that category's
  /// pane so leftover Select KeyUp cannot hit the nav rail.
  static void openSettings({String? categoryId, bool enterDetail = false}) {
    if (categoryId != null) {
      final addonAlias = _addonCategoryAliases[categoryId];
      if (addonAlias != null) {
        pendingAddonDeepLink = addonAlias;
        categoryId = 'sources'; // Addons hub
      }
      settingsHubCategoryId.value = categoryId;
      requestSettingsCategory.value = categoryId;
    }
    if (enterDetail) _enterSettingsDetail = true;
    requestTab.value = 'settings';
  }

  static bool takeEnterSettingsDetail() {
    if (!_enterSettingsDetail) return false;
    _enterSettingsDetail = false;
    return true;
  }

  /// Mid-session profile switch: next navbar reload selects the profile default tab.
  /// Cleared by [MainScreen] when applied.
  static bool selectDefaultTabOnNextNavLoad = false;

  /// True after the splash overlay is dismissed - defer heavy tab work until then.
  static final ValueNotifier<bool> splashDismissed = ValueNotifier<bool>(false);

  /// Bumps when shell chrome (e.g. search bar) needs a rebuild.
  static final ValueNotifier<int> shellChromeRevision = ValueNotifier<int>(0);

  /// When true, shell hides global rail / bottom nav (IPTV deep views, Music desktop).
  static final ValueNotifier<bool> hideGlobalNav = ValueNotifier<bool>(false);

  /// Opaque black cover over the shell while a root IPTV player is up.
  /// Hides the catalog/rail underlay during slide enter/exit (no layout reflow).
  /// Movies/Live Matches leave this false — underlay stays under their opaque route.
  static final ValueNotifier<bool> maskShellUnderPlayer = ValueNotifier<bool>(
    false,
  );

  /// True when [ShellOverlayNavigator] has a route above the transparent root.
  static final ValueNotifier<bool> shellOverlayHasPage = ValueNotifier<bool>(
    false,
  );

  /// Authoritative shell tab from [MainScreen] — used when overlay routes open
  /// so origin capture does not rely on TV focus state alone.
  static String? activeShellTabId;

  /// Shell tab that was active when the first overlay route was pushed (e.g.
  /// `anime` / `asian_drama` before details). Restored after pop-to-root so nav
  /// selection stays aligned with the hub under the overlay.
  static String? _overlayShellTabId;

  static void noteOverlayPushOrigin(String? tabId) {
    final resolved = tabId ?? activeShellTabId;
    if (resolved == null || resolved.isEmpty) return;
    _overlayShellTabId = resolved;
  }

  static String? takeOverlayShellTabId() {
    final id = _overlayShellTabId;
    _overlayShellTabId = null;
    return id;
  }

  static void clearOverlayShellTabId() => _overlayShellTabId = null;

  /// After the overlay stack returns to root, re-select the tab that opened it.
  /// TV: restore catalog focus. Desktop: clear stale rail focus (selection only).
  static void finishOverlayAndRestoreShellTab() {
    final origin = takeOverlayShellTabId();
    if (origin == null || origin.isEmpty) return;
    if (activeShellTabId != origin) {
      requestTab.value = origin;
    }
    ShellTvFocus.currentNavTabId = origin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ShellTvFocusCoordinator.tvBackPolicyEnabled) {
        ShellTvFocusCoordinator.unfocusShellNav();
        ShellTvFocusCoordinator.restoreTabFocusAfterOverlayPop(origin);
        return;
      }
      ShellTvFocusCoordinator.unfocusShellNav();
    });
  }

  /// True while any fullscreen video player surface is mounted.
  /// Drives tab purge, image-cache trim, and update-toast suppression — not
  /// nav hide. Overlay players (IPTV) set [hideGlobalNav] themselves.
  static final ValueNotifier<bool> playerSurfaceActive = ValueNotifier<bool>(
    false,
  );

  /// Bumps when a player surface becomes active (depth 0→1). [MainScreen]
  /// listens and force-evicts sibling mounted tabs (keeps the screen under
  /// the player) so decode gets max RAM.
  static final ValueNotifier<int> playerResourcePurgeRevision =
      ValueNotifier<int>(0);

  static int _playerSurfaceDepth = 0;
  static bool _playerSurfaceNotifyPending = false;
  static bool _playbackImageTrimPending = false;

  /// Flutter defaults (~1000 images / 100MB). While a player is up, keep a
  /// tiny budget so catalog logos cannot refill GPU after the trim.
  static const int playbackImageCacheMaxBytes = 16 * 1024 * 1024;
  static const int playbackImageCacheMaxCount = 80;
  static int? _imageCacheMaxBytesBeforePlayback;
  static int? _imageCacheMaxCountBeforePlayback;

  /// Updates [playerSurfaceActive] from [_playerSurfaceDepth]. Defers the
  /// notifier when called during build/layout/paint so ListenableBuilder
  /// ancestors are not marked dirty mid-frame.
  static void _syncPlayerSurfaceActive() {
    final active = _playerSurfaceDepth > 0;
    if (playerSurfaceActive.value == active) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      playerSurfaceActive.value = active;
      return;
    }

    if (_playerSurfaceNotifyPending) return;
    _playerSurfaceNotifyPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _playerSurfaceNotifyPending = false;
      final shouldBeActive = _playerSurfaceDepth > 0;
      if (playerSurfaceActive.value != shouldBeActive) {
        playerSurfaceActive.value = shouldBeActive;
      }
    });
  }

  /// Drop decoded catalog / poster bitmaps so the next player session can
  /// claim MediaCodec + GPU memory on weak Android TV SoCs.
  static void trimImageCacheForPlayback() {
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static void _capImageCacheForPlayback() {
    final cache = imageCache;
    _imageCacheMaxBytesBeforePlayback ??= cache.maximumSizeBytes;
    _imageCacheMaxCountBeforePlayback ??= cache.maximumSize;
    cache.maximumSizeBytes = playbackImageCacheMaxBytes;
    cache.maximumSize = playbackImageCacheMaxCount;
  }

  static void restoreImageCacheAfterPlayback() {
    final cache = imageCache;
    final bytes = _imageCacheMaxBytesBeforePlayback;
    if (bytes != null) {
      cache.maximumSizeBytes = bytes;
      _imageCacheMaxBytesBeforePlayback = null;
    }
    final count = _imageCacheMaxCountBeforePlayback;
    if (count != null) {
      cache.maximumSize = count;
      _imageCacheMaxCountBeforePlayback = null;
    }
  }

  /// Trim + cap after catalog Image widgets have left the tree.
  /// Idle/post-frame: [playerSurfaceActive] listeners already rebuilt.
  /// Mid-build: wait one frame so we do not clear under a still-mounted grid.
  static void _schedulePlaybackImageTrim() {
    void run() {
      if (_playerSurfaceDepth <= 0) return;
      trimImageCacheForPlayback();
      _capImageCacheForPlayback();
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      run();
      return;
    }
    if (_playbackImageTrimPending) return;
    _playbackImageTrimPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _playbackImageTrimPending = false;
      run();
    });
  }

  static void enterPlayerSurface() {
    final becameActive = _playerSurfaceDepth == 0;
    _playerSurfaceDepth++;
    _syncPlayerSurfaceActive();
    if (becameActive) {
      _schedulePlaybackImageTrim();
      // Defer tab purge past the current build/layout phase (same as surface
      // active notifier) so MainScreen setState is never mid-frame.
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        playerResourcePurgeRevision.value++;
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          playerResourcePurgeRevision.value++;
        });
      }
    }
  }

  static void leavePlayerSurface() {
    if (_playerSurfaceDepth > 0) _playerSurfaceDepth--;
    _syncPlayerSurfaceActive();
    if (_playerSurfaceDepth == 0) {
      restoreImageCacheAfterPlayback();
    }
  }

  static void notifyShellChromeChanged() {
    shellChromeRevision.value++;
  }

  /// IPTV / Music call when leaving the tab; [MainScreen] also resets on tab switch.
  static void clearHideGlobalNav() {
    if (hideGlobalNav.value) {
      hideGlobalNav.value = false;
      notifyShellChromeChanged();
    }
  }

  static void clearMaskShellUnderPlayer() {
    if (maskShellUnderPlayer.value) {
      maskShellUnderPlayer.value = false;
      notifyShellChromeChanged();
    }
  }

  static void openStremioSearch({
    required String query,
    required String addonBaseUrl,
  }) {
    stremioSearchNotifier.value = null;
    stremioSearchNotifier.value = {
      'query': query,
      'addonBaseUrl': addonBaseUrl,
    };
  }

  static final List<bool Function()> _findShortcutHandlers = [];

  /// Register Cmd/Ctrl+F handling while a search surface is mounted (newest wins).
  static void registerFindShortcutHandler(bool Function() handler) {
    _findShortcutHandlers.remove(handler);
    _findShortcutHandlers.add(handler);
  }

  static void unregisterFindShortcutHandler(bool Function() handler) {
    _findShortcutHandlers.remove(handler);
  }

  /// Returns true when a registered handler consumed the shortcut.
  static bool invokeFindShortcut() {
    for (var i = _findShortcutHandlers.length - 1; i >= 0; i--) {
      if (_findShortcutHandlers[i]()) return true;
    }
    return false;
  }
}
