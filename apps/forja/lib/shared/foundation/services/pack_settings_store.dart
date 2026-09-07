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

  static Future<List<String>> getStringList(
    String pluginId,
    String fieldId, {
    required List<String> defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final k = key(pluginId, fieldId);
    // Absent key → defaults. Present empty string → intentional empty selection.
    if (!prefs.containsKey(k)) return List<String>.from(defaultValue);
    final raw = prefs.getString(k) ?? '';
    if (raw.trim().isEmpty) return const [];
    return [
      for (final p in raw.split(','))
        if (p.trim().isNotEmpty) p.trim(),
    ];
  }

  static Future<void> setStringList(
    String pluginId,
    String fieldId,
    List<String> value,
  ) async {
    await setString(pluginId, fieldId, value.join(','));
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

  static Future<bool> migrateStringListIfAbsent(
    String pluginId,
    String fieldId,
    List<String> legacyValue,
  ) async {
    if (await has(pluginId, fieldId)) return false;
    await setStringList(pluginId, fieldId, legacyValue);
    return true;
  }
}
