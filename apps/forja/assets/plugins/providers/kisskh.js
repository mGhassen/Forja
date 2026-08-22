function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = (cfg.origin || 'https://kisskh.co').replace(/\/$/, '');
  var tmdbId = String(ctx.tmdbId || '');
  var title = String(ctx.title || '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Accept: 'application/json', Referer: origin + '/' };
  // Hub Sources injects KissKh drama/episode ids — Search never returns tmdbID.
  var episodeId = cfg.episodeId || ctx.config.episodeId;
  var dramaId = cfg.dramaId || ctx.config.dramaId;
  ctx.log(
    'kisskh start dramaId=' +
      (dramaId || '') +
      ' episodeId=' +
      (episodeId || '') +
      ' title=' +
      title +
      ' ep=' +
      (ctx.episode || 1) +
      ' hasKkey=' +
      !!(ctx.crypto && ctx.crypto.kisskhKkey),
  );

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
            {
              url: u,
              name: 'KissKh',
              headers: { 'User-Agent': ua, Referer: origin + '/', Origin: origin },
            },
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
      if (withKkey && !(ctx.crypto && ctx.crypto.kisskhKkey)) {
        ctx.log('kisskh kkey missing — Episode API will return SPA HTML');
        return Promise.resolve([]);
      }
      return ctx
        .fetch(episodeUrl(id, withKkey), { headers: headers })
        .then(function (r) {
          return r.text().then(function (body) {
            var trimmed = String(body || '').trim();
            if (!r.ok) {
              ctx.log('kisskh episode HTTP ' + r.status + ' kkey=' + !!withKkey);
              return null;
            }
            // Without kkey, kisskh.co serves the SPA shell (200 + HTML).
            if (!trimmed || trimmed.charAt(0) === '<') {
              ctx.log('kisskh episode HTML shell (need kkey) kkey=' + !!withKkey);
              return null;
            }
            try {
              return JSON.parse(trimmed);
            } catch (e) {
              ctx.log('kisskh episode JSON parse fail kkey=' + !!withKkey);
              return null;
            }
          });
        })
        .then(function (api) {
          if (!api) return [];
          var hasVideo =
            (api.Video || api.video || api.VideoUrl || api.videoUrl) ||
            ((api.ThirdParty || api.thirdParty || []).length > 0);
          if (!hasVideo) {
            ctx.log('kisskh episode JSON has no Video/ThirdParty');
            return [];
          }
          return rowsFromEpisode(api);
        })
        .catch(function (e) {
          ctx.log('kisskh episode error: ' + (e && e.message ? e.message : e));
          return [];
        });
    }
    // API requires consumet kkey; bare GET returns HTML.
    return tryOnce(true);
  }

  function episodeFromDrama(drama) {
    var eps = drama.episodes || drama.Episodes || [];
    var want = Number(ctx.episode || 1);
    var ep =
      eps.find(function (e) {
        return Number(e.number || e.Number) === want;
      }) || eps[0];
    if (!ep) return [];
    return fetchEpisode(ep.id || ep.Id);
  }

  function fetchDrama(id) {
    return ctx
      .fetch(origin + '/api/DramaList/Drama/' + id + '?isq=false', { headers: headers })
      .then(function (r) {
        return r.json();
      })
      .then(episodeFromDrama);
  }

  if (episodeId) return fetchEpisode(episodeId).catch(function () { return []; });
  if (dramaId) return fetchDrama(dramaId).catch(function () { return []; });

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
      return fetchDrama(hit.id);
    })
    .catch(function () {
      return [];
    });
}
