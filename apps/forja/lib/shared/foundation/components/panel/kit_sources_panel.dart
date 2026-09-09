import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/components/hero/hero_pill_buttons.dart';
import 'package:forja/shared/foundation/components/media_details/sources_panel_tv.dart';
import 'package:forja/shared/foundation/components/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';

/// Opaque tab for [KitSourcesPanel].
@immutable
class KitSourcesTab {
  const KitSourcesTab({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
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
  });

  final String title;
  final String? subtitle;
  final List<KitSourcesTab> tabs;
  final String? initialTabId;

  /// Load rows for a tab id. Called on first select and on reload.
  final Future<List<KitSourcesRow>> Function(String tabId) loadTab;

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
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _tabId = widget.initialTabId ??
        (widget.tabs.isNotEmpty ? widget.tabs.first.id : '');
    if (_tabId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensureLoaded(_tabId));
      });
    }
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
  }

  Future<void> _ensureLoaded(String tabId, {bool force = false}) async {
    if (tabId.isEmpty) return;
    if (!force && _rowsByTab.containsKey(tabId) && _loadingByTab[tabId] != true) {
      return;
    }
    final gen = ++_loadGen;
    setState(() {
      _loadingByTab[tabId] = true;
      _errorByTab[tabId] = null;
      if (force) _rowsByTab.remove(tabId);
    });
    try {
      final rows = await widget.loadTab(tabId);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rowsByTab[tabId] = rows;
        _loadingByTab[tabId] = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _errorByTab[tabId] = e.toString();
        _loadingByTab[tabId] = false;
        _rowsByTab[tabId] = const [];
      });
    }
  }

  void _selectTab(String id) {
    if (id == _tabId) return;
    setState(() => _tabId = id);
    unawaited(_ensureLoaded(id));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) _header(context),
        if (widget.showTabs && widget.tabs.length > 1) _tabs(context),
        Expanded(child: _body(context, loading: loading, error: error, rows: rows)),
      ],
    );
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
    final choice = Align(
      alignment: Alignment.centerLeft,
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
          for (var i = 0; i < widget.tabs.length; i++)
            HeroPillSegment(
              value: widget.tabs[i].id,
              label: widget.tabs[i].label,
              icon: i == 0 ? Icons.dns_rounded : Icons.live_tv_rounded,
            ),
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
    // Hero details (embedded): 2-col stream grid on wide — matches old live
    // match details. Side panel stays single-column ListView.
    if (widget.embedded) {
      return _embeddedSourcesGrid(context, rows);
    }
    return _sidePanelList(context, rows);
  }

  Widget _sidePanelList(BuildContext context, List<KitSourcesRow> rows) {
    final tvTabId = _effectiveTvTabId(context);
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _tile(context, rows[i], i),
    );
    if (tvTabId == null) return list;
    return TvKitRow(
      tabId: tvTabId,
      rowId: widget.listRowId,
      sortOrder: SourcesPanelTv.listSort,
      itemCount: rows.length,
      orientation: ShellTvRowOrientation.vertical,
      onFocusUp: () => SourcesPanelTv.focusKindItem(),
      child: list,
    );
  }

  /// Pre-kit live details: 2 columns when wide, 1 when narrow / TV compact.
  Widget _embeddedSourcesGrid(BuildContext context, List<KitSourcesRow> rows) {
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = ShellScope.metricsOf(context);
        final wide = !metrics.usesTvDensity && constraints.maxWidth >= 720;
        final crossCount = wide ? 2 : 1;

        if (crossCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: gap),
            itemBuilder: (context, i) => _tile(context, rows[i], i),
          );
        }

        final rowCount = (rows.length + 1) ~/ 2;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          itemCount: rowCount,
          itemBuilder: (context, row) {
            final left = row * 2;
            final right = left + 1;
            return Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _tile(context, rows[left], left)),
                    const SizedBox(width: gap),
                    Expanded(
                      child: right < rows.length
                          ? _tile(context, rows[right], right)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, KitSourcesRow row, int index) {
    final footer = (row.footer ?? '').trim();
    final tvTabId = _effectiveTvTabId(context);
    return SourcesPanelChannelTile(
      title: row.title,
      provider: row.subtitle,
      badges: row.badges,
      viewerCount: row.viewerCount,
      footerLabel: footer.isEmpty ? null : footer,
      tvTabId: tvTabId,
      tvRowId: widget.listRowId,
      tvItemIndex: index,
      onHoverProbe: row.onHoverProbe,
      probeHealthCache: row.probeHealthCache,
      onUpEdge: index == 0 && tvTabId != null
          ? () => SourcesPanelTv.focusKindItem()
          : null,
      onLeftEdge: widget.onTabsLeftEdge,
      onPlay: () => unawaited(widget.onPlayRow(row)),
    );
  }
}
