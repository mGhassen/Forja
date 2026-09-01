import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/sources/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:rust/rust.dart';

/// Layout widget [`CatalogKitTypes.list`] — host-backed poster grid.
class CatalogKitListWidget extends ConsumerStatefulWidget {
  const CatalogKitListWidget({
    super.key,
    required this.tabId,
    required this.layoutSpec,
    required this.refreshEpoch,
    this.tvRowOrder = 0,
  });

  final String tabId;
  final Map<String, dynamic> layoutSpec;
  final int refreshEpoch;
  final int tvRowOrder;

  String get listSource => (layoutSpec['source'] ?? 'my_list').toString();
  String get kindMenuId =>
      (layoutSpec['kindMenu'] ?? layoutSpec['kindTab'] ?? 'kind').toString();
  String get statusTabId =>
      (layoutSpec['statusTab'] ?? 'status').toString();
  String get gridRowId => (layoutSpec['id'] ?? 'grid').toString();

  @override
  ConsumerState<CatalogKitListWidget> createState() =>
      _CatalogKitListWidgetState();
}

class _CatalogKitListWidgetState extends ConsumerState<CatalogKitListWidget> {
  final _scroll = ScrollController();
  CatalogKitListSource? _source;

  @override
  void initState() {
    super.initState();
    _source = CatalogKitListSources.resolve(widget.listSource);
    TvHeroActions.bind(
      widget.tabId,
      enterFromNavFocus: _focusEntry,
      restoreFocus: () {
        if (_focusRow(widget.kindMenuId, 0)) return true;
        if (_focusRow(widget.statusTabId, 0)) return true;
        return _focusRow(widget.gridRowId, 0);
      },
    );
  }

  @override
  void didUpdateWidget(CatalogKitListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listSource != oldWidget.listSource) {
      _source = CatalogKitListSources.resolve(widget.listSource);
    }
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      _source?.invalidateOnRefresh(ref);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    ShellTvFocusCoordinator.clearTab(widget.tabId);
    super.dispose();
  }

  bool _focusRow(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItem(widget.tabId, rowId, index);

  bool _focusRowLast(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(widget.tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    return _focusRow(rowId, idx);
  }

  void _focusEntry() {
    if (_focusRow(widget.kindMenuId, 0)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ShellTvFocus.currentNavTabId != widget.tabId) return;
      _focusRow(widget.kindMenuId, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) {
      return Center(
        child: Text(
          'Unsupported kit.list source: ${widget.listSource}',
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      );
    }

    final scope = CatalogLayoutScope.of(context);
    final status =
        scope.selectedId(widget.statusTabId) ??
        widget.layoutSpec['defaultStatus']?.toString() ??
        'plantowatch';
    final kind = scope.selectedId(widget.kindMenuId);

    source.setupSideEffects(ref, status);
    final pageAsync = source.watchPage(ref, status);

    return pageAsync.when(
      loading: () => _loadingGrid(context),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      ),
      data: (page) {
        if (page.loadingRemote && page.totalCount == 0) {
          return _loadingGrid(context);
        }
        final entries = page.entriesForKind(kind);
        if (entries.isEmpty) return _emptyState(context, kind: kind);
        return _grid(context, source, entries);
      },
    );
  }

  Widget _grid(
    BuildContext context,
    CatalogKitListSource source,
    List<CatalogKitListEntry> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _homeGrid(context, constraints.maxWidth);
        return TvGrid(
          tabId: widget.tabId,
          rowId: widget.gridRowId,
          sortOrder: widget.tvRowOrder + 2,
          columns: grid.columns,
          itemCount: entries.length,
          onFocusUp: () =>
              _focusRowLast(widget.statusTabId) ||
              _focusRow(widget.statusTabId, 0),
          child: CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  grid.leading,
                  grid.topPad,
                  grid.rightPad,
                  shellTvCatalogScrollBottomGap(context),
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid.columns,
                    mainAxisSpacing: grid.gap,
                    crossAxisSpacing: grid.gap,
                    childAspectRatio: grid.cardW / grid.cardH,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = entries[index];
                    return Align(
                      alignment: Alignment.topCenter,
                      child: _card(context, source, entry, index, grid: grid),
                    );
                  }, childCount: entries.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  HubPosterCard _card(
    BuildContext context,
    CatalogKitListSource source,
    CatalogKitListEntry entry,
    int index, {
    required _HomeGrid grid,
  }) {
    final meta = entry.meta;
    final status =
        CatalogLayoutScope.of(context).selectedId(widget.statusTabId) ??
        'plantowatch';
    return HubPosterCard(
      imageUrl: catalogKitListPosterUrl(meta),
      title: meta.name,
      subtitle: hubPosterCardSubtitle(meta),
      rating: (meta.rating ?? 0) > 0 ? meta.rating : null,
      badge: hubPosterCardBadge(meta),
      listPin: source.buildEntryPin(context, entry, status),
      gridIndex: index,
      gridColumns: grid.columns,
      tvTabId: widget.tabId,
      tvRowId: widget.gridRowId,
      onUpEdge: index < grid.columns
          ? () =>
              _focusRowLast(widget.statusTabId) ||
              _focusRow(widget.statusTabId, 0)
          : null,
      onTap: () => source.openEntry(context, entry),
    );
  }

  Widget _loadingGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _homeGrid(context, constraints.maxWidth);
        return homeLoadingShimmer(
          GridView.builder(
            padding: EdgeInsets.fromLTRB(
              grid.leading,
              grid.topPad,
              grid.rightPad,
              ShellTokens.bodyHorizontalPadding,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid.columns,
              mainAxisSpacing: grid.gap,
              crossAxisSpacing: grid.gap,
              childAspectRatio: grid.cardW / grid.cardH,
            ),
            itemCount: grid.columns * 2,
            itemBuilder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(
                  shellCardBorderRadius(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, {String? kind}) {
    final filtered = kind != null;
    String? kindLabel;
    if (kind != null) {
      final kindSpec =
          CatalogLayoutScope.of(context).widgetSpecFor(widget.kindMenuId);
      if (kindSpec != null) {
        for (final tab in catalogKitItemsFromSpec(kindSpec)) {
          if (tab.id == kind) kindLabel = tab.label;
        }
      }
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            Text(
              filtered && kindLabel != null
                  ? 'Nothing in $kindLabel'
                  : 'Nothing in this list',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Tap a kind tab again to show everything'
                  : 'Tap + on a title to set Plan to Watch / Watching / On Hold / Completed / Dropped',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGrid {
  const _HomeGrid({
    required this.columns,
    required this.cardW,
    required this.cardH,
    required this.gap,
    required this.leading,
    required this.rightPad,
    required this.topPad,
  });

  final int columns;
  final double cardW;
  final double cardH;
  final double gap;
  final double leading;
  final double rightPad;
  final double topPad;
}

_HomeGrid _homeGrid(BuildContext context, double maxWidth) {
  final cardW = shellMovieCardWidth(context);
  final cardH = shellMovieCardHeight(context);
  final gap = shellMovieCardRowGap(context);
  final leading = ShellTokens.compactChromeLeadingInset(context);
  final trailing = ShellTokens.bodyHorizontalPadding;
  final inner = math.max(0.0, maxWidth - leading - trailing);
  final columns = math.max(1, ((inner + gap) / (cardW + gap)).floor());
  final gridW = columns * cardW + (columns - 1) * gap;
  final rightPad = math.max(trailing, maxWidth - leading - gridW);
  final topPad = cardH * (ShellTokens.focusActiveScale - 1) / 2 + 4;
  return _HomeGrid(
    columns: columns,
    cardW: cardW,
    cardH: cardH,
    gap: gap,
    leading: leading,
    rightPad: rightPad,
    topPad: topPad,
  );
}

String catalogKitListPosterUrl(CatalogMetaItem meta) {
  final poster = meta.poster;
  if (poster.isEmpty) return '';
  if (poster.startsWith('http')) return poster;
  if (poster.startsWith('/')) return TmdbApi.getImageUrl(poster);
  return poster;
}

/// @deprecated Use [catalogKitListPosterUrl].
String myListPosterUrl(CatalogMetaItem meta) => catalogKitListPosterUrl(meta);
