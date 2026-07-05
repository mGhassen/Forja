import 'dart:convert';

import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rust engine key-value store (`crates/storage` via FFI).
abstract final class EngineStorage {
  static bool get isReady => ForjaRust.isInitialized;

  static bool hasKey(String key) {
    _requireReady();
    return ForjaRust.instance.storageGetJson(key) != 'null';
  }

  static dynamic read(String key) {
    _requireReady();
    final raw = ForjaRust.instance.storageGetJson(key);
    if (raw == 'null') return null;
    return jsonDecode(raw);
  }

  static void write(String key, Object value) {
    _requireReady();
    final resp = jsonDecode(
      ForjaRust.instance.storageSetJson(key, jsonEncode(value)),
    ) as Map<String, dynamic>;
    if (resp.containsKey('error')) {
      throw StateError('storage_set failed: ${resp['error']}');
    }
  }

  static bool readBool(String key, {required bool fallback}) {
    final v = read(key);
    return v is bool ? v : fallback;
  }

  static void writeBool(String key, bool value) => write(key, value);

  static String readString(String key, {required String fallback}) {
    final v = read(key);
    return v is String ? v : fallback;
  }

  static void writeString(String key, String value) => write(key, value);

  static List<String> readStringList(
    String key, {
    required List<String> fallback,
  }) {
    final v = read(key);
    if (v is! List) return List.from(fallback);
    return v.map((e) => '$e').toList();
  }

  static void writeStringList(String key, List<String> values) =>
      write(key, values);

  static List<Map<String, dynamic>> readMapList(String key) {
    final v = read(key);
    if (v is! List) return [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static void writeMapList(String key, List<Map<String, dynamic>> values) =>
      write(key, values);

  /// One-time import from legacy SharedPreferences after [ForjaEngine.init].
  static Future<void> migrateLegacyPrefsIfNeeded() async {
    if (!isReady) return;
    if (hasKey('forja_provider_order')) return;

    final prefs = await SharedPreferences.getInstance();

    void migrateStringList(String key) {
      final list = prefs.getStringList(key);
      if (list != null) writeStringList(key, list);
    }

    void migrateString(String key) {
      final s = prefs.getString(key);
      if (s != null) writeString(key, s);
    }

    void migrateBool(String key) {
      if (prefs.containsKey(key)) {
        writeBool(key, prefs.getBool(key) ?? false);
      }
    }

    migrateStringList('forja_provider_order');
    migrateStringList('forja_enabled_providers');
    migrateString('forja_last_provider');

    migrateStringList('stream_provider_order');

    final stremio = prefs.getStringList('stremio_addons');
    if (stremio != null && stremio.isNotEmpty) {
      writeMapList(
        'stremio_addons',
        stremio.map((s) => jsonDecode(s) as Map<String, dynamic>).toList(),
      );
    }

    migrateBool('forja_auto_next');
    migrateString('forja_external_player');

    final iptvGroups = prefs.getString('forja_iptv_groups');
    if (iptvGroups != null) writeString('forja_iptv_groups', iptvGroups);

    final iptvMeta = prefs.getString('forja_iptv_portal_meta');
    if (iptvMeta != null) writeString('forja_iptv_portal_meta', iptvMeta);
  }

  static void _requireReady() {
    if (!isReady) {
      throw StateError(
        'Rust engine storage not loaded — call ForjaEngine.init()',
      );
    }
  }
}
