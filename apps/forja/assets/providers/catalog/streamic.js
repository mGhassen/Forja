function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-streamic');
  var api = cfg.api || 'https://streamic.st/api/J.php';
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
      poster: '',
      popular: false,
      airing: false,
      sources: [{ source: 'streamic', id: String(m.id || i), url: String(m.url || m.link || '') }],
      catalog: 'forja_live',
      pluginId: pluginId,
    };
  });
}
