import 'package:flutter/material.dart';
import 'package:forja/shared/engine/portals/channel_search/iptv_channel_search.dart';
import 'package:forja/shared/host/portals_ui/channel_search/iptv_forja_sports_gate.dart';
import 'package:forja/shared/host/portals_ui/open/live_play.dart';
import 'package:forja/shared/player/iptv/iptv_pt_player_screen.dart';
import 'package:forja/shared/player/sources/kit_sources_panel.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/player/sources/resolve_streams_hooks.dart';

/// IPTV / live resolve panel data — registered on [KitResolveStreamsHooks] (RFC-095).
///
/// Live TV rows come from the live hub pack (`action: liveTv`).
/// Providers / catalog resolve packs are pack-owned; host no longer embeds
/// [LiveResolveStreams] (deleted with live feeds). Non–Live-TV tabs return [].
abstract final class IptvResolveStreamsAdapter {
  IptvResolveStreamsAdapter._();

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    KitUrlHealthProbe? healthProbe,
    void Function(List<KitSourcesRow> rows)? onPartial,
    bool force = false,
  }) async {
    // Pack chrome id is `live_tv`; loader action is `liveTv` (panelTabLoadId).
    if (tabId == 'liveTv' || tabId == 'live_tv') {
      final sources = await _loadLiveTv(legacyRow, force: force);
      return _rowsFor(tabId, sources, healthProbe);
    }

    IptvChannelSearch.cancel(reason: 'leave browse tab');
    return const [];
  }

  static List<KitSourcesRow> _rowsFor(
    String tabId,
    List<IptvPlaySource> sources,
    KitUrlHealthProbe? healthProbe,
  ) {
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
    Map<String, dynamic> legacyRow, {
    bool force = false,
  }) async {
    final pluginId = await IptvForjaSportsGate.resolveSettingsPluginId();
    if (pluginId == null || pluginId.isEmpty) {
      debugPrint('[LiveTV] no hub with Forja Sports settings');
      return [];
    }
    try {
      final env = await MetaRuntime.instance.run(
        pluginId: pluginId,
        action: 'liveTv',
        params: {
          'row': legacyRow,
          if (force) 'force': true,
        },
        forceRefresh: force,
        timeout: const Duration(seconds: 90),
      );
      if (!env.ok) {
        debugPrint(
          '[LiveTV] hub liveTv failed: ${env.error?.code} ${env.error?.message}',
        );
        return [];
      }
      final raw = env.data?['sources'];
      if (raw is! List) return [];
      return IptvChannelSearch.sourcesFromMaps([
        for (final e in raw)
          if (e is Map) Map<String, dynamic>.from(e),
      ]);
    } catch (e, st) {
      debugPrint('[LiveTV] hub liveTv error: $e\n$st');
      return [];
    }
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
    final probeKey = iptvLiveSourceProbeKey(source);
    return KitSourcesRow(
      id: '${tabId}_$index',
      title: source.pickerTitle,
      subtitle: provider.isEmpty ? null : provider,
      footer: host,
      badges: [
        if (source.liveStreamHd) 'HD',
      ],
      viewerCount: source.liveViewerCount > 0 ? source.liveViewerCount : null,
      payload: _PlayPayload(sources: all, picked: source),
      probeHealthCache: healthProbe?.healthFor(probeKey),
      onHoverProbe: healthProbe == null || !iptvLiveSourceCanHoverProbe(source)
          ? null
          : () => iptvLiveSourceRunHoverProbe(
                source,
                healthProbe: healthProbe,
              ),
    );
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
    final picked = payload.picked;
    final ordered = <IptvPlaySource>[
      picked,
      for (final s in payload.sources)
        if (!identical(s, picked) && s.url != picked.url) s,
    ];
    await openForjaLiveNativePlayer(
      context,
      sources: ordered,
      title: title.isEmpty ? picked.pickerTitle : title,
      subtitle: picked.pickerSubtitle,
    );
  }
}

class _PlayPayload {
  const _PlayPayload({required this.sources, required this.picked});
  final List<IptvPlaySource> sources;
  final IptvPlaySource picked;
}
