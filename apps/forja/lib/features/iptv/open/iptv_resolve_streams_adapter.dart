import 'package:flutter/material.dart';
import 'package:forja/features/iptv/channel_search/iptv_channel_search.dart';
import 'package:forja/features/iptv/channel_search/iptv_forja_sports_gate.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/engine/live/live_resolve_streams.dart';
import 'package:forja/shared/foundation/components/panel/kit_sources_panel.dart';
import 'package:forja/shared/foundation/services/panel/kit_resolve_panel_host.dart';
import 'package:forja/shared/foundation/services/registry/kit_resolve_streams_hooks.dart';

/// IPTV / live resolve panel data — registered on [KitResolveStreamsHooks] (RFC-095).
abstract final class IptvResolveStreamsAdapter {
  IptvResolveStreamsAdapter._();

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    KitUrlHealthProbe? healthProbe,
  }) async {
    final sources = tabId == KitResolvePanelHost.liveTvTab
        ? await _loadLiveTv(legacyRow)
        : await LiveResolveStreams.loadProviders(legacyRow);
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

  static Future<List<IptvPlaySource>> _loadLiveTv(
    Map<String, dynamic> legacyRow,
  ) async {
    if (!await IptvForjaSportsGate.isForjaSportsEnabled()) return [];
    final game = IptvChannelSearch.gameFromLegacyRow(legacyRow);
    return IptvChannelSearch.search(game: game);
  }

  static KitSourcesRow _rowForSource({
    required String tabId,
    required int index,
    required IptvPlaySource source,
    required List<IptvPlaySource> all,
    KitUrlHealthProbe? healthProbe,
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
    await LiveResolveStreams.play(
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
