import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// macOS Keychain vs local-file choice (persisted).
enum ForjaKeychainConsent {
  /// Default on macOS — prefs vault only; never touch Keychain until the user
  /// opts in (Settings). Same runtime behavior as [declined].
  unset,

  /// User allowed Keychain (DP when sandboxed; may migrate legacy login items).
  accepted,

  /// User declined or never opted in — prefs vault only; never touch Keychain.
  declined,
}

/// Platform secret I/O shared by [SecureSettings] and the app host.
///
/// macOS policy:
/// - **Default:** local prefs vault — no Keychain, no boot prompt.
/// - **Opt-in:** user enables Keychain from Settings (explain dialog first).
/// - **Sandboxed** + accepted: Data Protection Keychain.
/// - **Non-sandboxed** (ad-hoc Release) + accepted: prefs vault for writes;
///   one-shot login-Keychain migrate may show a system Allow dialog.
///
/// **Android / Android TV:** always dual-write EncryptedSharedPreferences + a
/// SharedPreferences vault. Encrypted prefs have been empty after TV emulator
/// restarts; the vault keeps Supabase sessions across cold starts.
///
/// Never writes the legacy login Keychain (`useDataProtectionKeyChain: false`).
/// Reads may one-shot migrate leftovers out of that store after opt-in.
abstract final class ForjaPlatformSecureStore {
  static const _prefsPrefix = 'forja_secure_';
  static const _consentPrefsKey = 'forja_keychain_consent_v1';

  static const FlutterSecureStorage _dp = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: true),
  );

  /// Previous Forja macOS default — login Keychain. Read-only for migration.
  static const FlutterSecureStorage _legacyLogin = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  static ForjaKeychainConsent? _cachedConsent;

  static bool get _isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Sandboxed macOS sets this; ad-hoc Release does not.
  static bool get usesDataProtectionKeychain {
    if (!_isMacOS) return true;
    return Platform.environment.containsKey('APP_SANDBOX_CONTAINER_ID');
  }

  /// True when the user has opted into Keychain.
  static bool get usesKeychain => consent == ForjaKeychainConsent.accepted;

  static ForjaKeychainConsent get consent {
    final c = _cachedConsent ?? ForjaKeychainConsent.unset;
    // Unset behaves as declined (local file) until an explicit opt-in.
    if (c == ForjaKeychainConsent.unset) return ForjaKeychainConsent.declined;
    return c;
  }

  /// Prefer SharedPreferences vault as the durable store.
  static bool get _usePrefsVaultPrimary {
    if (_isAndroid) return true;
    if (!_isMacOS) return false;
    if (!usesKeychain) return true;
    return !usesDataProtectionKeychain;
  }

  /// Whether Keychain (DP or legacy migrate) may be touched.
  static bool get _mayTouchKeychain => _isMacOS && usesKeychain;

  static String prefsKey(String key) => '$_prefsPrefix$key';

  /// Load persisted consent (call before first secure read on macOS boot).
  static Future<ForjaKeychainConsent> ensureConsentLoaded() async {
    if (!_isMacOS) {
      _cachedConsent = ForjaKeychainConsent.accepted;
      return _cachedConsent!;
    }
    if (_cachedConsent != null) return consent;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_consentPrefsKey);
      _cachedConsent = switch (raw) {
        'accepted' => ForjaKeychainConsent.accepted,
        'declined' => ForjaKeychainConsent.declined,
        // Default: local file — do not ask at boot.
        _ => ForjaKeychainConsent.declined,
      };
      // Persist default so later launches stay quiet.
      if (raw == null || raw.isEmpty) {
        await prefs.setString(_consentPrefsKey, 'declined');
      }
    } catch (_) {
      _cachedConsent = ForjaKeychainConsent.declined;
    }
    return consent;
  }

  /// Persist Keychain vs local-file choice (Settings opt-in / opt-out).
  static Future<void> setKeychainConsent(ForjaKeychainConsent value) async {
    if (value == ForjaKeychainConsent.unset) {
      throw ArgumentError('Use accepted or declined');
    }
    _cachedConsent = value;
    if (!_isMacOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _consentPrefsKey,
        value == ForjaKeychainConsent.accepted ? 'accepted' : 'declined',
      );
    } catch (e) {
      debugPrint('[ForjaPlatformSecureStore] consent persist failed: $e');
    }
  }

  static Future<String?> read(String key) async {
    await ensureConsentLoaded();

    if (_isMacOS && !_mayTouchKeychain) {
      return _readPrefsVault(key);
    }

    if (_isMacOS && !usesDataProtectionKeychain) {
      final vault = await _readPrefsVault(key);
      if (vault != null) return vault;
      return _migrateFromLegacyLogin(key);
    }

    if (_isAndroid) {
      final vault = await _readPrefsVault(key);
      if (vault != null && vault.isNotEmpty) return vault;
    }

    try {
      final v = await _dp.read(key: key);
      if (v != null && v.isNotEmpty) {
        if (_isAndroid) {
          // Backfill vault if EncryptedSharedPreferences still has the value.
          await _writePrefsVault(key, v);
        }
        return v;
      }
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
    await ensureConsentLoaded();

    // macOS without Keychain opt-in, or ad-hoc non-sandbox: vault only.
    if (_isMacOS && (!usesKeychain || !usesDataProtectionKeychain)) {
      await _writePrefsVault(key, value);
      return;
    }

    if (_usePrefsVaultPrimary) {
      await _writePrefsVault(key, value);
      // Android dual-writes EncryptedSharedPreferences below.
      if (!_isAndroid) return;
    }

    try {
      await _dp.write(key: key, value: value);
    } on MissingPluginException {
      debugPrint(
        '[ForjaPlatformSecureStore] write skipped — no secure plugin ($key)',
      );
      if (_usePrefsVaultPrimary) return;
      rethrow;
    } catch (e) {
      debugPrint('[ForjaPlatformSecureStore] DP write failed ($key): $e');
      if (_usePrefsVaultPrimary) return;
      rethrow;
    }

    // Desktop sandboxed: drop prefs vault copies so Keychain is sole source.
    if (!_isAndroid) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(prefsKey(key));
        await prefs.remove(key);
      } catch (_) {}
    }
  }

  static Future<void> delete(String key) async {
    await ensureConsentLoaded();

    if (_isMacOS && !_mayTouchKeychain) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(prefsKey(key));
        await prefs.remove(key);
      } catch (_) {}
      return;
    }

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
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey(key));
      await prefs.remove(key);
    } catch (_) {}
  }

  static Future<void> _writePrefsVault(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey(key), value);
    await prefs.remove(key);
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
  /// May show one Keychain Allow dialog; only after in-app consent.
  static Future<String?> _migrateFromLegacyLogin(String key) async {
    if (!_isMacOS || !_mayTouchKeychain) return null;
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
