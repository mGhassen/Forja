var SPECS = {
  "webOrigin": "https://ppv.st",
  "apis": [
    "https://api.ppv.st/api/streams",
    "https://api.ppv.cx/api/streams"
  ]
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function ppvHeaders(cfg) {
  var origin = ((cfg && cfg.webOrigin) || 'https://ppv.st').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'ppv');
}

function ppvIframeFromDetail(data) {
  if (!data) return '';
  var sources = data.sources;
  if (!Array.isArray(sources)) return '';
  var picked = '';
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];
    if (!s) continue;
    var url = String(s.data || s.url || '').trim();
    if (!url || !/^https?:/i.test(url)) continue;
    if (s.default === true) return url;
    if (!picked) picked = url;
  }
  return picked;
}

function ppvPlayableUrl(data) {
  if (!data) return '';
  var fields = [data.m3u8, data.source, data.vip_mpegts];
  for (var i = 0; i < fields.length; i++) {
    var url = String(fields[i] || '').trim();
    if (url && /\.m3u8|\.mp4/i.test(url)) return url;
  }
  return '';
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var apis = cfg.apis || [
    'https://api.ppv.st/api/streams',
    'https://api.ppv.cx/api/streams',
  ];
  for (var i = 0; i < apis.length; i++) {
    try {
      var res = await ctx.fetch(apis[i], { headers: ppvHeaders(cfg) });
      if (!res.ok) continue;
      var data = await res.json();
      if (!data || data.success !== true || !Array.isArray(data.streams)) continue;
      var rows = [];
      data.streams.forEach(function (cat) {
        var category = String(cat.category || 'Other');
        (cat.streams || []).forEach(function (s) {
          if (s.id == null) return;
          var starts = Number(s.starts_at || 0);
          rows.push({
            id: 'ppv_' + String(s.id),
            title: String(s.name || ''),
            category: category.toLowerCase().replace(/\s+/g, '-'),
            date: starts > 0 ? starts * 1000 : 0,
            poster: String(s.poster || ''),
            popular: Number(s.viewers || 0) > 50,
            airing: Number(s.viewers || 0) > 0,
            viewers: Number(s.viewers || 0),
            starts_at: Number(s.starts_at || 0),
            ends_at: Number(s.ends_at || 0),
            category_name: category,
            always_live: s.always_live === true,
            iframe: String(s.iframe || ''),
            sources: [{
              source: 'ppv',
              id: String(s.id),
              iframe: String(s.iframe || ''),
            }],
            catalog: 'forja_live',
            pluginId: pluginId,
          });
        });
      });
      if (rows.length) return rows;
    } catch (e) {
      ctx.error(e);
    }
  }
  return [];
}

async function resolvePpv(ctx, cfg) {
  var streamId = String(ctx.matchId || (cfg && cfg.streamId) || '').replace(/^ppv_/, '');
  var iframe = String(ctx.embedUrl || ctx.iframe || (cfg && cfg.iframe) || '').trim();
  if (streamId) {
    var apis = (cfg && cfg.apis) || [
      'https://api.ppv.st/api/streams',
      'https://api.ppv.cx/api/streams',
    ];
    var headers = ppvHeaders(cfg);
    for (var i = 0; i < apis.length; i++) {
      try {
        var base = apis[i].replace(/\/$/, '');
        var detail = await ctx.fetch(base + '/' + streamId, { headers: headers });
        if (!detail.ok) continue;
        var body = await detail.json();
        if (!body || body.success !== true || !body.data) continue;
        var source = ppvPlayableUrl(body.data);
        if (source) {
          return [{ url: source, headers: headers }];
        }
        var fromDetail = ppvIframeFromDetail(body.data);
        if (fromDetail) iframe = fromDetail;
      } catch (_) {}
    }
  }
  if (iframe) {
    try {
      if (isEmbedIndiaUrl(iframe)) {
        var embedIndia = await resolveEmbedIndia(ctx, iframe, cfg);
        if (embedIndia) return embedIndia;
      }
      if (iframe.indexOf('embed.st') >= 0) {
        var embedResolved = await resolveGoatEmbed(ctx, iframe, cfg);
        if (embedResolved) return embedResolved;
      }
    } catch (_) {}
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') return resolvePpv(ctx, cfg);
  return [];
}
