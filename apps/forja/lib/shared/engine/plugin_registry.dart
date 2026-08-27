import 'dart:async';
import 'dart:convert';

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

  /// Official ForjaHQ manifest URL from `FORJA_HQ_MANIFEST_URL`.
  static const officialManifestUrl = String.fromEnvironment(
    'FORJA_HQ_MANIFEST_URL',
  );

  static const _packsKeyV1 = 'engine_js_packs_v1';
  static const _packsKeyV2 = 'engine_js_packs_v2';
  static const _scriptPrefixV1 = 'engine_js_script_';
  static const _preludePrefixV1 = 'engine_js_prelude_';
  static const _scriptPrefixV2 = 'engine_js_script_v2_';
  static const _preludePrefixV2 = 'engine_js_prelude_v2_';
  static const _migratedKey = 'engine_js_packs_v2_migrated';

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

  static bool isOfficialPack(String sourceUrl) =>
      sourceUrl == officialManifestUrl;

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
    final mu = Uri.parse(manifestUrl);
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    final path = mu.path.endsWith('/')
        ? '${mu.path}$filename'
        : '${mu.path.substring(0, mu.path.lastIndexOf('/') + 1)}$filename';
    return mu.replace(path: path).toString();
  }

  /// First boot / ensure: install or refresh ForjaHQ when version is newer.
  Future<void> ensureOfficialInstalled({bool force = false}) async {
    if (officialManifestUrl.trim().isEmpty) {
      _officialInstallFailed = true;
      officialInstallError.value =
          'FORJA_HQ_MANIFEST_URL missing — set in .env / dart-define';
      notifyChanged();
      return;
    }
    final packs = await listPacksRaw();
    EnginePack? local;
    for (final p in packs) {
      if (p.sourceUrl == officialManifestUrl) {
        local = p;
        break;
      }
    }
    if (local != null && !force) {
      _clearOfficialInstallError();
      if (!_officialUpdateChecked) {
        _officialUpdateChecked = true;
        await _maybeRefreshOfficialIfNewer(local);
      }
      return;
    }
    if (!force && _officialInstallFailed) return;
    if (_officialEnsureFuture != null) {
      await _officialEnsureFuture;
      return;
    }
    final run = () async {
      try {
        await install(officialManifestUrl);
        _clearOfficialInstallError();
        _officialUpdateChecked = true;
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

  Future<void> _maybeRefreshOfficialIfNewer(EnginePack local) async {
    try {
      final resp = await _httpGet(Uri.parse(officialManifestUrl));
      if (resp.statusCode != 200) return;
      final map = jsonDecode(resp.body);
      if (map is! Map) return;
      final remoteVer = (map['version'] as String?)?.trim() ?? '';
      if (remoteVer.isEmpty) return;
      if (compareEngineSemver(remoteVer, local.version) <= 0) return;
      debugPrint(
        '[engine] ForjaHQ $remoteVer > ${local.version} — refreshing',
      );
      await install(officialManifestUrl);
    } catch (e) {
      debugPrint('[engine] ForjaHQ version check failed: $e');
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
    if (officialManifestUrl.trim().isEmpty) {
      throw Exception(
        'FORJA_HQ_MANIFEST_URL missing — set in .env / dart-define',
      );
    }
    _officialInstallFailed = false;
    officialInstallError.value = null;
    _officialUpdateChecked = false;
    await install(officialManifestUrl);
    _clearOfficialInstallError();
  }

  /// Transactional install: fetch all bodies, then write prefs.
  Future<EnginePack> install(String manifestUrl) async {
    final resp = await _httpGet(Uri.parse(manifestUrl));
    if (resp.statusCode != 200) {
      throw Exception('manifest HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
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
      final pr = await _httpGet(Uri.parse(preludeUrl));
      if (pr.statusCode != 200 || pr.body.isEmpty) {
        missing.add('prelude:$prelude');
        continue;
      }
      preludes[prelude] = pr.body;
    }
    for (final plugin in pack.plugins) {
      if (plugin.entry.isEmpty) continue;
      if (!plugin.isHttp && !plugin.isHop) continue;
      final scriptUrl = resolveScriptUrl(manifestUrl, plugin.entry);
      final sr = await _httpGet(Uri.parse(scriptUrl));
      if (sr.statusCode != 200 || sr.body.isEmpty) {
        missing.add(plugin.id);
        continue;
      }
      scripts[plugin.id] = sr.body;
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
    if (manifestUrl == officialManifestUrl) {
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

  /// Load plugin JS (+ optional prelude) for [plugin] from [sourceUrl] pack.
  Future<String?> loadScript({
    required String sourceUrl,
    required EnginePlugin plugin,
  }) async {
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
}
