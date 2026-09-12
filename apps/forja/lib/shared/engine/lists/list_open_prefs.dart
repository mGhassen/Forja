import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Default details hub plugin id per engine type token (`movie`, `tv`, …).
abstract final class ListOpenPrefs {
  ListOpenPrefs._();

  static const _key = 'list_open_default_hubs_v1';

  static Future<Map<String, String>> _readMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key.toString().trim().isNotEmpty &&
              e.value.toString().trim().isNotEmpty)
            e.key.toString().trim(): e.value.toString().trim(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(map));
  }

  static Future<String?> defaultPluginId(String engineType) async {
    final want = engineType.trim();
    if (want.isEmpty) return null;
    final map = await _readMap();
    final v = map[want]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> setDefaultPluginId(
    String engineType,
    String? pluginId,
  ) async {
    final want = engineType.trim();
    if (want.isEmpty) return;
    final map = await _readMap();
    final id = pluginId?.trim() ?? '';
    if (id.isEmpty) {
      map.remove(want);
    } else {
      map[want] = id;
    }
    await _writeMap(map);
  }

  static Future<Map<String, String>> allDefaults() => _readMap();
}
