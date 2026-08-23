import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:forja/features/anime/catalog/miruro_pipe_session.dart';
import 'package:forja/shared/engine/anime_ids.dart';
import 'package:forja/shared/engine/categories.dart';
import 'package:forja/shared/engine/host_resolver.dart';
import 'package:forja/shared/engine/live_goat_unlock.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/runtime.dart';
import 'package:forja/shared/extractors/embed_extract_profiles.dart';
import 'package:forja/shared/extractors/providers/videasy/videasy_extractor.dart';
import 'package:forja/shared/playback/playback_stream_guards.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:http/http.dart' as http;
import 'package:rust/rust.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineService {
  EngineService._();
  static final EngineService instance = EngineService._();

  static const bundledSourceUrl = 'asset:plugins/engine.json';

  /// Internal `types: catalog` plugins — not shown in Settings toggles.
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

  /// Schedule catalogs implemented in `crates/live-matches` (RFC-065).
  static const _nativeLiveCatalogIds = {
    'catalog-espn',
    'catalog-timstreams',
    'catalog-streamic',
    'catalog-streamfree',
    'catalog-watchfooty',
  };
  static const _legacyBundledSourceUrlProviders = 'asset:providers/engine.json';
  static const _legacyBundledSourceUrl = 'asset:engine_js/engine.json';
  static const _assetRoot = 'assets/plugins';
  static const _packsKey = 'engine_js_packs_v1';
  static const _scriptPrefix = 'engine_js_script_';
  /// Legacy unscoped selection (migrated into `…_movie` once).
  static const _legacySelectedKey = 'engine_js_sources_selected_ids';
  static const _selectedKeyPrefix = 'engine_js_sources_selected_ids_';
  static const _selectAllDefaultKey = 'engine_js_sources_select_all_default';

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  int _extractGeneration = 0;
  int _liveCatalogGeneration = 0;
  EngineRuntime? _liveCatalogRuntime;
  Future<void>? _bundledEnsureFuture;
  bool _bundledReady = false;

  static bool isBundled(String sourceUrl) =>
      sourceUrl == bundledSourceUrl ||
      sourceUrl == _legacyBundledSourceUrlProviders ||
      sourceUrl == _legacyBundledSourceUrl;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  void cancelPending() {
    _extractGeneration++;
    cancelLiveCatalog();
    EngineRuntime.abortAll();
    // Kind-scoped: do not call Engine.cancelPendingResolve (kills magnet).
    Engine.cancelEngineJsExtracts();
  }

  /// Abort in-flight Forja Live catalog scrapes (tab hide / server switch).
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
    for (final p in hops) {
      final code = await _loadScript(p);
      if (code != null && code.isNotEmpty) {
        runtime.stashPluginCode(p.id, code);
      }
    }
  }

  Future<List<EnginePack>> listPacks() async {
    final cached = await _listPacksRaw();
    if (cached.isNotEmpty) {
      unawaited(ensureBundledInstalled());
      return cached;
    }
    await ensureBundledInstalled();
    return _listPacksRaw();
  }

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
    await ensureBundledInstalled();
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
    await ensureBundledInstalled();
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

  /// Enabled schedule catalogs — Settings → Forja Sports → **Catalog** toggles only.
  Future<List<EnginePlugin>> listEnabledLiveCatalogPlugins() async {
    await ensureBundledInstalled();
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

  static bool bundledPackUnchanged(EnginePack previous, EnginePack current) {
    if (previous.sourceUrl != bundledSourceUrl ||
        previous.version != current.version ||
        previous.plugins.length != current.plugins.length) {
      return false;
    }
    for (var i = 0; i < current.plugins.length; i++) {
      final prev = previous.plugins[i];
      final cur = current.plugins[i];
      if (prev.id != cur.id ||
          prev.entry != cur.entry ||
          prev.kind != cur.kind ||
          jsonEncode(prev.config) != jsonEncode(cur.config) ||
          jsonEncode(prev.hosts) != jsonEncode(cur.hosts)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _installBundled() async {
    final jsonStr = await rootBundle.loadString('$_assetRoot/engine.json');
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    var pack = EnginePack.fromJson(
      map,
      sourceUrl: bundledSourceUrl,
      bundled: true,
    );
    final all = await _listPacksRaw();
    EnginePack? previous;
    for (final a in all) {
      if (isBundled(a.sourceUrl)) {
        previous = a;
        break;
      }
    }
    if (previous != null) {
      final enabledById = {for (final p in previous.plugins) p.id: p.enabled};
      pack = pack.copyWithPlugins([
        for (final p in pack.plugins)
          p.copyWith(enabled: enabledById[p.id] ?? p.enabled),
      ]);
      if (bundledPackUnchanged(previous, pack)) {
        await _syncHops([pack]);
        return;
      }
    }
    final prefs = await _prefs;
    for (final plugin in pack.plugins) {
      if (plugin.entry.isEmpty) continue;
      if (!plugin.isHttp && !plugin.isHop) continue;
      final code = await rootBundle.loadString('$_assetRoot/${plugin.entry}');
      await prefs.setString(_scriptPrefix + plugin.id, code);
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

  static String _selectedPrefsKey(String panelCategory) =>
      '$_selectedKeyPrefix$panelCategory';

  Future<Set<String>> loadSourcesSelectedPluginIds({
    required Set<String> enabledIds,

    /// movie | tv | anime | drama — separate chip memory per Sources panel.
    required String panelCategory,

    /// When prefs have no saved selection and Select All by default is on,
    /// select this subset instead of every enabled plugin (soft categories).
    Set<String>? selectAllScopeIds,
  }) async {
    final prefs = await _prefs;
    final key = _selectedPrefsKey(panelCategory);
    var raw = prefs.getStringList(key);
    // One-shot: old global list → movie bucket only.
    if (raw == null && panelCategory == EngineCategories.movie) {
      final legacy = prefs.getStringList(_legacySelectedKey);
      if (legacy != null) {
        await prefs.setStringList(key, legacy);
        await prefs.remove(_legacySelectedKey);
        raw = legacy;
      }
    }
    if (raw == null) {
      final selectAll = await isSourcesSelectAllDefault();
      if (!selectAll) return {};
      final scope = selectAllScopeIds ?? enabledIds;
      return {
        for (final id in scope)
          if (enabledIds.contains(id)) id,
      };
    }
    return filterEngineSelectedPluginIds(savedIds: raw, enabledIds: enabledIds);
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

  Future<String?> _loadScript(EnginePlugin plugin) async {
    String? code;
    if (plugin.isLive && plugin.entry.isNotEmpty && isBundled(bundledSourceUrl)) {
      try {
        code = await rootBundle.loadString('$_assetRoot/${plugin.entry}');
      } catch (_) {}
    }
    if (code == null || code.isEmpty) {
      final prefs = await _prefs;
      final cached = prefs.getString(_scriptPrefix + plugin.id);
      if (cached != null && cached.isNotEmpty) code = cached;
    }
    if ((code == null || code.isEmpty) &&
        isBundled(bundledSourceUrl) &&
        plugin.entry.isNotEmpty) {
      try {
        code = await rootBundle.loadString('$_assetRoot/${plugin.entry}');
      } catch (_) {}
    }
    if (code == null || code.isEmpty) return null;
    if (plugin.entry.startsWith('live/') && !plugin.entry.contains('/goat/')) {
      try {
        final shared = await rootBundle.loadString(
          '$_assetRoot/live/embed-st.js',
        );
        code = '$shared\n$code';
      } catch (_) {}
    }
    return code;
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
    // Soft categories only — Sources filter hides chips; selected plugins always run.
    final mediaType = _normalizeEngineMediaType(type);

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
    final config = engineConfigWithKissKhIds(
      mergeEngineConfig(plugin.config, overlay),
      pluginId: plugin.id,
      kisskhId: kisskhId,
      kisskhEpisodeId: kisskhEpisodeId,
    );
    final code = await _loadScript(plugin);
    if (gen != _extractGeneration || code == null) return null;
    if (!rt.isLoaded(plugin.id)) {
      await rt.loadPlugin(pluginId: plugin.id, code: code);
    }
    if (gen != _extractGeneration) return null;
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
    final resolvedMal = animeIds?.malId ?? malId;
    final resolvedAnilist = animeIds?.anilistId ?? anilistId;
    final resolvedImdb = animeIds?.imdbId ?? movie?.imdbId;
    debugPrint(
      '[engine] ${plugin.id} start tmdb=$tmdbId type=$mediaType '
      's=$season e=$episode title=$title'
      '${resolvedMal != null ? ' mal=$resolvedMal' : ''}'
      '${resolvedAnilist != null ? ' anilist=$resolvedAnilist' : ''}'
      '${resolvedImdb != null && resolvedImdb.isNotEmpty ? ' imdb=$resolvedImdb' : ''}',
    );
    final sw = Stopwatch()..start();
    final raw = await rt.extract(
      pluginId: plugin.id,
      pluginName: plugin.name,
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
      // HTTP miss → ctx.host sniff (90s VidFast/VidRock). Default 30s
      // returned [] while HLS was already on the wire.
      timeout:
          EmbedExtractProfiles.resolve(plugin.id).timeout +
          const Duration(seconds: 30),
      allowHostFallback: allowHostFallback,
      isCancelled: () => gen != _extractGeneration,
    );
    if (gen != _extractGeneration) {
      debugPrint('[engine] ${plugin.id} cancelled after ${sw.elapsedMilliseconds}ms');
      return null;
    }
    var rawList = raw;
    // JS path under parallel All-walk often hangs on stalled HTTP bodies.
    // Dart VideasyExtractor has hard per-fetch timeouts — use it when JS is empty.
    if (rawList.isEmpty &&
        plugin.id == 'videasy' &&
        movie != null &&
        gen == _extractGeneration) {
      debugPrint('[engine] videasy JS empty — dart API fallback');
      try {
        final extracted = await VideasyExtractor(onLog: debugPrint).extract(
          tmdbId: tmdbId,
          isMovie: mediaType != 'tv',
          title: title ?? movie.title,
          year: VideasyExtractor.yearFromReleaseDate(
            year != null ? '$year-01-01' : movie.releaseDate,
          ),
          imdbId: animeIds?.imdbId ?? movie.imdbId,
          season: mediaType == 'tv' ? season : null,
          episode: mediaType == 'tv' ? episode : null,
          totalSeasons: mediaType == 'tv' ? movie.numberOfSeasons : null,
          isCancelled: () => gen != _extractGeneration,
        );
        if (extracted != null && extracted.sources != null) {
          rawList = [
            for (final s in extracted.sources!)
              if (s.url.trim().isNotEmpty)
                {
                  'url': s.url,
                  'name': s.title.isNotEmpty ? s.title : 'Videasy',
                  'quality': s.title,
                  if (s.headers != null && s.headers!.isNotEmpty)
                    'headers': s.headers,
                },
          ];
        }
      } catch (e) {
        debugPrint('[engine] videasy dart fallback failed: $e');
      }
    }
    if (rawList.isEmpty && gen == _extractGeneration) {
      rawList = await _animeEngineFallbacks(
        pluginId: plugin.id,
        anilistId: resolvedAnilist,
        episode: animeIds?.mappedEpisode ?? episode ?? 1,
        isCancelled: () => gen != _extractGeneration,
      );
    }
    if (gen != _extractGeneration) {
      debugPrint('[engine] ${plugin.id} cancelled after ${sw.elapsedMilliseconds}ms');
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
      '[engine] ${plugin.id} done raw=${rawList.length} streams=${streams.length} '
      '${sw.elapsedMilliseconds}ms',
    );
    return EngineExtractResult(
      pluginId: plugin.id,
      pluginName: plugin.name,
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

    final viaNative = await _runLiveCatalogNativeRust(
      catalogPlugin: catalogPlugin,
      config: config,
      gen: gen,
      generation: () => _liveCatalogGeneration,
    );
    if (viaNative != null) return viaNative;
    if (gen != _liveCatalogGeneration) return [];

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

  /// Native Rust schedule fetch — `forja_live_catalog` in live-matches.
  Future<List<Map<String, dynamic>>?> _runLiveCatalogNativeRust({
    required EnginePlugin catalogPlugin,
    required Map<String, dynamic> config,
    required int gen,
    required int Function() generation,
  }) async {
    if (!_nativeLiveCatalogIds.contains(catalogPlugin.id)) return null;
    if (gen != generation()) return null;

    debugPrint('[engine] ${catalogPlugin.id} start (native catalog)');
    final sw = Stopwatch()..start();
    try {
      final raw = await runLiveMatchesFetchJson(
        jsonEncode({
          'action': 'forja_live_catalog',
          'catalog_id': catalogPlugin.id,
          'config': config,
        }),
      );
      if (gen != generation()) return null;
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return null;
      if (parsed.containsKey('error')) {
        debugPrint(
          '[engine] ${catalogPlugin.id} native catalog error: ${parsed['error']}',
        );
        return null;
      }
      final items = parsed['items'];
      if (items is! List) return [];
      final rows = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
      debugPrint(
        '[engine] ${catalogPlugin.id} done (native catalog) raw=${rows.length} '
        '${sw.elapsedMilliseconds}ms',
      );
      return rows;
    } catch (e) {
      debugPrint('[engine] ${catalogPlugin.id} native catalog failed: $e');
      return null;
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
      debugPrint('[engine] ${plugin.id} enginejs live error: ${decoded['error']}');
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
    bool allowHostFallback = true,
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
    bool allowHostFallback = true,
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
      's=$season e=$episode title=$title hops=${hopPayload.length}',
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
      debugPrint('[engine] ${plugin.id} enginejs job error: ${decoded['error']}');
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
    if (effectiveRaw.isEmpty &&
        plugin.id == 'videasy' &&
        movie != null &&
        gen == _extractGeneration) {
      debugPrint('[engine] videasy enginejs empty — dart API fallback');
      try {
        final extracted = await VideasyExtractor(onLog: debugPrint).extract(
          tmdbId: tmdbId,
          isMovie: mediaType != 'tv',
          title: title ?? movie.title,
          year: VideasyExtractor.yearFromReleaseDate(
            year != null ? '$year-01-01' : movie.releaseDate,
          ),
          imdbId: animeIds?.imdbId ?? movie.imdbId,
          season: mediaType == 'tv' ? season : null,
          episode: mediaType == 'tv' ? episode : null,
          totalSeasons: mediaType == 'tv' ? movie.numberOfSeasons : null,
          isCancelled: () => gen != _extractGeneration,
        );
        if (extracted?.sources != null) {
          effectiveRaw = [
            for (final s in extracted!.sources!)
              if (s.url.trim().isNotEmpty)
                {
                  'url': s.url,
                  'name': s.title.isNotEmpty ? s.title : 'Videasy',
                  'quality': s.title,
                  if (s.headers != null && s.headers!.isNotEmpty)
                    'headers': s.headers,
                },
          ];
        }
      } catch (e) {
        debugPrint('[engine] videasy dart fallback failed: $e');
      }
    }
    if (effectiveRaw.isEmpty && gen == _extractGeneration) {
      effectiveRaw = await _animeEngineFallbacks(
        pluginId: plugin.id,
        anilistId: animeIds?.anilistId ?? anilistId,
        episode: animeIds?.mappedEpisode ?? episode ?? 1,
        isCancelled: () => gen != _extractGeneration,
      );
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

  /// When JS HTTP is empty (CF / wrong paths), reuse Rust+WebView anime extractors.
  Future<List<Map<String, dynamic>>> _animeEngineFallbacks({
    required String pluginId,
    required int? anilistId,
    required int episode,
    required bool Function() isCancelled,
  }) async {
    final al = anilistId ?? 0;
    if (al <= 0 || isCancelled()) return const [];

    if (pluginId == 'miruro') {
      debugPrint('[engine] miruro JS empty — dart CF pipe fallback');
      const providers = ['bee', 'kiwi', 'zoro', 'bonk', 'ally', 'moo', 'hop', 'bun'];
      final tasks = <Future<List<Map<String, dynamic>>>>[];
      for (final cat in ['sub', 'dub']) {
        for (final prov in providers) {
          tasks.add(() async {
            if (isCancelled()) return const <Map<String, dynamic>>[];
            try {
              final resolved = await miruroResolveWithCfFallback(
                anilistId: al,
                episodeNumber: episode,
                category: cat,
                provider: prov,
                fetchPipeViaWebView: MiruroPipeSession.instance.get,
              );
              final label = miruroUpstreamSources[prov] ?? prov;
              return [
                for (final s in resolved.streams)
                  if (s.url.trim().isNotEmpty)
                    {
                      'url': s.url,
                      'name': 'Miruro $label ${cat.toUpperCase()}',
                      'language': cat == 'dub' ? 'Dub' : 'Sub',
                      'headers': {
                        if (s.referer.isNotEmpty) 'Referer': s.referer,
                        if (s.origin.isNotEmpty) 'Origin': s.origin,
                      },
                    },
              ];
            } catch (e) {
              debugPrint('[engine] miruro dart fallback $prov/$cat: $e');
              return const <Map<String, dynamic>>[];
            }
          }());
        }
      }
      final groups = await Future.wait(tasks);
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final rows in groups) {
        for (final r in rows) {
          final u = (r['url'] ?? '').toString();
          if (u.isEmpty || !seen.add(u)) continue;
          out.add(r);
        }
      }
      return out;
    }

    if (pluginId == 'vidnest-anime') {
      debugPrint('[engine] vidnest-anime JS empty — dart API fallback');
      final out = <Map<String, dynamic>>[];
      for (final prov in vidnestKnownProviders) {
        for (final cat in ['sub', 'dub']) {
          if (isCancelled()) return out;
          try {
            final res = await vidnestExtractWithProvider(
              anilistId: al,
              episodeNumber: episode,
              category: cat,
              provider: prov,
            );
            if (res == null || res.url.trim().isEmpty) continue;
            out.add({
              'url': res.url,
              'name':
                  '${vidnestUpstreamLabels[prov] ?? prov} (${cat.toUpperCase()})',
              'language': cat == 'dub' ? 'Dub' : 'Sub',
              'headers': {
                if (res.referer.isNotEmpty) 'Referer': res.referer,
                if (res.origin.isNotEmpty) 'Origin': res.origin,
              },
            });
          } catch (e) {
            debugPrint('[engine] vidnest-anime dart fallback $prov/$cat: $e');
          }
        }
      }
      return out;
    }

    return const [];
  }
}
