import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LRU cap for IPTV catalog shelves (Live / Movies / Series combined).
abstract final class IptvCatalogShelfCache {
  static const maxShelves = 10;
  static const _lruPrefsKeyBase = 'pt_iptv_catalog_lru_v1';
  static String get _lruPrefsKey =>
      LocalDataScope.storageKey(_lruPrefsKeyBase);

  static String shelfKey(String portalKey, IptvSection section) =>
      '$portalKey|${section.name}';

  static ({String portalKey, IptvSection section})? parseShelfKey(
    String shelfKey,
  ) {
    for (final section in IptvSection.values) {
      final suffix = '|${section.name}';
      if (shelfKey.endsWith(suffix)) {
        return (
          portalKey: shelfKey.substring(0, shelfKey.length - suffix.length),
          section: section,
        );
      }
    }
    return null;
  }

  static Future<List<String>> _loadLru() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_lruPrefsKey) ?? const []);
  }

  static Future<void> _saveLru(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    if (order.isEmpty) {
      await prefs.remove(_lruPrefsKey);
      return;
    }
    await prefs.setStringList(_lruPrefsKey, order);
  }

  /// Mark [shelfKey] most-recent; evict oldest shelves until at most [maxShelves].
  /// [protect] is never chosen as the eviction victim.
  static Future<List<String>> touch(
    String shelfKey, {
    String? protect,
  }) async {
    if (shelfKey.isEmpty) return const [];
    final pin = protect ?? shelfKey;
    var order = await _loadLru();
    order.remove(shelfKey);
    order.add(shelfKey);
    final evicted = <String>[];
    while (order.length > maxShelves) {
      final victim = order.firstWhere(
        (k) => k != pin,
        orElse: () => order.first,
      );
      order.remove(victim);
      evicted.add(victim);
    }
    await _saveLru(order);
    return evicted;
  }

  static Future<void> remove(String shelfKey) async {
    if (shelfKey.isEmpty) return;
    final order = await _loadLru();
    if (order.remove(shelfKey)) {
      await _saveLru(order);
    }
  }

  static Future<void> removePortal(String portalKey) async {
    if (portalKey.isEmpty) return;
    final prefix = '$portalKey|';
    final order = await _loadLru();
    final next = order.where((k) => !k.startsWith(prefix)).toList();
    if (next.length != order.length) {
      await _saveLru(next);
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lruPrefsKey);
  }

  static Future<void> deleteShelfData(String shelfKey) async {
    final parsed = parseShelfKey(shelfKey);
    if (parsed == null) return;
    await IptvCatalogDiskStore.deleteShelf(parsed.portalKey, parsed.section);
  }

  static Future<void> reconcileOnLaunch() async {
    var order = await _loadLru();
    final evicted = <String>[];
    while (order.length > maxShelves) {
      evicted.add(order.removeAt(0));
    }
    if (evicted.isNotEmpty) {
      await _saveLru(order);
      for (final key in evicted) {
        await deleteShelfData(key);
      }
    } else if (order.isEmpty) {
      await IptvCatalogDiskStore.trimToMaxFiles(maxShelves);
    }
  }
}
