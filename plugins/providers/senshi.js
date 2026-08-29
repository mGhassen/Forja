var SPECS = {
  "base": "https://senshi.live",
  "mapApi": "https://id-mapping-api-malid.hf.space/api/resolve",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49",
  "jikan": "https://api.jikan.moe/v4/anime"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var mapApi = cfg.mapApi;
  var jikan = cfg.jikan;
  var tmdbKey = cfg.tmdbKey;
  var ua = 'Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0';
  // ninstream and similar CDNs whitelist senshi.live — keep Referer fixed.
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Origin: base, Accept: 'application/json,*/*' };
  var isTv = ctx.type !== 'movie';
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

  function embedType(embed) {
    var status = String(
      (embed && (embed.status || embed.type || embed.lang || embed.audio)) || '',
    ).toLowerCase();
    if (status.indexOf('dub') >= 0 || status === 'en' || status.indexOf('english') >= 0) return 'dub';
    if (status.indexOf('raw') >= 0) return 'raw';
    return 'sub';
  }

  function fetchEmbeds(malId, episode) {
    return fetchJson(base + '/episode-embeds/' + malId + '/' + episode).then(function (data) {
      return Array.isArray(data) ? data : [];
    });
  }

  function pickSources(embeds, want) {
    var out = [];
    for (var i = 0; i < embeds.length; i++) {
      if (embedType(embeds[i]) === want) out.push(embeds[i]);
    }
    return out.length ? out : embeds.slice();
  }

  function rowsFromSource(source, audio) {
    if (!source) return Promise.resolve([]);
    var lang = audio === 'dub' ? 'Dub' : audio === 'raw' ? 'Raw' : 'Sub';
    var tasks = [];
    function pushDirect(u, label) {
      if (!u || !/^https?:/i.test(String(u))) return;
      var url = String(u);
      if (/\.m3u8|\.mp4/i.test(url) || url.indexOf('/hls') >= 0) {
        tasks.push(
          Promise.resolve([
            {
              url: url,
              name: label || 'Senshi',
              headers: { 'User-Agent': ua, Referer: base + '/', Origin: base },
              language: lang,
            },
          ]),
        );
      } else {
        tasks.push(
          ctx.hop(url).then(function (rows) {
            return (rows || []).map(function (r) {
              return Object.assign({}, r, {
                name: r.name || label || 'Senshi embed',
                language: lang,
                headers: Object.assign({}, r.headers || {}, { Referer: base + '/', Origin: base }),
              });
            });
          }),
        );
      }
    }
    pushDirect(source.url, 'Senshi');
    pushDirect(source.server2, 'Senshi server2');
    pushDirect(source.serverFM, 'Senshi FM');
    if (!tasks.length) return Promise.resolve([]);
    return Promise.all(tasks).then(function (groups) {
      return [].concat.apply([], groups || []);
    });
  }

  function rowsFromEmbeds(embeds, audio) {
    var picked = pickSources(embeds, audio);
    return Promise.all(
      picked.slice(0, 4).map(function (src) {
        return rowsFromSource(src, audio);
      }),
    ).then(function (groups) {
      var seen = {};
      var out = [];
      ;[].concat.apply([], groups).forEach(function (r) {
        if (!r || !r.url || seen[r.url]) return;
        seen[r.url] = true;
        out.push(r);
      });
      return out;
    });
  }

  return resolveMal()
    .then(function (mal) {
      if (!mal) return [];
      return fetchEmbeds(mal, epNum).then(function (embeds) {
        if (!embeds.length) return [];
        return rowsFromEmbeds(embeds, 'sub').then(function (sub) {
          if (sub.length) return sub;
          return rowsFromEmbeds(embeds, 'dub').then(function (dub) {
            if (dub.length) return dub;
            return rowsFromEmbeds(embeds, 'raw');
          });
        });
      });
    })
    .then(function (rows) {
      return rows && rows.length ? rows : [];
    })
    .catch(function () {
      return [];
    });
}
