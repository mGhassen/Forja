import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/foundation/services/live/live_match_details_page.dart';
import 'package:forja/shared/foundation/services/live/live_sports_host.dart';
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
    return _LiveSportsStreamsPanel(
      key: ValueKey('live-panel-${entry.meta.id}'),
      entry: entry,
      refreshEpoch: refreshEpoch,
      onClosed: onClosed,
    );
  }

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    IptvLazyUrlHealthProbe? healthProbe,
  }) async {
    final sources = tabId == liveTvTab
        ? await MatchStreams.loadIptvChannels(legacyRow)
        : await MatchStreams.loadProviders(legacyRow);
    return [
      for (var i = 0; i < sources.length; i++)
        _rowForSource(
          tabId: tabId,
          index: i,
          source: sources[i],
          all: sources,
          healthProbe: healthProbe,
        ),
    ];
  }

  static KitSourcesRow _rowForSource({
    required String tabId,
    required int index,
    required IptvPlaySource source,
    required List<IptvPlaySource> all,
    IptvLazyUrlHealthProbe? healthProbe,
  }) {
    final provider = (source.liveProviderBadge ?? '').trim().isNotEmpty
        ? source.liveProviderBadge!.trim()
        : (source.pickerSubtitle ?? '').trim();
    final host = _embedHost(source);
    final probeKey = _probeKey(source);
    return KitSourcesRow(
      id: '${tabId}_$index',
      title: source.pickerTitle,
      subtitle: provider.isEmpty ? null : provider,
      footer: host,
      badges: [
        if (source.liveStreamHd) 'HD',
      ],
      viewerCount: source.liveViewerCount,
      payload: _PlayPayload(sources: all, picked: source),
      probeHealthCache: healthProbe?.healthFor(probeKey),
      onHoverProbe: healthProbe == null || !iptvLiveSourceCanHoverProbe(source)
          ? null
          : () async {
              final cached = healthProbe.healthFor(probeKey);
              if (cached != null) return cached;
              final probeUrl = iptvLiveSourceProbeUrl(source);
              if (probeUrl == null) {
                final ok = iptvLiveSourceProbeSkipped(source);
                healthProbe.remember(probeKey, ok);
                return ok;
              }
              return healthProbe.checkNow(probeKey, probeUrl);
            },
    );
  }

  static String _probeKey(IptvPlaySource source) {
    final url = source.url.trim();
    if (url.isNotEmpty) return url;
    final embed = (source.liveEngineEmbedUrl ?? '').trim();
    if (embed.isNotEmpty) return embed;
    return source.pickerTitle;
  }

  static String? _embedHost(IptvPlaySource source) {
    final embed = (source.liveEngineEmbedUrl ?? '').trim();
    final url = source.url.trim();
    final probe = embed.isNotEmpty
        ? embed
        : (url.startsWith('http') ? url : '');
    if (probe.isEmpty) return null;
    final host = Uri.tryParse(probe)?.host.trim() ?? '';
    return host.isEmpty ? null : host;
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

class _LiveSportsStreamsPanel extends StatefulWidget {
  const _LiveSportsStreamsPanel({
    super.key,
    required this.entry,
    required this.refreshEpoch,
    this.onClosed,
  });

  final KitListEntry entry;
  final int refreshEpoch;
  final VoidCallback? onClosed;

  @override
  State<_LiveSportsStreamsPanel> createState() =>
      _LiveSportsStreamsPanelState();
}

class _LiveSportsStreamsPanelState extends State<_LiveSportsStreamsPanel> {
  late final IptvLazyUrlHealthProbe _healthProbe;

  @override
  void initState() {
    super.initState();
    _healthProbe = IptvLazyUrlHealthProbe(
      onResult: (_, _) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _healthProbe.dispose();
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

    return Material(
      color: ForjaShellColors.surfaceElevated,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: ForjaShellColors.borderSubtle),
          ),
        ),
        child: ListenableBuilder(
          listenable: _healthProbe,
          builder: (context, _) => KitSourcesPanel(
            key: ValueKey(
              'live-panel-body-${widget.entry.meta.id}-${widget.refreshEpoch}',
            ),
            title: title.isEmpty ? 'Streams' : title,
            subtitle: subtitle.isEmpty ? null : subtitle,
            tabs: const [
              KitSourcesTab(
                id: LiveSportsStreamsPanelHost.providersTab,
                label: 'Providers',
              ),
              KitSourcesTab(
                id: LiveSportsStreamsPanelHost.liveTvTab,
                label: 'Live TV',
              ),
            ],
            initialTabId: LiveSportsStreamsPanelHost.providersTab,
            onClosed: widget.onClosed,
            loadTab: (tabId) => LiveSportsStreamsPanelHost.loadTab(
              row,
              tabId,
              healthProbe: _healthProbe,
            ),
            onPlayRow: (kitRow) => LiveSportsStreamsPanelHost.playRow(
              context,
              kitRow,
              title: title,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPayload {
  const _PlayPayload({required this.sources, required this.picked});
  final List<IptvPlaySource> sources;
  final IptvPlaySource picked;
}
