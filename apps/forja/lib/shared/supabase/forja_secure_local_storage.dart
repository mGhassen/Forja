import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the OS keychain / Keystore (desktop/mobile).
///
/// macOS **release** builds disable App Sandbox ([Release.entitlements]). The
/// plugin default `useDataProtectionKeyChain: true` then fails with Keychain
/// `-34018`; supabase_flutter swallows the write error and the next cold start
/// looks signed out. Use the legacy login keychain on macOS instead.
class ForjaSecureLocalStorage extends LocalStorage {
  ForjaSecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  @override
  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await accessToken();
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: persistSessionKey);
    } catch (e) {
      debugPrint('[Supabase] session read failed: $e');
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (e) {
      debugPrint('[Supabase] session delete failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(
        key: persistSessionKey,
        value: persistSessionString,
      );
    } catch (e) {
      debugPrint('[Supabase] session persist failed: $e');
      rethrow;
    }
  }
}
