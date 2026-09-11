import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/panel_tabs.dart' show kitPanelTabIcon;
import 'package:forja_foundation/widgets/sources/live_tv_browse.dart';
import 'package:forja_foundation/widgets/sources/sources_types.dart';

export 'package:forja_foundation/widgets/sources/sources_types.dart';

/// Pack-agnostic sources side panel paint (tabs + rows + reload/close).
///
/// Features wire load/play via callbacks. Zone A — no host TV / ShellScope.
///
/// When the active tab is in [browseCategoryTabIds], the body uses an IPTV-style
/// Categories rail + optional channel search (Live TV chrome).
class SourcesPanelChrome extends StatefulWidget {
  const SourcesPanelChrome({
    super.key,
    required this.title,
    required this.tabs,
    required this.loadTab,
    required this.onPlayRow,
    this.subtitle,
    this.initialTabId,
    this.onClosed,
    this.tvTabId,
    this.listRowId = 'sources-list',
    this.tabsRowId = 'sources-tabs',
    this.embedded = false,
    this.showTabs = true,
    this.onTabsLeftEdge,
    this.browseCategoryTabIds = const {},
    this.channelQuery,
    this.onChannelQueryChanged,
    this.showInlineSearch = true,
    this.onLoadingChanged,
    this.reloadNonce = 0,
    this.useFocusableChips = false,
    this.usesTvDensity = false,
    this.tileBuilder,
    this.listFocusWrap,
    this.tabsFocusWrap,
    this.tabsBuilder,
  });

  final String title;
  final String? subtitle;
  final List<SourcesTab> tabs;
  final String? initialTabId;

  /// Load rows for a tab id. Called on first select and on reload.
  /// When [force] is true, skip warm caches and rediscover from scratch.
  final Future<List<SourcesRow>> Function(
    String tabId, {
    void Function(List<SourcesRow> rows)? onPartial,
    bool force,
  }) loadTab;

  final Future<void> Function(SourcesRow row) onPlayRow;
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

  /// Host: TV / focusable chips — scrollbar non-interactive on TV.
  final bool useFocusableChips;

  /// Host: TV density — single-column embedded grid.
  final bool usesTvDensity;

  /// Optional host tile (SourcesPanelChannelTile + TV). Default: simple InkWell row.
  final Widget Function(
    BuildContext context,
    SourcesRow row,
    int index, {
    required bool hideCategorySubtitle,
    required bool upToTabs,
    required VoidCallback onPlay,
  })? tileBuilder;

  /// Optional host wrap for list/grid (TV focus row).
  final Widget Function(BuildContext context, Widget child, {required int itemCount})? listFocusWrap;

  /// Optional host wrap for tabs row.
  final Widget Function(BuildContext context, Widget child, {required int itemCount})? tabsFocusWrap;

  /// Host segmented tabs chrome. Null → ChoiceChip row.
  final Widget Function(
    BuildContext context, {
    required String selected,
    required ValueChanged<String> onSelected,
    required List<SourcesTab> tabs,
  })? tabsBuilder;

  /// Host wires TV focus — Zone A has no TV graph.
  static void claimProvidersFocus({int maxTries = 24}) {}

  @override
  State<SourcesPanelChrome> createState() => _SourcesPanelChromeState();
}

class _SourcesPanelChromeState extends State<SourcesPanelChrome> {
  late String _tabId;
  final Map<String, List<SourcesRow>> _rowsByTab = {};
  final Map<String, bool> _loadingByTab = {};
  final Map<String, String?> _errorByTab = {};
  final ScrollController _listScroll = ScrollController();
  int _loadGen = 0;
  String _internalQuery = '';
  String _selectedCategoryKey = kSourcesCategoryAll;

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
  void didUpdateWidget(SourcesPanelChrome oldWidget) {
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
              _selectedCategoryKey = kSourcesCategoryAll;
            }
          });
        },
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rowsByTab[tabId] = rows;
        _loadingByTab[tabId] = false;
        if (widget.browseCategoryTabIds.contains(tabId)) {
          _selectedCategoryKey = kSourcesCategoryAll;
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
        _selectedCategoryKey = kSourcesCategoryAll;
      } else {
        _selectedCategoryKey = kSourcesCategoryAll;
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
    final showSearch = widget.showInlineSearch && _browseActive;
    final loading = _loadingByTab[_tabId] == true;
    final tabsChrome = widget.tabsBuilder?.call(
          context,
          selected: _tabId,
          onSelected: _selectTab,
          tabs: widget.tabs,
        ) ??
        Wrap(
          spacing: 8,
          children: [
            for (final tab in widget.tabs)
              ChoiceChip(
                label: Text(tab.label),
                selected: tab.id == _tabId,
                onSelected: (_) => _selectTab(tab.id),
                avatar: Icon(kitPanelTabIcon(tab.icon), size: 16),
              ),
          ],
        );
    final choice = Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Flexible(child: tabsChrome),
          const Spacer(),
          if (showSearch)
            SourcesExpandingSearch(
              query: _effectiveQuery,
              onQueryChanged: _onQueryChanged,
              useTvBrowse: widget.useFocusableChips,
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
    final wrap = widget.tabsFocusWrap;
    if (wrap == null || widget.tabs.isEmpty) return padded;
    return wrap(context, padded, itemCount: widget.tabs.length);
  }

  Widget _body(
    BuildContext context, {
    required bool loading,
    required String? error,
    required List<SourcesRow> rows,
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

  String _effectiveCategoryKey(List<SourcesCategoryBucket> cats) {
    if (cats.length == 1) return cats.first.key;
    if (_selectedCategoryKey == kSourcesCategoryAll) {
      return kSourcesCategoryAll;
    }
    if (cats.any((c) => c.key == _selectedCategoryKey)) {
      return _selectedCategoryKey;
    }
    return kSourcesCategoryAll;
  }

  Widget _categoryBrowse(BuildContext context, List<SourcesRow> allRows) {
    final queried = sourcesFilterByQuery(allRows, _effectiveQuery);
    final cats = sourcesCategoriesFromRows(queried);
    final selected = _effectiveCategoryKey(cats);
    final filtered = sourcesFilterByCategory(queried, selected);
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
    required List<SourcesCategoryBucket> cats,
    required bool showAll,
    required int allCount,
    required String selectedKey,
  }) {
    final rows = <({String key, String label, int count})>[
      if (showAll)
        (key: kSourcesCategoryAll, label: 'All', count: allCount),
      for (final c in cats) (key: c.key, label: c.label, count: c.count),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final row = rows[i];
        return SourcesCategoryRailRow(
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
    List<SourcesRow> rows, {
    bool hideCategorySubtitle = false,
  }) {
    final interactive = !widget.useFocusableChips;
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
    final wrap = widget.listFocusWrap;
    if (wrap == null) return list;
    return wrap(context, list, itemCount: rows.length);
  }

  /// Hero details: 2 columns when wide, 1 when narrow.
  ///
  /// Wide layout is **column-major** — fill the left column top→bottom first,
  /// then the right column (one stream still sits in the left half).
  Widget _embeddedSourcesGrid(
    BuildContext context,
    List<SourcesRow> rows, {
    bool hideCategorySubtitle = false,
  }) {
    const gap = 10.0;
    // Flush with title / Providers — no extra side inset.
    const listPad = EdgeInsets.only(bottom: 8);
    final interactive = !widget.useFocusableChips;
    final grid = _streamListScrollbar(
      interactive: interactive,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              !widget.usesTvDensity && constraints.maxWidth >= 720;

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
    if (rows.isEmpty) return grid;
    final wrap = widget.listFocusWrap;
    if (wrap == null) return grid;
    return wrap(context, grid, itemCount: rows.length);
  }

  Widget _tile(
    BuildContext context,
    SourcesRow row,
    int index, {
    bool hideCategorySubtitle = false,
    bool upToTabs = false,
  }) {
    void onPlay() => unawaited(widget.onPlayRow(row));
    final custom = widget.tileBuilder;
    if (custom != null) {
      return custom(
        context,
        row,
        index,
        hideCategorySubtitle: hideCategorySubtitle,
        upToTabs: upToTabs,
        onPlay: onPlay,
      );
    }
    final footer = (row.footer ?? '').trim();
    final provider = hideCategorySubtitle ? null : row.subtitle;
    return Material(
      color: ForjaShellColors.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if ((provider ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  provider!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
