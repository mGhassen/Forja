var SPECS = {
  "origin": "https://vidsync.xyz",
  "enc": "https://enc-dec.app/api",
  "servers": [
    "cinevault",
    "cinedub",
    "cinebox",
    "cineflix",
    "cinevip",
    "cinecloud",
    "cine4k"
  ]
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var origin = cfg.origin;
  var enc = cfg.enc;
  var servers = cfg.servers || [];
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    Accept: '*/*',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua,
    'X-Requested-With': 'XMLHttpRequest',
  };
  var tmdbId = String(ctx.tmdbId);
  var isMovie = ctx.type === 'movie';
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';

  function mediaMeta() {
    var title = String(ctx.title || '').trim();
    var year = String(ctx.year || '').substring(0, 4);
    if (title) return Promise.resolve({ title: title, year: year });
    var kind = isMovie ? 'movie' : 'tv';
    return ctx
      .fetch(
        'https://api.themoviedb.org/3/' +
          kind +
          '/' +
          encodeURIComponent(tmdbId) +
          '?api_key=' +
          encodeURIComponent(tmdbKey),
        { headers: { Accept: 'application/json', 'User-Agent': ua } },
      )
      .then(function (r) {
        return r.json();
      })
      .then(function (d) {
        return {
          title: (isMovie ? d.title : d.name) || '',
          year: String((isMovie ? d.release_date : d.first_air_date) || '').substring(0, 4),
        };
      });
  }

  function validate(j) {
    if (!j || j.status !== 200) return null;
    return j.result;
  }

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o)) o.forEach(function (e) { walk(e, urls); });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  function toRows(payload, name) {
    var urls = [];
    walk(payload, urls);
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            {
              url: u,
              name: name || 'VidSync',
              headers: { 'User-Agent': ua, Referer: origin + '/' },
            },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  return ctx
    .fetch(enc + '/enc-vidsync', { headers: headers })
    .then(function (r) {
      return r.json();
    })
    .then(function (j) {
      var parts = validate(j);
      var token = parts && parts.token;
      if (!token) return [];
      return mediaMeta().then(function (meta) {
        if (!meta.title) return [];
        var hdrs = Object.assign({}, headers, { 'X-Cf-Turnstile': token });
        var q =
          'title=' +
          encodeURIComponent(meta.title).replace(/%20/g, '+') +
          '&type=' +
          (isMovie ? 'movie' : 'tv') +
          '&releaseYear=' +
          encodeURIComponent(meta.year || '') +
          '&mediaId=' +
          encodeURIComponent(tmdbId) +
          '&season=' +
          (ctx.season || 1) +
          '&episode=' +
          (ctx.episode || 1);
        var tasks = servers.slice(0, 8).map(function (server) {
          var name = typeof server === 'string' ? server : server && (server.id || server.name);
          if (!name) return Promise.resolve([]);
          var url =
            origin.replace(/\/$/, '') +
            '/api/stream/fetch?' +
            q +
            '&serverName=' +
            encodeURIComponent(name);
          return ctx
            .fetch(url, { headers: hdrs })
            .then(function (r) {
              return r.text();
            })
            .then(function (text) {
              if (!text) return [];
              return ctx
                .fetch(enc + '/dec-vidsync', {
                  method: 'POST',
                  headers: Object.assign({}, hdrs, { 'Content-Type': 'application/json' }),
                  body: JSON.stringify({ text: text, id: tmdbId }),
                })
                .then(function (r) {
                  return r.json();
                })
                .then(function (dj) {
                  return toRows(validate(dj), name);
                });
            })
            .catch(function () {
              return [];
            });
        });
        return Promise.all(tasks).then(function (groups) {
          return [].concat.apply([], groups);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
