var SPECS = {
  "base": "https://kurage.live",
  "tmdbKey": "439c478a771f35c05022f9feabcca01c",
  "anilistUrl": "https://graphql.anilist.co",
  "armBase": "https://arm.haglund.dev/api/v2",
  "cinemetaUrl": "https://v3-cinemeta.strem.io/meta"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var anilistUrl = cfg.anilistUrl;
  var armBase = cfg.armBase;
  var cinemetaUrl = cfg.cinemetaUrl;
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'application/json, text/plain, */*', Origin: base, Referer: base + '/' };
  var isTv = ctx.type !== 'movie';

  function fetchJson(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) })
      .then(function (r) { return r.json(); });
  }

  function getSyncInfo(id, season, episode) {
    var kind = isTv ? 'tv' : 'movie';
    var tmdbBase = 'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(id));
    return Promise.all([
      fetchJson(tmdbBase + (isTv ? '/external_ids' : '') + '?api_key=' + encodeURIComponent(tmdbKey)),
      fetchJson(tmdbBase + '?api_key=' + encodeURIComponent(tmdbKey)),
    ]).then(function (pair) {
      var details = pair[0];
      var meta = pair[1];
      var imdbId = details.imdb_id || null;
      var title = meta.name || meta.title || null;
      if (!imdbId) {
        return fetchJson(armBase + '/themoviedb?id=' + encodeURIComponent(String(id))).then(function (arm) {
          imdbId = Array.isArray(arm) && arm.length ? arm[0].imdb : null;
          if (!imdbId) throw new Error('no imdb');
          return { imdbId: imdbId, title: title, releaseDate: null, episodeTitle: null, dayIndex: 1, episode: episode };
        });
      }
      var cType = isTv ? 'series' : 'movie';
      return fetchJson(cinemetaUrl + '/' + cType + '/' + imdbId + '.json').then(function (cData) {
        var cMeta = cData.meta;
        var releaseDate = null;
        var episodeTitle = null;
        var dayIndex = 1;
        if (!isTv) {
          releaseDate = (cMeta && cMeta.released) ? cMeta.released.split('T')[0] : meta.release_date;
        } else {
          var videos = (cMeta && cMeta.videos) || [];
          var target = videos.find(function (v) { return v.season == season && v.episode == episode; });
          if (target && target.released) {
            releaseDate = target.released.split('T')[0];
            episodeTitle = target.name || null;
            dayIndex = videos.filter(function (v) {
              return v.season == season && v.released && v.released.split('T')[0] === releaseDate &&
                parseInt(v.episode, 10) < parseInt(episode, 10);
            }).length + 1;
          }
        }
        if (!releaseDate && meta.release_date) releaseDate = meta.release_date;
        if (!releaseDate) throw new Error('no date');
        return { imdbId: imdbId, title: title, releaseDate: releaseDate, episodeTitle: episodeTitle, dayIndex: dayIndex, episode: episode };
      });
    });
  }

  function resolveAnilist(syncInfo) {
    var query = 'query($search:String){Page(perPage:20){media(search:$search,type:ANIME){id type format title{romaji english}startDate{year month day}endDate{year month day}episodes streamingEpisodes{title}}}}';
    return ctx.fetch(anilistUrl, {
      method: 'POST',
      headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
      body: JSON.stringify({ query: query, variables: { search: syncInfo.title } }),
    }).then(function (r) { return r.json(); }).then(function (json) {
      var candidates = (((json.data || {}).Page || {}).media) || [];
      var targetDate = new Date(syncInfo.releaseDate);
      for (var i = 0; i < candidates.length; i++) {
        var anime = candidates[i];
        var s = anime.startDate || {};
        if (!s.year || !s.month || !s.day) continue;
        var startStr = s.year + '-' + String(s.month).padStart(2, '0') + '-' + String(s.day).padStart(2, '0');
        var startDate = new Date(startStr);
        var diffDays = Math.ceil(Math.abs(targetDate - startDate) / 86400000);
        var isMatch = false;
        if (anime.format === 'MOVIE' || anime.format === 'SPECIAL' || anime.episodes === 1) {
          if (diffDays <= 2) isMatch = true;
        } else {
          var startLimit = new Date(startDate);
          startLimit.setDate(startLimit.getDate() - 2);
          if (targetDate >= startLimit) {
            if (anime.endDate && anime.endDate.year) {
              var endDate = new Date(anime.endDate.year, (anime.endDate.month || 12) - 1, anime.endDate.day || 31);
              endDate.setDate(endDate.getDate() + 2);
              if (targetDate <= endDate) isMatch = true;
            } else isMatch = true;
          }
        }
        if (!isMatch) continue;
        var isTV = anime.format !== 'MOVIE' && anime.format !== 'SPECIAL' && anime.episodes !== 1;
        var episodeNum = isTV && syncInfo.episode ? syncInfo.episode : syncInfo.dayIndex || 1;
        var episodes = anime.streamingEpisodes || [];
        if (episodes.length > 1 && syncInfo.episodeTitle) {
          var cleanTarget = syncInfo.episodeTitle.toLowerCase().replace(/[^a-z0-9]/g, '');
          for (var j = 0; j < episodes.length; j++) {
            var cleanAl = String(episodes[j].title || '').toLowerCase().replace(/[^a-z0-9]/g, '');
            if (cleanAl && (cleanAl.indexOf(cleanTarget) >= 0 || cleanTarget.indexOf(cleanAl) >= 0)) {
              episodeNum = j + 1;
              break;
            }
          }
        }
        return { alId: anime.id, episode: episodeNum, title: syncInfo.title };
      }
      return null;
    });
  }

  var season = ctx.season || 1;
  var episode = ctx.episode || 1;
  return getSyncInfo(ctx.tmdbId, season, episode).then(function (syncInfo) {
    return resolveAnilist(syncInfo);
  }).then(function (resolved) {
    if (!resolved || !resolved.alId) return [];
    var input = {
      '0': { json: { id: resolved.alId } },
      '1': { json: { animeId: resolved.alId, episode: resolved.episode, language: 'sub' } },
      '2': { json: { animeId: resolved.alId, episode: resolved.episode, language: 'dub' } },
    };
    var url = base + '/api/trpc/catalog.anilistInfo,episodes.source,episodes.source?batch=1&input=' +
      encodeURIComponent(JSON.stringify(input));
    return fetchJson(url, { 'trpc-accept': 'application/json', 'x-trpc-source': 'nextjs-react' }).then(function (data) {
      var streams = [];
      (data || []).forEach(function (r) {
        var servers = ((((r.result || {}).data || {}).json) || {}).servers || [];
        servers.forEach(function (server) {
          var streamUrl = server.url && server.url.charAt(0) === '/' ? base + server.url : server.url;
          var extraHeaders = {};
          try {
            var hp = new URL(streamUrl).searchParams.get('headers');
            if (hp) extraHeaders = JSON.parse(atob(hp));
          } catch (e) {}
          var lang = String(server.language || 'sub').toUpperCase();
          streams.push({
            name: '[' + lang + '] Kurage - ' + (server.label || 'Stream'),
            url: streamUrl,
            quality: 'Auto',
            headers: Object.assign({}, hdrs, extraHeaders),
          });
        });
      });
      return streams;
    });
  }).catch(function () { return []; });
}
