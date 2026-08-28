var SPECS = {
  "base": "https://myflixer.to",
  "tmdbKey": "1865f43a0549ca50d341dd9ab8b29f49"
};

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = cfg.base.replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey;
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Referer: base + '/', Accept: 'text/html,application/xhtml+xml' };
  var isTv = ctx.type !== 'movie';

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

  function normalize(str) {
    return String(str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '')
      .trim();
  }

  function titleFromTmdb() {
    var kind = isTv ? 'tv' : 'movie';
    return fetchJson(
      'https://api.themoviedb.org/3/' + kind + '/' + encodeURIComponent(String(ctx.tmdbId || '')) + '?api_key=' + encodeURIComponent(tmdbKey),
    ).then(function (d) {
      return (isTv ? d.name : d.title) || d.original_title || d.original_name || String(ctx.title || '');
    });
  }

  function abs(href) {
    if (!href) return '';
    if (/^https?:/i.test(href)) return href;
    return base + (href.charAt(0) === '/' ? '' : '/') + href;
  }

  function pickWatchUrl(html, title) {
    var target = normalize(title);
    var best = '';
    var re = /<a\b[^>]*href=["']([^"']*(?:\/movie\/|\/tv\/|\/watch\/|\/film\/)[^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi;
    var m;
    while ((m = re.exec(html)) !== null) {
      var href = abs(m[1]);
      var text = m[2].replace(/<[^>]+>/g, '').trim();
      if (!href || /\/genre\/|\/country\/|\/search/i.test(href)) continue;
      if (normalize(text) === target || normalize(text).indexOf(target) >= 0) return href;
      if (!best) best = href;
    }
    return best;
  }

  function scrapeWatch(html) {
    var urls = [];
    String(html).replace(/https?:\/\/[^"'\s<>]+(?:\.m3u8|\.mp4)[^"'\s<>]*/gi, function (u) {
      urls.push(u);
      return u;
    });
    String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) {
      urls.push(abs(s));
      return _;
    });
    String(html).replace(/data-(?:src|url)=["']([^"']+)["']/gi, function (_, s) {
      if (/embed|player|stream|video/i.test(s)) urls.push(abs(s));
      return _;
    });
    var seen = {};
    return urls.filter(function (u) {
      if (!u || seen[u]) return false;
      seen[u] = true;
      return true;
    });
  }

  function resolveUrls(urls) {
    return Promise.all(
      urls.slice(0, 8).map(function (u) {
        if (/\.m3u8|\.mp4/i.test(u)) {
          return Promise.resolve([{ url: u, name: 'MyFlixer', headers: hdrs }]);
        }
        return ctx.hop(u).then(function (rows) {
          return rows && rows.length ? rows : [{ url: u, name: 'MyFlixer embed', headers: hdrs }];
        });
      }),
    ).then(function (groups) {
      return [].concat.apply([], groups);
    });
  }

  return titleFromTmdb()
    .then(function (title) {
      if (!title) return [];
      var searchUrl = base + '/search/' + encodeURIComponent(title.split(':')[0].trim());
      return fetchText(searchUrl)
        .catch(function () {
          return fetchText(base + '/search?q=' + encodeURIComponent(title));
        })
        .then(function (searchHtml) {
          var watchUrl = pickWatchUrl(searchHtml, title);
          if (!watchUrl) return [];
          if (isTv) {
            watchUrl = watchUrl.replace(/\/$/, '') + '/watch/ep-' + (ctx.episode || 1);
          }
          return fetchText(watchUrl, { Referer: base + '/' }).then(function (watchHtml) {
            var urls = scrapeWatch(watchHtml);
            return urls.length ? resolveUrls(urls) : [];
          });
        });
    })
    .catch(function () {
      return [];
    });
}
