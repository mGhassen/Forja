import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/kit/pack_layout_capabilities.dart';
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
      pluginId: PackLayoutCapabilities.instance.pluginIdForTab(tabId),
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

/// Pack View menu — per hub. Empty = use `kit.list.style`.
final kitListStyleOverrideProvider =
    StateProvider.family<String, String>((ref, chromeKey) => '');

const _kListStylePrefPrefix = 'kit.listStyle.';

final Set<String> _listStyleHydrated = {};

String? _normalizeListStyle(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  if (v.isEmpty) return null;
  // Legacy pack tokens → generic timeline style.
  if (v == 'epg' || v == 'guide') return 'timeline';
  // Persist any opaque View cycle token (grid / list / cards / timeline / …).
  if (RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(v)) return v;
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

/// One-shot disk hydrate into [kitListStyleOverrideProvider] (survives restart).
void ensureKitListStyleHydrated(WidgetRef ref, String chromeKey) {
  if (chromeKey.isEmpty || !_listStyleHydrated.add(chromeKey)) return;
  // Capture notifier while [ref] is valid.
  final notifier = ref.read(kitListStyleOverrideProvider(chromeKey).notifier);
  final current = ref.read(kitListStyleOverrideProvider(chromeKey));
  if (_normalizeListStyle(current) != null) return;
  Future<void>(() async {
    final v = await loadKitListStyle(chromeKey);
    if (v.isEmpty) return;
    if (_normalizeListStyle(notifier.state) != null) return;
    notifier.state = v;
  });
}

/// Write memory + disk for View chrome style.
void setKitListStyle(WidgetRef ref, String chromeKey, String style) {
  if (chromeKey.isEmpty) return;
  final v = _normalizeListStyle(style) ?? '';
  ref.read(kitListStyleOverrideProvider(chromeKey).notifier).state = v;
  _listStyleHydrated.add(chromeKey);
  Future<void>(() => saveKitListStyle(chromeKey, v));
}
