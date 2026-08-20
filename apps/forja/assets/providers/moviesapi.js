function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://moviesapi.to';
  var player = cfg.player || 'https://player.moviesapi.vip';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var rest =
    ctx.type === 'movie'
      ? 'movie/' + tmdbId
      : 'tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
  var headers = { 'User-Agent': ua, Referer: origin + '/', Accept: 'application/json, text/html' };

  ctx.log('start ' + rest);

  function walk(o, urls) {
    if (!o) return;
    if (typeof o === 'string' && /^https?:/i.test(o)) urls.push(o);
    else if (Array.isArray(o))
      o.forEach(function (e) {
        walk(e, urls);
      });
    else if (typeof o === 'object') {
      ['url', 'file', 'src', 'stream', 'link', 'playlist'].forEach(function (k) {
        if (o[k]) walk(o[k], urls);
      });
    }
  }

  function resolveUrls(urls) {
    return Promise.all(
      urls.slice(0, 8).map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u) || /ice.*m3u8=/i.test(u)) {
          return Promise.resolve([
            { url: u, name: 'MoviesAPI', headers: { 'User-Agent': ua, Referer: origin + '/' } },
          ]);
        }
        ctx.log('hop ' + u);
        return ctx.hop(u).then(function (rows) {
          return rows && rows.length ? rows : [];
        });
      }),
    ).then(function (groups) {
      var out = [].concat.apply([], groups);
      ctx.log('streams=' + out.length);
      return out;
    });
  }

  return ctx
    .fetch(origin + '/api/vidora/v1/' + rest, { headers: headers })
    .then(function (r) {
      ctx.log('api http ' + r.status);
      return r.text();
    })
    .then(function (body) {
      var json = null;
      try {
        json = JSON.parse(body);
      } catch (e) {}
      var urls = [];
      if (json) walk(json, urls);
      if (urls.length) return resolveUrls(urls);
      if (json && json.error) ctx.log('api error ' + json.error);
      ctx.log('fallback player ' + player + '/' + rest);
      return ctx
        .fetch(player + '/' + rest, { headers: headers })
        .then(function (r) {
          return r.text();
        })
        .then(function (html) {
          String(html).replace(/https?:\/\/[^"'\s<>]+(?:\.m3u8|\.mp4)[^"'\s<>]*/gi, function (u) {
            urls.push(u);
            return u;
          });
          String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
            urls.push(s);
            return _;
          });
          ctx.log('player scraped=' + urls.length);
          return urls.length ? resolveUrls(urls) : [];
        });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
