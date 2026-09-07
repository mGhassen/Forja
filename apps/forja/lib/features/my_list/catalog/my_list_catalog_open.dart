import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/services/plugin_nav.dart';
import 'package:forja/shared/foundation/blocks/shell/legacy_list_item.dart';
import 'package:forja/shared/foundation/blocks/shell/kit_open.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/components/lists/my_list_button.dart';
import 'package:rust/rust.dart';

Future<void> openMyListCatalogEntry(
  BuildContext context,
  KitListEntry entry,
) async {
  if (!context.mounted) return;
  final pluginId =
      entry.pluginId ?? await pluginIdForLegacyListRow(entry.legacyRow);
  final open = entry.meta.open;
  if (pluginId != null &&
      open != null &&
      metaOpenUsesKitDetails(open) &&
      context.mounted) {
    await openMetaItem(
      context,
      pluginId: pluginId,
      item: entry.meta,
    );
    return;
  }
  if (context.mounted) {
    await openLegacyListItem(context, item: entry.legacyRow);
  }
}

Future<String?> pluginIdForLegacyListRow(Map<String, dynamic> row) async {
  final stored = row['pluginId']?.toString();
  if (stored != null && stored.isNotEmpty) return stored;
  final meta = metaItemFromLegacyListItem(row);
  final open = meta.open;
  if (open == null) return null;
  if (open.surface == 'tmdb') {
    return PluginNavRegistry.pluginIdForEngineType('movie');
  }
  return PluginNavRegistry.resolveKitPluginId(
    pluginId: stored,
    engineType: open.effectiveExtract.panelCategory,
  );
}

Widget? myListEntryPin(
  BuildContext context,
  KitListEntry entry,
  String tabStatus,
) {
  final iconSize = shellScaled(context, 18).clamp(12.0, 18.0);
  final knownStatus = entry.listStatus ?? tabStatus;
  final hubTarget = listFollowTargetFromLegacyItemSync(entry.legacyRow);
  if (hubTarget != null) {
    return MyListButton.hub(
      hubTarget: hubTarget,
      excludeFromTvTraversal: true,
      iconSize: iconSize,
      knownStatus: knownStatus,
    );
  }

  final tmdbId =
      entry.meta.numericId('tmdb') ?? entry.legacyRow['tmdbId'] as int?;
  if (tmdbId == null) return null;
  final row = entry.legacyRow;
  final mt = row['mediaType']?.toString() ?? 'movie';
  final mediaType = (mt == 'tv' || mt == 'series') ? 'tv' : 'movie';
  return MyListButton.movie(
    movie: Movie(
      id: tmdbId,
      imdbId: row['imdbId']?.toString(),
      title: entry.meta.name,
      posterPath: entry.meta.poster,
      backdropPath: entry.meta.background,
      voteAverage: entry.meta.rating ?? 0,
      releaseDate: entry.meta.releaseInfo,
      mediaType: mediaType,
    ),
    excludeFromTvTraversal: true,
    iconSize: iconSize,
    knownStatus: knownStatus,
  );
}
