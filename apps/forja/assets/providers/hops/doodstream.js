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

  function rand(n) {
    var c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    var o = '';
    for (var i = 0; i < n; i++) o += c.charAt(Math.floor(Math.random() * c.length));
    return o;
  }
  return ctx.fetch(url, { headers: headers }).then(function (r) { return r.text(); }).then(function (html) {
    if (cf(html)) return [];
    var pass = (html.match(/\$\.get\('([^']*\/pass_md5\/[^']*)'/) || [])[1];
    var token = (html.match(/token=([a-zA-Z0-9]+)/) || [])[1];
    if (!pass || !token) return [];
    pass = abs(pass, url);
    return ctx.fetch(pass, { headers: headers }).then(function (r) { return r.text(); }).then(function (base) {
      base = String(base || '').trim();
      if (!base) return [];
      var direct = base + rand(10) + '?token=' + token + '&expiry=' + Date.now();
      return [row(direct, { name: 'Doodstream', referer: 'https://dood.li/' })];
    });
  }).catch(function () { return []; });
}
