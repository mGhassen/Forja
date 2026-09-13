import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/catalog_open.dart';
import 'package:forja/shared/engine/store/legacy_list_item.dart';
import 'package:forja/shared/host/lists_ui/list_open_bind_sheet.dart';
import 'package:forja/shared/engine/store/list_open_binding.dart';
import 'package:forja/shared/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';

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
