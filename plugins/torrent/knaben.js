function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'Knaben');
  var apiUrl = String(cfg.apiUrl || 'https://api.knaben.org/v1');
  var htmlBase = String(cfg.htmlBase || 'https://knaben.org');

  function fromApi() {
    return ctx
      .fetch(apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: query,
          search_field: 'title',
          size: 100,
          hide_unsafe: true,
          hide_xxx: false,
          from: 0,
        }),
      })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .then(function (v) {
        var hits = v && v.hits;
        if (!hits || !hits.length) return [];
        var out = [];
        for (var i = 0; i < hits.length; i++) {
          var hit = hits[i];
          var name = hit.title || '';
          var hash = hit.hash || '';
          if (!name || !hash) continue;
          out.push({
            name: name,
            magnet: magnetFromHash(hash, name),
            seeders: String(jsonInt(hit.seeders) || 0),
            size: jsonUint(hit.bytes) != null ? formatBytes(hit.bytes) : 'Unknown',
            source: source,
          });
        }
        return out;
      });
  }

  function fromHtml() {
    var url =
      htmlBase +
      '/search/' +
      encodeURIComponent(query) +
      '/0/1/seeders';
    return fetchText(ctx, url).then(function (html) {
      var $ = ctx.html(html);
      var out = [];
      $('tbody tr').each(function (_, tr) {
        var link = $(tr).find('td.text-wrap a[href^="magnet:"]').first();
        if (!link.length) return;
        var magnet = link.attr('href') || '';
        var name =
          link.attr('title') || link.text().trim();
        if (!magnet || !name) return;
        var cells = $(tr).find('td');
        var size = cells.eq(1).text().trim() || 'Unknown';
        var seeders =
          cells.length >= 3
            ? cells.eq(cells.length - 3).text().trim()
            : 'Unknown';
        out.push({
          name: name,
          magnet: magnet,
          seeders: seeders || 'Unknown',
          size: size,
          source: source,
        });
      });
      return out;
    });
  }

  return fromApi()
    .then(function (rows) {
      if (rows && rows.length) return rows;
      return fromHtml();
    })
    .catch(function () {
      return fromHtml().catch(function () {
        return [];
      });
    });
}
