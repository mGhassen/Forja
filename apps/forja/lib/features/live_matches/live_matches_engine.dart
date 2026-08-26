import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:rust/rust.dart';

/// Live Matches engine plugin orchestration (RFC-065).
class LiveMatchesEngine {
  LiveMatchesEngine._();

  static String? _cachedPpvWebOrigin;

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

  /// Merged plugin config (`engine.json` + remote overlay).
  static Future<Map<String, dynamic>> pluginConfig(String pluginId) async {
    await EngineService.instance.ensureBundledInstalled();
    final plugin = await EngineService.instance.pluginById(pluginId);
    if (plugin == null) return const {};
    final overlay =
        ProviderRuntimeConfig.instance.engine[pluginId] ?? const {};
    return mergeEngineConfig(plugin.config, overlay);
  }

  /// Site origin from plugin `webOrigin` / `origin` (no trailing slash).
  static Future<String> pluginWebOrigin(String pluginId) async {
    final cfg = await pluginConfig(pluginId);
    final raw = (cfg['webOrigin'] ?? cfg['origin'] ?? '').toString();
    return _normalizeOrigin(raw);
  }

  /// PPV catalog site origin — `live-ppv` / `catalog-ppv` config only.
  static Future<String> ppvWebOrigin() async {
    final cached = _cachedPpvWebOrigin;
    if (cached != null && cached.isNotEmpty) return cached;
    var origin = await pluginWebOrigin('live-ppv');
    if (origin.isEmpty) origin = await pluginWebOrigin('catalog-ppv');
    if (origin.isNotEmpty) _cachedPpvWebOrigin = origin;
    return origin;
  }

  static Future<String> ppvWebReferer() async =>
      _refererForOrigin(await ppvWebOrigin());

  /// Sync host label after [ppvWebOrigin] has been resolved once.
  static String ppvHostLabelCached() {
    final o = _cachedPpvWebOrigin;
    if (o == null || o.isEmpty) return 'PPV';
    return Uri.tryParse(o)?.host ?? 'PPV';
  }

  static Future<List<Map<String, dynamic>>> fetchCatalog() async {
    await EngineService.instance.ensureBundledInstalled();
    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (catalogPlugins.isEmpty) return [];

    final all = <Map<String, dynamic>>[];
    try {
      for (final catalog in catalogPlugins) {
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
    await EngineService.instance.ensureBundledInstalled();
    final plugin = await EngineService.instance.pluginById(catalogId);
    if (plugin == null || !plugin.isLiveCatalog) return [];
    return EngineService.instance.runLiveCatalog(catalogPlugin: plugin);
  }

  static Future<LiveEngineResolveResult?> resolve({
    required String pluginId,
    Map<String, dynamic> params = const {},
  }) async {
    if (pluginId == 'live-streamed') {
      final native = await LiveGoatUnlock.resolveStreamed(
        embedUrl: (params['embedUrl'] ?? params['url'] ?? '').toString(),
        source: (params['source'] ?? '').toString(),
        matchId: (params['matchId'] ?? '').toString(),
        stream: (params['stream'] ?? '1').toString(),
      );
      if (native != null) {
        return LiveEngineResolveResult.playable(
          url: native.url,
          headers: native.headers,
          label: 'Streamed',
        );
      }
    }

    if (pluginId == 'live-ppv') {
      final embed = (params['embedUrl'] ?? params['iframe'] ?? '')
          .toString()
          .trim();
      if (embed.isNotEmpty) {
        final native = await LiveGoatUnlock.resolvePpv(embedUrl: embed);
        if (native != null) {
          return LiveEngineResolveResult.playable(
            url: native.url,
            headers: native.headers,
            label: 'PPV',
          );
        }
      }
    }

    if (pluginId == 'live-watchfooty') {
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
            label: 'WatchFooty',
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
      if (mid.isNotEmpty) {
        final rows = await LiveGoatUnlock.resolveWatchfootyMatch(matchId: mid);
        if (rows.isNotEmpty) {
          final first = rows.first;
          return LiveEngineResolveResult.playable(
            url: first.url,
            headers: first.headers,
            label: first.name,
            directPlayback: LiveGoatUnlock.preferDirectEnginePlayback(first.url),
          );
        }
      }
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
      label: (first['name'] ?? first['title'] ?? pluginId).toString(),
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
  final path = (Uri.tryParse(m3u8Url.trim())?.path ?? '').toLowerCase();
  return path.contains('/delta/stream/') || path.contains('/echo/stream/');
}
