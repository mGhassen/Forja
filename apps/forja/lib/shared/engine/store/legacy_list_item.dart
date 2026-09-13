import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/runtime/catalog_open.dart';
import 'package:forja/shared/engine/runtime/plugin_nav.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/engine/store/list_open_flow.dart';

/// Prefer [metaOpen] / [open]; accept persisted [catalogOpen] from upsertCatalog.
Object? legacyListStoredOpenRaw(Map<String, dynamic> item) =>
    item['metaOpen'] ?? item['open'] ?? item['catalogOpen'];

int? legacyListTmdbId(Map<String, dynamic> item) {
  final raw = item['tmdbId'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

/// Engine type for details plugin resolve — opaque `open` / mediaType only.
@visibleForTesting
String? legacyListEngineType(Map<String, dynamic> item) {
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null) {
    final surface = stored.surface.trim();
    if (surface == 'tmdb') {
      final mt = item['mediaType']?.toString() ?? 'movie';
      return mt == 'tv' || mt == 'series' ? 'tv' : 'movie';
    }
    if (surface.isNotEmpty) return surface;
    final t = stored.effectiveExtract.resolveType.trim();
    if (t.isNotEmpty && t != 'tmdb') return t;
  }
  final mt = item['mediaType']?.toString() ?? '';
  if (mt == 'movie' || mt == 'tv' || mt == 'series') {
    return mt == 'tv' || mt == 'series' ? 'tv' : 'movie';
  }
  return mt.isNotEmpty ? mt : null;
}

String _legacyListSurface(Map<String, dynamic> item) {
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null && stored.surface.trim().isNotEmpty) {
    return stored.surface;
  }
  return 'tmdb';
}

String _legacyListOpenId(Map<String, dynamic> item) {
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null && stored.id.trim().isNotEmpty) {
    return stored.id;
  }
  final tmdb = item['tmdbId'];
  if (tmdb != null) return tmdb.toString();
  return item['metaId']?.toString() ?? item['uniqueId']?.toString() ?? '';
}

String _legacyListResolveType(Map<String, dynamic> item, String surface) {
  if (surface == 'tmdb') {
    final mt = item['mediaType']?.toString() ?? 'movie';
    return mt == 'tv' || mt == 'series' ? 'tv' : 'movie';
  }
  return surface;
}

Map<String, dynamic> _legacyListExtractCtx(Map<String, dynamic> item) {
  final ctx = <String, dynamic>{};
  void put(String key, dynamic value) {
    if (value == null) return;
    if (value is int) {
      ctx[key] = value;
      return;
    }
    if (value is num) {
      ctx[key] = value.toInt();
      return;
    }
    final parsed = int.tryParse(value.toString());
    ctx[key] = parsed ?? value;
  }

  put('tmdbId', item['tmdbId']);
  put('malId', item['malId']);

  final ids = item['ids'];
  if (ids is Map) {
    for (final e in ids.entries) {
      final k = e.key.toString();
      if (k.isEmpty) continue;
      final ck = k.endsWith('Id') ? k : '${k}Id';
      ctx.putIfAbsent(ck, () {
        final v = e.value;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse('$v') ?? v;
      });
    }
  }

  final openId = _legacyListOpenId(item);
  if (ctx.isEmpty && openId.isNotEmpty) ctx['openId'] = openId;
  return ctx;
}

/// Build [MetaOpen] from a stored row — opaque `open` passthrough only.
MetaOpen metaOpenFromLegacyListItem(Map<String, dynamic> item) {
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null && stored.extract != null) return stored;

  final surface = stored != null && stored.surface.trim().isNotEmpty
      ? stored.surface
      : _legacyListSurface(item);
  final id = stored != null && stored.id.trim().isNotEmpty
      ? stored.id
      : _legacyListOpenId(item);
  final resolveType = _legacyListResolveType(item, surface);
  final baseExtras = Map<String, dynamic>.from(stored?.extras ?? const {});
  if (surface == 'tmdb') {
    baseExtras['mediaType'] = resolveType == 'tv' ? 'tv' : 'movie';
  }
  return MetaOpen(
    surface: surface,
    id: id.isEmpty ? 'unknown' : id,
    extract: MetaOpenExtract(
      resolveType: resolveType,
      panelCategory: resolveType,
      ctx: _legacyListExtractCtx(item),
    ),
    extras: baseExtras,
  );
}

/// Row → [MetaItem]. Restores missing `open` from opaque stored fields only.
MetaItem metaItemFromLegacyListItem(Map<String, dynamic> item) {
  final open = metaOpenFromLegacyListItem(item);
  final pluginId = item['pluginId']?.toString();
  final metaId = item['metaId']?.toString() ??
      item['uniqueId']?.toString() ??
      (pluginId != null ? '$pluginId:${open.id}' : open.id);
  final ids = <String, dynamic>{};
  if (item['tmdbId'] != null) ids['tmdb'] = item['tmdbId'].toString();
  if (item['imdbId'] != null) ids['imdb'] = item['imdbId'].toString();
  final rawIds = item['ids'];
  if (rawIds is Map) {
    for (final e in rawIds.entries) {
      ids[e.key.toString()] = e.value;
    }
  }
  final mediaTypeRaw = item['mediaType']?.toString() ?? '';
  final openMedia = open.extraString('mediaType');
  final String? tmdbMediaType;
  if (openMedia == 'tv' || openMedia == 'movie') {
    tmdbMediaType = openMedia;
  } else if (open.surface == 'tmdb') {
    tmdbMediaType = open.effectiveExtract.resolveType == 'tv' ? 'tv' : 'movie';
  } else if (mediaTypeRaw == 'tv' || mediaTypeRaw == 'series') {
    tmdbMediaType = 'tv';
  } else if (mediaTypeRaw == 'movie') {
    tmdbMediaType = 'movie';
  } else {
    tmdbMediaType = null;
  }
  return MetaItem(
    id: metaId.isEmpty ? 'unknown' : metaId,
    type: item['mediaType']?.toString() ?? open.surface,
    name: item['title']?.toString() ?? 'Unknown',
    poster: item['posterPath']?.toString() ?? '',
    background: item['backdropPath']?.toString() ??
        item['posterPath']?.toString() ??
        '',
    description: item['overview']?.toString() ?? '',
    releaseInfo: item['releaseDate']?.toString() ?? '',
    rating: (item['voteAverage'] as num?)?.toDouble() ?? 0,
    ids: ids,
    open: open,
    tmdbMediaType: tmdbMediaType,
  );
}

ListFollowTarget? listFollowTargetFromLegacyItemSync(
  Map<String, dynamic> item,
) {
  final pluginId = item['pluginId']?.toString().trim();
  if (pluginId == null || pluginId.isEmpty) return null;
  if (legacyListStoredOpenRaw(item) == null) return null;
  final meta = metaItemFromLegacyListItem(item);
  if (meta.open == null) return null;
  return ListFollowTarget.fromMeta(pluginId: pluginId, meta: meta);
}

Future<bool> _pluginHasDetails(String pluginId) async {
  final want = pluginId.trim();
  if (want.isEmpty) return false;
  for (final pl in await PluginNavRegistry.listKitPlugins()) {
    if (pl.id == want) return pl.hasCapability('details');
  }
  return false;
}

/// Details plugin for a list row — opaque `open` / row pluginId only.
Future<String?> resolveLegacyListDetailsPluginId({
  required Map<String, dynamic> item,
  required MetaItem meta,
}) async {
  final fromRow = item['pluginId']?.toString().trim();
  if (fromRow != null &&
      fromRow.isNotEmpty &&
      await _pluginHasDetails(fromRow)) {
    return fromRow;
  }

  final open = meta.open;
  final surface = open?.surface.trim() ?? '';
  if (surface == 'tmdb') {
    return PluginNavRegistry.pluginIdForEngineType(tmdbCatalogTypeToken(meta));
  }
  if (surface.isNotEmpty) {
    final bySurface = await PluginNavRegistry.pluginIdForEngineType(surface);
    if (bySurface != null && bySurface.isNotEmpty) return bySurface;
  }

  final engineType = legacyListEngineType(item);
  if (engineType == null || engineType.isEmpty) return null;
  return PluginNavRegistry.pluginIdForEngineType(engineType);
}

Future<void> openLegacyListItem(
  BuildContext context, {
  required Map<String, dynamic> item,
  String? shellTabId,
  bool forcePick = false,
}) async {
  await openListItemWithBinding(
    context,
    item: item,
    shellTabId: shellTabId,
    forcePick: forcePick,
  );
}
