import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the OS keychain / Keystore (desktop/mobile).
///
/// Mirrors Guepard's "refresh in secure store" idea without a Tauri sidecar.
class ForjaSecureLocalStorage extends LocalStorage {
  ForjaSecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  @override
  Future<bool> hasAccessToken() async {
    final value = await _storage.read(key: persistSessionKey);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(
      key: persistSessionKey,
      value: persistSessionString,
    );
  }
}
