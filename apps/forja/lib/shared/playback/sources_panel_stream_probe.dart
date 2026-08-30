import 'package:forja/shared/player/player/utils.dart';

/// Soft reachability check for Sources panel stream rows (Forja / Nuvio / Stremio).
Future<bool> probeSourcesPanelStream(Map<String, dynamic> stream) async {
  final url = (stream['url'] ?? '').toString().trim();
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  if (lower.startsWith('magnet:') ||
      lower.startsWith('stremio://') ||
      lower.startsWith('debrid:')) {
    return false;
  }

  Map<String, String>? headers;
  final rawHeaders = stream['headers'];
  if (rawHeaders is Map) {
    headers = {
      for (final e in rawHeaders.entries)
        if (e.value != null) e.key.toString(): e.value.toString(),
    };
  }

  String? sourceKey;
  final addonBase = stream['_addonBaseUrl']?.toString().trim();
  if (addonBase != null && addonBase.isNotEmpty) {
    sourceKey = addonBase;
  } else {
    final pluginId = stream['_enginePluginId']?.toString().trim();
    if (pluginId != null && pluginId.isNotEmpty) {
      sourceKey = 'engine:$pluginId';
    }
  }

  return probeStreamSourceUrl(url, headers, sourceKey: sourceKey);
}
