import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/foundation/components/cards/kit_event_card.dart';
import 'package:forja/shared/foundation/components/cards/kit_event_dense_tile.dart';
import 'package:forja/shared/foundation/components/cards/kit_poster_card.dart';
import 'package:forja/shared/foundation/blocks/details/kit_entry_details.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/components/layout/kit_top_menu_registry.dart';
import 'package:forja/shared/foundation/components/layout/kit_types.dart';
import 'package:forja/shared/foundation/components/layout/kit_layout_scope.dart';
import 'package:forja/shared/foundation/components/meta/meta_movie.dart';
import 'package:forja/shared/foundation/services/registry/host_list_registry.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/protocol/protocol.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';
import 'package:forja/shared/foundation/components/layout/kit_panel_host.dart';
import 'package:forja/shared/foundation/components/posters/home_loading_skeleton.dart';
import 'package:rust/rust.dart';

/// Layout widget [`KitTypes.list`] — poster grid or dense list from a
/// registered host list source (opaque `source` id and/or hub [pluginId]).
///
/// When a [KitPanelHost] is registered for [listSource], selection and
/// side panel are owned here (no feature browse shell).
///
/// Pack `open`: `panel` (list + side panel) · `details` (full-page panel host).
class KitListWidget extends ConsumerStatefulWidget {
  const KitListWidget({
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
    this.shellTabVisible = true,
    this.layoutWidgets = const [],
  });

  final String tabId;
  final Map<String, dynamic> layoutSpec;
  final int refreshEpoch;
  final String pluginId;
  final int tvRowOrder;

  /// When set, dense rows highlight this entry id (list+panel).
  final String? selectedEntryId;

  /// Called when a row is activated (before [KitListSource.openEntry]).
  final ValueChanged<KitListEntry>? onEntrySelected;

  /// Optional side panel beside a dense list. When null, kit resolves a
  /// registered [KitPanelHost] for [listSource].
  final Widget? sidePanel;

  /// When true and no layout kind menu, expose unique entry kinds to parent.
  final bool dynamicKindChips;

  final ValueChanged<List<String>>? onDynamicKinds;

  /// Shell tab visibility for panel hosts.
  final bool shellTabVisible;

  /// Full layout tree passed through to [KitPanelHost].
  final List<Map<String, dynamic>> layoutWidgets;

  /// Opaque pack/feature source id — empty means resolve by [pluginId] only.
  String get listSource => (layoutSpec['source'] ?? '').toString().trim();
  String get kindMenuId =>
      (layoutSpec['kindMenu'] ?? layoutSpec['kindTab'] ?? 'kind').toString();
  String get statusTabId =>
      (layoutSpec['statusTab'] ?? 'status').toString();
  String get gridRowId => (layoutSpec['id'] ?? 'grid').toString();

  /// `list` → dense rows; `cards` → landscape live match cards; else poster grid.
  String get listStyle =>
      (layoutSpec['style'] ?? 'grid').toString().trim().toLowerCase();

  bool get isDenseList => listStyle == 'list';

  bool get isMatchCards => listStyle == 'cards';

  /// Pack `open`: `panel` | `details` | empty (panel for dense list, source open for grid).
  String get entryOpen =>
      (layoutSpec['open'] ?? '').toString().trim().toLowerCase();

  bool get opensDetails => entryOpen == 'details';

  bool get opensPanel =>
      entryOpen == 'panel' || (entryOpen.isEmpty && isDenseList);

  @override
  ConsumerState<KitListWidget> createState() =>
      _KitListWidgetState();
}

class _KitListWidgetState extends ConsumerState<KitListWidget> {
  final _scroll = ScrollController();
  KitListSource? _source;
  KitListEntry? _selected;
  List<String> _dynamicKinds = const [];
  String? _kindFilter;
  bool _pendingOpenConsumed = false;

  KitListSource? _resolveSource() => HostListRegistry.resolve(
        sourceId: widget.listSource.isEmpty ? null : widget.listSource,
        pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
      );

  KitPanelHost? get _panelHost {
    final id = widget.listSource;
    if (id.isEmpty) return null;
    return HostListRegistry.resolvePanel(id);
  }

  bool get _autoPanel =>
      widget.sidePanel == null &&
      _panelHost != null &&
      widget.opensPanel &&
      widget.isDenseList;

  bool get _layoutHasCategoryBar {
    var found = false;
    walkKitWidgets(widget.layoutWidgets, (spec) {
      if (found) return;
      final type = KitTypes.normalize(
        (spec['type'] ?? '').toString(),
        spec,
      );
      if (type == KitTypes.categoryBar) found = true;
    });
    return found;
  }

  void _openEntry(BuildContext context, KitListSource source,
      KitListEntry entry) {
    widget.onEntrySelected?.call(entry);
    if (widget.opensDetails && _panelHost != null) {
      final layouts = widget.layoutWidgets.isNotEmpty
          ? widget.layoutWidgets
          : [widget.layoutSpec];
      unawaited(
        KitEntryDetailsPage.open(
          context,
          entry: entry,
          listSourceId: widget.listSource,
          layoutWidgets: layouts,
          refreshEpoch: widget.refreshEpoch,
          shellTabId: widget.tabId,
        ),
      );
      return;
    }
    if (_autoPanel) {
      setState(() => _selected = entry);
      return;
    }
    source.openEntry(context, entry);
  }

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
  void didUpdateWidget(KitListWidget oldWidget) {
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
    if (!KitTopMenuRegistry.hasTopMenu(widget.tabId)) return 0;
    return KitTopMenuRegistry.bodyTopInset(context, widget.tabId);
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

    final scope = KitLayoutScope.maybeOf(context);
    final status =
        scope?.selectedId(widget.statusTabId) ??
        widget.layoutSpec['defaultStatus']?.toString() ??
        'plantowatch';

    source.setupSideEffects(ref, status);
    final pageAsync = source.watchPage(ref, status);

    final catalogMenuId =
        (widget.layoutSpec['catalogMenu'] ?? 'catalog').toString();
    final horizonMenuId =
        (widget.layoutSpec['horizonMenu'] ?? 'horizon').toString();
    if (scope != null) {
      final filters = <String, String>{};
      final catalog = scope.selectedId(catalogMenuId);
      final horizon = scope.selectedId(horizonMenuId);
      if (catalog != null) filters['catalog'] = catalog;
      if (horizon != null) filters['horizon'] = horizon;
      // Kind/sport stays in layout scope only (entriesForKind) — no reload.
      if (filters.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          source.onLayoutFilters(ref, filters);
        });
      }
    }

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
        final wantKinds =
            widget.dynamicKindChips ||
            widget.onDynamicKinds != null ||
            _autoPanel;
        if (wantKinds) {
          final kinds = <String>{};
          for (final e in page.entriesForKind(null)) {
            if (e.kind.isNotEmpty && e.kind != 'live_match') kinds.add(e.kind);
          }
          final sorted = kinds.toList()..sort();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onDynamicKinds?.call(sorted);
            if (!_sameStringList(sorted, _dynamicKinds)) {
              setState(() => _dynamicKinds = sorted);
            }
          });
        }
        final scopeKind = scope?.selectedId(widget.kindMenuId);
        final kind = scopeKind ?? _kindFilter;
        final entries = page.entriesForKind(kind);
        _consumePendingOpen(entries);
        if (entries.isEmpty) return _emptyState(context, kind: kind);
        final selectedId = widget.selectedEntryId ?? _selected?.meta.id;
        final body = widget.isDenseList
            ? _denseList(context, source, entries, selectedId: selectedId)
            : widget.isMatchCards
                ? _matchCards(context, source, entries)
                : _grid(context, source, entries);
        final panel = widget.sidePanel ?? _buildAutoPanel();
        Widget listBody = body;
        if (panel != null && widget.isDenseList) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final useSideSplit = wide || ShellTokens.isAndroidTvDevice;
          if (useSideSplit) {
            final panelFlex = ShellTokens.isAndroidTvDevice ? 50 : 40;
            final listFlex = 100 - panelFlex;
            listBody = Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: listFlex, child: body),
                Expanded(flex: panelFlex, child: panel),
              ],
            );
          } else {
            listBody = Stack(
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
          }
        }
        final chips = _dynamicKinds;
        if (_layoutHasCategoryBar || !_autoPanel || chips.length <= 1) {
          return listBody;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ForjaChipRow(
              tabId: widget.tabId,
              rowId: widget.kindMenuId,
              items: [
                for (final id in ['all', ...chips])
                  (
                    id: id,
                    label: id == 'all'
                        ? 'All'
                        : (id.isEmpty
                            ? id
                            : '${id[0].toUpperCase()}${id.substring(1)}'),
                  ),
              ],
              selectedId: kind ?? 'all',
              onSelect: (id) {
                setState(() => _kindFilter = id == 'all' ? null : id);
                scope?.onSelect(widget.kindMenuId, id, toggle: false);
              },
            ),
            Expanded(child: listBody),
          ],
        );
      },
    );
  }

  void _consumePendingOpen(List<KitListEntry> entries) {
    if (_pendingOpenConsumed || entries.isEmpty) return;
    final pending = _source?.takePendingSelectEntryId();
    if (pending == null || pending.isEmpty) {
      _pendingOpenConsumed = true;
      return;
    }
    KitListEntry? hit;
    for (final e in entries) {
      final id = e.meta.id;
      final openId = e.meta.open?.id ?? '';
      if (id == pending || openId == pending) {
        hit = e;
        break;
      }
    }
    _pendingOpenConsumed = true;
    if (hit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_autoPanel) {
        setState(() => _selected = hit);
        widget.onEntrySelected?.call(hit!);
        return;
      }
      _openEntry(context, _source!, hit!);
    });
  }

  Widget? _buildAutoPanel() {
    if (!_autoPanel) return null;
    final entry = _selected;
    final host = _panelHost;
    if (entry == null || host == null) return null;
    final layouts = widget.layoutWidgets.isNotEmpty
        ? widget.layoutWidgets
        : [widget.layoutSpec];
    return host.buildSidePanel(
      context: context,
      entry: entry,
      layoutWidgets: layouts,
      shellTabVisible: widget.shellTabVisible,
      refreshEpoch: widget.refreshEpoch,
      onClosed: () => setState(() => _selected = null),
    );
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _denseList(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries, {
    String? selectedId,
  }) {
    final leading = ShellTokens.compactChromeLeadingInset(context);
    final panelActive = widget.sidePanel != null || _autoPanel;
    final list = ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        leading,
        4 + _hoistedTopBarInset(context),
        ShellTokens.bodyHorizontalPadding,
        shellTvKitScrollBottomGap(context),
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
        final selected = selectedId != null && selectedId == meta.id;
        return KitEventDenseTile(
          title: meta.name,
          meta: kitEventDenseMetaLine(
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
          onRightEdge: selected && panelActive ? () {} : null,
          onTap: () => _openEntry(context, source, entry),
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

  Widget _matchCards(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _liveCardsGrid(
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
              _focusRowLast(widget.kindMenuId) ||
              _focusRow(widget.kindMenuId, 0),
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
                  shellTvKitScrollBottomGap(context),
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid.columns,
                    mainAxisSpacing: grid.gap,
                    crossAxisSpacing: grid.gap,
                    mainAxisExtent: grid.cardH,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = entries[index];
                    final match = MatchEvent.fromLegacyRow(entry.legacyRow);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: KitEventCard(
                        match: match,
                        gridIndex: index,
                        gridColumns: grid.columns,
                        tvTabId: widget.tabId,
                        tvRowId: widget.gridRowId,
                        onUpEdge: index < grid.columns
                            ? () =>
                                _focusRowLast(widget.kindMenuId) ||
                                _focusRow(widget.kindMenuId, 0)
                            : null,
                        onTap: () => _openEntry(context, source, entry),
                      ),
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

  Widget _grid(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries,
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
                  shellTvKitScrollBottomGap(context),
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

  KitPosterCard _card(
    BuildContext context,
    KitListSource source,
    KitListEntry entry,
    int index, {
    required _HomeGrid grid,
  }) {
    final meta = entry.meta;
    final status =
        KitLayoutScope.maybeOf(context)?.selectedId(widget.statusTabId) ??
        'plantowatch';
    return KitPosterCard(
      imageUrl: kitListPosterUrl(meta),
      title: meta.name,
      subtitle: kitPosterSubtitle(meta),
      rating: (meta.rating ?? 0) > 0 ? meta.rating : null,
      badge: kitPosterBadge(meta),
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
      onTap: () => _openEntry(context, source, entry),
    );
  }

  Widget _loadingGrid(BuildContext context) {
    if (widget.isDenseList) return _loadingDenseList(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = widget.isMatchCards
            ? _liveCardsGrid(
                context,
                constraints.maxWidth,
                chromeTop: _hoistedTopBarInset(context),
              )
            : _homeGrid(
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
            gridDelegate: widget.isMatchCards
                ? SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid.columns,
                    mainAxisSpacing: grid.gap,
                    crossAxisSpacing: grid.gap,
                    mainAxisExtent: grid.cardH,
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget _loadingDenseList(BuildContext context) {
    final leading = ShellTokens.compactChromeLeadingInset(context);
    // Vary bar widths so shimmer rows don't look like one solid block.
    const titleWidths = <double>[220, 180, 260, 200, 240, 170, 210, 190];
    const metaWidths = <double>[120, 90, 140, 110, 100, 130, 95, 125];
    return homeLoadingShimmer(
      ListView.separated(
        padding: EdgeInsets.fromLTRB(
          leading,
          4 + _hoistedTopBarInset(context),
          ShellTokens.bodyHorizontalPadding,
          shellTvKitScrollBottomGap(context),
        ),
        itemCount: titleWidths.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
        ),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    homeTitleBarSkeleton(
                      context,
                      width: titleWidths[index % titleWidths.length],
                      height: 14,
                    ),
                    const SizedBox(height: 6),
                    homeTitleBarSkeleton(
                      context,
                      width: metaWidths[index % metaWidths.length],
                      height: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, {String? kind}) {
    final filtered = kind != null && kind.isNotEmpty && kind != 'all';
    String? kindLabel;
    if (filtered) {
      final kindSpec =
          KitLayoutScope.maybeOf(context)?.widgetSpecFor(widget.kindMenuId);
      if (kindSpec != null) {
        for (final tab in kitItemsFromSpec(kindSpec)) {
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

_HomeGrid _liveCardsGrid(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  final cardW = KitEventCard.cardWidth(context);
  final cardH = KitEventCard.cardHeight(context);
  final gap = KitEventCard.gridGap(context);
  final leading = shellHomeSectionHorizontalPadding(context);
  final trailing = leading;
  final inner = math.max(0.0, maxWidth - leading - trailing);
  final columns =
      math.max(1, ((inner + gap) / (cardW + gap)).floor()).clamp(1, 8);
  final gridW = columns * cardW + (columns - 1) * gap;
  final rightPad = math.max(trailing, maxWidth - leading - gridW);
  final topPad = chromeTop + 4;
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

String kitListPosterUrl(MetaItem meta) {
  final poster = meta.poster;
  if (poster.isEmpty) return '';
  if (poster.startsWith('http')) return poster;
  if (poster.startsWith('/')) return TmdbApi.getImageUrl(poster);
  return poster;
}

/// @deprecated Use [kitListPosterUrl].
String myListPosterUrl(MetaItem meta) => kitListPosterUrl(meta);
