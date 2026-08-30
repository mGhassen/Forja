import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/catalog/kit/rows/catalog_row_prefetch.dart';
import 'package:forja/shared/catalog/kit/rows/hub_catalog_section.dart';
import 'package:forja/shared/catalog/kit/widgets/catalog_continue_watching_section.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_resolve.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart' show isInProgressResume;

/// Layout widget type `continue` — pack-scoped [CatalogWatchHistory] only.
class CatalogContinueWidget extends StatefulWidget {
  const CatalogContinueWidget({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.tvRowOrder = 1,
    this.tvFocusUp,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final CatalogHubRowPrefetchSlot? prefetchSlot;

  @override
  State<CatalogContinueWidget> createState() => _CatalogContinueWidgetState();
}

class _CatalogContinueWidgetState extends State<CatalogContinueWidget> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  bool _viewportActivated = false;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    CatalogWatchHistory.revision.addListener(_onHistoryRevision);
  }

  void _onHistoryRevision() {
    if (_viewportActivated) unawaited(_reload());
  }

  void _onViewportVisible() {
    _activate(prefetch: false);
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, () => _activate(prefetch: true));
  }

  void _activate({required bool prefetch}) {
    if (_viewportActivated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _viewportActivated = true);
    unawaited(_reload());
    widget.prefetchSlot?.notifyVisible();
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_onHistoryRevision);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await catalogContinueEntries(widget.pluginId);
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (_) {}
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    final metaId = entry['metaId']?.toString();
    if (metaId == null || _resumingMetaId != null) return;
    final meta = CatalogWatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    setState(() => _resumingMetaId = metaId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000 && isInProgressResume(posMs, durMs)) {
        final clamped = (durMs > 0 && posMs > durMs - 30000)
            ? (durMs - 30000)
            : posMs;
        startPosition =
            Duration(milliseconds: (clamped - 3000).clamp(0, 1 << 31));
      }
      final extras = entry['extras'];
      final ctx = catalogPlayContextFromMeta(
        meta: meta,
        pluginId: widget.pluginId,
        episodeNumber: epNum,
        episodeVideoId: entry['episodeVideoId']?.toString(),
        extras: extras is Map
            ? Map<String, dynamic>.from(extras)
            : const {},
        startPosition: startPosition,
      );
      if (!mounted) return;
      await runHubPlayFromContext(context: context, ctx: ctx);
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingMetaId = null);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> entry) async {
    final meta = CatalogWatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    await openCatalogMetaItem(
      context,
      pluginId: widget.pluginId,
      item: meta,
    );
    if (mounted) await _reload();
  }

  Future<void> _remove(Map<String, dynamic> entry) async {
    final id = entry['metaId']?.toString();
    if (id == null) return;
    await CatalogWatchHistory.remove(widget.pluginId, id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return HubLazyViewportGate(
      detectorKey: ValueKey('continue:${widget.tabId}'),
      placeholderHeight: HubCatalogSection.sectionHeight(
        context,
        cardAspect: HubPosterAspect.landscape,
      ),
      prefetchSlot: widget.prefetchSlot,
      onVisible: _onViewportVisible,
      builder: (_) => CatalogContinueWatchingSection(
        tabId: widget.tabId,
        entries: _entries,
        scrollController: _scroll,
        resumingMetaId: _resumingMetaId,
        onResume: _resume,
        onRemove: _remove,
        onOpenDetails: (e) => unawaited(_openDetails(e)),
        tvRowOrder: widget.tvRowOrder,
        tvFocusUp: widget.tvFocusUp,
      ),
    );
  }
}
