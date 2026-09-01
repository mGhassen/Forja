import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/cache.dart';
import 'package:forja/shared/engine/live_sport_capabilities.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_contract.dart';
import 'package:forja/shared/engine/plugin_install_validator.dart';
import 'package:forja/shared/engine/plugin_script_disk_store.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Owns engine pack install / refresh / remove / script cache.
///
/// [EngineService] stays the extract host and delegates pack lifecycle here.
/// Remote JS bodies live on disk ([PluginScriptDiskStore]); pack metadata in prefs.
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
  static const _legacyMonolithWipedKey = 'engine_js_legacy_forjahq_wiped';
  static const _liveSportMigrationKey = 'live_sport_unified_migration_v1';

  static const _legacyBundledSourceUrlProviders = 'asset:providers/engine.json';
  static const _legacyBundledSourceUrl = 'asset:engine_js/engine.json';
  static const _legacyAssetBundledSourceUrl = 'asset:plugins/engine.json';

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String?> officialInstallError =
      ValueNotifier<String?>(null);

  Future<void>? _officialEnsureFuture;
  bool _officialUpdateChecked = false;
  final Set<String> _scriptRepairAttempted = {};

  /// Test-only HTTP client override (MockClient).
  @visibleForTesting
  http.Client? debugHttpClient;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

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
  /// installed pack at the same conventional slot (remote URL).
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
    return url;
  }

  Future<String> _fetchText(String url) async {
    final file = _asLocalFile(url);
    if (file != null) {
      if (!await file.exists()) {
        throw Exception('file not found: ${file.path}');
      }
      return file.readAsString();
    }
    final resp = await _httpGet(Uri.parse(url)).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('plugin fetch $url'),
    );
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    return resp.body;
  }

  /// Path-pattern helper for Settings grouping — not pack inventory.
  @visibleForTesting
  static String? forjaHqSlot(String url) {
    final path = url.trim().replaceAll('\\', '/').toLowerCase();
    const core = {
      'plugins/providers/manifest.json': 'providers',
      'plugins/live/manifest.json': 'live',
      'plugins/torrent/manifest.json': 'torrent',
      'plugins/hubs/home/manifest.json': 'home',
      'plugins/hubs/manifest.json': 'home',
      'plugins/iptv/vod/manifest.json': 'iptv-vod',
      // Legacy path before IPTV VOD left `plugins/hubs/`.
      'plugins/hubs/iptv/manifest.json': 'iptv-vod',
    };
    for (final e in core.entries) {
      if (path.endsWith(e.key)) return e.value;
    }
    final hub = RegExp(r'plugins/hubs/([^/]+)/manifest\.json$').firstMatch(path);
    if (hub != null) return hub.group(1);
    return null;
  }

  /// Hub manifest slot (any path under `plugins/hubs/` except monolith home alias).
  static bool isHubManifestSlot(String? slot) {
    if (slot == null || slot.isEmpty) return false;
    return slot != 'providers' &&
        slot != 'live' &&
        slot != 'catalog' &&
        slot != 'torrent' &&
        slot != 'iptv-vod';
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
  static String packKindKey(EnginePack pack) {
    final slot = forjaHqSlot(pack.sourceUrl);
    if (slot != null) {
      return switch (slot) {
        'providers' => packKindProviders,
        'live' => packKindLive,
        'catalog' => packKindCatalog,
        'torrent' => packKindTorrent,
        'iptv-vod' => packKindIptv,
        _ when isHubManifestSlot(slot) => packKindHubs,
        _ => packKindOther,
      };
    }
    if (pack.plugins.any((p) => p.types.contains('iptv'))) return packKindIptv;
    if (pack.plugins.any((p) => p.isHubCatalog)) return packKindHubs;
    if (pack.plugins.any((p) => p.isLiveSportPlugin || p.isLive)) {
      return packKindLive;
    }
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

  /// Retired split live catalog pack — merged into [plugins/live/manifest.json].
  static bool isRetiredCatalogManifestUrl(String url) {
    final path = url.trim().replaceAll('\\', '/').toLowerCase();
    return path.contains('/plugins/catalog/manifest.json') ||
        forjaHqSlot(url) == 'catalog';
  }

  static bool isRetiredCatalogPack(EnginePack pack) =>
      pack.packId == 'forjahq-catalog' ||
      isRetiredCatalogManifestUrl(pack.sourceUrl);

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
  Future<bool> packNeedsDiskInstall(EnginePack pack) async {
    if (isLegacyAssetPack(pack.sourceUrl)) return false;
    if (isLocalManifestUrl(pack.sourceUrl)) return false;
    if (pack.plugins.isEmpty) return true;
    for (final p in pack.plugins) {
      if (p.entry.isEmpty || !p.needsScript) continue;
      if (!await PluginScriptDiskStore.hasEngineScript(
        sourceUrl: pack.sourceUrl,
        pluginId: p.id,
      )) {
        return true;
      }
      if (p.prelude.isNotEmpty &&
          !await PluginScriptDiskStore.hasEnginePrelude(
            sourceUrl: pack.sourceUrl,
            preludeEntry: p.prelude,
          )) {
        return true;
      }
    }
    return false;
  }

  Future<void> _purgePackScriptStorage(EnginePack pack) async {
    if (!isLocalManifestUrl(pack.sourceUrl)) {
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
    final raw = prefs.getString(_packsKeyV2);
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
    await prefs.setString(
      _packsKeyV2,
      jsonEncode([for (final p in packs) p.toJson()]),
    );
    notifyChanged();
  }

  Future<List<EnginePack>> listPacksRaw() async {
    await _migrateV1IfNeeded();
    await _wipeLegacyMonolithIfNeeded();
    await migrateScriptsToDiskIfNeeded();
    final prefs = await _prefs;
    final raw = prefs.getString(_packsKeyV2);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final packs = [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
      final withoutAssets = await _purgeLegacyAssetPacks(packs);
      return _purgeRetiredCatalogPacks(withoutAssets);
    } catch (_) {
      return [];
    }
  }

  /// Remove the pre-split single ForjaHQ pack so the three packs can install.
  Future<void> _wipeLegacyMonolithIfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_legacyMonolithWipedKey) == true) return;
    final raw = prefs.getString(_packsKeyV2);
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
      await prefs.setString(
        _packsKeyV2,
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
    final v2 = prefs.getString(_packsKeyV2);
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
      await prefs.setString(
        _packsKeyV2,
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

  Future<List<EnginePack>> _purgeLegacyAssetPacks(List<EnginePack> packs) async {
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

  Future<List<EnginePack>> _purgeRetiredCatalogPacks(List<EnginePack> packs) async {
    final keep = <EnginePack>[];
    final victims = <EnginePack>[];
    for (final p in packs) {
      if (isRetiredCatalogPack(p)) {
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
    debugPrint(
      '[engine] purged ${victims.length} retired catalog pack(s) from prefs',
    );
    return keep;
  }

  Future<void> repairMissingScripts(List<EnginePack> packs) async {
    for (final pack in packs) {
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      if (isLocalManifestUrl(pack.sourceUrl)) continue;
      if (_scriptRepairAttempted.contains(pack.sourceUrl)) continue;
      if (!await packNeedsDiskInstall(pack)) continue;
      _scriptRepairAttempted.add(pack.sourceUrl);
      debugPrint('[engine] repairing missing scripts for ${pack.name}');
      try {
        await install(pack.sourceUrl);
      } catch (e) {
        debugPrint('[engine] repair failed for ${pack.sourceUrl}: $e');
      }
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

  /// Debug checkout: install `plugins/torrent/manifest.json` when
  /// `FORJA_HQ_TORRENT_MANIFEST_URL` or `FORJA_REPO_ROOT` is set and no torrent
  /// slot pack is installed yet.
  @visibleForTesting
  static String? devTorrentManifestUrl() {
    if (!kDebugMode) return null;
    var explicit =
        const String.fromEnvironment('FORJA_HQ_TORRENT_MANIFEST_URL').trim();
    if (explicit.isEmpty) {
      explicit =
          Platform.environment['FORJA_HQ_TORRENT_MANIFEST_URL']?.trim() ?? '';
    }
    if (explicit.isNotEmpty) return explicit;

    var root = const String.fromEnvironment('FORJA_REPO_ROOT').trim();
    if (root.isEmpty) {
      root = Platform.environment['FORJA_REPO_ROOT']?.trim() ?? '';
    }
    if (root.isEmpty) return null;
    final normalized = root.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    return '$normalized/plugins/torrent/manifest.json';
  }

  Future<void> ensureDevTorrentPackSeeded() async {
    if (!kDebugMode) return;
    final url = devTorrentManifestUrl();
    if (url == null) return;
    final file = _asLocalFile(url);
    if (file == null || !await file.exists()) return;

    final packs = await listPacksRaw();
    if (packs.any((p) => forjaHqSlot(p.sourceUrl) == 'torrent')) return;

    debugPrint('[engine] dev seed ForjaHQ Torrent from $url');
    try {
      await install(url);
      notifyChanged();
    } catch (e) {
      debugPrint('[engine] dev torrent seed failed: $e');
    }
  }

  /// Hydrate lean stubs and refresh remote packs when needed.
  Future<void> ensureOfficialInstalled({bool force = false}) async {
    if (_officialEnsureFuture != null) {
      await _officialEnsureFuture;
      return;
    }
    final run = () async {
      try {
        await ensureDevTorrentPackSeeded();
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
        } else if (!_officialUpdateChecked) {
          _officialUpdateChecked = true;
          final pending = <Future<void>>[];
          for (final pack in packs) {
            if (pack.plugins.isEmpty) continue;
            if (_asLocalFile(pack.sourceUrl) != null) continue;
            pending.add(_maybeRefreshIfNewer(pack.sourceUrl, pack));
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

  Future<void> _maybeRefreshIfNewer(
    String manifestUrl,
    EnginePack local,
  ) =>
      maybeRefreshIfNewer(manifestUrl, local);

  /// Public for [PluginInstallCoordinator] — install if remote version newer.
  Future<bool> maybeRefreshIfNewer(
    String manifestUrl,
    EnginePack local,
  ) async {
    if (isLocalManifestUrl(manifestUrl)) {
      debugPrint('[engine] ${local.name} local checkout — refreshing scripts');
      await install(manifestUrl);
      return true;
    }
    try {
      final body = await _fetchText(manifestUrl);
      final map = jsonDecode(body);
      if (map is! Map) return false;
      final remoteVer = (map['version'] as String?)?.trim() ?? '';
      if (remoteVer.isEmpty) return false;
      if (compareEngineSemver(remoteVer, local.version) <= 0) return false;
      debugPrint(
        '[engine] ${local.name} $remoteVer > ${local.version} — refreshing',
      );
      await install(manifestUrl);
      return true;
    } catch (e) {
      debugPrint('[engine] ${local.name} version check failed: $e');
      return false;
    }
  }

  void _clearOfficialInstallError() {
    if (officialInstallError.value != null) {
      officialInstallError.value = null;
      notifyChanged();
    }
  }

  Future<void> retryOfficialInstall() async {
    officialInstallError.value = null;
    _officialUpdateChecked = false;
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
  }) =>
      _withInstallLock(
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
    manifestUrl = await _substituteUnreachableLocalManifest(manifestUrl);
    if (isRetiredCatalogManifestUrl(manifestUrl)) {
      await removePack(manifestUrl);
      throw Exception(
        'ForjaHQ Catalog pack retired — live schedules live in '
        'plugins/live/manifest.json',
      );
    }
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
      if (p.sourceUrl == manifestUrl) {
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

    // Refuse plugin id collisions with other packs. Same ForjaHQ slot
    // (providers/live/catalog) may overlap — cloud vs `.env` dual install.
    final slot = forjaHqSlot(manifestUrl);
    for (final other in all) {
      if (other.sourceUrl == manifestUrl) continue;
      if (slot != null && forjaHqSlot(other.sourceUrl) == slot) continue;
      final otherIds = {for (final p in other.plugins) p.id};
      for (final p in pack.plugins) {
        if (otherIds.contains(p.id)) {
          throw Exception(
            'plugin id "${p.id}" already installed from ${other.name} '
            '(${other.sourceUrl})',
          );
        }
      }
    }

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
    final fetchTotal = 1 + preludesNeeded.length + scriptsNeeded.length;
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

    tick('Fetched ${pack.name} manifest');

    for (final prelude in preludesNeeded) {
      final preludeUrl = resolveScriptUrl(manifestUrl, prelude);
      try {
        final text = await _fetchText(preludeUrl);
        if (text.isEmpty) {
          missing.add('prelude:$prelude');
          continue;
        }
        preludes[prelude] = text;
        tick('Downloaded $prelude');
      } catch (_) {
        missing.add('prelude:$prelude');
      }
    }
    for (final plugin in scriptsNeeded) {
      final scriptUrl = resolveScriptUrl(manifestUrl, plugin.entry);
      try {
        final text = await _fetchText(scriptUrl);
        if (text.isEmpty) {
          missing.add(plugin.id);
          continue;
        }
        scripts[plugin.id] = text;
        tick('Downloaded ${plugin.name}');
      } catch (_) {
        missing.add(plugin.id);
      }
    }
    if (missing.isNotEmpty) {
      throw Exception(
        'manifest install failed — missing scripts: ${missing.join(', ')}',
      );
    }

    try {
      await PluginInstallValidator.validateBeforeCommit(
        manifestUrl: manifestUrl,
        manifest: map,
        pack: pack,
        scripts: scripts,
        preludes: preludes,
      );
    } on FormatException catch (e) {
      throw Exception('install validation failed: ${e.message}');
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
    await _savePacks(all);
    final hubSlot = forjaHqSlot(manifestUrl);
    if (isHubManifestSlot(hubSlot) || isIptvVodManifestSlot(hubSlot)) {
      CatalogCache.instance.syncHubPackVersion(pack.packId, pack.version);
      // Scripts may change at the same semver — always drop this pack's answers.
      for (final p in pack.plugins) {
        CatalogCache.instance.wipePlugin(p.id);
      }
    }
    // Legacy combined hubs pack → wipe so rails re-fetch from split packs.
    if (pack.packId == 'forjahq-hubs') {
      CatalogCache.instance.wipeAll();
    }
    _clearOfficialInstallError();
    _scriptRepairAttempted.remove(manifestUrl);
    notifyChanged();
    return pack;
  }

  /// Fetch disk JS for [pack] when metadata landed before scripts (lean sync).
  /// Prefer [PluginInstallCoordinator.ensurePluginReady] for visible progress.
  Future<bool> ensurePackScriptsReady(EnginePack pack) async {
    if (isLegacyAssetPack(pack.sourceUrl)) return true;
    if (!await packNeedsDiskInstall(pack)) return true;
    debugPrint('[engine] hydrating scripts for ${pack.name}');
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

  Future<void> removePack(String sourceUrl) async {
    final all = await listPacksRaw();
    final victim = all.where((a) => a.sourceUrl == sourceUrl).toList();
    all.removeWhere((a) => a.sourceUrl == sourceUrl);
    for (final pack in victim) {
      await _purgePackScriptStorage(pack);
    }
    await _savePacks(all);
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

  /// One-time migration from twin `catalog-*` / `live-*` packs to unified ids.
  Future<void> migrateLegacyLiveSportPacksIfNeeded() async {
    final prefs = await _prefs;
    if (prefs.getBool(_liveSportMigrationKey) == true) return;

    var packs = await listPacksRaw();
    final capabilityWrites = <String, bool>{};

    for (final entry in LiveSportCapabilities.legacyTwinIds.entries) {
      final newId = entry.key;
      final (catalogOld, liveOld) = entry.value;
      final catalogOn = _legacyPluginEnabled(packs, catalogOld);
      final resolveOn =
          liveOld == null ? null : _legacyPluginEnabled(packs, liveOld);

      for (final pack in packs) {
        if (forjaHqSlot(pack.sourceUrl) != 'live') continue;
        for (final p in pack.plugins) {
          if (p.id != newId) continue;
          if (catalogOn != null) {
            capabilityWrites[
              LiveSportCapabilities.capabilityPrefsKey(
                pack.sourceUrl,
                newId,
                LiveSportCapabilities.catalog,
              )
            ] = catalogOn;
          }
          if (resolveOn != null) {
            capabilityWrites[
              LiveSportCapabilities.capabilityPrefsKey(
                pack.sourceUrl,
                newId,
                LiveSportCapabilities.resolve,
              )
            ] = resolveOn;
          }
        }
      }
    }

    for (final entry in capabilityWrites.entries) {
      await prefs.setBool(entry.key, entry.value);
    }

    final next = [
      for (final pack in packs)
        if (!isRetiredCatalogPack(pack)) pack,
    ];
    if (next.length != packs.length) {
      packs = next;
      await _savePacks(packs);
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
    var preludeEntry = plugin.prelude.trim().isNotEmpty
        ? plugin.prelude.trim()
        : packPrelude.trim();
    if (preludeEntry.isEmpty) {
      preludeEntry = await _manifestPreludeFromLocalCheckout(sourceUrl);
    }
    final localManifest = _asLocalFile(sourceUrl);
    if (localManifest != null) {
      if (plugin.entry.isEmpty) return null;
      final scriptPath = resolveScriptUrl(sourceUrl, plugin.entry);
      final scriptFile = File(scriptPath);
      if (!scriptFile.existsSync()) return null;
      var code = await scriptFile.readAsString();
      if (preludeEntry.isNotEmpty) {
        final preludePath = resolveScriptUrl(sourceUrl, preludeEntry);
        final preludeFile = File(preludePath);
        if (preludeFile.existsSync()) {
          final shared = await preludeFile.readAsString();
          if (shared.isNotEmpty) code = '$shared\n$code';
        }
      }
      return code;
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

  /// Resolve [pluginId] across packs — prefer active (pack + plugin on).
  static EnginePlugin? pluginFromPacks(
    List<EnginePack> packs,
    String pluginId,
  ) =>
      packPluginFromPacks(packs, pluginId)?.plugin;

  /// Resolve [pluginId] to owning pack + plugin (prefer active).
  static ({EnginePack pack, EnginePlugin plugin})? packPluginFromPacks(
    List<EnginePack> packs,
    String pluginId,
  ) {
    ({EnginePack pack, EnginePlugin plugin})? inactive;
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (p.id != pluginId) continue;
        if (pack.isPluginActive(p)) return (pack: pack, plugin: p);
        inactive ??= (pack: pack, plugin: p);
      }
    }
    return inactive;
  }

  /// Resolve [pluginId] to its owning pack + plugin.
  /// Prefers an active plugin when the same id exists in multiple packs
  /// (dev `.env` + disabled cloud shadow).
  Future<({EnginePack pack, EnginePlugin plugin})?> findPlugin(
    String pluginId,
  ) async =>
      packPluginFromPacks(await listPacksRaw(), pluginId);

  Future<void>? _hydrateLeanInFlight;

  /// Sync / cloud lean rows — URL (+ optional name) only. **No network.**
  /// Full packs land via [hydrateLeanInstalled] on first Settings/Sources use.
  Future<void> applyLeanManifestUrls(
    Iterable<Map<String, dynamic>> rows, {
    bool removeMissingUserPacks = true,
  }) async {
    final remote = <String, ({String? name, String? version})>{};
    for (final raw in rows) {
      final url = (raw['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty ||
          isLegacyAssetPack(url) ||
          isRetiredCatalogManifestUrl(url)) {
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
    var changed = false;

    for (final pack in all) {
      if (isLegacyAssetPack(pack.sourceUrl)) {
        next.add(pack);
        continue;
      }
      if (removeMissingUserPacks && !remote.containsKey(pack.sourceUrl)) {
        victims.add(pack);
        changed = true;
        continue;
      }
      final lean = remote[pack.sourceUrl];
      final leanName = lean?.name;
      if (leanName != null &&
          pack.plugins.isEmpty &&
          pack.name != leanName) {
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
      if (present.contains(entry.key)) continue;
      next.add(
        EnginePack(
          sourceUrl: entry.key,
          packId: EnginePack.packIdFromSourceUrl(entry.key),
          name: entry.value.name ?? 'Forja pack',
          version: entry.value.version ?? '0.0.0',
          plugins: const [],
        ),
      );
      changed = true;
    }

    if (changed) {
      for (final pack in victims) {
        await _purgePackScriptStorage(pack);
      }
      await _savePacks(next);
    }

    unawaited(ensureOfficialInstalled());
  }

  Future<void> _purgeRetiredOfficialPacks() async {
    await listPacksRaw();
  }

  /// Fetch manifests for lean stubs (`plugins` empty). Idempotent.
  Future<void> hydrateLeanInstalled() {
    return _hydrateLeanInFlight ??= _hydrateLeanInstalledImpl().whenComplete(
      () {
        _hydrateLeanInFlight = null;
      },
    );
  }

  Future<void> _hydrateLeanInstalledImpl() async {
    final all = await listPacksRaw();
    for (final pack in all) {
      if (pack.plugins.isNotEmpty) continue;
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      if (isRetiredCatalogPack(pack)) continue;
      if (_asLocalFile(pack.sourceUrl) != null &&
          !await _localManifestExists(pack.sourceUrl)) {
        if (isRetiredCatalogManifestUrl(pack.sourceUrl)) {
          await removePack(pack.sourceUrl);
        }
        continue;
      }
      try {
        final url = await _substituteUnreachableLocalManifest(pack.sourceUrl);
        await install(url);
      } catch (e) {
        if (isRetiredCatalogManifestUrl(pack.sourceUrl)) {
          await removePack(pack.sourceUrl);
          continue;
        }
        debugPrint(
          '[engine] lean hydrate failed (${pack.sourceUrl}): $e',
        );
      }
    }
  }
}
