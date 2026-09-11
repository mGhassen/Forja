import 'package:flutter/widgets.dart';
import 'package:forja/features/iptv/data/iptv_catalog_disk_store.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv_catalog_recs.dart';
import 'package:forja/features/iptv/iptv_lazy_url_health.dart';
import 'package:forja/features/iptv/open/iptv_open.dart';
import 'package:forja/features/iptv/open/iptv_play.dart';
import 'package:forja/features/iptv/open/iptv_resolve_streams_adapter.dart';
import 'package:forja/features/iptv/open/live_play.dart';
import 'package:forja/features/iptv/channel_search/iptv_channel_search.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/kit/kit_iptv_play_hooks.dart';
import 'package:forja/shared/kit/kit_resolve_streams_hooks.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext, RichMediaDetails;

/// Boots IPTV play + resolve hooks so foundation kit stays feature-free (RFC-095).
abstract final class IptvKitHooksRegister {
  IptvKitHooksRegister._();

  static void ensureRegistered() {
    KitIptvPlayHooks.resolvePortalFromMeta = resolveIptvPortalFromMeta;
    KitIptvPlayHooks.hubDetailsParams = iptvHubDetailsParams;
    KitIptvPlayHooks.loadCatalogRecs = _loadCatalogRecs;
    KitIptvPlayHooks.openVodStream = _openVodStream;
    KitIptvPlayHooks.playPortalFromContext = runIptvPortalPlayFromContext;
    KitIptvPlayHooks.openLiveNativePlayer = _openLiveNativePlayer;
    KitIptvPlayHooks.loadActiveLiveShelf = _loadActiveLiveShelf;

    KitResolveStreamsHooks.loadTab = IptvResolveStreamsAdapter.loadTab;
    KitResolveStreamsHooks.playRow = IptvResolveStreamsAdapter.playRow;
    KitResolveStreamsHooks.createHealthProbe = ({onResult}) =>
        IptvLazyUrlHealthProbe(onResult: onResult);
  }

  static Future<List<KitIptvRecHit>> _loadCatalogRecs({
    required MetaItem meta,
    required Object portal,
    required Object? shelf,
    required Object? rich,
  }) async {
    if (portal is! VerifiedPortal) return const [];
    if (rich is! RichMediaDetails) return const [];

    List<IptvStream> catalog;
    if (shelf is List<IptvStream>) {
      catalog = shelf;
    } else if (shelf is IptvCatalogShelfSnap) {
      catalog = shelf.streams;
    } else {
      catalog = [];
      for (final section in [IptvSection.vod, IptvSection.series]) {
        final disk = await IptvCatalogDiskStore.load(portal.key, section);
        if (disk != null) catalog.addAll(disk.streams);
      }
    }

    final stream = iptvStreamFromMeta(meta);
    final hits = filterIptvCatalogRecommendations(
      recommendations: rich.extras.recommendations,
      catalog: catalog,
      excludeStreamId: stream.streamId,
    );
    return [
      for (final h in hits) KitIptvRecHit(movie: h.tmdb, stream: h.stream),
    ];
  }

  static Future<void> _openVodStream(
    BuildContext context, {
    required Object stream,
    required Object portal,
  }) async {
    if (stream is! IptvStream || portal is! VerifiedPortal) return;
    await openIptvVodStream(context, stream: stream, portal: portal);
  }

  static Future<void> _openLiveNativePlayer(
    BuildContext context, {
    required List<dynamic> sources,
    required String title,
    String? subtitle,
    String? logoUrl,
    BuiltInPlayerContext engineContext = BuiltInPlayerContext.live,
    dynamic liveSourceKind,
    dynamic liveEngineResolveSource,
    bool titleTracksSource = true,
    bool vodPlayback = false,
    bool onlineSubtitles = false,
  }) async {
    final typed = <IptvPlaySource>[
      for (final s in sources)
        if (s is IptvPlaySource) s,
    ];
    await openForjaLiveNativePlayer(
      context,
      sources: typed,
      title: title,
      subtitle: subtitle,
      logoUrl: logoUrl,
      engineContext: engineContext,
      liveSourceKind: liveSourceKind is IptvLiveSourceKind
          ? liveSourceKind
          : null,
      liveEngineResolveSource:
          liveEngineResolveSource is IptvLiveEngineResolveSource
              ? liveEngineResolveSource
              : null,
      titleTracksSource: titleTracksSource,
      vodPlayback: vodPlayback,
      onlineSubtitles: onlineSubtitles,
    );
  }

  static Future<Object?> _loadActiveLiveShelf() async {
    final portal = await IptvChannelSearch.resolvePortal();
    if (portal == null) return null;
    return IptvCatalogDiskStore.load(portal.key, IptvSection.live);
  }
}
