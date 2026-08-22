import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/playback/provider_runtime_config.dart';
import 'package:rust/rust.dart';

/// Live Matches engine plugin orchestration (RFC-065).
class LiveMatchesEngine {
  LiveMatchesEngine._();

  static Future<bool> isEngineResolveMode() async =>
      SettingsService().isLiveStreamResolveEngine();

  /// One native Rust fetch per catalog plugin (`catalog-*`).
  static Future<List<Map<String, dynamic>>> fetchRustCatalog({
    required String catalogId,
    Map<String, dynamic> config = const {},
  }) async {
    try {
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final raw = await runLiveMatchesFetchJson(
        jsonEncode({
          'action': 'forja_live_catalog',
          'catalog_id': catalogId,
          'config': {...config, 'date': date},
        }),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed.containsKey('error')) {
        debugPrint('[LiveMatches] $catalogId catalog error: ${parsed['error']}');
        return [];
      }
      final list = parsed['items'] as List? ?? [];
      return [
        for (final item in list)
          if (item is Map)
            Map<String, dynamic>.from(item),
      ];
    } catch (e) {
      debugPrint('[LiveMatches] $catalogId catalog fetch failed: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCatalog() async {
    await EngineService.instance.ensureBundledInstalled();
    final catalogPlugins =
        await EngineService.instance.listEnabledLiveCatalogPlugins();
    if (catalogPlugins.isEmpty) return [];

    final all = <Map<String, dynamic>>[];
    try {
      for (final catalog in catalogPlugins) {
        final overlay =
            ProviderRuntimeConfig.instance.engine[catalog.id] ?? const {};
        final config = mergeEngineConfig(catalog.config, overlay);
        final batch = await fetchRustCatalog(
          catalogId: catalog.id,
          config: config,
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

    if (pluginId == 'live-ppv') {
      final embed = (params['embedUrl'] ?? params['iframe'] ?? '')
          .toString()
          .trim();
      if (embed.isNotEmpty) {
        final native = await LiveGoatUnlock.resolveStreamed(embedUrl: embed);
        if (native != null) {
          return LiveEngineResolveResult.playable(
            url: native.url,
            headers: native.headers,
            label: 'PPV',
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
