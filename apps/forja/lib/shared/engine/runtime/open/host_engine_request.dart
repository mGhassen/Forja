import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/portals/store/portal_catalog_page.dart';
import 'package:forja/shared/engine/runtime/open/legacy_movie_meta.dart';
import 'package:rust/rust.dart';

/// Opaque pack → Rust/engine jobs. No product `host.iptv` namespace (RFC-109).
///
/// Packs call `ctx.host.engine.request(kind, body)`.
abstract final class HostEngineRequest {
  HostEngineRequest._();

  static Future<Map<String, dynamic>> run({
    required String kind,
    Map<String, dynamic> body = const {},
  }) async {
    final k = kind.trim().toLowerCase();
    try {
      switch (k) {
        case 'iptv':
          return await _iptv(body);
        case 'portal_share':
          return await _portalShare(body);
        case 'parse_m3u':
          return await _parseM3u(body);
        case 'stremio':
          return await _stremio(body);
        default:
          return {
            'ok': false,
            'error': 'unknown_kind',
            'message': 'Unknown engine kind: $kind',
          };
      }
    } catch (e, st) {
      debugPrint('[HostEngineRequest] $k failed: $e\n$st');
      return {'ok': false, 'error': 'exception', 'message': e.toString()};
    }
  }

  /// VOD Stremio catalog hub bridge (issue 363). Feature defaults to [vod].
  static Future<Map<String, dynamic>> _stremio(
    Map<String, dynamic> body,
  ) async {
    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    final stremio = StremioService();
    switch (action) {
      case 'list':
        final feature = (body['feature'] ?? StremioAddonFeatures.vod)
            .toString()
            .trim();
        final catalogs = await stremio.getAllCatalogs(
          feature: feature.isEmpty ? StremioAddonFeatures.vod : feature,
        );
        return {'ok': true, 'catalogs': catalogs};
      case 'catalog':
        final baseUrl = (body['baseUrl'] ?? body['addonBaseUrl'] ?? '')
            .toString()
            .trim();
        final type =
            (body['type'] ?? body['catalogType'] ?? '').toString().trim();
        final id = (body['id'] ?? body['catalogId'] ?? '').toString().trim();
        if (baseUrl.isEmpty || type.isEmpty || id.isEmpty) {
          return {
            'ok': false,
            'error': 'missing_params',
            'message': 'catalog needs baseUrl, type, and id',
          };
        }
        final genre = (body['genre'] ?? '').toString().trim();
        final skip = (body['skip'] as num?)?.toInt();
        final addonName = (body['addonName'] ?? '').toString().trim();
        final metas = await stremio.getCatalog(
          baseUrl: baseUrl,
          type: type,
          id: id,
          genre: genre.isEmpty ? null : genre,
          skip: skip,
        );
        final items = <Map<String, dynamic>>[];
        for (final m in metas) {
          final stamped = Map<String, dynamic>.from(m);
          stamped['_addonBaseUrl'] = baseUrl;
          if (addonName.isNotEmpty) stamped['_addonName'] = addonName;
          items.add(metaItemFromStremioSearchResult(stamped).toJson());
        }
        return {'ok': true, 'items': items};
      case 'search':
        final query = (body['query'] ?? body['q'] ?? '').toString();
        if (query.trim().isEmpty) {
          return {'ok': true, 'items': <Map<String, dynamic>>[]};
        }
        final metas = await stremio.searchAllAddons(query);
        final items = metas
            .map((m) => metaItemFromStremioSearchResult(m).toJson())
            .toList();
        return {'ok': true, 'items': items};
      default:
        return {
          'ok': false,
          'error': 'unknown_action',
          'message': 'Unknown stremio action: $action',
        };
    }
  }

  static Future<Map<String, dynamic>> _iptv(Map<String, dynamic> body) async {
    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    switch (action) {
      case 'catalog_page':
        // Host-owned shelf + page (issue 290). Full streams never enter JS.
        return PortalCatalogPage.run(body);
      case 'xtream':
      case 'request':
        // Body is the Rust iptvXtream JSON request (action/login/catalog/…).
        final payload = body['request'] ?? body;
        final raw = await runIptvXtreamJson(
          payload is String ? payload : jsonEncode(payload),
        );
        return _parseOk(raw);
      case 'probe':
        final url = (body['url'] ?? '').toString().trim();
        if (url.isEmpty) {
          return {'ok': false, 'error': 'missing_url'};
        }
        final timeout = (body['timeoutSecs'] as num?)?.toInt() ??
            (body['timeout_secs'] as num?)?.toInt() ??
            8;
        final raw = await runIptvProbeStreamJson(url, timeoutSecs: timeout);
        return _parseOk(raw);
      case 'scrape':
      case 'reddit_catalog':
        final payload = body['request'] ?? body;
        final raw = await runIptvRedditCatalogJson(
          payload is String ? payload : jsonEncode(payload),
        );
        return _parseOk(raw);
      case 'create_link':
        // Stalker create_link goes through the same xtream/portal Rust job.
        final payload = Map<String, dynamic>.from(body);
        payload['action'] = 'create_link';
        final raw = await runIptvXtreamJson(jsonEncode(payload));
        return _parseOk(raw);
      default:
        // Treat whole body as xtream job request (login, get_live_categories, …).
        final raw = await runIptvXtreamJson(jsonEncode(body));
        return _parseOk(raw);
    }
  }

  static Future<Map<String, dynamic>> _portalShare(
    Map<String, dynamic> body,
  ) async {
    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    if (action == 'decode' || action == 'unseal') {
      final token = (body['token'] ?? body['code'] ?? '').toString();
      if (token.isEmpty) return {'ok': false, 'error': 'missing_token'};
      final raw = RustLib.instance.iptvPortalShareDecode(token);
      return _parseOk(raw);
    }
    final url = (body['url'] ?? '').toString();
    final username = (body['username'] ?? '').toString();
    final password = (body['password'] ?? '').toString();
    final platform = (body['platform'] ?? 'xtream').toString();
    final userAgent = (body['userAgent'] ?? body['user_agent'] ?? '').toString();
    final token = RustLib.instance.iptvPortalShareEncode(
      url,
      username,
      password,
      platform: platform,
      userAgent: userAgent,
    );
    if (token.trim().isEmpty) {
      return {'ok': false, 'error': 'encode_failed'};
    }
    return {'ok': true, 'token': token};
  }

  static Future<Map<String, dynamic>> _parseM3u(
    Map<String, dynamic> body,
  ) async {
    final content = (body['content'] ?? body['text'] ?? '').toString();
    if (content.isEmpty) return {'ok': false, 'error': 'missing_content'};
    final raw = await runParseM3uJson(content);
    return _parseOk(raw);
  }

  static Map<String, dynamic> _parseOk(String raw) {
    if (raw.trim().isEmpty) {
      return {'ok': false, 'error': 'empty'};
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        final m = Map<String, dynamic>.from(parsed);
        if (!m.containsKey('ok')) {
          m['ok'] = !m.containsKey('error');
        }
        return m;
      }
      if (parsed is List) {
        return {'ok': true, 'items': parsed};
      }
      return {'ok': true, 'value': parsed};
    } catch (_) {
      return {'ok': true, 'raw': raw};
    }
  }
}
