import 'package:flutter/foundation.dart';
import 'package:rust/rust.dart'
    show SettingsService, StremioAddonFeatures, StremioService;

/// Catalog chip id for an installed live Stremio addon (`stremio:<baseUrl>`).
const kLiveStremioCatalogFilterPrefix = 'stremio:';

bool isLiveStremioCatalogFilter(String filter) =>
    filter.startsWith(kLiveStremioCatalogFilterPrefix);

String liveStremioCatalogFilterId(String baseUrl) {
  final normalized =
      SettingsService.normalizeStremioAddonBaseUrl(baseUrl.trim());
  return '$kLiveStremioCatalogFilterPrefix$normalized';
}

String? liveStremioBaseUrlFromCatalogFilter(String filter) {
  if (!isLiveStremioCatalogFilter(filter)) return null;
  final raw = filter.substring(kLiveStremioCatalogFilterPrefix.length).trim();
  if (raw.isEmpty) return null;
  final normalized = SettingsService.normalizeStremioAddonBaseUrl(raw);
  return normalized.isEmpty ? null : normalized;
}

String liveStremioAddonDisplayName(Map<String, dynamic> addon) {
  final name = (addon['name']?.toString() ?? '').trim();
  if (name.isNotEmpty) return name;
  final manifest = addon['manifest'];
  if (manifest is Map) {
    final mname = (manifest['name']?.toString() ?? '').trim();
    if (mname.isNotEmpty) return mname;
  }
  return 'Stremio';
}

/// Short chip label when options miss — never paint `stremio:<full url>`.
String liveStremioCatalogChipFallbackLabel(String filterId) {
  final base = liveStremioBaseUrlFromCatalogFilter(filterId);
  if (base != null) {
    final host = Uri.tryParse(base)?.host.trim() ?? '';
    if (host.isNotEmpty) return host;
  }
  return 'Stremio';
}

/// Catalog picker rows for live-targeted Stremio addons.
Future<List<({String id, String label})>> liveStremioCatalogOptions() async {
  try {
    final addons =
        await StremioService().peekAddonsForFeature(StremioAddonFeatures.live);
    final out = <({String id, String label})>[];
    final seen = <String>{};
    for (final addon in addons) {
      final baseUrl = addon['baseUrl']?.toString() ?? '';
      if (baseUrl.trim().isEmpty) continue;
      final id = liveStremioCatalogFilterId(baseUrl);
      if (!seen.add(id)) continue;
      out.add((id: id, label: liveStremioAddonDisplayName(addon)));
    }
    return out;
  } catch (e) {
    debugPrint('[LiveStremio] catalog options error: $e');
    return const [];
  }
}
