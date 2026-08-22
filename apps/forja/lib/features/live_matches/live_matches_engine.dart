import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:rust/rust.dart';

/// Live Matches engine plugin orchestration (RFC-065).
class LiveMatchesEngine {
  LiveMatchesEngine._();

  static Future<bool> isEngineResolveMode() async =>
      SettingsService().isLiveStreamResolveEngine();

  static const _catalogTimeout = Duration(seconds: 30);
  static const catalogPluginTimeout = Duration(seconds: 20);

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
          timeout: _catalogTimeout,
        );
        all.addAll(batch);
      }
      return all.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      debugPrint('[LiveMatchesEngine] catalog: $e');
      return all;
    }
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
          ? 'Engine resolve failed — try Sniff mode in Settings → Forja Sports'
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
  });

  factory LiveEngineResolveResult.playable({
    required String url,
    Map<String, String> headers = const {},
    String label = '',
  }) => LiveEngineResolveResult._(
    playable: true,
    url: url,
    headers: headers,
    label: label,
  );

  factory LiveEngineResolveResult.webviewOnly({required String embedUrl}) =>
      LiveEngineResolveResult._(playable: false, embedUrl: embedUrl);

  final bool playable;
  final String url;
  final Map<String, String> headers;
  final String label;
  final String embedUrl;
}
