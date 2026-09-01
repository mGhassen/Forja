import 'package:flutter/material.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/data/storage.dart';
import 'package:forja/features/iptv/iptv_title_clean.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/features/iptv/screens/iptv_series_episode_list.dart';
import 'package:forja/shared/design/src/forja_toast.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_screen.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';

/// Build hub seed meta from a portal stream (host prefetches episodes for series).
CatalogMetaItem catalogMetaFromIptvStream({
  required IptvStream stream,
  required VerifiedPortal portal,
  List<IptvEpisode>? episodes,
}) {
  final cleaned = cleanIptvMediaTitle(stream.name);
  final displayName =
      cleaned.title.isNotEmpty ? cleaned.title : stream.name.trim();
  final isMovie = stream.kind == 'vod';
  final mediaType = isMovie ? 'movie' : 'tv';
  final metaId = 'iptv:${portal.key}:${stream.streamId}';

  final videos = [
    for (final e in episodes ?? const <IptvEpisode>[])
      CatalogVideo(
        id: e.id,
        title: e.title.trim().isNotEmpty ? e.title : 'Episode ${e.episode}',
        season: e.season,
        episode: e.episode,
        thumbnail: e.image,
      ),
  ];

  final plot = episodes
          ?.map((e) => e.plot.trim())
          .firstWhere((p) => p.isNotEmpty, orElse: () => '') ??
      '';

  return CatalogMetaItem(
    id: metaId,
    type: mediaType,
    name: displayName,
    poster: stream.icon,
    background: stream.icon,
    description: plot,
    releaseInfo: cleaned.year?.toString() ?? '',
    badge: isMovie ? 'MOVIE' : 'TV',
    videos: videos,
    open: CatalogOpen(
      surface: 'iptv',
      id: stream.streamId,
      extract: CatalogOpenExtract(
        resolveType: 'iptv',
        panelCategory: 'iptv',
        ctx: {
          'portalKey': portal.key,
          'streamId': stream.streamId,
          'kind': stream.kind,
          'platform': portal.portal.platform.wire,
          'containerExt': stream.containerExt,
          'categoryId': stream.categoryId,
        },
      ),
      extras: {
        'movie': isMovie,
        'kind': stream.kind,
        'portalKey': portal.key,
        'streamId': stream.streamId,
        'name': displayName,
        'icon': stream.icon,
        'plot': plot,
        'categoryId': stream.categoryId,
        'containerExt': stream.containerExt,
        'platform': portal.portal.platform.wire,
        'streamName': stream.name,
        'streamIcon': stream.icon,
        if (episodes != null)
          'portalEpisodes': [
            for (final e in episodes)
              {
                'id': e.id,
                'title': e.title,
                'season': e.season,
                'episode': e.episode,
                'image': e.image,
                'plot': e.plot,
              },
          ],
      },
    ),
  );
}

/// Params for pack `details` — includes portal snapshot from [hubDetailsParams].
Map<String, dynamic> iptvHubDetailsParams(CatalogMetaItem seed) {
  final params = hubDetailsParams(seed);
  final open = seed.open;
  if (open != null) {
    params['name'] ??= seed.name;
    params['icon'] ??= seed.poster;
    params['plot'] ??= seed.description;
    params['kind'] ??= open.extras['kind'] ?? open.extraString('kind');
    params['portalKey'] ??= open.extras['portalKey'];
    params['streamId'] ??= open.id;
    params['portalEpisodes'] ??= open.extras['portalEpisodes'];
  }
  return params;
}

Future<VerifiedPortal?> resolveIptvPortalFromMeta(CatalogMetaItem meta) async {
  final ctx = meta.open?.effectiveExtract.ctx ?? const {};
  final portalKey = ctx['portalKey']?.toString();
  if (portalKey == null || portalKey.isEmpty) return null;
  final portals = await IptvStore.load();
  for (final p in portals) {
    if (p.key == portalKey) return p;
  }
  return null;
}

IptvStream iptvStreamFromMeta(CatalogMetaItem meta) {
  final open = meta.open;
  final ctx = open?.effectiveExtract.ctx ?? const {};
  final extras = open?.extras ?? const {};
  final kind = ctx['kind']?.toString() ??
      extras['kind']?.toString() ??
      (hubMetaIsMovie(meta) ? 'vod' : 'series');
  return IptvStream(
    streamId: ctx['streamId']?.toString() ?? open?.id ?? meta.id,
    name: extras['streamName']?.toString() ?? meta.name,
    icon: extras['streamIcon']?.toString() ?? meta.poster,
    categoryId: ctx['categoryId']?.toString() ??
        extras['categoryId']?.toString() ??
        '',
    containerExt: ctx['containerExt']?.toString() ??
        extras['containerExt']?.toString() ??
        '',
    kind: kind,
  );
}

/// Installed IPTV VOD details pack plugin id, if any.
Future<String?> iptvVodDetailsPluginId() =>
    PluginNavRegistry.pluginIdForEngineType('iptv');

/// Returns false when scripts are still downloading — caller should abort open.
Future<bool> ensureIptvVodPluginReady(String pluginId) async {
  final coordinator = PluginInstallCoordinator.instance;
  if (coordinator.isInstalling) {
    final msg = await coordinator.pluginNotReadyMessage(pluginId);
    if (msg != null) ForjaToast.info(msg);
    return false;
  }
  final ready = await coordinator.ensurePluginReady(pluginId);
  if (ready) return true;
  final msg = await coordinator.pluginNotReadyMessage(pluginId);
  ForjaToast.error(msg ?? 'IPTV plugin is not ready yet');
  return false;
}

/// Movie/series tap — hub details when pack is installed; otherwise direct play
/// (movies) or portal episode list (series).
Future<void> openIptvVodStream(
  BuildContext context, {
  required IptvStream stream,
  required VerifiedPortal portal,
}) async {
  final pluginId = await iptvVodDetailsPluginId();
  if (!context.mounted) return;
  if (pluginId != null && pluginId.isNotEmpty) {
    if (!await ensureIptvVodPluginReady(pluginId)) return;
    if (!context.mounted) return;
    await openIptvVodDetails(
      context,
      stream: stream,
      portal: portal,
      pluginId: pluginId,
    );
    return;
  }
  if (stream.kind == 'vod') {
    await playIptvVodMovieDirect(context, stream: stream, portal: portal);
    return;
  }
  if (stream.kind == 'series') {
    await openIptvSeriesEpisodeList(
      context,
      series: stream,
      portal: portal,
    );
  }
}

/// Direct portal movie play — no details overlay.
Future<void> playIptvVodMovieDirect(
  BuildContext context, {
  required IptvStream stream,
  required VerifiedPortal portal,
}) async {
  final url = await IptvClient.resolvePlayUrl(
    portal.portal,
    stream,
    section: stream.kind,
  );
  if (!context.mounted) return;
  if (url == null || url.isEmpty) {
    ForjaToast.error('Could not open stream');
    return;
  }
  await IptvPtPlayerScreen.open(
    context,
    IptvPtPlayerScreen.singleStream(
      url: url,
      stream: stream,
      portalName: portal.displayLabel,
      portalPlatform: portal.portal.platform,
    ),
  );
}

/// Open IPTV VOD / series in the shared hub details kit (pack required).
Future<void> openIptvVodDetails(
  BuildContext context, {
  required IptvStream stream,
  required VerifiedPortal portal,
  String? pluginId,
}) async {
  final resolved = pluginId ?? await iptvVodDetailsPluginId();
  if (resolved == null || resolved.isEmpty) return;

  List<IptvEpisode>? episodes;
  if (stream.kind == 'series') {
    try {
      episodes = await IptvClient.seriesEpisodes(
        portal.portal,
        stream.streamId,
      );
    } catch (_) {
      episodes = const [];
    }
  }

  if (!context.mounted) return;
  final seed = catalogMetaFromIptvStream(
    stream: stream,
    portal: portal,
    episodes: episodes,
  );
  await openHubDetails(
    context,
    pluginId: resolved,
    item: seed,
    shellTabId: 'iptv',
  );
}
