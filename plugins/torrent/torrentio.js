function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var imdbId = String(ctx.imdbId || '').trim();
  if (!imdbId) return Promise.resolve([]);
  var source = String(cfg.source || 'Torrentio');
  var season = Number(ctx.season || 0);
  var episode = Number(ctx.episode || 0);
  var base = String(cfg.base || 'https://torrentio.strem.fun');
  var url =
    season > 0 && episode > 0
      ? base + '/stream/series/' + imdbId + ':' + season + ':' + episode + '.json'
      : base + '/stream/movie/' + imdbId + '.json';
  return fetchJson(ctx, url)
    .then(function (v) {
      var streams = v && v.streams;
      if (!streams || !streams.length) return [];
      var seedRe = /👤\s*(\d+)/;
      var sizeRe = /💾\s*([\d.]+)\s*(KB|MB|GB|TB)/;
      var out = [];
      for (var i = 0; i < streams.length; i++) {
        var stream = streams[i];
        var hash = stream.infoHash || '';
        if (!hash) continue;
        var rawTitle = String(stream.title || 'Torrentio').replace(/\n/g, ' ');
        var seedM = rawTitle.match(seedRe);
        var sizeM = rawTitle.match(sizeRe);
        out.push({
          name: rawTitle,
          magnet: magnetFromHash(hash, rawTitle),
          seeders: seedM ? seedM[1] : '0',
          size: sizeM ? sizeM[1] + ' ' + sizeM[2] : 'Unknown',
          source: source,
        });
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
