function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function ppvHeaders(cfg) {
  var origin = (cfg.webOrigin || 'https://ppv.is').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

async function fetchStreams(ctx, cfg) {
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
            sources: [{
              source: 'ppv',
              id: String(s.id),
              iframe: String(s.iframe || ''),
            }],
            catalog: 'forja_live',
            pluginId: 'live-ppv',
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
  var streamId = String(ctx.matchId || ctx.config.streamId || '').replace(/^ppv_/, '');
  var iframe = String(ctx.embedUrl || ctx.config.iframe || '').trim();
  if (streamId) {
    try {
      var detail = await ctx.fetch('https://ppv.land/api/streams/' + streamId, {
        headers: { 'User-Agent': ua(), Accept: 'application/json' },
      });
      if (detail.ok) {
        var body = await detail.json();
        var source = body && body.data && body.data.source;
        if (source && /\.m3u8|\.mp4/i.test(source)) {
          return [{
            url: String(source),
            headers: ppvHeaders(cfg),
          }];
        }
      }
    } catch (_) {}
  }
  if (iframe) {
    return [{
      sniffPending: true,
      embedUrl: iframe,
      referer: ppvHeaders(cfg).Referer,
    }];
  }
  return [];
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  if (action === 'resolve') return resolvePpv(ctx, cfg);
  return fetchStreams(ctx, cfg);
}
