import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool get isSignedIn => session != null;
  String? get userEmail => session?.user.email;
  Session? get session => ForjaSupabase.clientOrNull?.auth.currentSession;

  Stream<AuthState> get authChanges {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      debugPrint('[Sync] signIn failed: Supabase not configured');
      return false;
    }
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.session != null;
    } catch (e) {
      debugPrint('[Sync] signIn error: $e');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return false;
    try {
      final res = await client.auth.signUp(email: email, password: password);
      return res.session != null || res.user != null;
    } catch (e) {
      debugPrint('[Sync] signUp error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return;
    await client.auth.signOut();
  }

  /// Upsert domain payloads. Domain allowlist is deferred (RFC-006 R06-A09).
  Future<void> pushSettings(Map<String, dynamic> domains) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = domains.entries
        .map(
          (e) => {
            'user_id': userId,
            'domain': e.key,
            'payload': e.value,
            'updated_at': now,
          },
        )
        .toList();

    if (rows.isEmpty) return;

    try {
      await client.from('user_settings').upsert(rows);
    } catch (e) {
      debugPrint('[Sync] pushSettings error: $e');
    }
  }

  Future<void> pushDomain(String domain, Map<String, dynamic> payload) async {
    await pushSettings({domain: payload});
  }

  Future<Map<String, dynamic>?> pullSettings() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;

    try {
      final rows = await client
          .from('user_settings')
          .select('domain, payload, updated_at')
          .eq('user_id', userId);
      final out = <String, dynamic>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        out[map['domain'] as String] = {
          'payload': map['payload'],
          'updated_at': map['updated_at'],
        };
      }
      return out;
    } catch (e) {
      debugPrint('[Sync] pullSettings error: $e');
      return null;
    }
  }
}
