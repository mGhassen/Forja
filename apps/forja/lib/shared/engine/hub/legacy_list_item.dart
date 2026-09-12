import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:forja/shared/engine/hub/legacy_movie_meta.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:rust/rust.dart';

/// Prefer [metaOpen] / [open]; accept persisted [catalogOpen] from upsertCatalog.
Object? legacyListStoredOpenRaw(Map<String, dynamic> item) =>
    item['metaOpen'] ?? item['open'] ?? item['catalogOpen'];

int? legacyListTmdbId(Map<String, dynamic> item) {
  final raw = item['tmdbId'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}

/// Engine type for details plugin resolve — hub mediaType wins over a stale
/// `open.surface: tmdb` (bad KissKH/Simkl TMDB ids must not force Home details).
@visibleForTesting
String? legacyListEngineType(Map<String, dynamic> item) {
  final hub = legacyListHubEngineType(item);
  if (hub != null) return hub;

  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null) {
    final surface = stored.surface.trim();
    if (surface == 'tmdb') {
      final mt = item['mediaType']?.toString() ?? 'movie';
      return mt == 'tv' || mt == 'series' ? 'tv' : 'movie';
    }
    final t = stored.effectiveExtract.resolveType.trim();
    if (t.isNotEmpty && t != 'tmdb') return t;
  }
  final mt = item['mediaType']?.toString() ?? '';
  if (mt == 'movie' || mt == 'tv' || mt == 'series') {
    return mt == 'tv' || mt == 'series' ? 'tv' : 'movie';
  }
  return mt.isNotEmpty ? mt : null;
}

/// `anime` / `drama` when the row is a hub bookmark — not Home/TMDB.
@visibleForTesting
String? legacyListHubEngineType(Map<String, dynamic> item) {
  final mt = item['mediaType']?.toString() ?? '';
  final kind = item['kind']?.toString() ?? '';
  if (mt == 'anime' || kind == 'anime') return 'anime';
  if (mt == 'asian_drama' ||
      mt == 'drama' ||
      kind == 'asian_drama' ||
      kind == 'drama') {
    return 'drama';
  }

  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null) {
    final surface = stored.surface.trim();
    if (surface == 'anime') return 'anime';
    if (surface == 'drama') return 'drama';
    final ctx = stored.extract?.ctx;
    if (ctx != null) {
      if (ctx['anilistId'] != null || ctx['anilist'] != null) return 'anime';
      if (ctx['kisskhId'] != null || ctx['kisskh'] != null) return 'drama';
    }
  }

  if (item['anilistId'] != null) return 'anime';
  if (item['kisskhId'] != null) return 'drama';
  final ids = item['ids'];
  if (ids is Map) {
    if (ids['anilist'] != null) return 'anime';
    if (ids['kisskh'] != null) return 'drama';
  }
  return null;
}

String _legacyListSurface(Map<String, dynamic> item) {
  final hub = legacyListHubEngineType(item);
  if (hub == 'anime') return 'anime';
  if (hub == 'drama') return 'drama';
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (stored != null && stored.surface.trim().isNotEmpty) {
    return stored.surface;
  }
  return 'tmdb';
}

String? _legacyListOpenIdFromUniqueId(String? uniqueId) {
  final uid = uniqueId?.trim() ?? '';
  // catalog_<pluginId>_<openId> — pluginId may contain hyphens (kisskh-hub).
  final match = RegExp(r'^catalog_(.+)_([^_]+)$').firstMatch(uid);
  final id = match?.group(2)?.trim();
  if (id == null || id.isEmpty) return null;
  return id;
}

String _legacyListOpenId(Map<String, dynamic> item) {
  final hub = legacyListHubEngineType(item);
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (hub != null && stored != null && stored.surface.trim() == hub) {
    if (stored.id.trim().isNotEmpty) return stored.id;
  }
  if (hub == 'anime') {
    final anilist =
        item['anilistId'] ?? (item['ids'] is Map ? item['ids']['anilist'] : null);
    if (anilist != null) return anilist.toString();
    final ctxId = stored?.extract?.ctx['anilistId'];
    if (ctxId != null) return ctxId.toString();
    final fromUid = _legacyListOpenIdFromUniqueId(item['uniqueId']?.toString());
    if (fromUid != null) return fromUid;
  }
  if (hub == 'drama') {
    final kisskh =
        item['kisskhId'] ?? (item['ids'] is Map ? item['ids']['kisskh'] : null);
    if (kisskh != null) return kisskh.toString();
    final ctxId = stored?.extract?.ctx['kisskhId'];
    if (ctxId != null) return ctxId.toString();
    if (stored != null &&
        stored.surface.trim() == 'drama' &&
        stored.id.trim().isNotEmpty) {
      return stored.id;
    }
    final fromUid = _legacyListOpenIdFromUniqueId(item['uniqueId']?.toString());
    if (fromUid != null) return fromUid;
  }
  // catalog_<pluginId>_<openId> — recover hub id when open was overwritten to tmdb
  final pluginId = item['pluginId']?.toString().trim() ?? '';
  final uid = item['uniqueId']?.toString() ?? '';
  if (hub != null && pluginId.isNotEmpty) {
    final prefix = 'catalog_${pluginId}_';
    if (uid.startsWith(prefix)) {
      final recovered = uid.substring(prefix.length);
      if (recovered.isNotEmpty) return recovered;
    }
  }
  if (stored != null &&
      stored.id.trim().isNotEmpty &&
      stored.surface.trim() != 'tmdb') {
    return stored.id;
  }
  final anilist =
      item['anilistId'] ?? (item['ids'] is Map ? item['ids']['anilist'] : null);
  if (anilist != null) return anilist.toString();
  final kisskh =
      item['kisskhId'] ?? (item['ids'] is Map ? item['ids']['kisskh'] : null);
  if (kisskh != null) return kisskh.toString();
  if (hub == null) {
    final tmdb = item['tmdbId'];
    if (tmdb != null) return tmdb.toString();
    if (stored != null && stored.id.trim().isNotEmpty) return stored.id;
  }
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
  put('anilistId', item['anilistId']);
  put('kisskhId', item['kisskhId']);

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
  final hub = legacyListHubEngineType(item);
  if (hub == 'drama' && ctx['kisskhId'] == null && openId.isNotEmpty) {
    put('kisskhId', openId);
  }
  if (hub == 'anime' && ctx['anilistId'] == null && openId.isNotEmpty) {
    put('anilistId', openId);
  }
  return ctx;
}

/// Build [MetaOpen] from a stored row, including extract when missing.
/// Hub anime/drama always wins over a conflicting `tmdb` open (wrong TMDB ids).
@visibleForTesting
MetaOpen metaOpenFromLegacyListItem(Map<String, dynamic> item) {
  final hub = legacyListHubEngineType(item);
  final stored = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  if (hub == null && stored != null && stored.extract != null) return stored;

  final surface = hub ??
      (stored?.surface.trim().isNotEmpty == true
          ? stored!.surface
          : _legacyListSurface(item));
  final id = _legacyListOpenId(item);
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

/// Row → [MetaItem]. Restores missing `open` from mediaType / ids (legacy bookmarks).
MetaItem metaItemFromLegacyListItem(Map<String, dynamic> item) {
  final open = metaOpenFromLegacyListItem(item);
  final pluginId = item['pluginId']?.toString();
  final metaId = item['metaId']?.toString() ??
      item['uniqueId']?.toString() ??
      (pluginId != null ? '$pluginId:${open.id}' : open.id);
  final ids = <String, dynamic>{};
  if (item['tmdbId'] != null) ids['tmdb'] = item['tmdbId'].toString();
  if (item['imdbId'] != null) ids['imdb'] = item['imdbId'].toString();
  if (item['anilistId'] != null) ids['anilist'] = item['anilistId'].toString();
  if (item['kisskhId'] != null) ids['kisskh'] = item['kisskhId'].toString();
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

/// Details plugin for a list row — anime / drama / TMDB by hub type + `open`.
/// Never uses the browse list hub (feed-only) as the details plugin.
Future<String?> resolveLegacyListDetailsPluginId({
  required Map<String, dynamic> item,
  required MetaItem meta,
}) async {
  final hub = legacyListHubEngineType(item);
  if (hub == 'anime' || hub == 'drama') {
    final fromRow = item['pluginId']?.toString().trim();
    if (fromRow != null &&
        fromRow.isNotEmpty &&
        await _pluginHasDetails(fromRow)) {
      return fromRow;
    }
    return PluginNavRegistry.pluginIdForEngineType(hub!);
  }

  final open = meta.open;
  final surface = open?.surface.trim() ?? '';
  if (surface == 'tmdb') {
    return PluginNavRegistry.pluginIdForEngineType(tmdbCatalogTypeToken(meta));
  }

  final fromRow = item['pluginId']?.toString().trim();
  if (fromRow != null &&
      fromRow.isNotEmpty &&
      await _pluginHasDetails(fromRow)) {
    return fromRow;
  }

  final engineType = legacyListEngineType(item);
  if (engineType == null || engineType.isEmpty) return null;
  return PluginNavRegistry.pluginIdForEngineType(engineType);
}

Future<void> openLegacyListItem(
  BuildContext context, {
  required Map<String, dynamic> item,
  String? shellTabId,
}) async {
  final meta = metaItemFromLegacyListItem(item);
  final open = meta.open;
  final detailsPluginId = await resolveLegacyListDetailsPluginId(
    item: item,
    meta: meta,
  );
  if (!context.mounted) return;

  if (open != null &&
      metaOpenUsesKitDetails(open) &&
      detailsPluginId != null &&
      detailsPluginId.isNotEmpty) {
    await openMetaItem(
      context,
      pluginId: detailsPluginId,
      item: meta,
      shellTabId: shellTabId,
    );
    return;
  }

  final tmdbId = legacyListTmdbId(item);
  if (tmdbId == null ||
      tmdbId <= 0 ||
      detailsPluginId == null ||
      detailsPluginId.isEmpty ||
      !context.mounted) {
    return;
  }
  final mediaType = item['mediaType']?.toString() ?? 'movie';
  final movie = Movie(
    id: tmdbId,
    imdbId: item['imdbId']?.toString(),
    title: item['title']?.toString() ?? 'Unknown',
    posterPath: item['posterPath']?.toString() ?? '',
    backdropPath: item['backdropPath']?.toString() ??
        item['posterPath']?.toString() ??
        '',
    voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
    releaseDate: item['releaseDate']?.toString() ?? '',
    mediaType: mediaType == 'series' ? 'tv' : mediaType,
  );
  await openMetaItem(
    context,
    pluginId: detailsPluginId,
    item: metaItemFromMovie(movie),
    shellTabId: shellTabId,
  );
}
