import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/shell/kit_event_dense_tile.dart';
import 'package:forja/shared/shell/kit_poster_card.dart';
import 'package:forja/shared/player/details/kit_entry_details.dart';
import 'package:forja/shared/engine/hub/kit_top_menu_registry.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja/shared/engine/hub/meta_movie.dart';
import 'package:forja/shared/engine/hub/host_list_registry.dart';
import 'package:forja/shared/shell/kit_event_card.dart';
import 'package:forja/shared/engine/hub/kit_event_paint.dart';
import 'package:forja/shared/engine/hub/kit_list_source.dart';
import 'package:forja/shared/engine/hub/plugin_hub_feed_source.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/shell/forja_chip_row.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja/shared/engine/hub/kit_feed_chrome.dart';
import 'package:forja/shared/shell/focus_edge.dart';
import 'package:forja/shared/engine/hub/kit_list_event_query.dart';
import 'package:forja/shared/engine/hub/kit_list_open_mode.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/shell_tv_focus.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/engine/hub/kit_panel_host.dart';
import 'package:forja/shared/player/sources/kit_sources_panel.dart';
import 'package:forja/shared/shell/home_loading_skeleton.dart';
import 'package:forja_foundation/components/skeleton.dart';
import 'package:forja_foundation/widgets/chrome/catalog_list.dart';

/// Layout widget [`LayoutTypes.list`] — poster grid or dense list from a
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

  String? get focusLeftId {
    final raw = (layoutSpec['focusLeft'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  String? get focusRightId {
    final raw = (layoutSpec['focusRight'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  /// Pack layout defaults (overridden at runtime for `live_schedule` / openSetting).
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

  String? get openSettingId {
    final raw = (layoutSpec['openSetting'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

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

  /// Runtime style / open (prefs + pack settings override layoutSpec).
  String _effectiveStyle = 'grid';
  String _effectiveOpen = '';

  bool get _isDenseList => _effectiveStyle == 'list';
  bool get _isMatchCards => _effectiveStyle == 'cards';
  bool get _opensDetails => _effectiveOpen == 'details';
  bool get _opensPanel =>
      _effectiveOpen == 'panel' ||
      (_effectiveOpen.isEmpty && _isDenseList);

  void _resolveEffectiveLayout(WidgetRef ref) {
    final key = kitChromeKey(pluginId: widget.pluginId);
    final override = key.isEmpty
        ? ''
        : ref.watch(kitListStyleOverrideProvider(key)).trim().toLowerCase();
    _effectiveStyle = (override.isEmpty ? widget.listStyle : override)
        .trim()
        .toLowerCase();
    if (_effectiveStyle.isEmpty) _effectiveStyle = 'grid';

    final openSetting = widget.openSettingId;
    if (openSetting != null && widget.pluginId.trim().isNotEmpty) {
      final async = ref.watch(
        kitListOpenModeProvider((
          pluginId: widget.pluginId,
          fieldId: openSetting,
        )),
      );
      final fromPack = (async.asData?.value ?? widget.entryOpen)
          .trim()
          .toLowerCase();
      _effectiveOpen = fromPack.isEmpty ? kKitListOpenModeDefault : fromPack;
    } else {
      _effectiveOpen = widget.entryOpen;
    }

    if (_opensDetails && _selected != null) {
      _selected = null;
    }
  }

  KitListSource? _resolveSource() {
    final registered = HostListRegistry.resolve(
      sourceId: widget.listSource.isEmpty ? null : widget.listSource,
      pluginId: widget.pluginId.isEmpty ? null : widget.pluginId,
    );
    if (registered != null) return registered;
    final pluginId = widget.pluginId.trim();
    if (pluginId.isEmpty) return null;
    // Pack-owned list feed — no host product registration required.
    return PluginHubFeedListSource(pluginId);
  }

  KitPanelHost? get _panelHost {
    final id = widget.listSource;
    if (id.isEmpty) return null;
    return HostListRegistry.resolvePanel(id);
  }

  bool get _autoPanel =>
      widget.sidePanel == null &&
      _panelHost != null &&
      _opensPanel;

  bool get _layoutHasCategoryBar {
    var found = false;
    walkLayoutWidgets(widget.layoutWidgets, (spec) {
      if (found) return;
      final type = LayoutTypes.normalize(
        (spec['type'] ?? '').toString(),
        spec,
      );
      if (type == LayoutTypes.categoryBar) found = true;
    });
    return found;
  }

  void _openEntry(BuildContext context, KitListSource source,
      KitListEntry entry) {
    widget.onEntrySelected?.call(entry);
    if (_opensDetails && _panelHost != null) {
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
      _claimPanelProvidersFocus();
      return;
    }
    source.openEntry(context, entry);
  }

  /// TV: after opening a match, land D-pad on Providers in the side panel.
  void _claimPanelProvidersFocus() {
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
    KitSourcesPanel.claimProvidersFocus();
  }

  VoidCallback? _packFocusLeft() =>
      kitFocusSide(widget.tabId, widget.focusLeftId);

  VoidCallback? _listRightEdge({
    required bool selected,
    required bool panelActive,
    required bool atRightColumn,
  }) {
    final named = kitFocusSide(widget.tabId, widget.focusRightId);
    if (named != null) {
      if (panelActive) return selected ? named : null;
      return atRightColumn ? named : null;
    }
    if (selected && panelActive) return _claimPanelProvidersFocus;
    return null;
  }

  void _focusSelectedEvent() {
    final handle =
        ShellTvFocusCoordinator.rowHandle(widget.tabId, widget.gridRowId);
    if (handle == null || handle.itemCount <= 0) return;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    ShellTvFocusCoordinator.focusRowItem(widget.tabId, widget.gridRowId, idx);
  }

  @override
  void initState() {
    super.initState();
    _source = _resolveSource();
    _syncScrollIntoView();
    TvHeroActions.bind(
      widget.tabId,
      defaultFocus: _defaultFocusNode,
      enterFromNavFocus: _focusEntry,
      restoreFocus: _landContentFocus,
    );
  }

  @override
  void didUpdateWidget(KitListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabId != oldWidget.tabId ||
        widget.gridRowId != oldWidget.gridRowId) {
      ShellTvFocusCoordinator.setRowScrollIntoView(
        oldWidget.tabId,
        oldWidget.gridRowId,
        null,
      );
      _syncScrollIntoView();
    }
    if (widget.listSource != oldWidget.listSource ||
        widget.pluginId != oldWidget.pluginId) {
      _source = _resolveSource();
    }
    if (widget.refreshEpoch != oldWidget.refreshEpoch) {
      // Invalidate after this frame — mutating providers in didUpdateWidget
      // throws and aborts the rebuild (Live Sports skeleton stutter).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _source?.invalidateOnRefresh(ref);
      });
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.setRowScrollIntoView(
      widget.tabId,
      widget.gridRowId,
      null,
    );
    _scroll.dispose();
    ShellTvFocusCoordinator.clearTab(widget.tabId);
    super.dispose();
  }

  void _syncScrollIntoView() {
    ShellTvFocusCoordinator.setRowScrollIntoView(
      widget.tabId,
      widget.gridRowId,
      _scrollGridIndexIntoView,
    );
  }

  /// Mount a lazy schedule tile before D-pad restore (shelf / Portals ↓).
  void _scrollGridIndexIntoView(int index) {
    if (!_scroll.hasClients || index < 0) return;
    final node = ShellTvFocusCoordinator.itemNode(
      widget.tabId,
      widget.gridRowId,
      index,
    );
    final ctx = node?.context;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: Duration.zero,
      );
      return;
    }
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final estExtent = _isDenseList
        ? 56.0
        : _isMatchCards
            ? 160.0
            : 220.0;
    final cols = _isDenseList
        ? 1
        : math.max(1, (_scroll.position.viewportDimension / 180).floor());
    final row = index ~/ cols;
    final target = (row * estExtent).clamp(0.0, max);
    if ((_scroll.offset - target).abs() > 1) {
      _scroll.jumpTo(target);
    }
  }

  bool _focusRow(String rowId, int index) =>
      ShellTvFocusCoordinator.focusRowItem(widget.tabId, rowId, index);

  bool _focusRowLast(String rowId) {
    final handle = ShellTvFocusCoordinator.rowHandle(widget.tabId, rowId);
    if (handle == null || handle.itemCount <= 0) return false;
    final idx = handle.lastFocusedIndex.clamp(0, handle.itemCount - 1);
    return _focusRow(rowId, idx);
  }

  /// Category bar → status tabs → first list/grid item (never top-bar Catalog).
  bool _landContentFocus() {
    if (_focusRow(widget.kindMenuId, 0)) return true;
    if (_focusRow(widget.statusTabId, 0)) return true;
    return _focusRow(widget.gridRowId, 0);
  }

  FocusNode? _defaultFocusNode() {
    return ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.kindMenuId,
          0,
        ) ??
        ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.statusTabId,
          0,
        ) ??
        ShellTvFocusCoordinator.itemNode(
          widget.tabId,
          widget.gridRowId,
          0,
        );
  }

  double _hoistedTopBarInset(BuildContext context) {
    if (!KitTopMenuRegistry.hasTopMenu(widget.tabId)) return 0;
    return KitTopMenuRegistry.bodyTopInset(context, widget.tabId);
  }

  void _focusEntry() {
    if (_landContentFocus()) return;
    void retry({required int left}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ShellTvFocus.currentNavTabId != widget.tabId) return;
        if (_landContentFocus() || left <= 0) return;
        retry(left: left - 1);
      });
    }

    retry(left: 5);
  }

  @override
  Widget build(BuildContext context) {
    _resolveEffectiveLayout(ref);
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

    final scope = LayoutScope.maybeOf(context);
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
          return _scheduleLoadingSkeleton(context);
        }
        final wantKinds =
            widget.dynamicKindChips ||
            widget.onDynamicKinds != null ||
            _autoPanel;
        if (wantKinds) {
          final kinds = <String>{};
          for (final e in page.entriesForKind(null)) {
            if (e.kind.isEmpty) continue;
            final omit = source.omitKindIds.contains(e.kind);
            if (!omit) kinds.add(e.kind);
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
        final chromeKey = kitChromeKey(pluginId: widget.pluginId);
        final eventQuery = chromeKey.isEmpty
            ? ''
            : ref.watch(kitListEventQueryProvider(chromeKey));
        final rawEntries = page.entriesForKind(kind);
        final entries = kitListFilterEntries(rawEntries, eventQuery);
        _consumePendingOpen(entries);
        if (entries.isEmpty) {
          return _emptyState(
            context,
            kind: kind,
            loadingRemote: page.loadingRemote,
            eventQuery: eventQuery,
          );
        }
        final selectedId = widget.selectedEntryId ?? _selected?.meta.id;
        final body = _isDenseList
            ? _denseList(context, source, entries, selectedId: selectedId)
            : _isMatchCards
                ? _matchCards(
                    context,
                    source,
                    entries,
                    selectedId: selectedId,
                  )
                : _grid(context, source, entries);
        final panel = widget.sidePanel ?? _buildAutoPanel();
        final sidePanelOpen = panel != null && _opensPanel;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final sideSplit = wide || ShellTokens.isAndroidTvDevice;
        final panelFlex = ShellTokens.isAndroidTvDevice ? 50 : 40;
        final listFlex = 100 - panelFlex;
        final chips = _dynamicKinds;
        final showChips =
            !_layoutHasCategoryBar && _autoPanel && chips.length > 1;
        return CatalogList(
          body: body,
          sidePanel: panel,
          sidePanelOpen: sidePanelOpen,
          sideSplit: sideSplit,
          listFlex: listFlex,
          panelFlex: panelFlex,
          panelWidth: MediaQuery.sizeOf(context).width * 0.92,
          onDismissSidePanel: () {
            if (!mounted) return;
            setState(() => _selected = null);
          },
          header: showChips
              ? ForjaChipRow(
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
                )
              : null,
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
      _claimPanelProvidersFocus();
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
      onPanelLeftEdge: () => _focusSelectedEvent(),
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
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
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
          viewers: KitEventPaint.fromEntry(entry).viewers,
          selected: selected,
          index: index,
          playable: true,
          tvTabId: widget.tabId,
          tvRowId: widget.gridRowId,
          onUpEdge: index == 0
              ? () =>
                  _focusRowLast(widget.kindMenuId) ||
                  _focusRow(widget.kindMenuId, 0)
              : null,
          onLeftEdge: _packFocusLeft(),
          onRightEdge: _listRightEdge(
            selected: selected,
            panelActive: panelActive,
            atRightColumn: true,
          ),
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
          _focusRowLast(widget.kindMenuId) ||
          _focusRow(widget.kindMenuId, 0),
      child: _kitListScrollbar(
        context,
        interactive: !tv,
        child: list,
      ),
    );
  }

  Widget _matchCards(
    BuildContext context,
    KitListSource source,
    List<KitListEntry> entries, {
    String? selectedId,
  }) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final panelActive = widget.sidePanel != null || _autoPanel;
    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _eventCardsGrid(
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
          child: _kitListScrollbar(
            context,
            interactive: !tv,
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = entries[index];
                        final selected =
                            selectedId != null && selectedId == entry.meta.id;
                        return KitEventCard(
                          event: KitEventPaint.fromEntry(entry),
                          width: grid.cardW,
                          height: grid.cardH,
                          gridIndex: index,
                          gridColumns: grid.columns,
                          selected: selected,
                          tvTabId: widget.tabId,
                          tvRowId: widget.gridRowId,
                          onUpEdge: index < grid.columns
                              ? () =>
                                  _focusRowLast(widget.kindMenuId) ||
                                  _focusRow(widget.kindMenuId, 0)
                              : null,
                          onLeftEdge: index % grid.columns == 0
                              ? _packFocusLeft()
                              : null,
                          onRightEdge: _listRightEdge(
                            selected: selected,
                            panelActive: panelActive,
                            atRightColumn: index % grid.columns ==
                                    grid.columns - 1 ||
                                index == entries.length - 1,
                          ),
                          onTap: () => _openEntry(context, source, entry),
                        );
                      },
                      childCount: entries.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Always-visible thumb so long Live Sports schedules show scroll position.
  Widget _kitListScrollbar(
    BuildContext context, {
    required bool interactive,
    required Widget child,
  }) {
    return RawScrollbar(
      controller: _scroll,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: interactive,
      thickness: 4,
      radius: const Radius.circular(2),
      mainAxisMargin: 6,
      crossAxisMargin: 2,
      thumbColor: ForjaShellColors.brandGreen.withValues(alpha: 0.55),
      trackColor: Colors.white.withValues(alpha: 0.08),
      trackBorderColor: Colors.transparent,
      child: child,
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
        LayoutScope.maybeOf(context)?.selectedId(widget.statusTabId) ??
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
      onLeftEdge:
          index % grid.columns == 0 ? _packFocusLeft() : null,
      onRightEdge: _listRightEdge(
        selected: false,
        panelActive: false,
        atRightColumn: index % grid.columns == grid.columns - 1,
      ),
      onTap: () => _openEntry(context, source, entry),
    );
  }

  Widget _loadingGrid(BuildContext context) {
    if (_isDenseList || _isMatchCards) {
      return _scheduleLoadingSkeleton(context);
    }
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

  /// Live schedule / cards — skeleton rows (progress copy lives in top bar).
  Widget _scheduleLoadingSkeleton(BuildContext context) {
    if (_isMatchCards) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final grid = _eventCardsGrid(
            context,
            constraints.maxWidth,
            chromeTop: _hoistedTopBarInset(context),
          );
          return homeLoadingShimmer(
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
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
    final leading = ShellTokens.compactChromeLeadingInset(context);
    return homeLoadingShimmer(
      ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          leading,
          4 + _hoistedTopBarInset(context),
          ShellTokens.bodyHorizontalPadding,
          shellTvKitScrollBottomGap(context),
        ),
        itemCount: 10,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
        ),
        itemBuilder: (context, _) => const _KitDenseRowSkeleton(),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    String? kind,
    bool loadingRemote = false,
    String eventQuery = '',
  }) {
    if (loadingRemote) {
      return _scheduleLoadingSkeleton(context);
    }
    final searchQ = eventQuery.trim();
    final searching = searchQ.isNotEmpty;
    final filtered = kind != null && kind.isNotEmpty && kind != 'all';
    String? kindLabel;
    if (filtered) {
      final kindSpec =
          LayoutScope.maybeOf(context)?.widgetSpecFor(widget.kindMenuId);
      if (kindSpec != null) {
        for (final tab in layoutItemsFromSpec(kindSpec)) {
          if (tab.id == kind) kindLabel = tab.label;
        }
      }
    }
    final isLiveSchedule = _isDenseList || _isMatchCards;
    final title = searching
        ? 'No matches for “$searchQ”'
        : filtered && kindLabel != null
            ? 'Nothing in $kindLabel'
            : isLiveSchedule
                ? 'No matches'
                : 'Nothing in this list';
    final subtitle = searching
        ? 'Clear search or try another team / event name'
        : filtered
            ? 'Tap a kind tab again to show everything'
            : isLiveSchedule
                ? 'Try Catalog → All, a wider Schedule window, or Refresh'
                : 'Tap + on a title to set Plan to Watch / Watching / On Hold / Completed / Dropped';
    return Padding(
      padding: EdgeInsets.only(top: _hoistedTopBarInset(context)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searching
                    ? Icons.search_off_rounded
                    : isLiveSchedule
                        ? Icons.sports_rounded
                        : Icons.bookmark_border_rounded,
                size: 40,
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
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

_HomeGrid _eventCardsGrid(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  final minW = KitEventCard.cardWidth(context);
  final minH = KitEventCard.cardHeight(context);
  final gap = KitEventCard.gridGap(context);
  final pad = shellHomeSectionHorizontalPadding(context);
  final inner = math.max(0.0, maxWidth - pad * 2);
  final columns =
      math.max(1, ((inner + gap) / (minW + gap)).floor()).clamp(1, 8);
  final cardW = columns <= 1 ? inner : (inner - (columns - 1) * gap) / columns;
  final cardH = minW > 0 ? minH * (cardW / minW) : minH;
  return _HomeGrid(
    columns: columns,
    cardW: cardW,
    cardH: cardH,
    gap: gap,
    leading: pad,
    rightPad: pad,
    topPad: chromeTop + 4,
  );
}

_HomeGrid _homeGrid(
  BuildContext context,
  double maxWidth, {
  double chromeTop = 0,
}) {
  final cardW = shellPosterCardWidth(context);
  final cardH = shellPosterCardHeight(context);
  final gap = shellPosterCardRowGap(context);
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

String kitListPosterUrl(MetaItem meta) {
  final poster = meta.poster;
  if (poster.isEmpty) return '';
  return resolveAbsoluteCoverUrl(poster);
}

/// Placeholder dense schedule row while live catalogs scrape.
class _KitDenseRowSkeleton extends StatelessWidget {
  const _KitDenseRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Skeleton(
            width: 8,
            height: 8,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 12, width: double.infinity),
                SizedBox(height: 6),
                Skeleton(height: 10, width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
