function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'UIndex');
  var base = String(cfg.base || 'https://uindex.org');
  var direct = base + '/search.php?search=' + encodeURIComponent(query) + '&c=0';

  function parseHtml(html) {
    var $ = ctx.html(html);
    var out = [];
    $('table tr').each(function (_, tr) {
      if ($(tr).find('th').length) return;
      var cells = $(tr).find('td');
      if (cells.length < 5) return;
      var titleCell = cells.eq(1);
      var magnet =
        titleCell.find('a[href^="magnet:"]').first().attr('href') || '';
      var name =
        titleCell.find('a[href*="/details.php"]').first().text().trim() || '';
      if (!name || !magnet) return;
      var size = cells.eq(2).text().trim() || 'Unknown';
      var seeders =
        cells.eq(3).find('span.g').first().text().trim() ||
        cells.eq(3).text().trim().replace(/,/g, '') ||
        'Unknown';
      out.push({
        name: name,
        magnet: magnet,
        seeders: seeders || 'Unknown',
        size: size || 'Unknown',
        source: source,
      });
    });
    return out;
  }

  return fetchTextMaybeProxy(ctx, direct)
    .then(parseHtml)
    .catch(function () {
      return [];
    });
}
