import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncProfile {
  const SyncProfile({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final String color;
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool get isSignedIn => session != null;
  String? get userEmail => session?.user.email;
  Session? get session => ForjaSupabase.clientOrNull?.auth.currentSession;
  static const _activeProfileKeyPrefix = 'forja_sync_active_profile_';

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

  Future<List<SyncProfile>> listProfiles() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client
          .from('profiles')
          .select('id, name, color, created_at')
          .eq('user_id', userId)
          .order('created_at');
      return [
        for (final raw in rows as List)
          SyncProfile(
            id: (raw as Map)['id'] as String,
            name: raw['name'] as String? ?? 'Profile',
            color: raw['color'] as String? ?? '#1ce783',
          ),
      ];
    } catch (e) {
      debugPrint('[Sync] listProfiles error: $e');
      return const [];
    }
  }

  Future<SyncProfile?> activeProfile() async {
    final userId = session?.user.id;
    if (userId == null) return null;
    final profiles = await listProfiles();
    if (profiles.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_activeProfileKeyPrefix$userId');
    SyncProfile? selected;
    for (final profile in profiles) {
      if (profile.id == saved) {
        selected = profile;
        break;
      }
    }
    final active = selected ?? profiles.first;
    if (saved != active.id) {
      await prefs.setString('$_activeProfileKeyPrefix$userId', active.id);
    }
    return active;
  }

  Future<bool> selectProfile(String profileId) async {
    final userId = session?.user.id;
    if (userId == null) return false;
    final profiles = await listProfiles();
    if (!profiles.any((profile) => profile.id == profileId)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_activeProfileKeyPrefix$userId', profileId);
    return true;
  }

  /// Upsert domain payloads. Domain allowlist is deferred (RFC-006 R06-A09).
  Future<void> pushSettings(Map<String, dynamic> domains) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final profile = await activeProfile();
    if (profile == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = domains.entries
        .map(
          (e) => {
            'user_id': userId,
            'profile_id': profile.id,
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
    final profile = await activeProfile();
    if (profile == null) return null;

    try {
      final rows = await client
          .from('user_settings')
          .select('domain, payload, updated_at')
          .eq('user_id', userId)
          .eq('profile_id', profile.id);
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
