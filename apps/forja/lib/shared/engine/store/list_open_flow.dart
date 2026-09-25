import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/paint_artifact.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/engine/store/list_open_bind_sheet.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Feed-only kits (no `details`) use hub binding; details hubs open meta as-is.
@visibleForTesting
bool kitListUsesOpenBinding({required bool? callerHasDetails}) =>
    callerHasDetails == false;

/// `open.surface` on a kit.list row, including one nested under `meta`.
@visibleForTesting
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

/// Open a kit.list poster — hub binding when the caller pack has no details.
Future<void> openKitListItem(
  BuildContext context, {
  required String pluginId,
  required Map<String, dynamic> item,
  String? shellTabId,
  bool forcePick = false,
}) async {
  // Saved-library rows open the host page. Feed binding is for bookmarks
  // that still need a details hub.
  if (kitListItemSurface(item) == 'offline') {
    final meta = PackPaintArtifact.metaItemOf(
      props: PackPaintArtifact.propsOf(item),
      open: item['open'] ?? item['metaOpen'] ?? item['catalogOpen'],
      meta: item['meta'],
    );
    if (meta == null || !context.mounted) return;
    await openMetaItem(
      context,
      pluginId: pluginId,
      item: meta,
      shellTabId: shellTabId,
    );
    return;
  }
  final syncHas = PluginNavRegistry.pluginHasDetailsSync(pluginId);
  final hasDetails =
      syncHas ?? await PluginNavRegistry.pluginHasDetails(pluginId);
  if (!kitListUsesOpenBinding(callerHasDetails: hasDetails)) {
    if (forcePick) return;
    final meta = PackPaintArtifact.metaItemOf(
      props: PackPaintArtifact.propsOf(item),
      open: item['open'] ?? item['metaOpen'] ?? item['catalogOpen'],
      meta: item['meta'],
    );
    if (meta == null) return;
    if (!context.mounted) return;
    await openMetaItem(
      context,
      pluginId: pluginId,
      item: meta,
      shellTabId: shellTabId,
    );
    return;
  }
  if (!context.mounted) return;
  await openListItemWithBinding(
    context,
    item: kitListOpenRow(item),
    shellTabId: shellTabId,
    forcePick: forcePick,
  );
}

/// Open a My List / catalog list row with hub binding (RFC-108).
Future<void> openListItemWithBinding(
  BuildContext context, {
  required Map<String, dynamic> item,
  String? shellTabId,
  bool forcePick = false,
}) async {
  final row = Map<String, dynamic>.from(item);
  var meta = metaItemFromLegacyListItem(row);

  if (!forcePick) {
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

    final preferred =
        await ListOpenBinding.resolveDefault(item: row, meta: meta);
    if (preferred != null) {
      await ListOpenBinding.persistBinding(
        item: row,
        pluginId: preferred.pluginId,
        open: preferred.meta.open!,
        meta: preferred.meta,
      );
      if (!context.mounted) return;
      await openMetaItem(
        context,
        pluginId: preferred.pluginId,
        item: preferred.meta,
        shellTabId: shellTabId,
      );
      return;
    }
  }

  final candidates = await ListOpenBinding.candidatesFor(
    item: row,
    meta: meta,
    allDetailsHubs: forcePick,
  );

  if (!forcePick && candidates.length == 1 && candidates.first.compatible) {
    final only = candidates.first;
    final open = ListOpenBinding.metaOpenForCandidate(row, meta, only.types) ??
        meta.open;
    if (open != null && open.id.trim().isNotEmpty) {
      final next = meta.copyWith(open: open);
      await ListOpenBinding.persistBinding(
        item: row,
        pluginId: only.pluginId,
        open: open,
        meta: next,
      );
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
    if (context.mounted) {
      ForjaToast.info('No hub available to open this title');
    }
    return;
  }

  if (!context.mounted) return;
  final bound = await showListOpenBindSheet(
    context,
    candidates: candidates,
    sourceMeta: meta,
    title: forcePick ? 'Open with…' : 'Open in…',
    initialPluginId: row['pluginId']?.toString(),
  );
  if (bound == null || !context.mounted) return;

  await _applyBindAndOpen(
    context,
    row: row,
    meta: meta,
    bound: bound,
    shellTabId: shellTabId,
  );
}

Future<void> _applyBindAndOpen(
  BuildContext context, {
  required Map<String, dynamic> row,
  required MetaItem meta,
  required ListOpenBindResult bound,
  String? shellTabId,
}) async {
  final candidate = bound.candidate;
  MetaOpen? open;
  MetaItem next = meta;

  if (bound.hit != null) {
    final hit = bound.hit!;
    final hitOpen = hit.open;
    if (hitOpen == null || hitOpen.id.trim().isEmpty) {
      ForjaToast.info('That match has no open handoff');
      return;
    }
    open = hitOpen;
    next = hit.copyWith(
      name: hit.name.trim().isNotEmpty ? hit.name : meta.name,
      poster: hit.poster.trim().isNotEmpty ? hit.poster : meta.poster,
      background:
          hit.background.trim().isNotEmpty ? hit.background : meta.background,
    );
  } else {
    open = ListOpenBinding.metaOpenForCandidate(row, meta, candidate.types) ??
        meta.open;
    if (open == null || open.id.trim().isEmpty) {
      ForjaToast.info('No open handoff for ${candidate.label}');
      return;
    }
    next = meta.copyWith(open: open);
  }

  await ListOpenBinding.persistBinding(
    item: row,
    pluginId: candidate.pluginId,
    open: open,
    meta: next,
  );
  if (!context.mounted) return;
  await openMetaItem(
    context,
    pluginId: candidate.pluginId,
    item: next,
    shellTabId: shellTabId,
  );
}
