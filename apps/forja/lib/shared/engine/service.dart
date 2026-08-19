import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:forja/shared/engine/host_resolver.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineService {
  EngineService._();
  static final EngineService instance = EngineService._();

  static const bundledSourceUrl = 'asset:providers/engine.json';
  static const _legacyBundledSourceUrl = 'asset:engine_js/engine.json';
  static const _assetRoot = 'assets/providers';
  static const _packsKey = 'engine_js_packs_v1';
  static const _scriptPrefix = 'engine_js_script_';
  static const _selectedKey = 'engine_js_sources_selected_ids';
  static const _selectAllDefaultKey = 'engine_js_sources_select_all_default';

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  int _extractGeneration = 0;
  Future<void>? _bundledEnsureFuture;
  bool _bundledReady = false;

  static bool isBundled(String sourceUrl) =>
      sourceUrl == bundledSourceUrl || sourceUrl == _legacyBundledSourceUrl;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  void cancelPending() {
    _extractGeneration++;
    EngineRuntime.instance.abortPendingWork();
  }

  Future<void> _syncHopsForRuntime(
    EngineRuntime runtime,
    List<EnginePack> packs,
  ) async {
    final hops = <EnginePlugin>[
      for (final pack in packs)
        for (final p in pack.plugins)
          if (p.isHop) p,
    ];
    runtime.registerHops(hops);
    for (final p in hops) {
      final code = await _loadScript(p);
      if (code != null && code.isNotEmpty) {
        runtime.stashPluginCode(p.id, code);
      }
    }
  }

  Future<List<EnginePack>> listPacks() async {
    await ensureBundledInstalled();
    final prefs = await _prefs;
    final raw = prefs.getString(_packsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<EnginePack>> listSourcesPanelPacks() async {
    final packs = await listPacks();
    return [
      for (final p in packs)
        if (p.plugins.any((pl) => pl.enabled && pl.isExtractable))
          p.copyWithPlugins([
            for (final pl in p.plugins)
              if (pl.isExtractable) pl,
          ]),
    ];
  }

  Future<void> _savePacks(List<EnginePack> packs) async {
    final prefs = await _prefs;
    await prefs.setString(
      _packsKey,
      jsonEncode([for (final p in packs) p.toJson()]),
    );
    changeNotifier.value++;
  }

  Future<void> ensureBundledInstalled() async {
    if (_bundledReady) return;
    _bundledEnsureFuture ??= () async {
      try {
        await _installBundled();
        _bundledReady = true;
      } catch (e) {
        debugPrint('[engine] bundled ensure failed: $e');
      } finally {
        _bundledEnsureFuture = null;
      }
    }();
    await _bundledEnsureFuture;
  }

  Future<List<EnginePack>> _listPacksRaw() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_packsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) EnginePack.fromStored(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _installBundled() async {
    final jsonStr = await rootBundle.loadString('$_assetRoot/engine.json');
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    var pack = EnginePack.fromJson(
      map,
      sourceUrl: bundledSourceUrl,
      bundled: true,
    );
    final prefs = await _prefs;
    for (final plugin in pack.plugins) {
      if (plugin.entry.isEmpty) continue;
      if (!plugin.isHttp && !plugin.isHop) continue;
      final code = await rootBundle.loadString('$_assetRoot/${plugin.entry}');
      await prefs.setString(_scriptPrefix + plugin.id, code);
    }
    final all = await _listPacksRaw();
    EnginePack? previous;
    for (final a in all) {
      if (isBundled(a.sourceUrl)) {
        previous = a;
        break;
      }
    }
    if (previous != null) {
      final prev = previous;
      final enabledById = {for (final p in prev.plugins) p.id: p.enabled};
      pack = pack.copyWithPlugins([
        for (final p in pack.plugins)
          p.copyWith(enabled: enabledById[p.id] ?? p.enabled),
      ]);
      final same =
          prev.sourceUrl == bundledSourceUrl &&
          prev.version == pack.version &&
          prev.plugins.length == pack.plugins.length &&
          List.generate(
            pack.plugins.length,
            (i) =>
                prev.plugins[i].id == pack.plugins[i].id &&
                prev.plugins[i].entry == pack.plugins[i].entry &&
                jsonEncode(prev.plugins[i].config) ==
                    jsonEncode(pack.plugins[i].config) &&
                prev.plugins[i].kind == pack.plugins[i].kind &&
                jsonEncode(prev.plugins[i].hosts) ==
                    jsonEncode(pack.plugins[i].hosts),
          ).every((ok) => ok);
      if (same) {
        await _syncHops([pack]);
        return;
      }
    }
    all.removeWhere((a) => isBundled(a.sourceUrl));
    all.insert(0, pack);
    await _savePacks(all);
    await _syncHops([pack]);
  }

  Future<void> _syncHops(List<EnginePack> packs) async {
    await _syncHopsForRuntime(EngineRuntime.instance, packs);
  }

  String _resolveScriptUrl(String manifestUrl, String filename) {
    final mu = Uri.parse(manifestUrl);
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    final path = mu.path.endsWith('/')
        ? '${mu.path}$filename'
        : '${mu.path.substring(0, mu.path.lastIndexOf('/') + 1)}$filename';
    return mu.replace(path: path).toString();
  }

  Future<EnginePack> install(String manifestUrl) async {
    final resp = await http.get(Uri.parse(manifestUrl));
    if (resp.statusCode != 200) {
      throw Exception('engine.json HTTP ${resp.statusCode}');
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    var pack = EnginePack.fromJson(map, sourceUrl: manifestUrl);
    final prefs = await _prefs;
    for (final plugin in pack.plugins) {
      if (plugin.entry.isEmpty) continue;
      try {
        final scriptUrl = _resolveScriptUrl(manifestUrl, plugin.entry);
        final sr = await http.get(Uri.parse(scriptUrl));
        if (sr.statusCode == 200 && sr.body.isNotEmpty) {
          await prefs.setString(_scriptPrefix + plugin.id, sr.body);
        }
      } catch (e) {
        debugPrint('[engine] script fetch failed (${plugin.id}): $e');
      }
    }
    final all = await _listPacksRaw();
    all.removeWhere((a) => a.sourceUrl == manifestUrl);
    all.add(pack);
    await _savePacks(all);
    await _syncHops(all);
    return pack;
  }

  Future<void> removePack(String sourceUrl) async {
    if (isBundled(sourceUrl)) return;
    final all = await _listPacksRaw();
    final victim = all.where((a) => a.sourceUrl == sourceUrl).toList();
    all.removeWhere((a) => a.sourceUrl == sourceUrl);
    final prefs = await _prefs;
    for (final pack in victim) {
      for (final p in pack.plugins) {
        await prefs.remove(_scriptPrefix + p.id);
      }
    }
    await _savePacks(all);
  }

  Future<void> setPluginEnabled({
    required String sourceUrl,
    required String pluginId,
    required bool enabled,
  }) async {
    final all = await _listPacksRaw();
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

  Future<bool> isSourcesSelectAllDefault() async {
    final prefs = await _prefs;
    return prefs.getBool(_selectAllDefaultKey) ?? true;
  }

  Future<void> setSourcesSelectAllDefault(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_selectAllDefaultKey, value);
  }

  Future<Set<String>> loadSourcesSelectedPluginIds({
    required Set<String> enabledIds,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_selectedKey);
    if (raw == null) {
      final selectAll = await isSourcesSelectAllDefault();
      return selectAll ? Set<String>.from(enabledIds) : {};
    }
    return filterEngineSelectedPluginIds(savedIds: raw, enabledIds: enabledIds);
  }

  Future<void> saveSourcesSelectedPluginIds(Set<String> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(_selectedKey, ids.toList());
  }

  Future<String?> _loadScript(EnginePlugin plugin) async {
    final prefs = await _prefs;
    final cached = prefs.getString(_scriptPrefix + plugin.id);
    if (cached != null && cached.isNotEmpty) return cached;
    if (isBundled(bundledSourceUrl) && plugin.entry.isNotEmpty) {
      try {
        return await rootBundle.loadString('$_assetRoot/${plugin.entry}');
      } catch (_) {}
    }
    return null;
  }

  Future<EngineExtractResult?> runPlugin({
    required String pluginId,
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Movie? movie,
    bool allowHostFallback = true,
    EngineRuntime? runtime,
  }) async {
    final gen = _extractGeneration;
    final packs = await listPacks();
    if (gen != _extractGeneration) return null;
    EnginePlugin? plugin;
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (p.id == pluginId) {
          plugin = p;
          break;
        }
      }
      if (plugin != null) break;
    }
    final rt = runtime ?? EngineRuntime.instance;
    if (runtime == null) {
      await _syncHops(packs);
    } else {
      await _syncHopsForRuntime(rt, packs);
    }
    if (plugin == null || !plugin.enabled || !plugin.isExtractable) return null;
    final mediaType = type == 'tv' || type == 'series' ? 'tv' : 'movie';
    if (plugin.types.isNotEmpty &&
        !plugin.types.contains(mediaType) &&
        !(mediaType == 'tv' && plugin.types.contains('series'))) {
      return EngineExtractResult(
        pluginId: plugin.id,
        pluginName: plugin.name,
        streams: const [],
      );
    }

    if (plugin.isHost) {
      final resolvedMovie =
          movie ??
          Movie(
            id: int.tryParse(tmdbId) ?? 0,
            title: title ?? '',
            posterPath: '',
            backdropPath: '',
            voteAverage: 0,
            releaseDate: year != null ? '$year-01-01' : '',
            mediaType: mediaType,
          );
      final hostStreams = await EngineHostResolver.resolve(
        plugin: plugin,
        movie: resolvedMovie,
        season: season ?? 1,
        episode: episode ?? 1,
        isCancelled: () => gen != _extractGeneration,
      );
      if (gen != _extractGeneration) return null;
      return EngineExtractResult(
        pluginId: plugin.id,
        pluginName: plugin.name,
        streams: hostStreams,
      );
    }

    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = mergeEngineConfig(plugin.config, overlay);
    final code = await _loadScript(plugin);
    if (gen != _extractGeneration || code == null) return null;
    if (!rt.isLoaded(plugin.id)) {
      await rt.loadPlugin(pluginId: plugin.id, code: code);
    }
    if (gen != _extractGeneration) return null;
    final raw = await rt.extract(
      pluginId: plugin.id,
      tmdbId: tmdbId,
      imdbId: movie?.imdbId,
      type: mediaType,
      season: season,
      episode: episode,
      title: title,
      year: year,
      config: config,
      movie: movie,
      // HTTP miss → ctx.host sniff (90s VidFast/VidRock). Default 30s
      // returned [] while HLS was already on the wire.
      timeout:
          EmbedExtractProfiles.resolve(plugin.id).timeout +
          const Duration(seconds: 30),
      allowHostFallback: allowHostFallback,
      isCancelled: () => gen != _extractGeneration,
    );
    if (gen != _extractGeneration) return null;
    final streams = <Map<String, dynamic>>[];
    for (final s in raw) {
      final url = (s['url'] ?? '').toString().trim();
      if (url.isEmpty || isTorrentStreamUrl(url)) continue;
      final mapped = mapEngineStream(
        raw: s,
        plugin: plugin,
        mediaTitle: title,
        year: year,
        type: mediaType,
        season: season,
        episode: episode,
      );
      if (mapped != null) streams.add(mapped);
    }
    return EngineExtractResult(
      pluginId: plugin.id,
      pluginName: plugin.name,
      streams: streams,
    );
  }

  Future<EngineExtractResult?> runPluginIsolated({
    required String pluginId,
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Movie? movie,
    bool allowHostFallback = true,
  }) async {
    final runtime = EngineRuntime.fork();
    try {
      return await runPlugin(
        pluginId: pluginId,
        tmdbId: tmdbId,
        type: type,
        season: season,
        episode: episode,
        title: title,
        year: year,
        movie: movie,
        allowHostFallback: allowHostFallback,
        runtime: runtime,
      );
    } finally {
      runtime.dispose();
    }
  }
}
