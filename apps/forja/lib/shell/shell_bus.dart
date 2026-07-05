import 'package:flutter/foundation.dart';

/// Shell-level event bus — decouples features from [MainScreen].
class ShellBus {
  ShellBus._();

  /// SearchScreen listens for incoming Stremio search requests.
  /// Value: {'query': '...', 'addonBaseUrl': '...'} or null.
  static final ValueNotifier<Map<String, String>?> stremioSearchNotifier =
      ValueNotifier<Map<String, String>?>(null);

  /// Switch nav tab from anywhere: `ShellBus.requestTab.value = 'home';`
  static final ValueNotifier<String?> requestTab = ValueNotifier<String?>(null);

  static void openStremioSearch({required String query, required String addonBaseUrl}) {
    stremioSearchNotifier.value = null;
    stremioSearchNotifier.value = {'query': query, 'addonBaseUrl': addonBaseUrl};
  }
}
