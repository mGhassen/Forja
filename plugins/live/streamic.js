var CATALOG_MAX = 80;

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'streamic');
}

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('pilkanozna') >= 0 || s.indexOf('pilka') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  return s.replace(/\s+/g, '-');
}

function inCatalogWindow(ts) {
  if (!ts) return false;
  var ms = ts >= 1e12 ? ts : ts * 1000;
  var now = Date.now();
  return ms >= now - 24 * 3600000 && ms <= now + 7 * 24 * 3600000;
}

function isAiring(startTime) {
  if (!startTime) return false;
  var nowSec = Math.floor(Date.now() / 1000);
  return startTime <= nowSec && startTime >= nowSec - 6 * 3600;
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

function resolveOne(ctx, url, name) {
  var ref = embedReferer(url);
  if (/\.m3u8/i.test(url)) {
    return {
      url: url,
      name: name || 'Streamic',
      headers: { Referer: ref, Origin: ref.replace(/\/$/, ''), 'User-Agent': ua() },
    };
  }
  if (url) {
    return { webviewOnly: true, embedUrl: url, referer: ref, name: name || 'Streamic' };
  }
  return null;
}

function collectEmbeds(ctx, m) {
  var out = [];
  (m._embeds || []).forEach(function (group) {
    var lang = String(group.language || '').trim();
    (group.embeds || []).forEach(function (e) {
      var url = String(e.embed || e.url || '').trim();
      if (!url) return;
      var label = String(e.label || '').trim();
      var name = lang && label ? lang + ' · ' + label : lang || label || 'Streamic';
      var row = resolveOne(ctx, url, name);
      if (row) out.push(row);
    });
  });
  if (!out.length) {
    var direct = String(m.url || m.link || '').trim();
    if (direct) {
      var row = resolveOne(ctx, direct, 'Streamic');
      if (row) out.push(row);
    }
  }
  return out;
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var api = cfg.api || 'https://streamic.st/api/J.php';
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  var list = Array.isArray(data) ? data : (data.events || data.streams || []);
  return list
    .filter(function (m) {
      return inCatalogWindow(m.startTime ? Number(m.startTime) : 0);
    })
    .sort(function (a, b) {
      return Number(a.startTime || 0) - Number(b.startTime || 0);
    })
    .slice(0, CATALOG_MAX)
    .map(function (m, i) {
      var id = String(m.id || i);
      var startTime = m.startTime ? Number(m.startTime) : 0;
      var airing = isAiring(startTime);
      return {
        id: 'sic_' + id,
        title: String(m.title || m.name || 'Streamic'),
        category: normCategory(m.sport || m.category || 'other'),
        date: startTime > 0 ? startTime : Date.now(),
        poster: '',
        popular: airing,
        airing: airing,
        sources: [{ source: 'streamic', id: id }],
        catalog: 'forja_live',
        pluginId: pluginId,
      };
    });
}

async function resolveByEvent(ctx, cfg) {
  var eventKey = String(ctx.eventId || ctx.matchId || '').replace(/^sic_/, '');
  if (!eventKey) return [];
  var list = await fetchList(ctx, cfg);
  for (var i = 0; i < list.length; i++) {
    var m = list[i];
    if (String(m.id || i) === eventKey) {
      return collectEmbeds(ctx, m);
    }
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') {
    var direct = String(ctx.url || ctx.embedUrl || '').trim();
    if (direct) {
      var row = resolveOne(ctx, direct, 'Streamic');
      return row ? [row] : [];
    }
    return resolveByEvent(ctx, cfg);
  }
  return [];
}
