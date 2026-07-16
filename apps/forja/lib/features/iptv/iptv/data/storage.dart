import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Verified portal store (port of IptvStore.kt).
class IptvStore {
  static const _key = 'pt_iptv_verified_portals';
  static const _favKey = 'pt_iptv_favorite_portal_keys';
  static const _lastPortalKey = 'pt_iptv_last_portal_key';
  static const _lastSectionKey = 'pt_iptv_last_section';

  /// Bumped when portals change outside the IPTV tab (CSV import, etc.).
  static final ValueNotifier<int> listRevision = ValueNotifier(0);

  static void notifyListChanged() {
    listRevision.value++;
  }

  static Future<List<VerifiedPortal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final arr = json.decode(raw) as List;
      return arr.map((e) {
        final o = e as Map<String, dynamic>;
        return VerifiedPortal(
          portal: IptvPortal(
            url: o['url'] as String? ?? '',
            username: o['username'] as String? ?? '',
            password: o['password'] as String? ?? '',
            source: o['source'] as String? ?? '',
          ),
          label: o['label'] as String? ?? '',
          name: o['name'] as String? ?? '',
          expiry: o['expiry'] as String? ?? '',
          maxConnections: o['max'] as String? ?? '1',
          activeConnections: o['active'] as String? ?? '0',
        );
      }).toList();
    } catch (e) {
      debugPrint('IptvStore.load failed: $e');
      return [];
    }
  }

  static Future<void> save(List<VerifiedPortal> list) async {
    final prefs = await SharedPreferences.getInstance();
    final arr = list
        .map((v) => {
              'url': v.portal.url,
              'username': v.portal.username,
              'password': v.portal.password,
              'source': v.portal.source,
              'label': v.label,
              'name': v.name,
              'expiry': v.expiry,
              'max': v.maxConnections,
              'active': v.activeConnections,
            })
        .toList();
    await prefs.setString(_key, json.encode(arr));
    scheduleIptvSyncPush();
  }

  static Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favKey) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> saveFavorites(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, keys.toList());
    scheduleIptvSyncPush();
  }

  static Future<String?> loadLastPortalKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPortalKey);
  }

  static Future<void> saveLastPortalKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPortalKey, key);
  }

  static Future<void> clearLastPortalKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPortalKey);
  }

  static Future<IptvSection> loadLastSection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSectionKey);
    return switch (raw) {
      'vod' => IptvSection.vod,
      'series' => IptvSection.series,
      _ => IptvSection.live,
    };
  }

  static Future<void> saveLastSection(IptvSection section) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (section) {
      IptvSection.vod => 'vod',
      IptvSection.series => 'series',
      IptvSection.live => 'live',
    };
    await prefs.setString(_lastSectionKey, raw);
  }
}

/// Per-portal cache of "alive" live channel IDs + per-portal Live-only pref.
class IptvAliveStore {
  static String portalKey(IptvPortal p) =>
      '${p.url}|${p.username}|${p.password}'.toLowerCase();

  static String _aliveKey(String k) => 'pt_iptv_alive_$k';
  static String _liveOnlyKey(String k) => 'pt_iptv_liveonly_$k';

  static Future<AliveSnapshot?> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_aliveKey(key));
    if (raw == null) return null;
    try {
      final o = json.decode(raw) as Map<String, dynamic>;
      final ids = (o['ids'] as List).map((e) => e as String).toSet();
      return AliveSnapshot(
        checkedAt: (o['at'] as num?)?.toInt() ?? 0,
        aliveIds: ids,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String key, AliveSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _aliveKey(key),
      json.encode({'at': snap.checkedAt, 'ids': snap.aliveIds.toList()}),
    );
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_aliveKey(key));
    await prefs.remove(_liveOnlyKey(key));
  }

  /// Clears every portal's alive-ID snapshot and Live-only pref.
  /// Does not touch verified portals or favorites.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('pt_iptv_alive_') || k.startsWith('pt_iptv_liveonly_'),
    );
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Future<bool> loadLiveOnly(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_liveOnlyKey(key)) ?? false;
  }

  static Future<void> saveLiveOnly(String key, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_liveOnlyKey(key), enabled);
  }
}

class AliveSnapshot {
  final int checkedAt;
  final Set<String> aliveIds;
  const AliveSnapshot({required this.checkedAt, required this.aliveIds});
}

/// Per-HardcodedChannel persisted alive stream hits.
class IptvChannelResultsStore {
  static String _key(String channelId) => 'pt_iptv_ch_$channelId';

  static Future<List<StoredHit>> load(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(channelId));
    if (raw == null) return [];
    try {
      final arr = json.decode(raw) as List;
      return arr.map((e) {
        final o = e as Map<String, dynamic>;
        return StoredHit(
          portalUrl: o['pu'] as String? ?? '',
          portalUser: o['uu'] as String? ?? '',
          portalPass: o['pp'] as String? ?? '',
          portalName: o['pn'] as String? ?? '',
          streamId: o['sid'] as String? ?? '',
          streamName: o['sn'] as String? ?? '',
          streamIcon: o['si'] as String? ?? '',
          streamCategoryId: o['scid'] as String? ?? '',
          streamContainerExt: o['sce'] as String? ?? '',
          streamKind: o['sk'] as String? ?? 'live',
          streamUrl: o['url'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String channelId, List<StoredHit> hits) async {
    final prefs = await SharedPreferences.getInstance();
    final arr = hits
        .map((h) => {
              'pu': h.portalUrl,
              'uu': h.portalUser,
              'pp': h.portalPass,
              'pn': h.portalName,
              'sid': h.streamId,
              'sn': h.streamName,
              'si': h.streamIcon,
              'scid': h.streamCategoryId,
              'sce': h.streamContainerExt,
              'sk': h.streamKind,
              'url': h.streamUrl,
            })
        .toList();
    await prefs.setString(_key(channelId), json.encode(arr));
  }

  static Future<void> clear(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(channelId));
  }

  /// Clears cached channel-scan hits for every hardcoded channel.
  /// Does not touch per-channel favorite stream URLs (`pt_iptv_chfav_*`).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pt_iptv_ch_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

class StoredHit {
  final String portalUrl;
  final String portalUser;
  final String portalPass;
  final String portalName;
  final String streamId;
  final String streamName;
  final String streamIcon;
  final String streamCategoryId;
  final String streamContainerExt;
  final String streamKind;
  final String streamUrl;

  const StoredHit({
    required this.portalUrl,
    required this.portalUser,
    required this.portalPass,
    required this.portalName,
    required this.streamId,
    required this.streamName,
    required this.streamIcon,
    required this.streamCategoryId,
    required this.streamContainerExt,
    required this.streamKind,
    required this.streamUrl,
  });
}

/// Per-HardcodedChannel set of favorited stream URLs (pinned to top).
class IptvChannelFavoritesStore {
  static String _key(String channelId) => 'pt_iptv_chfav_$channelId';

  static Future<Set<String>> load(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(channelId)) ?? const <String>[]).toSet();
  }

  static Future<void> save(String channelId, Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(channelId), urls.toList());
  }
}
