// IPTV VOD details — portal-only meta (protocol 1). No TMDB here; see iptv-enrich-tmdb.

function iptvEpisodeVideos(raw) {
  if (!Array.isArray(raw)) return [];
  var out = [];
  for (var i = 0; i < raw.length; i++) {
    var e = raw[i] || {};
    var id = String(e.id || e.episodeId || '').trim();
    if (!id) continue;
    var season = Number(e.season);
    var episode = Number(e.episode);
    out.push({
      id: id,
      title: String(e.title || e.name || '').trim() || 'Episode ' + (episode > 0 ? episode : i + 1),
      season: season > 0 ? season : 1,
      episode: episode > 0 ? episode : i + 1,
      thumbnail: String(e.image || e.thumbnail || '').trim(),
    });
  }
  out.sort(function (a, b) {
    if (a.season !== b.season) return a.season - b.season;
    return a.episode - b.episode;
  });
  return out;
}

function iptvVodDetails(params) {
  var streamId = String(params.streamId || params.id || '').trim();
  var portalKey = String(params.portalKey || '').trim();
  if (!streamId || !portalKey) {
    return hubFail(
      'details',
      'INVALID_PARAMS',
      'details needs portalKey and streamId',
    );
  }

  var kind = String(params.kind || '').trim();
  var isMovie =
    kind === 'vod' ||
    kind === 'movie' ||
    params.movie === true ||
    params.movie === 'true';
  var type = isMovie ? 'movie' : 'tv';
  var name = String(params.name || params.title || '').trim() || 'Unknown';
  var icon = String(params.icon || params.poster || '').trim();
  var plot = String(params.plot || params.description || '').trim();

  var videos = iptvEpisodeVideos(params.portalEpisodes || params.episodes);
  var metaId = 'iptv:' + portalKey + ':' + streamId;

  var meta = {
    id: metaId,
    type: type,
    name: name,
    poster: icon,
    background: icon,
    description: plot,
    badge: isMovie ? 'MOVIE' : 'TV',
    open: {
      surface: 'iptv',
      id: streamId,
      movie: isMovie,
      kind: kind || (isMovie ? 'vod' : 'series'),
      portalKey: portalKey,
      streamName: name,
      streamIcon: icon,
      categoryId: String(params.categoryId || ''),
      containerExt: String(params.containerExt || ''),
      platform: String(params.platform || ''),
      extract: {
        resolveType: 'iptv',
        panelCategory: 'iptv',
        ctx: {
          portalKey: portalKey,
          streamId: streamId,
          kind: kind || (isMovie ? 'vod' : 'series'),
          platform: String(params.platform || ''),
          containerExt: String(params.containerExt || ''),
          categoryId: String(params.categoryId || ''),
        },
      },
    },
  };

  if (videos.length) meta.videos = videos;
  return hubOk('details', { meta: meta }, { maxAge: 300, swr: 900 });
}

function extract(ctx) {
  var action = hubAction(ctx);
  var params = hubParams(ctx);

  if (action === 'details') {
    return Promise.resolve(iptvVodDetails(params));
  }

  return hubFail(action, 'INVALID_ACTION', 'iptv-vod only supports action details');
}
