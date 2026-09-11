import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/models/models.dart';

import 'package:forja/shared/foundation/protocol/protocol.dart';

/// In-memory catalog response cache.
///
/// Process-lifetime only — hub rails are cheap to refetch and stale posters are
/// worse than a spinner after a cold start. [syncPackVersion] drops everything
/// when the hubs pack changes so a plugin update never serves old shapes.
class MetaCache {
  MetaCache._();
  static final MetaCache instance = MetaCache._();

  final Map<String, MetaCacheEntry> _entries = {};
  final Map<String, String> _hubPackVersions = {};

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

  MetaCacheEntry? get(String key) => _entries[key];

  void put({
    required String key,
    required String pluginId,
    required Map<String, dynamic> data,
    MetaCacheHints hints = MetaCacheHints.empty,
  }) {
    _entries[key] = MetaCacheEntry(
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
  void syncPackVersion(String packId, String version) {
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

  /// @Deprecated Prefer [syncPackVersion].
  void syncLegacyHubsPackVersion(String version) =>
      syncPackVersion('forjahq-hubs', version);

  static const defaultMaxAge = Duration(minutes: 5);
  static const defaultSwr = Duration(minutes: 30);

  @visibleForTesting
  int get length => _entries.length;
}

class MetaCacheEntry {
  const MetaCacheEntry({
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

  MetaCacheEntry copyWithStoredAt(DateTime at) => MetaCacheEntry(
    pluginId: pluginId,
    data: data,
    storedAt: at,
    maxAge: maxAge,
    swr: swr,
    etag: etag,
  );
}
