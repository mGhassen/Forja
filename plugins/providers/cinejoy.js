var SPECS = {
  "origin": "https://cinejoy.to",
  "api": "https://api.shegu.st",
  "enc": "https://enc-dec.app/api",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var origin = cfg.origin.replace(/\/$/, '');
  var api = cfg.api.replace(/\/$/, '');
  var enc = cfg.enc.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    Accept: '*/*',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua,
  };
  var isTv = ctx.type !== 'movie';

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o)) o.forEach(function (e) { walk(e, urls); });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link', 'source'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  function toRows(payload, label) {
    var urls = [];
    walk(payload, urls);
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            {
              url: u,
              name: 'CineJoy' + (label ? ' ' + label : ''),
              headers: { 'User-Agent': ua, Referer: origin + '/' },
            },
          ]);
        }
        return ctx.hop(u).then(function (rows) {
          return rows.map(function (r) {
            return Object.assign({}, r, { name: 'CineJoy' + (label ? ' ' + label : '') });
          });
        });
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  function fetchJson(url, extra) {
    return ctx
      .fetch(url, { headers: Object.assign({}, headers, extra || {}) })
      .then(function (r) {
        return r.json();
      });
  }

  function fetchMeta() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey) +
        '&append_to_response=external_ids',
    ).then(function (d) {
      var title = d.name || d.title || d.original_name || d.original_title || '';
      var year = ((d.first_air_date || d.release_date || '').match(/\d{4}/) || [])[0] || String(ctx.year || '');
      var imdb = (d.external_ids && d.external_ids.imdb_id) || ctx.imdbId || '';
      if (!title || !year) throw new Error('meta');
      return {
        title: title,
        year: year,
        imdb: imdb,
        tmdb: String(ctx.tmdbId || ''),
        type: isTv ? 'series' : 'movie',
        season: String(ctx.season || 1),
        episode: String(ctx.episode || 1),
      };
    });
  }

  function buildApiUrl(meta, server) {
    var q =
      'title=' +
      encodeURIComponent(meta.title) +
      '&type=' +
      encodeURIComponent(meta.type) +
      '&year=' +
      encodeURIComponent(meta.year) +
      '&imdb=' +
      encodeURIComponent(meta.imdb || '') +
      '&tmdb=' +
      encodeURIComponent(meta.tmdb) +
      '&server=' +
      encodeURIComponent(server);
    if (isTv) {
      q += '&season=' + encodeURIComponent(meta.season) + '&episode=' + encodeURIComponent(meta.episode);
    }
    return api + '/?' + q;
  }

  function resolveServer(meta, server) {
    var apiUrl = buildApiUrl(meta, server);
    return ctx
      .fetch(enc + '/enc-cinejoy?url=' + encodeURIComponent(apiUrl), { headers: headers })
      .then(function (r) {
        return r.json();
      })
      .then(function (j) {
        var token = validate(j);
        if (!token) return [];
        return fetchJson(api + '/challenge?rid=' + encodeURIComponent(token)).then(function (challenge) {
          var xat = ctx.crypto.solveScryptPow(challenge);
          if (!xat) return [];
          var reqHeaders = Object.assign({}, headers, { 'x-at': xat });
          return ctx
            .fetch(api + '/' + token, { headers: reqHeaders })
            .then(function (r) {
              return r.text();
            })
            .then(function (text) {
              return ctx
                .fetch(enc + '/dec-cinejoy', {
                  method: 'POST',
                  headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
                  body: JSON.stringify({ text: text }),
                })
                .then(function (r) {
                  return r.json();
                })
                .then(function (dj) {
                  return toRows(validate(dj), server);
                });
            });
        });
      })
      .catch(function () {
        return [];
      });
  }

  return fetchMeta()
    .then(function (meta) {
      return fetchJson(api + '/servers').then(function (sj) {
        var servers = ((sj && sj.servers) || []).map(function (s) {
          return s && (s.name || s.id || s);
        }).filter(Boolean);
        if (!servers.length) return [];
        return Promise.all(servers.slice(0, 6).map(function (name) { return resolveServer(meta, name); })).then(
          function (groups) {
            return [].concat.apply([], groups);
          },
        );
      });
    })
    .catch(function () {
      return [];
    });
}
