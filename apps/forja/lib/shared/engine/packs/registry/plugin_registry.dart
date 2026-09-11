import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/hub/meta_cache.dart';
import 'package:forja/shared/engine/models/lean_apply_result.dart';
import 'package:forja/shared/engine/live/live_sport_capabilities.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/catalog/official_forjahq_packs.dart';
import 'package:forja/shared/engine/packs/catalog/plugin_catalog_remote.dart';
import 'package:forja/shared/engine/packs/registry/plugin_contract.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_validator.dart';
import 'package:forja/shared/engine/packs/registry/plugin_script_disk_store.dart';
import 'package:forja/shared/engine/packs/install/remote_pack_intent_store.dart';
import 'package:forja/shared/playback/cache/catalog_sources_session_cache.dart';
import 'package:forja/shared/playback/cache/player_stream_extract_cache.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns engine pack install / refresh / remove / script cache.
///
/// [EngineService] stays the extract host and delegates pack lifecycle here.
/// Remote JS bodies live on disk ([PluginScriptDiskStore]); pack metadata in
/// prefs scoped per launched profile ([LocalDataScope]).
class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  static const _packsKeyV1 = 'engine_js_packs_v1';
  static const _packsKeyV2 = 'engine_js_packs_v2';
  static const _scriptPrefixV1 = 'engine_js_script_';
  static const _preludePrefixV1 = 'engine_js_prelude_';
  static const _scriptPrefixV2 = 'engine_js_script_v2_';
  static const _preludePrefixV2 = 'engine_js_prelude_v2_';
  static const _migratedKey = 'engine_js_packs_v2_migrated';
  static const _scriptsDiskMigratedKey = 'engine_js_scripts_disk_v3_migrated';

  /// Local checkout script bodies — invalidate catalog answers when JS edits.
  final Map<String, String> _localScriptDigests = {};
  static const _legacyMonolithWipedKey = 'engine_js_legacy_forjahq_wiped';
  static const _liveSportMigrationKey = 'live_sport_unified_migration_v1';

  static const _legacyBundledSourceUrlProviders = 'asset:providers/engine.json';
  static const _legacyBundledSourceUrl = 'asset:engine_js/engine.json';
  static const _legacyAssetBundledSourceUrl = 'asset:plugins/engine.json';

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String?> officialInstallError =
      ValueNotifier<String?>(null);

  Future<void>? _officialEnsureFuture;
  final Set<String> _scriptRepairAttempted = {};

  /// Test-only HTTP client override (MockClient).
  @visibleForTesting
  http.Client? debugHttpClient;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// Pack index for the launched profile (`engine_js_packs_v2@account:profile`).
  static String get packsPrefsKey => LocalDataScope.storageKey(_packsKeyV2);

  /// Read pack JSON for the active profile; lazy-copy unscoped legacy once.
  Future<String?> _readPacksJson(SharedPreferences prefs) async {
    final scoped = packsPrefsKey;
    final scopedRaw = prefs.getString(scoped);
    if (scopedRaw != null && scopedRaw.isNotEmpty) return scopedRaw;
    final bare = prefs.getString(_packsKeyV2);
    if (bare == null || bare.isEmpty) return null;
    await prefs.setString(scoped, bare);
    await prefs.remove(_packsKeyV2);
    return bare;
  }

  Future<void> _writePacksJson(SharedPreferences prefs, String json) async {
    await prefs.setString(packsPrefsKey, json);
    if (prefs.containsKey(_packsKeyV2)) {
      await prefs.remove(_packsKeyV2);
    }
  }

  Future<http.Response> _httpGet(Uri uri) async {
    final c = debugHttpClient;
    if (c != null) return c.get(uri);
    return http.get(uri);
  }

  static File? _asLocalFile(String url) {
    final t = url.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('file://')) return File.fromUri(Uri.parse(t));
    if (t.startsWith('/')) return File(t);
    if (Platform.isWindows && RegExp(r'^[A-Za-z]:\\').hasMatch(t)) {
      return File(t);
    }
    return null;
  }

  Future<bool> _localManifestExists(String url) async {
    final file = _asLocalFile(url);
    if (file == null) return true;
    return file.exists();
  }

  /// When a stored manifest is a local path this device cannot read, try another
  /// installed pack at the same opaque slot (remote URL), then a published
  /// catalog row with the same slot. No baked GitHub URL map.
  Future<String> _substituteUnreachableLocalManifest(String url) async {
    if (await _localManifestExists(url)) return url;
    final slot = forjaHqSlot(url);
    if (slot == null) return url;
    for (final pack in await listPacksRaw()) {
      if (pack.sourceUrl == url) continue;
      if (forjaHqSlot(pack.sourceUrl) != slot) continue;
      if (_asLocalFile(pack.sourceUrl) != null) continue;
      debugPrint(
        '[engine] local manifest missing ($slot) — using ${pack.sourceUrl}',
      );
      return pack.sourceUrl;
    }
    for (final published in await PluginCatalogRemote.fetchPublishedPacks()) {
      if (forjaHqSlot(published.manifestUrl) != slot) continue;
      debugPrint(
        '[engine] local manifest missing ($slot) — catalog ${published.manifestUrl}',
      );
      return published.manifestUrl;
    }
    return url;
  }

  Future<String> _fetchText(String url) async {
    final bytes = await _fetchBytes(url);
    return utf8.decode(bytes, allowMalformed: false);
  }

  Future<List<int>> _fetchBytes(String url) async {
    final file = _asLocalFile(url);
    if (file != null) {
      if (!await file.exists()) {
        throw ManifestGoneException(url);
      }
      return file.readAsBytes();
    }
    final resp = await _httpGet(Uri.parse(url)).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException('plugin fetch $url'),
    );
    if (resp.statusCode == 404 || resp.statusCode == 410) {
      throw ManifestGoneException(url, statusCode: resp.statusCode);
    }
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    return resp.bodyBytes;
  }

  /// Path-pattern helper for Settings grouping — not pack inventory.
  @visibleForTesting
  static String? forjaHqSlot(String url) => EnginePack.forjaHqSlot(url);

  /// Hub manifest slot (any path under `plugins/hubs/` except monolith home alias).
  static bool isHubManifestSlot(String? slot) {
    if (slot == null || slot.isEmpty) return false;
    return slot != 'providers' &&
        slot != 'live' &&
        slot != 'catalog' &&
        slot != 'torrent' &&
        slot != 'iptv-vod';
  }

  /// Features / rail id for a hub `nav` contribution (RFC-094).
  ///
  /// Host owns chrome ids as **opaque strings**. Packs may omit `nav.tabId`.
  /// - Hub tree URL → `nav.tabId` if set, else opaque `forjaHqSlot` path segment
  /// - Community / arbitrary URL → `p_<urlHash>` (+ optional local label)
  /// Never map slot names in Dart — packs that need a stable id ≠ folder declare
  /// `nav.tabId` (e.g. My List folder `my_list` → `"tabId": "mylist"`).
  static String hostNavId({
    required String sourceUrl,
    required String authorTabId,
  }) {
    final slot = forjaHqSlot(sourceUrl);
    final local = authorTabId.trim();
    if (slot != null) {
      if (local.isNotEmpty) return local;
      return slot;
    }
    final hash = EnginePack.urlHash(sourceUrl);
    final sanitized = local.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitized.isEmpty) return 'p_$hash';
    return 'p_${hash}_$sanitized';
  }

  /// IPTV VOD details pack — catalog protocol, not a shell hub tab.
  static bool isIptvVodManifestSlot(String? slot) => slot == 'iptv-vod';

  static String? hubSlotLabel(String? slot) {
    if (slot == null || slot.isEmpty) return null;
    return slot
        .split(RegExp(r'[_-]+'))
        .where((w) => w.isNotEmpty)
        .map(
          (w) => w.length == 1
              ? w.toUpperCase()
              : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }

  /// Settings → Forja plugins pack buckets (not per-plugin [EngineCategories]).
  static const packKindProviders = 'providers';
  static const packKindLive = 'live';
  static const packKindCatalog = 'catalog';
  static const packKindTorrent = 'torrent';
  static const packKindIptv = 'iptv';
  static const packKindHubs = 'hubs';
  static const packKindOther = 'other';

  static const packKindOrder = [
    packKindProviders,
    packKindLive,
    packKindCatalog,
    packKindTorrent,
    packKindIptv,
    packKindHubs,
    packKindOther,
  ];

  static String packKindLabel(String key) => switch (key) {
    packKindProviders => 'Providers',
    packKindLive => 'Live',
    packKindCatalog => 'Catalog',
    packKindTorrent => 'Torrent',
    packKindIptv => 'IPTV',
    packKindHubs => 'Hubs',
    _ => 'Other',
  };

  /// Pack bucket for the installed list: Providers / Live / Catalog / IPTV / Hubs / Other.
  ///
  /// Known URL tree segments map when present; unknown slots fall through to
  /// plugin-type heuristics (no pack-id / folder allowlist for community packs).
  static String packKindKey(EnginePack pack) {
    final slot = forjaHqSlot(pack.sourceUrl);
    if (slot != null) {
      final fromSlot = switch (slot) {
        'providers' => packKindProviders,
        'live' => packKindLive,
        'catalog' => packKindCatalog,
        'torrent' => packKindTorrent,
        'iptv-vod' => packKindIptv,
        _ when isHubManifestSlot(slot) => packKindHubs,
        _ => null,
      };
      if (fromSlot != null) return fromSlot;
    }
    if (pack.plugins.any((p) => p.types.contains('iptv'))) return packKindIptv;
    if (pack.plugins.any((p) => p.isKitPlugin)) return packKindHubs;
    if (pack.plugins.any((p) => p.isLiveSportPlugin || p.isLive)) {
      return packKindLive;
    }
    if (pack.plugins.any((p) => p.isLiveFeedPlugin)) return packKindCatalog;
    if (pack.plugins.any((p) => p.isHttp)) return packKindProviders;
    return packKindOther;
  }

  /// Subtitle kind chip: `Providers` or `Hubs · Home` or `IPTV · VOD`.
  static String packKindInfo(EnginePack pack) {
    final kind = packKindKey(pack);
    final slot = forjaHqSlot(pack.sourceUrl);
    final slotLabel = hubSlotLabel(slot);
    if (kind == packKindHubs && slotLabel != null) {
      return '${packKindLabel(kind)} · $slotLabel';
    }
    if (kind == packKindIptv && slotLabel != null) {
      return '${packKindLabel(kind)} · $slotLabel';
    }
    return packKindLabel(kind);
  }

  /// Pack at a conventional ForjaHQ path that is not in [keepUrls].
  static bool isShadowSlotPack(EnginePack pack, Set<String> keepUrls) {
    if (keepUrls.contains(pack.sourceUrl)) return false;
    if (pack.packId == 'forjahq-hubs') return true; // legacy monolith hubs
    return forjaHqSlot(pack.sourceUrl) != null;
  }

  static bool isLegacyMonolithPack(EnginePack pack) => pack.packId == 'forjahq';

  static bool isLegacyAssetPack(String sourceUrl) =>
      sourceUrl.startsWith('asset:') ||
      sourceUrl == _legacyAssetBundledSourceUrl ||
      sourceUrl == _legacyBundledSourceUrlProviders ||
      sourceUrl == _legacyBundledSourceUrl;

  static String urlHash(String sourceUrl) => EnginePack.urlHash(sourceUrl);

  /// Legacy prefs keys — kept for migration + tests only.
  @visibleForTesting
  static String scriptPrefsKey(String sourceUrl, String pluginId) =>
      '$_scriptPrefixV2${urlHash(sourceUrl)}_$pluginId';

  @visibleForTesting
  static String preludePrefsKey(String sourceUrl, String preludeEntry) =>
      '$_preludePrefixV2${urlHash(sourceUrl)}_'
      '${Uri.encodeComponent(preludeEntry)}';

  static bool isLocalManifestUrl(String url) => _asLocalFile(url) != null;

  /// True when a remote pack needs install/repair (lean stub or missing disk JS).
  /// Unreachable local checkout paths (synced Mac paths on TV) also need install
  /// so [_substituteUnreachableLocalManifest] can swap to a peer/catalog URL.
  ///
  /// Lean stubs (`plugins: []`) after sign-out / profile reset still return
  /// true here — call [rehydrateLeanStubsFromDisk] first so the active profile
  /// scope can restore metadata from `pack.json` without a network re-fetch.
  Future<bool> packNeedsDiskInstall(EnginePack pack) async {
    if (isLegacyAssetPack(pack.sourceUrl)) return false;
    if (isLocalManifestUrl(pack.sourceUrl)) {
      return !(await _localManifestExists(pack.sourceUrl));
    }
    if (pack.plugins.isEmpty) return true;
    return !(await _diskHasAllScripts(pack));
  }

  Future<bool> _diskHasAllScripts(EnginePack pack) async {
    for (final p in pack.plugins) {
      if (p.entry.isEmpty || !p.needsScript) continue;
      if (!await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: pack.sourceUrl,
        pluginId: p.id,
      )) {
        return false;
      }
      if (p.prelude.isNotEmpty &&
          !await PluginScriptDiskStore.hasEnginePrelude(
            sourceUrl: pack.sourceUrl,
            preludeEntry: p.prelude,
          )) {
        return false;
      }
    }
    return true;
  }

  /// Restore lean stubs from this profile's disk `pack.json` when scripts are
  /// already present (e.g. after a lean soft-pull stubbed the prefs index).
  Future<int> rehydrateLeanStubsFromDisk() async {
    final all = await listPacksRaw();
    var restored = 0;
    final next = <EnginePack>[];
    for (final pack in all) {
      if (pack.plugins.isNotEmpty ||
          isLegacyAssetPack(pack.sourceUrl) ||
          isLocalManifestUrl(pack.sourceUrl)) {
        next.add(pack);
        continue;
      }
      final meta = await PluginScriptDiskStore.loadEnginePackMeta(
        pack.sourceUrl,
      );
      if (meta == null || meta.plugins.isEmpty) {
        next.add(pack);
        continue;
      }
      if (!await _diskHasAllScripts(meta)) {
        next.add(pack);
        continue;
      }
      next.add(
        meta.copyWith(
          name: pack.name.trim().isNotEmpty && pack.name != 'Forja pack'
              ? pack.name
              : meta.name,
          version: pack.version != '0.0.0' ? pack.version : meta.version,
          enabled: pack.enabled,
        ),
      );
      restored++;
    }
    if (restored > 0) {
      await _savePacks(next);
      debugPrint(
        '[engine] rehydrated $restored pack(s) from disk '
        '(skipped re-download)',
      );
      notifyChanged();
    }
    return restored;
  }

  Future<void> _purgePackScriptStorage(
    EnginePack pack, {
    bool purgeDisk = true,
  }) async {
    if (purgeDisk && !isLocalManifestUrl(pack.sourceUrl)) {
      await PluginScriptDiskStore.removeEnginePack(pack.sourceUrl);
    }
    final prefs = await _prefs;
    for (final p in pack.plugins) {
      await prefs.remove(scriptPrefsKey(pack.sourceUrl, p.id));
      if (p.prelude.isNotEmpty) {
        await prefs.remove(preludePrefsKey(pack.sourceUrl, p.prelude));
      }
    }
  }

  /// One-time: prefs script bodies → disk. Idempotent.
  Future<void> migrateScriptsToDiskIfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_scriptsDiskMigratedKey) == true) return;
    final raw = await _readPacksJson(prefs);
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(_scriptsDiskMigratedKey, true);
      return;
    }
    List<EnginePack> packs;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.setBool(_scriptsDiskMigratedKey, true);
        return;
      }
      packs = [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      await prefs.setBool(_scriptsDiskMigratedKey, true);
      return;
    }
    for (final pack in packs) {
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      if (isLocalManifestUrl(pack.sourceUrl)) continue;
      for (final p in pack.plugins) {
        if (p.entry.isEmpty || !p.needsScript) continue;
        final key = scriptPrefsKey(pack.sourceUrl, p.id);
        final body = prefs.getString(key);
        if (body != null && body.isNotEmpty) {
          await PluginScriptDiskStore.saveEngineScript(
            sourceUrl: pack.sourceUrl,
            pluginId: p.id,
            body: body,
          );
          await prefs.remove(key);
        }
        if (p.prelude.isNotEmpty) {
          final preKey = preludePrefsKey(pack.sourceUrl, p.prelude);
          final pre = prefs.getString(preKey);
          if (pre != null && pre.isNotEmpty) {
            await PluginScriptDiskStore.saveEnginePrelude(
              sourceUrl: pack.sourceUrl,
              preludeEntry: p.prelude,
              body: pre,
            );
            await prefs.remove(preKey);
          }
        }
      }
    }
    await prefs.setBool(_scriptsDiskMigratedKey, true);
    debugPrint('[engine] migrated script bodies to disk');
  }

  /// Serialize [install] writes — parallel callers fetch concurrently via
  /// [Future.wait] but must not interleave prefs commits.
  Future<void> _installMutex = Future<void>.value();

  Future<T> _withInstallLock<T>(Future<T> Function() fn) {
    final done = Completer<T>();
    _installMutex = _installMutex.then((_) async {
      try {
        done.complete(await fn());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  void notifyChanged() => changeNotifier.value++;

  Future<void> _savePacks(List<EnginePack> packs) async {
    final prefs = await _prefs;
    await _writePacksJson(
      prefs,
      jsonEncode([for (final p in packs) p.toJson()]),
    );
    notifyChanged();
  }

  Future<List<EnginePack>> listPacksRaw() async {
    await _migrateV1IfNeeded();
    await _wipeLegacyMonolithIfNeeded();
    await migrateScriptsToDiskIfNeeded();
    final prefs = await _prefs;
    final raw = await _readPacksJson(prefs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final packs = [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
      return _purgeLegacyAssetPacks(packs);
    } catch (_) {
      return [];
    }
  }

  /// Remove the pre-split single ForjaHQ pack so the three packs can install.
  Future<void> _wipeLegacyMonolithIfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_legacyMonolithWipedKey) == true) return;
    final raw = await _readPacksJson(prefs);
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(_legacyMonolithWipedKey, true);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await prefs.setBool(_legacyMonolithWipedKey, true);
        return;
      }
      final packs = [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
      final victims = packs.where(isLegacyMonolithPack).toList();
      if (victims.isEmpty) {
        await prefs.setBool(_legacyMonolithWipedKey, true);
        return;
      }
      for (final pack in victims) {
        await _purgePackScriptStorage(pack);
      }
      final keep = packs.where((p) => !isLegacyMonolithPack(p)).toList();
      await _writePacksJson(
        prefs,
        jsonEncode([for (final p in keep) p.toJson()]),
      );
      notifyChanged();
      debugPrint(
        '[engine] wiped ${victims.length} legacy ForjaHQ monolith pack(s)',
      );
    } catch (e) {
      debugPrint('[engine] legacy ForjaHQ wipe failed: $e');
    }
    await prefs.setBool(_legacyMonolithWipedKey, true);
  }

  Future<List<EnginePack>> listPacks() async {
    await ensureOfficialInstalled();
    final packs = await listPacksRaw();
    await repairMissingScripts(packs);
    return listPacksRaw();
  }

  Future<void> _migrateV1IfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_migratedKey) == true) return;
    final v2 = await _readPacksJson(prefs);
    if (v2 != null && v2.isNotEmpty) {
      await prefs.setBool(_migratedKey, true);
      return;
    }
    final v1 = prefs.getString(_packsKeyV1);
    if (v1 == null || v1.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      return;
    }
    try {
      final decoded = jsonDecode(v1);
      if (decoded is! List) {
        await prefs.setBool(_migratedKey, true);
        return;
      }
      final packs = <EnginePack>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        // Drop legacy bundled flag; fromStored ignores it.
        final pack = EnginePack.fromStored(map);
        if (isLegacyAssetPack(pack.sourceUrl) || map['bundled'] == true) {
          continue;
        }
        packs.add(pack);
        for (final p in pack.plugins) {
          final old = prefs.getString('$_scriptPrefixV1${p.id}');
          if (old != null && old.isNotEmpty) {
            if (!isLocalManifestUrl(pack.sourceUrl)) {
              await PluginScriptDiskStore.saveEngineScript(
                sourceUrl: pack.sourceUrl,
                pluginId: p.id,
                body: old,
              );
            }
          }
          if (p.prelude.isNotEmpty) {
            final oldPre = prefs.getString(
              '$_preludePrefixV1${Uri.encodeComponent(p.prelude)}',
            );
            if (oldPre != null &&
                oldPre.isNotEmpty &&
                !isLocalManifestUrl(pack.sourceUrl)) {
              await PluginScriptDiskStore.saveEnginePrelude(
                sourceUrl: pack.sourceUrl,
                preludeEntry: p.prelude,
                body: oldPre,
              );
            }
          }
        }
      }
      await _writePacksJson(
        prefs,
        jsonEncode([for (final p in packs) p.toJson()]),
      );
      await prefs.remove(_packsKeyV1);
      // Orphan unscoped v1 script keys for migrated plugin ids.
      for (final pack in packs) {
        for (final p in pack.plugins) {
          await prefs.remove('$_scriptPrefixV1${p.id}');
          if (p.prelude.isNotEmpty) {
            await prefs.remove(
              '$_preludePrefixV1${Uri.encodeComponent(p.prelude)}',
            );
          }
        }
      }
      // Legacy embed-st shared key.
      await prefs.remove('engine_js_script___embed_st__');
      debugPrint('[engine] migrated ${packs.length} packs to prefs v2');
    } catch (e) {
      debugPrint('[engine] packs v1 migrate failed: $e');
    }
    await prefs.setBool(_migratedKey, true);
  }

  Future<List<EnginePack>> _purgeLegacyAssetPacks(
    List<EnginePack> packs,
  ) async {
    final keep = <EnginePack>[];
    final victims = <EnginePack>[];
    for (final p in packs) {
      if (isLegacyAssetPack(p.sourceUrl)) {
        victims.add(p);
      } else {
        keep.add(p);
      }
    }
    if (victims.isEmpty) return packs;
    for (final pack in victims) {
      await _purgePackScriptStorage(pack);
    }
    await _savePacks(keep);
    return keep;
  }

  /// Log-only marker for remote packs still missing disk JS.
  /// Downloads belong to [PluginInstallCoordinator.ensureAllInstalled] (boot)
  /// / mid-session cloud auto-install — this never prompts or fetches.
  ///
  /// Quiet until a profile was launched ([PluginScriptDiskStore.hasBoundProfileScope]).
  /// Guest local profile and signed-in [selectProfile] both count; profile
  /// picker / account gate do not (issue 259).
  Future<void> repairMissingScripts(List<EnginePack> packs) async {
    if (!PluginScriptDiskStore.hasBoundProfileScope) return;
    for (final pack in packs) {
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      if (isLocalManifestUrl(pack.sourceUrl)) continue;
      if (_scriptRepairAttempted.contains(pack.sourceUrl)) continue;
      if (!await packNeedsDiskInstall(pack)) continue;
      _scriptRepairAttempted.add(pack.sourceUrl);
      debugPrint(
        '[engine] scripts missing for ${pack.name} — '
        'awaiting splash/cloud hydrate',
      );
    }
  }

  String resolveScriptUrl(String manifestUrl, String filename) {
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    final manifestFile = _asLocalFile(manifestUrl);
    if (manifestFile != null) {
      final rel = filename.replaceAll('/', Platform.pathSeparator);
      return '${manifestFile.parent.path}${Platform.pathSeparator}$rel';
    }
    final mu = Uri.parse(manifestUrl);
    final path = mu.path.endsWith('/')
        ? '${mu.path}$filename'
        : '${mu.path.substring(0, mu.path.lastIndexOf('/') + 1)}$filename';
    return mu.replace(path: path).toString();
  }

  static bool _isPackRelativeAssetPath(String? ref) {
    final s = ref?.trim() ?? '';
    if (s.isEmpty) return false;
    if (s.startsWith('http://') || s.startsWith('https://')) return false;
    if (s.startsWith('file://')) return false;
    if (s.startsWith('assets/') || s.startsWith('forja://')) return false;
    if (s.contains('..')) return false;
    return true;
  }

  /// Fetch a pack-relative file into [PluginScriptDiskStore] when missing.
  ///
  /// Used for hub `nav.icon` bitmaps so the rail paints from disk offline.
  Future<void> ensureRemotePackRelativeFile({
    required String sourceUrl,
    required String relative,
  }) async {
    final url = sourceUrl.trim();
    final rel = relative.trim();
    if (url.isEmpty || !_isPackRelativeAssetPath(rel)) return;
    if (isLegacyAssetPack(url) || isLocalManifestUrl(url)) return;
    if (await PluginScriptDiskStore.hasPackRelativeFile(
      sourceUrl: url,
      relative: rel,
    )) {
      return;
    }
    try {
      final bytes = await _fetchBytes(resolveScriptUrl(url, rel));
      if (bytes.isEmpty) return;
      await PluginScriptDiskStore.savePackRelativeFile(
        sourceUrl: url,
        relative: rel,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('[engine] pack asset fetch failed ($rel @ $url): $e');
    }
  }

  /// Disable (not remove) packs that share a conventional slot but are not in
  /// [keepUrls]. Never touches [EnginePack.enabled] on keep URLs.
  @visibleForTesting
  Future<void> applyOfficialKeepSet(List<String> keepUrls) async {
    final keep = {
      for (final u in keepUrls)
        if (u.trim().isNotEmpty) u.trim(),
    };
    final packs = await listPacksRaw();
    final next = <EnginePack>[];
    var changed = false;
    for (final pack in packs) {
      if (keep.contains(pack.sourceUrl)) {
        next.add(pack);
        continue;
      }
      if (!isShadowSlotPack(pack, keep)) {
        next.add(pack);
        continue;
      }
      if (!pack.enabled) {
        next.add(pack);
        continue;
      }
      debugPrint(
        '[engine] disable shadow pack ${pack.packId} (${pack.sourceUrl})',
      );
      next.add(pack.copyWith(enabled: false));
      changed = true;
    }
    if (changed) await _savePacks(next);
  }

  @visibleForTesting
  @Deprecated('Use applyOfficialKeepSet')
  Future<void> disableShadowOfficialPacks(List<String> keepUrls) =>
      applyOfficialKeepSet(keepUrls);

  /// Debug override: full manifest URL/path from env only (no packs-tree invent).
  @visibleForTesting
  static String? devCatalogManifestUrl() {
    if (!kDebugMode) return null;
    var explicit = const String.fromEnvironment(
      'FORJA_HQ_CATALOG_MANIFEST_URL',
    ).trim();
    if (explicit.isEmpty) {
      explicit =
          Platform.environment['FORJA_HQ_CATALOG_MANIFEST_URL']?.trim() ?? '';
    }
    return explicit.isEmpty ? null : explicit;
  }

  /// Debug override: full torrent manifest URL/path from env only.
  @visibleForTesting
  static String? devTorrentManifestUrl() {
    if (!kDebugMode) return null;
    var explicit = const String.fromEnvironment(
      'FORJA_HQ_TORRENT_MANIFEST_URL',
    ).trim();
    if (explicit.isEmpty) {
      explicit =
          Platform.environment['FORJA_HQ_TORRENT_MANIFEST_URL']?.trim() ?? '';
    }
    return explicit.isEmpty ? null : explicit;
  }

  /// Debug override: full live manifest URL/path from env only.
  @visibleForTesting
  static String? devLiveManifestUrl() {
    if (!kDebugMode) return null;
    var explicit = const String.fromEnvironment(
      'FORJA_HQ_LIVE_MANIFEST_URL',
    ).trim();
    if (explicit.isEmpty) {
      explicit =
          Platform.environment['FORJA_HQ_LIVE_MANIFEST_URL']?.trim() ?? '';
    }
    return explicit.isEmpty ? null : explicit;
  }

  /// Hydrate lean stubs and refresh remote packs when needed.
  Future<void> ensureOfficialInstalled({bool force = false}) async {
    if (_officialEnsureFuture != null) {
      await _officialEnsureFuture;
      return;
    }
    final run = () async {
      try {
        await migrateLegacyLiveSportPacksIfNeeded();
        await _purgeRetiredOfficialPacks();
        await hydrateLeanInstalled();
        final packs = await listPacksRaw();
        if (force) {
          final pending = <Future<void>>[];
          for (final pack in packs) {
            if (isLegacyAssetPack(pack.sourceUrl)) continue;
            pending.add(install(pack.sourceUrl));
          }
          if (pending.isNotEmpty) await Future.wait(pending);
        }
        _clearOfficialInstallError();
      } catch (e) {
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        officialInstallError.value = msg;
        notifyChanged();
        debugPrint('[engine] pack hydrate failed: $msg');
      }
    }();
    _officialEnsureFuture = run;
    try {
      await run;
    } finally {
      if (identical(_officialEnsureFuture, run)) {
        _officialEnsureFuture = null;
      }
    }
  }

  /// Peek remote manifest without installing.
  ///
  /// [gone] is true only when the URL is missing (HTTP 404/410 or local file
  /// gone). Network / parse failures leave [gone] false and [version] null.
  Future<({String? version, bool gone})> peekRemoteManifest(
    String manifestUrl,
  ) async {
    try {
      final body = await _fetchText(manifestUrl);
      final map = jsonDecode(body);
      if (map is! Map) return (version: null, gone: false);
      final remoteVer = (map['version'] as String?)?.trim() ?? '';
      return (
        version: remoteVer.isEmpty ? null : remoteVer,
        gone: false,
      );
    } on ManifestGoneException catch (e) {
      debugPrint('[engine] remote manifest gone ($manifestUrl): $e');
      return (version: null, gone: true);
    } catch (e) {
      debugPrint('[engine] peek remote version failed ($manifestUrl): $e');
      return (version: null, gone: false);
    }
  }

  /// Fetch manifest `version` without installing (Settings update badge).
  Future<String?> peekRemoteVersion(String manifestUrl) async {
    final peek = await peekRemoteManifest(manifestUrl);
    return peek.version;
  }

  /// Returns update info when the remote manifest version is newer.
  Future<EnginePackUpdateInfo?> peekRemoteUpdate(EnginePack local) async {
    final peek = await peekRemoteManifest(local.sourceUrl);
    final remoteVer = peek.version;
    if (remoteVer == null) return null;
    if (compareEngineSemver(remoteVer, local.version) <= 0) return null;
    return EnginePackUpdateInfo(
      sourceUrl: local.sourceUrl,
      packName: local.name,
      installedVersion: local.version,
      remoteVersion: remoteVer,
    );
  }

  void _clearOfficialInstallError() {
    if (officialInstallError.value != null) {
      officialInstallError.value = null;
      notifyChanged();
    }
  }

  Future<void> retryOfficialInstall() async {
    officialInstallError.value = null;
    await ensureOfficialInstalled(force: true);
    if (officialInstallError.value != null) {
      throw Exception(officialInstallError.value);
    }
  }

  /// Transactional install: fetch all bodies, write disk (remote), then prefs index.
  ///
  /// [onScriptFetched] fires after each prelude/script body is downloaded
  /// (for install progress UI). [onFetchProgress] carries step counts.
  /// Local checkout packs skip disk cache writes.
  Future<EnginePack> install(
    String manifestUrl, {
    void Function()? onScriptFetched,
    void Function(PluginScriptFetchProgress progress)? onFetchProgress,
  }) => _withInstallLock(
    () => _installUnlocked(
      manifestUrl,
      onScriptFetched: onScriptFetched,
      onFetchProgress: onFetchProgress,
    ),
  );

  Future<EnginePack> _installUnlocked(
    String manifestUrl, {
    void Function()? onScriptFetched,
    void Function(PluginScriptFetchProgress progress)? onFetchProgress,
  }) async {
    final requestedUrl = manifestUrl.trim();
    manifestUrl = await _substituteUnreachableLocalManifest(requestedUrl);
    final remappedFromLocal =
        requestedUrl != manifestUrl && isLocalManifestUrl(requestedUrl);
    final body = await _fetchText(manifestUrl);
    final map = jsonDecode(body) as Map<String, dynamic>;
    try {
      PluginContract.validateManifest(map);
    } on FormatException catch (e) {
      throw Exception('invalid manifest: ${e.message}');
    }
    final all = await listPacksRaw();
    EnginePack? previous;
    for (final p in all) {
      if (p.sourceUrl == manifestUrl ||
          (remappedFromLocal && p.sourceUrl == requestedUrl)) {
        previous = p;
        break;
      }
    }
    final enabledById = previous == null
        ? null
        : {for (final p in previous.plugins) p.id: p.enabled};
    var pack = EnginePack.fromJson(map, sourceUrl: manifestUrl);
    if (previous != null) {
      pack = pack.copyWith(
        enabled: previous.enabled,
        plugins: enabledById == null
            ? pack.plugins
            : [
                for (final p in pack.plugins)
                  p.copyWith(enabled: enabledById[p.id] ?? p.enabled),
              ],
      );
    }

    // Plugin ids are pack-local (RFC-094). Scripts/disk already key by
    // urlHash+pluginId. Cross-pack duplicates are allowed — resolve with
    // sourceUrl at run time. Same ForjaHQ slot (cloud vs `.env`) still OK.

    final scripts = <String, String>{}; // pluginId -> body
    final preludes = <String, String>{}; // prelude path -> body
    final missing = <String>[];
    final localCheckout = isLocalManifestUrl(manifestUrl);

    final preludesNeeded = <String>{
      if (pack.prelude.isNotEmpty) pack.prelude,
      for (final p in pack.plugins)
        if (p.prelude.isNotEmpty) p.prelude,
    };
    final scriptsNeeded = [
      for (final p in pack.plugins)
        if (p.entry.isNotEmpty && p.needsScript) p,
    ];

    // Manifest `bundle` lists pack files to fetch. Empty → derive from entries.
    // Always pull pack-relative `nav.icon` bitmaps so the shell rail can paint
    // from disk after install (CDN Image.network fails stick after offline).
    final navIcons = <String>{
      for (final p in pack.plugins)
        if (_isPackRelativeAssetPath(p.nav?['icon']?.toString()))
          p.nav!['icon'].toString().trim(),
    };
    final filesToFetch = <String>[
      ...{
        if (pack.bundle.isNotEmpty)
          ...pack.bundle
        else ...{
          ...preludesNeeded,
          for (final p in scriptsNeeded) p.entry,
        },
        ...navIcons,
      },
    ];
    final fetchTotal = 1 + filesToFetch.length;
    var fetchDone = 0;

    void tick(String label) {
      fetchDone++;
      onScriptFetched?.call();
      onFetchProgress?.call(
        PluginScriptFetchProgress(
          completed: fetchDone,
          total: fetchTotal,
          label: label,
          sourceUrl: manifestUrl,
        ),
      );
    }

    // Splash / banner: pack name only — never enumerate every file path.
    final packLabel = 'Installing ${pack.name}…';
    tick(packLabel);

    final byPath = <String, String>{};
    final byPathBytes = <String, List<int>>{};

    // Sign-out keeps JS under the profile scope but clears prefs. Prefer disk
    // before CDN so splash does not re-download every pack (issue 259).
    if (!localCheckout) {
      var reused = 0;
      for (final plugin in scriptsNeeded) {
        final body = await PluginScriptDiskStore.loadEngineScript(
          sourceUrl: manifestUrl,
          pluginId: plugin.id,
        );
        if (body == null || body.isEmpty) continue;
        byPath[plugin.entry] = body;
        byPathBytes[plugin.entry] = utf8.encode(body);
        reused++;
      }
      for (final prelude in preludesNeeded) {
        if (byPathBytes.containsKey(prelude)) continue;
        final body = await PluginScriptDiskStore.loadEnginePrelude(
          sourceUrl: manifestUrl,
          preludeEntry: prelude,
        );
        if (body == null || body.isEmpty) continue;
        byPath[prelude] = body;
        byPathBytes[prelude] = utf8.encode(body);
        reused++;
      }
      for (final path in filesToFetch) {
        if (byPathBytes.containsKey(path)) continue;
        final bytes = await PluginScriptDiskStore.loadPackRelativeFileBytes(
          sourceUrl: manifestUrl,
          relative: path,
        );
        if (bytes == null || bytes.isEmpty) continue;
        byPathBytes[path] = bytes;
        final lower = path.toLowerCase();
        if (!lower.endsWith('.wasm')) {
          try {
            final text = utf8.decode(bytes);
            if (text.isNotEmpty) byPath[path] = text;
          } catch (_) {}
        }
        reused++;
      }
      if (reused > 0) {
        // Count disk hits as completed steps so the splash bar moves.
        fetchDone = 1 + [
          for (final path in filesToFetch)
            if (byPathBytes.containsKey(path)) path,
        ].length;
        onFetchProgress?.call(
          PluginScriptFetchProgress(
            completed: fetchDone,
            total: fetchTotal,
            label: packLabel,
            sourceUrl: manifestUrl,
          ),
        );
        debugPrint(
          '[PluginInstall] reuse disk for ${pack.name} '
          '($reused file(s), skip CDN)',
        );
      }
    }

    final toFetch = [
      for (final path in filesToFetch)
        if (!byPathBytes.containsKey(path)) path,
    ];
    await Future.wait([
      for (final path in toFetch)
        () async {
          final url = resolveScriptUrl(manifestUrl, path);
          try {
            final bytes = await _fetchBytes(url);
            if (bytes.isEmpty) {
              missing.add(path);
              return;
            }
            byPathBytes[path] = bytes;
            // JS entry/prelude need UTF-8 text; binary (.wasm) stays bytes-only.
            final lower = path.toLowerCase();
            if (!lower.endsWith('.wasm')) {
              try {
                final text = utf8.decode(bytes);
                if (text.isNotEmpty) byPath[path] = text;
              } catch (_) {
                // Non-text asset listed in bundle — bytes-only is fine.
              }
            }
            tick(packLabel);
          } catch (_) {
            missing.add(path);
          }
        }(),
    ]);

    for (final prelude in preludesNeeded) {
      final text = byPath[prelude];
      if (text == null || text.isEmpty) {
        if (!missing.contains(prelude) &&
            !missing.contains('prelude:$prelude')) {
          missing.add('prelude:$prelude');
        }
        continue;
      }
      preludes[prelude] = text;
    }
    for (final plugin in scriptsNeeded) {
      final text = byPath[plugin.entry];
      if (text == null || text.isEmpty) {
        if (!missing.contains(plugin.entry) && !missing.contains(plugin.id)) {
          missing.add(plugin.id);
        }
        continue;
      }
      scripts[plugin.id] = text;
    }
    if (missing.isNotEmpty) {
      throw Exception(
        'manifest install failed: missing scripts: ${missing.join(', ')}',
      );
    }

    final scriptPaths = <String>{
      ...preludesNeeded,
      for (final p in scriptsNeeded) p.entry,
    };
    try {
      PluginInstallValidator.validateBeforeCommit(
        manifestUrl: manifestUrl,
        manifest: map,
        pack: pack,
        scripts: scripts,
        preludes: preludes,
        packFiles: {
          for (final e in byPathBytes.entries)
            if (!scriptPaths.contains(e.key)) e.key: e.value,
        },
      );
    } on FormatException catch (e) {
      throw Exception('install validation failed: ${e.message}');
    }

    // Re-read prefs so pack/plugin toggles during download are not overwritten.
    if (previous != null) {
      final fresh = await listPacksRaw();
      for (final p in fresh) {
        if (p.sourceUrl != manifestUrl) continue;
        previous = p;
        break;
      }
      if (previous != null) {
        final enabledById = {for (final p in previous.plugins) p.id: p.enabled};
        pack = pack.copyWith(
          enabled: previous.enabled,
          plugins: [
            for (final p in pack.plugins)
              p.copyWith(enabled: enabledById[p.id] ?? p.enabled),
          ],
        );
      }
    }

    // Commit disk (remote only) + prefs index only after all fetches succeed.
    if (!localCheckout) {
      for (final e in preludes.entries) {
        await PluginScriptDiskStore.saveEnginePrelude(
          sourceUrl: manifestUrl,
          preludeEntry: e.key,
          body: e.value,
        );
      }
      for (final e in scripts.entries) {
        await PluginScriptDiskStore.saveEngineScript(
          sourceUrl: manifestUrl,
          pluginId: e.key,
          body: e.value,
        );
      }
      for (final e in byPathBytes.entries) {
        if (scriptPaths.contains(e.key)) continue;
        await PluginScriptDiskStore.savePackRelativeFile(
          sourceUrl: manifestUrl,
          relative: e.key,
          bytes: e.value,
        );
      }
    }

    // Drop scripts removed from this pack on refresh.
    if (previous != null) {
      final nextIds = {for (final p in pack.plugins) p.id};
      final nextPreludes = {
        for (final p in pack.plugins)
          if (p.prelude.isNotEmpty) p.prelude,
      };
      final prefs = await _prefs;
      for (final p in previous.plugins) {
        if (!nextIds.contains(p.id)) {
          if (!localCheckout) {
            await PluginScriptDiskStore.removeEngineScript(
              sourceUrl: manifestUrl,
              pluginId: p.id,
            );
          }
          await prefs.remove(scriptPrefsKey(manifestUrl, p.id));
        }
        if (p.prelude.isNotEmpty && !nextPreludes.contains(p.prelude)) {
          if (!localCheckout) {
            await PluginScriptDiskStore.removeEnginePrelude(
              sourceUrl: manifestUrl,
              preludeEntry: p.prelude,
            );
          }
          await prefs.remove(preludePrefsKey(manifestUrl, p.prelude));
        }
      }
    }

    final packIdx = all.indexWhere((a) => a.sourceUrl == manifestUrl);
    if (packIdx >= 0) {
      all[packIdx] = pack;
    } else {
      all.add(pack);
    }
    if (remappedFromLocal) {
      all.removeWhere((a) => a.sourceUrl == requestedUrl);
      await DeferredRemoteInstallStore.clear(requestedUrl);
      await PendingRemotePurgeStore.clear(requestedUrl);
    }
    await _savePacks(all);
    if (!localCheckout) {
      await PluginScriptDiskStore.saveEnginePackMeta(pack);
    }
    final hubSlot = forjaHqSlot(manifestUrl);
    if (isHubManifestSlot(hubSlot) || isIptvVodManifestSlot(hubSlot)) {
      MetaCache.instance.syncPackVersion(pack.packId, pack.version);
    }
    // Scripts may change at the same semver — always drop cached catalog answers.
    for (final p in pack.plugins) {
      MetaCache.instance.wipePlugin(p.id);
      _localScriptDigests.remove(p.id);
    }
    // Legacy combined hubs pack → wipe so rails re-fetch from split packs.
    if (pack.packId == 'forjahq-hubs') {
      MetaCache.instance.wipeAll();
    }
    // Green Play / Sources RAM + resume extracts must not keep pre-update empties.
    _invalidatePlaybackCachesAfterPackChange();
    _clearOfficialInstallError();
    _scriptRepairAttempted.remove(manifestUrl);
    notifyChanged();
    return pack;
  }

  void _invalidatePlaybackCachesAfterPackChange() {
    CatalogSourcesSessionCache.clearAll();
    unawaited(PlayerStreamExtractCache.clearAll());
  }

  /// Local checkout only — remote packs never download here.
  /// Boot/cloud hydrate: [PluginInstallCoordinator.ensureAllInstalled].
  Future<bool> ensurePackScriptsReady(EnginePack pack) async {
    if (isLegacyAssetPack(pack.sourceUrl)) return true;
    if (!await packNeedsDiskInstall(pack)) return true;
    // Remote lean / missing disk JS: coordinator owns silent download.
    if (!isLocalManifestUrl(pack.sourceUrl)) {
      debugPrint(
        '[engine] scripts missing for ${pack.name} — '
        'awaiting splash/cloud hydrate',
      );
      return false;
    }
    debugPrint('[engine] refreshing local checkout scripts for ${pack.name}');
    try {
      await install(pack.sourceUrl);
      _scriptRepairAttempted.remove(pack.sourceUrl);
      return true;
    } catch (e) {
      debugPrint('[engine] script hydrate failed (${pack.sourceUrl}): $e');
      return false;
    }
  }

  /// Prefer [PluginInstallCoordinator.ensurePluginReady] for visible progress.
  Future<bool> ensurePluginScriptsReady(String pluginId) async {
    final want = pluginId.trim();
    if (want.isEmpty) return false;
    final hit = packPluginFromPacks(await listPacksRaw(), want);
    if (hit == null) return false;
    return ensurePackScriptsReady(hit.pack);
  }

  Future<EnginePack> refresh(String manifestUrl) => install(manifestUrl);

  Future<void> removePack(String sourceUrl, {bool purgeDisk = true}) async {
    final all = await listPacksRaw();
    final victim = all.where((a) => a.sourceUrl == sourceUrl).toList();
    all.removeWhere((a) => a.sourceUrl == sourceUrl);
    for (final pack in victim) {
      await _purgePackScriptStorage(pack, purgeDisk: purgeDisk);
      for (final p in pack.plugins) {
        MetaCache.instance.wipePlugin(p.id);
      }
    }
    await _savePacks(all);
    if (victim.isNotEmpty) {
      _invalidatePlaybackCachesAfterPackChange();
      notifyChanged();
    }
  }

  Future<void> setPluginEnabled({
    required String sourceUrl,
    required String pluginId,
    required bool enabled,
  }) async {
    final all = await listPacksRaw();
    final next = <EnginePack>[];
    for (final pack in all) {
      if (pack.sourceUrl != sourceUrl) {
        next.add(pack);
        continue;
      }
      next.add(
        pack.copyWithPlugins([
          for (final p in pack.plugins)
            p.id == pluginId ? p.copyWith(enabled: enabled) : p,
        ]),
      );
    }
    await _savePacks(next);
  }

  bool? _legacyPluginEnabled(List<EnginePack> packs, String pluginId) {
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (p.id != pluginId) continue;
        return pack.enabled && p.enabled;
      }
    }
    return null;
  }

  Future<bool> liveCapabilityEnabled({
    required String sourceUrl,
    required EnginePlugin plugin,
    required String capability,
  }) async {
    if (!plugin.isLiveSportPlugin) {
      return plugin.enabled;
    }
    final prefs = await _prefs;
    final key = LiveSportCapabilities.capabilityPrefsKey(
      sourceUrl,
      plugin.id,
      capability,
    );
    final stored = prefs.getBool(key);
    if (stored != null) return stored;
    return LiveSportCapabilities.defaultEnabled(plugin, capability);
  }

  Future<bool> isLiveCapabilityActive({
    required EnginePack pack,
    required EnginePlugin plugin,
    required String capability,
  }) async {
    if (!pack.enabled) return false;
    if (!plugin.isLiveSportPlugin) {
      if (!plugin.enabled) return false;
      return pack.isPluginActive(plugin);
    }
    // live_sport: Settings prefs + app first-run defaults only.
    return liveCapabilityEnabled(
      sourceUrl: pack.sourceUrl,
      plugin: plugin,
      capability: capability,
    );
  }

  Future<void> setLiveCapabilityEnabled({
    required String sourceUrl,
    required String pluginId,
    required String capability,
    required bool enabled,
  }) async {
    final prefs = await _prefs;
    final key = LiveSportCapabilities.capabilityPrefsKey(
      sourceUrl,
      pluginId,
      capability,
    );
    await prefs.setBool(key, enabled);
    notifyChanged();
  }

  /// One-time: retired twin plugin ids on `legacyIds` → capability prefs.
  /// Runs for any pack that declares `liveLegacyIds` (no pack id / slot filter).
  Future<void> migrateLegacyLiveSportPacksIfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_liveSportMigrationKey) == true) return;

    var packs = await listPacksRaw();
    final capabilityWrites = <String, bool>{};

    for (final pack in packs) {
      for (final p in pack.plugins) {
        final legacy = p.liveLegacyIds;
        if (legacy == null) continue;
        final catalogOld = legacy.catalog;
        final liveOld = legacy.resolve;
        final catalogOn = catalogOld == null
            ? null
            : _legacyPluginEnabled(packs, catalogOld);
        final resolveOn = liveOld == null
            ? null
            : _legacyPluginEnabled(packs, liveOld);
        if (catalogOn != null) {
          capabilityWrites[LiveSportCapabilities.capabilityPrefsKey(
                pack.sourceUrl,
                p.id,
                LiveSportCapabilities.catalog,
              )] =
              catalogOn;
        }
        if (resolveOn != null) {
          capabilityWrites[LiveSportCapabilities.capabilityPrefsKey(
                pack.sourceUrl,
                p.id,
                LiveSportCapabilities.resolve,
              )] =
              resolveOn;
        }
      }
    }

    for (final entry in capabilityWrites.entries) {
      await prefs.setBool(entry.key, entry.value);
    }

    await prefs.setBool(_liveSportMigrationKey, true);
    notifyChanged();
  }

  /// Pack master switch — does not change per-plugin [EnginePlugin.enabled].
  Future<void> setPackEnabled({
    required String sourceUrl,
    required bool enabled,
  }) async {
    final all = await listPacksRaw();
    final next = <EnginePack>[];
    var changed = false;
    for (final pack in all) {
      if (pack.sourceUrl != sourceUrl) {
        next.add(pack);
        continue;
      }
      if (pack.enabled == enabled) {
        next.add(pack);
        continue;
      }
      next.add(pack.copyWith(enabled: enabled));
      changed = true;
    }
    if (changed) await _savePacks(next);
  }

  /// Enable or disable every plugin in [pluginIds] for one pack.
  Future<void> setPluginsEnabled({
    required String sourceUrl,
    required Set<String> pluginIds,
    required bool enabled,
  }) async {
    if (pluginIds.isEmpty) return;
    final all = await listPacksRaw();
    final next = <EnginePack>[];
    var changed = false;
    for (final pack in all) {
      if (pack.sourceUrl != sourceUrl) {
        next.add(pack);
        continue;
      }
      next.add(
        pack.copyWithPlugins([
          for (final p in pack.plugins)
            pluginIds.contains(p.id) && p.enabled != enabled
                ? p.copyWith(enabled: enabled)
                : p,
        ]),
      );
      changed = pack.plugins.any(
        (p) => pluginIds.contains(p.id) && p.enabled != enabled,
      );
    }
    if (changed) await _savePacks(next);
  }

  /// Pack root `prelude` from a local checkout manifest (torrent pack pattern).
  Future<String> _manifestPreludeFromLocalCheckout(String sourceUrl) async {
    final manifest = _asLocalFile(sourceUrl);
    if (manifest == null || !await manifest.exists()) return '';
    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map) return '';
      return (decoded['prelude'] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Load plugin JS (+ optional prelude) for [plugin] from [sourceUrl] pack.
  /// Local checkout packs always read from disk so JS edits apply without reinstall.
  Future<String?> loadScript({
    required String sourceUrl,
    required EnginePlugin plugin,
    String packPrelude = '',
  }) async {
    if (kDebugMode &&
        (plugin.isTorrent ||
            plugin.isKitPlugin ||
            plugin.id.startsWith('catalog-') ||
            plugin.supportsLiveBroadcast ||
            plugin.isLiveResolve)) {
      final String? devUrl;
      if (plugin.isTorrent) {
        devUrl = devTorrentManifestUrl();
      } else if (plugin.isLiveSportPlugin ||
          plugin.isLiveResolve ||
          plugin.supportsLiveResolve) {
        devUrl = devLiveManifestUrl();
      } else if (plugin.isKitPlugin) {
        devUrl = _asLocalFile(sourceUrl)?.path;
      } else {
        devUrl = devCatalogManifestUrl();
      }
      if (devUrl != null) {
        final fromCheckout = await _loadScriptFromLocalManifest(
          manifestUrl: devUrl,
          plugin: plugin,
          packPrelude: packPrelude,
        );
        if (fromCheckout != null && fromCheckout.isNotEmpty) {
          _maybeNotifyLocalScriptChanged(plugin.id, fromCheckout);
          return fromCheckout;
        }
      }
    }

    var preludeEntry = plugin.prelude.trim().isNotEmpty
        ? plugin.prelude.trim()
        : packPrelude.trim();
    if (preludeEntry.isEmpty) {
      preludeEntry = await _manifestPreludeFromLocalCheckout(sourceUrl);
    }
    final localManifest = _asLocalFile(sourceUrl);
    if (localManifest != null) {
      final fromCheckout = await _loadScriptFromLocalManifest(
        manifestUrl: sourceUrl,
        plugin: plugin,
        preludeEntry: preludeEntry,
      );
      if (fromCheckout != null && fromCheckout.isNotEmpty) {
        _maybeNotifyLocalScriptChanged(plugin.id, fromCheckout);
      }
      return fromCheckout;
    }

    var code = await PluginScriptDiskStore.loadEngineScript(
      sourceUrl: sourceUrl,
      pluginId: plugin.id,
    );
    if (code == null || code.isEmpty) {
      // Lazy migrate leftover prefs key.
      final prefs = await _prefs;
      final cached = prefs.getString(scriptPrefsKey(sourceUrl, plugin.id));
      if (cached == null || cached.isEmpty) return null;
      await PluginScriptDiskStore.saveEngineScript(
        sourceUrl: sourceUrl,
        pluginId: plugin.id,
        body: cached,
      );
      await prefs.remove(scriptPrefsKey(sourceUrl, plugin.id));
      code = cached;
    }

    if (preludeEntry.isNotEmpty) {
      var shared = await PluginScriptDiskStore.loadEnginePrelude(
        sourceUrl: sourceUrl,
        preludeEntry: preludeEntry,
      );
      if (shared == null || shared.isEmpty) {
        final prefs = await _prefs;
        final pre = prefs.getString(preludePrefsKey(sourceUrl, preludeEntry));
        if (pre != null && pre.isNotEmpty) {
          await PluginScriptDiskStore.saveEnginePrelude(
            sourceUrl: sourceUrl,
            preludeEntry: preludeEntry,
            body: pre,
          );
          await prefs.remove(preludePrefsKey(sourceUrl, preludeEntry));
          shared = pre;
        }
      }
      if (shared != null && shared.isNotEmpty) {
        code = '$shared\n$code';
      }
    }
    return code;
  }

  Future<String?> _loadScriptFromLocalManifest({
    required String manifestUrl,
    required EnginePlugin plugin,
    String packPrelude = '',
    String preludeEntry = '',
  }) async {
    if (plugin.entry.isEmpty) return null;
    final localManifest = _asLocalFile(manifestUrl);
    if (localManifest == null) return null;

    var prelude = preludeEntry.trim();
    if (prelude.isEmpty) {
      prelude = plugin.prelude.trim().isNotEmpty
          ? plugin.prelude.trim()
          : packPrelude.trim();
    }
    if (prelude.isEmpty) {
      prelude = await _manifestPreludeFromLocalCheckout(manifestUrl);
    }

    final scriptPath = resolveScriptUrl(manifestUrl, plugin.entry);
    final scriptFile = File(scriptPath);
    if (!scriptFile.existsSync()) return null;
    var code = await scriptFile.readAsString();
    if (prelude.isNotEmpty) {
      final preludePath = resolveScriptUrl(manifestUrl, prelude);
      final preludeFile = File(preludePath);
      if (preludeFile.existsSync()) {
        final shared = await preludeFile.readAsString();
        if (shared.isNotEmpty) code = '$shared\n$code';
      }
    }
    return code;
  }

  void _maybeNotifyLocalScriptChanged(String pluginId, String body) {
    final id = pluginId.trim();
    if (id.isEmpty || body.isEmpty) return;
    final digest = md5.convert(utf8.encode(body)).toString();
    final prev = _localScriptDigests[id];
    if (prev == digest) return;
    _localScriptDigests[id] = digest;
    if (prev == null) return;
    debugPrint('[engine] $id script changed — invalidating caches');
    MetaCache.instance.wipePlugin(id);
    _invalidatePlaybackCachesAfterPackChange();
    notifyChanged();
  }

  /// Resolve [pluginId] across packs — prefer active (pack + plugin on).
  static EnginePlugin? pluginFromPacks(
    List<EnginePack> packs,
    String pluginId,
  ) => packPluginFromPacks(packs, pluginId)?.plugin;

  /// Resolve [pluginId] to owning pack + plugin (prefer active).
  static ({EnginePack pack, EnginePlugin plugin})? packPluginFromPacks(
    List<EnginePack> packs,
    String pluginId, {
    String? sourceUrl,
  }) {
    final wantUrl = sourceUrl?.trim() ?? '';
    ({EnginePack pack, EnginePlugin plugin})? inactive;
    for (final pack in packs) {
      if (wantUrl.isNotEmpty && pack.sourceUrl != wantUrl) continue;
      for (final p in pack.plugins) {
        if (p.id != pluginId) continue;
        if (pack.isPluginActive(p)) return (pack: pack, plugin: p);
        inactive ??= (pack: pack, plugin: p);
      }
    }
    return inactive;
  }

  /// Resolve [pluginId] to its owning pack + plugin.
  ///
  /// Pass [sourceUrl] when known (hub KitShell / community packs). Without it,
  /// prefers an active plugin when the same id exists in multiple packs
  /// (dev `.env` + disabled cloud shadow; legacy provider path).
  Future<({EnginePack pack, EnginePlugin plugin})?> findPlugin(
    String pluginId, {
    String? sourceUrl,
  }) async =>
      packPluginFromPacks(await listPacksRaw(), pluginId, sourceUrl: sourceUrl);

  Future<void>? _hydrateLeanInFlight;

  /// Rewrite lean `manifestUrl`s to published catalog URLs when the opaque
  /// [forjaHqSlot] matches. Profile rows may still hold a retired host
  /// (e.g. old monorepo GitHub path) after admin moves `plugin_packs.manifest_url`.
  static List<Map<String, dynamic>> rewriteLeanUrlsThroughCatalog(
    Iterable<Map<String, dynamic>> rows,
    Iterable<OfficialForjaHqPack> catalog,
  ) {
    final slotToUrl = <String, String>{};
    for (final pack in catalog) {
      final url = pack.manifestUrl.trim();
      if (url.isEmpty) continue;
      final slot = forjaHqSlot(url);
      if (slot == null) continue;
      slotToUrl[slot] = url;
    }
    if (slotToUrl.isEmpty) {
      return [
        for (final raw in rows)
          if (raw is Map<String, dynamic>)
            Map<String, dynamic>.from(raw)
          else if (raw is Map)
            Map<String, dynamic>.from(raw),
      ];
    }
    final out = <Map<String, dynamic>>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final url = (row['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty) {
        out.add(row);
        continue;
      }
      final slot = forjaHqSlot(url);
      final catalogUrl = slot == null ? null : slotToUrl[slot];
      if (catalogUrl != null && catalogUrl != url) {
        row['manifestUrl'] = catalogUrl;
      }
      out.add(row);
    }
    return out;
  }

  /// Sync / cloud lean rows — URL (+ optional name) only. **No network.**
  ///
  /// When [purgeRemovedImmediately] is false (mid-session), packs missing from
  /// cloud stay on disk until the uninstall prompt / pending purge / next boot.
  ///
  /// Unreachable local paths from another machine are not turned into install
  /// stubs. A **readable** local ForjaHQ checkout still satisfies a same-slot
  /// remote URL so soft-pull does not purge a working Mac install.
  ///
  /// Same-slot **remote → remote** URL changes (catalog / profile move): the
  /// cloud URL wins — old remote install is purged and the new URL is added
  /// for download (issue 267).
  Future<LeanApplyResult> applyLeanManifestUrls(
    Iterable<Map<String, dynamic>> rows, {
    bool removeMissingUserPacks = true,
    bool purgeRemovedImmediately = true,
  }) async {
    final remote = <String, ({String? name, String? version})>{};
    for (final raw in rows) {
      final url = (raw['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty || isLegacyAssetPack(url)) {
        continue;
      }
      // Other-device absolute paths: keep for membership if we already have
      // that exact install; never invent a download stub we cannot fetch.
      if (isLocalManifestUrl(url) && !(await _localManifestExists(url))) {
        continue;
      }

      final name = (raw['name'] as String?)?.trim();
      final version = (raw['version'] as String?)?.trim();
      remote[url] = (
        name: (name != null && name.isNotEmpty) ? name : null,
        version: (version != null && version.isNotEmpty) ? version : null,
      );
    }

    final all = await listPacksRaw();
    final next = <EnginePack>[];
    final victims = <EnginePack>[];
    final added = <LeanPackDelta>[];
    final removed = <LeanPackDelta>[];
    var changed = false;
    // Remote lean URLs already satisfied by a kept local/remote pack (same slot).
    final satisfiedRemote = <String>{};

    for (final pack in all) {
      if (isLegacyAssetPack(pack.sourceUrl)) {
        next.add(pack);
        continue;
      }
      final remoteKey = _leanRemoteKeyForPack(remote, pack.sourceUrl);
      if (removeMissingUserPacks && remoteKey == null) {
        // Readable local checkout is device-local membership — soft-pull must
        // not delete it just because cloud omitted the absolute path (or has
        // a same-slot remote twin).
        if (isLocalManifestUrl(pack.sourceUrl) &&
            await _localManifestExists(pack.sourceUrl)) {
          next.add(pack);
          satisfiedRemote.add(pack.sourceUrl);
          _markLeanSlotSatisfied(satisfiedRemote, remote, pack.sourceUrl);
          continue;
        }
        final stub = pack.plugins.isEmpty;
        if (stub || purgeRemovedImmediately) {
          victims.add(pack);
          changed = true;
          if (!stub) {
            removed.add(
              LeanPackDelta(manifestUrl: pack.sourceUrl, name: pack.name),
            );
          }
          await DeferredRemoteInstallStore.clear(pack.sourceUrl);
        } else {
          next.add(pack);
          removed.add(
            LeanPackDelta(manifestUrl: pack.sourceUrl, name: pack.name),
          );
        }
        continue;
      }
      if (remoteKey != null && remoteKey != pack.sourceUrl) {
        final localOk = isLocalManifestUrl(pack.sourceUrl) &&
            await _localManifestExists(pack.sourceUrl);
        if (localOk) {
          // Readable checkout wins over same-slot remote URL.
          satisfiedRemote.add(remoteKey);
          satisfiedRemote.add(pack.sourceUrl);
          _markLeanSlotSatisfied(satisfiedRemote, remote, pack.sourceUrl);
          next.add(pack);
          continue;
        }
        // Remote URL moved (or dead local path) — cloud URL wins.
        debugPrint(
          '[engine] lean URL migrate ${pack.sourceUrl} → $remoteKey',
        );
        victims.add(pack);
        changed = true;
        await DeferredRemoteInstallStore.clear(pack.sourceUrl);
        continue;
      }
      if (remoteKey != null) {
        satisfiedRemote.add(remoteKey);
        satisfiedRemote.add(pack.sourceUrl);
        _markLeanSlotSatisfied(satisfiedRemote, remote, pack.sourceUrl);
      }
      final lean = remoteKey != null ? remote[remoteKey] : null;
      final leanName = lean?.name;
      if (leanName != null && pack.plugins.isEmpty && pack.name != leanName) {
        next.add(
          EnginePack(
            sourceUrl: pack.sourceUrl,
            packId: pack.packId,
            name: leanName,
            version: lean?.version ?? pack.version,
            plugins: pack.plugins,
            enabled: pack.enabled,
          ),
        );
        changed = true;
      } else {
        next.add(pack);
      }
    }

    final present = next.map((p) => p.sourceUrl).toSet();
    for (final entry in remote.entries) {
      if (present.contains(entry.key) || satisfiedRemote.contains(entry.key)) {
        await PendingRemotePurgeStore.clear(entry.key);
        continue;
      }
      // Prefer on-disk pack.json + scripts for this profile over a lean stub
      // that would force a full re-download (issue 259).
      final diskPack = await PluginScriptDiskStore.loadEnginePackMeta(
        entry.key,
      );
      if (diskPack != null &&
          diskPack.plugins.isNotEmpty &&
          await _diskHasAllScripts(diskPack)) {
        next.add(
          diskPack.copyWith(
            name: entry.value.name ?? diskPack.name,
            version: entry.value.version ?? diskPack.version,
          ),
        );
        changed = true;
        await PendingRemotePurgeStore.clear(entry.key);
        continue;
      }
      next.add(
        EnginePack(
          sourceUrl: entry.key,
          packId: EnginePack.packIdFromSourceUrl(entry.key),
          name: entry.value.name ?? 'Forja pack',
          version: entry.value.version ?? '0.0.0',
          plugins: const [],
        ),
      );
      added.add(LeanPackDelta(manifestUrl: entry.key, name: entry.value.name));
      changed = true;
      await PendingRemotePurgeStore.clear(entry.key);
    }

    if (changed) {
      for (final pack in victims) {
        await _purgePackScriptStorage(pack);
      }
      await _savePacks(next);
    }

    if (purgeRemovedImmediately) {
      await PendingRemotePurgeStore.clearAll();
    }

    return LeanApplyResult(added: added, removed: removed);
  }

  /// Cloud lean row key for [sourceUrl], or null if the pack is not in [remote].
  /// Matches exact URL, else same opaque [forjaHqSlot] (local checkout ↔ remote).
  static String? _leanRemoteKeyForPack(
    Map<String, ({String? name, String? version})> remote,
    String sourceUrl,
  ) {
    if (remote.containsKey(sourceUrl)) return sourceUrl;
    final slot = forjaHqSlot(sourceUrl);
    if (slot == null) return null;
    for (final key in remote.keys) {
      if (forjaHqSlot(key) == slot) return key;
    }
    return null;
  }

  /// Mark every remote lean URL that shares [sourceUrl]'s opaque slot.
  static void _markLeanSlotSatisfied(
    Set<String> satisfiedRemote,
    Map<String, ({String? name, String? version})> remote,
    String sourceUrl,
  ) {
    final slot = forjaHqSlot(sourceUrl);
    if (slot == null) return;
    for (final key in remote.keys) {
      if (forjaHqSlot(key) == slot) satisfiedRemote.add(key);
    }
  }

  Future<void> _purgeRetiredOfficialPacks() async {
    await listPacksRaw();
  }

  /// No-op. Membership JS downloads via
  /// [PluginInstallCoordinator.ensureAllInstalled] / mid-session cloud auto-install.
  Future<void> hydrateLeanInstalled() {
    return _hydrateLeanInFlight ??= _hydrateLeanInstalledImpl().whenComplete(
      () {
        _hydrateLeanInFlight = null;
      },
    );
  }

  static bool _leanHydrateSkipLogged = false;

  Future<void> _hydrateLeanInstalledImpl() async {
    if (_leanHydrateSkipLogged) return;
    _leanHydrateSkipLogged = true;
    debugPrint(
      '[engine] lean hydrate no-op — coordinator owns membership download',
    );
  }
}
