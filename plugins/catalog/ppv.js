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
  var origin = cfg.webOrigin.replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-ppv');
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
