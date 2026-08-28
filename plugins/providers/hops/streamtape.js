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
    var robot = (html.match(/id=["']robotlink["'][^>]*>([^<]+)/) || html.match(/document\.getElementById\(['"]robotlink['"]\)\.innerHTML\s*=\s*['"]([^'"]+)/) || [])[1];
    if (!robot) {
      var ide = html.match(/ideoooolink['"]\)\.innerHTML\s*=\s*['"]([^'"]+)/);
      robot = ide ? ide[1] : '';
    }
    if (!robot) {
      var m = html.match(/\('robotlink'\)\.innerHTML\s*=\s*'([^']+)'[\s\S]*?\+\s*\(['"]([^'"]+)['"]\)\.substring\((\d+)\)/);
      if (m) robot = m[1] + m[2].substring(parseInt(m[3], 10));
    }
    if (!robot) {
      var m2 = html.match(/innerHTML\s*=\s*["']([^"']+)["']\s*\+\s*["']([^"']+)["']\.substring\((\d+)\)/);
      if (m2) robot = m2[1] + m2[2].substring(parseInt(m2[3], 10));
    }
    robot = String(robot || '').replace(/&amp;/g, '&').trim();
    if (!robot) return [];
    if (robot.indexOf('//') === 0) robot = 'https:' + robot;
    if (!/^https?:/i.test(robot)) robot = 'https://streamtape.com/get_video' + (robot.charAt(0) === '?' ? robot : '');
    return [row(robot, { name: 'Streamtape', referer: 'https://streamtape.com/' })];
  }).catch(function () { return []; });
}
