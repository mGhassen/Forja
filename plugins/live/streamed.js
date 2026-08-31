var SPECS = {
  "origin": "https://streamed.pk",
  "embedOrigin": "https://embed.st"
};

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
  return cfg.origin.replace(/\/$/, '');
}

async function fetchJson(ctx, path, cfg) {
  var base = streamedOrigin(cfg);
  var res = await ctx.fetch(base + path, { headers: streamedHeaders() });
  if (!res.ok) throw new Error('streamed ' + path + ' ' + res.status);
  return res.json();
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'streamed');
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

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
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

async function resolveStream(ctx, cfg) {
  var embedUrl = String(ctx.embedUrl || ctx.url || '').trim();
  var slot = parseEmbedUrl(embedUrl, cfg);
  if (!slot) {
    if (ctx.source && ctx.matchId && ctx.stream) {
      slot = {
        origin: embedOrigin(cfg),
        source: String(ctx.source),
        id: String(ctx.matchId),
        stream: String(ctx.stream),
        path: ctx.source + '/' + ctx.matchId + '/' + ctx.stream,
      };
    }
  }
  if (!slot) throw new Error('streamed resolve: missing embed slot');

  if (slot.source === 'golf') {
    var golfUrl = await resolveGolf(ctx, slot, cfg);
    return [
      {
        url: golfUrl,
        headers: {
          Referer: 'https://exposestrat.com/',
          Origin: 'https://exposestrat.com',
          'User-Agent': ua(),
        },
      },
    ];
  }

  var fetched = await postFetch(ctx, slot, cfg);
  var m3u8 = '';
  if (ctx.live && typeof ctx.live.goatUnlock === 'function') {
    m3u8 = await ctx.live.goatUnlock(fetched.bodyHex, fetched.goat, slot);
  }
  if (!m3u8) throw new Error('goat unlock failed');
  return [
    {
      url: m3u8,
      headers: playbackHeadersForSlot(slot, cfg),
      directPlayback: preferDirectPlayback(m3u8),
    },
  ];
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') return resolveStream(ctx, cfg);
  return [];
}
