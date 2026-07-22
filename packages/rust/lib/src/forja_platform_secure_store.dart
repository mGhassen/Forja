import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform secret I/O shared by [SecureSettings] and the app host.
///
/// macOS policy:
/// - **Sandboxed** (Debug / future signed+sandbox): Data Protection Keychain.
///   Access is by keychain group, not binary CDHash → no login-password dialog
///   on every rebuild/update.
/// - **Non-sandboxed** (ad-hoc Release DMG): SharedPreferences vault. Login
///   Keychain ACLs re-prompt on every ad-hoc re-sign; DP Keychain returns
///   `-34018` without sandbox. Prefs avoid both.
///
/// Never writes the legacy login Keychain (`useDataProtectionKeyChain: false`).
/// Reads may one-shot migrate leftovers out of that store (one Allow dialog).
abstract final class ForjaPlatformSecureStore {
  static const _prefsPrefix = 'forja_secure_';

  static const FlutterSecureStorage _dp = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: true),
  );

  /// Previous Forja macOS default — login Keychain. Read-only for migration.
  static const FlutterSecureStorage _legacyLogin = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  static bool get _isMacOS => !kIsWeb && Platform.isMacOS;

  /// Sandboxed macOS sets this; ad-hoc Release does not.
  static bool get usesDataProtectionKeychain {
    if (!_isMacOS) return true;
    return Platform.environment.containsKey('APP_SANDBOX_CONTAINER_ID');
  }

  static String prefsKey(String key) => '$_prefsPrefix$key';

  static Future<String?> read(String key) async {
    if (_isMacOS && !usesDataProtectionKeychain) {
      final vault = await _readPrefsVault(key);
      if (vault != null) return vault;
      return _migrateFromLegacyLogin(key);
    }

    try {
      final v = await _dp.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } on MissingPluginException {
      return _readPrefsVault(key);
    } catch (e) {
      debugPrint('[ForjaPlatformSecureStore] DP read failed ($key): $e');
    }

    final migrated = await _migrateFromLegacyLogin(key);
    if (migrated != null) return migrated;

    return _readPrefsVault(key);
  }

  static Future<void> write(String key, String value) async {
    if (_isMacOS && !usesDataProtectionKeychain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey(key), value);
      await prefs.remove(key);
      return;
    }

    try {
      await _dp.write(key: key, value: value);
    } on MissingPluginException {
      debugPrint(
        '[ForjaPlatformSecureStore] write skipped — no secure plugin ($key)',
      );
      rethrow;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey(key));
      await prefs.remove(key);
    } catch (_) {}
  }

  static Future<void> delete(String key) async {
    if (_isMacOS && !usesDataProtectionKeychain) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(prefsKey(key));
        await prefs.remove(key);
      } catch (_) {}
      return;
    }

    try {
      await _dp.delete(key: key);
    } on MissingPluginException {
      // ignore
    } catch (e) {
      debugPrint('[ForjaPlatformSecureStore] DP delete failed ($key): $e');
      rethrow;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey(key));
      await prefs.remove(key);
    } catch (_) {}
  }

  static Future<String?> _readPrefsVault(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vault = prefs.getString(prefsKey(key));
      if (vault != null && vault.isNotEmpty) return vault;
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    } catch (_) {}
    return null;
  }

  /// Pull a value out of the login Keychain into the current primary store.
  /// May show one Keychain Allow dialog; afterward primary hits and login is unused.
  static Future<String?> _migrateFromLegacyLogin(String key) async {
    if (!_isMacOS) return null;
    try {
      final legacy = await _legacyLogin.read(key: key);
      if (legacy == null || legacy.isEmpty) return null;
      await write(key, legacy);
      return legacy;
    } catch (e) {
      debugPrint(
        '[ForjaPlatformSecureStore] login Keychain migrate skipped ($key): $e',
      );
      return null;
    }
  }
}
