function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://epeng.animeapps.top').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var armBase = (cfg.armBase || 'https://arm.haglund.dev/api/v2').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'application/json' };
  var isTv = ctx.type === 'tv';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchJson(url, extra) {
    return ctx
      .fetch(url, { headers: Object.assign({}, hdrs, extra || {}) })
      .then(function (r) {
        return r.json();
      });
  }

  function fetchText(url, extra) {
    return ctx
      .fetch(url, { headers: Object.assign({}, hdrs, extra || {}, { Accept: 'text/html,application/xhtml+xml' }) })
      .then(function (r) {
        return r.text();
      });
  }

  function resolveMal() {
    var fromHost = globalThis.__engineCtxMal && globalThis.__engineCtxMal(ctx);
    if (fromHost) return Promise.resolve(fromHost.malId);
    if (!isTv) {
      return fetchJson(
        'https://api.themoviedb.org/3/movie/' +
          encodeURIComponent(String(ctx.tmdbId || '')) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
      )
        .then(function (d) {
          var title = d.title || d.original_title || '';
          if (!title) return null;
          return fetchJson(jikan + '?q=' + encodeURIComponent(title) + '&type=movie&limit=1').then(function (j) {
            return j && j.data && j.data[0] ? j.data[0].mal_id : null;
          });
        })
        .catch(function () {
          return null;
        });
    }
    var imdbP = ctx.imdbId
      ? Promise.resolve(String(ctx.imdbId))
      : fetchJson(
          'https://api.themoviedb.org/3/tv/' +
            encodeURIComponent(String(ctx.tmdbId || '')) +
            '/external_ids?api_key=' +
            encodeURIComponent(tmdbKey),
        )
          .then(function (d) {
            return (d && d.imdb_id) || '';
          })
          .catch(function () {
            return '';
          });
    return imdbP.then(function (imdbId) {
      if (!imdbId) return null;
      return fetchJson(
        mapApi +
          '?id=' +
          encodeURIComponent(imdbId) +
          '&s=' +
          encodeURIComponent(String(ctx.season || 1)) +
          '&e=' +
          encodeURIComponent(String(epNum)),
      )
        .then(function (m) {
          return m && m.mal_id ? m.mal_id : null;
        })
        .catch(function () {
          return null;
        });
    });
  }

  function resolveAnilist(malId) {
    var fromHost = globalThis.__engineCtxAnilist && globalThis.__engineCtxAnilist(ctx);
    if (fromHost) return Promise.resolve(fromHost);
    return fetchJson(armBase + '/ids?source=myanimelist&id=' + encodeURIComponent(String(malId))).then(function (d) {
      return d && d.anilist ? d.anilist : null;
    });
  }

  function audioFromServerName(name) {
    return /dub/i.test(String(name || '')) ? 'dub' : 'sub';
  }

  function fetchServers(anilistId) {
    return fetchJson(api + '/api2.php?epid=' + encodeURIComponent(String(anilistId))).then(function (data) {
      return Array.isArray(data) ? data : [];
    });
  }

  function findEpisodeLink(groups, audio, episode) {
    for (var i = 0; i < groups.length; i++) {
      if (audioFromServerName(groups[i].server_name) !== audio) continue;
      var eps = groups[i].server_data || [];
      for (var j = 0; j < eps.length; j++) {
        if (Number(eps[j].name || eps[j].slug) === Number(episode)) return eps[j].link;
      }
    }
    return null;
  }

  function fetchPlayerLinks(providerLink) {
    return fetchJson(api + '/apilink.php?data=' + encodeURIComponent(providerLink)).then(function (data) {
      return Array.isArray(data) ? data : [];
    });
  }

  function extractVideoUrl(html, origin) {
    var m = html.match(/videoUrl\s*:\s*"([^"]+)"/);
    if (!m) return null;
    var raw = m[1];
    if (/^https?:\/\//i.test(raw)) return raw;
    return origin + (raw.charAt(0) === '/' ? '' : '/') + raw;
  }

  function resolvePlayerStream(playerLink) {
    var origin = playerLink.match(/^https?:\/\/[^/]+/)[0];
    var referer = origin + '/';
    return fetchText(playerLink, { Referer: referer }).then(function (html) {
      var hls = extractVideoUrl(html, origin);
      if (!hls) throw new Error('no videoUrl');
      return { hls: hls, referer: referer };
    });
  }

  function streamsFor(anilistId, audio, episode) {
    return fetchServers(anilistId).then(function (groups) {
      var link = findEpisodeLink(groups, audio, episode);
      if (!link) return [];
      return fetchPlayerLinks(link).then(function (servers) {
        var tasks = [];
        for (var i = 0; i < servers.length; i++) {
          if (!servers[i] || !servers[i].link) continue;
          (function (entry) {
            tasks.push(
              resolvePlayerStream(entry.link)
                .then(function (resolved) {
                  return [
                    {
                      url: resolved.hls,
                      name: 'AniBD ' + (entry.server || audio.toUpperCase()),
                      headers: { 'User-Agent': ua, Referer: resolved.referer },
                      language: audio === 'dub' ? 'Dub' : 'Sub',
                    },
                  ];
                })
                .catch(function () {
                  return ctx.hop(entry.link).then(function (rows) {
                    return rows.map(function (r) {
                      return Object.assign({}, r, { name: 'AniBD ' + (entry.server || 'embed'), language: audio === 'dub' ? 'Dub' : 'Sub' });
                    });
                  });
                }),
            );
          })(servers[i]);
        }
        return Promise.all(tasks).then(function (groups2) {
          return [].concat.apply([], groups2);
        });
      });
    });
  }

  return resolveMal()
    .then(function (mal) {
      if (!mal) return ctx.host('anibd');
      return resolveAnilist(mal).then(function (alId) {
        if (!alId) return ctx.host('anibd');
        return streamsFor(alId, 'sub', epNum)
          .then(function (sub) {
            if (sub.length) return sub;
            return streamsFor(alId, 'dub', epNum);
          })
          .then(function (rows) {
            return rows.length ? rows : ctx.host('anibd');
          });
      });
    })
    .catch(function () {
      return ctx.host('anibd');
    });
}
