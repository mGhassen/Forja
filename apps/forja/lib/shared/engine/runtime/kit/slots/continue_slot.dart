import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/store/continue_entries.dart';
import 'package:forja/shared/engine/store/watch_history.dart';
import 'package:forja/shared/playback/open/history_playback_resume.dart';
import 'package:forja/shared/playback/play_resolve.dart';
import 'package:forja/shared/engine/runtime/details/kit_details_play.dart';
import 'package:forja/shell/core/forja_shell_layout.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/catalog/continue_section.dart';
import 'package:rust/rust.dart' show WatchHistoryService, canResumeFromSavedProgress;

/// Hub `continue` — resume playback (not details-only).
class PackContinueSlot extends StatefulWidget {
  const PackContinueSlot({
    super.key,
    required this.pluginId,
    this.tabId,
    this.mergeHomeWatchHistory = false,
  });

  final String pluginId;
  final String? tabId;
  final bool mergeHomeWatchHistory;

  @override
  State<PackContinueSlot> createState() => _PackContinueSlotState();
}

class _PackContinueSlotState extends State<PackContinueSlot> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  StreamSubscription<List<Map<String, dynamic>>>? _homeHistorySub;

  @override
  void initState() {
    super.initState();
    WatchHistory.revision.addListener(_onHistoryRevision);
    if (widget.mergeHomeWatchHistory) {
      _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
        unawaited(_reload());
      });
    }
    unawaited(_reload());
  }

  @override
  void didUpdateWidget(covariant PackContinueSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.mergeHomeWatchHistory != widget.mergeHomeWatchHistory) {
      unawaited(_homeHistorySub?.cancel());
      _homeHistorySub = null;
      if (widget.mergeHomeWatchHistory) {
        _homeHistorySub = WatchHistoryService().historyStream.listen((_) {
          unawaited(_reload());
        });
      }
      unawaited(_reload());
    }
  }

  void _onHistoryRevision() => unawaited(_reload());

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
      await openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: meta,
        initialSeason: home is Map ? home['season'] as int? : null,
        initialEpisode: home is Map ? home['episode'] as int? : null,
      );
      if (mounted) await _reload();
      return;
    }

    final meta = WatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    await openMetaItem(context, pluginId: widget.pluginId, item: meta);
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
    if (_entries.isEmpty) return const SizedBox.shrink();
    final showArrows = ShellScope.inputPolicyOf(context).scaleOnHover;
    final cardW = shellContinueWatchingCardWidth(context);
    final cardH = shellContinueWatchingCardHeight(context);
    final pad = shellHomeSectionHorizontalPadding(context);

    Map<String, dynamic>? byId(String metaId) {
      for (final e in _entries) {
        if (e['metaId']?.toString() == metaId) return e;
      }
      return null;
    }

    return ContinueSection(
      scrollController: _scroll,
      showScrollArrows: showArrows,
      cardWidth: cardW,
      cardHeight: cardH,
      titlePadding: EdgeInsets.fromLTRB(
        pad,
        shellSectionTitleTopCompact(context),
        pad,
        16,
      ),
      listPadding: EdgeInsets.symmetric(horizontal: pad),
      entries: [
        for (final e in _entries) ContinueEntry.fromMap(e),
      ],
      resumingMetaId: _resumingMetaId,
      onResume: (entry) {
        final raw = byId(entry.metaId);
        if (raw != null) unawaited(_resume(raw));
      },
      onInfo: (entry) {
        final raw = byId(entry.metaId);
        if (raw != null) unawaited(_openDetails(raw));
      },
      onRemove: (entry) {
        final raw = byId(entry.metaId);
        if (raw != null) unawaited(_remove(raw));
      },
    );
  }
}
