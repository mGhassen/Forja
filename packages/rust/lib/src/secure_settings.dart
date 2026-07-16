import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kv.dart';

/// Platform Keychain/Keystore for credentials.
///
/// Non-secret configuration belongs in Rust KV (`forja_engine_store.json`).
/// Never write secrets into that file; never fall back to plaintext **writes**
/// when secure storage fails on a real device — report and leave the caller's
/// write incomplete. Reads may still surface legacy SharedPreferences values
/// until migration into Keychain succeeds. MissingPluginException (unit tests)
/// is soft-skipped.
abstract final class SecureSettings {
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

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

  /// WebStreamr secrets
  static const webstreamrMfpPassword = 'webstreamr_mfp_password';
  static const webstreamrTmdbToken = 'webstreamr_tmdb_token';

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
    webstreamrMfpPassword,
    webstreamrTmdbToken,
  };

  static Future<String?> read(String key) async {
    try {
      final v = await _secure.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } on MissingPluginException {
      // Unit tests / no plugin — fall through to prefs legacy.
    } catch (e) {
      debugPrint('[SecureSettings] read failed ($key): $e');
      // Keychain can fail on macOS without keychain-access-groups (-34018).
      // Fall through to prefs so Settings can still load unmigrated secrets.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) return legacy;
    } catch (_) {}
    return null;
  }

  static Future<void> write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } on MissingPluginException {
      debugPrint('[SecureSettings] write skipped — no secure plugin ($key)');
      rethrow;
    } catch (e) {
      debugPrint('[SecureSettings] write failed ($key): $e');
      rethrow;
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _secure.delete(key: key);
    } on MissingPluginException {
      return;
    } catch (e) {
      debugPrint('[SecureSettings] delete failed ($key): $e');
      rethrow;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  /// Copy [key] from SharedPreferences → secure storage, then remove prefs.
  ///
  /// Returns `false` when a secret still sits in prefs and Keychain write
  /// failed (e.g. macOS `-34018` missing entitlement). Callers should retry
  /// later and must not crash the UI.
  static Future<bool> migrateFromPrefs(String key) async {
    try {
      String? existing;
      try {
        existing = await _secure.read(key: key);
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        final legacy = prefs.getString(key);
        if (legacy == null || legacy.isEmpty) return true;
        debugPrint('[SecureSettings] migrateFromPrefs failed ($key): $e');
        return false;
      }
      if (existing != null && existing.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
        return true;
      }
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy == null || legacy.isEmpty) return true;
      await _secure.write(key: key, value: legacy);
      await prefs.remove(key);
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
        existing = await _secure.read(key: key);
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
      await _secure.write(key: key, value: legacy);
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
