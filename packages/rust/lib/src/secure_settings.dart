import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'forja_platform_secure_store.dart';
import 'kv.dart';

/// Platform Keychain/Keystore for credentials.
///
/// Non-secret configuration belongs in Rust KV (`forja_engine_store.json`).
/// Never write secrets into that file. On macOS the user chooses Keychain vs
/// local file storage once ([ForjaPlatformSecureStore]); declined / ad-hoc
/// non-sandbox builds use a prefs vault (no login-Keychain password dialog).
/// MissingPluginException (unit tests) is soft-skipped on reads.
abstract final class SecureSettings {
  /// Debrid
  static const rdAccessToken = 'rd_access_token';
  static const rdRefreshToken = 'rd_refresh_token';
  static const rdTokenExpiry = 'rd_token_expiry';
  static const rdClientId = 'rd_client_id';
  static const rdClientSecret = 'rd_client_secret';
  static const torboxApiKey = 'torbox_api_key';
  static const alldebridApiKey = 'alldebrid_api_key';
  static const premiumizeApiKey = 'premiumize_api_key';
  static const debridlinkApiKey = 'debridlink_api_key';

  /// Indexers (API keys only — URLs stay in KV)
  static const jackettApiKey = 'jackett_api_key';
  static const prowlarrApiKey = 'prowlarr_api_key';

  /// Retired WebStreamr secrets — purged on upgrade; kept out of KV exports.
  static const retiredSecureKeys = <String>{
    'webstreamr_mfp_password',
    'webstreamr_tmdb_token',
  };

  /// IPTV Xtream portal passwords (JSON map `url|username` → password).
  static const iptvPortalPasswords = 'iptv_portal_passwords_v1';

  /// Keys that must never appear as plaintext in forja_engine_store.json.
  static const forbiddenCanonicalKeys = <String>{
    rdAccessToken,
    rdRefreshToken,
    rdTokenExpiry,
    rdClientId,
    rdClientSecret,
    torboxApiKey,
    alldebridApiKey,
    premiumizeApiKey,
    debridlinkApiKey,
    jackettApiKey,
    prowlarrApiKey,
    ...retiredSecureKeys,
    iptvPortalPasswords,
  };

  static Future<String?> read(String key) => ForjaPlatformSecureStore.read(key);

  static Future<void> write(String key, String value) =>
      ForjaPlatformSecureStore.write(key, value);

  static Future<void> delete(String key) => ForjaPlatformSecureStore.delete(key);

  /// Copy [key] from SharedPreferences → secure storage, then remove prefs.
  ///
  /// Returns `false` when a secret still sits in prefs and the platform write
  /// failed. Callers should retry later and must not crash the UI.
  static Future<bool> migrateFromPrefs(String key) async {
    try {
      String? existing;
      try {
        existing = await ForjaPlatformSecureStore.read(key);
      } catch (e) {
        debugPrint('[SecureSettings] migrateFromPrefs failed ($key): $e');
        return false;
      }
      // [read] already surfaces prefs vault / legacy prefs. If we got a value
      // from Keychain, drop plaintext leftovers; if only prefs remain, write
      // through the platform store (no-op for non-sandbox prefs vault).
      if (existing != null && existing.isNotEmpty) {
        // Re-write so non-sandbox vault keys get the `forja_secure_` prefix and
        // sandboxed builds land in DP Keychain, then strip unprefixed prefs.
        await ForjaPlatformSecureStore.write(key, existing);
        return true;
      }
      return true;
    } on MissingPluginException {
      return true;
    } catch (e) {
      debugPrint('[SecureSettings] migrateFromPrefs failed ($key): $e');
      return false;
    }
  }

  /// Copy [key] from Rust KV → secure storage, then clear the KV value.
  ///
  /// Returns `false` when a secret still sits in KV and Keychain write failed.
  static Future<bool> migrateFromKv(String key) async {
    try {
      String? existing;
      try {
        existing = await ForjaPlatformSecureStore.read(key);
      } catch (e) {
        final legacy = await kvGetString(key);
        if (legacy == null || legacy.isEmpty) return true;
        debugPrint('[SecureSettings] migrateFromKv failed ($key): $e');
        return false;
      }
      if (existing != null && existing.isNotEmpty) {
        await kvSetString(key, '');
        return true;
      }
      final legacy = await kvGetString(key);
      if (legacy == null || legacy.isEmpty) return true;
      await ForjaPlatformSecureStore.write(key, legacy);
      await kvSetString(key, '');
      return true;
    } on MissingPluginException {
      return true;
    } catch (e) {
      debugPrint('[SecureSettings] migrateFromKv failed ($key): $e');
      return false;
    }
  }
}
