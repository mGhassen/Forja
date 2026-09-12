import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:rust/rust.dart';

/// Prefer [metaOpen] / [open]; accept persisted [catalogOpen] from upsertCatalog.
Object? legacyListStoredOpenRaw(Map<String, dynamic> item) =>
    item['metaOpen'] ?? item['open'] ?? item['catalogOpen'];

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

Future<void> openLegacyListItem(
  BuildContext context, {
  required Map<String, dynamic> item,
  String? shellTabId,
}) async {
  final pluginId = item['pluginId']?.toString().trim();
  final meta = metaItemFromLegacyListItem(item);
  final open = meta.open;
  if (pluginId != null &&
      pluginId.isNotEmpty &&
      open != null &&
      metaOpenUsesKitDetails(open) &&
      context.mounted) {
    await openMetaItem(
      context,
      pluginId: pluginId,
      item: meta,
      shellTabId: shellTabId,
    );
    return;
  }

  final tmdbId = item['tmdbId'] as int?;
  if (tmdbId == null || !context.mounted) return;
  final mediaType = item['mediaType']?.toString() ?? 'movie';
  await AppRouter.openMovie(
    context,
    movie: Movie(
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
    ),
    shellTabId: shellTabId,
  );
}
