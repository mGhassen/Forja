function cleanUindexQuery(query) {
  return String(query || '')
    .replace(/[^a-zA-Z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = cleanUindexQuery(ctx.query);
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'UIndex');
  var base = String(cfg.base || 'https://uindex.org');
  var direct = base + '/search.php?search=' + encodeURIComponent(query) + '&c=0';

  function parseHtml(html) {
    if (isCloudflareChallenge(html)) {
      if (!flareSolverrBase(ctx)) {
        ctx.log(
          'Cloudflare blocked — set FlareSolverr/Byparr URL in Settings → Sources → Torrent search',
        );
      }
      return [];
    }
    var $ = ctx.html(html);
    var out = [];
    $('tr').each(function (_, tr) {
      var seedsSpan = $(tr).find('span.g').first();
      if (!seedsSpan.length) return;
      var magnet = $(tr).find('a[href^="magnet:"]').first().attr('href') || '';
      var name = $(tr).find('a[href*="details.php"]').first().text().trim() || '';
      if (!name || !magnet) return;
      var cells = $(tr).find('td');
      var sizeTd = cells.filter('[style*="white-space:nowrap"]').first();
      var size =
        (sizeTd.length ? sizeTd.text().trim() : cells.eq(3).text().trim()) ||
        'Unknown';
      out.push({
        name: name,
        magnet: magnet,
        seeders: seedsSpan.text().trim() || '0',
        size: size,
        source: source,
      });
    });
    return out;
  }

  return fetchTextCloudflare(ctx, direct)
    .then(parseHtml)
    .catch(function (e) {
      ctx.log('search failed: ' + String(e && e.message ? e.message : e));
      return [];
    });
}
