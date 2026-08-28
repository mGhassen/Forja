var SPECS = {
  "origin": "https://streamfree.top"
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-streamfree');
  var origin = cfg.origin.replace(/\/$/, '');
  var res = await ctx.fetch(origin + '/streams', { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  Object.keys(data.streams || {}).forEach(function (category) {
    (data.streams[category] || []).forEach(function (s) {
      var id = s.stream_key || s.id;
      if (!id) return;
      rows.push({
        id: 'sf_' + id,
        title: String(s.name || ''),
        category: String(category).toLowerCase(),
        date: s.match_timestamp ? Number(s.match_timestamp) * 1000 : 0,
        poster: String(s.thumbnail_url || ''),
        popular: Number(s.viewers || 0) > 100,
        airing: false,
        sources: [{ source: 'streamfree', id: String(id) }],
        catalog: 'forja_live',
        pluginId: pluginId,
      });
    });
  });
  return rows;
}
