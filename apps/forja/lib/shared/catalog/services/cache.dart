import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// In-memory catalog response cache.
///
/// Process-lifetime only — hub rails are cheap to refetch and stale posters are
/// worse than a spinner after a cold start. [syncPackVersion] drops everything
/// when the hubs pack changes so a plugin update never serves old shapes.
class CatalogCache {
  CatalogCache._();
  static final CatalogCache instance = CatalogCache._();

  final Map<String, CatalogCacheEntry> _entries = {};
  final Map<String, String> _hubPackVersions = {};

  /// `pluginId|action|paramsHash|authSubject`
  static String keyFor({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    String? authSubject,
  }) =>
      '$pluginId|$action|${paramsHash(params)}|${authSubject ?? ''}';

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

  CatalogCacheEntry? get(String key) => _entries[key];

  void put({
    required String key,
    required String pluginId,
    required Map<String, dynamic> data,
    CatalogCacheHints hints = CatalogCacheHints.empty,
  }) {
    _entries[key] = CatalogCacheEntry(
      pluginId: pluginId,
      data: data,
      etag: hints.etag,
      storedAt: DateTime.now(),
      maxAge: hints.maxAge ?? defaultMaxAge,
      swr: hints.swr ?? defaultSwr,
    );
  }

  /// Extend freshness after a `notModified` answer.
  void touch(String key) {
    final e = _entries[key];
    if (e == null) return;
    _entries[key] = e.copyWithStoredAt(DateTime.now());
  }

  void wipePlugin(String pluginId) {
    _entries.removeWhere((_, e) => e.pluginId == pluginId);
  }

  void wipeAll() => _entries.clear();

  /// Drop everything when a hub pack version changes.
  void syncHubPackVersion(String packId, String version) {
    final v = version.trim();
    final id = packId.trim();
    if (v.isEmpty || id.isEmpty) return;
    final prev = _hubPackVersions[id];
    if (prev != null && prev != v) {
      debugPrint('[catalog] $id $prev → $v — cache wiped');
      wipeAll();
    }
    _hubPackVersions[id] = v;
  }

  /// @Deprecated Prefer [syncHubPackVersion].
  void syncPackVersion(String version) =>
      syncHubPackVersion('forjahq-hubs', version);

  static const defaultMaxAge = Duration(minutes: 5);
  static const defaultSwr = Duration(minutes: 30);

  @visibleForTesting
  int get length => _entries.length;
}

class CatalogCacheEntry {
  const CatalogCacheEntry({
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

  CatalogCacheEntry copyWithStoredAt(DateTime at) => CatalogCacheEntry(
    pluginId: pluginId,
    data: data,
    storedAt: at,
    maxAge: maxAge,
    swr: swr,
    etag: etag,
  );
}
