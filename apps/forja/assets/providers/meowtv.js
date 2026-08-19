function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://meowtv.ru';
  var api = (cfg.api || 'https://api.meowtv.ru').replace(/\/$/, '');
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var servers = cfg.servers || [];
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Origin: origin,
    Referer: origin + '/',
  };
  var tmdbId = String(ctx.tmdbId);
  var isMovie = ctx.type === 'movie';

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
              name: name || 'MeowTV',
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

  var tasks = servers.slice(0, 8).map(function (server) {
    var sid = server && (server.id || server);
    if (!sid) return Promise.resolve([]);
    var path = isMovie
      ? '/streams/movie/' + tmdbId
      : '/streams/tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
    var url = api + path + '?s=' + encodeURIComponent(sid);
    return ctx
      .fetch(url, { headers: headers })
      .then(function (r) {
        if (!r.ok) return [];
        return r.json();
      })
      .then(function (data) {
        if (!data || Array.isArray(data) && !data.length) return [];
        return ctx
          .fetch(enc + '/dec-meowtv', {
            method: 'POST',
            headers: Object.assign({}, headers, { 'Content-Type': 'application/json' }),
            body: JSON.stringify({ data: data }),
          })
          .then(function (r) {
            return r.json();
          })
          .then(function (j) {
            return toRows(validate(j), server.label || sid);
          });
      })
      .catch(function () {
        return [];
      });
  });

  return Promise.all(tasks).then(function (groups) {
    return [].concat.apply([], groups);
  });
}
