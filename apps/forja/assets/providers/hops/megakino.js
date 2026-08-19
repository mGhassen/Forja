function extract(ctx) {
  var url = String((ctx && ctx.url) || '');
  if (!url) return Promise.resolve([]);
  var cfg = ctx.config || {};
  var ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36';
  var headers = { 'User-Agent': ua, Referer: url, Accept: 'text/html,application/xhtml+xml' };
  function row(u, extra) {
    extra = extra || {};
    return { url: u, name: extra.name || cfg.name || '', quality: extra.quality || '', headers: extra.headers || { 'User-Agent': ua, Referer: extra.referer || url } };
  }
  function cf(html) { return /just a moment|cf-challenge|challenge-platform/i.test(String(html || '')); }
  function abs(u, base) {
    if (!u) return '';
    if (/^https?:/i.test(u)) return u;
    try { return new URL(u, base).toString(); } catch (e) { return u; }
  }

  return ctx.fetch(url, { headers: headers }).then(function (r) { return r.text(); }).then(function (html) {
    if (cf(html)) return [];
    var embeds = [];
    String(html).replace(/<iframe[^>]*src=["']([^"']+)["']/gi, function (_, s) { embeds.push(abs(s, url)); return _; });
    String(html).replace(/data-link=["']([^"']+)["']/gi, function (_, s) { embeds.push(abs(s, url)); return _; });
    var hops = embeds.filter(Boolean).slice(0, 6).map(function (u) { return ctx.hop(u); });
    if (!hops.length) return [];
    return Promise.all(hops).then(function (rows) { return [].concat.apply([], rows); });
  }).catch(function () { return []; });
}
