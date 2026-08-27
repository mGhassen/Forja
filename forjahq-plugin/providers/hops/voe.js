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

  function rot13(s) {
    return String(s).replace(/[a-zA-Z]/g, function (c) {
      var base = c <= 'Z' ? 65 : 97;
      return String.fromCharCode(base + ((c.charCodeAt(0) - base + 13) % 26));
    });
  }
  function b64(s) {
    try { return atob(s); } catch (e) { return ''; }
  }
  function decodeVoe(encoded) {
    var junk = ['@$', '^^', '~@', '%?', '*~', '!!', '#&'];
    var step1 = rot13(encoded);
    junk.forEach(function (p) { step1 = step1.split(p).join('_'); });
    var step2 = step1.replace(/_/g, '');
    var step3 = b64(step2);
    var step4 = '';
    for (var i = 0; i < step3.length; i++) step4 += String.fromCharCode(step3.charCodeAt(i) - 3);
    var step5 = b64(step4.split('').reverse().join(''));
    try { return JSON.parse(step5); } catch (e) { return null; }
  }
  function sourceFromHtml(html) {
    var blocks = String(html).match(/<script[^>]*type=["']application\/json["'][^>]*>([\s\S]*?)<\/script>/gi) || [];
    for (var i = 0; i < blocks.length; i++) {
      var inner = blocks[i].replace(/^[\s\S]*?>/, '').replace(/<\/script>$/i, '').trim();
      if (inner.charAt(0) === '"' && inner.charAt(inner.length - 1) === '"') inner = inner.slice(1, -1);
      try { inner = JSON.parse('"' + inner + '"'); } catch (e) {}
      var decoded = decodeVoe(inner);
      if (decoded && decoded.source) return decoded.source;
    }
    var a168 = (html.match(/var a168c='([^']+)'/) || [])[1];
    if (a168) {
      var d = decodeVoe(a168);
      if (d && d.source) return d.source;
    }
    var hls = (html.match(/'hls':\s*'([^']+)'/) || [])[1];
    if (hls) return hls;
    var m3u = (html.match(/https?:\/\/[^\s'"<>]+?\.m3u8[^\s'"<>]*/) || [])[0];
    return m3u || '';
  }
  function follow(html) {
    var m = html.match(/['"](\s*https?:\/\/[^'"<>\s]+\/e\/[^'"<>\s]+)['"]/) ||
      html.match(/(?:location\.href|window\.location(?:\.href)?)\s*=\s*['"](https?:\/\/[^'"<>\s]+)['"]/);
    return m ? m[1].trim() : '';
  }
  return ctx.fetch(url, { headers: headers }).then(function (r) { return r.text(); }).then(function (html) {
    if (cf(html)) return [];
    var src = sourceFromHtml(html);
    if (src) return [row(src, { name: 'VOE' })];
    var next = follow(html);
    if (!next) return [];
    return ctx.fetch(next, { headers: headers }).then(function (r) { return r.text(); }).then(function (html2) {
      if (cf(html2)) return [];
      var s2 = sourceFromHtml(html2);
      return s2 ? [row(s2, { name: 'VOE' })] : [];
    });
  }).catch(function () { return []; });
}
