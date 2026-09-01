function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'YTS');
  var direct =
    'https://yts.mx/api/v2/list_movies.json?query_term=' +
    encodeURIComponent(query) +
    '&limit=50';
  var jina =
    'https://r.jina.ai/http://yts.mx/api/v2/list_movies.json?query_term=' +
    encodeURIComponent(query) +
    '&limit=50';
  return fetchJsonMaybeJina(ctx, direct, jina)
    .then(function (v) {
      var movies = v && v.data && v.data.movies;
      if (!movies || !movies.length) return [];
      var out = [];
      for (var i = 0; i < movies.length; i++) {
        var movie = movies[i];
        var title =
          movie.title_long || movie.title || 'Unknown';
        var torrents = movie.torrents;
        if (!torrents || !torrents.length) continue;
        for (var j = 0; j < torrents.length; j++) {
          var t = torrents[j];
          var hash = t.hash || '';
          if (!hash) continue;
          var quality = t.quality || '';
          var typ = t.type || '';
          var name = (title + ' [' + quality + ' ' + typ + ']').trim();
          var size =
            jsonUint(t.size_bytes) != null
              ? formatBytes(t.size_bytes)
              : t.size || 'Unknown';
          out.push({
            name: name,
            magnet: magnetFromHash(hash, name),
            seeders: String(jsonInt(t.seeds) || 0),
            size: String(size),
            source: source,
          });
        }
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
