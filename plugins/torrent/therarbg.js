function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'TheRARBG');
  var quest =
    'https://therarbg.to/get-posts/keywords:' +
    encodeURIComponent(query) +
    ':format:json/?page=1';
  var url =
    'https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(quest);
  return fetchJson(ctx, url)
    .then(function (v) {
      var results = v && v.results;
      if (!results || !results.length) return [];
      var out = [];
      for (var i = 0; i < results.length; i++) {
        var item = results[i];
        var name = item.n || '';
        var hash = item.h || '';
        if (!name || !hash) continue;
        out.push({
          name: name,
          magnet: magnetFromHash(hash, name),
          seeders: String(jsonInt(item.se) || 0),
          size: jsonUint(item.s) != null ? formatBytes(item.s) : 'Unknown',
          source: source,
        });
      }
      return out;
    })
    .catch(function () {
      return [];
    });
}
