function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://hexa.su';
  var api = (cfg.api || 'https://theemoviedb.hexa.su').replace(/\/$/, '');
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var path =
    ctx.type === 'movie'
      ? '/api/tmdb/movie/' + tmdbId + '/images'
      : '/api/tmdb/tv/' +
        tmdbId +
        '/season/' +
        (ctx.season || 1) +
        '/episode/' +
        (ctx.episode || 1) +
        '/images';
  var CryptoJS = ctx.crypto;
  var key =
    CryptoJS && CryptoJS.lib
      ? CryptoJS.lib.WordArray.random(32).toString(CryptoJS.enc.Hex)
      : '';
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    Accept: 'text/plain',
    'X-Fingerprint-Lite': cfg.fingerprint || 'e9136c41504646444',
    'X-Api-Key': key,
  };

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

  if (!key) return ctx.host('hexa');

  return ctx
    .fetch(enc + '/enc-hexa', { headers: { 'User-Agent': ua } })
    .then(function (r) {
      return r.json();
    })
    .then(function (j) {
      var token = (validate(j) || {}).token;
      if (!token) return null;
      headers['X-Cap-Token'] = token;
      return ctx.fetch(api + path, { headers: headers }).then(function (r) {
        return r.text();
      });
    })
    .then(function (encrypted) {
      if (!encrypted) return ctx.host('hexa');
      return ctx
        .fetch(enc + '/dec-hexa', {
          method: 'POST',
          headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
          body: JSON.stringify({ text: encrypted, key: key }),
        })
        .then(function (r) {
          return r.json();
        })
        .then(function (dj) {
          var payload = validate(dj);
          var urls = [];
          walk(payload, urls);
          return Promise.all(
            urls.map(function (u) {
              if (/\.m3u8|\.mp4/i.test(u)) {
                return Promise.resolve([
                  {
                    url: u,
                    name: 'Hexa',
                    headers: { 'User-Agent': ua, Referer: origin + '/' },
                  },
                ]);
              }
              return ctx.hop(u);
            }),
          ).then(function (groups) {
            var out = [].concat.apply([], groups);
            return out.length ? out : ctx.host('hexa');
          });
        });
    })
    .catch(function () {
      return ctx.host('hexa');
    });
}
