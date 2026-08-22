function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  return s.replace(/\s+/g, '-');
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-timstreams');
  var api = cfg.api || 'https://timstreams.st/api/live-upcoming';
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua(), Accept: 'application/json' } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  (data.events || []).forEach(function (ev, idx) {
    var sources = (ev.streams || [])
      .filter(function (st) { return !st.vip; })
      .map(function (st, i) {
        return {
          source: 'timstreams',
          id: String(st.name || i),
        };
      });
    if (!sources.length) return;
    rows.push({
      id: 'ts_' + String(ev.url || idx),
      title: String(ev.name || 'TimStreams event'),
      category: normCategory(ev.genre && ev.genre.name ? ev.genre.name : 'other'),
      date: Date.now(),
      poster: '',
      popular: ev.featured === true,
      airing: false,
      sources: sources,
      catalog: 'forja_live',
      pluginId: pluginId,
    });
  });
  return rows;
}
