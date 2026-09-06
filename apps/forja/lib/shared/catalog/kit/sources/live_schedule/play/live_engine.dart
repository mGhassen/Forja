import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// Live Matches engine plugin orchestration (RFC-065).
///
/// Site origins, labels, and native unlock paths come from plugin/catalog
/// **config** — not a hardcoded list of third-party plugin ids.
class LiveMatchesEngine {
  LiveMatchesEngine._();

  static final Map<String, String> _originByPluginId = {};
  static final Map<String, String> _nameByPluginId = {};
  static final Map<String, String> _nativeUnlockByPluginId = {};
  static final Map<String, bool> _airingOnlyLiveByPluginId = {};
  static final Map<String, String> _scheduleHorizonModeByPluginId = {};
  static final Map<String, String> _catalogLayoutByPluginId = {};
  static final Map<String, bool> _catalogUncappedByPluginId = {};
  static final Map<String, bool> _scheduleEnrichByPluginId = {};
  static final Map<String, String> _providerResolveIdByPluginId = {};
  static final Map<String, String> _matchIdPrefixByPluginId = {};
  static final Map<String, String> _resolveSourceByPluginId = {};

  static Future<bool> isEngineResolveMode() async {
    if (!AccountFeatures.instance.isAdmin) return true;
    return SettingsService().isLiveStreamResolveEngine();
  }

  static String _normalizeOrigin(String raw) {
    var t = raw.trim();
    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static String _refererForOrigin(String origin) {
    final o = _normalizeOrigin(origin);
    if (o.isEmpty) return '';
    return '$o/';
  }

  static String? _originFromConfig(Map<String, dynamic> cfg) {
    final direct = _normalizeOrigin(
      (cfg['webOrigin'] ?? cfg['origin'] ?? '').toString(),
    );
    if (direct.isNotEmpty) return direct;
    final api = (cfg['api'] ?? '').toString().trim();
    if (api.isEmpty) return null;
    final host = Uri.tryParse(api)?.origin;
    if (host == null || host.isEmpty) return null;
    return _normalizeOrigin(host);
  }

  static void _cachePluginMeta(EnginePlugin plugin) {
    final key = _metaPluginKey(plugin.id);
    _nameByPluginId[key] = plugin.name;
    final unlock = (plugin.config['nativeUnlock'] ?? '').toString().trim();
    if (unlock.isNotEmpty) {
      _nativeUnlockByPluginId[key] = unlock.toLowerCase();
    }
    if (plugin.config['airingOnlyLive'] == true) {
      _airingOnlyLiveByPluginId[key] = true;
    }
    final scheduleHorizon = scheduleHorizonModeFromConfig(plugin.config);
    if (scheduleHorizon != null) {
      _scheduleHorizonModeByPluginId[key] = scheduleHorizon;
    }
    final origin = _originFromConfig(plugin.config);
    if (origin != null && origin.isNotEmpty) {
      _originByPluginId[key] = origin;
    }
    _catalogLayoutByPluginId[key] = catalogLayoutFromConfig(plugin.config);
    _catalogUncappedByPluginId[key] = catalogUncappedFromConfig(plugin.config);
    _scheduleEnrichByPluginId[key] =
        isScheduleEnrichCatalogConfig(plugin.config);
    final providerId = (plugin.config['providerId'] ?? '').toString().trim();
    if (providerId.isNotEmpty) {
      _providerResolveIdByPluginId[key] = providerId;
    }
    final matchIdPrefix =
        (plugin.config['matchIdPrefix'] ?? '').toString().trim();
    if (matchIdPrefix.isNotEmpty) {
      _matchIdPrefixByPluginId[key] = matchIdPrefix;
    }
    final resolveSource =
        (plugin.config['resolveSource'] ?? '').toString().trim();
    if (resolveSource.isNotEmpty) {
      _resolveSourceByPluginId[key] = resolveSource.toLowerCase();
    }
  }

  static String _metaPluginKey(String pluginId) =>
      EngineService.normalizeLiveSportPluginId(pluginId);

  /// Pack manifest `config.scheduleHorizon` (e.g. `fullDay` scoreboard catalogs).
  static String? scheduleHorizonModeFromConfig(Map<String, dynamic> config) {
    final mode =
        (config['scheduleHorizon'] ?? '').toString().trim().toLowerCase();
    return mode.isEmpty ? null : mode;
  }

  static bool scheduleFullDayFromConfig(Map<String, dynamic> config) =>
      scheduleHorizonModeFromConfig(config) == 'fullday';

  /// Pack `config.catalogLayout` — `iframe` rows land in the iframe grid bucket.
  static String catalogLayoutFromConfig(Map<String, dynamic> config) {
    final layout =
        (config['catalogLayout'] ?? 'schedule').toString().trim().toLowerCase();
    return layout.isEmpty ? 'schedule' : layout;
  }

  static bool isIframeCatalogConfig(Map<String, dynamic> config) =>
      catalogLayoutFromConfig(config) == 'iframe';

  static bool isIframeCatalogPlugin(EnginePlugin plugin) =>
      isIframeCatalogConfig(plugin.config);

  static bool cachedIsIframeCatalog(String pluginId) {
    if (pluginId.isEmpty) return false;
    return _catalogLayoutByPluginId[_metaPluginKey(pluginId)] == 'iframe';
  }

  /// Pack `config.catalogCap` — when false, ingest is not capped per plugin.
  static bool catalogUncappedFromConfig(Map<String, dynamic> config) {
    final cap = config['catalogCap'];
    if (cap is bool) return !cap;
    if (cap is num) return cap <= 0;
    return config['uncappedCatalog'] == true;
  }

  static bool cachedCatalogUncapped(String pluginId) {
    if (pluginId.isEmpty) return false;
    return _catalogUncappedByPluginId[_metaPluginKey(pluginId)] == true;
  }

  /// Full-day scoreboard catalogs that publish `sportMatchGame` for team merge.
  static bool isScheduleEnrichCatalogConfig(Map<String, dynamic> config) {
    if (!scheduleFullDayFromConfig(config)) return false;
    final leagues = config['leagues'];
    return leagues is List && leagues.isNotEmpty;
  }

  static bool isScheduleEnrichCatalogPlugin(EnginePlugin plugin) =>
      isScheduleEnrichCatalogConfig(plugin.config);

  static bool cachedIsScheduleEnrichCatalog(String pluginId) {
    if (pluginId.isEmpty) return false;
    return _scheduleEnrichByPluginId[_metaPluginKey(pluginId)] == true;
  }

  /// Pack `config.providerId` — catalog row → live resolve plugin (opaque passthrough).
  static String cachedProviderResolvePluginId(String pluginId) {
    if (pluginId.isEmpty) return '';
    final key = _metaPluginKey(pluginId);
    final configured = _providerResolveIdByPluginId[key];
    if (configured != null && configured.isNotEmpty) return configured;
    return pluginId.trim();
  }

  /// Resolve param `source` token — pack `resolveSource`, else `nativeUnlock`, else slug.
  static String cachedResolveSourceToken(String pluginId) {
    if (pluginId.isEmpty) return '';
    final key = _metaPluginKey(pluginId);
    final explicit = _resolveSourceByPluginId[key];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final unlock = _nativeUnlockByPluginId[key];
    if (unlock != null && unlock.isNotEmpty) return unlock;
    return key;
  }

  /// Strip pack-declared `matchIdPrefix` / `{slug}_` before live `resolve`.
  static String cachedResolveRefId(String rowId, String pluginId) {
    final id = rowId.trim();
    if (id.isEmpty) return '';
    final key = _metaPluginKey(pluginId);
    final prefixes = <String>[];
    final configured = _matchIdPrefixByPluginId[key];
    if (configured != null && configured.isNotEmpty) prefixes.add(configured);
    if (key.isNotEmpty) prefixes.add('${key}_');
    for (final prefix in prefixes) {
      if (prefix.isEmpty || id.length <= prefix.length) continue;
      if (id.toLowerCase().startsWith(prefix.toLowerCase())) {
        return id.substring(prefix.length);
      }
    }
    return id;
  }

  static bool linkedProviderResolvePlugin(EnginePlugin catalog) {
    return (catalog.config['providerId'] ?? '').toString().trim().isNotEmpty;
  }

  /// Schedule catalogs that feed Providers (`live-*` resolve), not enrich/broadcast-only.
  static bool isProviderStreamCatalog(EnginePlugin plugin) {
    if (!plugin.supportsLiveCatalog) return false;
    if (isScheduleEnrichCatalogPlugin(plugin)) return false;
    if (plugin.supportsLiveBroadcast && !linkedProviderResolvePlugin(plugin)) {
      return false;
    }
    return linkedProviderResolvePlugin(plugin);
  }

  static String? cachedIframeProviderResolvePluginId() {
    for (final entry in _catalogLayoutByPluginId.entries) {
      if (entry.value != 'iframe') continue;
      final resolveId = _providerResolveIdByPluginId[entry.key];
      if (resolveId != null && resolveId.isNotEmpty) return resolveId;
    }
    return null;
  }

  static String resolvePluginKey(String pluginId) =>
      EngineService.normalizeLiveSportPluginId(
        cachedProviderResolvePluginId(pluginId),
      );

  /// Warm web origin for iframe-layout catalogs (embed Referer on first load).
  static Future<void> warmIframeCatalogWebOrigin() async {
    await warmPluginMeta();
    for (final e in _catalogLayoutByPluginId.entries) {
      if (e.value != 'iframe') continue;
      final o = await pluginWebOrigin(e.key);
      if (o.isNotEmpty) return;
    }
  }

  /// Cache manifest config before catalog ingest / display filters run.
  static void cachePluginMeta(EnginePlugin plugin) => _cachePluginMeta(plugin);

  /// Drop in-memory manifest-derived flags after catalog/live pack changes.
  static void invalidateDerivedCaches() {
    _originByPluginId.clear();
    _nameByPluginId.clear();
    _nativeUnlockByPluginId.clear();
    _airingOnlyLiveByPluginId.clear();
    _scheduleHorizonModeByPluginId.clear();
    _catalogLayoutByPluginId.clear();
    _catalogUncappedByPluginId.clear();
    _scheduleEnrichByPluginId.clear();
    _providerResolveIdByPluginId.clear();
    _matchIdPrefixByPluginId.clear();
    _resolveSourceByPluginId.clear();
  }

  /// Warm name/origin/unlock caches from installed live + catalog plugins.
  static Future<void> warmPluginMeta() async {
    await EngineService.instance.ensureOfficialInstalled();
    for (final p in await EngineService.instance.listLivePluginsForSettings()) {
      _cachePluginMeta(p);
    }
    for (final p
        in await EngineService.instance.listEnabledLiveCatalogPlugins()) {
      _cachePluginMeta(p);
    }
    // Disabled catalogs still carry config for warm cache.
    for (final pack in await EngineService.instance.listPacks()) {
      for (final p in pack.plugins) {
        if (p.isLiveSportPlugin || p.isLiveCatalog) _cachePluginMeta(p);
      }
    }
  }

  /// Merged plugin config (manifest + remote overlay).
  static Future<Map<String, dynamic>> pluginConfig(String pluginId) async {
    await EngineService.instance.ensureOfficialInstalled();
    final plugin = await EngineService.instance.pluginById(pluginId);
    if (plugin == null) return const {};
    _cachePluginMeta(plugin);
    final overlay =
        ProviderRuntimeConfig.instance.engine[pluginId] ?? const {};
    return mergeEngineConfig(plugin.config, overlay);
  }

  /// Site origin from plugin/catalog `webOrigin` / `origin` / `api` host.
  static Future<String> pluginWebOrigin(String pluginId) async {
    final normalized = EngineService.normalizeLiveSportPluginId(pluginId);
    if (normalized.isEmpty) return '';
    final cached = _originByPluginId[normalized];
    if (cached != null && cached.isNotEmpty) return cached;

    final cfg = await pluginConfig(normalized);
    final fromCfg = _originFromConfig(cfg);
    if (fromCfg != null && fromCfg.isNotEmpty) {
      _originByPluginId[normalized] = fromCfg;
      return fromCfg;
    }

    await warmPluginMeta();
    return _originByPluginId[normalized] ?? '';
  }

  /// Catalog-site Referer for iframe / unlock wrappers.
  static Future<String> pluginReferer(
    String pluginId, {
    String embedUrl = '',
  }) async {
    final origin = await pluginWebOrigin(pluginId);
    if (origin.isNotEmpty) return _refererForOrigin(origin);
    final uri = Uri.tryParse(embedUrl.trim());
    if (uri != null && uri.host.isNotEmpty) return '${uri.origin}/';
    return '';
  }

  /// Display name from plugin/catalog manifest (`name`), never a Dart allowlist.
  static Future<String> pluginDisplayName(String pluginId) async {
    final normalized = EngineService.normalizeLiveSportPluginId(pluginId);
    if (normalized.isEmpty) return 'Forja Live';
    final cached = _nameByPluginId[normalized];
    if (cached != null && cached.isNotEmpty) return cached;
    final plugin = await EngineService.instance.pluginById(normalized);
    if (plugin != null) {
      _cachePluginMeta(plugin);
      return plugin.name;
    }
    await warmPluginMeta();
    return _nameByPluginId[normalized] ?? normalized;
  }

  /// Sync label after [warmPluginMeta] / [pluginDisplayName] has run.
  static String cachedPluginDisplayName(String pluginId) {
    final normalized = EngineService.normalizeLiveSportPluginId(pluginId);
    if (normalized.isEmpty) return 'Forja Live';
    return _nameByPluginId[normalized] ?? normalized;
  }

  /// Sync Referer after [warmPluginMeta] / [pluginReferer] has populated origins.
  static String cachedPluginReferer(String pluginId) {
    final o = _originByPluginId[_metaPluginKey(pluginId)];
    if (o == null || o.isEmpty) return '';
    return _refererForOrigin(o);
  }

  /// Host capability declared on the plugin (`nativeUnlock` in config).
  static Future<String> pluginNativeUnlock(String pluginId) async {
    final normalized = EngineService.normalizeLiveSportPluginId(pluginId);
    if (normalized.isEmpty) return '';
    final cached = _nativeUnlockByPluginId[normalized];
    if (cached != null) return cached;
    final cfg = await pluginConfig(normalized);
    final unlock = (cfg['nativeUnlock'] ?? '').toString().trim().toLowerCase();
    _nativeUnlockByPluginId[normalized] = unlock;
    return unlock;
  }

  static bool cachedIsNativeUnlock(String pluginId, String kind) {
    final k = kind.trim().toLowerCase();
    if (k.isEmpty || pluginId.isEmpty) return false;
    return _nativeUnlockByPluginId[_metaPluginKey(pluginId)] == k;
  }

  /// First live plugin id that declares [kind] (`nativeUnlock`), if any.
  static String? cachedPluginIdForNativeUnlock(String kind) {
    final k = kind.trim().toLowerCase();
    if (k.isEmpty) return null;
    for (final e in _nativeUnlockByPluginId.entries) {
      if (e.value == k) return e.key;
    }
    return null;
  }

  /// When true, ● LIVE follows catalog `airing` only (no kickoff-window fudge).
  static bool cachedAiringOnlyLive(String pluginId) {
    if (pluginId.isEmpty) return false;
    return _airingOnlyLiveByPluginId[_metaPluginKey(pluginId)] == true;
  }

  /// Pack manifest `scheduleHorizon` (e.g. `fullDay` scoreboard catalogs).
  static String? cachedScheduleHorizonMode(String pluginId) {
    if (pluginId.isEmpty) return null;
    return _scheduleHorizonModeByPluginId[_metaPluginKey(pluginId)];
  }

  static bool cachedScheduleFullDay(String pluginId) =>
      cachedScheduleHorizonMode(pluginId) == 'fullday';

  /// Enabled catalog plugins with `catalogLayout: iframe` (embed grid bucket).
  static Future<List<EnginePlugin>> enabledIframeCatalogPlugins() async {
    await warmPluginMeta();
    final out = <EnginePlugin>[];
    for (final p in await EngineService.instance.listEnabledLiveCatalogPlugins()) {
      if (isIframeCatalogPlugin(p)) out.add(p);
    }
    return out;
  }

  /// Enabled schedule catalogs that link to a live resolve plugin (`providerId`).
  static Future<List<EnginePlugin>> enabledScheduleStreamCatalogPlugins() async {
    await warmPluginMeta();
    final out = <EnginePlugin>[];
    for (final p in await EngineService.instance.listEnabledLiveCatalogPlugins()) {
      if (!isProviderStreamCatalog(p) || isIframeCatalogPlugin(p)) continue;
      out.add(p);
    }
    return out;
  }

  /// Site origin for the first iframe-layout catalog (manifest `webOrigin` / `origin`).
  static Future<String> iframeCatalogWebOrigin() async {
    await warmPluginMeta();
    for (final e in _catalogLayoutByPluginId.entries) {
      if (e.value != 'iframe') continue;
      final o = await pluginWebOrigin(e.key);
      if (o.isNotEmpty) return o;
    }
    return '';
  }

  static Future<String> iframeCatalogWebReferer() async =>
      _refererForOrigin(await iframeCatalogWebOrigin());

  /// Sync label for iframe-layout catalogs after [warmPluginMeta].
  static String iframeCatalogHostLabelCached() {
    for (final e in _catalogLayoutByPluginId.entries) {
      if (e.value != 'iframe') continue;
      final o = _originByPluginId[e.key];
      if (o != null && o.isNotEmpty) {
        return Uri.tryParse(o)?.host ?? cachedPluginDisplayName(e.key);
      }
      final name = cachedPluginDisplayName(e.key);
      if (name.isNotEmpty) return name;
    }
    return 'Live';
  }

  /// Sync label for the first linked schedule catalog (legacy server picker).
  static String scheduleStreamCatalogHostLabelCached() {
    for (final e in _catalogLayoutByPluginId.entries) {
      if (e.value == 'iframe') continue;
      final linked = _providerResolveIdByPluginId[e.key];
      if (linked == null || linked.isEmpty) continue;
      final o = _originByPluginId[e.key];
      if (o != null && o.isNotEmpty) {
        return Uri.tryParse(o)?.host ?? cachedPluginDisplayName(e.key);
      }
      final name = cachedPluginDisplayName(e.key);
      if (name.isNotEmpty) return name;
    }
    return 'Schedule';
  }

  static Future<List<Map<String, dynamic>>> fetchCatalog() async {
    await EngineService.instance.ensureOfficialInstalled();
    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (catalogPlugins.isEmpty) return [];

    final all = <Map<String, dynamic>>[];
    try {
      for (final catalog in catalogPlugins) {
        _cachePluginMeta(catalog);
        final batch = await EngineService.instance.runLiveCatalog(
          catalogPlugin: catalog,
        );
        all.addAll(batch);
      }
      return all.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      debugPrint('[LiveMatchesEngine] catalog: $e');
      return all;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCatalogPlugin(
    EnginePlugin catalogPlugin,
  ) async {
    if (!catalogPlugin.supportsLiveCatalog &&
        !catalogPlugin.supportsLiveBroadcast) {
      return [];
    }
    _cachePluginMeta(catalogPlugin);
    return EngineService.instance.runLiveCatalog(catalogPlugin: catalogPlugin);
  }

  static Future<LiveEngineResolveResult?> resolve({
    required String pluginId,
    Map<String, dynamic> params = const {},
  }) async {
    final label = await pluginDisplayName(pluginId);
    final raw = await EngineService.instance.runLivePlugin(
      pluginId: pluginId,
      action: 'resolve',
      params: params,
    );
    if (raw.isEmpty) return null;
    final first = raw.first;
    if (first['webviewOnly'] == true) {
      return LiveEngineResolveResult.webviewOnly(
        embedUrl: (first['embedUrl'] ?? params['embedUrl'] ?? '').toString(),
      );
    }
    final url = (first['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    // Embed HTML pages are not native-playable (no-embed-playback).
    final ready = url.toLowerCase().contains('127.0.0.1') ||
        url.toLowerCase().contains('/hls-proxy') ||
        RegExp(r'\.m3u8(\?|$)|\.mp4(\?|$)', caseSensitive: false).hasMatch(url);
    if (!ready) return null;
    final headers = <String, String>{};
    final h = first['headers'];
    if (h is Map) {
      h.forEach((k, v) => headers[k.toString()] = v.toString());
    }
    return LiveEngineResolveResult.playable(
      url: url,
      headers: headers,
      label: (first['name'] ?? first['title'] ?? label).toString(),
      directPlayback: first['directPlayback'] == true,
    );
  }

  static Future<String?> proxyPlayUrl({
    required String url,
    Map<String, String> headers = const {},
  }) async {
    final proxy = LocalServerService();
    await proxy.start();
    if (proxy.port <= 0) return url;
    return proxy.getHlsProxyUrl(url, headers);
  }

  static void engineResolveFailed([String? detail]) {
    ForjaToast.error(
      detail == null || detail.isEmpty
          ? 'No playable stream found'
          : detail,
    );
  }
}

class LiveEngineResolveResult {
  const LiveEngineResolveResult._({
    required this.playable,
    this.url = '',
    this.headers = const {},
    this.label = '',
    this.embedUrl = '',
    this.directPlayback = false,
  });

  factory LiveEngineResolveResult.playable({
    required String url,
    Map<String, String> headers = const {},
    String label = '',
    bool directPlayback = false,
  }) => LiveEngineResolveResult._(
    playable: true,
    url: url,
    headers: headers,
    label: label,
    directPlayback: directPlayback,
  );

  factory LiveEngineResolveResult.webviewOnly({required String embedUrl}) =>
      LiveEngineResolveResult._(playable: false, embedUrl: embedUrl);

  final bool playable;
  final String url;
  final Map<String, String> headers;
  final String label;
  final String embedUrl;
  final bool directPlayback;
}

bool liveEnginePreferDirectPlayback(String m3u8Url) {
  return LiveGoatUnlock.preferDirectEnginePlayback(m3u8Url);
}

/// Plugin `directPlayback` must not force a MediaKit open of `wfty.st` —
/// that CDN needs `/hls-proxy` so child playlists keep sportsembed Referer.
bool liveEngineOpenDirect(String m3u8Url, {bool pluginDirect = false}) {
  final host = Uri.tryParse(m3u8Url.trim())?.host.toLowerCase() ?? '';
  if (host.contains('wfty.st')) return false;
  return pluginDirect || liveEnginePreferDirectPlayback(m3u8Url);
}
