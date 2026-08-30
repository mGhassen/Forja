import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_play.dart';
import 'package:forja/shared/catalog/kit/widgets/catalog_continue_watching_section.dart';
import 'package:forja/shared/catalog/services/catalog_home_watch_history.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/playback/catalog_play_resolve.dart';
import 'package:forja/shared/playback/history_playback_resume.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart' show WatchHistoryService, isInProgressResume;

/// Layout widget type `continue` — pack-scoped history; Home also reads legacy
/// [WatchHistoryService] until TMDB details play through catalog meta.
class CatalogContinueWidget extends StatefulWidget {
  const CatalogContinueWidget({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.tvRowOrder = 1,
  });

  final String pluginId;
  final String tabId;
  final int tvRowOrder;

  @override
  State<CatalogContinueWidget> createState() => _CatalogContinueWidgetState();
}

class _CatalogContinueWidgetState extends State<CatalogContinueWidget> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _entries = const [];
  String? _resumingMetaId;
  StreamSubscription<List<Map<String, dynamic>>>? _legacyHistorySub;

  @override
  void initState() {
    super.initState();
    CatalogWatchHistory.revision.addListener(_reload);
    if (catalogHomeUsesLegacyWatchHistory(widget.pluginId)) {
      _legacyHistorySub = listenLegacyHomeWatchHistory(_reload);
    }
    unawaited(_reload());
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_reload);
    unawaited(_legacyHistorySub?.cancel());
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
    final legacy = entry['_legacyWatch'];
    if (legacy is Map) {
      final uniqueId = entry['_legacyUniqueId']?.toString();
      if (uniqueId == null || _resumingMetaId != null) return;
      setState(() => _resumingMetaId = uniqueId);
      try {
        await resumePlaybackFromHistory(
          context,
          Map<String, dynamic>.from(legacy),
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
    final legacy = entry['_legacyWatch'];
    if (legacy is Map) {
      final item = Map<String, dynamic>.from(legacy);
      final movie = movieFromWatchHistory(item);
      final stremioItemId = item['stremioId'] as String?;
      final stremioAddonBase = item['stremioAddonBaseUrl'] as String?;
      final isCustomId = stremioItemId != null &&
          stremioAddonBase != null &&
          !stremioItemId.startsWith('tt');
      Map<String, dynamic>? stremioItem;
      if (isCustomId) {
        stremioItem = {
          'id': stremioItemId,
          '_addonBaseUrl': stremioAddonBase,
          'type': item['stremioType'] ??
              (item['season'] != null ? 'series' : 'movie'),
          'name': movie.title,
        };
      }
      await AppRouter.openDetails(
        context,
        movie: movie,
        stremioItem: stremioItem,
        initialSeason: item['season'] as int?,
        initialEpisode: item['episode'] as int?,
      );
      if (mounted) await _reload();
      return;
    }

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
    final legacyId = entry['_legacyUniqueId']?.toString();
    if (legacyId != null) {
      await WatchHistoryService().removeItem(legacyId);
      if (mounted) await _reload();
      return;
    }
    final id = entry['metaId']?.toString();
    if (id == null) return;
    await CatalogWatchHistory.remove(widget.pluginId, id);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return CatalogContinueWatchingSection(
      tabId: widget.tabId,
      entries: _entries,
      scrollController: _scroll,
      resumingMetaId: _resumingMetaId,
      onResume: _resume,
      onRemove: _remove,
      onOpenDetails: (e) => unawaited(_openDetails(e)),
      tvRowOrder: widget.tvRowOrder,
    );
  }
}
