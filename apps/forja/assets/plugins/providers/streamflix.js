function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://api.streamflix.app').replace(/\/$/, '');
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Referer: api + '/',
  };
  var title = String(ctx.title || '').trim();
  if (!title) return Promise.resolve([]);
  var isTv = ctx.type !== 'movie';

  function getJson(url) {
    return ctx.fetch(url, { headers: headers }).then(function (r) {
      return r.json();
    });
  }

  function rowsFrom(bases, path, quality) {
    return (bases || [])
      .filter(Boolean)
      .map(function (base) {
        return {
          url: String(base).replace(/\/$/, '') + '/' + String(path).replace(/^\//, ''),
          name: 'StreamFlix',
          quality: quality || '',
          headers: { 'User-Agent': ua, Referer: api + '/' },
        };
      });
  }

  return Promise.all([getJson(api + '/data.json'), getJson(api + '/config/config-streamflixapp.json')])
    .then(function (pair) {
      var catalog = (pair[0] && pair[0].data) || [];
      var config = pair[1] || {};
      var q = title.toLowerCase();
      var words = q.split(/\s+/).filter(function (w) {
        return w.length > 2;
      });
      var hits = catalog.filter(function (item) {
        var n = String((item && item.moviename) || '').toLowerCase();
        if (!n) return false;
        if (!words.length) return n.indexOf(q) >= 0;
        return words.every(function (w) {
          return n.indexOf(w) >= 0;
        });
      });
      var best = hits[0];
      hits.forEach(function (item) {
        if (String(item.moviename || '').toLowerCase() === q) best = item;
      });
      if (!best) return [];
      if (!isTv) {
        if (!best.movielink) return [];
        return rowsFrom(config.premium, best.movielink, '1080p').concat(
          rowsFrom(config.movies, best.movielink, '720p'),
        );
      }
      var bases = config.premium || [];
      if (!bases.length || !best.moviekey) return [];
      var s = ctx.season || 1;
      var e = ctx.episode || 1;
      return rowsFrom(bases, 'tv/' + best.moviekey + '/s' + s + '/episode' + e + '.mkv', '1080p');
    })
    .catch(function () {
      return [];
    });
}
