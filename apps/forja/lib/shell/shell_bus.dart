import 'package:flutter/foundation.dart';
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

  /// TMDB watch-provider filter for Home desktop top bar (`null` = all providers).
  static final ValueNotifier<int?> selectedWatchProviderId = ValueNotifier(
    null,
  );

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

  /// Mid-session profile switch: next navbar reload selects the profile default tab.
  /// Cleared by [MainScreen] when applied.
  static bool selectDefaultTabOnNextNavLoad = false;

  /// True after the splash overlay is dismissed - defer heavy tab work until then.
  static final ValueNotifier<bool> splashDismissed = ValueNotifier<bool>(false);

  /// Bumps when shell chrome (e.g. search bar) needs a rebuild.
  static final ValueNotifier<int> shellChromeRevision = ValueNotifier<int>(0);

  /// When true, shell hides global rail / bottom nav (IPTV deep views, Music desktop).
  static final ValueNotifier<bool> hideGlobalNav = ValueNotifier<bool>(false);

  /// True when [ShellOverlayNavigator] has a route above the transparent root.
  static final ValueNotifier<bool> shellOverlayHasPage = ValueNotifier<bool>(
    false,
  );

  /// True while any fullscreen video player surface is mounted.
  /// Hides shell nav for overlay players (IPTV) and update toasts over playback.
  static final ValueNotifier<bool> playerSurfaceActive = ValueNotifier<bool>(
    false,
  );

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

  static void enterPlayerSurface() {
    _playerSurfaceDepth++;
    _syncPlayerSurfaceActive();
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
