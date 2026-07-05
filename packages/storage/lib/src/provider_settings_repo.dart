import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rust/rust.dart';

class ProviderSettingsRepo {
  static const _orderKey = 'forja_provider_order';
  static const _enabledKey = 'forja_enabled_providers';
  static const _lastUsedKey = 'forja_last_provider';

  static const defaultOrder = [
    'videasy',
    'vidsrc',
    'vidnest',
    'vidlink',
    'vixsrc',
    'vidzee',
    'vidrock',
    'service111477',
  ];

  static const defaultEnabled = defaultOrder;

  /// One-time import from legacy SharedPreferences after [ForjaEngine.init].
  static Future<void> migrateLegacyPrefsIfNeeded() async {
    if (!ForjaRust.isInitialized) return;
    if (ForjaRust.instance.storageGetJson(_orderKey) != 'null') return;

    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList(_orderKey);
    if (order != null) {
      _setJson(_orderKey, order);
    }
    final enabled = prefs.getStringList(_enabledKey);
    if (enabled != null) {
      _setJson(_enabledKey, enabled);
    }
    final last = prefs.getString(_lastUsedKey);
    if (last != null) {
      _setJson(_lastUsedKey, last);
    }
  }

  Future<List<String>> getOrder() async {
    return _stringList(_orderKey, defaultOrder);
  }

  Future<void> setOrder(List<String> order) async {
    _setJson(_orderKey, order);
  }

  Future<List<String>> getEnabled() async {
    return _stringList(_enabledKey, defaultEnabled);
  }

  Future<void> setEnabled(List<String> ids) async {
    _setJson(_enabledKey, ids);
  }

  Future<String?> getLastUsed() async {
    final raw = ForjaRust.instance.storageGetJson(_lastUsedKey);
    if (raw == 'null') return null;
    final decoded = jsonDecode(raw);
    return decoded is String ? decoded : null;
  }

  Future<void> setLastUsed(String id) async {
    _setJson(_lastUsedKey, id);
  }

  static List<String> _stringList(String key, List<String> fallback) {
    _requireStorage();
    final raw = ForjaRust.instance.storageGetJson(key);
    if (raw == 'null') return List.from(fallback);
    final decoded = jsonDecode(raw);
    if (decoded is! List) return List.from(fallback);
    return decoded.map((e) => '$e').toList();
  }

  static void _setJson(String key, Object value) {
    _requireStorage();
    final resp = jsonDecode(
      ForjaRust.instance.storageSetJson(key, jsonEncode(value)),
    ) as Map<String, dynamic>;
    if (resp.containsKey('error')) {
      throw StateError('storage_set failed: ${resp['error']}');
    }
  }

  static void _requireStorage() {
    if (!ForjaRust.isInitialized) {
      throw StateError('Rust engine storage not loaded — call ForjaEngine.init()');
    }
  }
}
