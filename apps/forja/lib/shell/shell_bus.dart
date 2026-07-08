import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Home desktop top-bar category (Films vs TV Shows).
enum ShellHomeCategory { films, tvShows }

/// Shell-level event bus — decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

  /// Films / TV Shows selection for [ShellTopBar] + [HomeScreen] feed.
  static final ValueNotifier<ShellHomeCategory> homeCategory =
      ValueNotifier(ShellHomeCategory.films);

  /// Home feed vertical scroll — [ShellTopBar] uses this for a gradient bg when scrolled.
  static final ValueNotifier<double> homeScrollOffset = ValueNotifier(0);

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
