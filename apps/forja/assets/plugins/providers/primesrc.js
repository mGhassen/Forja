function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = (cfg.origin || 'https://primesrc.me').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var isTv = ctx.type !== 'movie';
  var tmdbId = String(ctx.tmdbId || '').trim();
  if (!tmdbId) return Promise.resolve([]);

  var embedReferer = isTv
    ? origin +
      '/embed/tv?tmdb=' +
      encodeURIComponent(tmdbId) +
      '&season=' +
      (ctx.season || 1) +
      '&episode=' +
      (ctx.episode || 1)
    : origin + '/embed/movie?tmdb=' + encodeURIComponent(tmdbId);
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Referer: embedReferer,
    Origin: origin,
  };

  function getJson(url) {
    return ctx.fetch(url, { headers: headers }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }

  function tmdbImdb() {
    var kind = isTv ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(tmdbId) +
        '?api_key=' +
        encodeURIComponent(tmdbKey) +
        '&append_to_response=external_ids',
    )
      .then(function (d) {
        return (d.external_ids && d.external_ids.imdb_id) || '';
      })
      .catch(function () {
        return '';
      });
  }

  function listServers(imdbId) {
    var q =
      origin +
      '/api/v1/s?type=' +
      (isTv ? 'tv' : 'movie') +
      '&tmdb=' +
      encodeURIComponent(tmdbId);
    if (imdbId) q += '&imdb=' + encodeURIComponent(imdbId);
    if (isTv) {
      q +=
        '&season=' +
        encodeURIComponent(String(ctx.season || 1)) +
        '&episode=' +
        encodeURIComponent(String(ctx.episode || 1));
    }
    return getJson(q);
  }

  function resolveKey(key, serverName) {
    if (!key) return Promise.resolve([]);
    return getJson(origin + '/api/v1/l?key=' + encodeURIComponent(key))
      .then(function (j) {
        var url = (j && (j.url || j.link || j.file || j.src || j.embed)) || '';
        if (!url && j && j.data) {
          url = j.data.url || j.data.link || j.data.embed || j.data.file || '';
        }
        if (!url && j && j.result) {
          url = j.result.url || j.result.link || j.result.embed || '';
        }
        if (!url) return [];
        if (/\.m3u8|\.mp4/i.test(url)) {
          return [{ url: url, name: 'PrimeSrc ' + (serverName || ''), headers: headers }];
        }
        return ctx.hop(url).then(function (rows) {
          return (rows || []).map(function (r) {
            return Object.assign({}, r, { name: 'PrimeSrc ' + (serverName || r.name || '') });
          });
        });
      })
      .catch(function () {
        return [];
      });
  }

  function scrapeEmbed(html) {
    var urls = [];
    var re = /https?:\/\/[^"'\\\s<>]+(?:\.m3u8|\.mp4)[^"'\\\s<>]*/gi;
    var m;
    while ((m = re.exec(String(html || '')))) urls.push(m[0]);
    String(html || '').replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
      urls.push(s);
      return _;
    });
    return urls;
  }

  function hopEmbedFallback() {
    return ctx
      .fetch(embedReferer, { headers: Object.assign({}, headers, { Accept: 'text/html,application/xhtml+xml' }) })
      .then(function (r) {
        return r.text();
      })
      .then(function (html) {
        var urls = scrapeEmbed(html).slice(0, 8);
        return Promise.all(
          urls.map(function (u) {
            if (/\.m3u8|\.mp4/i.test(u)) {
              return Promise.resolve([{ url: u, name: 'PrimeSrc', headers: headers }]);
            }
            return ctx.hop(u);
          }),
        ).then(function (groups) {
          return [].concat.apply([], groups);
        });
      })
      .catch(function () {
        return [];
      });
  }

  return tmdbImdb()
    .then(function (imdbId) {
      return listServers(imdbId);
    })
    .then(function (payload) {
      var servers = (payload && payload.servers) || [];
      if (!servers.length) return [];
      var seen = {};
      var tasks = servers.slice(0, 12).map(function (s) {
        if (!s || !s.key || seen[s.key]) return Promise.resolve([]);
        seen[s.key] = true;
        return resolveKey(s.key, s.name || '');
      });
      return Promise.all(tasks).then(function (groups) {
        var out = [].concat.apply([], groups);
        if (out.length) return out;
        return hopEmbedFallback();
      });
    })
    .catch(function () {
      return [];
    });
}
