function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var imdbId = String(ctx.imdbId || '').trim();
  if (!imdbId) return Promise.resolve([]);
  if (!/^tt\d+$/i.test(imdbId)) {
    var digits = imdbId.replace(/[^0-9]/g, '');
    if (!digits) return Promise.resolve([]);
    imdbId = 'tt' + digits;
  }
  var source = String(cfg.source || 'Torrentio');
  var season = Number(ctx.season || 0);
  var episode = Number(ctx.episode || 0);
  // Torrentio is per-episode API — skip season-only TV passes (text indexers only).
  if (season > 0 && episode <= 0) return Promise.resolve([]);
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
      var sizeRe = /💾\s*([\d.]+)\s*(KB|MB|GB|TB)/i;
      var out = [];
      for (var i = 0; i < streams.length; i++) {
        var stream = streams[i];
        var hash = hashFromStream(stream);
        if (!hash) continue;
        var rawTitle = String(stream.title || 'Torrentio').replace(/\n/g, ' ');
        var seedM = rawTitle.match(seedRe);
        var sizeM = rawTitle.match(sizeRe);
        var size = sizeM ? sizeM[1] + ' ' + sizeM[2].toUpperCase() : sizeFromHints(stream);
        out.push({
          name: rawTitle,
          magnet: magnetFromHash(hash, rawTitle),
          seeders: seedM ? seedM[1] : '0',
          size: size,
          source: source,
        });
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}

function hashFromStream(stream) {
  var hash = String(stream.infoHash || '').trim();
  if (hash) return hash;
  var url = String(stream.url || '').trim();
  if (!url) return '';
  var m = url.match(/btih:([a-fA-F0-9]{40})/i);
  if (m) return m[1];
  m = url.match(/btih:([a-zA-Z0-9]{32})/i);
  return m ? m[1] : '';
}

function sizeFromHints(stream) {
  var hints = stream.behaviorHints;
  if (!hints || hints.videoSize == null) return 'Unknown';
  return formatBytes(Number(hints.videoSize));
}
