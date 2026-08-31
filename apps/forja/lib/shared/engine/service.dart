import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/catalog_extract_context.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineService {
  EngineService._();
  static final EngineService instance = EngineService._();

  static bool isInternalLiveCatalog(EnginePlugin plugin) => plugin.isLiveCatalog;

  static String catalogFilterId(EnginePlugin catalog) {
    final providerId = (catalog.config['providerId'] ?? '').toString().trim();
    if (providerId.startsWith('live-')) return providerId;
    return catalog.id;
  }

  static String catalogPluginIdForLiveSport(String liveSportId) {
    if (!liveSportId.startsWith('live-')) return liveSportId;
    return 'catalog-${liveSportId.substring('live-'.length)}';
  }

  /// Legacy unscoped selection (migrated into `…_movie` once).
  static const _legacySelectedKey = 'engine_js_sources_selected_ids';
  static const _selectedKeyPrefix = 'engine_js_sources_selected_ids_';
  static const _viewFilterKeyPrefix = 'engine_js_sources_view_filter_ids_';

  static ValueNotifier<int> get changeNotifier => PluginRegistry.changeNotifier;
  static ValueNotifier<String?> get officialInstallError =>
      PluginRegistry.officialInstallError;

  int _extractGeneration = 0;
  int _liveCatalogGeneration = 0;
  int _catalogGeneration = 0;
  EngineRuntime? _liveCatalogRuntime;

  static bool isLegacyAssetPack(String sourceUrl) =>
      PluginRegistry.isLegacyAssetPack(sourceUrl);

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  void cancelPending() {
    abortInFlightExtracts();
    cancelLiveCatalog();
    Engine.cancelEngineJsExtracts();
  }

  void abortInFlightExtracts() {
    _extractGeneration++;
    EngineRuntime.abortAll();
  }

  /// Abort in-flight catalog hub actions (tab switch / logout).
  void cancelCatalog() {
    _catalogGeneration++;
  }

  void cancelLiveCatalog() {
    _liveCatalogGeneration++;
    _abortLiveCatalogRuntime();
    Engine.cancelLiveMatchesFetch();
  }

  void _abortLiveCatalogRuntime() {
    final rt = _liveCatalogRuntime;
    _liveCatalogRuntime = null;
    if (rt == null) return;
    rt.abortPendingWork();
    rt.dispose();
  }

  Future<void> _syncHopsForRuntime(
    EngineRuntime runtime,
    List<EnginePack> packs,
  ) async {
    final hops = <EnginePlugin>[
      for (final pack in packs)
        for (final p in pack.plugins)
          if (p.isHop && pack.isPluginActive(p)) p,
    ];
    runtime.registerHops(hops);
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isHop || !pack.isPluginActive(p)) continue;
        final code = await _loadScript(p, sourceUrl: pack.sourceUrl);
        if (code != null && code.isNotEmpty) {
          runtime.stashPluginCode(p.id, code);
        }
      }
    }
  }

  Future<List<EnginePack>> listPacks() => PluginRegistry.instance.listPacks();

  /// Settings list — prefs first (instant), ensure/hydrate in background.
  Future<List<EnginePack>> listUserPacks() async {
    final cached = await PluginRegistry.instance.listPacksRaw();
    unawaited(PluginRegistry.instance.ensureOfficialInstalled());
    unawaited(PluginRegistry.instance.hydrateLeanInstalled());
    return cached;
  }

  Future<void> applyLeanManifestUrls(Iterable<Map<String, dynamic>> rows) =>
      PluginRegistry.instance.applyLeanManifestUrls(rows);

  Future<List<EnginePack>> listSourcesPanelPacks() async {
    // Never block Play/Sources on network install / lean hydrate.
    unawaited(PluginRegistry.instance.ensureOfficialInstalled());
    unawaited(PluginRegistry.instance.hydrateLeanInstalled());
    final packs = await PluginRegistry.instance.listPacksRaw();
    return [
      for (final p in packs)
        if (p.enabled && p.plugins.any((pl) => pl.enabled && pl.isVodCatalog))
          p.copyWithPlugins([
            for (final pl in p.plugins)
              if (pl.isVodCatalog) pl,
          ]),
    ];
  }

  Future<List<EnginePlugin>> listEnabledLivePlugins() async {
    await ensureOfficialInstalled();
    final out = <EnginePlugin>[];
    for (final pack in await listPacks()) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (p.enabled && p.isLiveSport && p.isHttp) {
          out.add(p);
        }
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<List<EnginePlugin>> listLivePluginsForSettings() async {
    await ensureOfficialInstalled();
    final out = <EnginePlugin>[];
    for (final pack in await listPacks()) {
      for (final p in pack.plugins) {
        if (p.isLive && p.isHttp) out.add(p);
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<EnginePlugin?> pluginById(String id) async {
    EnginePlugin? inactive;
    for (final pack in await listPacks()) {
      for (final p in pack.plugins) {
        if (p.id != id) continue;
        if (pack.isPluginActive(p)) return p;
        inactive ??= p;
      }
    }
    return inactive;
  }

  Future<List<EnginePlugin>> listEnabledLiveCatalogPlugins() async {
    await ensureOfficialInstalled();
    final out = <EnginePlugin>[];
    for (final pack in await listPacks()) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.isLiveCatalog || !p.isHttp || !p.enabled) continue;
        out.add(p);
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Enabled catalog hub plugins (`kind: catalog`) — Home / Anime / hubs.
  Future<List<EnginePlugin>> listHubCatalogPlugins() async {
    await ensureOfficialInstalled();
    final out = <EnginePlugin>[];
    for (final pack in await listPacks()) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (p.isHubCatalog && p.enabled) out.add(p);
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Run one catalog hub action and return the raw protocol envelope map.
  ///
  /// Plugins must resolve to `[envelope]` — both engine paths only carry a JSON
  /// array back. Catalog request fields are first-class on `ctx` (`params` /
  /// `auth` / `cache` / `kit` / `protocol`); `ctx.action` stays top level too
  /// (R70-A12).
  Future<Map<String, dynamic>?> runCatalog({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? auth,
    Map<String, dynamic>? cache,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final gen = _catalogGeneration;
    final packs = await listPacks();
    if (gen != _catalogGeneration) return null;
    final hit = PluginRegistry.packPluginFromPacks(packs, pluginId);
    if (hit == null ||
        !hit.plugin.isHubCatalog ||
        !hit.pack.isPluginActive(hit.plugin)) {
      debugPrint('[catalog] $pluginId not an active catalog plugin');
      return null;
    }
    final plugin = hit.plugin;
    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = <String, dynamic>{
      ...mergeEngineConfig(plugin.config, overlay),
    };
    // Catalog hubs may call ctx.host.tmdb.match / hubTmdbMatch — inject the
    // same compile-time key Home uses (R70-A14 / R70-A28).
    const tmdbKey = String.fromEnvironment('TMDB_API_KEY');
    if (tmdbKey.isNotEmpty &&
        (config['apiKey'] == null || config['apiKey'].toString().isEmpty)) {
      config['apiKey'] = tmdbKey;
    }

    // First-class catalog request (both EngineJS + flutter_js invokers).
    final catalogCtx = <String, dynamic>{
      'params': params,
      if (auth != null && auth.isNotEmpty) 'auth': auth,
      if (cache != null && cache.isNotEmpty) 'cache': cache,
      'kit': hostKitVersion,
      'protocol': hostProtocolVersion,
    };

    final code = await _loadScript(plugin, sourceUrl: hit.pack.sourceUrl);
    if (gen != _catalogGeneration) return null;
    if (code == null || code.isEmpty) {
      debugPrint('[catalog] ${plugin.id} missing script');
      return null;
    }

    final viaRust = await _runLiveEngineRustJs(
      plugin: plugin,
      config: config,
      action: action,
      params: catalogCtx,
      timeout: timeout,
      gen: gen,
      generation: () => _catalogGeneration,
    );
    if (viaRust != null) {
      final envelope = _firstEnvelopeMap(viaRust);
      if (envelope != null) return envelope;
      if (gen != _catalogGeneration) return null;
      debugPrint(
        '[catalog] ${plugin.id} $action enginejs gave no envelope — flutter_js',
      );
    }
    if (gen != _catalogGeneration) return null;

    final runtime = EngineRuntime.fork();
    try {
      await runtime.loadPlugin(pluginId: plugin.id, code: code);
      if (gen != _catalogGeneration) return null;
      final raw = await runtime.extractLive(
        pluginId: plugin.id,
        pluginName: plugin.name,
        action: action,
        params: catalogCtx,
        config: config,
        timeout: timeout,
        isCancelled: () => gen != _catalogGeneration,
      );
      if (gen != _catalogGeneration) return null;
      return _firstEnvelopeMap(raw);
    } finally {
      runtime.dispose();
    }
  }

  static Map<String, dynamic>? _firstEnvelopeMap(
    List<Map<String, dynamic>> rows,
  ) {
    for (final row in rows) {
      if (row.containsKey('ok')) return row;
    }
    return null;
  }

  Future<void> ensureOfficialInstalled({bool force = false}) =>
      PluginRegistry.instance.ensureOfficialInstalled(force: force);

  Future<void> retryOfficialInstall() =>
      PluginRegistry.instance.retryOfficialInstall();

  Future<EnginePack> install(String manifestUrl) async {
    final pack = await PluginRegistry.instance.install(manifestUrl);
    await _syncHops(await PluginRegistry.instance.listPacksRaw());
    return pack;
  }

  Future<EnginePack> refresh(String manifestUrl) => install(manifestUrl);

  Future<EnginePack> installManifestUrl(String manifestUrl) =>
      install(manifestUrl);

  Future<EnginePack> refreshManifestUrl(String manifestUrl) =>
      refresh(manifestUrl);

  Future<void> removePack(String sourceUrl) =>
      PluginRegistry.instance.removePack(sourceUrl);

  Future<void> setPluginEnabled({
    required String sourceUrl,
    required String pluginId,
    required bool enabled,
  }) =>
      PluginRegistry.instance.setPluginEnabled(
        sourceUrl: sourceUrl,
        pluginId: pluginId,
        enabled: enabled,
      );

  Future<void> setPackEnabled({
    required String sourceUrl,
    required bool enabled,
  }) =>
      PluginRegistry.instance.setPackEnabled(
        sourceUrl: sourceUrl,
        enabled: enabled,
      );

  Future<void> setPluginsEnabled({
    required String sourceUrl,
    required Set<String> pluginIds,
    required bool enabled,
  }) =>
      PluginRegistry.instance.setPluginsEnabled(
        sourceUrl: sourceUrl,
        pluginIds: pluginIds,
        enabled: enabled,
      );

  static String _selectedPrefsKey(String panelCategory) =>
      '$_selectedKeyPrefix$panelCategory';

  Future<Set<String>> loadSourcesSelectedPluginIds({
    required Set<String> enabledIds,
    required String panelCategory,
    Set<String>? selectAllScopeIds,
  }) async {
    final prefs = await _prefs;
    final key = _selectedPrefsKey(panelCategory);
    var raw = prefs.getStringList(key);
    if (raw == null && panelCategory == EngineCategories.movie) {
      final legacy = prefs.getStringList(_legacySelectedKey);
      if (legacy != null) {
        await prefs.setStringList(key, legacy);
        await prefs.remove(_legacySelectedKey);
        raw = legacy;
      }
    }
    if (raw == null || raw.isEmpty) {
      final scope = selectAllScopeIds ?? enabledIds;
      return {
        for (final id in scope)
          if (enabledIds.contains(id)) id,
      };
    }
    final filtered = filterEngineSelectedPluginIds(
      savedIds: raw,
      enabledIds: enabledIds,
    );
    if (filtered.isEmpty && enabledIds.isNotEmpty) {
      final scope = selectAllScopeIds ?? enabledIds;
      return {
        for (final id in scope)
          if (enabledIds.contains(id)) id,
      };
    }
    return filtered;
  }

  Future<void> saveSourcesSelectedPluginIds(
    Set<String> ids, {
    required String panelCategory,
  }) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _selectedPrefsKey(panelCategory),
      ids.toList(),
    );
  }

  static String _viewFilterPrefsKey(String panelCategory) =>
      '$_viewFilterKeyPrefix$panelCategory';

  /// All-mode provider chip filters (view-only under All).
  Future<Set<String>> loadSourcesViewFilterPluginIds({
    required Set<String> enabledIds,
    required String panelCategory,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_viewFilterPrefsKey(panelCategory));
    if (raw == null || raw.isEmpty) return {};
    return filterEngineSelectedPluginIds(
      savedIds: raw,
      enabledIds: enabledIds,
    );
  }

  Future<void> saveSourcesViewFilterPluginIds(
    Set<String> ids, {
    required String panelCategory,
  }) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _viewFilterPrefsKey(panelCategory),
      ids.toList(),
    );
  }

  Future<void> _syncHops(List<EnginePack> packs) async {
    await _syncHopsForRuntime(EngineRuntime.instance, packs);
  }

  Future<String?> _loadScript(
    EnginePlugin plugin, {
    String? sourceUrl,
  }) async {
    var url = sourceUrl;
    if (url == null || url.isEmpty) {
      final found = await PluginRegistry.instance.findPlugin(plugin.id);
      if (found == null) return null;
      return PluginRegistry.instance.loadScript(
        sourceUrl: found.pack.sourceUrl,
        plugin: found.plugin,
      );
    }
    return PluginRegistry.instance.loadScript(
      sourceUrl: url,
      plugin: plugin,
    );
  }

  Future<EngineExtractResult?> runPlugin({
    required String pluginId,
    required String tmdbId,
    required String type,
    Movie? movie,
    CatalogOpen? catalogOpen,
    int? episode,
    String? episodeVideoId,
    int? season,
    String? title,
    String? year,
    bool allowHostFallback = false,
    EngineRuntime? runtime,
  }) async {
    final resolved = resolveEngineExtractInputs(
      type: type,
      movie: movie,
      catalogOpen: catalogOpen,
      episodeVideoId: episodeVideoId,
      episode: episode,
      panelCategoryHint: type,
    );
    final extractType = resolved.type;
    final extractCtx = Map<String, dynamic>.from(resolved.ctx);
    if (movie?.imdbId != null && movie!.imdbId!.trim().isNotEmpty) {
      extractCtx.putIfAbsent('imdbId', () => movie.imdbId!.trim());
    }
    final resolvedMalId = extractCtxInt(extractCtx, 'malId');
    final resolvedAnilistId = extractCtxInt(extractCtx, 'anilistId');
    final resolvedImdb = extractCtx['imdbId']?.toString() ?? movie?.imdbId;
    final mappedEpisode = extractCtxInt(extractCtx, 'mappedEpisode') ?? episode;

    final gen = _extractGeneration;
    final packs = await listPacks();
    if (gen != _extractGeneration) return null;
    final hit = PluginRegistry.packPluginFromPacks(packs, pluginId);
    final rt = runtime ?? EngineRuntime.instance;
    if (runtime == null) {
      await _syncHops(packs);
    } else {
      await _syncHopsForRuntime(rt, packs);
    }
    if (hit == null ||
        !hit.pack.isPluginActive(hit.plugin) ||
        !hit.plugin.isExtractable) {
      return null;
    }
    final active = hit.plugin;
    // Soft categories only — Sources filter hides chips; selected plugins always run.
    final mediaType = _normalizeEngineMediaType(extractType);

    if (active.isHost) {
      if (gen != _extractGeneration) return null;
      return null;
    }

    final overlay =
        ProviderRuntimeConfig.instance.engine[active.id] ?? const {};
    final config = injectExtractCtxIntoConfig(
      active,
      extractCtx,
      mergeEngineConfig(active.config, overlay),
    );
    var code = await _loadScript(active, sourceUrl: hit.pack.sourceUrl);
    if (gen != _extractGeneration) return null;
    if (code == null || code.isEmpty) {
      debugPrint('[engine] ${active.id} missing script — repairing pack');
      try {
        await PluginRegistry.instance.install(hit.pack.sourceUrl);
      } catch (e) {
        debugPrint('[engine] repair install failed: $e');
      }
      code = await _loadScript(active, sourceUrl: hit.pack.sourceUrl);
      if (gen != _extractGeneration) return null;
      if (code == null || code.isEmpty) {
        debugPrint('[engine] ${active.id} still missing script after repair');
        return null;
      }
    }
    if (!rt.isLoaded(active.id)) {
      await rt.loadPlugin(pluginId: active.id, code: code);
    }
    if (gen != _extractGeneration) return null;
    debugPrint(
      '[engine] ${active.id} start tmdb=$tmdbId type=$mediaType '
      's=$season e=$episode title=$title'
      '${resolvedMalId != null ? ' mal=$resolvedMalId' : ''}'
      '${resolvedAnilistId != null ? ' anilist=$resolvedAnilistId' : ''}'
      '${resolvedImdb != null && resolvedImdb.isNotEmpty ? ' imdb=$resolvedImdb' : ''}',
    );
    final sw = Stopwatch()..start();
    final raw = await rt.extract(
      pluginId: active.id,
      pluginName: active.name,
      tmdbId: tmdbId,
      imdbId: resolvedImdb,
      malId: resolvedMalId,
      anilistId: resolvedAnilistId,
      mappedEpisode: mappedEpisode,
      type: mediaType,
      season: season,
      episode: episode,
      title: title,
      year: year,
      config: config,
      movie: movie,
      extractCtx: extractCtx,
      // HTTP plugins: extract(ctx) only — no host / WebView / Dart extract fallbacks.
      timeout: const Duration(seconds: 75),
      allowHostFallback: allowHostFallback,
      isCancelled: () => gen != _extractGeneration,
    );
    if (gen != _extractGeneration) {
      debugPrint('[engine] ${active.id} cancelled after ${sw.elapsedMilliseconds}ms');
      return null;
    }
    var rawList = raw;
    if (gen != _extractGeneration) {
      debugPrint('[engine] ${active.id} cancelled after ${sw.elapsedMilliseconds}ms');
      return null;
    }
    final streams = <Map<String, dynamic>>[];
    for (final s in rawList) {
      final url = (s['url'] ?? '').toString().trim();
      if (url.isEmpty || isTorrentStreamUrl(url)) continue;
      final mapped = mapEngineStream(
        raw: s,
        plugin: active,
        mediaTitle: title,
        year: year,
        type: mediaType,
        season: season,
        episode: episode,
      );
      if (mapped != null) streams.add(mapped);
    }
    debugPrint(
      '[engine] ${active.id} done raw=${rawList.length} streams=${streams.length} '
      '${sw.elapsedMilliseconds}ms',
    );
    return EngineExtractResult(
      pluginId: active.id,
      pluginName: active.name,
      streams: streams,
    );
  }

  /// Live Matches Forja plugins (`providers` / `live_sport` / internal `catalog`).
  Future<List<Map<String, dynamic>>> runLivePlugin({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (action != 'resolve') return [];
    final gen = _extractGeneration;
    final packs = await listPacks();
    if (gen != _extractGeneration) return [];
    final hit = PluginRegistry.packPluginFromPacks(packs, pluginId);
    if (hit == null ||
        !(hit.plugin.isLivePlugin || hit.plugin.isLiveSport) ||
        !hit.pack.isPluginActive(hit.plugin)) {
      return [];
    }
    final plugin = hit.plugin;
    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = mergeEngineConfig(plugin.config, overlay);
    final code = await _loadScript(plugin, sourceUrl: hit.pack.sourceUrl);
    if (gen != _extractGeneration || code == null) return [];
    final viaRust = await _runLiveEngineRustJs(
      plugin: plugin,
      config: config,
      action: action,
      params: params,
      timeout: timeout,
      gen: gen,
      generation: () => _extractGeneration,
    );
    if (viaRust != null) {
      if (viaRust.isNotEmpty) {
        return _postProcessLivePluginRows(viaRust);
      }
      // Cancel may have emptied the list after gen bump — never stampede JSC.
      if (gen != _extractGeneration) return [];
      debugPrint(
        '[engine] ${plugin.id} enginejs live resolve empty — flutter_js fallback',
      );
    }
    if (gen != _extractGeneration) return [];

    final runtime = EngineRuntime.fork();
    try {
      await _syncHopsForRuntime(runtime, packs);
      if (gen != _extractGeneration) return [];
      await runtime.loadPlugin(pluginId: plugin.id, code: code);
      if (gen != _extractGeneration) return [];
      final raw = await runtime.extractLive(
        pluginId: plugin.id,
        pluginName: plugin.name,
        action: action,
        params: params,
        config: config,
        timeout: timeout,
        isCancelled: () => gen != _extractGeneration,
      );
      if (gen != _extractGeneration) return [];
      return _postProcessLivePluginRows(raw);
    } finally {
      runtime.dispose();
    }
  }

  /// Run one bundled live catalog plugin (`catalog/*.js`).
  Future<List<Map<String, dynamic>>> runLiveCatalog({
    required EnginePlugin catalogPlugin,
    Map<String, dynamic> extraConfig = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!catalogPlugin.isLiveCatalog) return [];
    final gen = _liveCatalogGeneration;
    final packs = await listPacks();
    if (gen != _liveCatalogGeneration) return [];

    final overlay =
        ProviderRuntimeConfig.instance.engine[catalogPlugin.id] ?? const {};
    var config = mergeEngineConfig(catalogPlugin.config, overlay);

    final providerId = (catalogPlugin.config['providerId'] ?? '').toString();
    if (providerId.startsWith('live-')) {
      final provider = await pluginById(providerId);
      if (provider != null) {
        final providerOverlay =
            ProviderRuntimeConfig.instance.engine[provider.id] ?? const {};
        config = mergeEngineConfig(provider.config, config);
        config = mergeEngineConfig(config, providerOverlay);
        config['providerId'] = providerId;
      }
    }

    if (extraConfig.isNotEmpty) {
      config = {...config, ...extraConfig};
    }

    final code = await _loadScript(catalogPlugin);
    if (gen != _liveCatalogGeneration || code == null) return [];

    final viaRust = await _runLiveEngineRustJs(
      plugin: catalogPlugin,
      config: config,
      action: 'catalog',
      timeout: timeout,
      gen: gen,
      generation: () => _liveCatalogGeneration,
    );
    if (viaRust != null) return _postProcessLivePluginRows(viaRust);
    if (gen != _liveCatalogGeneration) return [];

    final runtime = EngineRuntime.fork();
    _liveCatalogRuntime = runtime;
    try {
      await _syncHopsForRuntime(runtime, packs);
      if (gen != _liveCatalogGeneration) return [];
      if (!runtime.isLoaded(catalogPlugin.id)) {
        await runtime.loadPlugin(pluginId: catalogPlugin.id, code: code);
      }
      if (gen != _liveCatalogGeneration) return [];
      final raw = await runtime.extractLive(
        pluginId: catalogPlugin.id,
        pluginName: catalogPlugin.name,
        action: 'catalog',
        config: config,
        timeout: timeout,
        isCancelled: () => gen != _liveCatalogGeneration,
      );
      if (gen != _liveCatalogGeneration) return [];
      return _postProcessLivePluginRows(raw);
    } finally {
      if (identical(_liveCatalogRuntime, runtime)) {
        _liveCatalogRuntime = null;
      }
      runtime.dispose();
    }
  }

  /// Forja EngineJS live plugin path — null → flutter_js fork fallback.
  Future<List<Map<String, dynamic>>?> _runLiveEngineRustJs({
    required EnginePlugin plugin,
    required Map<String, dynamic> config,
    required String action,
    Map<String, dynamic> params = const {},
    required Duration timeout,
    required int gen,
    required int Function() generation,
  }) async {
    if (gen != generation()) return null;
    final code = await _loadScript(plugin);
    if (gen != generation() || code == null) return null;

    final ctx = <String, Object?>{
      'tmdbId': '',
      'imdbId': '',
      'malId': '',
      'anilistId': '',
      'mappedEpisode': 1,
      'type': 'live',
      'season': 1,
      'episode': 1,
      'year': '',
      ...params,
      'title': (params['title'] ?? '').toString(),
      'url': (params['url'] ?? params['embedUrl'] ?? '').toString(),
      'action': action,
      'matchId': (params['matchId'] ?? '').toString(),
      'source': (params['source'] ?? '').toString(),
      'stream': (params['stream'] ?? '').toString(),
      'eventId': (params['eventId'] ?? '').toString(),
      'embedUrl': (params['embedUrl'] ?? params['url'] ?? '').toString(),
      'iframe': (params['iframe'] ?? params['embedUrl'] ?? '').toString(),
      'category': (params['category'] ?? '').toString(),
      'config': config,
    };

    debugPrint('[engine] ${plugin.id} start (enginejs live) action=$action');
    final sw = Stopwatch()..start();
    late final String rawJson;
    try {
      rawJson = await EngineJobs.run(EngineAsyncJob.engineJsExtract, {
        'plugin_id': plugin.id,
        'code': code,
        'ctx': ctx,
        'timeout_ms': timeout.inMilliseconds,
        'allow_host_fallback': false,
        'hops': <Map<String, Object?>>[],
        'hop_depth': 0,
      });
    } catch (e) {
      debugPrint('[engine] ${plugin.id} enginejs live submit failed: $e');
      return null;
    }
    if (gen != generation()) return null;

    Map<String, dynamic> decoded;
    try {
      final v = jsonDecode(rawJson);
      if (v is! Map) return null;
      decoded = Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
    if (decoded['unsupported'] == true) {
      debugPrint(
        '[engine] ${plugin.id} enginejs live unsupported — flutter_js fallback',
      );
      return null;
    }
    if (decoded['error'] != null && decoded['streams'] == null) {
      final err = decoded['error'].toString();
      debugPrint('[engine] ${plugin.id} enginejs live error: $err');
      if (err == 'cancelled') {
        // ROOT cancel may not have bumped Dart gen; do it here so the
        // caller skips flutter_js (null alone would stampede JSC).
        if (gen == generation()) {
          abortInFlightExtracts();
        }
        return null;
      }
      return null;
    }

    final rawList = <Map<String, dynamic>>[];
    final streamsRaw = decoded['streams'];
    if (streamsRaw is List) {
      for (final s in streamsRaw) {
        if (s is Map) rawList.add(Map<String, dynamic>.from(s));
      }
    }
    debugPrint(
      '[engine] ${plugin.id} done (enginejs live) raw=${rawList.length} '
      '${sw.elapsedMilliseconds}ms',
    );
    return rawList;
  }

  Future<List<Map<String, dynamic>>> _postProcessLivePluginRows(
    List<Map<String, dynamic>> raw,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final row in raw) {
      if (row['goatPending'] == true) {
        final slotRaw = row['slot'];
        final slot = slotRaw is Map
            ? Map<String, dynamic>.from(slotRaw)
            : <String, dynamic>{};
        final url = await LiveGoatUnlock.unlock(
          slot: slot,
          goat: (row['goat'] ?? '').toString(),
          bodyHex: (row['bodyHex'] ?? '').toString(),
        );
        if (url == null || url.isEmpty) continue;
        final headers = <String, dynamic>{};
        final h = row['headers'];
        if (h is Map) {
          h.forEach((k, v) => headers[k.toString()] = v);
        }
        out.add({'url': url, 'headers': headers});
        continue;
      }
      if (row['sniffPending'] == true) {
        debugPrint(
          '[EngineService] sniffPending ignored — use Sniff mode embed player',
        );
        continue;
      }
      out.add(row);
    }
    return out;
  }

  Future<EngineExtractResult?> runPluginIsolated({
    required String pluginId,
    required String tmdbId,
    required String type,
    Movie? movie,
    CatalogOpen? catalogOpen,
    int? episode,
    String? episodeVideoId,
    int? season,
    String? title,
    String? year,
    bool allowHostFallback = false,
  }) async {
    final resolved = resolveEngineExtractInputs(
      type: type,
      movie: movie,
      catalogOpen: catalogOpen,
      episodeVideoId: episodeVideoId,
      episode: episode,
      panelCategoryHint: type,
    );
    final extractType = resolved.type;
    final extractCtx = Map<String, dynamic>.from(resolved.ctx);
    if (movie?.imdbId != null && movie!.imdbId!.trim().isNotEmpty) {
      extractCtx.putIfAbsent('imdbId', () => movie.imdbId!.trim());
    }

    // RFC-064: Forja EngineJS on tokio (true parallel). Null → flutter_js fork
    // only when Rust is unsupported — never after cancelPending gen bump
    // (that stampeded UI-isolate JSC forks mid-play → macOS SIGSEGV).
    final genAtStart = _extractGeneration;
    final viaRust = await _runHttpPluginRustJs(
      pluginId: pluginId,
      tmdbId: tmdbId,
      type: extractType,
      season: season,
      episode: episode,
      title: title,
      year: year,
      movie: movie,
      extractCtx: extractCtx,
      allowHostFallback: allowHostFallback,
    );
    if (viaRust != null) return viaRust;
    if (genAtStart != _extractGeneration) {
      debugPrint(
        '[engine] $pluginId cancelled — skip flutter_js fallback',
      );
      return EngineExtractResult(
        pluginId: pluginId,
        pluginName: pluginId,
        streams: const [],
      );
    }

    final runtime = EngineRuntime.fork();
    try {
      return await runPlugin(
        pluginId: pluginId,
        tmdbId: tmdbId,
        type: extractType,
        season: season,
        episode: episode,
        title: title,
        year: year,
        movie: movie,
        catalogOpen: catalogOpen,
        episodeVideoId: episodeVideoId,
        allowHostFallback: allowHostFallback,
        runtime: runtime,
      );
    } finally {
      runtime.dispose();
    }
  }

  /// Off-UI extract. Returns `null` when Rust JS is unsupported / failed setup
  /// so [runPluginIsolated] can fall back to flutter_js.
  Future<EngineExtractResult?> _runHttpPluginRustJs({
    required String pluginId,
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    String? title,
    String? year,
    Movie? movie,
    required Map<String, dynamic> extractCtx,
    bool allowHostFallback = false,
  }) async {
    final gen = _extractGeneration;
    final packs = await listPacks();
    if (gen != _extractGeneration) return null;
    final hit = PluginRegistry.packPluginFromPacks(packs, pluginId);
    if (hit == null ||
        !hit.pack.isPluginActive(hit.plugin) ||
        !hit.plugin.isHttp) {
      return null;
    }
    final plugin = hit.plugin;

    final mediaType = _normalizeEngineMediaType(type);
    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = injectExtractCtxIntoConfig(
      plugin,
      extractCtx,
      mergeEngineConfig(plugin.config, overlay),
    );
    final code = await _loadScript(plugin);
    if (gen != _extractGeneration || code == null) return null;

    final spreadCtx = Map<String, dynamic>.from(extractCtx);
    if (movie?.imdbId != null && movie!.imdbId!.trim().isNotEmpty) {
      spreadCtx.putIfAbsent('imdbId', () => movie.imdbId!.trim());
    }
    final resolvedMalId = extractCtxInt(spreadCtx, 'malId');
    final resolvedAnilistId = extractCtxInt(spreadCtx, 'anilistId');
    final resolvedImdb = spreadCtx['imdbId']?.toString() ?? movie?.imdbId ?? '';
    final mappedEpisode =
        extractCtxInt(spreadCtx, 'mappedEpisode') ?? episode ?? 1;

    final timeout = const Duration(seconds: 75);
    final ctx = <String, Object?>{
      'tmdbId': tmdbId,
      'imdbId': resolvedImdb,
      'malId': resolvedMalId ?? '',
      'anilistId': resolvedAnilistId ?? '',
      'mappedEpisode': mappedEpisode,
      'type': mediaType,
      'season': season ?? 1,
      'episode': episode ?? 1,
      'title': title ?? '',
      'year': year ?? '',
      'url': '',
      ...spreadCtx,
      'config': config,
    };

    final hopPayload = <Map<String, Object?>>[];
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isHop || !pack.isPluginActive(p)) continue;
        final hopCode = await _loadScript(p, sourceUrl: pack.sourceUrl);
        if (hopCode == null || hopCode.isEmpty) continue;
        hopPayload.add({
          'id': p.id,
          'hosts': p.hopHosts,
          'code': hopCode,
        });
      }
    }
    if (gen != _extractGeneration) return null;

    debugPrint(
      '[engine] ${plugin.id} start (enginejs) tmdb=$tmdbId type=$mediaType '
      's=$season e=$episode title=$title hops=${hopPayload.length}'
      '${resolvedMalId != null ? ' mal=$resolvedMalId' : ''}'
      '${resolvedAnilistId != null ? ' anilist=$resolvedAnilistId' : ''}'
      '${resolvedImdb.isNotEmpty ? ' imdb=$resolvedImdb' : ''}'
      ' mappedEp=$mappedEpisode',
    );
    final sw = Stopwatch()..start();
    late final String rawJson;
    try {
      rawJson = await EngineJobs.run(EngineAsyncJob.engineJsExtract, {
        'plugin_id': plugin.id,
        'code': code,
        'ctx': ctx,
        'timeout_ms': timeout.inMilliseconds,
        'allow_host_fallback': allowHostFallback,
        'hops': hopPayload,
        'hop_depth': 0,
      });
    } catch (e) {
      debugPrint('[engine] ${plugin.id} enginejs submit failed: $e');
      return null;
    }
    if (gen != _extractGeneration) return null;

    Map<String, dynamic> decoded;
    try {
      final v = jsonDecode(rawJson);
      if (v is! Map) return null;
      decoded = Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
    if (decoded['error'] != null && decoded['streams'] == null) {
      final err = decoded['error'].toString();
      debugPrint('[engine] ${plugin.id} enginejs job error: $err');
      // ROOT cancelPendingResolve can abort EngineJS without Dart gen bump.
      // Returning null → runPluginIsolated forks flutter_js → JSC SIGSEGV.
      if (err == 'cancelled') {
        return EngineExtractResult(
          pluginId: plugin.id,
          pluginName: plugin.name,
          streams: const [],
        );
      }
      return null;
    }
    if (decoded['unsupported'] == true) {
      debugPrint(
        '[engine] ${plugin.id} enginejs unsupported — flutter_js fallback',
      );
      return null;
    }
    if (decoded['error'] != null) {
      debugPrint('[engine] ${plugin.id} enginejs error: ${decoded['error']}');
      // Soft failure with empty streams still counts as a completed extract
      // when unsupported is not set (e.g. timeout) — avoid double-running.
    }

    final rawList = <Map<String, dynamic>>[];
    final streamsRaw = decoded['streams'];
    if (streamsRaw is List) {
      for (final s in streamsRaw) {
        if (s is Map) rawList.add(Map<String, dynamic>.from(s));
      }
    }

    var effectiveRaw = rawList;
    final needsHost = (decoded['needs_host'] ?? '').toString().trim();
    if (effectiveRaw.isEmpty &&
        needsHost.isNotEmpty &&
        allowHostFallback &&
        gen == _extractGeneration) {
      debugPrint('[engine] ${plugin.id} enginejs needs_host=$needsHost (skipped)');
    }
    if (gen != _extractGeneration) return null;

    final streams = <Map<String, dynamic>>[];
    for (final s in effectiveRaw) {
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
    debugPrint(
      '[engine] ${plugin.id} done (enginejs) raw=${effectiveRaw.length} '
      'streams=${streams.length} ${sw.elapsedMilliseconds}ms',
    );
    return EngineExtractResult(
      pluginId: plugin.id,
      pluginName: plugin.name,
      streams: streams,
    );
  }

  static String _normalizeEngineMediaType(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'tv' || t == 'series') return 'tv';
    if (t == 'movie') return 'movie';
    return t;
  }
}
