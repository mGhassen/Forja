import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/components/cards/kit_poster_card.dart';
import 'package:forja/shared/foundation/blocks/details/kit_details_play.dart';
import 'package:forja/shared/foundation/components/rows/kit_row_prefetch.dart';
import 'package:forja/shared/foundation/components/rows/kit_section.dart';
import 'package:forja/shared/foundation/components/sections/continue_watching_section.dart';
import 'package:forja/shared/foundation/blocks/play/play_resolve.dart';
import 'package:forja/shared/foundation/services/watch_history.dart';
import 'package:forja/shared/foundation/blocks/shell/kit_open.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/playback/open/history_playback_resume.dart';
import 'package:rust/rust.dart' show WatchHistoryService, canResumeFromSavedProgress;

/// Layout widget type `continue` — pack-scoped [WatchHistory]; optional
/// legacy Home TMDB [WatchHistoryService] when the pack requests it.
class ContinueWidget extends StatefulWidget {
  const ContinueWidget({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.mergeHomeWatchHistory = false,
    this.tvRowOrder = 1,
    this.tvFocusUp,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final bool mergeHomeWatchHistory;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<ContinueWidget> createState() => _ContinueWidgetState();
}

class _ContinueWidgetState extends State<ContinueWidget> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  bool _viewportActivated = false;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    WatchHistory.revision.addListener(_onHistoryRevision);
    if (widget.mergeHomeWatchHistory) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_reload());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ContinueWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
  }

  void _onHistoryRevision() {
    unawaited(_reload());
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
    WatchHistory.revision.removeListener(_onHistoryRevision);
    unawaited(_homeHistorySub?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await catalogContinueEntries(
        widget.pluginId,
        mergeHomeWatchHistory: widget.mergeHomeWatchHistory,
      );
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (_) {}
  }

  Future<void> _resume(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final home = entry['homeHistory'];
      if (home is! Map || _resumingMetaId != null) return;
      final metaId = entry['metaId']?.toString();
      if (metaId == null) return;
      setState(() => _resumingMetaId = metaId);
      try {
        await resumePlaybackFromHistory(
          context,
          Map<String, dynamic>.from(home),
        );
        if (mounted) await _reload();
      } catch (e) {
        if (mounted) ForjaToast.error('Resume failed: $e');
      } finally {
        if (mounted) setState(() => _resumingMetaId = null);
      }
      return;
    }

    final metaId = entry['metaId']?.toString();
    if (metaId == null || _resumingMetaId != null) return;
    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    setState(() => _resumingMetaId = metaId);
    try {
      final epNum = (entry['episodeNumber'] as num?)?.toInt() ?? 1;
      final posMs = (entry['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (entry['durationMs'] as num?)?.toInt() ?? 0;
      Duration? startPosition;
      if (posMs > 5000 && canResumeFromSavedProgress(posMs, durMs)) {
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
      await runPlayFromContext(context: context, ctx: ctx);
      if (mounted) await _reload();
    } catch (e) {
      if (mounted) ForjaToast.error('Resume failed: $e');
    } finally {
      if (mounted) setState(() => _resumingMetaId = null);
    }
  }

  Future<void> _openDetails(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final metaJson = entry['meta'];
      if (metaJson is! Map) return;
      final meta = MetaItem.fromJson(Map<String, dynamic>.from(metaJson));
      final home = entry['homeHistory'];
      final season = home is Map ? home['season'] as int? : null;
      final episode = home is Map ? home['episode'] as int? : null;
      await openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: meta,
        initialSeason: season,
        initialEpisode: episode,
      );
      if (mounted) await _reload();
      return;
    }

    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    await openMetaItem(
      context,
      pluginId: widget.pluginId,
      item: meta,
    );
    if (mounted) await _reload();
  }

  Future<void> _remove(Map<String, dynamic> entry) async {
    if (isHomeWatchHistoryEntry(entry)) {
      final id = entry['metaId']?.toString();
      if (id == null) return;
      await WatchHistoryService().removeItem(id);
      if (mounted) await _reload();
      return;
    }

    final id = entry['metaId']?.toString();
    if (id == null) return;
    await WatchHistory.remove(widget.pluginId, id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return KitLazyViewportGate(
      detectorKey: ValueKey('continue:${widget.tabId}'),
      placeholderHeight: KitSection.sectionHeight(
        context,
        cardAspect: KitPosterAspect.landscape,
      ),
      prefetchSlot: widget.prefetchSlot,
      onVisible: _onViewportVisible,
      builder: (_) => ContinueWatchingSection(
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
