function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://aniwaves.ru').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '1865f43a0549ca50d341dd9ab8b29f49';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var hdrs = { 'User-Agent': ua, Accept: 'text/html,*/*', Referer: base + '/' };
  var isTv = ctx.type === 'tv';
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
    return fetchText(base + '/filter?keyword=' + encodeURIComponent(query)).then(function (html) {
      var results = [];
      var re = /href="(\/watch\/([^"?#]+))"[^>]*>[\s\S]{0,300}?class="(?:name|d-title)"[^>]*>([^<]+)/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        results.push({ slug: m[2], title: m[3].trim() });
      }
      if (!results.length) {
        var re2 = /href="\/watch\/([^"?#]+)"/gi;
        while ((m = re2.exec(html)) !== null) results.push({ slug: m[1], title: query });
      }
      return results;
    });
  }

  function watchId(slug) {
    var direct = String(slug).match(/-(\d{3,})$/);
    if (direct) return Promise.resolve(direct[1]);
    return search(String(slug).replace(/-/g, ' ')).then(function (hits) {
      var hit = hits.find(function (h) {
        return h.slug.indexOf(slug) >= 0;
      }) || hits[0];
      var m = hit && String(hit.slug).match(/-(\d+)$/);
      return m ? m[1] : null;
    });
  }

  function episodes(slug, id) {
    return fetchJson(base + '/ajax/episode/list/' + id, { Referer: base + '/watch/' + slug }).then(function (data) {
      var html = (data && (data.result || data.html)) || '';
      var eps = [];
      var re = /data-ids="([^"]+)"[^>]*data-num="(\d+)"/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        eps.push({ ids: m[1], num: Number(m[2]) });
      }
      if (!eps.length) {
        var re2 = /data-num="(\d+)"[^>]*data-ids="([^"]+)"/gi;
        while ((m = re2.exec(html)) !== null) eps.push({ ids: m[2], num: Number(m[1]) });
      }
      return eps;
    });
  }

  function servers(ids) {
    return fetchJson(base + '/ajax/server/list?servers=' + encodeURIComponent(ids)).then(function (data) {
      var html = (data && (data.result || data.html)) || '';
      var out = [];
      var re = /data-link-id="([^"]+)"[^>]*>([\s\S]*?)<\/li>/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        out.push({
          linkId: m[1],
          name: m[2].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim() || 'Server',
        });
      }
      if (!out.length) {
        var re2 = /data-link-id="([^"]+)"/gi;
        while ((m = re2.exec(html)) !== null) out.push({ linkId: m[1], name: 'Server' });
      }
      return out;
    });
  }

  function embed(linkId) {
    if (/^https?:\/\//i.test(linkId)) return Promise.resolve(linkId);
    return fetchJson(base + '/ajax/sources?id=' + encodeURIComponent(linkId) + '&asi=0&autoPlay=0')
      .then(function (data) {
        var body = (data && (data.result || data)) || {};
        return body.url || body.link || '';
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
        return watchId(hit.slug).then(function (id) {
          if (!id) return [];
          return episodes(hit.slug, id).then(function (eps) {
            var ep =
              eps.find(function (e) {
                return e.num === Number(epNum);
              }) || eps[0];
            if (!ep) return [];
            return servers(ep.ids).then(function (svs) {
              return Promise.all(
                svs.slice(0, 4).map(function (s) {
                  return embed(s.linkId).then(function (url) {
                    if (!url) return [];
                    if (/\.m3u8|\.mp4/i.test(url)) {
                      return [
                        {
                          url: url,
                          name: 'AniWaves ' + s.name,
                          headers: { 'User-Agent': ua, Referer: base + '/' },
                        },
                      ];
                    }
                    return ctx.hop(url).then(function (rows) {
                      return (rows || []).map(function (r) {
                        return Object.assign({}, r, { name: r.name || 'AniWaves ' + s.name });
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
      });
    })
    .catch(function () {
      return [];
    });
}
