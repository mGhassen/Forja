function parseTherarbgJson(v, source) {
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
}

function fetchTherarbgJson(ctx, base, query, source) {
  var quest =
    base +
    '/get-posts/keywords:' +
    encodeURIComponent(query) +
    ':format:json/?page=1';
  var jina = 'https://r.jina.ai/' + quest;
  return fetchJson(ctx, quest)
    .then(function (v) {
      return parseTherarbgJson(v, source);
    })
    .catch(function () {
      return fetchJson(ctx, jina)
        .then(unwrapJina)
        .then(function (v) {
          return parseTherarbgJson(v, source);
        });
    })
    .catch(function () {
      return fetchJson(
        ctx,
        'https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(quest),
      ).then(function (v) {
        return parseTherarbgJson(v, source);
      });
    });
}

function tryTherarbgMirrors(ctx, query, source, bases, index) {
  if (index >= bases.length) return fromRargbHtml(ctx, query, source);
  return fetchTherarbgJson(ctx, bases[index], query, source)
    .then(function (rows) {
      if (rows.length) return rows;
      return tryTherarbgMirrors(ctx, query, source, bases, index + 1);
    })
    .catch(function () {
      return tryTherarbgMirrors(ctx, query, source, bases, index + 1);
    });
}

function magnetFromDetailHtml(html) {
  var m = String(html || '').match(/magnet:\?[^"'\s<>]+/i);
  return m ? m[0] : '';
}

function fetchRargbMagnet(ctx, detailPath) {
  var url = 'https://rargb.to' + detailPath;
  return fetchTextMaybeProxy(ctx, url).then(magnetFromDetailHtml).catch(function () {
    return '';
  });
}

function enrichRargbRows(ctx, rows, index, out) {
  if (index >= rows.length) return Promise.resolve(out);
  var row = rows[index];
  return fetchRargbMagnet(ctx, row.detailPath).then(function (magnet) {
    if (magnet) {
      out.push({
        name: row.name,
        magnet: magnet,
        seeders: row.seeders,
        size: row.size,
        source: row.source,
      });
    }
    return enrichRargbRows(ctx, rows, index + 1, out);
  });
}

function fromRargbHtml(ctx, query, source) {
  var maxRows = 25;
  var url = 'https://rargb.to/search/?search=' + encodeURIComponent(query);
  return fetchTextMaybeProxy(ctx, url)
    .then(function (html) {
      var $ = ctx.html(html);
      var pending = [];
      $('tr.lista2').each(function (_, tr) {
        if (pending.length >= maxRows) return;
        var cells = $(tr).find('td.lista');
        if (cells.length < 6) return;
        var titleLink = cells.eq(1).find('a').first();
        if (!titleLink.length) return;
        var name = titleLink.text().trim();
        var href = titleLink.attr('href') || '';
        if (!name || !href) return;
        var seedFont = cells.eq(5).find('font').first();
        pending.push({
          name: name,
          detailPath: href,
          seeders: seedFont.text().trim() || cells.eq(5).text().trim() || '0',
          size: cells.eq(4).text().trim() || 'Unknown',
          source: source,
        });
      });
      return enrichRargbRows(ctx, pending, 0, []);
    })
    .catch(function () {
      return [];
    });
}

function search(ctx) {
  var cfg = Object.assign({}, ctx.config || {});
  var query = String(ctx.query || '').trim();
  if (!query) return Promise.resolve([]);
  var source = String(cfg.source || 'TheRARBG');
  var bases = [
    'https://therarbg.to',
    'https://therarbg.com',
  ];
  return tryTherarbgMirrors(ctx, query, source, bases, 0).catch(function () {
    return [];
  });
}
