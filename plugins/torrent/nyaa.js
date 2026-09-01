function parseNyaaRss(xml, source) {
  var out = [];
  var itemRe = /<item>([\s\S]*?)<\/item>/gi;
  var titleRe = /<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>/i;
  var hashRe = /<nyaa:infoHash>([\s\S]*?)<\/nyaa:infoHash>/i;
  var sizeRe = /<nyaa:size>([\s\S]*?)<\/nyaa:size>/i;
  var seedRe = /<nyaa:seeders>([\s\S]*?)<\/nyaa:seeders>/i;
  var m;
  while ((m = itemRe.exec(xml))) {
    var block = m[1] || '';
    var titleM = block.match(titleRe);
    var hashM = block.match(hashRe);
    var name = htmlUnescape((titleM && titleM[1] || '').trim());
    var hash = (hashM && hashM[1] || '').trim();
    if (!name || !hash) continue;
    var sizeM = block.match(sizeRe);
    var seedM = block.match(seedRe);
    out.push({
      name: name,
      magnet: magnetFromHash(hash, name),
      seeders: (seedM && seedM[1] || '0').trim(),
      size: (sizeM && sizeM[1] || 'Unknown').trim(),
      source: source,
    });
  }
  return out;
}

function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'Nyaa');
  var url = 'https://nyaa.si/?page=rss&q=' + encodeURIComponent(query);
  return fetchText(ctx, url)
    .then(function (xml) {
      return parseNyaaRss(xml, source);
    })
    .catch(function () {
      return [];
    });
}
