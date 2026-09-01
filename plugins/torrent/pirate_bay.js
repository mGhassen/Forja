function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'ThePirateBay');
  var tpbBase = String(cfg.tpbBase || 'https://1.piratebays.to');
  var maxPages = Number(cfg.maxPages || 10);

  function fromApi() {
    var url = 'https://apibay.org/q.php?q=' + encodeURIComponent(query);
    return fetchJson(ctx, url).then(function (v) {
      if (!Array.isArray(v)) return [];
      var out = [];
      for (var i = 0; i < v.length; i++) {
        var item = v[i];
        var name = item.name || '';
        if (!name || name === 'No results returned') continue;
        var hash = item.info_hash || '';
        if (!hash) continue;
        out.push({
          name: name,
          magnet: magnetFromHash(hash, name),
          seeders: String(jsonInt(item.seeders) || 0),
          size: jsonUint(item.size) != null ? formatBytes(item.size) : 'Unknown',
          source: source,
        });
      }
      return out;
    });
  }

  function fromHtmlPage(page) {
    var url =
      page === 1
        ? tpbBase +
          '/s/?q=' +
          encodeURIComponent(query) +
          '&video=on&category=0'
        : tpbBase +
          '/s/page/' +
          page +
          '/?q=' +
          encodeURIComponent(query) +
          '&video=on&category=0';
    return fetchText(ctx, url).then(function (html) {
      var $ = ctx.html(html);
      var out = [];
      $('table tr').each(function (_, tr) {
        if ($(tr).find('th').length) return;
        var titleLink = $(tr).find('a.detLink').first();
        var magnetLink = $(tr).find('a[href^="magnet:"]').first();
        if (!titleLink.length || !magnetLink.length) return;
        var name = titleLink.text().trim();
        var magnet = magnetLink.attr('href') || '';
        if (!name || !magnet) return;
        var cells = $(tr).find('td');
        out.push({
          name: name,
          magnet: magnet,
          seeders: cells.eq(5).text().trim() || 'Unknown',
          size: cells.eq(4).text().trim() || 'Unknown',
          source: source,
        });
      });
      return out;
    });
  }

  function fromHtmlAll() {
    var chain = Promise.resolve([]);
    for (var page = 1; page <= maxPages; page++) {
      (function (p) {
        chain = chain.then(function (acc) {
          return fromHtmlPage(p).then(function (batch) {
            if (!batch.length) return acc;
            return acc.concat(batch);
          });
        });
      })(page);
    }
    return chain;
  }

  return fromApi()
    .then(function (rows) {
      if (rows && rows.length) return rows;
      return fromHtmlAll();
    })
    .catch(function () {
      return fromHtmlAll().catch(function () {
        return [];
      });
    });
}
