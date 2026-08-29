import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/cache.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Owns engine pack install / refresh / remove / script cache.
///
/// [EngineService] stays the extract host and delegates pack lifecycle here.
class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  /// Official ForjaHQ Providers pack (`FORJA_HQ_PROVIDERS_MANIFEST_URL`).
  static const officialProvidersManifestUrl = String.fromEnvironment(
    'FORJA_HQ_PROVIDERS_MANIFEST_URL',
  );

  /// Official ForjaHQ Live pack (`FORJA_HQ_LIVE_MANIFEST_URL`).
  static const officialLiveManifestUrl = String.fromEnvironment(
    'FORJA_HQ_LIVE_MANIFEST_URL',
  );

  /// Official ForjaHQ Catalog pack (`FORJA_HQ_CATALOG_MANIFEST_URL`).
  static const officialCatalogManifestUrl = String.fromEnvironment(
    'FORJA_HQ_CATALOG_MANIFEST_URL',
  );

  /// Official ForjaHQ Home hub pack (`FORJA_HQ_HOME_MANIFEST_URL`).
  static const officialHomeManifestUrl = String.fromEnvironment(
    'FORJA_HQ_HOME_MANIFEST_URL',
  );

  /// Official ForjaHQ Anime hub pack (`FORJA_HQ_ANIME_MANIFEST_URL`).
  static const officialAnimeManifestUrl = String.fromEnvironment(
    'FORJA_HQ_ANIME_MANIFEST_URL',
  );

  /// Official ForjaHQ Asian Drama hub pack (`FORJA_HQ_ASIAN_DRAMA_MANIFEST_URL`).
  static const officialAsianDramaManifestUrl = String.fromEnvironment(
    'FORJA_HQ_ASIAN_DRAMA_MANIFEST_URL',
  );

  /// Official ForjaHQ Arabic hub pack (`FORJA_HQ_ARABIC_MANIFEST_URL`).
  static const officialArabicManifestUrl = String.fromEnvironment(
    'FORJA_HQ_ARABIC_MANIFEST_URL',
  );

  /// Dev switch (`FORJA_HQ_FORCE_PLUGIN_ENV`):
  /// - `true` → install from dart-define / `.env` URLs; disable cloud ForjaHQ.
  /// - `false` → prefer cloud Profile ForjaHQ URLs when present; disable `.env` locals.
  static const forcePluginEnv = bool.fromEnvironment(
    'FORJA_HQ_FORCE_PLUGIN_ENV',
    defaultValue: false,
  );

  static const officialPackIds = {
    'forjahq-providers',
    'forjahq-live',
    'forjahq-catalog',
    'forjahq-home',
    'forjahq-anime',
    'forjahq-asian-drama',
    'forjahq-arabic',
  };

  static const _cloudOfficialKey = 'engine_js_cloud_forjahq_urls_v1';

  /// Slot resolve order — all six are required.
  static const officialSlotOrder = [
    'providers',
    'live',
    'catalog',
    'home',
    'anime',
    'asian_drama',
    'arabic',
  ];

  /// Hub catalog slots (one pack per shell hub tab).
  static const hubSlotIds = {'home', 'anime', 'asian_drama', 'arabic'};

  /// Packs that must be configured for the engine to work at all.
  static const requiredOfficialPackCount = 7;

  /// All configured official pack URLs from dart-define.
  static List<String> get officialManifestUrls => [
        for (final u in [
          officialProvidersManifestUrl,
          officialLiveManifestUrl,
          officialCatalogManifestUrl,
          officialHomeManifestUrl,
          officialAnimeManifestUrl,
          officialAsianDramaManifestUrl,
          officialArabicManifestUrl,
        ])
          if (u.trim().isNotEmpty) u.trim(),
      ];

  /// @Deprecated Use [officialProvidersManifestUrl] or [officialManifestUrls].
  static const officialManifestUrl = officialProvidersManifestUrl;

  static const _packsKeyV1 = 'engine_js_packs_v1';
  static const _packsKeyV2 = 'engine_js_packs_v2';
  static const _scriptPrefixV1 = 'engine_js_script_';
  static const _preludePrefixV1 = 'engine_js_prelude_';
  static const _scriptPrefixV2 = 'engine_js_script_v2_';
  static const _preludePrefixV2 = 'engine_js_prelude_v2_';
  static const _migratedKey = 'engine_js_packs_v2_migrated';
  static const _legacyMonolithWipedKey = 'engine_js_legacy_forjahq_wiped';

  static const _legacyBundledSourceUrlProviders = 'asset:providers/engine.json';
  static const _legacyBundledSourceUrl = 'asset:engine_js/engine.json';
  static const _legacyAssetBundledSourceUrl = 'asset:plugins/engine.json';

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String?> officialInstallError =
      ValueNotifier<String?>(null);

  Future<void>? _officialEnsureFuture;
  bool _officialInstallFailed = false;
  bool _officialUpdateChecked = false;
  /// `FORJA_HQ_FORCE_PLUGIN_ENV=true` disk reinstall — once per process.
  bool _forceEnvApplied = false;
  /// Cloud ForjaHQ applied for `FORCE=false` — once until cloud URLs change.
  bool _cloudOfficialApplied = false;
  /// Slot → cloud manifest URL (`providers` / `live` / `catalog`).
  final Map<String, String> _cloudOfficialBySlot = {};
  bool _cloudOfficialLoaded = false;
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

  static bool isOfficialPack(String sourceUrl) {
    if (officialManifestUrls.contains(sourceUrl)) return true;
    if (!forcePluginEnv &&
        instance._cloudOfficialBySlot.values.contains(sourceUrl)) {
      return true;
    }
    return false;
  }

  /// `providers` / `live` / `catalog` / `home` / `anime` / `asian_drama`
  /// when [url] is a ForjaHQ pack path.
  @visibleForTesting
  static String? forjaHqSlot(String url) {
    final path = url.trim().replaceAll('\\', '/').toLowerCase();
    if (path.endsWith('plugins/providers/manifest.json')) return 'providers';
    if (path.endsWith('plugins/live/manifest.json')) return 'live';
    if (path.endsWith('plugins/catalog/manifest.json')) return 'catalog';
    if (path.endsWith('plugins/hubs/home/manifest.json')) return 'home';
    if (path.endsWith('plugins/hubs/anime/manifest.json')) return 'anime';
    if (path.endsWith('plugins/hubs/asian_drama/manifest.json')) {
      return 'asian_drama';
    }
    if (path.endsWith('plugins/hubs/arabic/manifest.json')) return 'arabic';
    // Legacy monolith hubs pack — treat as shadow of home so it gets replaced.
    if (path.endsWith('plugins/hubs/manifest.json')) return 'home';
    return null;
  }

  /// Cloud/GitHub (or other) URL that mirrors an official ForjaHQ pack path but
  /// is not the current dart-define URL.
  static bool isShadowingOfficialManifestUrl(String sourceUrl) {
    if (officialManifestUrls.contains(sourceUrl) ||
        isLegacyAssetPack(sourceUrl)) {
      return false;
    }
    return forjaHqSlot(sourceUrl) != null;
  }

  /// Pack that shadows the active keep-set of official URLs.
  static bool isShadowOfficialPack(EnginePack pack, Set<String> keepUrls) {
    if (keepUrls.contains(pack.sourceUrl)) return false;
    if (pack.packId == 'forjahq-hubs') return true; // legacy monolith hubs
    if (officialPackIds.contains(pack.packId)) return true;
    return forjaHqSlot(pack.sourceUrl) != null;
  }

  static bool isLegacyMonolithPack(EnginePack pack) => pack.packId == 'forjahq';

  static bool isLegacyAssetPack(String sourceUrl) =>
      sourceUrl.startsWith('asset:') ||
      sourceUrl == _legacyAssetBundledSourceUrl ||
      sourceUrl == _legacyBundledSourceUrlProviders ||
      sourceUrl == _legacyBundledSourceUrl;

  static String urlHash(String sourceUrl) => EnginePack.urlHash(sourceUrl);

  static String scriptPrefsKey(String sourceUrl, String pluginId) =>
      '$_scriptPrefixV2${urlHash(sourceUrl)}_$pluginId';

  static String preludePrefsKey(String sourceUrl, String preludeEntry) =>
      '$_preludePrefixV2${urlHash(sourceUrl)}_'
      '${Uri.encodeComponent(preludeEntry)}';

  static const _missingOfficialUrlsMessage =
      'FORJA_HQ_PROVIDERS/LIVE/CATALOG/HOME/ANIME/ASIAN_DRAMA/ARABIC_MANIFEST_URL '
      'missing — set in .env / dart-define';

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
      return _purgeLegacyAssetPacks(packs);
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
        for (final p in pack.plugins) {
          await prefs.remove(scriptPrefsKey(pack.sourceUrl, p.id));
          if (p.prelude.isNotEmpty) {
            await prefs.remove(preludePrefsKey(pack.sourceUrl, p.prelude));
          }
        }
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
            await prefs.setString(
              scriptPrefsKey(pack.sourceUrl, p.id),
              old,
            );
          }
          if (p.prelude.isNotEmpty) {
            final oldPre = prefs.getString(
              '$_preludePrefixV1${Uri.encodeComponent(p.prelude)}',
            );
            if (oldPre != null && oldPre.isNotEmpty) {
              await prefs.setString(
                preludePrefsKey(pack.sourceUrl, p.prelude),
                oldPre,
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
    final prefs = await _prefs;
    for (final pack in victims) {
      for (final p in pack.plugins) {
        await prefs.remove(scriptPrefsKey(pack.sourceUrl, p.id));
        if (p.prelude.isNotEmpty) {
          await prefs.remove(preludePrefsKey(pack.sourceUrl, p.prelude));
        }
      }
    }
    await _savePacks(keep);
    return keep;
  }

  Future<void> repairMissingScripts(List<EnginePack> packs) async {
    final prefs = await _prefs;
    for (final pack in packs) {
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      if (_scriptRepairAttempted.contains(pack.sourceUrl)) continue;
      var needs = false;
      for (final p in pack.plugins) {
        if (p.entry.isEmpty) continue;
        if (!p.needsScript) continue;
        final cached = prefs.getString(scriptPrefsKey(pack.sourceUrl, p.id));
        if (cached == null || cached.isEmpty) {
          needs = true;
          break;
        }
        if (p.prelude.isNotEmpty) {
          final pre =
              prefs.getString(preludePrefsKey(pack.sourceUrl, p.prelude));
          if (pre == null || pre.isEmpty) {
            needs = true;
            break;
          }
        }
      }
      if (!needs) continue;
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

  /// Disable (not remove) packs that are not in [keepUrls] but share ForjaHQ
  /// pack ids / canonical paths. Enable packs in [keepUrls].
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
        if (!pack.enabled) {
          debugPrint(
            '[engine] ForjaHQ: enable ${pack.packId} (${pack.sourceUrl})',
          );
          next.add(pack.copyWith(enabled: true));
          changed = true;
        } else {
          next.add(pack);
        }
        continue;
      }
      if (!isShadowOfficialPack(pack, keep)) {
        next.add(pack);
        continue;
      }
      if (!pack.enabled) {
        next.add(pack);
        continue;
      }
      debugPrint(
        '[engine] ForjaHQ: disable ${pack.packId} (${pack.sourceUrl})',
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

  Future<void> _loadCloudOfficialFromPrefs() async {
    if (_cloudOfficialLoaded) return;
    _cloudOfficialLoaded = true;
    final prefs = await _prefs;
    final raw = prefs.getString(_cloudOfficialKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final e in decoded.entries) {
        final slot = e.key.toString();
        final url = e.value?.toString().trim() ?? '';
        if (url.isEmpty || forjaHqSlot(url) != slot) continue;
        _cloudOfficialBySlot[slot] = url;
      }
    } catch (_) {}
  }

  Future<void> _persistCloudOfficial() async {
    final prefs = await _prefs;
    await prefs.setString(
      _cloudOfficialKey,
      jsonEncode(_cloudOfficialBySlot),
    );
  }

  void _rememberCloudOfficialUrl(String url) {
    final slot = forjaHqSlot(url);
    if (slot == null) return;
    if (_asLocalFile(url) != null) return; // never treat local path as cloud
    final prev = _cloudOfficialBySlot[slot];
    if (prev == url) return;
    _cloudOfficialBySlot[slot] = url;
    _cloudOfficialApplied = false;
  }

  Future<void> _discoverCloudOfficialFromInstalled() async {
    for (final pack in await listPacksRaw()) {
      final slot = forjaHqSlot(pack.sourceUrl);
      if (slot == null) continue;
      if (_asLocalFile(pack.sourceUrl) != null) continue;
      _cloudOfficialBySlot.putIfAbsent(slot, () => pack.sourceUrl);
    }
  }

  /// Active official URLs: `.env` when [forcePluginEnv], else cloud (fallback `.env`).
  @visibleForTesting
  Future<List<String>> resolveEffectiveOfficialUrls() async {
    final dartUrls = officialManifestUrls;
    if (dartUrls.length < requiredOfficialPackCount) return dartUrls;
    if (forcePluginEnv) return dartUrls;

    await _loadCloudOfficialFromPrefs();
    await _discoverCloudOfficialFromInstalled();

    // Resolve every slot this build configures (all seven when dart-defines are set).
    final wanted = <String>{
      for (final u in dartUrls)
        if (forjaHqSlot(u) != null) forjaHqSlot(u)!,
    };
    final bySlot = <String, String>{};
    for (final s in officialSlotOrder) {
      if (!wanted.contains(s)) continue;
      final cloud = _cloudOfficialBySlot[s];
      if (cloud != null && cloud.isNotEmpty) bySlot[s] = cloud;
    }
    // Fill missing slots from dart-define.
    for (final u in dartUrls) {
      final s = forjaHqSlot(u);
      if (s == null || bySlot.containsKey(s)) continue;
      bySlot[s] = u;
    }
    final out = [
      for (final s in officialSlotOrder)
        if (bySlot[s] != null) bySlot[s]!,
    ];
    return out.length == wanted.length ? out : dartUrls;
  }

  /// First boot / ensure: install or refresh each official pack when needed.
  ///
  /// [forcePluginEnv] true → dart-define / `.env` once, disable cloud.
  /// false → cloud Profile ForjaHQ when known, disable local `.env` copies.
  Future<void> ensureOfficialInstalled({bool force = false}) async {
    final dartUrls = officialManifestUrls;
    if (dartUrls.length < requiredOfficialPackCount) {
      _officialInstallFailed = true;
      officialInstallError.value = _missingOfficialUrlsMessage;
      notifyChanged();
      return;
    }
    if (_officialEnsureFuture != null) {
      await _officialEnsureFuture;
      return;
    }
    final run = () async {
      try {
        final urls = await resolveEffectiveOfficialUrls();
        final usingCloud =
            !forcePluginEnv && urls.every((u) => _asLocalFile(u) == null);

        final forceEnvReinstall = forcePluginEnv && !_forceEnvApplied;
        final cloudNeedsApply = usingCloud && !_cloudOfficialApplied;
        // Run enable/disable + optional install even when only switching keep-set.
        final mustRun = force || forceEnvReinstall || cloudNeedsApply;

        if (!mustRun && _officialInstallFailed) return;

        if (forceEnvReinstall) {
          debugPrint(
            '[engine] FORJA_HQ_FORCE_PLUGIN_ENV=true: install from dart-define',
          );
        } else if (cloudNeedsApply) {
          debugPrint(
            '[engine] FORJA_HQ_FORCE_PLUGIN_ENV=false: prefer cloud packs',
          );
        }

        await applyOfficialKeepSet(urls);

        final packs = await listPacksRaw();
        final byUrl = {for (final p in packs) p.sourceUrl: p};
        for (final url in urls) {
          final local = byUrl[url];
          if (local == null || local.plugins.isEmpty) {
            await install(url);
          } else if (forceEnvReinstall) {
            // FORCE=true once: reload scripts from dart-define / disk.
            await install(url);
          } else if (!_officialUpdateChecked) {
            await _maybeRefreshOfficialIfNewer(url, local);
          }
        }
        await applyOfficialKeepSet(urls);

        if (forcePluginEnv) {
          _forceEnvApplied = true;
        }
        if (usingCloud) {
          _cloudOfficialApplied = true;
        }
        _officialUpdateChecked = true;
        _clearOfficialInstallError();
      } catch (e) {
        _officialInstallFailed = true;
        // Once-per-process: do not retry-storm when FORCE install fails.
        if (forcePluginEnv) {
          _forceEnvApplied = true;
        }
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        officialInstallError.value = msg;
        notifyChanged();
        debugPrint('[engine] ForjaHQ install failed: $msg');
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

  Future<void> _maybeRefreshOfficialIfNewer(
    String manifestUrl,
    EnginePack local,
  ) async {
    try {
      final body = await _fetchText(manifestUrl);
      final map = jsonDecode(body);
      if (map is! Map) return;
      final remoteVer = (map['version'] as String?)?.trim() ?? '';
      if (remoteVer.isEmpty) return;
      if (compareEngineSemver(remoteVer, local.version) <= 0) return;
      debugPrint(
        '[engine] ${local.name} $remoteVer > ${local.version} — refreshing',
      );
      await install(manifestUrl);
    } catch (e) {
      debugPrint('[engine] ${local.name} version check failed: $e');
    }
  }

  void _clearOfficialInstallError() {
    _officialInstallFailed = false;
    if (officialInstallError.value != null) {
      officialInstallError.value = null;
      notifyChanged();
    }
  }

  Future<void> retryOfficialInstall() async {
    final urls = await resolveEffectiveOfficialUrls();
    if (urls.length < requiredOfficialPackCount) {
      throw Exception(_missingOfficialUrlsMessage);
    }
    _officialInstallFailed = false;
    officialInstallError.value = null;
    _officialUpdateChecked = false;
    _forceEnvApplied = false;
    _cloudOfficialApplied = false;
    await applyOfficialKeepSet(urls);
    for (final url in urls) {
      await install(url);
    }
    await applyOfficialKeepSet(urls);
    if (forcePluginEnv) {
      _forceEnvApplied = true;
    } else if (urls.every((u) => _asLocalFile(u) == null)) {
      _cloudOfficialApplied = true;
    }
    _clearOfficialInstallError();
  }

  /// Transactional install: fetch all bodies, then write prefs.
  Future<EnginePack> install(String manifestUrl) async {
    final body = await _fetchText(manifestUrl);
    final map = jsonDecode(body) as Map<String, dynamic>;
    final schema = map['schema'];
    if (schema != null && schema != 1) {
      throw Exception('unsupported manifest schema: $schema');
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
      if (officialPackIds.contains(pack.packId) &&
          other.packId == pack.packId) {
        continue;
      }
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

    final preludesNeeded = <String>{
      for (final p in pack.plugins)
        if (p.prelude.isNotEmpty) p.prelude,
    };
    for (final prelude in preludesNeeded) {
      final preludeUrl = resolveScriptUrl(manifestUrl, prelude);
      try {
        final text = await _fetchText(preludeUrl);
        if (text.isEmpty) {
          missing.add('prelude:$prelude');
          continue;
        }
        preludes[prelude] = text;
      } catch (_) {
        missing.add('prelude:$prelude');
      }
    }
    for (final plugin in pack.plugins) {
      if (plugin.entry.isEmpty) continue;
      if (!plugin.needsScript) continue;
      final scriptUrl = resolveScriptUrl(manifestUrl, plugin.entry);
      try {
        final text = await _fetchText(scriptUrl);
        if (text.isEmpty) {
          missing.add(plugin.id);
          continue;
        }
        scripts[plugin.id] = text;
      } catch (_) {
        missing.add(plugin.id);
      }
    }
    if (missing.isNotEmpty) {
      throw Exception(
        'manifest install failed — missing scripts: ${missing.join(', ')}',
      );
    }

    // Commit prefs only after all fetches succeed.
    final prefs = await _prefs;
    for (final e in preludes.entries) {
      await prefs.setString(
        preludePrefsKey(manifestUrl, e.key),
        e.value,
      );
    }
    for (final e in scripts.entries) {
      await prefs.setString(
        scriptPrefsKey(manifestUrl, e.key),
        e.value,
      );
    }

    // Drop scripts removed from this pack on refresh.
    if (previous != null) {
      final nextIds = {for (final p in pack.plugins) p.id};
      final nextPreludes = {
        for (final p in pack.plugins)
          if (p.prelude.isNotEmpty) p.prelude,
      };
      for (final p in previous.plugins) {
        if (!nextIds.contains(p.id)) {
          await prefs.remove(scriptPrefsKey(manifestUrl, p.id));
        }
        if (p.prelude.isNotEmpty && !nextPreludes.contains(p.prelude)) {
          await prefs.remove(preludePrefsKey(manifestUrl, p.prelude));
        }
      }
    }

    all.removeWhere((a) => a.sourceUrl == manifestUrl);
    all.add(pack);
    await _savePacks(all);
    if (officialPackIds.contains(pack.packId) &&
        hubSlotIds.contains(forjaHqSlot(manifestUrl))) {
      CatalogCache.instance.syncHubPackVersion(pack.packId, pack.version);
    }
    // Legacy combined hubs pack → wipe so rails re-fetch from split packs.
    if (pack.packId == 'forjahq-hubs') {
      CatalogCache.instance.wipeAll();
    }
    if (isOfficialPack(manifestUrl)) {
      _clearOfficialInstallError();
    }
    _scriptRepairAttempted.remove(manifestUrl);
    return pack;
  }

  Future<EnginePack> refresh(String manifestUrl) => install(manifestUrl);

  Future<void> removePack(String sourceUrl) async {
    final all = await listPacksRaw();
    final victim = all.where((a) => a.sourceUrl == sourceUrl).toList();
    all.removeWhere((a) => a.sourceUrl == sourceUrl);
    final prefs = await _prefs;
    for (final pack in victim) {
      for (final p in pack.plugins) {
        await prefs.remove(scriptPrefsKey(pack.sourceUrl, p.id));
        if (p.prelude.isNotEmpty) {
          await prefs.remove(preludePrefsKey(pack.sourceUrl, p.prelude));
        }
      }
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

  /// Load plugin JS (+ optional prelude) for [plugin] from [sourceUrl] pack.
  /// Local checkout packs always read from disk so JS edits apply without reinstall.
  Future<String?> loadScript({
    required String sourceUrl,
    required EnginePlugin plugin,
  }) async {
    final localManifest = _asLocalFile(sourceUrl);
    if (localManifest != null) {
      if (plugin.entry.isEmpty) return null;
      final scriptPath = resolveScriptUrl(sourceUrl, plugin.entry);
      final scriptFile = File(scriptPath);
      if (!scriptFile.existsSync()) return null;
      var code = await scriptFile.readAsString();
      final prelude = plugin.prelude.trim();
      if (prelude.isNotEmpty) {
        final preludePath = resolveScriptUrl(sourceUrl, prelude);
        final preludeFile = File(preludePath);
        if (preludeFile.existsSync()) {
          final shared = await preludeFile.readAsString();
          if (shared.isNotEmpty) code = '$shared\n$code';
        }
      }
      return code;
    }

    final prefs = await _prefs;
    final cached = prefs.getString(scriptPrefsKey(sourceUrl, plugin.id));
    if (cached == null || cached.isEmpty) return null;
    var code = cached;
    final prelude = plugin.prelude.trim();
    if (prelude.isNotEmpty) {
      final shared = prefs.getString(preludePrefsKey(sourceUrl, prelude));
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
  /// Official ForjaHQ packs are never removed.
  Future<void> applyLeanManifestUrls(
    Iterable<Map<String, dynamic>> rows, {
    bool removeMissingUserPacks = true,
  }) async {
    final remote = <String, ({String? name, String? version})>{};
    var cloudOfficialChanged = false;
    for (final raw in rows) {
      final url = (raw['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty || isLegacyAssetPack(url)) continue;

      final slot = forjaHqSlot(url);
      final isCloudForjaHq =
          slot != null && _asLocalFile(url) == null;

      if (isCloudForjaHq) {
        final prev = _cloudOfficialBySlot[slot];
        _rememberCloudOfficialUrl(url);
        if (prev != url) cloudOfficialChanged = true;
        // FORCE=true: remember URL but do not seed lean hydrate against `.env`.
        if (forcePluginEnv) continue;
      } else if (officialManifestUrls.contains(url) || isOfficialPack(url)) {
        continue;
      }

      final name = (raw['name'] as String?)?.trim();
      final version = (raw['version'] as String?)?.trim();
      remote[url] = (
        name: (name != null && name.isNotEmpty) ? name : null,
        version: (version != null && version.isNotEmpty) ? version : null,
      );
    }

    if (cloudOfficialChanged || _cloudOfficialBySlot.isNotEmpty) {
      await _persistCloudOfficial();
    }

    final all = await listPacksRaw();
    final next = <EnginePack>[];
    final victims = <EnginePack>[];
    var changed = false;
    final keepDart = officialManifestUrls.toSet();

    for (final pack in all) {
      if (isLegacyAssetPack(pack.sourceUrl)) {
        next.add(pack);
        continue;
      }
      // Keep dart-define + cloud ForjaHQ rows; never wipe either side.
      if (keepDart.contains(pack.sourceUrl) ||
          forjaHqSlot(pack.sourceUrl) != null ||
          officialPackIds.contains(pack.packId)) {
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
      final prefs = await _prefs;
      for (final pack in victims) {
        for (final p in pack.plugins) {
          await prefs.remove(scriptPrefsKey(pack.sourceUrl, p.id));
          if (p.prelude.isNotEmpty) {
            await prefs.remove(preludePrefsKey(pack.sourceUrl, p.prelude));
          }
        }
      }
      await _savePacks(next);
    }

    // FORCE=false + cloud ForjaHQ known → switch active packs to cloud.
    if (!forcePluginEnv &&
        _cloudOfficialBySlot.length >= requiredOfficialPackCount &&
        (cloudOfficialChanged || !_cloudOfficialApplied)) {
      _officialInstallFailed = false;
      unawaited(ensureOfficialInstalled(force: true));
    }
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
    final keep = (await resolveEffectiveOfficialUrls()).toSet();
    final all = await listPacksRaw();
    for (final pack in all) {
      if (pack.plugins.isNotEmpty) continue;
      if (isLegacyAssetPack(pack.sourceUrl)) continue;
      // Only hydrate the active official slot URL (cloud or `.env`), not both.
      final slot = forjaHqSlot(pack.sourceUrl);
      if (slot != null && !keep.contains(pack.sourceUrl)) {
        continue;
      }
      if (forcePluginEnv && isShadowingOfficialManifestUrl(pack.sourceUrl)) {
        continue;
      }
      try {
        await install(pack.sourceUrl);
      } catch (e) {
        debugPrint(
          '[engine] lean hydrate failed (${pack.sourceUrl}): $e',
        );
      }
    }
  }
}
