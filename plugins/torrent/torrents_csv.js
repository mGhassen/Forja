function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'Torrents CSV');
  var url =
    'https://torrents-csv.com/service/search?q=' + encodeURIComponent(query);
  return fetchJson(ctx, url)
    .then(function (v) {
      var arr = v && v.torrents;
      if (!arr || !arr.length) return [];
      var out = [];
      for (var i = 0; i < arr.length && i < 100; i++) {
        var item = arr[i];
        var name = item.name || '';
        var hash = item.infohash || '';
        if (!name || !hash) continue;
        out.push({
          name: name,
          magnet: magnetFromHash(hash, name),
          seeders: String(jsonInt(item.seeders) || 0),
          size: jsonUint(item.size_bytes) != null ? formatBytes(item.size_bytes) : 'Unknown',
          source: source,
        });
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
