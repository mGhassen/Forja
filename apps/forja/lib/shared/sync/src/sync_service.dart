import 'package:flutter/foundation.dart';
import 'package:forja/shared/supabase/forja_supabase.dart';
import 'package:forja/shared/sync/src/desktop_browser_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncProfile {
  const SyncProfile({
    required this.id,
    required this.name,
    required this.color,
    required this.avatarKey,
  });

  final String id;
  final String name;
  final String color;
  final String avatarKey;
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Rebuilds profile/account chrome after sign-in, sign-out, or profile switch.
  final ValueNotifier<int> identityRevision = ValueNotifier<int>(0);

  bool get isSignedIn => session != null;
  String? get userEmail => session?.user.email;
  Session? get session => ForjaSupabase.clientOrNull?.auth.currentSession;
  static const _activeProfileKeyPrefix = 'forja_sync_active_profile_';

  Stream<AuthState> get authChanges {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange;
  }

  void _notifyIdentityChanged() {
    identityRevision.value++;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _notifyIdentityChanged();
    return response;
  }

  Future<AuthResponse> createAccount({
    required String email,
    required String password,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.signUp(email: email, password: password);
    if (response.session != null) _notifyIdentityChanged();
    return response;
  }

  Future<bool> signIn({required String email, required String password}) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      debugPrint('[Sync] signIn failed: Supabase not configured');
      return false;
    }
    try {
      final res = await signInWithPassword(email: email, password: password);
      return res.session != null;
    } catch (e) {
      debugPrint('[Sync] signIn error: $e');
      return false;
    }
  }

  Future<bool> signUp({required String email, required String password}) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return false;
    try {
      final res = await createAccount(email: email, password: password);
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
    _notifyIdentityChanged();
  }

  /// Applies tokens from [DesktopBrowserAuth] (web portal → localhost callback).
  Future<AuthResponse> signInWithBrowserTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await ForjaSupabase.ensureInitialized();
    final client = ForjaSupabase.clientOrNull;
    if (client == null) {
      throw const AuthException('Supabase is not configured for this build.');
    }
    final response = await client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    if (response.session == null) {
      throw const AuthException('Web login did not return a usable session.');
    }
    _notifyIdentityChanged();
    return response;
  }

  /// Opens the web portal login in the system browser and waits for a session.
  ///
  /// Complete [cancel] to abort the wait (e.g. user tapped Cancel on the
  /// account entry screen).
  Future<AuthResponse> signInWithBrowser({Future<void>? cancel}) async {
    final result = await DesktopBrowserAuth.signIn(cancel: cancel);
    if (!result.isSuccess) {
      throw AuthException(result.error ?? 'Web login failed.');
    }
    return signInWithBrowserTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken!,
    );
  }

  Future<List<SyncProfile>> listProfiles() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    try {
      final rows = await client
          .from('profiles')
          .select('id, name, color, avatar_key, created_at')
          .eq('account_id', userId)
          .order('created_at');
      return [
        for (final raw in rows as List)
          SyncProfile(
            id: (raw as Map)['id'] as String,
            name: raw['name'] as String? ?? 'Profile',
            color: raw['color'] as String? ?? '#1ce783',
            avatarKey: raw['avatar_key'] as String? ?? 'forge',
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
    _notifyIdentityChanged();
    return true;
  }

  static const _profileColors = [
    '#1ce783',
    '#ff4d1c',
    '#5aa9ff',
    '#c084fc',
    '#facc15',
    '#fb7185',
  ];

  Future<SyncProfile> createProfile({
    required String name,
    required String avatarKey,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to create a profile.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AuthException('Enter a profile name.');
    }
    final existing = await listProfiles();
    final color = _profileColors[existing.length % _profileColors.length];
    try {
      final row = await client
          .from('profiles')
          .insert({
            'account_id': userId,
            'name': cleanName,
            'color': color,
            'avatar_key': avatarKey,
          })
          .select('id, name, color, avatar_key')
          .single();
      final profile = SyncProfile(
        id: row['id'] as String,
        name: row['name'] as String? ?? cleanName,
        color: row['color'] as String? ?? color,
        avatarKey: row['avatar_key'] as String? ?? avatarKey,
      );
      await client.from('profile_settings').upsert({
        'profile_id': profile.id,
        'account_id': userId,
        'payload': <String, dynamic>{},
      });
      await selectProfile(profile.id);
      return profile;
    } catch (e) {
      debugPrint('[Sync] createProfile error: $e');
      throw const AuthException('Could not create profile.');
    }
  }

  Future<void> updateProfile({
    required String profileId,
    required String name,
    required String avatarKey,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to edit a profile.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AuthException('Enter a profile name.');
    }
    try {
      await client
          .from('profiles')
          .update({
            'name': cleanName,
            'avatar_key': avatarKey,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', profileId)
          .eq('account_id', userId);
      _notifyIdentityChanged();
    } catch (e) {
      debugPrint('[Sync] updateProfile error: $e');
      throw const AuthException('Could not save profile.');
    }
  }

  Future<void> deleteProfile(String profileId) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      throw const AuthException('Sign in to delete a profile.');
    }
    final profiles = await listProfiles();
    if (profiles.length <= 1) {
      throw const AuthException('Every account needs one profile.');
    }
    final wasActive = (await activeProfile())?.id == profileId;
    try {
      await client
          .from('profiles')
          .delete()
          .eq('id', profileId)
          .eq('account_id', userId);
      if (wasActive) {
        final next = profiles.firstWhere((p) => p.id != profileId);
        await selectProfile(next.id);
      } else {
        _notifyIdentityChanged();
      }
    } catch (e) {
      debugPrint('[Sync] deleteProfile error: $e');
      throw const AuthException('Could not delete profile.');
    }
  }

  /// Upsert domain payloads. Domain allowlist is deferred (RFC-006 R06-A09).
  @Deprecated('Use pushProfileSettings for lean single-row sync')
  Future<void> pushSettings(Map<String, dynamic> domains) async {
    // Compose legacy domain map into one lean profile_settings payload.
    final merged = <String, dynamic>{};
    final connected = <String, dynamic>{};
    for (final e in domains.entries) {
      switch (e.key) {
        case 'preferences':
          merged['playback'] = e.value;
        case 'providers':
          connected['providers'] = e.value;
        case 'stremio':
          connected['stremio'] = e.value;
        case 'iptv':
          merged['iptv'] = e.value;
        case 'navigation':
          merged['navigation'] = e.value;
      }
    }
    if (connected.isNotEmpty) merged['connectedServices'] = connected;
    await pushProfileSettings(merged);
  }

  Future<void> pushDomain(String domain, Map<String, dynamic> payload) async {
    await pushSettings({domain: payload});
  }

  Future<void> pushProfileSettings(Map<String, dynamic> payload) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final profile = await activeProfile();
    if (profile == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await client.from('profile_settings').upsert({
        'profile_id': profile.id,
        'account_id': userId,
        'payload': payload,
        'updated_at': now,
        'updated_by': userId,
      });
    } catch (e) {
      debugPrint('[Sync] pushProfileSettings error: $e');
    }
  }

  Future<Map<String, dynamic>?> pullProfileSettings() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;
    final profile = await activeProfile();
    if (profile == null) return null;

    try {
      final row = await client
          .from('profile_settings')
          .select('payload, updated_at')
          .eq('account_id', userId)
          .eq('profile_id', profile.id)
          .maybeSingle();
      if (row == null) return null;
      final payload = row['payload'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('[Sync] pullProfileSettings error: $e');
      return null;
    }
  }

  @Deprecated('Use pullProfileSettings')
  Future<Map<String, dynamic>?> pullSettings() async {
    final payload = await pullProfileSettings();
    if (payload == null) return null;
    // Adapt to legacy domain wrapper shape for any leftover callers.
    final out = <String, dynamic>{};
    if (payload['playback'] is Map) {
      out['preferences'] = {
        'payload': payload['playback'],
        'updated_at': null,
      };
    }
    final connected = payload['connectedServices'];
    if (connected is Map) {
      if (connected['providers'] is Map) {
        out['providers'] = {
          'payload': connected['providers'],
          'updated_at': null,
        };
      }
      if (connected['stremio'] is Map) {
        out['stremio'] = {
          'payload': connected['stremio'],
          'updated_at': null,
        };
      }
    }
    if (payload['iptv'] is Map) {
      out['iptv'] = {'payload': payload['iptv'], 'updated_at': null};
    }
    return out;
  }

  Future<String?> upsertIptvPortal({
    required String url,
    required String username,
    required String password,
    String? source,
    String? expiry,
    String? maxConnections,
  }) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null) return null;
    try {
      final id = await client.rpc(
        'upsert_iptv_portal',
        params: {
          'p_url': url,
          'p_username': username,
          'p_password': password,
          'p_source': source,
          'p_expiry': expiry,
          'p_max_connections': maxConnections,
        },
      );
      return id as String?;
    } catch (e) {
      debugPrint('[Sync] upsertIptvPortal error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getIptvPortals(List<String> ids) async {
    final client = ForjaSupabase.clientOrNull;
    if (client == null || ids.isEmpty) return const [];
    try {
      final rows = await client.rpc(
        'get_iptv_portals',
        params: {'p_ids': ids},
      );
      if (rows is! List) return const [];
      return [
        for (final raw in rows) Map<String, dynamic>.from(raw as Map),
      ];
    } catch (e) {
      debugPrint('[Sync] getIptvPortals error: $e');
      return const [];
    }
  }

  /// Load this profile's portal assignments (`user_iptv_portals` + credentials).
  Future<List<Map<String, dynamic>>> pullUserIptvPortals() async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return const [];
    final profile = await activeProfile();
    if (profile == null) return const [];

    try {
      final rows = await client
          .from('user_iptv_portals')
          .select()
          .eq('account_id', userId)
          .eq('profile_id', profile.id)
          .order('created_at');
      if (rows.isEmpty) return const [];
      final assignments = [
        for (final raw in rows) Map<String, dynamic>.from(raw as Map),
      ];
      final ids = <String>[
        for (final a in assignments)
          if ((a['portal_id'] as String?)?.isNotEmpty == true)
            a['portal_id'] as String,
      ];
      final globals = await getIptvPortals(ids);
      final byId = {
        for (final g in globals) (g['id'] as String? ?? ''): g,
      };
      final out = <Map<String, dynamic>>[];
      for (final a in assignments) {
        final id = a['portal_id'] as String? ?? '';
        final g = byId[id];
        if (g == null) continue;
        out.add({
          ...a,
          'portal': g,
        });
      }
      return out;
    } catch (e) {
      debugPrint('[Sync] pullUserIptvPortals error: $e');
      return const [];
    }
  }

  /// Replace this profile's `user_iptv_portals` rows.
  /// [portalName] is the per-profile label.
  Future<void> replaceUserIptvPortals(
    List<
      ({
        String portalId,
        String portalName,
        bool favorite,
      })
    >
    assignments,
  ) async {
    final client = ForjaSupabase.clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;
    final profile = await activeProfile();
    if (profile == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await client
          .from('user_iptv_portals')
          .delete()
          .eq('account_id', userId)
          .eq('profile_id', profile.id);

      if (assignments.isEmpty) return;

      await client.from('user_iptv_portals').insert([
        for (final a in assignments)
          {
            'account_id': userId,
            'profile_id': profile.id,
            'portal_id': a.portalId,
            'portal_name': a.portalName,
            'favorite': a.favorite,
            'updated_at': now,
            'updated_by': userId,
            'created_by': userId,
          },
      ]);
    } catch (e) {
      debugPrint('[Sync] replaceUserIptvPortals error: $e');
    }
  }
}
