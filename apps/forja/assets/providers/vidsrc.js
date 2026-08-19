function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin || 'https://vidsrc.xyz';
  var tmdbId = String(ctx.tmdbId);
  var embed =
    ctx.type === 'movie'
      ? origin + '/embed/movie/' + tmdbId
      : origin + '/embed/tv/' + tmdbId + '/' + (ctx.season || 1) + '/' + (ctx.episode || 1);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: origin + '/' };

  return ctx
    .fetch(embed, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var urls = [];
      String(html).replace(/https?:\/\/[^"'\s]+(?:rcp|prorcp|m3u8)[^"'\s]*/gi, function (u) {
        urls.push(u);
        return u;
      });
      String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
        urls.push(s.indexOf('http') === 0 ? s : origin + s);
        return _;
      });
      return Promise.all(
        urls.slice(0, 6).map(function (u) {
          if (/\.m3u8/i.test(u)) {
            return Promise.resolve([
              { url: u, name: 'VidSrc', headers: { 'User-Agent': ua, Referer: origin + '/' } },
            ]);
          }
          return ctx.hop(u);
        }),
      ).then(function (groups) {
        var out = [].concat.apply([], groups);
        return out.length ? out : ctx.host(cfg.hostId || 'vidsrc');
      });
    })
    .catch(function () {
      return ctx.host(cfg.hostId || 'vidsrc');
    });
}
