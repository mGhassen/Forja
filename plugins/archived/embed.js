function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin;
  if (!origin) {
    ctx.log('embed.js missing origin');
    return Promise.resolve([]);
  }
  var tmdbId = String(ctx.tmdbId);
  var path =
    ctx.type === 'movie'
      ? (cfg.moviePath || '/embed/movie/{id}').replace(/\{id\}|\{tmdb\}/g, tmdbId)
      : (cfg.tvPath || '/embed/tv/{id}/{s}/{e}')
          .replace(/\{id\}|\{tmdb\}/g, tmdbId)
          .replace('{s}', String(ctx.season || 1))
          .replace('{e}', String(ctx.episode || 1));
  var embed = /^https?:/i.test(path) ? path : origin.replace(/\/$/, '') + path;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Referer: origin + '/',
    Accept: 'text/html,application/xhtml+xml',
  };

  ctx.log('start ' + embed);

  function scrape(html) {
    var urls = [];
    var re = /https?:\/\/[^"'\\\s<>]+(?:\.m3u8|\.mp4)[^"'\\\s<>]*/gi;
    var m;
    while ((m = re.exec(html))) urls.push(m[0]);
    String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
      urls.push(s);
      return _;
    });
    return urls;
  }

  function resolveOne(u) {
    if (!u) return Promise.resolve([]);
    if (!/^https?:/i.test(u)) {
      try {
        u = new URL(u, origin).toString();
      } catch (e) {
        return Promise.resolve([]);
      }
    }
    if (/\.m3u8|\.mp4/i.test(u) || /ice.*m3u8=/i.test(u)) {
      return Promise.resolve([
        { url: u, name: cfg.name || '', headers: { 'User-Agent': ua, Referer: origin + '/' } },
      ]);
    }
    ctx.log('hop ' + u);
    return ctx.hop(u).then(function (rows) {
      return rows && rows.length ? rows : [];
    });
  }

  return ctx
    .fetch(embed, { headers: headers })
    .then(function (r) {
      ctx.log('embed http ' + r.status);
      return r.text();
    })
    .then(function (html) {
      if (/just a moment|cf-challenge|challenge-platform/i.test(html)) {
        ctx.log('cloudflare challenge — no HTTP stream');
        return [];
      }
      var urls = scrape(html);
      ctx.log('scraped urls=' + urls.length);
      return Promise.all(urls.slice(0, 8).map(resolveOne)).then(function (groups) {
        var out = [].concat.apply([], groups);
        ctx.log('streams=' + out.length);
        return out;
      });
    })
    .catch(function (e) {
      ctx.error(e && e.message ? e.message : e);
      return [];
    });
}
