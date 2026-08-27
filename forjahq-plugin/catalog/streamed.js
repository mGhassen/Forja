function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function streamedHeaders() {
  return {
    Accept: 'application/json',
    Origin: 'https://streamed.pk',
    Referer: 'https://streamed.pk/',
    'User-Agent': ua(),
  };
}

function streamedOrigin(cfg) {
  return (cfg.origin || 'https://streamed.pk').replace(/\/$/, '');
}

async function fetchJson(ctx, path, cfg) {
  var base = streamedOrigin(cfg);
  var res = await ctx.fetch(base + path, { headers: streamedHeaders() });
  if (!res.ok) throw new Error('streamed ' + path + ' ' + res.status);
  return res.json();
}

function matchRow(m, pluginId) {
  var date = Number(m.date || 0);
  return {
    id: String(m.id || ''),
    title: String(m.title || ''),
    category: String(m.category || 'other'),
    date: date > 1e12 ? date : date * 1000,
    poster: String(m.poster || ''),
    popular: m.popular === true,
    airing: m.airing === true,
    sources: (m.sources || []).map(function (s) {
      return { source: String(s.source || ''), id: String(s.id || '') };
    }),
    catalog: 'forja_live',
    pluginId: pluginId,
  };
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-streamed');
  var all = await fetchJson(ctx, '/api/matches/all', cfg);
  var live = await fetchJson(ctx, '/api/matches/live', cfg);
  var byId = {};
  (Array.isArray(all) ? all : []).forEach(function (m) {
    if (m && m.id) byId[m.id] = m;
  });
  (Array.isArray(live) ? live : []).forEach(function (m) {
    if (!m || !m.id) return;
    m.airing = true;
    byId[m.id] = m;
  });
  return Object.keys(byId).map(function (k) {
    return matchRow(byId[k], pluginId);
  });
}
