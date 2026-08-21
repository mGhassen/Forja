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

  function playHeaders(extra) {
    var h = { 'User-Agent': ua, Referer: origin + '/', Origin: origin };
    if (extra && typeof extra === 'object') {
      Object.keys(extra).forEach(function (k) {
        if (extra[k] != null && String(extra[k]).trim()) h[k] = String(extra[k]);
      });
    }
    return h;
  }

  function toRows(payload, name) {
    var urls = [];
    walk(payload, urls);
    var fromPayload =
      payload && typeof payload === 'object' && payload.headers && typeof payload.headers === 'object'
        ? payload.headers
        : null;
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            {
              url: u,
              name: name || 'MeowTV',
              headers: playHeaders(fromPayload),
            },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  ctx.log('start tmdb=' + tmdbId + ' type=' + (isMovie ? 'movie' : 'tv') + ' servers=' + servers.length);

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
        if (!r.ok) {
          ctx.log('server ' + sid + ' http ' + r.status);
          return [];
        }
        return r.json();
      })
      .then(function (data) {
        if (!data || (Array.isArray(data) && !data.length)) return [];
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
            return toRows(validate(j), (server && server.label) || sid);
          });
      })
      .catch(function (e) {
        ctx.log('server ' + sid + ' err ' + (e && e.message ? e.message : e));
        return [];
      });
  });

  return Promise.all(tasks).then(function (groups) {
    var out = [].concat.apply([], groups);
    ctx.log('streams=' + out.length);
    return out;
  });
}
