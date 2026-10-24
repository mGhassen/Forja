import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/store/list_open_bind_sheet.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shared/engine/store/list_providers.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// `open.surface` on a kit.list row, including one nested under `meta`.
String? kitListItemSurface(Map<String, dynamic> item) {
  final row = kitListOpenRow(item);
  final open = row['open'];
  if (open is! Map) return null;
  final surface = (open['surface'] ?? '').toString().trim();
  return surface.isEmpty ? null : surface;
}

/// Flatten kit.list feed row so legacy open binding sees open / title / ids.
Map<String, dynamic> kitListOpenRow(Map<String, dynamic> item) {
  final row = Map<String, dynamic>.from(item);
  final meta = item['meta'];
  if (meta is Map) {
    final m = Map<String, dynamic>.from(meta);
    row['open'] ??= m['open'] ?? item['metaOpen'] ?? item['catalogOpen'];
    row['metaOpen'] ??= m['open'] ?? item['metaOpen'];
    final name = (m['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      row['name'] ??= name;
      row['title'] ??= name;
    }
    final poster = (m['poster'] ?? '').toString().trim();
    if (poster.isNotEmpty) row['poster'] ??= poster;
    final bg = (m['background'] ?? '').toString().trim();
    if (bg.isNotEmpty) row['background'] ??= bg;
    final ids = m['ids'];
    if (ids is Map && row['ids'] == null) {
      row['ids'] = Map<String, dynamic>.from(ids);
    }
    final tmdbMt = (m['tmdbMediaType'] ?? '').toString().trim();
    if (tmdbMt.isNotEmpty) row['tmdbMediaType'] ??= tmdbMt;
    final type = (m['type'] ?? '').toString().trim();
    if (type.isNotEmpty) {
      row['type'] ??= type;
      row['mediaType'] ??= type;
    }
  } else {
    row['open'] ??= item['metaOpen'] ?? item['catalogOpen'];
  }
  return row;
}

/// Open a kit.list row through the pack-declared hub-bind sheet
/// (`open: 'bind'` + `bind{}`). [forcePick] re-opens the sheet to rebind.
Future<void> openKitListBind(
  BuildContext context, {
  required String pluginId,
  required Map<String, dynamic> item,
  required KitListBindSpec spec,
  String? shellTabId,
  bool forcePick = false,
}) async {
  await openListItemWithBinding(
    context,
    spec: spec,
    item: kitListOpenRow(item),
    sourceItem: item,
    shellTabId: shellTabId,
    forcePick: forcePick,
  );
}

/// Open a list row with hub binding (RFC-108). Copy, candidate filter and
/// whether the pick is remembered all come from the pack [spec].
Future<void> openListItemWithBinding(
  BuildContext context, {
  required KitListBindSpec spec,
  required Map<String, dynamic> item,
  Map<String, dynamic>? sourceItem,
  String? shellTabId,
  bool forcePick = false,
}) async {
  final row = Map<String, dynamic>.from(item);
  var meta = metaItemFromLegacyListItem(row);

  if (!forcePick) {
    // Order: per-title bind → type default (settings) → first hub (Auto).
    final stored = await ListOpenBinding.resolveStored(item: row, meta: meta);
    if (stored != null) {
      if (!context.mounted) return;
      await openMetaItem(
        context,
        pluginId: stored.pluginId,
        item: stored.meta,
        shellTabId: shellTabId,
      );
      return;
    }

    final preferred = await ListOpenBinding.resolveDefault(
      item: row,
      meta: meta,
    );
    if (preferred != null) {
      if (spec.remember) {
        await ListOpenBinding.persistBinding(
          item: row,
          pluginId: preferred.pluginId,
          open: preferred.meta.open!,
          meta: preferred.meta,
        );
      }
      if (!context.mounted) return;
      await openMetaItem(
        context,
        pluginId: preferred.pluginId,
        item: preferred.meta,
        shellTabId: shellTabId,
      );
      return;
    }

    final engine = await ListOpenBinding.resolveEngineFallback(
      item: row,
      meta: meta,
    );
    if (engine != null) {
      if (!context.mounted) return;
      await openMetaItem(
        context,
        pluginId: engine.pluginId,
        item: engine.meta,
        shellTabId: shellTabId,
      );
      return;
    }
  }

  final candidates = await ListOpenBinding.candidatesFor(
    item: row,
    meta: meta,
    excludeTypes: spec.excludeTypes,
    allDetailsHubs: forcePick,
  );

  if (!forcePick && candidates.length == 1 && candidates.first.compatible) {
    final only = candidates.first;
    final open =
        ListOpenBinding.metaOpenForCandidate(row, meta, only.types) ??
        meta.open;
    if (open != null && open.id.trim().isNotEmpty) {
      final next = meta.copyWith(open: open);
      if (spec.remember) {
        await ListOpenBinding.persistBinding(
          item: row,
          pluginId: only.pluginId,
          open: open,
          meta: next,
        );
      }
      if (!context.mounted) return;
      await openMetaItem(
        context,
        pluginId: only.pluginId,
        item: next,
        shellTabId: shellTabId,
      );
      return;
    }
  }

  if (candidates.isEmpty) {
    if (context.mounted && spec.noHub.isNotEmpty) {
      ForjaToast.info(spec.noHub);
    }
    return;
  }

  if (!context.mounted) return;
  if (forcePick) {
    await showListOpenBindSheet(
      context,
      spec: spec,
      candidates: candidates,
      sourceMeta: meta,
      initialPluginId: row['pluginId']?.toString(),
      pickFilm: true,
      onSave: (bound) async {
        final saved = await persistListOpenBinding(
          spec: spec,
          row: row,
          meta: meta,
          bound: bound,
          sourceItem: sourceItem,
        );
        if (saved == null) return false;
        ProviderContainer? container;
        if (context.mounted) {
          try {
            container = ProviderScope.containerOf(context, listen: false);
          } catch (_) {}
        }
        invalidateListHubFeeds(container);
        return true;
      },
    );
    return;
  }

  final bound = await showListOpenBindSheet(
    context,
    spec: spec,
    candidates: candidates,
    sourceMeta: meta,
    initialPluginId: row['pluginId']?.toString(),
  );
  if (bound == null || !context.mounted) return;

  final saved = await persistListOpenBinding(
    spec: spec,
    row: row,
    meta: meta,
    bound: bound,
    sourceItem: sourceItem,
  );
  if (saved == null || !context.mounted) return;
  await openMetaItem(
    context,
    pluginId: bound.candidate.pluginId,
    item: saved,
    shellTabId: shellTabId,
  );
}

/// Copies a saved hub bind onto the grid row the next tap will read.
@visibleForTesting
void stampListOpenBinding(
  Map<String, dynamic> saved,
  Map<String, dynamic> target,
) {
  for (final key in const [
    'pluginId',
    'uniqueId',
    'metaOpen',
    'open',
    'catalogOpen',
    'listStatus',
    'mediaType',
    'title',
    'name',
    'poster',
    'posterPath',
    'background',
    'backdropPath',
  ]) {
    if (!saved.containsKey(key)) continue;
    target[key] = saved[key];
  }
  final meta = target['meta'];
  final open = saved['open'];
  if (meta is Map) {
    if (open != null) meta['open'] = open;
    for (final key in const ['name', 'poster', 'background']) {
      if (!saved.containsKey(key)) continue;
      meta[key] = saved[key];
    }
  }
  final paint = target['paint'];
  if (paint is Map) {
    final props = paint['props'];
    if (props is Map) {
      final title = saved['title'] ?? saved['name'];
      if (title != null) props['title'] = title;
      final poster = saved['poster'] ?? saved['posterPath'];
      if (poster != null) {
        props['imageUrl'] = poster;
        props['posterUrl'] = poster;
      }
    }
  }
}

/// Writes the chosen hub onto the bookmark when the pack remembers binds.
/// Returns the meta that would open.
Future<MetaItem?> persistListOpenBinding({
  required KitListBindSpec spec,
  required Map<String, dynamic> row,
  required MetaItem meta,
  required ListOpenBindResult bound,
  Map<String, dynamic>? sourceItem,
}) async {
  final candidate = bound.candidate;
  MetaOpen? open;
  MetaItem next = meta;

  if (bound.hit != null) {
    final hit = bound.hit!;
    final hitOpen = hit.open;
    if (hitOpen == null || hitOpen.id.trim().isEmpty) {
      if (spec.noHandoff.isNotEmpty) ForjaToast.info(spec.noHandoff);
      return null;
    }
    open = hitOpen;
    next = hit.copyWith(
      name: hit.name.trim().isNotEmpty ? hit.name : meta.name,
      poster: hit.poster.trim().isNotEmpty ? hit.poster : meta.poster,
      background: hit.background.trim().isNotEmpty
          ? hit.background
          : meta.background,
    );
    final surface = open.surface.trim();
    if (surface.isNotEmpty && surface != 'tmdb') {
      final panel = open.effectiveExtract.panelCategory.trim();
      row['mediaType'] = panel.isNotEmpty ? panel : surface;
    }
  } else {
    open =
        ListOpenBinding.metaOpenForCandidate(row, meta, candidate.types) ??
        meta.open;
    if (open == null || open.id.trim().isEmpty) {
      if (spec.noHandoffFor.isNotEmpty) {
        ForjaToast.info(spec.noHandoffForHub(candidate.label));
      }
      return null;
    }
    next = meta.copyWith(open: open);
  }

  if (!spec.remember) return next;
  await ListOpenBinding.persistBinding(
    item: row,
    pluginId: candidate.pluginId,
    open: open,
    meta: next,
  );
  final grid = sourceItem;
  if (grid != null && !identical(grid, row)) {
    stampListOpenBinding(row, grid);
  }
  return next;
}
