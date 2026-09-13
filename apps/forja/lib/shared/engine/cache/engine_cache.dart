import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Generic namespaced cache + catalog response entries (RFC-109).
///
/// Replaces former `MetaCache`. Catalog helpers use a separate entry map with
/// SWR semantics; [get]/[set]/[invalidate] are opaque namespace/key slots.
class EngineCache {
  EngineCache._();
  static final EngineCache instance = EngineCache._();

  final Map<String, _EngineCacheSlot> _slots = {};
  final Map<String, EngineCacheEntry> _catalog = {};
  final Map<String, String> _packVersions = {};

  static String _slot(String namespace, String key) =>
      '${namespace.trim()}|${key.trim()}';

  /// Returns stored value, or null if missing / past [ttl].
  Object? get(String namespace, String key) {
    final slot = _slot(namespace, key);
    final e = _slots[slot];
    if (e == null) return null;
    if (e.isExpired) {
      _slots.remove(slot);
      return null;
    }
    return e.value;
  }

  void set(
    String namespace,
    String key,
    Object value, {
    Duration? ttl,
  }) {
    final ns = namespace.trim();
    final k = key.trim();
    if (ns.isEmpty || k.isEmpty) return;
    _slots[_slot(ns, k)] = _EngineCacheSlot(
      value: value,
      storedAt: DateTime.now(),
      ttl: ttl,
    );
  }

  /// Drop one key, or the whole [namespace] when [key] is null/empty.
  void invalidate(String namespace, [String? key]) {
    final ns = namespace.trim();
    if (ns.isEmpty) return;
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      final prefix = '$ns|';
      _slots.removeWhere((slot, _) => slot.startsWith(prefix));
      return;
    }
    _slots.remove(_slot(ns, k));
  }

  void wipeAll() {
    _slots.clear();
    _catalog.clear();
  }

  // --- Catalog response cache (was MetaCache) ---

  /// `pluginId|packHash|action|paramsHash|authSubject`
  static String keyFor({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    String? authSubject,
    String? packSourceUrl,
  }) {
    final pack =
        (packSourceUrl == null || packSourceUrl.trim().isEmpty)
            ? ''
            : EnginePack.urlHash(packSourceUrl);
    return '$pluginId|$pack|$action|${paramsHash(params)}|${authSubject ?? ''}';
  }

  /// Stable short hash of [params] — key order must not change the key.
  static String paramsHash(Map<String, dynamic> params) {
    if (params.isEmpty) return '0';
    final canonical = jsonEncode(_canonical(params));
    return md5.convert(utf8.encode(canonical)).toString().substring(0, 12);
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(value[k])};
    }
    if (value is List) return [for (final e in value) _canonical(e)];
    return value;
  }

  EngineCacheEntry? getEntry(String key) => _catalog[key];

  void putEntry({
    required String key,
    required String pluginId,
    required Map<String, dynamic> data,
    MetaCacheHints hints = MetaCacheHints.empty,
  }) {
    _catalog[key] = EngineCacheEntry(
      pluginId: pluginId,
      data: data,
      etag: hints.etag,
      storedAt: DateTime.now(),
      maxAge: hints.maxAge ?? defaultMaxAge,
      swr: hints.swr ?? defaultSwr,
    );
  }

  /// Extend freshness after a `notModified` answer.
  void touchEntry(String key) {
    final e = _catalog[key];
    if (e == null) return;
    _catalog[key] = e.copyWithStoredAt(DateTime.now());
  }

  void wipePlugin(String pluginId) {
    _catalog.removeWhere((_, e) => e.pluginId == pluginId);
  }

  /// Drop catalog entries for one action (`feed`, `rail`, …).
  /// Key shape: `pluginId|pack|action|paramsHash|authSubject`.
  void wipeAction(String action) {
    final want = action.trim();
    if (want.isEmpty) return;
    _catalog.removeWhere((key, _) {
      final parts = key.split('|');
      return parts.length >= 3 && parts[2] == want;
    });
  }

  void wipeCatalog() => _catalog.clear();

  /// Drop catalog when a pack version changes.
  /// Returns true when entries were wiped.
  bool syncPackVersion(String packId, String version) {
    final v = version.trim();
    final id = packId.trim();
    if (v.isEmpty || id.isEmpty) return false;
    final prev = _packVersions[id];
    var wiped = false;
    if (prev != null && prev != v) {
      debugPrint('[catalog] $id $prev → $v — cache wiped');
      wipeCatalog();
      wiped = true;
    }
    _packVersions[id] = v;
    return wiped;
  }

  static const defaultMaxAge = Duration(minutes: 5);
  static const defaultSwr = Duration(minutes: 30);

  @visibleForTesting
  int get length => _slots.length + _catalog.length;

  @visibleForTesting
  int get catalogLength => _catalog.length;
}

class EngineCacheEntry {
  const EngineCacheEntry({
    required this.pluginId,
    required this.data,
    required this.storedAt,
    required this.maxAge,
    required this.swr,
    this.etag,
  });

  final String pluginId;
  final Map<String, dynamic> data;
  final DateTime storedAt;
  final Duration maxAge;
  final Duration swr;
  final String? etag;

  Duration get age => DateTime.now().difference(storedAt);

  bool get isFresh => age <= maxAge;

  /// Past [maxAge] but still inside the stale-while-revalidate window.
  bool get isRevalidatable => !isFresh && age <= maxAge + swr;

  bool get isExpired => age > maxAge + swr;

  EngineCacheEntry copyWithStoredAt(DateTime at) => EngineCacheEntry(
        pluginId: pluginId,
        data: data,
        storedAt: at,
        maxAge: maxAge,
        swr: swr,
        etag: etag,
      );
}

class _EngineCacheSlot {
  _EngineCacheSlot({
    required this.value,
    required this.storedAt,
    this.ttl,
  });

  final Object value;
  final DateTime storedAt;
  final Duration? ttl;

  bool get isExpired {
    final t = ttl;
    if (t == null) return false;
    return DateTime.now().difference(storedAt) > t;
  }
}
