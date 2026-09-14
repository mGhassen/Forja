import 'package:flutter/material.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/player/live/hooks/live_play.dart';
import 'package:forja/shared/player/live/pt_player_screen.dart';
import 'package:forja/shared/player/sources/kit_sources_panel.dart';
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart';
import 'package:forja/shared/player/sources/resolve_streams_hooks.dart';

/// Live resolve panel data — registered on [KitResolveStreamsHooks].
///
/// Live TV rows come from any hub pack that declares `liveTv` (opaque capability).
abstract final class ResolveStreamsAdapter {
  ResolveStreamsAdapter._();

  static Future<List<KitSourcesRow>> loadTab(
    Map<String, dynamic> legacyRow,
    String tabId, {
    KitUrlHealthProbe? healthProbe,
    void Function(List<KitSourcesRow> rows)? onPartial,
    bool force = false,
  }) async {
    if (tabId == 'liveTv' || tabId == 'live_tv') {
      final sources = await _loadLiveTv(legacyRow, force: force);
      return _rowsFor(tabId, sources, healthProbe);
    }
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

  static Future<String?> _resolveLiveTvPluginId() async {
    final packs = await EngineService.instance.listPacks();
    for (final pack in packs) {
      if (!pack.enabled) continue;
      for (final p in pack.plugins) {
        if (!p.enabled) continue;
        if (p.hasCapability('liveTv')) return p.id;
      }
    }
    return null;
  }

  static List<IptvPlaySource> sourcesFromMaps(List<Map<String, dynamic>> maps) {
    final out = <IptvPlaySource>[];
    for (final m in maps) {
      final url = (m['url'] ?? '').toString().trim();
      final streamId =
          (m['streamId'] ?? m['stream_id'] ?? '').toString().trim();
      final kindName =
          (m['liveSourceKind'] ?? m['live_source_kind'] ?? '').toString().trim();
      final kind = switch (kindName) {
        'iptvStalker' => IptvLiveSourceKind.iptvStalker,
        'iptvXtream' => IptvLiveSourceKind.iptvXtream,
        'stremio' => IptvLiveSourceKind.stremio,
        'liveEngine' => IptvLiveSourceKind.liveEngine,
        _ => streamId.isNotEmpty && url.isEmpty
            ? IptvLiveSourceKind.iptvStalker
            : IptvLiveSourceKind.iptvXtream,
      };
      if (kind == IptvLiveSourceKind.iptvStalker) {
        if (streamId.isEmpty) continue;
      } else if (url.isEmpty) {
        continue;
      }
      final label = (m['label'] ?? m['name'] ?? 'Stream').toString().trim();
      final detail = (m['detail'] ?? m['title'] ?? '').toString().trim();
      final logo = (m['logoUrl'] ?? m['logo'] ?? '').toString().trim();
      final epg =
          (m['epgChannelId'] ?? m['epg_channel_id'] ?? '').toString().trim();
      out.add(
        IptvPlaySource(
          url: url,
          label: label.isEmpty ? 'Stream' : label,
          detail: detail.isEmpty ? null : detail,
          logoUrl: logo.isEmpty ? null : logo,
          streamId: streamId.isEmpty ? null : streamId,
          epgChannelId: epg.isEmpty ? null : epg,
          liveSourceKind: kind,
        ),
      );
    }
    return out;
  }

  static Future<List<IptvPlaySource>> _loadLiveTv(
    Map<String, dynamic> legacyRow, {
    bool force = false,
  }) async {
    final pluginId = await _resolveLiveTvPluginId();
    if (pluginId == null || pluginId.isEmpty) {
      debugPrint('[LiveTV] no hub with liveTv capability');
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
      return sourcesFromMaps([
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
