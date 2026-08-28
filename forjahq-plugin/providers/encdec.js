function extract(ctx) {
  var cfg = ctx.config || {};
  var origin = cfg.origin;
  var enc = cfg.enc || 'https://enc-dec.app/api';
  var slug = cfg.slug;
  if (!origin || !slug) return Promise.resolve([]);
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var tmdbId = String(ctx.tmdbId);
  var page =
    ctx.type === 'movie'
      ? (cfg.movie || origin + '/movie/{id}').replace(/\{id\}|\{tmdb\}/g, tmdbId)
      : (cfg.tv || origin + '/tv/{id}/{s}/{e}')
          .replace(/\{id\}|\{tmdb\}/g, tmdbId)
          .replace('{s}', String(ctx.season || 1))
          .replace('{e}', String(ctx.episode || 1));
  var headers = { 'User-Agent': ua, Referer: origin + '/' };

  function validate(j) {
    return j && j.status === 200 ? j.result : j;
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

  function toRows(payload) {
    var urls = [];
    walk(payload, urls);
    return Promise.all(
      urls.map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([
            { url: u, name: cfg.name || slug, headers: { 'User-Agent': ua, Referer: origin + '/' } },
          ]);
        }
        return ctx.hop(u);
      }),
    ).then(function (groups) {
      var out = [].concat.apply([], groups);
      return out.length ? out : [];
    });
  }

  return ctx
    .fetch(page, { headers: headers })
    .then(function (r) {
      return r.text();
    })
    .then(function (html) {
      var text = (html.match(/\\"(?:en|token|data)\\":\\"([^\\"]+)\\"/) ||
        html.match(/"(?:en|token|data)":"([^"]+)"/) ||
        [])[1];
      if (!text) {
        var urls = [];
        walk(html.match(/https?:\/\/[^"'\s]+/g), urls);
        var embeds = (html.match(/https?:\/\/[^"'\s]+(?:\/e\/|dood|voe|filemoon|streamtape|mixdrop)[^"'\s]*/gi) || []);
        if (embeds.length) {
          return Promise.all(embeds.slice(0, 6).map(function (u) { return ctx.hop(u); })).then(function (g) {
            var out = [].concat.apply([], g);
            return out.length ? out : [];
          });
        }
        return [];
      }
      return ctx
        .fetch(enc + '/enc-' + slug + '?text=' + encodeURIComponent(text), { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          return toRows(validate(j));
        });
    })
    .catch(function () {
      return [];
    });
}
