import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/catalog/kit/cards/hub_live_match_dense_tile.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_top_menu_registry.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_layout_scope.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/host_list_registry.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';
import 'package:rust/rust.dart';

/// Layout widget [`CatalogKitTypes.list`] — poster grid or dense list from a
/// registered host list source (opaque `source` id and/or hub [pluginId]).
class CatalogKitListWidget extends ConsumerStatefulWidget {
  const CatalogKitListWidget({
    super.key,
    required this.tabId,
    required this.layoutSpec,
    required this.refreshEpoch,
    this.pluginId = '',
    this.tvRowOrder = 0,
    this.selectedEntryId,
    this.onEntrySelected,
    this.sidePanel,
    this.dynamicKindChips = false,
    this.onDynamicKinds,
  });

  final String tabId;
  final Map<String, dynamic> layoutSpec;
  final int refreshEpoch;
  final String pluginId;
  final int tvRowOrder;

  /// When set, dense rows highlight this entry id (list+panel).
  final String? selectedEntryId;

  /// Called when a row is activated (before [CatalogKitListSource.openEntry]).
  final ValueChanged<CatalogKitListEntry>? onEntrySelected;

  /// Optional side panel beside a dense list (Live Sports streams panel).
  final Widget? sidePanel;

  /// When true and no layout kind menu, expose unique entry kinds to parent.
  final bool dynamicKindChips;

  final ValueChanged<List<String>>? onDynamicKinds;

  /// Opaque pack/feature source id — empty means resolve by [pluginId] only.
  String get listSource => (layoutSpec['source'] ?? '').toString().trim();
  String get kindMenuId =>
      (layoutSpec['kindMenu'] ?? layoutSpec['kindTab'] ?? 'kind').toString();
  String get statusTabId =>
      (layoutSpec['statusTab'] ?? 'status').toString();
  String get gridRowId => (layoutSpec['id'] ?? 'grid').toString();

  /// `list` → dense rows; anything else → poster grid.
  String get listStyle =>
      (layoutSpec['style'] ?? 'grid').toString().trim().toLowerCase();

  bool get isDenseList => listStyle == 'list';

  @override
  ConsumerState<CatalogKitListWidget> createState() =>
      _CatalogKitListWidgetState();
}

class _CatalogKitListWidgetState extends ConsumerState<CatalogKitListWidget> {
  final _scroll = ScrollController();
  CatalogKitListSource? _source;

  CatalogKitListSource? _resolveSource() => CatalogHostListRegistry.resolve(
        sourceId: widget.listSource.isEmpty ? null : widget.listSource,
        pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
      );

  @override
  void initState() {
    super.initState();
    _source = _resolveSource();
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
    if (widget.listSource != oldWidget.listSource ||
        widget.pluginId != oldWidget.pluginId) {
      _source = _resolveSource();
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

  double _hoistedTopBarInset(BuildContext context) {
    if (!CatalogKitTopMenuRegistry.hasTopMenu(widget.tabId)) return 0;
    return CatalogKitTopMenuRegistry.bodyTopInset(context, widget.tabId);
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
      final label = widget.listSource.isNotEmpty
          ? widget.listSource
          : (widget.pluginId.isNotEmpty ? widget.pluginId : '(none)');
      return Center(
        child: Text(
          'Unsupported kit.list source: $label',
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

    // Status / Simkl writes re-run the FutureProvider; keep the current grid
    // instead of swapping to the shimmer skeleton (feels like a full reload).
    return pageAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
        if (widget.dynamicKindChips || widget.onDynamicKinds != null) {
          final kinds = <String>{};
          for (final e in page.entriesForKind(null)) {
            if (e.kind.isNotEmpty && e.kind != 'live_match') kinds.add(e.kind);
          }
          final sorted = kinds.toList()..sort();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onDynamicKinds?.call(sorted);
          });
        }
        final entries = page.entriesForKind(kind);
        if (entries.isEmpty) return _emptyState(context, kind: kind);
        final body = widget.isDenseList
            ? _denseList(context, source, entries)
            : _grid(context, source, entries);
        final panel = widget.sidePanel;
        if (panel == null || !widget.isDenseList) return body;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final useSideSplit = wide || ShellTokens.isAndroidTvDevice;
        if (useSideSplit) {
          final panelFlex = ShellTokens.isAndroidTvDevice ? 50 : 40;
          final listFlex = 100 - panelFlex;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: listFlex, child: body),
              Expanded(flex: panelFlex, child: panel),
            ],
          );
        }
        return Stack(
          children: [
            body,
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.92,
                    child: panel,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _denseList(
    BuildContext context,
    CatalogKitListSource source,
    List<CatalogKitListEntry> entries,
  ) {
    final leading = ShellTokens.compactChromeLeadingInset(context);
    final list = ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        leading,
        4 + _hoistedTopBarInset(context),
        ShellTokens.bodyHorizontalPadding,
        shellTvCatalogScrollBottomGap(context),
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final meta = entry.meta;
        final airing = meta.airing == true;
        final selected = widget.selectedEntryId != null &&
            widget.selectedEntryId == meta.id;
        return HubLiveMatchDenseTile(
          title: meta.name,
          meta: hubLiveMatchDenseMetaLine(
            airing: airing,
            startsAt: meta.startsAt,
            badge: meta.badge,
            genres: meta.genres,
          ),
          airing: airing,
          viewers: meta.viewers ?? 0,
          selected: selected,
          index: index,
          playable: true,
          tvTabId: widget.tabId,
          tvRowId: widget.gridRowId,
          onUpEdge: index == 0
              ? () =>
                  _focusRowLast(widget.statusTabId) ||
                  _focusRow(widget.statusTabId, 0) ||
                  _focusRow(widget.kindMenuId, 0)
              : null,
          onRightEdge: selected && widget.sidePanel != null
              ? () {}
              : null,
          onTap: () {
            widget.onEntrySelected?.call(entry);
            source.openEntry(context, entry);
          },
        );
      },
    );
    return TvGrid(
      tabId: widget.tabId,
      rowId: widget.gridRowId,
      sortOrder: widget.tvRowOrder + 2,
      columns: 1,
      itemCount: entries.length,
      onFocusUp: () =>
          _focusRowLast(widget.statusTabId) ||
          _focusRow(widget.statusTabId, 0) ||
          _focusRow(widget.kindMenuId, 0),
      child: list,
    );
  }

  Widget _grid(
    BuildContext context,
    CatalogKitListSource source,
    List<CatalogKitListEntry> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _homeGrid(
          context,
          constraints.maxWidth,
          chromeTop: _hoistedTopBarInset(context),
        );
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
      onTap: () {
        widget.onEntrySelected?.call(entry);
        source.openEntry(context, entry);
      },
    );
  }

  Widget _loadingGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _homeGrid(
          context,
          constraints.maxWidth,
          chromeTop: _hoistedTopBarInset(context),
        );
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
    return Padding(
      padding: EdgeInsets.only(top: _hoistedTopBarInset(context)),
      child: Center(
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

_HomeGrid _homeGrid(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  final cardW = shellMovieCardWidth(context);
  final cardH = shellMovieCardHeight(context);
  final gap = shellMovieCardRowGap(context);
  final leading = ShellTokens.compactChromeLeadingInset(context);
  final trailing = ShellTokens.bodyHorizontalPadding;
  final inner = math.max(0.0, maxWidth - leading - trailing);
  final columns = math.max(1, ((inner + gap) / (cardW + gap)).floor());
  final gridW = columns * cardW + (columns - 1) * gap;
  final rightPad = math.max(trailing, maxWidth - leading - gridW);
  final topPad =
      chromeTop + cardH * (ShellTokens.focusActiveScale - 1) / 2 + 4;
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
