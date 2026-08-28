import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/anime_ids.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:forja/shared/engine/host_resolver.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineService {
  EngineService._();
  static final EngineService instance = EngineService._();

  /// Official ForjaHQ Providers pack URL — see [PluginRegistry.officialProvidersManifestUrl].
  static const officialProvidersManifestUrl =
      PluginRegistry.officialProvidersManifestUrl;
  static const officialLiveManifestUrl =
      PluginRegistry.officialLiveManifestUrl;
  static const officialCatalogManifestUrl =
      PluginRegistry.officialCatalogManifestUrl;
  static List<String> get officialManifestUrls =>
      PluginRegistry.officialManifestUrls;

  /// @Deprecated Prefer [officialProvidersManifestUrl].
  static const officialManifestUrl = PluginRegistry.officialManifestUrl;

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

  static ValueNotifier<int> get changeNotifier => PluginRegistry.changeNotifier;
  static ValueNotifier<String?> get officialInstallError =>
      PluginRegistry.officialInstallError;

  int _extractGeneration = 0;
  int _liveCatalogGeneration = 0;
  EngineRuntime? _liveCatalogRuntime;

  static bool isOfficialPack(String sourceUrl) =>
      PluginRegistry.isOfficialPack(sourceUrl);

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
          if (p.isHop) p,
    ];
    runtime.registerHops(hops);
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isHop) continue;
        final code = await _loadScript(p, sourceUrl: pack.sourceUrl);
        if (code != null && code.isNotEmpty) {
          runtime.stashPluginCode(p.id, code);
        }
      }
    }
  }

  Future<List<EnginePack>> listPacks() => PluginRegistry.instance.listPacks();

  Future<List<EnginePack>> listSourcesPanelPacks() async {
    final packs = await listPacks();
    return [
      for (final p in packs)
        if (p.plugins.any((pl) => pl.enabled && pl.isVodCatalog))
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
    for (final pack in await listPacks()) {
      for (final p in pack.plugins) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Future<List<EnginePlugin>> listEnabledLiveCatalogPlugins() async {
    await ensureOfficialInstalled();
    final out = <EnginePlugin>[];
    for (final pack in await listPacks()) {
      for (final p in pack.plugins) {
        if (!p.isLiveCatalog || !p.isHttp || !p.enabled) continue;
        out.add(p);
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
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
    int? season,
    int? episode,
    String? title,
    String? year,
    Movie? movie,
    int? malId,
    int? anilistId,
    int? kisskhId,
    int? kisskhEpisodeId,
    bool allowHostFallback = false,
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
    final active = plugin;
    // Soft categories only — Sources filter hides chips; selected plugins always run.
    final mediaType = _normalizeEngineMediaType(type);

    if (active.isHost) {
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
        plugin: active,
        movie: resolvedMovie,
        season: season ?? 1,
        episode: episode ?? 1,
        isCancelled: () => gen != _extractGeneration,
      );
      if (gen != _extractGeneration) return null;
      return EngineExtractResult(
        pluginId: active.id,
        pluginName: active.name,
        streams: hostStreams,
      );
    }

    final overlay =
        ProviderRuntimeConfig.instance.engine[active.id] ?? const {};
    final config = engineConfigWithKissKhIds(
      mergeEngineConfig(active.config, overlay),
      pluginId: active.id,
      kisskhId: kisskhId,
      kisskhEpisodeId: kisskhEpisodeId,
    );
    var code = await _loadScript(active);
    if (gen != _extractGeneration) return null;
    if (code == null || code.isEmpty) {
      debugPrint('[engine] ${active.id} missing script — repairing pack');
      for (final pack in packs) {
        if (pack.plugins.any((p) => p.id == active.id)) {
          try {
            await PluginRegistry.instance.install(pack.sourceUrl);
          } catch (e) {
            debugPrint('[engine] repair install failed: $e');
          }
          break;
        }
      }
      code = await _loadScript(active);
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
    EngineAnimeIdBundle? animeIds;
    if (EngineAnimeIds.pluginNeedsResolve(active)) {
      final kinds = EngineAnimeIds.requiredKinds(active);
      final haveMal =
          !kinds.contains('mal') || (malId != null && malId > 0);
      final haveAnilist =
          !kinds.contains('anilist') || (anilistId != null && anilistId > 0);
      if (haveMal && haveAnilist) {
        animeIds = EngineAnimeIdBundle(
          imdbId: movie?.imdbId,
          malId: malId,
          anilistId: anilistId,
          mappedEpisode: episode ?? 1,
        );
      } else {
        animeIds = await EngineAnimeIds.resolve(
          tmdbId: tmdbId,
          mediaType: _tmdbResolveMediaType(mediaType),
          season: season ?? 1,
          episode: episode ?? 1,
          title: title,
          imdbId: movie?.imdbId,
          knownMalId: malId,
          knownAnilistId: anilistId,
          kinds: kinds,
        );
      }
      if (gen != _extractGeneration) return null;
    }
    final resolvedMal = animeIds?.malId ?? malId;
    final resolvedAnilist = animeIds?.anilistId ?? anilistId;
    final resolvedImdb = animeIds?.imdbId ?? movie?.imdbId;
    debugPrint(
      '[engine] ${active.id} start tmdb=$tmdbId type=$mediaType '
      's=$season e=$episode title=$title'
      '${resolvedMal != null ? ' mal=$resolvedMal' : ''}'
      '${resolvedAnilist != null ? ' anilist=$resolvedAnilist' : ''}'
      '${resolvedImdb != null && resolvedImdb.isNotEmpty ? ' imdb=$resolvedImdb' : ''}',
    );
    final sw = Stopwatch()..start();
    final raw = await rt.extract(
      pluginId: active.id,
      pluginName: active.name,
      tmdbId: tmdbId,
      imdbId: resolvedImdb,
      malId: resolvedMal,
      anilistId: resolvedAnilist,
      mappedEpisode: animeIds?.mappedEpisode,
      type: mediaType,
      season: season,
      episode: episode,
      title: title,
      year: year,
      config: config,
      movie: movie,
      // HTTP plugins: extract(ctx) only — no host / WebView / Dart extract fallbacks.
      timeout:
          EmbedExtractProfiles.resolve(active.id).timeout +
          const Duration(seconds: 30),
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
    if (plugin == null || !(plugin.isLivePlugin || plugin.isLiveSport)) {
      return [];
    }
    if (!plugin.enabled) return [];
    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = mergeEngineConfig(plugin.config, overlay);
    final code = await _loadScript(plugin);
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
    int? season,
    int? episode,
    String? title,
    String? year,
    Movie? movie,
    int? malId,
    int? anilistId,
    int? kisskhId,
    int? kisskhEpisodeId,
    bool allowHostFallback = false,
  }) async {
    // RFC-064: Forja EngineJS on tokio (true parallel). Null → flutter_js fork
    // only when Rust is unsupported — never after cancelPending gen bump
    // (that stampeded UI-isolate JSC forks mid-play → macOS SIGSEGV).
    final genAtStart = _extractGeneration;
    final viaRust = await _runHttpPluginRustJs(
      pluginId: pluginId,
      tmdbId: tmdbId,
      type: type,
      season: season,
      episode: episode,
      title: title,
      year: year,
      movie: movie,
      malId: malId,
      anilistId: anilistId,
      kisskhId: kisskhId,
      kisskhEpisodeId: kisskhEpisodeId,
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
        type: type,
        season: season,
        episode: episode,
        title: title,
        year: year,
        movie: movie,
        malId: malId,
        anilistId: anilistId,
        kisskhId: kisskhId,
        kisskhEpisodeId: kisskhEpisodeId,
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
    int? malId,
    int? anilistId,
    int? kisskhId,
    int? kisskhEpisodeId,
    bool allowHostFallback = false,
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
    if (plugin == null || !plugin.enabled || !plugin.isHttp) return null;

    final mediaType = _normalizeEngineMediaType(type);
    final overlay =
        ProviderRuntimeConfig.instance.engine[plugin.id] ?? const {};
    final config = engineConfigWithKissKhIds(
      mergeEngineConfig(plugin.config, overlay),
      pluginId: plugin.id,
      kisskhId: kisskhId,
      kisskhEpisodeId: kisskhEpisodeId,
    );
    final code = await _loadScript(plugin);
    if (gen != _extractGeneration || code == null) return null;

    EngineAnimeIdBundle? animeIds;
    if (EngineAnimeIds.pluginNeedsResolve(plugin)) {
      final kinds = EngineAnimeIds.requiredKinds(plugin);
      final haveMal =
          !kinds.contains('mal') || (malId != null && malId > 0);
      final haveAnilist =
          !kinds.contains('anilist') || (anilistId != null && anilistId > 0);
      if (haveMal && haveAnilist) {
        animeIds = EngineAnimeIdBundle(
          imdbId: movie?.imdbId,
          malId: malId,
          anilistId: anilistId,
          mappedEpisode: episode ?? 1,
        );
      } else {
        animeIds = await EngineAnimeIds.resolve(
          tmdbId: tmdbId,
          mediaType: _tmdbResolveMediaType(mediaType),
          season: season ?? 1,
          episode: episode ?? 1,
          title: title,
          imdbId: movie?.imdbId,
          knownMalId: malId,
          knownAnilistId: anilistId,
          kinds: kinds,
        );
      }
      if (gen != _extractGeneration) return null;
    }

    final timeout =
        EmbedExtractProfiles.resolve(plugin.id).timeout +
        const Duration(seconds: 30);
    final ctx = <String, Object?>{
      'tmdbId': tmdbId,
      'imdbId': animeIds?.imdbId ?? movie?.imdbId ?? '',
      'malId': animeIds?.malId ?? malId ?? '',
      'anilistId': animeIds?.anilistId ?? anilistId ?? '',
      'mappedEpisode': animeIds?.mappedEpisode ?? episode ?? 1,
      'type': mediaType,
      'season': season ?? 1,
      'episode': episode ?? 1,
      'title': title ?? '',
      'year': year ?? '',
      'url': '',
      'config': config,
    };

    final hopPayload = <Map<String, Object?>>[];
    for (final pack in packs) {
      for (final p in pack.plugins) {
        if (!p.isHop || !p.enabled) continue;
        final hopCode = await _loadScript(p);
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
      '${(animeIds?.malId ?? malId) != null ? ' mal=${animeIds?.malId ?? malId}' : ''}'
      '${(animeIds?.anilistId ?? anilistId) != null ? ' anilist=${animeIds?.anilistId ?? anilistId}' : ''}'
      '${(animeIds?.imdbId ?? movie?.imdbId)?.isNotEmpty == true ? ' imdb=${animeIds?.imdbId ?? movie?.imdbId}' : ''}'
      ' mappedEp=${animeIds?.mappedEpisode ?? episode ?? 1}',
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
      debugPrint('[engine] ${plugin.id} enginejs needs_host=$needsHost');
      final resolvedMovie =
          movie ??
          Movie(
            id: int.tryParse(tmdbId) ?? 0,
            imdbId: animeIds?.imdbId,
            title: title ?? '',
            posterPath: '',
            backdropPath: '',
            voteAverage: 0,
            releaseDate: year != null ? '$year-01-01' : '',
            mediaType: mediaType,
          );
      final hostPlugin = EnginePlugin(
        id: 'host:$needsHost',
        name: needsHost,
        entry: '',
        kind: 'host',
        hostId: needsHost,
      );
      try {
        final hostMapped = await EngineHostResolver.resolve(
          plugin: hostPlugin,
          movie: resolvedMovie,
          season: season ?? 1,
          episode: episode ?? 1,
          isCancelled: () => gen != _extractGeneration,
        );
        if (gen != _extractGeneration) return null;
        if (hostMapped.isNotEmpty) {
          debugPrint(
            '[engine] ${plugin.id} done (enginejs+host) streams=${hostMapped.length} '
            '${sw.elapsedMilliseconds}ms',
          );
          return EngineExtractResult(
            pluginId: plugin.id,
            pluginName: plugin.name,
            streams: hostMapped,
          );
        }
      } catch (e) {
        debugPrint('[engine] ${plugin.id} host fallback failed: $e');
      }
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
    if (t == 'anime') return 'anime';
    if (t == 'drama') return 'drama';
    return 'movie';
  }

  /// TMDB id-mapping APIs only understand movie/tv.
  static String _tmdbResolveMediaType(String mediaType) {
    if (mediaType == 'anime' || mediaType == 'drama') return 'tv';
    return mediaType;
  }
}
