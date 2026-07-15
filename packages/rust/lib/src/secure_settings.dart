import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kv.dart';

/// Platform Keychain/Keystore for credentials.
///
/// Non-secret configuration belongs in Rust KV (`forja_engine_store.json`).
/// Never write secrets into that file; never fall back to plaintext when
/// secure storage fails on a real device — report and leave the caller's
/// write incomplete. MissingPluginException (unit tests) is soft-skipped.
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
      return await _secure.read(key: key);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[SecureSettings] read failed ($key): $e');
      rethrow;
    }
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
  }

  /// Copy [key] from SharedPreferences → secure storage, then remove prefs.
  static Future<void> migrateFromPrefs(String key) async {
    try {
      final existing = await _secure.read(key: key);
      if (existing != null && existing.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy == null || legacy.isEmpty) return;
      await _secure.write(key: key, value: legacy);
      await prefs.remove(key);
    } on MissingPluginException {
      return;
    } catch (e) {
      debugPrint('[SecureSettings] migrateFromPrefs failed ($key): $e');
      rethrow;
    }
  }

  /// Copy [key] from Rust KV → secure storage, then clear the KV value.
  static Future<void> migrateFromKv(String key) async {
    try {
      final existing = await _secure.read(key: key);
      if (existing != null && existing.isNotEmpty) {
        await kvSetString(key, '');
        return;
      }
      final legacy = await kvGetString(key);
      if (legacy == null || legacy.isEmpty) return;
      await _secure.write(key: key, value: legacy);
      await kvSetString(key, '');
    } on MissingPluginException {
      return;
    } catch (e) {
      debugPrint('[SecureSettings] migrateFromKv failed ($key): $e');
      rethrow;
    }
  }
}
