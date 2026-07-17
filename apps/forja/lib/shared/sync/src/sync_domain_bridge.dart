import 'dart:async';

import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_store.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:rust/rust.dart';

/// Export/import between local stores and lean `profile_settings.payload`.
class SyncDomainBridge {
  SyncDomainBridge._();
  static final SyncDomainBridge instance = SyncDomainBridge._();

  static const _domainIptv = 'iptv';
  static const _domainPreferences = 'preferences';
  static const _domainProviders = 'providers';
  static const _domainStremio = 'stremio';
  static const _domainNavigation = 'navigation';

  final _settings = SettingsService();
  final Map<String, Timer> _pushTimers = {};

  /// Drop deferred cloud pushes (sign-out / tear-down). Does not write local stores.
  void cancelPendingPushes() {
    for (final timer in _pushTimers.values) {
      timer.cancel();
    }
    _pushTimers.clear();
  }

  /// Persist the current profile before changing the device-local selection.
  Future<void> prepareProfileSwitch() async {
    cancelPendingPushes();
    await pushAllLocal();
  }

  Future<void> pullAndMergeAll() async {
    if (!SyncService.instance.isSignedIn) return;
    final remote = await SyncService.instance.pullProfileSettings();
    if (remote == null) {
      await pushAllLocal();
      return;
    }
    await _applyLeanPayload(remote);
    await _pullAndApplyUserIptvPortals();
  }

  Future<void> pushAllLocal() async {
    if (!SyncService.instance.isSignedIn) return;
    final payload = await _buildLeanPayload();
    await SyncService.instance.pushProfileSettings(payload);
    await _pushUserIptvPortals();
  }

  void schedulePush(String domain) {
    if (!SyncService.instance.isSignedIn) return;
    _pushTimers[domain]?.cancel();
    _pushTimers[domain] = Timer(const Duration(seconds: 3), () {
      unawaited(pushAllLocal());
    });
  }

  Future<Map<String, dynamic>> _buildLeanPayload() async {
    final out = <String, dynamic>{};

    // Full playback prefs (incl. play_source_*) — never strip defaults.
    out['playback'] = await exportPreferences();

    final providers = await _exportProvidersCompact();
    final stremio = await _exportStremioCompact();
    final connected = <String, dynamic>{};
    if (providers.isNotEmpty) connected['providers'] = providers;
    if (stremio.isNotEmpty) connected['stremio'] = stremio;
    if (connected.isNotEmpty) out['connectedServices'] = connected;

    final navigation = await _exportNavigationCompact();
    if (navigation.isNotEmpty) out['navigation'] = navigation;

    // Settings iptv = M3U only. Portals use user_iptv_portals.
    final iptv = await _exportIptvM3uCompact();
    if (iptv.isNotEmpty) out['iptv'] = iptv;

    return out;
  }

  Future<void> _applyLeanPayload(Map<String, dynamic> payload) async {
    final playback = payload['playback'];
    if (playback is Map) {
      await importPreferences(Map<String, dynamic>.from(playback));
    }

    final connected = payload['connectedServices'];
    if (connected is Map) {
      final providers = connected['providers'];
      if (providers is Map) {
        await importProviders(Map<String, dynamic>.from(providers));
      }
      final stremio = connected['stremio'];
      if (stremio is Map) {
        await importStremio(Map<String, dynamic>.from(stremio));
      }
    }

    final navigation = payload['navigation'];
    if (navigation is Map) {
      await _importNavigation(Map<String, dynamic>.from(navigation));
    }

    final iptv = payload['iptv'];
    if (iptv is Map) {
      final iptvMap = Map<String, dynamic>.from(iptv);
      await _importIptvM3uLean(iptvMap);
      // One-shot: migrate legacy settings.iptv.portals → user_iptv_portals.
      if (iptvMap['portals'] is List &&
          (iptvMap['portals'] as List).isNotEmpty) {
        await _migrateLegacyIptvPortalsFromSettings(iptvMap);
      }
    }
  }

  Future<void> _migrateLegacyIptvPortalsFromSettings(
    Map<String, dynamic> iptv,
  ) async {
    final rawAssignments = iptv['portals'] as List? ?? const [];
    if (rawAssignments.isEmpty) return;
    final existing = await SyncService.instance.pullUserIptvPortals();
    if (existing.isNotEmpty) return; // table already owns assignments

    final ids = <String>[];
    final nameById = <String, String>{};
    final favoriteIds = <String>{};
    for (final raw in rawAssignments) {
      final o = Map<String, dynamic>.from(raw as Map);
      final id = o['portalId'] as String? ?? '';
      if (id.isEmpty) continue;
      ids.add(id);
      final portalName =
          ((o['portal_name'] as String?) ?? (o['label'] as String?))?.trim() ??
          '';
      if (portalName.isNotEmpty) nameById[id] = portalName;
      if (o['favorite'] == true) favoriteIds.add(id);
    }
    if (ids.isEmpty) return;

    final globals = await SyncService.instance.getIptvPortals(ids);
    final assignments =
        <({String portalId, String portalName, bool favorite})>[];
    for (final g in globals) {
      final id = g['id'] as String? ?? '';
      if (id.isEmpty) continue;
      final username = g['username'] as String? ?? '';
      assignments.add((
        portalId: id,
        portalName: nameById[id] ?? username,
        favorite: favoriteIds.contains(id),
      ));
    }
    if (assignments.isEmpty) return;
    await SyncService.instance.replaceUserIptvPortals(assignments);
  }

  Future<Map<String, dynamic>> _exportProvidersCompact() async {
    final stream = await _settings.getStreamProviderOrder();
    final anime = await _settings.getAnimeProviderOrder();
    final asian = await _settings.getAsianDramaProviderOrder();
    final out = <String, dynamic>{};
    if (!_listEquals(stream, SettingsService.defaultStreamProviderOrder)) {
      out['stream_provider_order'] = stream;
    }
    if (!_listEquals(anime, SettingsService.defaultAnimeProviderOrder)) {
      out['anime_provider_order'] = anime;
    }
    if (!_listEquals(asian, SettingsService.defaultAsianDramaProviderOrder)) {
      out['asian_drama_provider_order'] = asian;
    }
    return out;
  }

  Future<Map<String, dynamic>> _exportStremioCompact() async {
    final addons = await _settings.getStremioAddons();
    if (addons.isEmpty) return {};
    final lean = <Map<String, dynamic>>[];
    for (final raw in addons) {
      final baseUrl = (raw['baseUrl'] as String?)?.trim() ?? '';
      if (baseUrl.isEmpty) continue;
      final row = <String, dynamic>{'baseUrl': baseUrl};
      final name = (raw['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) row['name'] = name;
      final description = (raw['description'] as String?)?.trim();
      if (description != null && description.isNotEmpty) {
        row['description'] = description;
      }
      lean.add(row);
    }
    return lean.isEmpty ? {} : {'addons': lean};
  }

  Future<Map<String, dynamic>> _exportNavigationCompact() async {
    final ids = await _settings.getNavbarConfig();
    final defaultTab = await _settings.getDefaultNavTab();
    final out = <String, dynamic>{};
    if (ids.isNotEmpty) out['visibleIds'] = ids;
    if (defaultTab.trim().isNotEmpty) {
      out['defaultTab'] = defaultTab.trim();
    }
    return out;
  }

  Future<void> _importNavigation(Map<String, dynamic> payload) async {
    if (payload['visibleIds'] is List) {
      await _settings.setNavbarConfig(
        (payload['visibleIds'] as List).cast<String>(),
      );
    }
    if (payload['defaultTab'] is String) {
      await _settings.setDefaultNavTab(payload['defaultTab'] as String);
    }
  }

  Future<Map<String, dynamic>> _exportIptvM3uCompact() async {
    final m3u = await M3uStore.loadAll();
    final cloudM3u = <Map<String, dynamic>>[];
    for (final p in m3u) {
      final url = p.sourceUrl?.trim();
      if (url == null || url.isEmpty) continue; // file playlists stay local
      cloudM3u.add({
        'id': p.id,
        'name': p.name,
        'sourceUrl': url,
        'addedAt': p.addedAt,
        'updatedAt': p.updatedAt,
      });
    }
    if (cloudM3u.isEmpty) return {};
    return {'m3uPlaylists': cloudM3u};
  }

  Future<void> _pushUserIptvPortals() async {
    final portals = await IptvStore.load();
    final favorites = await IptvStore.loadFavorites();
    final assignments =
        <({String portalId, String portalName, bool favorite})>[];

    for (final v in portals) {
      final portalId = await SyncService.instance.upsertIptvPortal(
        url: v.portal.url,
        username: v.portal.username,
        password: v.portal.password,
        source: v.portal.source.isEmpty ? null : v.portal.source,
        expiry: v.expiry.isEmpty ? null : v.expiry,
        maxConnections: v.maxConnections.isEmpty ? null : v.maxConnections,
      );
      if (portalId == null) continue;
      final portalName = v.label.trim().isNotEmpty
          ? v.label.trim()
          : v.portal.username;
      assignments.add((
        portalId: portalId,
        portalName: portalName,
        favorite: favorites.contains(v.portal.key),
      ));
    }

    await SyncService.instance.replaceUserIptvPortals(assignments);
  }

  Future<void> _pullAndApplyUserIptvPortals() async {
    final rows = await SyncService.instance.pullUserIptvPortals();
    final portals = <VerifiedPortal>[];
    final favoriteKeys = <String>{};
    for (final row in rows) {
      final portal = row['portal'];
      if (portal is! Map) continue;
      final g = Map<String, dynamic>.from(portal);
      final url = g['url'] as String? ?? '';
      final username = g['username'] as String? ?? '';
      final password = g['password'] as String? ?? '';
      final verified = VerifiedPortal(
        portal: IptvPortal(
          url: url,
          username: username,
          password: password,
          source: g['source'] as String? ?? '',
        ),
        // Per-profile label from user_iptv_portals.portal_name
        label: (row['portal_name'] as String?)?.trim() ?? '',
        // Device-local Xtream probe name (not stored in cloud).
        name: '',
        expiry: g['expiry'] as String? ?? '',
        maxConnections: g['max_connections'] as String? ?? '1',
        activeConnections: '0',
      );
      portals.add(verified);
      if (row['favorite'] == true) {
        favoriteKeys.add(verified.portal.key);
      }
    }
    await IptvStore.save(portals);
    await IptvStore.saveFavorites(favoriteKeys);
  }

  Future<void> _importIptvM3uLean(Map<String, dynamic> payload) async {
    // Legacy: if portals still present in settings JSON, ignore — table owns them.
    final localM3u = await M3uStore.loadAll();
    final fileLocal = localM3u
        .where((p) => p.sourceUrl == null || p.sourceUrl!.trim().isEmpty)
        .toList();
    final localById = {for (final p in localM3u) p.id: p};

    final remoteM3u = payload['m3uPlaylists'] as List? ?? const [];
    final mergedUrl = <M3uPlaylist>[];
    for (final raw in remoteM3u) {
      final o = Map<String, dynamic>.from(raw as Map);
      final sourceUrl = (o['sourceUrl'] as String?)?.trim() ?? '';
      if (sourceUrl.isEmpty) continue;
      final id = o['id'] as String? ?? '';
      final existing = localById[id];
      mergedUrl.add(
        M3uPlaylist(
          id: id.isEmpty ? existing?.id ?? '' : id,
          name: o['name'] as String? ?? existing?.name ?? 'Playlist',
          sourceUrl: sourceUrl,
          addedAt: (o['addedAt'] as num?)?.toInt() ?? existing?.addedAt ?? 0,
          updatedAt:
              (o['updatedAt'] as num?)?.toInt() ?? existing?.updatedAt ?? 0,
          channels: existing?.channels ?? const [],
        ),
      );
    }
    await M3uStore.saveAll([...fileLocal, ...mergedUrl]);
  }

  Future<Map<String, dynamic>> exportIptv() async {
    // Legacy export shape for debugging — assignments + m3u.
    final m3u = await _exportIptvM3uCompact();
    return m3u;
  }

  Future<void> importIptv(Map<String, dynamic> payload) async {
    await _importIptvM3uLean(payload);
    await _pullAndApplyUserIptvPortals();
  }

  Future<Map<String, dynamic>> exportPreferences() async {
    return {
      'play_source_torrent_enabled':
          await _settings.isPlaySourceTorrentEnabled(),
      'play_source_stremio_enabled': await _settings.isPlaySourceStremioEnabled(),
      'play_source_webstreaming_enabled':
          await _settings.isPlaySourceWebstreamingEnabled(),
      'preferred_audio_lang': await _settings.getPreferredAudioLanguage(),
      'avoid_unsupported_audio': await _settings.getAvoidUnsupportedAudio(),
      'auto_next_episode': await _settings.getAutoNextEpisode(),
      'auto_skip_intro': await _settings.getAutoSkipIntro(),
      'iptv_epg_enabled': await _settings.isIptvEpgEnabled(),
      'max_playback_height': await _settings.getMaxPlaybackHeight(),
    };
  }

  Future<void> importPreferences(Map<String, dynamic> payload) async {
    if (payload.containsKey('play_source_torrent_enabled')) {
      await _settings.setPlaySourceTorrentEnabled(
        payload['play_source_torrent_enabled'] as bool,
      );
    }
    if (payload.containsKey('play_source_stremio_enabled')) {
      await _settings.setPlaySourceStremioEnabled(
        payload['play_source_stremio_enabled'] as bool,
      );
    }
    if (payload.containsKey('play_source_webstreaming_enabled')) {
      await _settings.setPlaySourceWebstreamingEnabled(
        payload['play_source_webstreaming_enabled'] as bool,
      );
    }
    if (payload.containsKey('preferred_audio_lang')) {
      await _settings.setPreferredAudioLanguage(
        payload['preferred_audio_lang'] as String,
      );
    }
    if (payload.containsKey('avoid_unsupported_audio')) {
      await _settings.setAvoidUnsupportedAudio(
        payload['avoid_unsupported_audio'] as bool,
      );
    }
    if (payload.containsKey('auto_next_episode')) {
      await _settings.setAutoNextEpisode(payload['auto_next_episode'] as bool);
    }
    if (payload.containsKey('auto_skip_intro')) {
      await _settings.setAutoSkipIntro(payload['auto_skip_intro'] as bool);
    }
    if (payload.containsKey('iptv_epg_enabled')) {
      await _settings.setIptvEpgEnabled(payload['iptv_epg_enabled'] as bool);
    }
    if (payload.containsKey('max_playback_height')) {
      await _settings.setMaxPlaybackHeight(
        (payload['max_playback_height'] as num).toInt(),
      );
    }
  }

  Future<Map<String, dynamic>> exportProviders() async {
    return {
      'stream_provider_order': await _settings.getStreamProviderOrder(),
      'anime_provider_order': await _settings.getAnimeProviderOrder(),
      'asian_drama_provider_order':
          await _settings.getAsianDramaProviderOrder(),
    };
  }

  Future<void> importProviders(Map<String, dynamic> payload) async {
    if (payload['stream_provider_order'] is List) {
      await _settings.setStreamProviderOrder(
        (payload['stream_provider_order'] as List).cast<String>(),
      );
    }
    if (payload['anime_provider_order'] is List) {
      await _settings.setAnimeProviderOrder(
        (payload['anime_provider_order'] as List).cast<String>(),
      );
    }
    if (payload['asian_drama_provider_order'] is List) {
      await _settings.setAsianDramaProviderOrder(
        (payload['asian_drama_provider_order'] as List).cast<String>(),
      );
    }
  }

  Future<Map<String, dynamic>> exportStremio() async {
    return {'addons': await _settings.getStremioAddons()};
  }

  Future<void> importStremio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final remoteUrls = <String>{
      for (final raw in addons)
        if ((raw as Map)['baseUrl'] is String) (raw)['baseUrl'] as String,
    };
    final current = await _settings.getStremioAddons();
    for (final addon in current) {
      final baseUrl = addon['baseUrl'] as String? ?? '';
      if (baseUrl.isNotEmpty && !remoteUrls.contains(baseUrl)) {
        await _settings.removeStremioAddon(baseUrl);
      }
    }
    for (final raw in addons) {
      final addon = Map<String, dynamic>.from(raw as Map);
      final baseUrl = addon['baseUrl'] as String? ?? '';
      if (baseUrl.isEmpty) continue;
      await _settings.saveStremioAddon(addon);
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

void schedulePreferencesSyncPush() => SyncDomainBridge.instance
    .schedulePush(SyncDomainBridge._domainPreferences);

void scheduleProvidersSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainProviders);

void scheduleStremioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainStremio);

void scheduleNavigationSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNavigation);
