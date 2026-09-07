import 'package:flutter/material.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/features/live_sports/catalog/live_match_details_page.dart';
import 'package:forja/features/live_sports/live_sports_host.dart';
import 'package:forja/shared/foundation/components/layout/kit_list_source.dart';
import 'package:forja/shared/foundation/components/layout/kit_panel_host.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/services/live/match_streams.dart';

/// Thin registry host — wires [KitSourcesPanel] to [MatchStreams] only.
/// Layout composition (list+panel vs cards+details) belongs in pack JS + kit.
final class LiveSportsStreamsPanelHost implements KitPanelHost {
  const LiveSportsStreamsPanelHost();

  static const instance = LiveSportsStreamsPanelHost();

  static const providersTab = 'providers';
  static const liveTvTab = 'live_tv';

  @override
  String get listSourceId => LiveSportsHost.listSourceId;

  @override
  Widget? buildDetailsPage({
    required BuildContext context,
    required KitListEntry entry,
    required List<Map<String, dynamic>> layoutWidgets,
    required int refreshEpoch,
  }) {
    return LiveMatchDetailsPage(
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
        child: KitSourcesPanel(
          key: ValueKey('live-panel-${entry.meta.id}'),
          title: title.isEmpty ? 'Streams' : title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          tabs: const [
            KitSourcesTab(id: providersTab, label: 'Providers'),
            KitSourcesTab(id: liveTvTab, label: 'Live TV'),
          ],
          initialTabId: providersTab,
          onClosed: onClosed,
          loadTab: (tabId) => loadTab(row, tabId),
          onPlayRow: (kitRow) => playRow(context, kitRow, title: title),
        ),
      ),
    );
  }

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId,
  ) async {
    final sources = tabId == liveTvTab
        ? await MatchStreams.loadIptvChannels(legacyRow)
        : await MatchStreams.loadProviders(legacyRow);
    return [
      for (var i = 0; i < sources.length; i++)
        KitSourcesRow(
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

  static Future<void> playRow(
    BuildContext context,
    KitSourcesRow kitRow, {
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
