var SPECS = {
  "base": "https://animeheaven.me",
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

  function fetchJson(url) {
    return ctx.fetch(url, { headers: Object.assign({}, hdrs, { Accept: 'application/json' }) }).then(function (r) {
      return r.json();
    });
  }

  function normalize(s) {
    return String(s || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  }

  function scoreTitle(query, title) {
    var needle = normalize(query);
    var hay = normalize(title);
    if (!needle || !hay) return 0;
    if (hay === needle) return 100;
    var ratio = Math.min(needle.length, hay.length) / Math.max(needle.length, hay.length);
    if (hay.indexOf(needle) === 0 || needle.indexOf(hay) === 0) return ratio >= 0.6 ? 80 : Math.floor(ratio * 60);
    if (hay.indexOf(needle) >= 0 || needle.indexOf(hay) >= 0) return ratio >= 0.6 ? 60 : Math.floor(ratio * 45);
    return 0;
  }

  function search(query) {
    return fetchText(base + '/fastsearch.php?xhr=1&s=' + encodeURIComponent(query)).then(function (html) {
      var results = [];
      var re = /href="([^"]*anime\.php\?([^"]+))"[^>]*>[\s\S]*?class="fastname"[^>]*>([^<]+)/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        results.push({ id: m[2], title: m[3].trim() });
      }
      if (!results.length) {
        var re2 = /anime\.php\?([^"'&\s]+)/g;
        while ((m = re2.exec(html)) !== null) {
          results.push({ id: m[1], title: query });
        }
      }
      return results;
    });
  }

  function findId(title) {
    var variants = [title, title.split(/[:(|-]/)[0], title.split(/\s+/).slice(0, 2).join(' ')].filter(function (v) {
      return v && v.trim().length >= 3;
    });
    var seen = {};
    var chain = Promise.resolve([]);
    variants.forEach(function (v) {
      chain = chain.then(function (acc) {
        return search(v)
          .then(function (rows) {
            rows.forEach(function (r) {
              if (!seen[r.id]) {
                seen[r.id] = true;
                acc.push(r);
              }
            });
            return acc;
          })
          .catch(function () {
            return acc;
          });
      });
    });
    return chain.then(function (all) {
      if (!all.length) return null;
      all.sort(function (a, b) {
        return scoreTitle(title, b.title) - scoreTitle(title, a.title);
      });
      return scoreTitle(title, all[0].title) >= 60 ? all[0].id : null;
    });
  }

  function episodes(animeId) {
    return fetchText(base + '/anime.php?' + animeId).then(function (html) {
      var eps = [];
      var re = /gate[ha]\("([^"]+)"\)[\s\S]{0,200}?class="watch2"[^>]*>([^<]+)/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        var num = parseInt(String(m[2]).replace(/^0+(\d)/, '$1'), 10);
        if (num > 0) eps.push({ id: m[1], num: num });
      }
      if (!eps.length) {
        var re2 = /gate[ha]\("([^"]+)"\)/g;
        var n = 0;
        while ((m = re2.exec(html)) !== null) {
          n += 1;
          eps.push({ id: m[1], num: n });
        }
      }
      return eps;
    });
  }

  function stream(episodeKey) {
    return ctx
      .fetch(base + '/gate.php', {
        headers: Object.assign({}, hdrs, { Cookie: 'key=' + episodeKey, Accept: 'text/html,*/*' }),
      })
      .then(function (r) {
        return r.text();
      })
      .then(function (html) {
        var sources = [];
        var re = /<source[^>]+src=["']([^"']+)["']/gi;
        var m;
        while ((m = re.exec(html)) !== null) {
          if (/^https?:/i.test(m[1])) sources.push(m[1]);
        }
        var primary = sources.find(function (u) {
          return u.indexOf('/video.mp4') >= 0;
        }) || sources[0];
        if (!primary) return [];
        return [
          {
            url: primary,
            name: 'AnimeHeaven',
            headers: { 'User-Agent': ua, Referer: base + '/', Origin: base },
          },
        ];
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
      return d.name || d.title || d.original_title || '';
    });
  }

  return resolveTitle()
    .then(function (title) {
      if (!title) return [];
      return findId(title).then(function (id) {
        if (!id) return [];
        return episodes(id).then(function (eps) {
          var hit =
            eps.find(function (e) {
              return e.num === Number(epNum);
            }) || eps[0];
          if (!hit) return [];
          return stream(hit.id);
        });
      });
    })
    .catch(function () {
      return [];
    });
}
