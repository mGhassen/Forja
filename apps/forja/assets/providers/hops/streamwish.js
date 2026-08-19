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
    if (cf(html) || /File Not Found|File is no longer available/i.test(html)) return [];
    var unpacked = (globalThis.__engineUnpack && globalThis.__engineUnpack(html)) || html;
    var file = (unpacked.match(/file:\s*["'](https?:[^"']+)["']/) || html.match(/(https?:\/\/[^"'\s]+\.m3u8[^"'\s]*)/) || [])[1];
    return file ? [row(file, { name: 'StreamWish' })] : [];
  }).catch(function () { return []; });
}
