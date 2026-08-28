var SPECS = {
  "base": "https://anidao.to",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,*/*', Referer: base + '/' };
  var isTv = ctx.type !== 'movie';
  var epNum = isTv ? ctx.episode || 1 : 1;

  function fetchText(url, extra) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, extra || {}) }).then(function (r) {
      return r.text();
    });
  }

  function fetchJson(url, extra) {
    return ctx
      .fetch(url, {
        headers: Object.assign({}, hdrs, extra || {}, {
          Accept: 'application/json,*/*',
          'X-Requested-With': 'XMLHttpRequest',
        }),
      })
      .then(function (r) {
        return r.json();
      });
  }

  function resolveTitle() {
    if (ctx.title) return Promise.resolve(String(ctx.title));
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(String(ctx.tmdbId || '')) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    ).then(function (d) {
      return d.name || d.title || '';
    });
  }

  function search(query) {
    return fetchText(base + '/search.html?keyword=' + encodeURIComponent(query)).then(function (html) {
      var results = [];
      var re = /href="(\/anime\/[^"?#]+)"[^>]*>[\s\S]{0,400}?>([^<]{2,120})</gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var id = m[1].split('/').filter(Boolean).pop();
        if (id && !results.some(function (r) { return r.id === id; })) {
          results.push({ id: id, href: m[1], title: m[2].trim() });
        }
      }
      return results;
    });
  }

  function episodes(slug) {
    var clean = String(slug).replace(/-\d+$/, '');
    return fetchText(base + '/anime/' + clean).then(function (html) {
      var eps = [];
      var re = /href="(\/watch-online\/[^"]*episode-(\d+(?:\.\d+)?)[^"]*)"/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var num = Number(m[2]);
        if (num > 0 && !eps.some(function (e) { return e.num === num; })) {
          eps.push({ num: num, href: m[1] });
        }
      }
      return eps.sort(function (a, b) {
        return a.num - b.num;
      });
    });
  }

  function servers(href) {
    return fetchText(href).then(function (html) {
      var out = [];
      var re = /data-an-video=["']([^"']+)["'][^>]*>([\s\S]*?)<\/[^>]+>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        out.push({
          sourceId: m[1],
          name: m[2].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim() || 'Server',
        });
      }
      if (out.length) return out;
      var re2 = /data-an-video=["']([^"']+)["']/gi;
      while ((m = re2.exec(html)) !== null) out.push({ sourceId: m[1], name: 'Server' });
      return out;
    });
  }

  function resolveSource(sourceId) {
    if (/^https?:\/\//i.test(sourceId)) return Promise.resolve(sourceId);
    return fetchJson(base + '/ajax/v2/episode/sources?id=' + encodeURIComponent(sourceId))
      .then(function (data) {
        return (data && (data.link || data.url)) || '';
      })
      .catch(function () {
        return '';
      });
  }

  return resolveTitle()
    .then(function (title) {
      if (!title) return [];
      return search(title).then(function (hits) {
        var hit = hits[0];
        if (!hit) return [];
        return episodes(hit.id).then(function (eps) {
          var ep =
            eps.find(function (e) {
              return e.num === Number(epNum);
            }) || eps[0];
          if (!ep) return [];
          return servers(ep.href).then(function (svs) {
            return Promise.all(
              svs.slice(0, 4).map(function (s) {
                return resolveSource(s.sourceId).then(function (embed) {
                  if (!embed) return [];
                  if (/\.m3u8|\.mp4/i.test(embed)) {
                    return [
                      {
                        url: embed,
                        name: 'AniDao ' + s.name,
                        headers: { 'User-Agent': ua, Referer: base + '/' },
                      },
                    ];
                  }
                  return ctx.hop(embed).then(function (rows) {
                    return (rows || []).map(function (r) {
                      return Object.assign({}, r, { name: r.name || 'AniDao ' + s.name });
                    });
                  });
                });
              }),
            ).then(function (groups) {
              return [].concat.apply([], groups);
            });
          });
        });
      });
    })
    .catch(function () {
      return [];
    });
}
