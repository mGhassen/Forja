import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Legacy My List / Simkl row → hub open (caller boundary — not pack ids).
class CatalogLegacyListTarget {
  const CatalogLegacyListTarget({
    required this.pluginId,
    required this.meta,
  });

  final String pluginId;
  final CatalogMetaItem meta;
}

/// Build [CatalogOpen] from a stored row, including extract when missing.
CatalogOpen catalogOpenFromLegacyListItem(Map<String, dynamic> item) {
  final stored = CatalogOpen.fromJson(item['catalogOpen']);
  if (stored != null && stored.extract != null) return stored;

  final surface = stored?.surface ?? _legacyListSurface(item);
  final id = stored?.id ?? _legacyListOpenId(item);
  final ctx = _legacyListExtractCtx(item);
  final resolveType = _legacyListResolveType(item, surface);
  return CatalogOpen(
    surface: surface,
    id: id,
    extract: CatalogOpenExtract(
      resolveType: resolveType,
      panelCategory: resolveType,
      ctx: ctx,
    ),
    extras: stored?.extras ?? const {},
  );
}

CatalogMetaItem catalogMetaFromLegacyListItem(Map<String, dynamic> item) {
  final open = catalogOpenFromLegacyListItem(item);
  final pluginId = item['pluginId']?.toString();
  final metaId = item['metaId']?.toString() ??
      item['uniqueId']?.toString() ??
      (pluginId != null ? '$pluginId:${open.id}' : open.id);
  return CatalogMetaItem(
    id: metaId,
    type: item['mediaType']?.toString() ?? open.surface,
    name: item['title']?.toString() ?? 'Unknown',
    poster: item['posterPath']?.toString() ?? '',
    background: item['backdropPath']?.toString() ??
        item['posterPath']?.toString() ??
        '',
    description: item['overview']?.toString() ?? '',
    releaseInfo: item['releaseDate']?.toString() ?? '',
    rating: (item['voteAverage'] as num?)?.toDouble() ?? 0,
    ids: _legacyListIds(item),
    open: open,
  );
}

CatalogListFollowTarget? listFollowTargetFromLegacyItemSync(
  Map<String, dynamic> item,
) {
  final pluginId = item['pluginId']?.toString();
  if (pluginId == null || pluginId.isEmpty) return null;
  if (item['catalogOpen'] == null &&
      item['anilistId'] == null &&
      item['kisskhId'] == null) {
    return null;
  }
  final meta = catalogMetaFromLegacyListItem(item);
  return CatalogListFollowTarget.fromMeta(pluginId: pluginId, meta: meta);
}

Future<CatalogListFollowTarget?> listFollowTargetFromLegacyItem(
  Map<String, dynamic> item,
) async {
  final stored = listFollowTargetFromLegacyItemSync(item);
  if (stored != null) return stored;
  final resolved = await resolveLegacyListTarget(item);
  if (resolved == null) return null;
  return CatalogListFollowTarget.fromMeta(
    pluginId: resolved.pluginId,
    meta: resolved.meta,
  );
}

Future<CatalogLegacyListTarget?> resolveLegacyListTarget(
  Map<String, dynamic> item,
) async {
  final pluginId = await PluginNavRegistry.resolveHubPluginId(
    pluginId: item['pluginId']?.toString(),
    tabId: item['hubTabId']?.toString(),
    engineType: _legacyListEngineType(item),
  );
  if (pluginId == null || pluginId.isEmpty) return null;
  return CatalogLegacyListTarget(
    pluginId: pluginId,
    meta: catalogMetaFromLegacyListItem(item),
  );
}

Future<void> openLegacyListItem(
  BuildContext context, {
  required Map<String, dynamic> item,
}) async {
  final tmdbId = item['tmdbId'] as int?;
  final source = item['source']?.toString() ?? 'tmdb';
  if (source == 'tmdb' &&
      tmdbId != null &&
      item['catalogOpen'] == null &&
      item['anilistId'] == null &&
      item['kisskhId'] == null) {
    // Home TMDB rows without hub meta — legacy movie adapter.
    if (!context.mounted) return;
    final details = await _loadTmdbMovie(item, tmdbId);
    if (details != null && context.mounted) {
      await AppRouter.openMovie(context, movie: details);
    }
    return;
  }

  final target = await resolveLegacyListTarget(item);
  if (target != null && context.mounted) {
    await openCatalogMetaItem(
      context,
      pluginId: target.pluginId,
      item: target.meta,
    );
    return;
  }

  final imdbId = item['imdbId']?.toString();
  final mediaType = item['mediaType']?.toString() ?? 'movie';
  if (imdbId != null && imdbId.startsWith('tt')) {
    try {
      final movie = await TmdbApi().findByImdbId(
        imdbId,
        mediaType: mediaType == 'series' ? 'tv' : mediaType,
      );
      if (movie != null && context.mounted) {
        await AppRouter.openMovie(context, movie: movie);
        return;
      }
    } catch (_) {}
  }

  final title = item['title']?.toString() ?? 'Unknown';
  final poster = item['posterPath']?.toString() ?? '';
  if (!context.mounted) return;
  await AppRouter.openMovie(
    context,
    movie: Movie(
      id: tmdbId ?? title.hashCode,
      imdbId: imdbId,
      title: title,
      posterPath: poster,
      backdropPath: poster,
      voteAverage: (item['voteAverage'] as num?)?.toDouble() ?? 0,
      releaseDate: item['releaseDate']?.toString() ?? '',
      mediaType: mediaType == 'series' ? 'tv' : mediaType,
    ),
  );
}

Future<Movie?> _loadTmdbMovie(Map<String, dynamic> item, int tmdbId) async {
  final api = TmdbApi();
  final mt = item['mediaType']?.toString() ?? 'movie';
  try {
    return mt == 'tv' || mt == 'series'
        ? await api.getTvDetails(tmdbId)
        : await api.getMovieDetails(tmdbId);
  } catch (_) {
    return null;
  }
}

String? _legacyListEngineType(Map<String, dynamic> item) {
  if (item['anilistId'] != null) return 'anime';
  if (item['kisskhId'] != null) return 'drama';
  final mt = item['mediaType']?.toString() ?? '';
  if (mt == 'anime') return 'anime';
  if (mt == 'asian_drama') return 'drama';
  if (mt == 'movie' || mt == 'tv' || mt == 'series') return 'movie';
  return mt.isNotEmpty ? mt : null;
}

String _legacyListSurface(Map<String, dynamic> item) {
  final stored = CatalogOpen.fromJson(item['catalogOpen']);
  if (stored != null) return stored.surface;
  final mt = item['mediaType']?.toString() ?? '';
  if (item['anilistId'] != null || mt == 'anime') return 'anime';
  if (item['kisskhId'] != null || mt == 'asian_drama') return 'drama';
  return 'tmdb';
}

String _legacyListOpenId(Map<String, dynamic> item) {
  final stored = CatalogOpen.fromJson(item['catalogOpen']);
  if (stored != null) return stored.id;
  final kisskh = item['kisskhId'];
  if (kisskh != null) return kisskh.toString();
  final anilist = item['anilistId'];
  if (anilist != null) return anilist.toString();
  final tmdb = item['tmdbId'];
  if (tmdb != null) return tmdb.toString();
  return item['metaId']?.toString() ?? '';
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
  put('anilistId', item['anilistId']);
  put('kisskhId', item['kisskhId']);
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

Map<String, dynamic> _legacyListIds(Map<String, dynamic> item) {
  final ids = <String, dynamic>{};
  void put(String key, dynamic value) {
    if (value == null) return;
    ids[key] = value.toString();
  }

  put('tmdb', item['tmdbId']);
  put('anilist', item['anilistId']);
  put('kisskh', item['kisskhId']);
  put('imdb', item['imdbId']);

  final raw = item['ids'];
  if (raw is Map) {
    for (final e in raw.entries) {
      ids[e.key.toString()] = e.value;
    }
  }
  return ids;
}
