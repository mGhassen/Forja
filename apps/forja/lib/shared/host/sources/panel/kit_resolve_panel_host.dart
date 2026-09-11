import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/layout/kit_panel_host.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shared/foundation/services/registry/kit_resolve_streams_hooks.dart';
import 'package:forja/shared/host/live_sports/kit_match_details_page.dart';

/// Thin registry host — load/play via [KitResolveStreamsHooks] (RFC-095 D).
final class KitResolvePanelHost implements KitPanelHost {
  const KitResolvePanelHost();

  static const instance = KitResolvePanelHost();

  static const providersTab = 'providers';
  static const liveTvTab = 'live_tv';

  /// Must match [KitLiveBoot.listSourceId] (`live_schedule`).
  @override
  String get listSourceId => 'live_schedule';

  @override
  Widget? buildDetailsPage({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required int refreshEpoch,
  }) {
    return KitMatchDetailsPage(
      entry: entry,
      refreshEpoch: refreshEpoch,
    );
  }

  @override
  Widget buildSidePanel({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
    VoidCallback? onPanelLeftEdge,
  }) {
    return _KitResolveStreamsPanel(
      key: ValueKey('live-panel-${entry.meta.id}'),
      entry: entry,
      refreshEpoch: refreshEpoch,
      onClosed: onClosed,
      onPanelLeftEdge: onPanelLeftEdge,
    );
  }

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    KitUrlHealthProbe? healthProbe,
    void Function(List<KitSourcesRow> rows)? onPartial,
    bool force = false,
  }) async {
    final load = KitResolveStreamsHooks.loadTab;
    if (load == null) return const [];
    return load(
      legacyRow,
      tabId,
      healthProbe: healthProbe,
      onPartial: onPartial,
      force: force,
    );
  }

  static Future<void> playRow(
    BuildContext context,
    KitSourcesRow kitRow, {
    required String title,
  }) async {
    final play = KitResolveStreamsHooks.playRow;
    if (play == null) return;
    await play(context, kitRow, title: title);
  }
}

class _KitResolveStreamsPanel extends StatefulWidget {
  const _KitResolveStreamsPanel({
    super.key,
    required this.entry,
    required this.refreshEpoch,
    this.onClosed,
    this.onPanelLeftEdge,
  });

  final KitListEntry entry;
  final int refreshEpoch;
  final VoidCallback? onClosed;
  final VoidCallback? onPanelLeftEdge;

  @override
  State<_KitResolveStreamsPanel> createState() =>
      _KitResolveStreamsPanelState();
}

class _KitResolveStreamsPanelState extends State<_KitResolveStreamsPanel> {
  KitUrlHealthProbe? _healthProbe;

  @override
  void initState() {
    super.initState();
    final create = KitResolveStreamsHooks.createHealthProbe;
    _healthProbe = create?.call(
      onResult: (_, _) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _healthProbe?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.entry.legacyRow;
    final title = (row['title'] ?? row['name'] ?? widget.entry.meta.name)
        .toString()
        .trim();
    final subtitle = (row['category'] ?? widget.entry.meta.badge ?? '')
        .toString()
        .trim();
    final probe = _healthProbe;

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: probe == null
            ? _buildPanel(context, row, title, subtitle, null)
            : ListenableBuilder(
                listenable: probe,
                builder: (context, _) =>
                    _buildPanel(context, row, title, subtitle, probe),
              ),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Map<String, dynamic> row,
    String title,
    String subtitle,
    KitUrlHealthProbe? healthProbe,
  ) {
    return KitSourcesPanel(
      key: ValueKey(
        'live-panel-body-${widget.entry.meta.id}-${widget.refreshEpoch}',
      ),
      title: title.isEmpty ? 'Streams' : title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      tabs: const [
        KitSourcesTab(
          id: KitResolvePanelHost.providersTab,
          label: 'Providers',
        ),
        KitSourcesTab(
          id: KitResolvePanelHost.liveTvTab,
          label: 'Live TV',
        ),
      ],
      initialTabId: KitResolvePanelHost.providersTab,
      browseCategoryTabIds: const {KitResolvePanelHost.liveTvTab},
      showInlineSearch: true,
      onClosed: widget.onClosed,
      onTabsLeftEdge: widget.onPanelLeftEdge,
      loadTab: (tabId, {onPartial, force = false}) =>
          KitResolvePanelHost.loadTab(
        row,
        tabId,
        healthProbe: healthProbe,
        onPartial: onPartial,
        force: force,
      ),
      onPlayRow: (kitRow) => KitResolvePanelHost.playRow(
        context,
        kitRow,
        title: title,
      ),
    );
  }
}
