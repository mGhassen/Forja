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

/// Row → [MetaItem]. Uses stored `open` only — never invents a hub surface.
MetaItem metaItemFromLegacyListItem(Map<String, dynamic> item) {
  final open = MetaOpen.fromJson(legacyListStoredOpenRaw(item));
  final pluginId = item['pluginId']?.toString();
  final metaId = item['metaId']?.toString() ??
      item['uniqueId']?.toString() ??
      (pluginId != null && open != null
          ? '$pluginId:${open.id}'
          : item['tmdbId']?.toString() ?? '');
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
  final openMedia = open?.extraString('mediaType');
  final String? tmdbMediaType;
  if (openMedia == 'tv' || openMedia == 'movie') {
    tmdbMediaType = openMedia;
  } else if (mediaTypeRaw == 'tv' || mediaTypeRaw == 'series') {
    tmdbMediaType = 'tv';
  } else if (mediaTypeRaw == 'movie') {
    tmdbMediaType = 'movie';
  } else {
    tmdbMediaType = null;
  }
  return MetaItem(
    id: metaId.isEmpty ? 'unknown' : metaId,
    type: item['mediaType']?.toString() ?? open?.surface ?? 'movie',
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

/// Details plugin for a list row — follows pack `open`, never the browse hub tab.
Future<String?> resolveLegacyListDetailsPluginId({
  required Map<String, dynamic> item,
  required MetaItem meta,
}) async {
  final fromRow = item['pluginId']?.toString().trim();
  if (fromRow != null && fromRow.isNotEmpty) {
    return resolveOpenPluginId(pluginId: fromRow, item: meta);
  }
  final open = meta.open;
  if (open != null && open.surface.trim() == 'tmdb') {
    return PluginNavRegistry.pluginIdForEngineType(tmdbCatalogTypeToken(meta));
  }
  final tmdbId = legacyListTmdbId(item);
  if (tmdbId == null || tmdbId <= 0) return null;
  final mt = item['mediaType']?.toString() ?? 'movie';
  final typeToken = (mt == 'tv' || mt == 'series') ? 'tv' : 'movie';
  return PluginNavRegistry.pluginIdForEngineType(typeToken);
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
