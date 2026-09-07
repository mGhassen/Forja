import 'package:flutter/material.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_list_source.dart';
import 'package:forja/shared/catalog/kit/layout/catalog_kit_panel_host.dart';
import 'package:forja/shared/catalog/kit/panel/catalog_kit_sources_panel.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/live/match_streams.dart';

/// Live Sports streams panel — thin kit host over [CatalogKitSourcesPanel].
final class LiveSportsStreamsPanelHost implements CatalogKitPanelHost {
  const LiveSportsStreamsPanelHost();

  static const instance = LiveSportsStreamsPanelHost();

  static const _providersTab = 'providers';
  static const _liveTvTab = 'live_tv';

  @override
  String get listSourceId => LiveSportsHost.listSourceId;

  @override
  Widget buildSidePanel({
    required BuildContext context,
    required CatalogKitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required bool shellTabVisible,
    required int refreshEpoch,
    VoidCallback? onClosed,
  }) {
    final row = entry.legacyRow;
    final title = (row['title'] ?? row['name'] ?? entry.meta.name)
        .toString()
        .trim();
    final subtitle = (row['category'] ?? entry.meta.badge ?? '')
        .toString()
        .trim();

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: CatalogKitSourcesPanel(
          key: ValueKey('live-panel-${entry.meta.id}'),
          title: title.isEmpty ? 'Streams' : title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          tabs: const [
            CatalogKitSourcesTab(id: _providersTab, label: 'Providers'),
            CatalogKitSourcesTab(id: _liveTvTab, label: 'Live TV'),
          ],
          initialTabId: _providersTab,
          onClosed: onClosed,
          loadTab: (tabId) => _loadTab(row, tabId),
          onPlayRow: (kitRow) => _playRow(context, kitRow, title: title),
        ),
      ),
    );
  }

  static Future<List<CatalogKitSourcesRow>> _loadTab(
    Map<String, dynamic> legacyRow,
    String tabId,
  ) async {
    final sources = tabId == _liveTvTab
        ? await MatchStreams.loadIptvChannels(legacyRow)
        : await MatchStreams.loadProviders(legacyRow);
    return [
      for (var i = 0; i < sources.length; i++)
        CatalogKitSourcesRow(
          id: '${tabId}_$i',
          title: sources[i].pickerTitle,
          subtitle: sources[i].pickerSubtitle ?? sources[i].liveProviderBadge,
          badges: [
            if (sources[i].liveStreamHd) 'HD',
            if ((sources[i].liveProviderBadge ?? '').trim().isNotEmpty)
              sources[i].liveProviderBadge!.trim(),
          ],
          viewerCount: sources[i].liveViewerCount,
          payload: _PlayPayload(sources: sources, picked: sources[i]),
        ),
    ];
  }

  static Future<void> _playRow(
    BuildContext context,
    CatalogKitSourcesRow kitRow, {
    required String title,
  }) async {
    final payload = kitRow.payload;
    if (payload is! _PlayPayload) return;
    await MatchStreams.play(
      context,
      sources: payload.sources,
      picked: payload.picked,
      title: title.isEmpty ? payload.picked.pickerTitle : title,
      subtitle: payload.picked.pickerSubtitle,
    );
  }
}

class _PlayPayload {
  const _PlayPayload({required this.sources, required this.picked});
  final List<IptvPlaySource> sources;
  final IptvPlaySource picked;
}
