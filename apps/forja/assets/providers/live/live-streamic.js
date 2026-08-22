function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-streamic';
  var api = cfg.api || 'https://streamic.st/api/J.php';

  if (action === 'resolve') {
    var url = String(ctx.url || ctx.embedUrl || '').trim();
    if (/\.m3u8/i.test(url)) {
      return [{ url: url, headers: { Referer: 'https://streamic.st/', 'User-Agent': ua() } }];
    }
    if (url) {
      return [{ sniffPending: true, embedUrl: url, referer: 'https://streamic.st/' }];
    }
    return [];
  }

  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  var list = Array.isArray(data) ? data : (data.events || data.streams || []);
  return list.map(function (m, i) {
    return {
      id: 'sic_' + String(m.id || i),
      title: String(m.title || m.name || 'Streamic'),
      category: String(m.sport || m.category || 'other').toLowerCase(),
      date: Date.now(),
      sources: [{ source: 'streamic', id: String(m.id || i), url: String(m.url || m.link || '') }],
      catalog: 'forja_live',
      pluginId: pluginId,
    };
  });
}
