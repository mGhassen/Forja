import 'package:shared_preferences/shared_preferences.dart';

/// Device-local prefs for pack-declared Addon settings fields (RFC-089).
///
/// Key: `pack_setting_v1_<pluginId>_<fieldId>`.
abstract final class PackSettingsStore {
  PackSettingsStore._();

  static const _prefix = 'pack_setting_v1_';

  static String key(String pluginId, String fieldId) {
    final p = pluginId.trim();
    final f = fieldId.trim();
    return '$_prefix${p}_$f';
  }

  static Future<bool> getBool(
    String pluginId,
    String fieldId, {
    required bool defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final k = key(pluginId, fieldId);
    if (!prefs.containsKey(k)) return defaultValue;
    return prefs.getBool(k) ?? defaultValue;
  }

  static Future<void> setBool(
    String pluginId,
    String fieldId,
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(pluginId, fieldId), value);
  }

  static Future<String> getString(
    String pluginId,
    String fieldId, {
    required String defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final k = key(pluginId, fieldId);
    if (!prefs.containsKey(k)) return defaultValue;
    return prefs.getString(k) ?? defaultValue;
  }

  static Future<void> setString(
    String pluginId,
    String fieldId,
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key(pluginId, fieldId), value);
  }

  /// True when the pack setting key already exists (no default fallback needed).
  static Future<bool> has(String pluginId, String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key(pluginId, fieldId));
  }

  /// One-shot: copy [legacyValue] into the pack key when unset.
  static Future<bool> migrateBoolIfAbsent(
    String pluginId,
    String fieldId,
    bool legacyValue,
  ) async {
    if (await has(pluginId, fieldId)) return false;
    await setBool(pluginId, fieldId, legacyValue);
    return true;
  }
}
