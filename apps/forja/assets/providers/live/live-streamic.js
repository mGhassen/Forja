function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function embedReferer(raw) {
  try {
    return new URL(String(raw || '').trim()).origin + '/';
  } catch (_) {
    return 'https://streamic.st/';
  }
}

async function fetchList(ctx, cfg) {
  var api = cfg.api || 'https://streamic.st/api/J.php';
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  return Array.isArray(data) ? data : (data.events || data.streams || []);
}

function resolveUrl(ctx, url) {
  var ref = embedReferer(url);
  if (/\.m3u8/i.test(url)) {
    return [{ url: url, headers: { Referer: ref, Origin: ref.replace(/\/$/, ''), 'User-Agent': ua() } }];
  }
  if (url) {
    return [{ sniffPending: true, embedUrl: url, referer: ref }];
  }
  return [];
}

async function resolveByEvent(ctx, cfg) {
  var eventKey = String(ctx.eventId || ctx.matchId || '').replace(/^sic_/, '');
  if (!eventKey) return [];
  var list = await fetchList(ctx, cfg);
  for (var i = 0; i < list.length; i++) {
    var m = list[i];
    if (String(m.id || i) === eventKey) {
      return resolveUrl(ctx, String(m.url || m.link || ''));
    }
  }
  return [];
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-streamic';

  if (action === 'resolve') {
    var direct = String(ctx.url || ctx.embedUrl || '').trim();
    if (direct) return resolveUrl(ctx, direct);
    return resolveByEvent(ctx, cfg);
  }

  var list = await fetchList(ctx, cfg);
  return list.map(function (m, i) {
    return {
      id: 'sic_' + String(m.id || i),
      title: String(m.title || m.name || 'Streamic'),
      category: String(m.sport || m.category || 'other').toLowerCase(),
      date: Date.now(),
      sources: [{ source: 'streamic', id: String(m.id || i) }],
      catalog: 'forja_live',
      pluginId: pluginId,
    };
  });
}
