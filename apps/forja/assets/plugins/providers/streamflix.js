function extract(ctx) {
  var cfg = ctx.config || {};
  var api = (cfg.api || 'https://api.streamflix.app').replace(/\/$/, '');
  var tmdbKey = cfg.tmdbKey || '439c478a771f35c05022f9feabcca01c';
  var ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = {
    'User-Agent': ua,
    Accept: 'application/json, text/plain, */*',
    Referer: api + '/',
  };
  var isTv = ctx.type !== 'movie';
  var tmdbId = String(ctx.tmdbId || '').trim();

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

  function tmdbTitle() {
    if (String(ctx.title || '').trim()) {
      return Promise.resolve({ title: String(ctx.title).trim(), year: String(ctx.year || '').substring(0, 4) });
    }
    var kind = isTv ? 'tv' : 'movie';
    return getJson(
      'https://api.themoviedb.org/3/' +
        kind +
        '/' +
        encodeURIComponent(tmdbId) +
        '?api_key=' +
        encodeURIComponent(tmdbKey),
    ).then(function (d) {
      return {
        title: (isTv ? d.name : d.title) || '',
        year: String((isTv ? d.first_air_date : d.release_date) || '').substring(0, 4),
      };
    });
  }

  function pickBest(catalog, title) {
    if (!catalog.length) return null;
    if (tmdbId) {
      var byTmdb = catalog.filter(function (item) {
        return String(item.tmdb || '') === tmdbId;
      })[0];
      if (byTmdb) return byTmdb;
    }
    var q = String(title || '').toLowerCase();
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
    return best || null;
  }

  return Promise.all([getJson(api + '/data.json'), getJson(api + '/config/config-streamflixapp.json'), tmdbTitle()])
    .then(function (triple) {
      var catalog = (triple[0] && triple[0].data) || [];
      var config = triple[1] || {};
      var meta = triple[2] || {};
      var best = pickBest(catalog, meta.title);
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
