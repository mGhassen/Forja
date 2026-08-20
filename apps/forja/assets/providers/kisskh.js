function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = (cfg.origin || 'https://kisskh.co').replace(/\/$/, '');
  var tmdbId = String(ctx.tmdbId || '');
  var title = String(ctx.title || '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: 'application/json', Referer: origin + '/' };
  var episodeId = cfg.episodeId || ctx.config.episodeId;

  function rowsFromEpisode(api) {
    if (!api || typeof api !== 'object') return Promise.resolve([]);
    var urls = [];
    ['Video', 'video', 'VideoUrl', 'videoUrl'].forEach(function (k) {
      if (api[k] && /^https?:/i.test(String(api[k]))) urls.push(String(api[k]));
    });
    (api.ThirdParty || api.thirdParty || []).forEach(function (e) {
      var u = e && (e.src || e.url);
      if (u) urls.push(u);
    });
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            { url: u, name: 'KissKh', headers: { 'User-Agent': ua, Referer: origin + '/', Origin: origin } },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  function episodeUrl(id, withKkey) {
    var q = '.png?err=false&ts=&time=';
    if (withKkey && ctx.crypto && ctx.crypto.kisskhKkey) {
      q += '&kkey=' + encodeURIComponent(ctx.crypto.kisskhKkey(id, 'video'));
    }
    return origin + '/api/DramaList/Episode/' + id + q;
  }

  function fetchEpisode(id) {
    function tryOnce(withKkey) {
      return ctx
        .fetch(episodeUrl(id, withKkey), { headers: headers })
        .then(function (r) {
          if (!r.ok) return null;
          return r.json();
        })
        .then(function (api) {
          if (!api) return [];
          var hasVideo =
            (api.Video || api.video || api.VideoUrl || api.videoUrl) ||
            ((api.ThirdParty || api.thirdParty || []).length > 0);
          if (!hasVideo) return [];
          return rowsFromEpisode(api);
        })
        .catch(function () {
          return [];
        });
    }
    // Miru kisskh.co works without kkey; some mirrors still require consumet kkey.
    return tryOnce(false).then(function (rows) {
      if (rows && rows.length) return rows;
      return tryOnce(true);
    });
  }

  if (episodeId) return fetchEpisode(episodeId).catch(function () { return []; });

  var q = encodeURIComponent(title);
  if (!q) return Promise.resolve([]);
  return ctx
    .fetch(origin + '/api/DramaList/Search?q=' + q + '&type=0', { headers: headers })
    .then(function (r) {
      return r.json();
    })
    .then(function (list) {
      var hit =
        (Array.isArray(list) ? list : []).find(function (d) {
          return String(d.tmdbID || d.tmdbId || '') === tmdbId;
        }) ||
        (Array.isArray(list) ? list[0] : null);
      if (!hit) return [];
      var dramaId = hit.id;
      return ctx
        .fetch(origin + '/api/DramaList/Drama/' + dramaId + '?isq=false', { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (drama) {
          var eps = drama.episodes || drama.Episodes || [];
          var want = Number(ctx.episode || 1);
          var ep =
            eps.find(function (e) {
              return Number(e.number || e.Number) === want;
            }) || eps[0];
          if (!ep) return [];
          return fetchEpisode(ep.id || ep.Id);
        });
    })
    .catch(function () {
      return [];
    });
}
