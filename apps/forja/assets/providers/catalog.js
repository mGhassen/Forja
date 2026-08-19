function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || cfg.origin || '').replace(/\/$/, '');
  var hostId = cfg.hostId;
  var title = String(ctx.title || '');
  var tmdbId = String(ctx.tmdbId || '');
  if (!base) return hostId ? ctx.host(hostId) : Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/json' };
  var q = encodeURIComponent(title || tmdbId);
  var search = (cfg.search || base + '/search?q={q}')
    .replace('{q}', q)
    .replace('{tmdb}', tmdbId)
    .replace('{s}', String(ctx.season || 1))
    .replace('{e}', String(ctx.episode || 1));

  function abs(u) {
    if (!u) return '';
    if (/^https?:/i.test(u)) return u;
    try {
      return new URL(u, base).toString();
    } catch (e) {
      return u;
    }
  }

  function hopAll(urls) {
    return Promise.all(
      urls.slice(0, 8).map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            { url: u, name: cfg.name || '', headers: { 'User-Agent': ua, Referer: base + '/' } },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      var out = [].concat.apply([], groups);
      return out.length ? out : hostId ? ctx.host(hostId) : [];
    });
  }

  return ctx
    .fetch(search, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (body) {
      var json = null;
      try {
        json = JSON.parse(body);
      } catch (e) {}
      var urls = [];
      if (json) {
        JSON.stringify(json).replace(/https?:\\\/\\\/[^"\\]+/g, function (u) {
          urls.push(u.replace(/\\\//g, '/'));
          return u;
        });
        JSON.stringify(json).replace(/https?:\/\/[^"\\]+/g, function (u) {
          urls.push(u);
          return u;
        });
      }
      var html = body;
      var $ = ctx.html ? ctx.html(html) : null;
      if ($ && cfg.link) {
        $(cfg.link).each(function () {
          var href = $(this).attr('href') || $(this).attr('data-url') || '';
          if (href) urls.push(abs(href));
        });
      }
      String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
        urls.push(abs(s));
        return _;
      });
      String(html).replace(/https?:\/\/[^"'\s<>]+(?:\/e\/|dood|voe|filemoon|streamtape|mixdrop|streamwish)[^"'\s<>]*/gi, function (u) {
        urls.push(u);
        return u;
      });
      var seen = {};
      urls = urls.filter(function (u) {
        if (!u || seen[u]) return false;
        seen[u] = true;
        return true;
      });
      if (urls.length) return hopAll(urls);
      return hostId ? ctx.host(hostId) : [];
    })
    .catch(function () {
      return hostId ? ctx.host(hostId) : [];
    });
}
