import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Pack sort menu token — per hub. Empty until pack default / user pick.
final kitFeedSortPrefProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');

/// Pack View menu (`list` / `cards`) — per hub. Empty = use `kit.list.style`.
final kitListStyleOverrideProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');

const _kListStylePrefPrefix = 'kit.listStyle.';

String? _normalizeListStyle(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  if (v == 'list' || v == 'cards') return v;
  return null;
}

Future<String> loadKitListStyle(String chromeKey) async {
  if (chromeKey.isEmpty) return '';
  final prefs = await SharedPreferences.getInstance();
  return _normalizeListStyle(prefs.getString('$_kListStylePrefPrefix$chromeKey')) ??
      '';
}

Future<void> saveKitListStyle(String chromeKey, String style) async {
  if (chromeKey.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = '$_kListStylePrefPrefix$chromeKey';
  final v = _normalizeListStyle(style);
  if (v == null) {
    await prefs.remove(key);
    return;
  }
  await prefs.setString(key, v);
}

/// Write memory + disk for List/Cards chrome.
void setKitListStyle(
  ProviderContainer container,
  String chromeKey,
  String style,
) {
  if (chromeKey.isEmpty) return;
  final v = _normalizeListStyle(style) ?? '';
  container.read(kitListStyleOverrideProvider(chromeKey).notifier).state = v;
  Future<void>(() => saveKitListStyle(chromeKey, v));
}

/// Apply remembered List/Cards into paint state (memory first, then disk).
Future<void> applyPersistedKitListStyle({
  required ProviderContainer container,
  required String chromeKey,
  required void Function(String style) apply,
}) async {
  if (chromeKey.isEmpty) return;
  final mem = _normalizeListStyle(
    container.read(kitListStyleOverrideProvider(chromeKey)),
  );
  if (mem != null) {
    apply(mem);
    return;
  }
  final v = await loadKitListStyle(chromeKey);
  if (v.isEmpty) return;
  container.read(kitListStyleOverrideProvider(chromeKey).notifier).state = v;
  apply(v);
}
