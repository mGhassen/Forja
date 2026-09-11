import 'package:flutter/foundation.dart';
import 'package:forja/shared/host/live_sports/match_event.dart';
import 'package:forja/shared/host/live_sports/stremio_live_meta.dart';
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

/// Catalog picker rows for live-targeted Stremio addons (RFC-050).
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

/// Sport schedule rows for one live Stremio addon (Catalog chip selected).
Future<List<Map<String, dynamic>>> loadLiveStremioCatalogFeed({
  required String baseUrl,
}) async {
  final normalized =
      SettingsService.normalizeStremioAddonBaseUrl(baseUrl.trim());
  if (normalized.isEmpty) return const [];

  final stremio = StremioService();
  List<Map<String, dynamic>> addons;
  try {
    addons = await stremio.getAddonsForFeature(StremioAddonFeatures.live);
  } catch (e) {
    debugPrint('[LiveStremio] addons error: $e');
    return const [];
  }

  Map<String, dynamic>? addon;
  for (final a in addons) {
    final url = SettingsService.normalizeStremioAddonBaseUrl(
      a['baseUrl']?.toString() ?? '',
    );
    if (url == normalized) {
      addon = a;
      break;
    }
  }
  if (addon == null) return const [];

  final addonName = liveStremioAddonDisplayName(addon);
  final catalogs = StremioService.sportCatalogsForLive(addon);
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (final cat in catalogs) {
    final type = cat['type']?.toString() ?? 'sport';
    final catalogId = cat['id']?.toString() ?? '';
    if (catalogId.isEmpty) continue;
    try {
      final metas = await stremio.getCatalog(
        baseUrl: normalized,
        type: type,
        id: catalogId,
      );
      for (final meta in metas) {
        final row = liveStremioMetaToFeedRow(
          meta,
          addonBaseUrl: normalized,
          addonName: addonName,
          type: type,
        );
        if (row == null) continue;
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty || !seen.add(id)) continue;
        out.add(row);
      }
    } catch (e) {
      debugPrint('[LiveStremio] catalog $catalogId: $e');
    }
  }
  return out;
}

/// Wire shape for kit schedule + [MatchEvent.fromLegacyRow].
Map<String, dynamic>? liveStremioMetaToFeedRow(
  Map<String, dynamic> meta, {
  required String addonBaseUrl,
  String addonName = '',
  String type = 'sport',
}) {
  final id = meta['id']?.toString().trim() ?? '';
  if (id.isEmpty) return null;
  final title = meta['name']?.toString().trim() ?? '';
  if (title.isEmpty) return null;
  final genres = meta['genres'] is List ? meta['genres'] as List : const [];
  final release = meta['releaseInfo']?.toString().toUpperCase() ?? '';
  final descRaw = meta['description']?.toString() ?? '';
  final desc = descRaw.toUpperCase();
  final dateMs = liveStremioKickoffMs(meta);
  final poster = meta['poster']?.toString() ?? '';
  final metaType = meta['type']?.toString().trim();
  final live = stremioMetaLooksLive(
    releaseInfoUpper: release,
    descriptionUpper: desc,
    poster: poster,
    genres: genres,
  );
  final alwaysOn = stremioMetaIsAlwaysOnChannel(
    looksLive: live,
    dateMs: dateMs,
    descriptionUpper: desc,
    title: title,
    genres: genres,
  );
  final ongoing = stremioTitleEventIsOngoing(title);
  // LIVE badge with no kickoff, kickoff inside live window, or multi-day
  // tournament window still covering today (Flix Solheim / US Open).
  final airing = alwaysOn ||
      (live && dateMs <= 0) ||
      stremioKickoffIsAiringNow(dateMs) ||
      ongoing;
  final categoryRaw =
      alwaysOn ? '24/7' : stremioCategoryFromGenres(genres);
  final category = categoryRaw.isEmpty ? 'other' : categoryRaw.toLowerCase();
  return {
    'id': id,
    'title': title,
    'name': title,
    'type': 'live_match',
    'category': category,
    'genres': [category],
    'badge': category,
    'date': dateMs,
    if (dateMs > 0)
      'startsAt': DateTime.fromMillisecondsSinceEpoch(dateMs).toIso8601String(),
    'poster': poster,
    'airing': airing,
    'alwaysLive': alwaysOn,
    'sources': const <Map<String, dynamic>>[],
    'catalog': 'stremio',
    'stremioBaseUrl': addonBaseUrl,
    'stremioType':
        (metaType == null || metaType.isEmpty) ? type : metaType,
    'stremioAddonName': addonName.trim(),
    'open': {'surface': 'live', 'id': id},
  };
}

int liveStremioKickoffMs(Map<String, dynamic> meta) {
  final released = meta['released'];
  if (released is num) {
    final n = released.toInt();
    return n > 20000000000 ? n : n * 1000;
  }
  if (released is String) {
    final asInt = int.tryParse(released);
    if (asInt != null) return asInt > 20000000000 ? asInt : asInt * 1000;
    final dt = DateTime.tryParse(released);
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  final releaseInfo = meta['releaseInfo']?.toString().trim() ?? '';
  final fromRelease = stremioKickoffMsFromReleaseInfo(releaseInfo);
  if (fromRelease > 0) return fromRelease;
  final title = meta['name']?.toString() ?? '';
  final desc = meta['description']?.toString() ?? '';
  final fromTitleTime = stremioKickoffMsFromTitleAndTime(
    title: title,
    description: desc,
  );
  if (fromTitleTime > 0) return fromTitleTime;
  final timeLine = RegExp(
    r'Time:\s*([^\n]+)',
    caseSensitive: false,
  ).firstMatch(desc);
  if (timeLine != null) {
    final dt = DateTime.tryParse(timeLine.group(1)!.trim());
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  return 0;
}

/// Soft-match pool: all live Stremio sport metas (Providers on Forja cards).
Future<List<MatchEvent>> fetchLiveStremioSportMatches() async {
  final stremio = StremioService();
  final addons = await stremio.getAddonsForFeature(StremioAddonFeatures.live);
  if (addons.isEmpty) return const [];
  final out = <MatchEvent>[];
  final seen = <String>{};
  for (final addon in addons) {
    final baseUrl = addon['baseUrl']?.toString() ?? '';
    if (baseUrl.isEmpty) continue;
    final addonName = liveStremioAddonDisplayName(addon);
    final catalogs = StremioService.sportCatalogsForLive(addon);
    for (final cat in catalogs) {
      final type = cat['type']?.toString() ?? 'sport';
      final catalogId = cat['id']?.toString() ?? '';
      if (catalogId.isEmpty) continue;
      try {
        final metas = await stremio.getCatalog(
          baseUrl: baseUrl,
          type: type,
          id: catalogId,
        );
        for (final meta in metas) {
          final row = liveStremioMetaToFeedRow(
            meta,
            addonBaseUrl: baseUrl,
            addonName: addonName,
            type: type,
          );
          if (row == null) continue;
          final m = MatchEvent.fromLegacyRow(row);
          if (m.id.isEmpty || !seen.add(m.id)) continue;
          out.add(m);
        }
      } catch (e) {
        debugPrint(
          '[LiveStremio] soft-match catalog ($baseUrl/$catalogId): $e',
        );
      }
    }
  }
  return out;
}
