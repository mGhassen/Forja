function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://senshi.live').replace(/\/$/, '');
  var mapApi = cfg.mapApi || 'https://id-mapping-api-malid.hf.space/api/resolve';
  var jikan = cfg.jikan || 'https://api.jikan.moe/v4/anime';
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua = 'Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'application/json' };
  var isTv = ctx.type === 'tv';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchJson(url) {
    return ctx.fetch(url, { headers: hdrs }).then(function (r) {
      return r.json();
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

  function isDub(status) {
    return String(status || '').toLowerCase() === 'dub';
  }

  function fetchEmbeds(malId, episode) {
    return fetchJson(base + '/episode-embeds/' + malId + '/' + episode).then(function (data) {
      return Array.isArray(data) ? data : [];
    });
  }

  function pickSource(embeds, wantDub) {
    for (var i = 0; i < embeds.length; i++) {
      if (wantDub ? isDub(embeds[i].status) : !isDub(embeds[i].status)) return embeds[i];
    }
    return embeds[0] || null;
  }

  function rowsFromSource(source, audio) {
    if (!source) return [];
    var rows = [];
    if (source.url) {
      rows.push({
        url: source.url,
        name: 'Senshi',
        headers: hdrs,
        language: audio === 'dub' ? 'Dub' : 'Sub',
      });
    }
    var embedTasks = [];
    if (source.server2) embedTasks.push(ctx.hop(source.server2));
    if (source.serverFM) embedTasks.push(ctx.hop(source.serverFM));
    return Promise.all(embedTasks).then(function (groups) {
      var hopped = [].concat.apply([], groups || []);
      hopped.forEach(function (r) {
        rows.push(Object.assign({}, r, { name: r.name || 'Senshi embed', language: audio === 'dub' ? 'Dub' : 'Sub' }));
      });
      return rows;
    });
  }

  return resolveMal()
    .then(function (mal) {
      if (!mal) return ctx.host('senshi');
      return fetchEmbeds(mal, epNum).then(function (embeds) {
        if (!embeds.length) return ctx.host('senshi');
        return rowsFromSource(pickSource(embeds, false), 'sub').then(function (sub) {
          if (sub.length) return sub;
          return rowsFromSource(pickSource(embeds, true), 'dub');
        });
      });
    })
    .then(function (rows) {
      return rows && rows.length ? rows : ctx.host('senshi');
    })
    .catch(function () {
      return ctx.host('senshi');
    });
}
