import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:forja/shared/engine/hub/legacy_list_item.dart';
import 'package:forja/shared/engine/lists/list_open_binding.dart';
import 'package:forja/shared/engine/lists/list_open_picker.dart';
import 'package:forja/shared/engine/lists/list_open_title_rank.dart';
import 'package:forja/shared/shell/forja_toast.dart';
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
  final picked = await showListOpenHubPicker(
    context,
    candidates: candidates,
    title: forcePick ? 'Open with' : 'Choose hub',
  );
  if (picked == null || !context.mounted) return;

  await _bindCandidateAndOpen(
    context,
    row: row,
    meta: meta,
    candidate: picked,
    shellTabId: shellTabId,
  );
}

Future<void> _bindCandidateAndOpen(
  BuildContext context, {
  required Map<String, dynamic> row,
  required MetaItem meta,
  required ListOpenCandidate candidate,
  String? shellTabId,
}) async {
  MetaOpen? open = ListOpenBinding.metaOpenForCandidate(
    row,
    meta,
    candidate.types,
  );
  MetaItem next = meta;

  if (open == null ||
      open.id.trim().isEmpty ||
      candidate.needsSearch) {
    if (!candidate.hasSearch) {
      if (context.mounted) {
        ForjaToast.info(
          '${candidate.label} needs a title match, but this hub has no search',
        );
      }
      return;
    }
    final title = meta.name.trim();
    if (title.isEmpty) {
      if (context.mounted) ForjaToast.info('Missing title to search');
      return;
    }
    final hits = await listOpenSearchHub(
      pluginId: candidate.pluginId,
      query: title,
      yearHint: meta.releaseInfo.isNotEmpty
          ? meta.releaseInfo
          : meta.premiereDate,
    );
    if (!context.mounted) return;
    if (hits.isEmpty) {
      await listOpenShowEmptySearchToast(candidate.label);
      return;
    }
    final queryYear = listOpenParseYear(meta.releaseInfo) ??
        listOpenParseYear(meta.premiereDate) ??
        listOpenParseYear(title);
    final top = hits.first;
    final topYear = listOpenParseYear(
      top.releaseInfo.isNotEmpty ? top.releaseInfo : top.premiereDate,
    );
    // Exact / same-token title → skip the picker.
    final hit = hits.length == 1 ||
            listOpenIsStrongTitleMatch(
              title,
              top.name,
              queryYear: queryYear,
              candidateYear: topYear,
            )
        ? top
        : await showListOpenSearchHitPicker(
            context,
            hits: hits,
            hubLabel: candidate.label,
          );
    if (hit == null || !context.mounted) return;
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
