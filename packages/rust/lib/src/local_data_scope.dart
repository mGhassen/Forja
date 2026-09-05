import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Active account + profile for **local** prefs / KV / disk namespaces.
///
/// Guest / signed-out: `local` / `default` (same as [PluginScriptDiskStore]).
/// Signed-in: Supabase user id + profile id.
///
/// [storageKey] → `base@accountId:profileId`. Call [configure] from SyncService
/// whenever the shell identity changes; listeners reload in-memory caches.
abstract final class LocalDataScope {
  static const guestAccountId = 'local';
  static const guestProfileId = 'default';
  static const _migratedPrefsKey = 'local_data_scope_v1_migrated';

  static String _accountId = guestAccountId;
  static String _profileId = guestProfileId;

  static final List<Future<void> Function()> _listeners = [];

  static String get accountId => _accountId;
  static String get profileId => _profileId;

  /// `accountId:profileId` — suffix for prefs keys and disk path segments.
  static String get id => '$_accountId:$_profileId';

  static bool get isGuest =>
      _accountId == guestAccountId && _profileId == guestProfileId;

  /// Prefs / KV key for [base] under the active identity.
  static String storageKey(String base) => '$base@$id';

  /// True when [key] belongs to the active identity (`…@account:profile`).
  static bool ownsKey(String key) => key.endsWith('@$id');

  static void addListener(Future<void> Function() listener) {
    _listeners.add(listener);
  }

  static void removeListener(Future<void> Function() listener) {
    _listeners.remove(listener);
  }

  /// Test / tear-down — resets to guest without notifying or migrating.
  @visibleForTesting
  static void resetForTest() {
    _accountId = guestAccountId;
    _profileId = guestProfileId;
    _listeners.clear();
  }

  /// Active account + profile — must track SyncService select / guest / sign-out.
  static Future<void> configure({
    required String? accountId,
    required String? profileId,
  }) async {
    final account = _sanitize(accountId ?? guestAccountId);
    final profile = _sanitize(profileId ?? guestProfileId);
    final changed = _accountId != account || _profileId != profile;
    _accountId = account;
    _profileId = profile;
    // Always attempt one-time legacy migrate (guest boot keeps local/default).
    await _migrateLegacyKeysIfNeeded();
    if (!changed) return;
    for (final listener in List<Future<void> Function()>.from(_listeners)) {
      try {
        await listener();
      } catch (e) {
        debugPrint('[LocalDataScope] listener failed: $e');
      }
    }
  }

  static String _sanitize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return guestProfileId;
    return t.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  /// One-time: copy unscoped legacy keys into the **current** scope, then drop
  /// the bare keys (same pattern as plugin disk flat → scoped migrate).
  static Future<void> _migrateLegacyKeysIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedPrefsKey) == true) return;

    // Mix of JSON strings and string lists — migrate by runtime type.
    const legacyBases = <String>[
      'episodes_watched',
      'episodes_watched_timestamps',
      'my_list_items',
      'forja_player_stream_extract_cache_v1',
      'forja_webstreaming_stream_cache_v1',
      'enma_anime_stream_cache_v1',
      'enma_anime_source_v1',
      'pt_iptv_catalog_lru_v1',
    ];
    for (final base in legacyBases) {
      await _migratePref(prefs, base);
    }

    // Hub continue-watching: catalog_cw_{pluginId}
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('catalog_cw_')) continue;
      if (key.contains('@')) continue;
      await _migratePref(prefs, key);
    }

    // IPTV alive / liveonly / channel-scan prefs
    for (final key in prefs.getKeys().toList()) {
      if (key.contains('@')) continue;
      final isAlive = key.startsWith('pt_iptv_alive_') ||
          key.startsWith('pt_iptv_liveonly_') ||
          key.startsWith('pt_iptv_ch_');
      if (!isAlive) continue;
      await _migratePref(prefs, key);
    }

    await prefs.setBool(_migratedPrefsKey, true);
  }

  /// Copy bare [base] into the active scope, preserving string / list / bool.
  /// Typed getters (`getString`) throw if the stored type differs — use [get].
  static Future<void> _migratePref(
    SharedPreferences prefs,
    String base,
  ) async {
    if (!prefs.containsKey(base)) return;
    final scoped = storageKey(base);
    if (!prefs.containsKey(scoped)) {
      final value = prefs.get(base);
      if (value is String) {
        await prefs.setString(scoped, value);
      } else if (value is List) {
        await prefs.setStringList(
          scoped,
          value.map((e) => e?.toString() ?? '').toList(),
        );
      } else if (value is bool) {
        await prefs.setBool(scoped, value);
      } else if (value is int) {
        await prefs.setInt(scoped, value);
      } else if (value is double) {
        await prefs.setDouble(scoped, value);
      }
    }
    await prefs.remove(base);
  }

  /// KV / engine-store keys (watch history, etc.) — migrate bare → scoped once.
  static Future<void> migrateKvStringListIfNeeded({
    required String base,
    required Future<List<Map<String, dynamic>>> Function(String key) readList,
    required Future<void> Function(String key, List<Map<String, dynamic>> list)
        writeList,
    required Future<void> Function(String key) clearKey,
  }) async {
    final scoped = storageKey(base);
    final legacy = await readList(base);
    if (legacy.isEmpty) return;
    final existing = await readList(scoped);
    if (existing.isEmpty) {
      await writeList(scoped, legacy);
    }
    await clearKey(base);
  }

  static Future<void> migrateKvStringListPlainIfNeeded({
    required String base,
    required Future<List<String>> Function(String key) readList,
    required Future<void> Function(String key, List<String> list) writeList,
    required Future<void> Function(String key) clearKey,
  }) async {
    final scoped = storageKey(base);
    final legacy = await readList(base);
    if (legacy.isEmpty) return;
    final existing = await readList(scoped);
    if (existing.isEmpty) {
      await writeList(scoped, legacy);
    }
    await clearKey(base);
  }
}
