function extract(ctx) {
  var cfg = ctx.config || {};
  var api = String(cfg.api || '').replace(/\/+$/, '');
  var origin = cfg.origin || 'https://goated.cx';
  if (!api) return Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    Origin: origin,
  };
  var tmdbId = String(ctx.tmdbId || '');
  if (!tmdbId) return Promise.resolve([]);
  var isTv = ctx.type !== 'movie';

  function solve(host) {
    return ctx.fetch(host + '/api/challenge', { headers: headers }).then(function (r) {
      return r.json();
    }).then(function (j) {
      var solved = ctx.crypto.solvePow(j.challenge, j.difficulty);
      if (!solved || !solved.nonce) throw new Error('pow');
      return solved;
    });
  }

  function bodyFor(pow) {
    var b = {
      mediaType: isTv ? 'tv' : 'movie',
      id: tmdbId,
      challenge: pow.challenge,
      nonce: pow.nonce,
    };
    if (isTv) {
      b.season = ctx.season || 1;
      b.episode = ctx.episode || 1;
    }
    return JSON.stringify(b);
  }

  function post(path, pow) {
    return ctx.fetch(api + path, {
      method: 'POST',
      headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
      body: bodyFor(pow),
    }).then(function (r) {
      return r.json();
    });
  }

  function heightQuality(h) {
    h = h | 0;
    if (h >= 2000) return '4K';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h > 0) return h + 'p';
    return '';
  }

  function parseMaster(text, base) {
    var lines = String(text || '').split('\n');
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.indexOf('#EXT-X-STREAM-INF') !== 0) continue;
      var next = (lines[i + 1] || '').trim();
      if (!next || next.charAt(0) === '#') continue;
      var hm = line.match(/RESOLUTION=\d+x(\d+)/);
      var url = next;
      try {
        url = new URL(next, base).toString();
      } catch (e) {}
      out.push({ url: url, quality: heightQuality(hm && hm[1]) });
    }
    return out;
  }

  return solve(api)
    .then(function (pow) {
      return post('/api/resolve', pow);
    })
    .then(function (resolved) {
      var master = resolved && resolved.url;
      if (!master) return [];
      return ctx
        .fetch(master, { headers: headers })
        .then(function (r) {
          return r.text();
        })
        .then(function (playlist) {
          var variants = parseMaster(playlist, master);
          var rows = variants.length
            ? variants
            : [{ url: master, quality: '' }];
          return solve(api)
            .then(function (subPow) {
              return post('/api/subtitles', subPow).catch(function () {
                return null;
              });
            })
            .catch(function () {
              return null;
            })
            .then(function (subsJson) {
              var subs = ((subsJson && subsJson.subtitles) || []).filter(function (s) {
                return s && s.url;
              }).map(function (s) {
                return { url: s.url, lang: s.lang || s.language || '' };
              });
              return rows.map(function (row) {
                return {
                  url: row.url,
                  name: 'Goated',
                  quality: row.quality,
                  headers: headers,
                  subtitles: subs,
                };
              });
            });
        });
    })
    .catch(function () {
      return [];
    });
}
