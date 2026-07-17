import 'package:flutter/foundation.dart';
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

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!isConfigured) {
      debugPrint(
        '[Supabase] Not configured — set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY',
      );
      return;
    }
    await Supabase.initialize(
      url: url,
      // Same project key as apps/web VITE_SUPABASE_PUBLISHABLE_KEY.
      publishableKey: publishableKey,
    );
    _initialized = true;
    debugPrint('[Supabase] Initialized');
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
