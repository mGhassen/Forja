function extract(ctx) {
  var cfg = ctx.config || {};
  var base = (cfg.base || 'https://kaa.lt').replace(/\/$/, '');
  var hls = (cfg.hls || 'https://hls.krussdomi.com/manifest').replace(/\/$/, '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
  var title = String(ctx.title || '');
  var epNum = ctx.type === 'movie' ? 1 : ctx.episode || 1;

  function getJson(url, opts) {
    return ctx.fetch(url, Object.assign({ headers: headers }, opts || {})).then(function (r) {
      return r.json();
    });
  }

  function search() {
    var q = title.replace(/[^\w\s]/g, ' ').replace(/\s+/g, ' ').trim();
    if (!q) return Promise.resolve([]);
    return getJson(base + '/api/fsearch', {
      method: 'POST',
      body: JSON.stringify({ page: 1, query: q }),
    }).then(function (data) {
      return Array.isArray(data && data.result) ? data.result : [];
    });
  }

  function pick(results) {
    var q = title.toLowerCase();
    var best = null;
    var bestScore = 0;
    results.forEach(function (r) {
      var en = String(r.title_en || '').toLowerCase();
      var jp = String(r.title || '').toLowerCase();
      var score = 0;
      if (en && q.indexOf(en) >= 0) score = en.length;
      else if (en && en.indexOf(q) >= 0) score = q.length;
      else if (jp && q.indexOf(jp) >= 0) score = jp.length / 2;
      if (ctx.year && Number(r.year) === Number(ctx.year)) score += 10;
      if (ctx.type === 'movie' && String(r.type || '').toLowerCase() === 'movie') score += 5;
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    });
    return best && best.slug ? best : results[0];
  }

  function episodeSlug(showSlug, showInfo) {
    if (showInfo && showInfo.type === 'movie') {
      var m = String(showInfo.watch_uri || '').match(/\/(ep-\d+-[a-f0-9]+)$/i);
      return m ? m[1] : '';
    }
    return getJson(base + '/api/show/' + showSlug + '/episodes?ep=' + epNum + '&lang=ja-JP').then(
      function (d) {
        var list = Array.isArray(d && d.result) ? d.result : [];
        var hit = null;
        list.forEach(function (e) {
          if (Number(e.episode_number) === Number(epNum)) hit = e;
        });
        if (!hit && list[0]) hit = list[0];
        return hit ? 'ep-' + hit.episode_number + '-' + hit.slug : '';
      },
    );
  }

  if (!title) return ctx.host('kickassanime');

  return search()
    .then(function (results) {
      var show = pick(results);
      if (!show || !show.slug) return ctx.host('kickassanime');
      return getJson(base + '/api/show/' + show.slug).then(function (info) {
        return Promise.resolve(episodeSlug(show.slug, info)).then(function (full) {
          if (!full) return ctx.host('kickassanime');
          return getJson(base + '/api/show/' + show.slug + '/episode/' + full).then(function (ep) {
            var servers = Array.isArray(ep && ep.servers) ? ep.servers : [];
            var rows = [];
            servers.forEach(function (s) {
              var src = s && s.src;
              var m = src && String(src).match(/[?&]id=([^&]+)/);
              if (!m) return;
              rows.push({
                url: hls + '/' + m[1] + '/master.m3u8',
                name: s.name || 'KickAssAnime',
                headers: { 'User-Agent': ua, Referer: 'https://krussdomi.com/' },
              });
            });
            return rows.length ? rows : ctx.host('kickassanime');
          });
        });
      });
    })
    .catch(function () {
      return ctx.host('kickassanime');
    });
}
