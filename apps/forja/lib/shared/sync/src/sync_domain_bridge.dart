import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/shared/nuvio/nuvio.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/src/account_features.dart';
import 'package:forja/shared/sync/src/packs_onboarding_store.dart';
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

  /// Bumped when Features / Addons schedules a navigation push. Cleared to match
  /// [_navigationSyncedGen] after a successful navigation overlay push.
  /// Pulls skip applying cloud nav while these differ so a stale empty
  /// `visibleIds` cannot flip Home (etc.) off before the local edit lands
  /// (issue 221).
  int _navigationLocalGen = 0;
  int _navigationSyncedGen = 0;

  /// Same race as nav for RFC-086 `addon_feature_*` prefs (issue 224): Addons
  /// opens with `syncFromCloud(force: true)` while preferences push was
  /// debounced 3s — soft pull re-applied cloud `false` and snapped IPTV /
  /// Live Sports off (Features inventory empty).
  int _addonFeatureLocalGen = 0;
  int _addonFeatureSyncedGen = 0;

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
    _navigationLocalGen = 0;
    _navigationSyncedGen = 0;
    _addonFeatureLocalGen = 0;
    _addonFeatureSyncedGen = 0;
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
      'addon_feature_iptv': false,
      'addon_feature_live_matches': false,
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
    await PacksOnboardingStore.clearLocalForActiveProfile();

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
        // Do NOT auto-flush dirty navigation here — a thin/empty ATV cache
        // with intentional overlay would wipe richer cloud Features (224).
        // [_applyLeanPayload] takes cloud when dirty local would shrink it.
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
    // Snapshot so a Features/Addons edit mid-pull cannot be overwritten by
    // the stale remote payload we are about to apply (224).
    final navGenAtFetch = _navigationLocalGen;
    final addonFeatureGenAtFetch = _addonFeatureLocalGen;
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
    await _applyLeanPayload(
      remote,
      resetLocalFirst: resetLocalFirst,
      navGenAtFetch: navGenAtFetch,
      addonFeatureGenAtFetch: addonFeatureGenAtFetch,
    );
    // Lazy IPTV: only pull portals when this profile shows the IPTV tab.
    // Otherwise keep the boundary wipe (already empty when resetLocalFirst).
    final nav = await _settings.getNavbarConfig();
    if (nav.contains('iptv')) {
      await _pullAndApplyUserIptvPortals();
    } else {
      // No IPTV tab — skip portal pull; clear stale portals for this profile.
      // (Not a Features/Home failure — Home lives in navigation.visibleIds.)
      await wipeLocalIptvInventoryForProfileBoundary();
    }
    // Empty `{}` insert left cloud hollow - backfill settings only when this
    // soft pull did not leave a newer local Features edit unsynced.
    if (remote.isEmpty && _navigationLocalGen == _navigationSyncedGen) {
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
    final navGenAtStart = _navigationLocalGen;
    final addonFeatureGenAtStart = _addonFeatureLocalGen;
    final overlayNav = overlayDomains == null ||
        overlayDomains.contains(_domainNavigation);
    final overlayPrefs = overlayDomains == null ||
        overlayDomains.contains(_domainPreferences);
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
    if (overlayNav && navGenAtStart == _navigationLocalGen) {
      _navigationSyncedGen = navGenAtStart;
    }
    if (overlayPrefs && addonFeatureGenAtStart == _addonFeatureLocalGen) {
      _addonFeatureSyncedGen = addonFeatureGenAtStart;
    }
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

  /// Mark Features/Addons nav dirty before KV write finishes so a concurrent
  /// soft pull cannot apply empty cloud over a just-enabled IPTV tab (224).
  void noteNavigationDirty() {
    if (_navigationLocalGen == _navigationSyncedGen) {
      _navigationLocalGen++;
    }
  }

  /// Mark Addons IPTV / Live Sports feature flags dirty before KV write so a
  /// concurrent Addons soft pull cannot demote them from stale cloud (224).
  void noteAddonFeaturesDirty() {
    if (_addonFeatureLocalGen == _addonFeatureSyncedGen) {
      _addonFeatureLocalGen++;
    }
  }

  /// Schedules (or immediately runs) a domain overlay push.
  ///
  /// Navigation / Forja / pending addon-feature prefs return after the upsert
  /// finishes so callers can await before a soft pull (Addons / Features —
  /// issue 221 / 224).
  Future<void> schedulePush(String domain) async {
    if (!SyncService.instance.isSignedIn) return;
    final prefsNeedImmediate = domain == _domainPreferences &&
        _addonFeatureLocalGen != _addonFeatureSyncedGen;
    // Features nav + Forja pack membership + pending addon_feature_* prefs:
    // push immediately so soft pulls cannot wipe a just-enabled IPTV/Live
    // (issue 221 / 224).
    if (domain == _domainNavigation ||
        domain == _domainForja ||
        prefsNeedImmediate) {
      if (domain == _domainNavigation) {
        noteNavigationDirty();
      }
      _pushTimers.remove(domain)?.cancel();
      await pushAllLocal(
        pushIptvIfLocalEmpty: false,
        allowIptvShrink: false,
        allowEmptyForjaWipe: domain == _domainForja,
        overlayDomains: {domain},
      );
      return;
    }
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

  /// Onboarding Skip / Install complete — set cloud `onboarded` without
  /// wiping remote `packs[]` when this device has an empty pack index.
  void scheduleOnboardedPush() {
    if (!SyncService.instance.isSignedIn) return;
    _pushTimers[_domainForja]?.cancel();
    _pushTimers[_domainForja] = Timer(const Duration(seconds: 1), () {
      unawaited(
        pushAllLocal(
          pushIptvIfLocalEmpty: false,
          allowIptvShrink: false,
          allowEmptyForjaWipe: false,
          overlayDomains: {_domainForja},
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

  /// True when [remoteNav] drops any tab id that [localNav] still has.
  /// Kept for unit tests / diagnostics. Soft pulls do **not** use this to
  /// block cloud apply — that fought intentional web Features clears (221).
  @visibleForTesting
  static bool navigationWouldShrinkLocal(
    Map<String, dynamic> localNav,
    Map<String, dynamic>? remoteNav,
  ) {
    final localIds = _navVisibleIds(localNav);
    if (localIds.isEmpty) return false;
    final remoteSet = _navVisibleIds(remoteNav).toSet();
    return localIds.any((id) => !remoteSet.contains(id));
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
        final localForja =
            Map<String, dynamic>.from(localConnected['forja'] as Map);
        final remoteForja = remoteConnected['forja'] is Map
            ? Map<String, dynamic>.from(remoteConnected['forja'] as Map)
            : <String, dynamic>{};
        final localPacks = localForja['packs'];
        final remotePacks = remoteForja['packs'];
        final localPacksEmpty = localPacks is! List || localPacks.isEmpty;
        final remoteHasPacks =
            remotePacks is List && remotePacks.isNotEmpty;
        if (localPacksEmpty && remoteHasPacks && !allowEmptyForjaWipe) {
          // Onboarding Skip / onboarded-only push — keep cloud pack membership.
          final merged = Map<String, dynamic>.from(remoteForja);
          if (localForja['onboarded'] == true) {
            merged['onboarded'] = true;
          }
          connected['forja'] = merged;
        } else {
          final merged = Map<String, dynamic>.from(localForja);
          if (localForja['onboarded'] == true ||
              remoteForja['onboarded'] == true) {
            merged['onboarded'] = true;
          }
          connected['forja'] = merged;
        }
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
    int? navGenAtFetch,
    int? addonFeatureGenAtFetch,
  }) async {
    // Profile switch: wipe first so missing lean keys cannot keep prior profile.
    // Focus/resume refresh: apply cloud over the current cache — do not flash
    // platform-default nav (all tabs) before the real visibleIds land.
    if (resetLocalFirst) {
      // IPTV already wiped at pullAndMergeAll entry (issue 217). clearIptv
      // true is idempotent and covers any caller that reset without that wipe.
      _navigationLocalGen = 0;
      _navigationSyncedGen = 0;
      _addonFeatureLocalGen = 0;
      _addonFeatureSyncedGen = 0;
      await resetSyncedLocalToPlatformDefaults(
        clearIptv: true,
        notify: false,
      );
    }

    final playback = payload['playback'];
    if (playback is Map) {
      final editedAddonDuringPull = !resetLocalFirst &&
          addonFeatureGenAtFetch != null &&
          _addonFeatureLocalGen != addonFeatureGenAtFetch;
      final addonFeaturePending = !resetLocalFirst &&
          (_addonFeatureLocalGen != _addonFeatureSyncedGen ||
              editedAddonDuringPull);
      if (addonFeaturePending) {
        debugPrint(
          '[Sync] skip addon_feature_* apply — local Addons edit not synced yet'
          '${editedAddonDuringPull ? ' (edited during pull)' : ''}',
        );
      }
      await importPreferences(
        Map<String, dynamic>.from(playback),
        skipAddonFeatures: addonFeaturePending,
      );
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
    final editedDuringPull = !resetLocalFirst &&
        navGenAtFetch != null &&
        _navigationLocalGen != navGenAtFetch;
    final navPending =
        !resetLocalFirst && _navigationLocalGen != _navigationSyncedGen;
    if (editedDuringPull) {
      debugPrint(
        '[Sync] skip navigation apply — local edit during cloud pull',
      );
    } else if (navPending) {
      final localNav = await _exportNavigationCompact();
      final remoteNav = navigation is Map
          ? Map<String, dynamic>.from(navigation)
          : null;
      final localIds = _navVisibleIds(localNav);
      final remoteIds = _navVisibleIds(remoteNav);
      // Hollow dirty local (empty ATV cache) may take richer cloud Features.
      // Non-empty dirty local must never be replaced — Addons OK → [iptv]
      // then "richer cloud" apply was wiping the enable so the next OK
      // logged next=[live_matches] only (224).
      if (localIds.isEmpty && remoteIds.isNotEmpty) {
        debugPrint(
          '[Sync] apply cloud nav — dirty local hollow, take Features from cloud',
        );
        _navigationLocalGen = _navigationSyncedGen;
        if (navigation is Map) {
          await _importNavigation(Map<String, dynamic>.from(navigation));
        }
      } else {
        debugPrint(
          '[Sync] skip navigation apply — local Features edit not synced yet '
          '(local ${localIds.length} tab(s))',
        );
      }
    } else if (navigation is Map) {
      // Soft pull: never drop local tabs for a thinner cloud row — that wiped
      // Addons/Features enables right after OK (224). Profile switch
      // (resetLocalFirst) still applies cloud as master.
      final localNav = await _exportNavigationCompact();
      final remoteNav = Map<String, dynamic>.from(navigation);
      if (!resetLocalFirst &&
          navigationWouldShrinkLocal(localNav, remoteNav)) {
        debugPrint(
          '[Sync] skip cloud nav shrink on soft pull — keep local '
          '${_navVisibleIds(localNav).length} tab(s)',
        );
        // Heal hollow cloud so the next soft pull matches the device.
        unawaited(schedulePush(_domainNavigation));
      } else {
        await _importNavigation(remoteNav);
      }
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
    final packs = await PluginRegistry.instance.listPacksRaw();
    final pendingPurge = await PendingRemotePurgeStore.read();
    final lean = <Map<String, dynamic>>[];
    for (final pack in packs) {
      final manifestUrl = pack.sourceUrl.trim();
      if (manifestUrl.isEmpty) continue;
      if (PluginRegistry.isLegacyAssetPack(manifestUrl)) continue;
      if (pendingPurge.contains(manifestUrl)) continue;
      final row = <String, dynamic>{'manifestUrl': manifestUrl};
      final name = pack.name.trim();
      if (name.isNotEmpty) row['name'] = name;
      final version = pack.version.trim();
      if (version.isNotEmpty) row['version'] = version;
      lean.add(row);
    }
    final out = <String, dynamic>{};
    if (lean.isNotEmpty) out['packs'] = lean;
    // Keep onboarded even when packs is empty (Skip path must not drop the flag).
    if (await PacksOnboardingStore.isOnboardedLocal()) {
      out['onboarded'] = true;
    }
    return out;
  }

  Future<Map<String, dynamic>> _exportNavigationCompact() async {
    final ids = await _settings.getNavbarConfig();
    final tabOrder = await _settings.getNavbarTabOrder();
    final defaultTab = await _settings.getDefaultNavTab();
    final out = <String, dynamic>{
      // Always include — empty list is intentional "all feature tabs off".
      'visibleIds': ids,
    };
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
      'addon_feature_iptv': await _settings.isAddonFeatureEnabled('iptv'),
      'addon_feature_live_matches':
          await _settings.isAddonFeatureEnabled('live_matches'),
    };
  }

  Future<void> importPreferences(
    Map<String, dynamic> payload, {
    bool skipAddonFeatures = false,
  }) async {
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
    if (!skipAddonFeatures) {
      if (payload.containsKey('addon_feature_iptv')) {
        await _settings.setAddonFeatureEnabled(
          'iptv',
          payload['addon_feature_iptv'] as bool,
        );
      }
      if (payload.containsKey('addon_feature_live_matches')) {
        await _settings.setAddonFeatureEnabled(
          'live_matches',
          payload['addon_feature_live_matches'] as bool,
        );
      }
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
        // Only persist + notify when cloud lean fields actually differ — every
        // resume sync used to flip `changed` and remount Live Providers.
        final before = _stremioLeanFingerprint(existing);
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
        if (before == _stremioLeanFingerprint(existing)) continue;
        await _settings.saveStremioAddon(existing, notify: false);
        changed = true;
        continue;
      }

      if (syncedFeatures != null) lean['features'] = syncedFeatures;
      if (lean.containsKey('enabled')) {
        lean['enabled'] = StremioAddonFeatures.normalizeEnabled(lean['enabled']);
      }
      // New lean row or unhydrated stub — skip notify churn if identical stub.
      final prior = localByBase[baseUrl];
      if (prior != null &&
          _stremioLeanFingerprint(prior) == _stremioLeanFingerprint(lean)) {
        continue;
      }
      await _settings.saveStremioAddon(lean, notify: false);
      changed = true;
    }

    if (changed) SettingsService.addonChangeNotifier.value++;
  }

  /// Cloud lean fields that affect Live Providers / Stremio UI — not full manifest.
  static String _stremioLeanFingerprint(Map<String, dynamic> addon) {
    final features = addon['features'];
    final feat = features is List
        ? StremioAddonFeatures.normalize(features).join(',')
        : '';
    final enabled = addon.containsKey('enabled')
        ? StremioAddonFeatures.normalizeEnabled(addon['enabled']).toString()
        : '';
    final name = (addon['name'] ?? '').toString().trim();
    final description = (addon['description'] ?? '').toString().trim();
    final base = SettingsService.normalizeStremioAddonBaseUrl(
      addon['baseUrl']?.toString() ?? '',
    );
    return '$base|$enabled|$name|$description|$feat';
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

  /// Apply cloud lean rows (`manifestUrl` + optional name). **No network.**
  /// Mid-session: enqueue install/uninstall confirms. Boot: silent hydrate/purge.
  Future<LeanApplyResult> importForja(Map<String, dynamic> payload) async {
    await PacksOnboardingStore.applyFromCloud(
      payload['onboarded'] == true,
    );
    final packs = payload['packs'] as List? ?? const [];
    final rows = <Map<String, dynamic>>[
      for (final raw in packs)
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    final boot = PluginInstallCoordinator.instance.isBootWarm;
    final result = await EngineService.instance.applyLeanManifestUrls(
      rows,
      purgeRemovedImmediately: boot,
    );
    await PluginInstallPromptService.enqueueFromLeanDiff(result);
    return result;
  }
}

void scheduleIptvSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainIptv);

Future<void> schedulePreferencesSyncPush() =>
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

/// Push `onboarded` without wiping cloud pack membership when local packs are empty.
void scheduleForjaOnboardedSyncPush() =>
    SyncDomainBridge.instance.scheduleOnboardedPush();

Future<void> scheduleNavigationSyncPush() =>
    SyncDomainBridge.instance.schedulePush(SyncDomainBridge._domainNavigation);

/// Call before writing navbar so soft pulls cannot wipe a mid-edit enable.
void noteNavigationDirty() =>
    SyncDomainBridge.instance.noteNavigationDirty();

/// Call before writing `addon_feature_*` so soft pulls cannot demote mid-edit.
void noteAddonFeaturesDirty() =>
    SyncDomainBridge.instance.noteAddonFeaturesDirty();
