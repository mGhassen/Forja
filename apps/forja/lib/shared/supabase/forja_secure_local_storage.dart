import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rust/rust.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session via [ForjaPlatformSecureStore].
///
/// macOS: Keychain opt-in or prefs vault. Android: prefs + on-disk file vault
/// + EncryptedSharedPreferences (file vault is cold-start SoT — issue 519).
class ForjaSecureLocalStorage extends LocalStorage {
  ForjaSecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

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
      return await ForjaPlatformSecureStore.read(persistSessionKey);
    } catch (e) {
      debugPrint('[Supabase] session read failed: $e');
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await ForjaPlatformSecureStore.delete(persistSessionKey);
    } catch (e) {
      debugPrint('[Supabase] session delete failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await ForjaPlatformSecureStore.write(
        persistSessionKey,
        persistSessionString,
      );
      // Android: prefs/encrypted can look written then vanish on cold start.
      // File vault is the durable SoT — verify we can read back (issue 519).
      final roundTrip = await ForjaPlatformSecureStore.read(persistSessionKey);
      if (roundTrip == null || roundTrip.isEmpty) {
        debugPrint(
          '[Supabase] session persist round-trip empty — retrying write',
        );
        await ForjaPlatformSecureStore.write(
          persistSessionKey,
          persistSessionString,
        );
      }
    } catch (e) {
      debugPrint('[Supabase] session persist failed: $e');
      rethrow;
    }
  }
}
