import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Home desktop top-bar category (Films vs TV Shows).
enum ShellHomeCategory { films, tvShows }

/// Shell-level event bus - decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

  /// Films / TV Shows filter for [HomeScreen] (`null` = mixed feed).
  static final ValueNotifier<ShellHomeCategory?> homeCategory =
      ValueNotifier<ShellHomeCategory?>(null);

  /// Genre filter for Home top-bar Categories menu (`null` = all genres).
  static final ValueNotifier<String?> homeSelectedGenreId =
      ValueNotifier<String?>(null);

  /// TMDB watch-provider filter for Home (`null` = all providers).
  static final ValueNotifier<int?> selectedWatchProviderId = ValueNotifier(
    null,
  );

  /// Floating Home provider panel (hover/hold Home, or top-logo tap).
  /// Session UI only — not persisted. Hide on leave-Home, tap-outside, or
  /// desktop unhover after [homeProviderMenuHideDelay].
  static final ValueNotifier<bool> homeProviderMenuVisible = ValueNotifier(
    false,
  );

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

  static Timer? _homeProviderHideTimer;

  static void cancelHomeProviderMenuHide() {
    _homeProviderHideTimer?.cancel();
    _homeProviderHideTimer = null;
  }

  /// Start (or restart) the desktop unhover hide timer.
  static void scheduleHomeProviderMenuHide() {
    if (!homeProviderMenuVisible.value) return;
    cancelHomeProviderMenuHide();
    _homeProviderHideTimer = Timer(homeProviderMenuHideDelay, () {
      _homeProviderHideTimer = null;
      hideHomeProviderMenu();
    });
  }

  static void showHomeProviderMenu() {
    cancelHomeProviderMenuHide();
    if (!homeProviderMenuVisible.value) {
      homeProviderMenuVisible.value = true;
    }
  }

  static void hideHomeProviderMenu() {
    cancelHomeProviderMenuHide();
    if (homeProviderMenuVisible.value) {
      homeProviderMenuVisible.value = false;
    }
  }

  /// Top-bar selected-provider mark: open panel, or clear filter if already open.
  static void onTopProviderLogoTap() {
    if (!homeProviderMenuVisible.value) {
      homeProviderMenuVisible.value = true;
      cancelHomeProviderMenuHide();
      return;
    }
    selectedWatchProviderId.value = null;
  }

  /// Leaving Home hides the panel; filter stays until cleared.
  static void onLeaveHomeTab() {
    hideHomeProviderMenu();
  }

  /// Home feed vertical scroll - [HomeTopBar] slides away near [homeHeroHeight].
  static final ValueNotifier<double> homeScrollOffset = ValueNotifier(0);

  /// Cinematic hero height in px (not the extended page-bleed backdrop).
  /// [HomeCinematicHero] publishes on layout; [HomeTopBar] uses it as the
  /// scroll-hide anchor.
  static final ValueNotifier<double> homeHeroHeight = ValueNotifier(0);

  /// SearchScreen listens for incoming Stremio search requests.
  /// Value: {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier =
      ValueNotifier<Map<String, String>?>(null);

  /// Switch nav tab from anywhere: `ShellBus.requestTab.value = 'home';`
  static final ValueNotifier<String?> requestTab = ValueNotifier<String?>(null);

  /// Settings hub category to select on the next Settings show (`lan`, `playback`, …).
  static final ValueNotifier<String?> requestSettingsCategory =
      ValueNotifier<String?>(null);

  /// Switch to Settings, optionally landing on [categoryId] in the split hub.
  static void openSettings({String? categoryId}) {
    if (categoryId != null) {
      requestSettingsCategory.value = categoryId;
    }
    requestTab.value = 'settings';
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

  static void enterPlayerSurface() {
    final becameActive = _playerSurfaceDepth == 0;
    _playerSurfaceDepth++;
    _syncPlayerSurfaceActive();
    if (becameActive) {
      trimImageCacheForPlayback();
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
