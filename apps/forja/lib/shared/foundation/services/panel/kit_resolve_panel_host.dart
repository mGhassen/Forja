import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/services/panel/kit_match_details_page.dart';
import 'package:forja/shared/foundation/services/schedule/kit_live_boot.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/layout/kit_panel_host.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/registry/kit_resolve_streams_hooks.dart';

/// Thin registry host — load/play via [KitResolveStreamsHooks] (RFC-095 D).
final class KitResolvePanelHost implements KitPanelHost {
  const KitResolvePanelHost();

  static const instance = KitResolvePanelHost();

  static const providersTab = 'providers';
  static const liveTvTab = 'live_tv';

  @override
  String get listSourceId => KitLiveBoot.listSourceId;

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
  }) {
    return _KitResolveStreamsPanel(
      key: ValueKey('live-panel-${entry.meta.id}'),
      entry: entry,
      refreshEpoch: refreshEpoch,
      onClosed: onClosed,
    );
  }

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    KitUrlHealthProbe? healthProbe,
  }) async {
    final load = KitResolveStreamsHooks.loadTab;
    if (load == null) return const [];
    return load(legacyRow, tabId, healthProbe: healthProbe);
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
  });

  final KitListEntry entry;
  final int refreshEpoch;
  final VoidCallback? onClosed;

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
      onClosed: widget.onClosed,
      loadTab: (tabId) => KitResolvePanelHost.loadTab(
        row,
        tabId,
        healthProbe: healthProbe,
      ),
      onPlayRow: (kitRow) => KitResolvePanelHost.playRow(
        context,
        kitRow,
        title: title,
      ),
    );
  }
}
