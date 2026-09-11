import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/host/kit/kit_sources_live_tv_browse.dart';
import 'package:forja/shared/host/kit/kit_panel_tabs.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shared/host/kit/hero_pill_buttons.dart';
import 'package:forja/shared/player/details/sources_panel_tv.dart';
import 'package:forja/shared/player/sources/torrent_source_tiles.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';

/// Opaque tab for [KitSourcesPanel].
@immutable
class KitSourcesTab {
  const KitSourcesTab({
    required this.id,
    required this.label,
    this.icon = '',
  });

  final String id;
  final String label;
  final String icon;
}

/// Opaque row for [KitSourcesPanel].
@immutable
class KitSourcesRow {
  const KitSourcesRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.footer,
    this.badges = const [],
    this.viewerCount,
    this.payload,
    this.onHoverProbe,
    this.probeHealthCache,
  });

  final String id;
  final String title;
  final String? subtitle;
  /// Right-side muted text (e.g. embed host).
  final String? footer;
  final List<String> badges;
  final int? viewerCount;

  /// Opaque play/resolve payload (feature/service owned).
  final Object? payload;

  final Future<bool> Function()? onHoverProbe;
  final bool? probeHealthCache;
}

/// Pack-agnostic sources side panel (tabs + rows + reload/close).
///
/// Features wire load/play via callbacks. Kit never knows pack names.
///
/// When the active tab is in [browseCategoryTabIds], the body uses an IPTV-style
/// Categories rail + optional channel search (Live TV chrome).
class KitSourcesPanel extends StatefulWidget {
  const KitSourcesPanel({
    super.key,
    required this.title,
    required this.tabs,
    required this.loadTab,
    required this.onPlayRow,
    this.subtitle,
    this.initialTabId,
    this.onClosed,
    this.tvTabId,
    this.listRowId = SourcesPanelTv.listRowId,
    this.tabsRowId = SourcesPanelTv.kindRowId,
    this.embedded = false,
    this.showTabs = true,
    this.onTabsLeftEdge,
    this.browseCategoryTabIds = const {},
    this.channelQuery,
    this.onChannelQueryChanged,
    this.showInlineSearch = true,
    this.onLoadingChanged,
    this.reloadNonce = 0,
  });

  final String title;
  final String? subtitle;
  final List<KitSourcesTab> tabs;
  final String? initialTabId;

  /// Load rows for a tab id. Called on first select and on reload.
  /// When [force] is true, skip warm caches and rediscover from scratch.
  final Future<List<KitSourcesRow>> Function(
    String tabId, {
    void Function(List<KitSourcesRow> rows)? onPartial,
    bool force,
  }) loadTab;

  final Future<void> Function(KitSourcesRow row) onPlayRow;
  final VoidCallback? onClosed;

  final String? tvTabId;
  final String listRowId;
  final String tabsRowId;

  /// Hero details — hide title/close chrome (tabs optional via [showTabs]).
  final bool embedded;

  /// When false, only the list body is shown (parent owns tab chrome).
  final bool showTabs;

  /// TV: ← from Providers / Live TV (and stream rows) — e.g. back to match list.
  final VoidCallback? onTabsLeftEdge;

  /// Tabs that get Categories rail + channel search filtering.
  final Set<String> browseCategoryTabIds;

  /// External channel query (e.g. cards hero owns search). When null, panel
  /// keeps its own query when [showInlineSearch] is true.
  final String? channelQuery;

  /// Called when the panel's expanding search changes the query.
  final ValueChanged<String>? onChannelQueryChanged;

  /// Show expanding search next to tabs (side panel) when browse tab active.
  /// Set false when the parent owns search chrome (cards hero).
  final bool showInlineSearch;

  /// Fires when the active tab's load starts/ends (progressive discover).
  final ValueChanged<bool>? onLoadingChanged;

  /// Parent bumps this to force-reload the active tab (embedded details chrome).
  final int reloadNonce;

  /// Put D-pad on the first tab (Providers). Retries while nodes mount.
  static void claimProvidersFocus({int maxTries = 24}) {
    SourcesPanelTv.focusKindItem(maxTries: maxTries);
  }

  @override
  State<KitSourcesPanel> createState() => _KitSourcesPanelState();
}

class _KitSourcesPanelState extends State<KitSourcesPanel> {
  late String _tabId;
  final Map<String, List<KitSourcesRow>> _rowsByTab = {};
  final Map<String, bool> _loadingByTab = {};
  final Map<String, String?> _errorByTab = {};
  final ScrollController _listScroll = ScrollController();
  int _loadGen = 0;
  String _internalQuery = '';
  String _selectedCategoryKey = kKitSourcesCategoryAll;

  bool get _browseActive =>
      widget.browseCategoryTabIds.contains(_tabId);

  String get _effectiveQuery => widget.channelQuery ?? _internalQuery;

  @override
  void initState() {
    super.initState();
    _tabId = widget.initialTabId ??
        (widget.tabs.isNotEmpty ? widget.tabs.first.id : '');
    if (widget.channelQuery != null) {
      _internalQuery = widget.channelQuery!;
    }
    if (_tabId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensureLoaded(_tabId));
      });
    }
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(KitSourcesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.subtitle != widget.subtitle) {
      _rowsByTab.clear();
      _errorByTab.clear();
      if (_tabId.isNotEmpty) unawaited(_ensureLoaded(_tabId, force: true));
    }
    if (widget.reloadNonce != oldWidget.reloadNonce &&
        widget.reloadNonce != 0) {
      if (_tabId.isNotEmpty) unawaited(_ensureLoaded(_tabId, force: true));
    }
    if (widget.initialTabId != null &&
        widget.initialTabId != oldWidget.initialTabId &&
        widget.initialTabId != _tabId) {
      _selectTab(widget.initialTabId!);
    }
    if (widget.channelQuery != null &&
        widget.channelQuery != oldWidget.channelQuery) {
      _internalQuery = widget.channelQuery!;
    }
  }

  Future<void> _ensureLoaded(String tabId, {bool force = false}) async {
    if (tabId.isEmpty) return;
    if (!force && _rowsByTab.containsKey(tabId) && _loadingByTab[tabId] != true) {
      _emitLoading(false);
      return;
    }
    final gen = ++_loadGen;
    setState(() {
      _loadingByTab[tabId] = true;
      _errorByTab[tabId] = null;
      if (force) _rowsByTab.remove(tabId);
    });
    _emitLoading(tabId == _tabId);
    try {
      final rows = await widget.loadTab(
        tabId,
        force: force,
        onPartial: (partial) {
          if (!mounted || gen != _loadGen) return;
          setState(() {
            _rowsByTab[tabId] = partial;
            if (widget.browseCategoryTabIds.contains(tabId)) {
              _selectedCategoryKey = kKitSourcesCategoryAll;
            }
          });
        },
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rowsByTab[tabId] = rows;
        _loadingByTab[tabId] = false;
        if (widget.browseCategoryTabIds.contains(tabId)) {
          _selectedCategoryKey = kKitSourcesCategoryAll;
        }
      });
      _emitLoading(false);
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _errorByTab[tabId] = e.toString();
        _loadingByTab[tabId] = false;
        _rowsByTab[tabId] = const [];
      });
      _emitLoading(false);
    }
  }

  void _emitLoading(bool loading) {
    widget.onLoadingChanged?.call(loading);
  }

  void _selectTab(String id) {
    if (id == _tabId) return;
    setState(() {
      _tabId = id;
      if (!widget.browseCategoryTabIds.contains(id)) {
        _internalQuery = '';
        _selectedCategoryKey = kKitSourcesCategoryAll;
      } else {
        _selectedCategoryKey = kKitSourcesCategoryAll;
      }
    });
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
    _emitLoading(_loadingByTab[id] == true);
    unawaited(_ensureLoaded(id));
  }

  /// Always-visible thumb so long Providers / Live TV lists show scroll position.
  Widget _streamListScrollbar({
    required bool interactive,
    required Widget child,
  }) {
    return RawScrollbar(
      controller: _listScroll,
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

  void _onQueryChanged(String next) {
    if (next == _effectiveQuery) return;
    setState(() => _internalQuery = next);
    widget.onChannelQueryChanged?.call(next);
  }

  String? _effectiveTvTabId(BuildContext context) {
    if (widget.tvTabId != null) return widget.tvTabId;
    if (SourcesPanelTv.isTv(context)) return SourcesPanelTv.tabId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingByTab[_tabId] == true;
    final error = _errorByTab[_tabId];
    final rows = _rowsByTab[_tabId] ?? const [];

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) _header(context),
        if (widget.showTabs && widget.tabs.length > 1) _tabs(context),
        Expanded(
          child: _body(context, loading: loading, error: error, rows: rows),
        ),
      ],
    );
    // Hero page paints [KitHeroContentScrim] edge-to-edge; no nested panel scrim.
    return column;
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: () => unawaited(_ensureLoaded(_tabId, force: true)),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: ForjaShellColors.textSecondary,
          ),
          if (widget.onClosed != null)
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClosed,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: ForjaShellColors.textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final tvTabId = _effectiveTvTabId(context);
    final showSearch =
        widget.showInlineSearch && _browseActive;
    final loading = _loadingByTab[_tabId] == true;
    final choice = Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(
            child: HeroPillSegmentedChoice<String>(
              selected: _tabId,
              onSelected: _selectTab,
              tvTabId: tvTabId,
              tvRowId: widget.tabsRowId,
              tvItemIndexStart: 0,
              onLeftEdge: widget.onTabsLeftEdge,
              onDownEdge: tvTabId != null
                  ? () => SourcesPanelTv.focusListItem(index: 0)
                  : null,
              segments: [
                for (final tab in widget.tabs)
                  HeroPillSegment(
                    value: tab.id,
                    label: tab.label,
                    icon: kitPanelTabIcon(tab.icon),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (showSearch)
            KitSourcesExpandingSearch(
              query: _effectiveQuery,
              onQueryChanged: _onQueryChanged,
            ),
          if (loading) ...[
            if (showSearch) const SizedBox(width: 10),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ForjaShellColors.sectionAccent,
              ),
            ),
          ],
        ],
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: choice,
    );
    if (tvTabId == null || widget.tabs.isEmpty) return padded;
    return TvKitRow(
      tabId: tvTabId,
      rowId: widget.tabsRowId,
      sortOrder: SourcesPanelTv.kindSort,
      itemCount: widget.tabs.length,
      onFocusDown: () => SourcesPanelTv.focusListItem(index: 0),
      child: padded,
    );
  }

  Widget _body(
    BuildContext context, {
    required bool loading,
    required String? error,
    required List<KitSourcesRow> rows,
  }) {
    if (loading && rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent),
      );
    }
    if (error != null && rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: ForjaShellColors.textSecondary),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No sources',
          style: TextStyle(color: ForjaShellColors.textSecondary),
        ),
      );
    }
    if (_browseActive) {
      return _categoryBrowse(context, rows);
    }
    // Hero details (embedded): 2-col stream grid on wide — matches old live
    // match details. Side panel stays single-column ListView.
    if (widget.embedded) {
      return _embeddedSourcesGrid(context, rows);
    }
    return _sidePanelList(context, rows);
  }

  String _effectiveCategoryKey(List<KitSourcesCategoryBucket> cats) {
    if (cats.length == 1) return cats.first.key;
    if (_selectedCategoryKey == kKitSourcesCategoryAll) {
      return kKitSourcesCategoryAll;
    }
    if (cats.any((c) => c.key == _selectedCategoryKey)) {
      return _selectedCategoryKey;
    }
    return kKitSourcesCategoryAll;
  }

  Widget _categoryBrowse(BuildContext context, List<KitSourcesRow> allRows) {
    final queried = kitSourcesFilterByQuery(allRows, _effectiveQuery);
    final cats = kitSourcesCategoriesFromRows(queried);
    final selected = _effectiveCategoryKey(cats);
    final filtered = kitSourcesFilterByCategory(queried, selected);
    final showAll = cats.length >= 2;
    final searching = _effectiveQuery.trim().isNotEmpty;

    if (queried.isEmpty && searching) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'No channels match “${_effectiveQuery.trim()}”',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        if (!wide || cats.isEmpty) {
          return widget.embedded
              ? _embeddedSourcesGrid(
                  context,
                  filtered,
                  hideCategorySubtitle: true,
                )
              : _sidePanelList(
                  context,
                  filtered,
                  hideCategorySubtitle: true,
                );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: constraints.maxWidth >= 720 ? 200 : 168,
              child: _categoryRail(
                context,
                cats: cats,
                showAll: showAll,
                allCount: queried.length,
                selectedKey: selected,
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: ForjaShellColors.borderSubtle,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: widget.embedded
                  ? _embeddedSourcesGrid(
                      context,
                      filtered,
                      hideCategorySubtitle: true,
                    )
                  : _sidePanelList(
                      context,
                      filtered,
                      hideCategorySubtitle: true,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryRail(
    BuildContext context, {
    required List<KitSourcesCategoryBucket> cats,
    required bool showAll,
    required int allCount,
    required String selectedKey,
  }) {
    final rows = <({String key, String label, int count})>[
      if (showAll)
        (key: kKitSourcesCategoryAll, label: 'All', count: allCount),
      for (final c in cats) (key: c.key, label: c.label, count: c.count),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final row = rows[i];
        return KitSourcesCategoryRailRow(
          label: row.label,
          count: row.count,
          selected: row.key == selectedKey,
          listIndex: i,
          onTap: () {
            if (_selectedCategoryKey == row.key) return;
            setState(() => _selectedCategoryKey = row.key);
            if (_listScroll.hasClients) _listScroll.jumpTo(0);
          },
        );
      },
    );
  }

  Widget _sidePanelList(
    BuildContext context,
    List<KitSourcesRow> rows, {
    bool hideCategorySubtitle = false,
  }) {
    final tvTabId = _effectiveTvTabId(context);
    final interactive =
        !ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final list = _streamListScrollbar(
      interactive: interactive,
      child: ListView.separated(
        controller: _listScroll,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) => _tile(
          context,
          rows[i],
          i,
          hideCategorySubtitle: hideCategorySubtitle,
        ),
      ),
    );
    if (tvTabId == null) return list;
    return TvKitRow(
      tabId: tvTabId,
      rowId: widget.listRowId,
      sortOrder: SourcesPanelTv.listSort,
      itemCount: rows.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: _listFocusUp(tvTabId),
      child: list,
    );
  }

  /// Hero details: 2 columns when wide, 1 when narrow.
  ///
  /// Wide layout is **column-major** — fill the left column top→bottom first,
  /// then the right column (one stream still sits in the left half).
  Widget _embeddedSourcesGrid(
    BuildContext context,
    List<KitSourcesRow> rows, {
    bool hideCategorySubtitle = false,
  }) {
    const gap = 10.0;
    // Flush with title / Providers — no extra side inset.
    const listPad = EdgeInsets.only(bottom: 8);
    final tvTabId = _effectiveTvTabId(context);
    final interactive =
        !ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final grid = _streamListScrollbar(
      interactive: interactive,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = ShellScope.metricsOf(context);
          final wide =
              !metrics.usesTvDensity && constraints.maxWidth >= 720;

          if (!wide) {
            return ListView.separated(
              controller: _listScroll,
              padding: listPad,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: gap),
              itemBuilder: (context, i) => _tile(
                context,
                rows[i],
                i,
                hideCategorySubtitle: hideCategorySubtitle,
                upToTabs: i == 0,
              ),
            );
          }

          // Column-major: left = first half, right = remainder.
          final leftCount = (rows.length + 1) ~/ 2;
          return ListView.builder(
            controller: _listScroll,
            padding: listPad,
            itemCount: leftCount,
            itemBuilder: (context, row) {
              final left = row;
              final right = leftCount + row;
              return Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _tile(
                          context,
                          rows[left],
                          left,
                          hideCategorySubtitle: hideCategorySubtitle,
                          upToTabs: row == 0,
                        ),
                      ),
                      const SizedBox(width: gap),
                      Expanded(
                        child: right < rows.length
                            ? _tile(
                                context,
                                rows[right],
                                right,
                                hideCategorySubtitle: hideCategorySubtitle,
                                upToTabs: row == 0,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    if (tvTabId == null || rows.isEmpty) return grid;
    return TvKitRow(
      tabId: tvTabId,
      rowId: widget.listRowId,
      sortOrder: SourcesPanelTv.listSort,
      itemCount: rows.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: _listFocusUp(tvTabId),
      child: grid,
    );
  }

  VoidCallback _listFocusUp(String tvTabId) {
    // Embedded match details: ↑ from streams lands on Providers / Live TV.
    if (widget.embedded || tvTabId == MediaDetailsTv.tabId) {
      return () {
        ShellTvFocusCoordinator.focusRowItem(
          tvTabId,
          MediaDetailsTv.heroRowId,
          0,
        );
      };
    }
    return () => SourcesPanelTv.focusKindItem();
  }

  Widget _tile(
    BuildContext context,
    KitSourcesRow row,
    int index, {
    bool hideCategorySubtitle = false,
    bool upToTabs = false,
  }) {
    final footer = (row.footer ?? '').trim();
    final tvTabId = _effectiveTvTabId(context);
    final provider = hideCategorySubtitle ? null : row.subtitle;
    return SourcesPanelChannelTile(
      title: row.title,
      provider: provider,
      badges: row.badges,
      viewerCount: row.viewerCount,
      footerLabel: footer.isEmpty ? null : footer,
      tvTabId: tvTabId,
      tvRowId: widget.listRowId,
      tvItemIndex: index,
      onHoverProbe: row.onHoverProbe,
      probeHealthCache: row.probeHealthCache,
      onUpEdge: tvTabId != null && (upToTabs || index == 0)
          ? _listFocusUp(tvTabId)
          : null,
      onLeftEdge: widget.onTabsLeftEdge,
      onPlay: () => unawaited(widget.onPlayRow(row)),
    );
  }
}
