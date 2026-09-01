function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'SolidTorrents');
  var direct =
    'https://solidtorrents.to/api/v1/search?q=' +
    encodeURIComponent(query) +
    '&limit=100&sort=seeders';
  var jina =
    'https://r.jina.ai/https://solidtorrents.to/api/v1/search?q=' +
    encodeURIComponent(query) +
    '&limit=100&sort=seeders';
  return fetchJsonMaybeJina(ctx, direct, jina)
    .then(function (v) {
      var results = v && v.results;
      if (!results || !results.length) return [];
      var out = [];
      for (var i = 0; i < results.length; i++) {
        var item = results[i];
        var name = item.title || '';
        var hash = item.infohash || '';
        if (!name || !hash) continue;
        out.push({
          name: name,
          magnet: magnetFromHash(hash, name),
          seeders: String(jsonInt(item.seeders) || 0),
          size: jsonUint(item.size) != null ? formatBytes(item.size) : 'Unknown',
          source: source,
        });
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
