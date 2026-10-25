import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local prefs for pack-declared Addon settings fields (RFC-089).
///
/// Key: `pack_setting_v1_<pluginId>_<fieldId>`.
/// Secrets (RFC-101): `pack_secret_v1_<pluginId>_<fieldId>` via [SecureSettings].
/// Non-secret cloud sync is scheduled via [onNonSecretUserWrite] (issue 307).
abstract final class PackSettingsStore {
  PackSettingsStore._();

  /// Bumped on every write so open-mode gates / UI can rebuild (RFC-104).
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Hook for cloud `packSettings` push — wired from sync bootstrap.
  static void Function()? onNonSecretUserWrite;

  /// Bump prefs revision and optionally invalidate that plugin’s hub mount.
  /// Settings UI must not remount — hubs listen via [PluginRegistry.hubFeedEpoch].
  /// Hub soft-reload keeps live feed cache (forceNetwork: false) — pack wipe /
  /// Reload packs still pass forceNetwork: true (issue 314).
  static void _bump(String pluginId, {bool reloadHub = true}) {
    revision.value++;
    if (!reloadHub) return;
    final id = pluginId.trim();
    if (id.isEmpty) return;
    PluginRegistry.bumpHubFeedEpoch(pluginIds: [id], forceNetwork: false);
  }

  /// User-facing non-secret write: bump + optional cloud push hook.
  static void _bumpUser(String pluginId, {bool reloadHub = true}) {
    _bump(pluginId, reloadHub: reloadHub);
    onNonSecretUserWrite?.call();
  }

  static const _prefix = 'pack_setting_v1_';
  static const _secretPrefix = 'pack_secret_v1_';
  static bool _scopeListenerArmed = false;

  static void _ensureScopeListener() {
    if (_scopeListenerArmed) return;
    _scopeListenerArmed = true;
    LocalDataScope.addListener(() async {
      revision.value++;
    });
  }

  /// Bare base (pre-scope) — used for lazy migrate + export labels.
  static String bareKey(String pluginId, String fieldId) {
    final p = pluginId.trim();
    final f = fieldId.trim();
    return '$_prefix${p}_$f';
  }

  static String bareSecretKey(String pluginId, String fieldId) {
    final p = pluginId.trim();
    final f = fieldId.trim();
    return '$_secretPrefix${p}_$f';
  }

  static String key(String pluginId, String fieldId) {
    _ensureScopeListener();
    return LocalDataScope.storageKey(bareKey(pluginId, fieldId));
  }

  static String secretKey(String pluginId, String fieldId) {
    _ensureScopeListener();
    return LocalDataScope.storageKey(bareSecretKey(pluginId, fieldId));
  }

  static Future<void> _migratePrefBareIfNeeded(
    SharedPreferences prefs,
    String bare,
  ) async {
    if (LocalDataScope.isGuest) return;
    final scoped = LocalDataScope.storageKey(bare);
    if (prefs.containsKey(scoped) || !prefs.containsKey(bare)) return;
    final value = prefs.get(bare);
    if (value is String) {
      await prefs.setString(scoped, value);
    } else if (value is bool) {
      await prefs.setBool(scoped, value);
    } else if (value is int) {
      await prefs.setInt(scoped, value);
    } else if (value is double) {
      await prefs.setDouble(scoped, value);
    } else if (value is List) {
      await prefs.setStringList(
        scoped,
        value.map((e) => e?.toString() ?? '').toList(),
      );
    }
    await prefs.remove(bare);
  }

  static Future<bool> getBool(
    String pluginId,
    String fieldId, {
    required bool defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bare = bareKey(pluginId, fieldId);
    await _migratePrefBareIfNeeded(prefs, bare);
    final k = LocalDataScope.storageKey(bare);
    if (!prefs.containsKey(k)) return defaultValue;
    return prefs.getBool(k) ?? defaultValue;
  }

  static Future<void> setBool(
    String pluginId,
    String fieldId,
    bool value, {
    bool reloadHub = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(pluginId, fieldId), value);
    if (reloadHub) {
      _bumpUser(pluginId, reloadHub: true);
    } else {
      // Paint-only fields (e.g. matchOpen) still sync — just skip hub scrape.
      _bump(pluginId, reloadHub: false);
      onNonSecretUserWrite?.call();
    }
  }

  static Future<String> getString(
    String pluginId,
    String fieldId, {
    required String defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bare = bareKey(pluginId, fieldId);
    await _migratePrefBareIfNeeded(prefs, bare);
    final k = LocalDataScope.storageKey(bare);
    if (!prefs.containsKey(k)) return defaultValue;
    return prefs.getString(k) ?? defaultValue;
  }

  static Future<void> setString(
    String pluginId,
    String fieldId,
    String value, {
    bool reloadHub = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key(pluginId, fieldId), value);
    if (reloadHub) {
      _bumpUser(pluginId, reloadHub: true);
    } else {
      // Paint-only fields (e.g. matchOpen) still sync — just skip hub scrape.
      _bump(pluginId, reloadHub: false);
      onNonSecretUserWrite?.call();
    }
  }

  static Future<String> getSecret(
    String pluginId,
    String fieldId, {
    String defaultValue = '',
  }) async {
    final bare = bareSecretKey(pluginId, fieldId);
    await LocalDataScope.migrateSecureBareIfNeeded(
      bare,
      read: SecureSettings.read,
      write: SecureSettings.write,
      delete: SecureSettings.delete,
    );
    final raw = await SecureSettings.read(LocalDataScope.storageKey(bare));
    if (raw == null || raw.isEmpty) return defaultValue;
    return raw;
  }

  static Future<void> setSecret(
    String pluginId,
    String fieldId,
    String value, {
    bool reloadHub = true,
  }) async {
    final k = secretKey(pluginId, fieldId);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await SecureSettings.delete(k);
      _bump(pluginId, reloadHub: reloadHub);
      return;
    }
    await SecureSettings.write(k, trimmed);
    _bump(pluginId, reloadHub: reloadHub);
  }

  static Future<List<String>> getStringList(
    String pluginId,
    String fieldId, {
    required List<String> defaultValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bare = bareKey(pluginId, fieldId);
    await _migratePrefBareIfNeeded(prefs, bare);
    final k = LocalDataScope.storageKey(bare);
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
    List<String> value, {
    bool reloadHub = true,
  }) async {
    await setString(pluginId, fieldId, value.join(','), reloadHub: reloadHub);
  }

  /// True when the pack setting key already exists (no default fallback needed).
  static Future<bool> has(String pluginId, String fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final bare = bareKey(pluginId, fieldId);
    await _migratePrefBareIfNeeded(prefs, bare);
    return prefs.containsKey(LocalDataScope.storageKey(bare));
  }

  /// One-shot: copy [legacyValue] into the pack key when unset.
  static Future<bool> migrateBoolIfAbsent(
    String pluginId,
    String fieldId,
    bool legacyValue,
  ) async {
    if (await has(pluginId, fieldId)) return false;
    await setBool(pluginId, fieldId, legacyValue, reloadHub: false);
    return true;
  }

  /// One-shot: copy [legacyValue] into the pack key when unset.
  static Future<bool> migrateStringIfAbsent(
    String pluginId,
    String fieldId,
    String legacyValue,
  ) async {
    if (await has(pluginId, fieldId)) return false;
    await setString(pluginId, fieldId, legacyValue, reloadHub: false);
    return true;
  }

  static Future<bool> migrateStringListIfAbsent(
    String pluginId,
    String fieldId,
    List<String> legacyValue,
  ) async {
    if (await has(pluginId, fieldId)) return false;
    await setStringList(pluginId, fieldId, legacyValue, reloadHub: false);
    return true;
  }

  /// Merge all declared settings (+ secrets) for [pluginId] into a config map.
  static Future<Map<String, dynamic>> configOverlayForPlugin({
    required String pluginId,
    required List<
      ({
        String id,
        String type,
        String defaultString,
        bool defaultBool,
        List<String> defaultStringList,
      })
    >
    fields,
  }) async {
    final out = <String, dynamic>{};
    for (final field in fields) {
      final type = field.type;
      if (type == 'toggle') {
        out[field.id] = await getBool(
          pluginId,
          field.id,
          defaultValue: field.defaultBool,
        );
      } else if (type == 'password' || type == 'secret') {
        final v = await getSecret(pluginId, field.id);
        if (v.isNotEmpty) out[field.id] = v;
      } else if (type == 'multi_select' ||
          type == 'multiselect' ||
          type == 'chips') {
        out[field.id] = await getStringList(
          pluginId,
          field.id,
          defaultValue: field.defaultStringList,
        );
      } else {
        // text / select
        out[field.id] = await getString(
          pluginId,
          field.id,
          defaultValue: field.defaultString,
        );
      }
    }
    return out;
  }
}
