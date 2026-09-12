import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';

Future<void> openCatalogListEntry(
  BuildContext context,
  KitListEntry entry,
) async {
  if (!context.mounted) return;
  final shellTabId = ShellBus.activeShellTabId ?? '';
  if (shellTabId.isEmpty) return;

  // Prefer pack `open` handoff (TMDB / anime / drama). Never resolve details
  // from the active list-hub tab — that calls feed-only packs with `details`.
  final row = Map<String, dynamic>.from(entry.legacyRow);
  final entryPlugin = entry.pluginId?.trim();
  if (entryPlugin != null &&
      entryPlugin.isNotEmpty &&
      row['pluginId'] == null) {
    row['pluginId'] = entryPlugin;
  }
  if (context.mounted) {
    await openLegacyListItem(
      context,
      item: row,
      shellTabId: shellTabId,
    );
  }
}

Widget? catalogListEntryPin(
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
      entry.meta.numericId('tmdb') ?? legacyListTmdbId(entry.legacyRow);
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
