import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Dev: force reinstall from dart-define URLs every ensure, and drop stale
  /// GitHub/cloud installs of the same official pack ids (different sourceUrl).
  /// `FORJA_HQ_FORCE_PLUGIN_ENV=true` via `.env` / `--dart-define`.
  static const forcePluginEnv = bool.fromEnvironment(
    'FORJA_HQ_FORCE_PLUGIN_ENV',
    defaultValue: false,
  );

  static const officialPackIds = {
    'forjahq-providers',
    'forjahq-live',
    'forjahq-catalog',
  };

  /// All configured official pack URLs (providers, live, catalog).
  static List<String> get officialManifestUrls => [
        for (final u in [
          officialProvidersManifestUrl,
          officialLiveManifestUrl,
          officialCatalogManifestUrl,
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

  static bool isOfficialPack(String sourceUrl) =>
      officialManifestUrls.contains(sourceUrl);

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
        if (!p.isHttp && !p.isHop) continue;
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

  /// Drop installed packs with official packIds whose [sourceUrl] is not in
  /// [keepUrls] (e.g. GitHub install after `.env` switched to a local path).
  @visibleForTesting
  Future<void> evictStaleOfficialSiblingPacks(List<String> keepUrls) async {
    final keep = {
      for (final u in keepUrls)
        if (u.trim().isNotEmpty) u.trim(),
    };
    final packs = await listPacksRaw();
    for (final pack in packs) {
      if (!officialPackIds.contains(pack.packId)) continue;
      if (keep.contains(pack.sourceUrl)) continue;
      debugPrint(
        '[engine] FORJA_HQ_FORCE_PLUGIN_ENV: evict stale ${pack.packId} '
        '(${pack.sourceUrl})',
      );
      await removePack(pack.sourceUrl);
    }
  }

  /// First boot / ensure: install or refresh each official pack when needed.
  ///
  /// When [forcePluginEnv] is true, always reinstalls from dart-define URLs and
  /// evicts sibling official packs at other sourceUrls (local `.env` wins).
  Future<void> ensureOfficialInstalled({bool force = false}) async {
    final urls = officialManifestUrls;
    if (urls.length < 3) {
      _officialInstallFailed = true;
      officialInstallError.value =
          'FORJA_HQ_PROVIDERS/LIVE/CATALOG_MANIFEST_URL missing — set in .env / dart-define';
      notifyChanged();
      return;
    }
    final forceEnv = forcePluginEnv;
    final effectiveForce = force || forceEnv;
    if (!effectiveForce && _officialInstallFailed) return;
    if (_officialEnsureFuture != null) {
      await _officialEnsureFuture;
      return;
    }
    final run = () async {
      try {
        if (forceEnv) {
          await evictStaleOfficialSiblingPacks(urls);
          debugPrint(
            '[engine] FORJA_HQ_FORCE_PLUGIN_ENV: reinstalling from dart-define',
          );
        }
        final packs = await listPacksRaw();
        final byUrl = {for (final p in packs) p.sourceUrl: p};
        for (final url in urls) {
          final local = byUrl[url];
          if (local == null || effectiveForce) {
            await install(url);
          } else if (!_officialUpdateChecked) {
            await _maybeRefreshOfficialIfNewer(url, local);
          }
        }
        _officialUpdateChecked = true;
        _clearOfficialInstallError();
      } catch (e) {
        _officialInstallFailed = true;
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
    final urls = officialManifestUrls;
    if (urls.length < 3) {
      throw Exception(
        'FORJA_HQ_PROVIDERS/LIVE/CATALOG_MANIFEST_URL missing — set in .env / dart-define',
      );
    }
    _officialInstallFailed = false;
    officialInstallError.value = null;
    _officialUpdateChecked = false;
    for (final url in urls) {
      await install(url);
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
    if (enabledById != null) {
      pack = pack.copyWithPlugins([
        for (final p in pack.plugins)
          p.copyWith(enabled: enabledById[p.id] ?? p.enabled),
      ]);
    }

    // Refuse plugin id collisions with other packs.
    for (final other in all) {
      if (other.sourceUrl == manifestUrl) continue;
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
      if (!plugin.isHttp && !plugin.isHop) continue;
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

  /// Resolve [pluginId] to its owning pack + plugin (first match).
  Future<({EnginePack pack, EnginePlugin plugin})?> findPlugin(
    String pluginId,
  ) async {
    for (final pack in await listPacksRaw()) {
      for (final p in pack.plugins) {
        if (p.id == pluginId) return (pack: pack, plugin: p);
      }
    }
    return null;
  }

  Future<void>? _hydrateLeanInFlight;

  /// Sync / cloud lean rows — URL (+ optional name) only. **No network.**
  /// Full packs land via [hydrateLeanInstalled] on first Settings/Sources use.
  /// Official ForjaHQ packs are never removed.
  Future<void> applyLeanManifestUrls(
    Iterable<Map<String, dynamic>> rows, {
    bool removeMissingUserPacks = true,
  }) async {
    final remote = <String, ({String? name, String? version})>{};
    for (final raw in rows) {
      final url = (raw['manifestUrl'] as String?)?.trim() ?? '';
      if (url.isEmpty || isOfficialPack(url) || isLegacyAssetPack(url)) {
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
      if (isOfficialPack(pack.sourceUrl) || isLegacyAssetPack(pack.sourceUrl)) {
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

    if (!changed) return;

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
