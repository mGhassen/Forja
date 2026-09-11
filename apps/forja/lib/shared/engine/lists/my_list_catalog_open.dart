import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja/shared/engine/hub/plugin_nav.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';

import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja/shared/engine/lists/my_list_host.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
Future<void> openMyListCatalogEntry(
  BuildContext context,
  KitListEntry entry,
) async {
  if (!context.mounted) return;
  final shellTabId =
      ShellBus.activeShellTabId ?? MyListHost.tabId;
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
      shellTabId: shellTabId,
    );
    return;
  }
  if (context.mounted) {
    await openLegacyListItem(
      context,
      item: entry.legacyRow,
      shellTabId: shellTabId,
    );
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
  final followTarget = listFollowTargetFromLegacyItemSync(entry.legacyRow);
  if (followTarget != null) {
    return KitListStatusButton.follow(
      followTarget: followTarget,
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
  return KitListStatusButton.movie(
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
