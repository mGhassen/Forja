import 'dart:convert';

/// Dart reference Stremio URL + JSON parse helpers — Rust-off fallback.
abstract final class StremioDartParse {
  static ({String baseUrl, String? queryParams}) splitAddonUrl(String url) {
    final qIdx = url.indexOf('?');
    String path = qIdx >= 0 ? url.substring(0, qIdx) : url;
    final query = qIdx >= 0 ? url.substring(qIdx + 1) : null;
    path = path.replaceAll(RegExp(r'/manifest\.json$'), '').replaceAll(RegExp(r'/$'), '');
    if (!path.startsWith('http')) path = 'https://$path';
    return (baseUrl: path, queryParams: query);
  }

  static String buildResourceUrl(String addonBaseUrl, String resourcePath) {
    final parts = splitAddonUrl(addonBaseUrl);
    final qp = parts.queryParams;
    return qp != null
        ? '${parts.baseUrl}$resourcePath?$qp'
        : '${parts.baseUrl}$resourcePath';
  }

  static String normalizeManifestUrl(String url) {
    var manifestUrl = url.trim();
    if (manifestUrl.startsWith('stremio://')) {
      manifestUrl = manifestUrl.replaceFirst('stremio://', 'https://');
    }
    if (!manifestUrl.endsWith('/manifest.json')) {
      manifestUrl = manifestUrl.endsWith('/')
          ? '${manifestUrl}manifest.json'
          : '$manifestUrl/manifest.json';
    }
    return manifestUrl;
  }

  static Map<String, dynamic>? parseManifestJson(String body) {
    return json.decode(body) as Map<String, dynamic>;
  }

  static List<dynamic> parseStreamsJson(String body) {
    final data = json.decode(body);
    if (data is Map) return data['streams'] ?? [];
    return const [];
  }

  static List<Map<String, dynamic>> parseSubtitlesJson(String body) {
    final data = json.decode(body);
    if (data is! Map) return const [];
    final subs = data['subtitles'] as List? ?? [];
    return subs.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
  }

  static List<Map<String, dynamic>> parseCatalogJson(String body) {
    final data = json.decode(body);
    if (data is! Map) return const [];
    final metas = data['metas'] as List? ?? [];
    return metas.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  static Map<String, dynamic>? parseMetaJson(String body) {
    final data = json.decode(body);
    if (data is! Map) return null;
    final meta = data['meta'];
    if (meta is! Map) return null;
    final map = Map<String, dynamic>.from(meta);
    if (map['type'] == 'collections' && map['videos'] is List) {
      map['_isCollection'] = true;
    }
    return map;
  }
}
