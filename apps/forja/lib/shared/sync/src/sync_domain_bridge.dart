import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/data/storage.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:rust/rust.dart';

/// Export/import between local stores and lean `profile_settings.payload`.
///
/// **Cloud is master** for `profile_settings` and IPTV assignments. Local KV /
/// `IptvStore` are caches — intentional UI edits write the cache then push;
/// wipe / pull / defaults never push incomplete cache over cloud.
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
  static const _domainNuvio = 'nuvio';
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
  ///
  /// Flushes pending domain edits (incl. intentional empty Stremio/Nuvio wipe).
  /// Cloud is master — never push an empty IPTV cache; never drop remote
  /// connectedServices just because local export omitted them.
  Future<void> prepareProfileSwitch() async {
    final pending = Set<String>.from(_pushTimers.keys);
    cancelPendingPushes();
    await pushAllLocal(
      pushIptvIfLocalEmpty: false,
      allowEmptyStremioWipe: pending.contains(_domainStremio),
      allowEmptyNuvioWipe: pending.contains(_domainNuvio),
    );
  }

  /// After sign-out / session loss: cancel pushes, reset synced domains, wipe
  /// IPTV portals + credential caches, notify live controllers.
  Future<void> clearAccountBoundLocalState() async {
    cancelPendingPushes();
    await resetSyncedLocalToPlatformDefaults(clearIptv: true);
    await IptvStore.clearLastPortalKey();
    await IptvAliveStore.clearAll();
    await IptvChannelResultsStore.clearAll();
    await IptvCatalogDiskStore.clearAll();
    IptvStore.notifyListChanged();
  }

  /// Wipe synced local domains to platform defaults (no prior-profile bleed).
  ///
  /// Local KV is a device-global **cache**; every profile switch/create must
  /// reset before applying that profile's cloud payload. Never schedules a
  /// cloud push — empty/default cache must not overwrite cloud.
  Future<void> resetSyncedLocalToPlatformDefaults({
    bool clearIptv = true,
  }) async {
    // Cache-only wipe — cancel any debounced push that would upload defaults.
    cancelPendingPushes();
    final defaults = PlatformDefaults.forProfile(
      SettingsService.platformProfile,
    );
    await importPreferences({
      'play_source_torrent_enabled': defaults.playSourceTorrent,
      'play_source_stremio_enabled': defaults.playSourceStremio,
      'play_source_nuvio_enabled': defaults.playSourceNuvio,
      'play_source_webstreaming_enabled': defaults.playSourceWebstreaming,
      'preferred_audio_lang': 'None',
      'preferred_subtitle_lang': 'English',
      'avoid_unsupported_audio': true,
      'auto_next_episode': true,
      'auto_skip_intro': false,
      'iptv_epg_enabled': defaults.iptvEpgEnabled,
      'max_playback_height': 0,
    });
    await _settings.setNavbarConfig(List<String>.from(defaults.visibleNavIds));
    await _settings.setDefaultNavTab('home');

    final addons = await _settings.getStremioAddons();
    for (final addon in addons) {
      final baseUrl = (addon['baseUrl'] as String?)?.trim() ?? '';
      if (baseUrl.isNotEmpty) {
        await _settings.removeStremioAddon(baseUrl);
      }
    }

    final nuvioAddons = await NuvioService.instance.listAddons();
    for (final addon in nuvioAddons) {
      if (NuvioService.isBundled(addon.manifestUrl)) continue;
      try {
        await NuvioService.instance.remove(addon.manifestUrl);
      } catch (_) {}
    }

    if (clearIptv) {
      // Local cache only — never schedule a cloud push from a wipe.
      await IptvStore.save(const [], scheduleSync: false);
      await IptvStore.saveFavorites({}, scheduleSync: false);
    }
  }

  /// After creating a profile: local defaults + push so cloud is not `{}` / prior prefs.
  Future<void> seedNewProfileDefaults() async {
    cancelPendingPushes();
    await resetSyncedLocalToPlatformDefaults(clearIptv: true);
    // New profile has no assignments yet — settings only; skip empty IPTV wipe.
    await pushAllLocal(pushIptvIfLocalEmpty: false);
  }

  Future<void> pullAndMergeAll() async {
    if (!SyncService.instance.isSignedIn) {
      AccountFeatures.instance.clear();
      return;
    }
    await SyncService.instance.pullAccountFeatures();
    final remote = await SyncService.instance.pullProfileSettings();
    if (remote == null) {
      // Missing row — seed defaults under the active profile (never push prior prefs).
      await seedNewProfileDefaults();
      return;
    }
    await _applyLeanPayload(remote);
    await _pullAndApplyUserIptvPortals();
    // Empty `{}` insert left cloud hollow — backfill settings once (not IPTV).
    if (remote.isEmpty) {
      await pushAllLocal(pushIptvIfLocalEmpty: false);
    }
  }

  /// Pull cloud portal assignments into local IPTV store (after deal / remote edit).
  /// Returns `false` when the pull failed and local inventory was left unchanged.
  Future<bool> pullIptvPortalsFromCloud() async {
    if (!SyncService.instance.isSignedIn) return false;
    return _pullAndApplyUserIptvPortals();
  }

  /// Push lean settings + IPTV. Cloud is master:
  /// - Merges local cache into the existing cloud row (never replaces with a
  ///   partial local export that drops remote keys).
  /// - Empty local Stremio/Nuvio never deletes cloud unless
  ///   [allowEmptyStremioWipe] / [allowEmptyNuvioWipe] (that domain's edit).
  /// - Empty IPTV cache never deletes assignments unless [allowEmptyIptvWipe].
  /// [pushIptvIfLocalEmpty] false skips IPTV entirely when local is empty
  /// (profile switch / seed).
  Future<void> pushAllLocal({
    bool pushIptvIfLocalEmpty = true,
    bool allowEmptyIptvWipe = false,
    bool allowEmptyStremioWipe = false,
    bool allowEmptyNuvioWipe = false,
  }) async {
    if (!SyncService.instance.isSignedIn) return;
    final payload = await _buildMergedCloudPayload(
      allowEmptyStremioWipe: allowEmptyStremioWipe,
      allowEmptyNuvioWipe: allowEmptyNuvioWipe,
    );
    await SyncService.instance.pushProfileSettings(payload);
    await _pushUserIptvPortals(
      pushIfLocalEmpty: pushIptvIfLocalEmpty,
      allowEmptyWipe: allowEmptyIptvWipe,
    );
  }

  /// User intentionally cleared every portal — sync empty assignments to cloud.
  Future<void> pushEmptyIptvInventory() async {
    if (!SyncService.instance.isSignedIn) return;
    await _pushUserIptvPortals(pushIfLocalEmpty: true, allowEmptyWipe: true);
  }

  void schedulePush(String domain) {
    if (!SyncService.instance.isSignedIn) return;
    _pushTimers[domain]?.cancel();
    _pushTimers[domain] = Timer(const Duration(seconds: 3), () {
      // Debounced user edits — empty connected wipe only for that domain.
      unawaited(
        pushAllLocal(
          pushIptvIfLocalEmpty: false,
          allowEmptyStremioWipe: domain == _domainStremio,
          allowEmptyNuvioWipe: domain == _domainNuvio,
        ),
      );
    });
  }

  /// Local cache export for domains we own. Omitted keys mean "unchanged on
  /// cloud" — see [_buildMergedCloudPayload].
  Future<Map<String, dynamic>> _buildLeanPayload() async {
    final out = <String, dynamic>{};

    // Full playback prefs (incl. play_source_*) — never strip defaults.
    out['playback'] = await exportPreferences();

    final stremio = await _exportStremioCompact();
    final nuvio = await _exportNuvioCompact();
    final connected = <String, dynamic>{};
    if (stremio.isNotEmpty) connected['stremio'] = stremio;
    if (nuvio.isNotEmpty) connected['nuvio'] = nuvio;
    if (connected.isNotEmpty) out['connectedServices'] = connected;

    final navigation = await _exportNavigationCompact();
    if (navigation.isNotEmpty) out['navigation'] = navigation;

    // Never write iptv into profile_settings — portals use user_iptv_portals;
    // M3U stays device-local.
    return out;
  }

  /// Cloud SoT: start from remote row, overlay intentional local cache.
  Future<Map<String, dynamic>> _buildMergedCloudPayload({
    required bool allowEmptyStremioWipe,
    required bool allowEmptyNuvioWipe,
  }) async {
    final remote = await SyncService.instance.pullProfileSettings() ?? {};
    final local = await _buildLeanPayload();
    final next = Map<String, dynamic>.from(remote);

    final playback = local['playback'];
    if (playback is Map) {
      next['playback'] = Map<String, dynamic>.from(playback);
    }

    final navigation = local['navigation'];
    if (navigation is Map && navigation.isNotEmpty) {
      next['navigation'] = Map<String, dynamic>.from(navigation);
    }

    final remoteConnected = remote['connectedServices'] is Map
        ? Map<String, dynamic>.from(remote['connectedServices'] as Map)
        : <String, dynamic>{};
    final localConnected = local['connectedServices'] is Map
        ? Map<String, dynamic>.from(local['connectedServices'] as Map)
        : <String, dynamic>{};
    final connected = Map<String, dynamic>.from(remoteConnected);

    if (localConnected.containsKey('stremio')) {
      connected['stremio'] = localConnected['stremio'];
    } else if (allowEmptyStremioWipe) {
      connected.remove('stremio');
    }

    if (localConnected.containsKey('nuvio')) {
      connected['nuvio'] = localConnected['nuvio'];
    } else if (allowEmptyNuvioWipe) {
      connected.remove('nuvio');
    }

    if (connected.isNotEmpty) {
      next['connectedServices'] = connected;
    } else {
      next.remove('connectedServices');
    }

    // Portals use user_iptv_portals; strip any legacy payload.iptv.
    next.remove('iptv');
    return next;
  }

  Future<void> _applyLeanPayload(Map<String, dynamic> payload) async {
    // Reset first: missing lean keys must not keep the previous profile's local state.
    await resetSyncedLocalToPlatformDefaults(clearIptv: false);

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
      final nuvio = connected['nuvio'];
      if (nuvio is Map) {
        await importNuvio(Map<String, dynamic>.from(nuvio));
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

  Future<Map<String, dynamic>> _exportNuvioCompact() async {
    final addons = await NuvioService.instance.listAddons();
    if (addons.isEmpty) return {};
    final lean = <Map<String, dynamic>>[];
    for (final addon in addons) {
      final manifestUrl = addon.manifestUrl.trim();
      if (manifestUrl.isEmpty) continue;
      final row = <String, dynamic>{'manifestUrl': manifestUrl};
      final name = addon.name.trim();
      if (name.isNotEmpty) row['name'] = name;
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

  Future<void> _pushUserIptvPortals({
    required bool pushIfLocalEmpty,
    required bool allowEmptyWipe,
  }) async {
    final portals = await IptvStore.load();
    if (portals.isEmpty) {
      if (!pushIfLocalEmpty) {
        debugPrint('[Sync] skip IPTV push — empty local cache (cloud is master)');
        return;
      }
      if (!allowEmptyWipe) {
        debugPrint(
          '[Sync] refuse empty IPTV replace — empty cache must not wipe cloud',
        );
        return;
      }
      await SyncService.instance.replaceUserIptvPortals(const []);
      return;
    }

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

    // Upserts failed entirely — do not delete cloud assignments.
    if (assignments.isEmpty) {
      debugPrint('[Sync] refuse IPTV replace — no portal ids resolved');
      return;
    }

    await SyncService.instance.replaceUserIptvPortals(assignments);
  }

  Future<bool> _pullAndApplyUserIptvPortals() async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await SyncService.instance.pullUserIptvPortals();
    } catch (e) {
      // Keep local inventory — never replace with [] on credential/RPC failure.
      debugPrint('[Sync] pullUserIptvPortals failed (local kept): $e');
      return false;
    }
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
    // Cloud → local cache only; never schedule a push that could race-wipe.
    await IptvStore.save(portals, scheduleSync: false);
    await IptvStore.saveFavorites(favoriteKeys, scheduleSync: false);
    return true;
  }

  Future<Map<String, dynamic>> exportPreferences() async {
    return {
      'play_source_torrent_enabled': await _settings
          .isPlaySourceTorrentEnabled(),
      'play_source_stremio_enabled': await _settings
          .isPlaySourceStremioEnabled(),
      'play_source_nuvio_enabled': await _settings.isPlaySourceNuvioEnabled(),
      'play_source_webstreaming_enabled': await _settings
          .isPlaySourceWebstreamingEnabled(),
      'simple_streaming_resolve_enabled': await _settings
          .isSimpleStreamingResolveEnabled(),
      'preferred_audio_lang': await _settings.getPreferredAudioLanguage(),
      'preferred_subtitle_lang': await _settings.getPreferredSubtitleLanguage(),
      'avoid_unsupported_audio': await _settings.getAvoidUnsupportedAudio(),
      'auto_next_episode': await _settings.getAutoNextEpisode(),
      'auto_skip_intro': await _settings.getAutoSkipIntro(),
      'iptv_epg_enabled': await _settings.isIptvEpgEnabled(),
      'max_playback_height': await _settings.getMaxPlaybackHeight(),
      'anime_title_language': await _settings.getAnimeTitleLanguage(),
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
    if (payload.containsKey('play_source_nuvio_enabled')) {
      await _settings.setPlaySourceNuvioEnabled(
        payload['play_source_nuvio_enabled'] as bool,
      );
    }
    if (payload.containsKey('play_source_webstreaming_enabled')) {
      await _settings.setPlaySourceWebstreamingEnabled(
        payload['play_source_webstreaming_enabled'] as bool,
      );
    }
    if (payload.containsKey('simple_streaming_resolve_enabled')) {
      await _settings.setSimpleStreamingResolveEnabled(
        payload['simple_streaming_resolve_enabled'] as bool,
      );
    }
    if (payload.containsKey('preferred_audio_lang')) {
      await _settings.setPreferredAudioLanguage(
        payload['preferred_audio_lang'] as String,
      );
    }
    if (payload.containsKey('preferred_subtitle_lang')) {
      await _settings.setPreferredSubtitleLanguage(
        payload['preferred_subtitle_lang'] as String,
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
    if (payload.containsKey('anime_title_language')) {
      await _settings.setAnimeTitleLanguage(
        payload['anime_title_language'] as String,
      );
    }
  }

  Future<Map<String, dynamic>> exportProviders() async {
    return {
      'stream_provider_order': await _settings.getStreamProviderOrder(),
      'anime_provider_order': await _settings.getAnimeProviderOrder(),
      'asian_drama_provider_order': await _settings
          .getAsianDramaProviderOrder(),
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

  /// Install / refresh manifests from cloud lean rows (`baseUrl` only).
  /// Same contract as [importNuvio] — cloud never stores full manifests.
  Future<void> importStremio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final remoteUrls = <String>{
      for (final raw in addons)
        if ((raw as Map)['baseUrl'] is String)
          ((raw)['baseUrl'] as String).trim(),
    }..removeWhere((u) => u.isEmpty);

    final current = await _settings.getStremioAddons();
    for (final addon in current) {
      final baseUrl = (addon['baseUrl'] as String?)?.trim() ?? '';
      if (baseUrl.isNotEmpty && !remoteUrls.contains(baseUrl)) {
        await _settings.removeStremioAddon(baseUrl);
      }
    }

    final stremio = StremioService();
    for (final raw in addons) {
      final lean = Map<String, dynamic>.from(raw as Map);
      final baseUrl = (lean['baseUrl'] as String?)?.trim() ?? '';
      if (baseUrl.isEmpty) continue;
      try {
        final fresh = await stremio.fetchManifest(baseUrl);
        if (fresh != null) {
          await _settings.saveStremioAddon(fresh);
          continue;
        }
      } catch (e) {
        debugPrint('[Sync] Stremio manifest fetch failed ($baseUrl): $e');
      }
      // Keep lean row so Settings still lists it; Sources hydrates later.
      await _settings.saveStremioAddon(lean);
    }
  }

  Future<Map<String, dynamic>> exportNuvio() async {
    return _exportNuvioCompact();
  }

  /// Install / refresh manifests from cloud; drop user addons not in remote.
  /// Built-in All-in-One is never removed even if omitted from the payload.
  Future<void> importNuvio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final remoteUrls = <String>{
      for (final raw in addons)
        if ((raw as Map)['manifestUrl'] is String)
          ((raw)['manifestUrl'] as String).trim(),
    }..removeWhere((u) => u.isEmpty);

    final current = await NuvioService.instance.listAddons();
    for (final addon in current) {
      if (NuvioService.isBundled(addon.manifestUrl)) continue;
      if (!remoteUrls.contains(addon.manifestUrl)) {
        try {
          await NuvioService.instance.remove(addon.manifestUrl);
        } catch (_) {}
      }
    }
    for (final url in remoteUrls) {
      try {
        await NuvioService.instance.refreshFromUrl(url);
      } catch (_) {
        try {
          await NuvioService.instance.install(url);
        } catch (e) {
          debugPrint('[Sync] Nuvio import failed ($url): $e');
        }
      }
    }
    await NuvioService.instance.ensureBundledInstalled();
  }
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

void schedulePreferencesSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainPreferences);

void scheduleProvidersSyncPush() {
  // Provider order is device-local — do not push to cloud.
}

void scheduleStremioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainStremio);

void scheduleNuvioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNuvio);

void scheduleNavigationSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNavigation);
