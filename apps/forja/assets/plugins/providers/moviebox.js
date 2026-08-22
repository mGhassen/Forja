function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://h5-api.aoneroom.com').replace(/\/$/, '');
  var referer = cfg.referer || 'https://videodownloader.site/';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    'X-Client-Info': '{"timezone":"UTC"}',
    Referer: referer,
    'User-Agent': ua,
  };
  var title = String(ctx.title || '').replace(/\s+S\d+$/i, '').trim();
  var year = String(ctx.year || '').substring(0, 4);
  if (!title) return Promise.resolve([]);
  var isTv = ctx.type !== 'movie';
  var season = isTv ? ctx.season || 1 : 0;
  var episode = isTv ? ctx.episode || 1 : 0;

  function postJson(url, body) {
    return ctx
      .fetch(url, { method: 'POST', headers: headers, body: JSON.stringify(body) })
      .then(function (r) {
        return r.json();
      });
  }

  function pick(items) {
    var nameL = title.toLowerCase();
    var pool = items || [];
    if (isTv) {
      var matching = pool.filter(function (item) {
        var t = String((item && item.title) || '')
          .replace(/\s+S\d+$/i, '')
          .toLowerCase();
        return t === nameL;
      });
      if (matching.length) pool = matching;
      var hit = pool.filter(function (i) {
        return i.season === season && i.hasResource;
      })[0];
      if (hit) return hit;
    } else {
      var exact = pool.filter(function (item) {
        var t = String((item && item.title) || '').toLowerCase() === nameL;
        var y = !year || String(item.releaseDate || '').indexOf(year) === 0;
        return t && y && item.hasResource;
      })[0];
      if (exact) return exact;
    }
    return pool.filter(function (i) {
      return i.hasResource;
    })[0];
  }

  return postJson(api + '/wefeed-h5api-bff/subject/search', {
    keyword: title,
    page: 1,
    perPage: 24,
    subjectType: isTv ? 2 : 1,
  })
    .then(function (j) {
      var items = (j && j.data && j.data.items) || [];
      var match = pick(items);
      if (!match || !match.subjectId) return [];
      var q =
        'subjectId=' +
        encodeURIComponent(match.subjectId) +
        '&se=' +
        season +
        '&ep=' +
        episode +
        '&detailPath=' +
        encodeURIComponent(match.detailPath || '');
      return ctx
        .fetch(api + '/wefeed-h5api-bff/subject/download?' + q, { headers: headers })
        .then(function (r) {
          return r.json();
        })
        .then(function (dj) {
          var downloads = (dj && dj.data && dj.data.downloads) || [];
          return downloads
            .filter(function (d) {
              return d && d.url;
            })
            .map(function (d) {
              var h = d.resolution | 0;
              return {
                url: d.url,
                name: 'MovieBox',
                quality: h > 0 ? h + 'p' : '',
                headers: { 'User-Agent': ua, Referer: referer },
              };
            });
        });
    })
    .catch(function () {
      return [];
    });
}
