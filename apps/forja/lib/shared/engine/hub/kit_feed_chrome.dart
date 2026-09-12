import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';

/// Opaque key for kit chrome prefs — prefer hub [pluginId], else `tab:<tabId>`.
String kitChromeKey({String? pluginId, String? tabId}) {
  final p = pluginId?.trim() ?? '';
  if (p.isNotEmpty) return p;
  final t = tabId?.trim() ?? '';
  if (t.isNotEmpty) return 'tab:$t';
  return '';
}

String kitChromeKeyForTab(String tabId) => kitChromeKey(
      pluginId: PluginNavRegistry.pluginIdForTabSync(tabId),
      tabId: tabId,
    );

/// Opaque catalog chip (`all` / plugin id / `stremio:…`) — per hub.
final kitFeedCatalogFilterProvider =
    StateProvider.family<String, String>((ref, chromeKey) => 'all');

/// Pack horizon menu token — per hub. Empty until pack default / user pick.
final kitFeedHorizonPrefProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');

/// Pack View menu (`list` / `cards`) — per hub. Empty = use `kit.list.style`.
final kitListStyleOverrideProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');
