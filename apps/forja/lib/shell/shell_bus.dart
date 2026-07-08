import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Home desktop top-bar category (Films vs TV Shows).
enum ShellHomeCategory { films, tvShows }

/// Shell-level event bus — decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

  /// Films / TV Shows filter for [HomeScreen] (`null` = mixed feed).
  static final ValueNotifier<ShellHomeCategory?> homeCategory =
      ValueNotifier<ShellHomeCategory?>(null);

  /// Genre filter for Home top-bar Categories menu (`null` = all genres).
  static final ValueNotifier<String?> homeSelectedGenreId =
      ValueNotifier<String?>(null);

  /// TMDB watch-provider filter for Home desktop top bar (`null` = all providers).
  static final ValueNotifier<int?> selectedWatchProviderId = ValueNotifier(null);

  /// Home feed vertical scroll — [HomeTopBar] hides when this passes [homeHeroHeight].
  static final ValueNotifier<double> homeScrollOffset = ValueNotifier(0);

  /// Hero block height in px — [HomeScreen] publishes on layout.
  static final ValueNotifier<double> homeHeroHeight = ValueNotifier(0);

  /// SearchScreen listens for incoming Stremio search requests.
  /// Value: {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier =
      ValueNotifier<Map<String, String>?>(null);

  /// Switch nav tab from anywhere: `ShellBus.requestTab.value = 'home';`
  static final ValueNotifier<String?> requestTab = ValueNotifier<String?>(null);

  /// True after the splash overlay is dismissed — defer heavy tab work until then.
  static final ValueNotifier<bool> splashDismissed = ValueNotifier<bool>(false);

  /// Bumps when shell chrome (e.g. search bar) needs a rebuild.
  static final ValueNotifier<int> shellChromeRevision = ValueNotifier<int>(0);

  /// When true, shell hides global rail / bottom nav (IPTV deep views, Music desktop).
  static final ValueNotifier<bool> hideGlobalNav = ValueNotifier<bool>(false);

  /// True when [ShellOverlayNavigator] has a route above the transparent root.
  static final ValueNotifier<bool> shellOverlayHasPage =
      ValueNotifier<bool>(false);

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

  static void openStremioSearch({required String query, required String addonBaseUrl}) {
    stremioSearchNotifier.value = null;
    stremioSearchNotifier.value = {'query': query, 'addonBaseUrl': addonBaseUrl};
  }
}
