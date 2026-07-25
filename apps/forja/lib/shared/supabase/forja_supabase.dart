import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_secure_local_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase project with [apps/web].
///
/// Pass at run/build time:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
class ForjaSupabase {
  ForjaSupabase._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static String get _persistSessionKey {
    final host = Uri.tryParse(url)?.host ?? 'forja';
    return 'sb-$host-auth-token';
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!isConfigured) {
      debugPrint(
        '[Supabase] Not configured - set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY',
      );
      return;
    }
    final localStorage = kIsWeb
        ? null
        : ForjaSecureLocalStorage(persistSessionKey: _persistSessionKey);
    await Supabase.initialize(
      url: url,
      // Same project key as apps/web VITE_SUPABASE_PUBLISHABLE_KEY.
      publishableKey: publishableKey,
      authOptions: FlutterAuthClientOptions(
        // Desktop/mobile: ForjaPlatformSecureStore (DP Keychain when sandboxed;
        // prefs vault on ad-hoc macOS). Web keeps plugin defaults.
        localStorage: localStorage,
      ),
    );
    _initialized = true;
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final persisted = localStorage == null
        ? null
        : await localStorage.hasAccessToken();
    debugPrint(
      '[Supabase] Initialized signedIn=$signedIn '
      'persistedSession=${persisted ?? 'n/a (web)'}',
    );
  }

  static SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('ForjaSupabase.ensureInitialized() was not called');
    }
    return Supabase.instance.client;
  }
}
