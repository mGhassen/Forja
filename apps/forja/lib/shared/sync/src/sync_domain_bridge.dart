import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/sync_service.dart';
import 'package:rust/rust.dart';

/// Export/import between local stores and lean `profile_settings.payload`.
///
/// **Cloud is master** for `profile_settings` and IPTV assignments. Local KV /
/// `IptvStore` are caches - intentional UI edits write the cache then push;
/// wipe / pull / defaults never push incomplete cache over cloud.
///
/// IPTV portals sync via `user_iptv_portals` / `iptv_portals` - never
/// `profile_settings`. M3U playlists are device-local only.
class SyncDomainBridge {
  SyncDomainBridge._();
  static final SyncDomainBridge instance = SyncDomainBridge._();

  /// Debounce key for portal assignment pushes (not profile_settings.iptv).
  static const _domainIptv = 'iptv';
  static const _domainPreferences = 'preferences';
  static const _domainStremio = 'stremio';
  static const _domainNuvio = 'nuvio';
  static const _domainForja = 'forja';
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
  /// Flushes **pending** domain edits only (same rule as [syncFromCloud] /
  /// issue 126). Never full-overlays lean domains — a stale TV nav cache must
  /// not rewrite cloud Features when switching profiles (or when nothing was
  /// pending).
  Future<void> prepareProfileSwitch() async {
    final pending = Set<String>.from(_pushTimers.keys);
    cancelPendingPushes();
    if (pending.isEmpty) return;
    await pushAllLocal(
      pushIptvIfLocalEmpty: false,
      allowEmptyStremioWipe: pending.contains(_domainStremio),
      allowEmptyNuvioWipe: pending.contains(_domainNuvio),
      allowEmptyForjaWipe: pending.contains(_domainForja),
      overlayDomains: pending,
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

  /// Fail-closed IPTV cache wipe for profile boundaries (issue 217).
  ///
  /// [IptvStore] is device-global. On profile switch / active-profile delete we
  /// must clear portals + passwords **before** cloud pull — never keep the prior
  /// profile's inventory when pull fails, times out, or continues early.
  /// Cache-only (`scheduleSync: false`); empty local must not push to cloud.
  Future<void> wipeLocalIptvInventoryForProfileBoundary({
    bool notify = true,
  }) async {
    _pushTimers.remove(_domainIptv)?.cancel();
    await IptvStore.save(const [], scheduleSync: false);
    await IptvStore.saveFavorites({}, scheduleSync: false);
    await IptvStore.clearLastPortalKey();
    if (notify) IptvStore.notifyListChanged();
  }

  /// Wipe synced local domains to platform defaults (no prior-profile bleed).
  ///
  /// Local KV is a device-global **cache**; every profile switch/create must
  /// reset before applying that profile's cloud payload. Never schedules a
  /// cloud push - empty/default cache must not overwrite cloud.
  ///
  /// When [notify] is false, UI listeners are not bumped mid-wipe (caller
  /// should notify once after the final cloud import so the shell does not
  /// flash platform-default nav tabs).
  Future<void> resetSyncedLocalToPlatformDefaults({
    bool clearIptv = true,
    bool notify = true,
  }) async {
    // Cache-only wipe - cancel any debounced push that would upload defaults.
    cancelPendingPushes();
    final defaults = PlatformDefaults.forProfile(
      SettingsService.platformProfile,
    );
    await importPreferences({
      'play_source_torrent_enabled': defaults.playSourceTorrent,
      'play_source_stremio_enabled': defaults.playSourceStremio,
      'play_source_nuvio_enabled': defaults.playSourceNuvio,
      'play_source_webstreaming_enabled': defaults.playSourceWebstreaming,
      'play_source_engine_auto_start': true,
      'preferred_audio_lang': 'None',
      'preferred_subtitle_lang': 'English',
      'avoid_unsupported_audio': true,
      'auto_next_episode': true,
      'auto_skip_intro': false,
      'content_warnings': true,
      'iptv_epg_enabled': defaults.iptvEpgEnabled,
      'max_playback_height': 2160,
    });
    await _settings.setNavbarConfig(
      List<String>.from(defaults.visibleNavIds),
      notify: notify,
    );
    await _settings.setDefaultNavTab('home');

    final addons = await _settings.getStremioAddons();
    for (final addon in addons) {
      final baseUrl = (addon['baseUrl'] as String?)?.trim() ?? '';
      if (baseUrl.isNotEmpty) {
        await _settings.removeStremioAddon(baseUrl, notify: notify);
      }
    }

    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      if (PluginRegistry.isLegacyAssetPack(pack.sourceUrl)) continue;
      try {
        await EngineService.instance.removePack(
          pack.sourceUrl,
          purgeDisk: false,
        );
      } catch (_) {}
    }

    final nuvioAddons = await NuvioService.instance.listAddons();
    for (final addon in nuvioAddons) {
      if (NuvioService.isBundled(addon.manifestUrl)) continue;
      try {
        await NuvioService.instance.remove(
          addon.manifestUrl,
          purgeScripts: false,
        );
      } catch (_) {}
    }

    if (clearIptv) {
      // Local cache only - never schedule a cloud push from a wipe.
      await IptvStore.save(const [], scheduleSync: false);
      await IptvStore.saveFavorites({}, scheduleSync: false);
      await IptvStore.clearLastPortalKey();
      if (notify) IptvStore.notifyListChanged();
    }
  }

  /// After creating a profile: local defaults + push so cloud is not `{}` / prior prefs.
  Future<void> seedNewProfileDefaults() async {
    cancelPendingPushes();
    await resetSyncedLocalToPlatformDefaults(clearIptv: true);
    // New profile has no assignments yet - settings only; skip empty IPTV wipe.
    await pushAllLocal(pushIptvIfLocalEmpty: false);
  }

  DateTime? _lastCloudPullAt;
  Future<void>? _cloudPullInFlight;
  static const _cloudPullMinInterval = Duration(seconds: 15);

  /// Cloud → local cache. Flush pending local domain pushes first so an in-flight
  /// edit is not lost, then [pullAndMergeAll]. Debounced unless [force].
  ///
  /// Call on side-nav tab select, window focus / app resume. Not on a timer.
  Future<void> syncFromCloud({bool force = false}) async {
    if (!SyncService.instance.isSignedIn) return;
    final now = DateTime.now();
    if (!force &&
        _lastCloudPullAt != null &&
        now.difference(_lastCloudPullAt!) < _cloudPullMinInterval) {
      return;
    }
    final inflight = _cloudPullInFlight;
    if (inflight != null) return inflight;

    late final Future<void> run;
    run = () async {
      try {
        final pending = Set<String>.from(_pushTimers.keys);
        cancelPendingPushes();
        if (pending.isNotEmpty) {
          await pushAllLocal(
            pushIptvIfLocalEmpty: false,
            allowEmptyStremioWipe: pending.contains(_domainStremio),
            allowEmptyNuvioWipe: pending.contains(_domainNuvio),
            allowEmptyForjaWipe: pending.contains(_domainForja),
            // Only flush domains that were pending — never overlay stale
            // navigation / playback from an unrelated edit (issue 126).
            overlayDomains: pending,
          );
        }
        await pullAndMergeAll(resetLocalFirst: false);
        _lastCloudPullAt = DateTime.now();
      } catch (e) {
        debugPrint('[Sync] syncFromCloud failed: $e');
      } finally {
        if (identical(_cloudPullInFlight, run)) {
          _cloudPullInFlight = null;
        }
      }
    }();
    _cloudPullInFlight = run;
    return run;
  }

  Future<void> pullAndMergeAll({bool resetLocalFirst = true}) async {
    if (!SyncService.instance.isSignedIn) {
      AccountFeatures.instance.clear();
      return;
    }
    // Profile switch: wipe IPTV first so a failed/slow settings pull cannot
    // leave profile A's portals visible under profile B (issue 217).
    if (resetLocalFirst) {
      await wipeLocalIptvInventoryForProfileBoundary();
    }
    await SyncService.instance.pullAccountFeatures();
    final Map<String, dynamic>? remote;
    try {
      remote = await SyncService.instance.pullProfileSettings();
    } catch (e) {
      // Failed pull ≠ missing row. Keep lean local cache; never seed+push
      // defaults over a populated cloud row (Android TV JWT / network —
      // issue 126). IPTV already wiped when [resetLocalFirst] (issue 217).
      debugPrint('[Sync] pullAndMergeAll aborted (keep lean local): $e');
      return;
    }
    if (remote == null) {
      // Confirmed missing row - seed defaults under the active profile.
      await seedNewProfileDefaults();
      return;
    }
    await _applyLeanPayload(remote, resetLocalFirst: resetLocalFirst);
    // Lazy IPTV: only pull portals when this profile shows the IPTV tab.
    // Otherwise keep the boundary wipe (already empty when resetLocalFirst).
    final nav = await _settings.getNavbarConfig();
    if (nav.contains('iptv')) {
      await _pullAndApplyUserIptvPortals();
    } else {
      debugPrint('[Sync] IPTV pull skip (iptv tab not visible)');
      await wipeLocalIptvInventoryForProfileBoundary();
    }
    // Empty `{}` insert left cloud hollow - backfill settings once (not IPTV).
    if (remote.isEmpty) {
      await pushAllLocal(pushIptvIfLocalEmpty: false);
    }
  }

  /// Pull cloud portal assignments into local IPTV store (after deal / remote
  /// edit / portal panel open). Merges: keeps existing local probe fields,
  /// appends new assignments, drops unassigned. Notifies only when inventory
  /// actually changed. Returns `false` when the pull failed and local was kept.
  Future<bool> pullIptvPortalsFromCloud() async {
    if (!SyncService.instance.isSignedIn) return false;
    return _pullAndApplyUserIptvPortals();
  }

  /// Push lean settings + IPTV. Cloud is master:
  /// - Merges local cache into the existing cloud row (never replaces with a
  ///   partial local export that drops remote keys).
  /// - [overlayDomains] null = full overlay (new-profile seed / empty-row
  ///   backfill). Non-null = only those domains (debounced UI edits **and**
  ///   [prepareProfileSwitch] flush). A playback-only / empty-pending switch
  ///   cannot rewrite cloud navigation (issue 126). Navigation shrink from a
  ///   thin device cache is refused unless `_domainNavigation` is in the
  ///   overlay set (Settings → Features).
  /// - Empty local Stremio/Nuvio/Forja never deletes cloud unless
  ///   [allowEmptyStremioWipe] / [allowEmptyNuvioWipe] / [allowEmptyForjaWipe]
  ///   (that domain's edit).
  /// - Empty IPTV cache never deletes assignments unless [allowEmptyIptvWipe].
  /// - Local IPTV shorter than cloud never replaces unless [allowIptvShrink]
  ///   (intentional delete) or [allowEmptyIptvWipe] (clear-all).
  /// [pushIptvIfLocalEmpty] false skips IPTV entirely when local is empty
  /// (profile switch / seed).
  Future<void> pushAllLocal({
    bool pushIptvIfLocalEmpty = true,
    bool allowEmptyIptvWipe = false,
    bool allowIptvShrink = false,
    bool allowEmptyStremioWipe = false,
    bool allowEmptyNuvioWipe = false,
    bool allowEmptyForjaWipe = false,
    Set<String>? overlayDomains,
  }) async {
    if (!SyncService.instance.isSignedIn) return;
    final payload = await _buildMergedCloudPayload(
      allowEmptyStremioWipe: allowEmptyStremioWipe,
      allowEmptyNuvioWipe: allowEmptyNuvioWipe,
      allowEmptyForjaWipe: allowEmptyForjaWipe,
      overlayDomains: overlayDomains,
    );
    if (payload == null) {
      debugPrint('[Sync] pushAllLocal skipped (cloud pull failed)');
      return;
    }
    await SyncService.instance.pushProfileSettings(payload);
    final pushIptv = overlayDomains == null ||
        overlayDomains.contains(_domainIptv);
    if (pushIptv) {
      await _pushUserIptvPortals(
        pushIfLocalEmpty: pushIptvIfLocalEmpty,
        allowEmptyWipe: allowEmptyIptvWipe,
        allowShrink: allowIptvShrink,
      );
    }
  }

  /// User intentionally cleared every portal - sync empty assignments to cloud.
  Future<void> pushEmptyIptvInventory() async {
    if (!SyncService.instance.isSignedIn) return;
    await _pushUserIptvPortals(
      pushIfLocalEmpty: true,
      allowEmptyWipe: true,
      allowShrink: true,
    );
  }

  /// User deleted one or more portals - allow cloud assignment count to drop.
  Future<void> pushIptvInventoryAfterDelete() async {
    if (!SyncService.instance.isSignedIn) return;
    await _pushUserIptvPortals(
      pushIfLocalEmpty: true,
      allowEmptyWipe: false,
      allowShrink: true,
    );
  }

  void schedulePush(String domain) {
    if (!SyncService.instance.isSignedIn) return;
    _pushTimers[domain]?.cancel();
    _pushTimers[domain] = Timer(const Duration(seconds: 3), () {
      // Debounced user edits - overlay only this domain onto cloud.
      // IPTV: never shrink cloud from a thin local cache (issue 118).
      // Navigation / playback: never rewrite the other from a stale cache
      // (issue 126).
      unawaited(
        pushAllLocal(
          pushIptvIfLocalEmpty: false,
          allowIptvShrink: false,
          allowEmptyStremioWipe: domain == _domainStremio,
          allowEmptyNuvioWipe: domain == _domainNuvio,
          allowEmptyForjaWipe: domain == _domainForja,
          overlayDomains: {domain},
        ),
      );
    });
  }

  /// True when [localNav] drops any tab id that [remoteNav] still has.
  @visibleForTesting
  static bool navigationWouldShrinkCloud(
    Map<String, dynamic>? remoteNav,
    Map<String, dynamic> localNav,
  ) {
    final remoteIds = _navVisibleIds(remoteNav);
    if (remoteIds.isEmpty) return false;
    final localSet = _navVisibleIds(localNav).toSet();
    return remoteIds.any((id) => !localSet.contains(id));
  }

  static List<String> _navVisibleIds(Map<String, dynamic>? nav) {
    final raw = nav?['visibleIds'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((id) => id.isNotEmpty).toList();
  }

  /// Local cache export for domains we own. Omitted keys mean "unchanged on
  /// cloud" - see [_buildMergedCloudPayload].
  Future<Map<String, dynamic>> _buildLeanPayload() async {
    final out = <String, dynamic>{};

    // Full playback prefs (incl. play_source_*) - never strip defaults.
    out['playback'] = await exportPreferences();

    final stremio = await _exportStremioCompact();
    final nuvio = await _exportNuvioCompact();
    final forja = await _exportForjaCompact();
    final connected = <String, dynamic>{};
    if (stremio.isNotEmpty) connected['stremio'] = stremio;
    if (nuvio.isNotEmpty) connected['nuvio'] = nuvio;
    if (forja.isNotEmpty) connected['forja'] = forja;
    if (connected.isNotEmpty) out['connectedServices'] = connected;

    final navigation = await _exportNavigationCompact();
    if (navigation.isNotEmpty) out['navigation'] = navigation;

    // Never write iptv into profile_settings - portals use user_iptv_portals;
    // M3U stays device-local.
    return out;
  }

  /// Cloud SoT: start from remote row, overlay intentional local cache.
  ///
  /// Returns `null` when the cloud pull failed — caller must not upsert
  /// (would replace cloud with a local-only payload).
  ///
  /// [overlayDomains] null overlays every lean domain. Otherwise only the
  /// listed domains (preferences → playback, navigation, stremio, nuvio, forja).
  Future<Map<String, dynamic>?> _buildMergedCloudPayload({
    required bool allowEmptyStremioWipe,
    required bool allowEmptyNuvioWipe,
    required bool allowEmptyForjaWipe,
    Set<String>? overlayDomains,
  }) async {
    final Map<String, dynamic> remote;
    try {
      remote = await SyncService.instance.pullProfileSettings() ?? {};
    } catch (e) {
      debugPrint('[Sync] merge aborted (cloud pull failed): $e');
      return null;
    }
    final local = await _buildLeanPayload();
    final next = Map<String, dynamic>.from(remote);
    final overlayAll = overlayDomains == null;
    final overlayPlayback =
        overlayAll || overlayDomains.contains(_domainPreferences);
    final overlayNavigation =
        overlayAll || overlayDomains.contains(_domainNavigation);
    final overlayStremio =
        overlayAll || overlayDomains.contains(_domainStremio);
    final overlayNuvio = overlayAll || overlayDomains.contains(_domainNuvio);
    final overlayForja = overlayAll || overlayDomains.contains(_domainForja);

    if (overlayPlayback) {
      final playback = local['playback'];
      if (playback is Map) {
        next['playback'] = Map<String, dynamic>.from(playback);
      }
    }

    if (overlayNavigation) {
      final navigation = local['navigation'];
      if (navigation is Map && navigation.isNotEmpty) {
        final localNav = Map<String, dynamic>.from(navigation);
        final remoteNav = remote['navigation'] is Map
            ? Map<String, dynamic>.from(remote['navigation'] as Map)
            : null;
        // Features UI schedules `_domainNavigation` — allow intentional hide.
        // Full overlay / profile-switch flush / playback-only must never drop
        // cloud tabs from a thin device cache (issue 126).
        final intentionalNavEdit =
            overlayDomains != null &&
            overlayDomains.contains(_domainNavigation);
        if (!intentionalNavEdit &&
            navigationWouldShrinkCloud(remoteNav, localNav)) {
          debugPrint(
            '[Sync] refuse navigation shrink from non-Features push',
          );
        } else {
          next['navigation'] = localNav;
        }
      }
    }

    final remoteConnected = remote['connectedServices'] is Map
        ? Map<String, dynamic>.from(remote['connectedServices'] as Map)
        : <String, dynamic>{};
    final localConnected = local['connectedServices'] is Map
        ? Map<String, dynamic>.from(local['connectedServices'] as Map)
        : <String, dynamic>{};
    final connected = Map<String, dynamic>.from(remoteConnected);

    if (overlayStremio) {
      if (localConnected.containsKey('stremio')) {
        connected['stremio'] = localConnected['stremio'];
      } else if (allowEmptyStremioWipe) {
        connected.remove('stremio');
      }
    }

    if (overlayNuvio) {
      if (localConnected.containsKey('nuvio')) {
        connected['nuvio'] = localConnected['nuvio'];
      } else if (allowEmptyNuvioWipe) {
        connected.remove('nuvio');
      }
    }

    if (overlayForja) {
      if (localConnected.containsKey('forja')) {
        connected['forja'] = localConnected['forja'];
      } else if (allowEmptyForjaWipe) {
        connected.remove('forja');
      }
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

  Future<void> _applyLeanPayload(
    Map<String, dynamic> payload, {
    required bool resetLocalFirst,
  }) async {
    // Profile switch: wipe first so missing lean keys cannot keep prior profile.
    // Focus/resume refresh: apply cloud over the current cache — do not flash
    // platform-default nav (all tabs) before the real visibleIds land.
    if (resetLocalFirst) {
      // IPTV already wiped at pullAndMergeAll entry (issue 217). clearIptv
      // true is idempotent and covers any caller that reset without that wipe.
      await resetSyncedLocalToPlatformDefaults(
        clearIptv: true,
        notify: false,
      );
    }

    final playback = payload['playback'];
    if (playback is Map) {
      await importPreferences(Map<String, dynamic>.from(playback));
    }

    final connected = payload['connectedServices'];
    if (connected is Map) {
      // Provider order is device-local - ignore legacy cloud providers keys.
      final stremio = connected['stremio'];
      if (stremio is Map) {
        await importStremio(Map<String, dynamic>.from(stremio));
      }
      final nuvio = connected['nuvio'];
      if (nuvio is Map) {
        await importNuvio(Map<String, dynamic>.from(nuvio));
      }
      final forja = connected['forja'];
      if (forja is Map) {
        await importForja(Map<String, dynamic>.from(forja));
      }
    }

    final navigation = payload['navigation'];
    if (navigation is Map) {
      await _importNavigation(Map<String, dynamic>.from(navigation));
    } else if (resetLocalFirst) {
      // Reset left platform-default nav without notifying; publish once.
      SettingsService.navbarChangeNotifier.value++;
    }

    // Ignore legacy payload.iptv (M3U / portals) - tables + local store own IPTV.
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
      final features = StremioAddonFeatures.read(raw);
      row['features'] = features;
      if (!StremioAddonFeatures.isEnabled(raw)) {
        row['enabled'] = false;
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

  Future<Map<String, dynamic>> _exportForjaCompact() async {
    final packs = await EngineService.instance.listPacks();
    if (packs.isEmpty) return {};
    final lean = <Map<String, dynamic>>[];
    for (final pack in packs) {
      final manifestUrl = pack.sourceUrl.trim();
      if (manifestUrl.isEmpty) continue;
      if (PluginRegistry.isLegacyAssetPack(manifestUrl)) continue;
      final row = <String, dynamic>{'manifestUrl': manifestUrl};
      final name = pack.name.trim();
      if (name.isNotEmpty) row['name'] = name;
      final version = pack.version.trim();
      if (version.isNotEmpty) row['version'] = version;
      lean.add(row);
    }
    return lean.isEmpty ? {} : {'packs': lean};
  }

  Future<Map<String, dynamic>> _exportNavigationCompact() async {
    final ids = await _settings.getNavbarConfig();
    final tabOrder = await _settings.getNavbarTabOrder();
    final defaultTab = await _settings.getDefaultNavTab();
    final out = <String, dynamic>{};
    if (ids.isNotEmpty) out['visibleIds'] = ids;
    if (tabOrder.isNotEmpty) out['tabOrder'] = tabOrder;
    if (defaultTab.trim().isNotEmpty) {
      out['defaultTab'] = defaultTab.trim();
    }
    return out;
  }

  Future<void> _importNavigation(Map<String, dynamic> payload) async {
    if (payload['visibleIds'] is List) {
      final tabOrder = payload['tabOrder'] is List
          ? (payload['tabOrder'] as List).cast<String>()
          : null;
      await _settings.setNavbarConfig(
        (payload['visibleIds'] as List).cast<String>(),
        tabOrder: tabOrder,
      );
    }
    if (payload['defaultTab'] is String) {
      await _settings.setDefaultNavTab(payload['defaultTab'] as String);
    }
  }

  Future<void> _pushUserIptvPortals({
    required bool pushIfLocalEmpty,
    required bool allowEmptyWipe,
    required bool allowShrink,
  }) async {
    final portals = await IptvStore.load();
    if (portals.isEmpty) {
      if (!pushIfLocalEmpty) {
        debugPrint('[Sync] skip IPTV push - empty local cache (cloud is master)');
        return;
      }
      if (!allowEmptyWipe) {
        debugPrint(
          '[Sync] refuse empty IPTV replace - empty cache must not wipe cloud',
        );
        return;
      }
      await SyncService.instance.replaceUserIptvPortals(
        const [],
        allowShrink: true,
      );
      return;
    }

    final cloudCount = await SyncService.instance.countUserIptvPortals();
    if (cloudCount < 0) {
      debugPrint('[Sync] refuse IPTV replace - cloud count unavailable');
      return;
    }
    // Thin local cache must never replace a larger cloud inventory (096 / 118).
    if (!allowEmptyWipe && !allowShrink && cloudCount > portals.length) {
      debugPrint(
        '[Sync] refuse IPTV shrink - local ${portals.length} < cloud $cloudCount',
      );
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
        platform: v.portal.platform.wire,
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

    // Upserts failed entirely - do not delete cloud assignments.
    if (assignments.isEmpty) {
      debugPrint('[Sync] refuse IPTV replace - no portal ids resolved');
      return;
    }
    // Partial upsert must never over-shrink (even intentional delete).
    if (assignments.length < portals.length) {
      debugPrint(
        '[Sync] refuse IPTV replace - resolved ${assignments.length} of '
        '${portals.length} local portals',
      );
      return;
    }
    if (!allowEmptyWipe &&
        !allowShrink &&
        cloudCount > assignments.length) {
      debugPrint(
        '[Sync] refuse IPTV shrink after upsert - '
        'resolved ${assignments.length} < cloud $cloudCount',
      );
      return;
    }

    await SyncService.instance.replaceUserIptvPortals(
      assignments,
      allowShrink: allowEmptyWipe || allowShrink,
    );
  }

  Future<bool> _pullAndApplyUserIptvPortals() async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await SyncService.instance.pullUserIptvPortals();
    } catch (e) {
      // Focus/resume re-pull: keep whatever is already in the cache for this
      // profile. Profile-switch paths wipe first (issue 217), so failure stays
      // empty — never rehydrate the previous profile's portals.
      debugPrint('[Sync] pullUserIptvPortals failed (local kept): $e');
      return false;
    }
    final local = await IptvStore.load();
    final localByKey = {for (final v in local) v.key: v};
    final localFav = await IptvStore.loadFavorites();

    // Cloud is master for *which* portals are assigned. Existing local rows
    // keep probe fields (name / seats / expiry) — only append new keys and
    // drop unassigned; never wipe local account probes on a re-pull.
    final portals = <VerifiedPortal>[];
    final favoriteKeys = <String>{};
    for (final row in rows) {
      final portal = row['portal'];
      if (portal is! Map) continue;
      final g = Map<String, dynamic>.from(portal);
      final url = g['url'] as String? ?? '';
      final username = g['username'] as String? ?? '';
      final password = g['password'] as String? ?? '';
      final cloudLabel = (row['portal_name'] as String?)?.trim() ?? '';
      final cloudPortal = IptvPortal(
        url: url,
        username: username,
        password: password,
        source: g['source'] as String? ?? '',
        platform: IptvPortalPlatform.fromString(g['platform'] as String?),
      );
      final key = cloudPortal.key;
      final existing = localByKey[key];
      if (existing != null) {
        portals.add(
          cloudLabel.isNotEmpty && cloudLabel != existing.label
              ? existing.withLabel(cloudLabel)
              : existing,
        );
      } else {
        portals.add(
          VerifiedPortal(
            portal: cloudPortal,
            label: cloudLabel,
            name: '',
            expiry: g['expiry'] as String? ?? '',
            maxConnections: g['max_connections'] as String? ?? '1',
            activeConnections: '0',
          ),
        );
      }
      if (row['favorite'] == true) {
        favoriteKeys.add(key);
      }
    }

    final localKeys = local.map((v) => v.key).toSet();
    final nextKeys = portals.map((v) => v.key).toSet();
    final keysSame =
        localKeys.length == nextKeys.length && localKeys.containsAll(nextKeys);
    final favSame = localFav.length == favoriteKeys.length &&
        localFav.containsAll(favoriteKeys);
    var labelChanged = false;
    if (keysSame) {
      for (final p in portals) {
        final prev = localByKey[p.key];
        if (prev != null && prev.label != p.label) {
          labelChanged = true;
          break;
        }
      }
    }
    if (keysSame && favSame && !labelChanged) return true;

    // Cloud → local cache only; never schedule a push that could race-wipe.
    await IptvStore.save(portals, scheduleSync: false);
    await IptvStore.saveFavorites(favoriteKeys, scheduleSync: false);
    IptvStore.notifyListChanged();
    return true;
  }

  Future<Map<String, dynamic>> exportPreferences() async {
    return {
      // Stored (not effective) so Android TV does not wipe desktop play sources.
      'play_source_torrent_enabled': await _settings.isPlaySourceTorrentStored(),
      'play_source_stremio_enabled': await _settings.isPlaySourceStremioStored(),
      'play_source_nuvio_enabled': await _settings.isPlaySourceNuvioStored(),
      'play_source_webstreaming_enabled': await _settings
          .isPlaySourceWebstreamingEnabled(),
      'play_source_engine_auto_start': await _settings
          .isPlaySourceEngineAutoStartEnabled(),
      'simple_streaming_resolve_enabled': await _settings
          .isSimpleStreamingResolveEnabled(),
      'preferred_audio_lang': await _settings.getPreferredAudioLanguage(),
      'preferred_subtitle_lang': await _settings.getPreferredSubtitleLanguage(),
      'avoid_unsupported_audio': await _settings.getAvoidUnsupportedAudio(),
      'auto_next_episode': await _settings.getAutoNextEpisode(),
      'auto_skip_intro': await _settings.getAutoSkipIntro(),
      'content_warnings': await _settings.getContentWarnings(),
      'auto_pip_on_desktop_switch': await _settings.getAutoPipOnDesktopSwitch(),
      // play_in_background is device-local (desktop on / phone·TV off).
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
    if (payload.containsKey('play_source_engine_auto_start')) {
      await _settings.setPlaySourceEngineAutoStartEnabled(
        payload['play_source_engine_auto_start'] as bool,
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
    if (payload.containsKey('content_warnings')) {
      await _settings.setContentWarnings(payload['content_warnings'] as bool);
    }
    if (payload.containsKey('auto_pip_on_desktop_switch')) {
      await _settings.setAutoPipOnDesktopSwitch(
        payload['auto_pip_on_desktop_switch'] as bool,
      );
    }
    // play_in_background ignored — device-local (issue 159).
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

  /// Apply cloud lean rows (`baseUrl` + optional name/features). **No network** —
  /// [StremioService.hydrateInstalledAddons] fills manifests on first Stremio
  /// use (Details / Home / Settings). Tab sync / cold pull must not hit addon
  /// hosts while the user is in IPTV or anywhere else.
  Future<void> importStremio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final remoteByBase = <String, Map<String, dynamic>>{};
    for (final raw in addons) {
      final lean = Map<String, dynamic>.from(raw as Map);
      final baseUrl = SettingsService.normalizeStremioAddonBaseUrl(
        lean['baseUrl']?.toString() ?? '',
      );
      if (baseUrl.isEmpty) continue;
      lean['baseUrl'] = baseUrl;
      remoteByBase[baseUrl] = lean;
    }

    final current = await _settings.getStremioAddons();
    final localByBase = <String, Map<String, dynamic>>{};
    for (final addon in current) {
      final base = SettingsService.normalizeStremioAddonBaseUrl(
        addon['baseUrl']?.toString() ?? '',
      );
      if (base.isEmpty) continue;
      localByBase[base] = Map<String, dynamic>.from(addon);
    }

    var changed = false;
    for (final base in localByBase.keys.toList()) {
      if (remoteByBase.containsKey(base)) continue;
      await _settings.removeStremioAddon(base, notify: false);
      localByBase.remove(base);
      changed = true;
    }

    for (final entry in remoteByBase.entries) {
      final baseUrl = entry.key;
      final lean = entry.value;
      final syncedFeatures = lean['features'] is List
          ? StremioAddonFeatures.normalize(lean['features'])
          : null;

      final existing = localByBase[baseUrl];
      if (existing != null && _stremioHasManifestResources(existing)) {
        // Keep hydrated local manifest; overlay synced feature targets + meta.
        if (syncedFeatures != null) {
          existing['features'] = syncedFeatures;
        }
        if (lean.containsKey('enabled')) {
          existing['enabled'] = StremioAddonFeatures.normalizeEnabled(
            lean['enabled'],
          );
        }
        final name = (lean['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) existing['name'] = name;
        final description = (lean['description'] as String?)?.trim();
        if (description != null && description.isNotEmpty) {
          existing['description'] = description;
        }
        await _settings.saveStremioAddon(existing, notify: false);
        changed = true;
        continue;
      }

      if (syncedFeatures != null) lean['features'] = syncedFeatures;
      if (lean.containsKey('enabled')) {
        lean['enabled'] = StremioAddonFeatures.normalizeEnabled(lean['enabled']);
      }
      await _settings.saveStremioAddon(lean, notify: false);
      changed = true;
    }

    if (changed) SettingsService.addonChangeNotifier.value++;
  }

  static bool _stremioHasManifestResources(Map<String, dynamic> addon) {
    final manifest = addon['manifest'];
    if (manifest is! Map) return false;
    final resources = manifest['resources'];
    return resources is List && resources.isNotEmpty;
  }

  Future<Map<String, dynamic>> exportNuvio() async {
    return _exportNuvioCompact();
  }

  /// Apply cloud lean rows (`manifestUrl` + optional name). **No network** —
  /// scrapers land only after user install in Settings (never auto-hydrate).
  Future<void> importNuvio(Map<String, dynamic> payload) async {
    final addons = payload['addons'] as List? ?? const [];
    final rows = <Map<String, dynamic>>[
      for (final raw in addons)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    await NuvioService.instance.applyLeanManifestUrls(rows);
  }

  Future<Map<String, dynamic>> exportForja() async {
    return _exportForjaCompact();
  }

  /// Apply cloud lean rows (`manifestUrl` + optional name). **No network** —
  /// then [promptPendingPackInstalls] asks before any download.
  /// This is the only auto path that offers pack downloads (after cloud sync).
  Future<void> importForja(Map<String, dynamic> payload) async {
    final packs = payload['packs'] as List? ?? const [];
    final rows = <Map<String, dynamic>>[
      for (final raw in packs)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    await EngineService.instance.applyLeanManifestUrls(rows);
    await PluginInstallCoordinator.instance.promptPendingPackInstalls();
  }
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

void schedulePreferencesSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainPreferences);

void scheduleProvidersSyncPush() {
  // Provider order is device-local - do not push to cloud.
}

void scheduleStremioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainStremio);

void scheduleNuvioSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNuvio);

void scheduleForjaSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainForja);

void scheduleNavigationSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNavigation);
