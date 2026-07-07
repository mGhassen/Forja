import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shell-level event bus — decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

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

  static void notifyShellChromeChanged() {
    shellChromeRevision.value++;
  }

  static void openStremioSearch({required String query, required String addonBaseUrl}) {
    stremioSearchNotifier.value = null;
    stremioSearchNotifier.value = {'query': query, 'addonBaseUrl': addonBaseUrl};
  }
}
