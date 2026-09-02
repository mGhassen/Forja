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

  /// Cache manifest config before catalog ingest / display filters run.
  static void cachePluginMeta(EnginePlugin plugin) => _cachePluginMeta(plugin);

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

  /// PPV site origin — any plugin that declares `nativeUnlock: ppv`, else
  /// legacy catalog/live ppv ids when packs still use those ids.
  static Future<String> ppvWebOrigin() async {
    await warmPluginMeta();
    for (final e in _nativeUnlockByPluginId.entries) {
      if (e.value != 'ppv') continue;
      final o = await pluginWebOrigin(e.key);
      if (o.isNotEmpty) return o;
    }
    return pluginWebOrigin('ppv');
  }

  static Future<String> ppvWebReferer() async =>
      _refererForOrigin(await ppvWebOrigin());

  /// Sync host label after [ppvWebOrigin] has been resolved once.
  static String ppvHostLabelCached() {
    for (final e in _nativeUnlockByPluginId.entries) {
      if (e.value != 'ppv') continue;
      final o = _originByPluginId[e.key];
      if (o != null && o.isNotEmpty) {
        return Uri.tryParse(o)?.host ?? cachedPluginDisplayName(e.key);
      }
    }
    final o = _originByPluginId['ppv'];
    if (o == null || o.isEmpty) {
      return cachedPluginDisplayName('ppv');
    }
    return Uri.tryParse(o)?.host ?? cachedPluginDisplayName('ppv');
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

  static Future<List<Map<String, dynamic>>> fetchServerCatalog(
    String catalogId,
  ) async {
    await EngineService.instance.ensureOfficialInstalled();
    final plugin = await EngineService.instance.pluginById(catalogId);
    if (plugin == null || !plugin.supportsLiveCatalog) return [];
    _cachePluginMeta(plugin);
    return EngineService.instance.runLiveCatalog(catalogPlugin: plugin);
  }

  static Future<LiveEngineResolveResult?> _tryNativeUnlock({
    required String unlock,
    required String label,
    required Map<String, dynamic> params,
  }) async {
    switch (unlock) {
      case 'streamed':
        final native = await LiveGoatUnlock.resolveStreamed(
          embedUrl: (params['embedUrl'] ?? params['url'] ?? '').toString(),
          source: (params['source'] ?? '').toString(),
          matchId: (params['matchId'] ?? '').toString(),
          stream: (params['stream'] ?? '1').toString(),
        );
        if (native == null) return null;
        return LiveEngineResolveResult.playable(
          url: native.url,
          headers: native.headers,
          label: label,
        );
      case 'ppv':
        final embed = (params['embedUrl'] ?? params['iframe'] ?? '')
            .toString()
            .trim();
        if (embed.isEmpty) return null;
        final native = await LiveGoatUnlock.resolvePpv(embedUrl: embed);
        if (native == null) return null;
        return LiveEngineResolveResult.playable(
          url: native.url,
          headers: native.headers,
          label: label,
          directPlayback: LiveGoatUnlock.preferDirectEnginePlayback(native.url),
        );
      case 'watchfooty':
        final embed =
            (params['embedUrl'] ?? params['url'] ?? params['iframe'] ?? '')
                .toString()
                .trim();
        if (embed.isNotEmpty) {
          final native = await LiveGoatUnlock.resolveWatchfootyEmbed(
            embedUrl: embed,
          );
          if (native != null) {
            return LiveEngineResolveResult.playable(
              url: native.url,
              headers: native.headers,
              label: label,
              directPlayback: LiveGoatUnlock.preferDirectEnginePlayback(
                native.url,
              ),
            );
          }
        }
        final mid = (params['matchId'] ?? params['eventId'] ?? '')
            .toString()
            .trim()
            .replaceFirst(RegExp(r'^wf_'), '');
        if (mid.isEmpty) return null;
        final rows = await LiveGoatUnlock.resolveWatchfootyMatch(matchId: mid);
        if (rows.isEmpty) return null;
        final first = rows.first;
        return LiveEngineResolveResult.playable(
          url: first.url,
          headers: first.headers,
          label: first.name.isNotEmpty ? first.name : label,
          directPlayback: LiveGoatUnlock.preferDirectEnginePlayback(first.url),
        );
      default:
        return null;
    }
  }

  static Future<LiveEngineResolveResult?> resolve({
    required String pluginId,
    Map<String, dynamic> params = const {},
  }) async {
    final label = await pluginDisplayName(pluginId);
    final unlock = await pluginNativeUnlock(pluginId);
    if (unlock.isNotEmpty) {
      final native = await _tryNativeUnlock(
        unlock: unlock,
        label: label,
        params: params,
      );
      if (native != null) return native;
    }

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
          ? 'Engine resolve failed: no playable stream found'
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
