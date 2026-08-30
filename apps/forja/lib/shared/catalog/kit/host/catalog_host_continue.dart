import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/home/catalog_continue_watching_section.dart';
import 'package:rust/rust.dart' show isInProgressResume;
import 'package:forja/shared/catalog/kit/home/continue_watching_section.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/playback/catalog_play_resolve.dart';

/// `host.continue` — pack-agnostic Continue Watching (keyed by [pluginId]).
class CatalogHostContinue extends StatefulWidget {
  const CatalogHostContinue({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.continuePool,
    this.tvRowOrder = 1,
  });

  final String pluginId;
  final String tabId;
  /// Layout widget `pool` — e.g. `watch_history` for TMDB home pool.
  final String? continuePool;
  final int tvRowOrder;

  @override
  State<CatalogHostContinue> createState() => _CatalogHostContinueState();
}

class _CatalogHostContinueState extends State<CatalogHostContinue> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;

  @override
  void initState() {
    super.initState();
    CatalogWatchHistory.revision.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_reload);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await CatalogWatchHistory.getAll(widget.pluginId);
      if (!mounted) return;
      setState(() {
        _entries = list
            .where((e) {
              final pos = (e['positionMs'] as num?)?.toInt() ?? 0;
              final dur = (e['durationMs'] as num?)?.toInt() ?? 0;
              return isInProgressResume(pos, dur);
            })
            .take(10)
            .toList();
      });
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

  void _openDetails(Map<String, dynamic> entry) {
    final meta = CatalogWatchHistory.metaFromEntry(entry);
    if (meta == null) return;
    unawaited(
      openCatalogMetaItem(
        context,
        pluginId: widget.pluginId,
        item: meta,
      ).then((_) => _reload()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TMDB home pool uses a separate host widget until unified meta CW ships.
    if (widget.continuePool == 'watch_history') {
      return HomeContinueWatchingSection(
        compactTop: false,
        tvRowOrder: widget.tvRowOrder,
      );
    }

    return CatalogContinueWatchingSection(
      tabId: widget.tabId,
      entries: _entries,
      scrollController: _scroll,
      resumingMetaId: _resumingMetaId,
      onResume: _resume,
      onRemove: (e) async {
        final id = e['metaId']?.toString();
        if (id == null) return;
        await CatalogWatchHistory.remove(widget.pluginId, id);
        if (mounted) await _reload();
      },
      onOpenDetails: _openDetails,
      tvRowOrder: widget.tvRowOrder,
    );
  }
}
