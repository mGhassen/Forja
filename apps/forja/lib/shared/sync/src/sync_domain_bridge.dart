import 'dart:async';

import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:rust/rust.dart';

/// Export/import between local stores and lean `profile_settings.payload`.
///
/// IPTV portals sync via `user_iptv_portals` / `iptv_portals` — never
/// `profile_settings`. M3U playlists are device-local only.
class SyncDomainBridge {
  SyncDomainBridge._();
  static final SyncDomainBridge instance = SyncDomainBridge._();

  /// Debounce key for portal assignment pushes (not profile_settings.iptv).
  static const _domainIptv = 'iptv';
  static const _domainPreferences = 'preferences';
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
    if (!SyncService.instance.isSignedIn) {
      AccountFeatures.instance.clear();
      return;
    }
    await SyncService.instance.pullAccountFeatures();
    final remote = await SyncService.instance.pullProfileSettings();
    if (remote == null) {
      await pushAllLocal();
      return;
    }
    await _applyLeanPayload(remote);
    await _pullAndApplyUserIptvPortals();
  }

  /// Pull cloud portal assignments into local IPTV store (after deal / remote edit).
  Future<void> pullIptvPortalsFromCloud() async {
    if (!SyncService.instance.isSignedIn) return;
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

    final stremio = await _exportStremioCompact();
    final connected = <String, dynamic>{};
    if (stremio.isNotEmpty) connected['stremio'] = stremio;
    if (connected.isNotEmpty) out['connectedServices'] = connected;

    final navigation = await _exportNavigationCompact();
    if (navigation.isNotEmpty) out['navigation'] = navigation;

    // Never write iptv into profile_settings — portals use user_iptv_portals;
    // M3U stays device-local.
    return out;
  }

  Future<void> _applyLeanPayload(Map<String, dynamic> payload) async {
    final playback = payload['playback'];
    if (playback is Map) {
      await importPreferences(Map<String, dynamic>.from(playback));
    }

    final connected = payload['connectedServices'];
    if (connected is Map) {
      // Provider order is device-local — ignore legacy cloud providers keys.
      final stremio = connected['stremio'];
      if (stremio is Map) {
        await importStremio(Map<String, dynamic>.from(stremio));
      }
    }

    final navigation = payload['navigation'];
    if (navigation is Map) {
      await _importNavigation(Map<String, dynamic>.from(navigation));
    }

    // Ignore legacy payload.iptv (M3U / portals) — tables + local store own IPTV.
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
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

void schedulePreferencesSyncPush() => SyncDomainBridge.instance
    .schedulePush(SyncDomainBridge._domainPreferences);

void scheduleProvidersSyncPush() {
  // Provider order is device-local — do not push to cloud.
}

void scheduleStremioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainStremio);

void scheduleNavigationSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNavigation);
