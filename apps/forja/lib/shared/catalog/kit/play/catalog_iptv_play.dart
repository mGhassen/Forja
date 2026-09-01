import 'package:flutter/material.dart';
import 'package:forja/features/iptv/data/iptv_network.dart';
import 'package:forja/features/iptv/data/models.dart';
import 'package:forja/features/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shared/design/src/forja_toast.dart';
import 'package:forja/shared/catalog/kit/details/hub_details_meta.dart';
import 'package:forja/shared/catalog/kit/play/catalog_play_context.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/shell/catalog_iptv_open.dart';
import 'package:rust/rust.dart' show BuiltInPlayerContext;

/// Portal play from hub details when `resolveType == iptv`.
Future<void> runIptvPortalPlayFromContext({
  required BuildContext context,
  required CatalogPlayContext ctx,
}) async {
  final meta = ctx.catalogMeta;
  if (meta == null) return;

  final portal = await resolveIptvPortalFromMeta(meta);
  if (portal == null || !context.mounted) {
    ForjaToast.error('Portal not found');
    return;
  }

  final stream = iptvStreamFromMeta(meta);
  final isMovie = hubMetaIsMovie(meta); // hub_details_meta

  if (isMovie) {
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
    return;
  }

  final videos = meta.videos;
  final epNum = ctx.episode ?? 1;
  CatalogVideo? selected;
  for (final v in videos) {
    if ((v.episode ?? 1) == epNum) {
      selected = v;
      break;
    }
  }
  selected ??= videos.isEmpty ? null : videos.first;
  if (selected == null) {
    ForjaToast.error('No episode selected');
    return;
  }

  final episode = IptvEpisode(
    id: selected.id,
    title: selected.title,
    containerExt: stream.containerExt,
    season: selected.season ?? 1,
    episode: selected.episode ?? epNum,
    plot: '',
    image: selected.thumbnail,
  );

  final url = await IptvClient.resolveEpisodeUrl(portal.portal, episode);
  if (!context.mounted) return;
  if (url == null || url.isEmpty) {
    ForjaToast.error('Could not open episode');
    return;
  }

  final allEps = [
    for (final v in videos)
      IptvEpisode(
        id: v.id,
        title: v.title,
        containerExt: stream.containerExt,
        season: v.season ?? 1,
        episode: v.episode ?? 1,
        plot: '',
        image: v.thumbnail,
      ),
  ];

  await IptvPtPlayerScreen.open(
    context,
    IptvPtPlayerScreen(
      sources: [
        IptvPlaySource(url: url, label: portal.displayLabel),
      ],
      title: 'Ep ${episode.episode} · ${episode.title}',
      subtitle: '${meta.name} · Season ${episode.season}',
      logoUrl: episode.image.isNotEmpty ? episode.image : stream.icon,
      engineContext: BuiltInPlayerContext.iptv,
      vodPlayback: true,
      onlineSubtitles: true,
      subtitleSearchTitle: meta.name,
      subtitleSeason: episode.season,
      subtitleEpisode: episode.episode,
      seriesEpisodes: allEps,
      seriesPortal: portal.portal,
      seriesShowTitle: meta.name,
    ),
  );
}
