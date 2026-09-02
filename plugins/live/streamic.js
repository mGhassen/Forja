var CATALOG_MAX = 80;

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'streamic');
}

function streamicOrigin(cfg) {
  return String((cfg && cfg.origin) || 'https://streamic.st').replace(/\/$/, '');
}

function streamicHeaders(cfg) {
  var origin = streamicOrigin(cfg);
  var headers = {
    Accept: '*/*',
    Referer: origin + '/',
    'User-Agent': ua(),
  };
  var ssig = String((cfg && cfg.ssig) || 'bytmo8xialhem066').trim();
  if (ssig) headers['X-SSIG'] = ssig;
  return headers;
}

function b64decodeUTF8(b64) {
  try {
    return decodeURIComponent(
      atob(String(b64 || ''))
        .split('')
        .map(function (c) {
          return '%' + c.charCodeAt(0).toString(16).padStart(2, '0');
        })
        .join('')
    );
  } catch (_) {
    try {
      return decodeURIComponent(escape(atob(String(b64 || ''))));
    } catch (e2) {
      return '';
    }
  }
}

function eventTitle(m) {
  var title = m && m.title;
  if (title && typeof title === 'object') {
    if (title.pl && title.pl.home && title.pl.away) {
      return String(title.pl.home) + ' - ' + String(title.pl.away);
    }
    return String(title.home || title.away || title.en || title.pl || '');
  }
  return String((m && (m.title || m.name)) || 'Streamic');
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

function embedRows(group) {
  var embeds = group && group.embeds;
  if (!embeds) return [];
  if (Array.isArray(embeds)) return embeds;
  if (typeof embeds === 'object') {
    return Object.keys(embeds)
      .sort()
      .map(function (k) {
        return embeds[k];
      })
      .filter(Boolean);
  }
  return [];
}

async function fetchPopularList(ctx, cfg) {
  var origin = streamicOrigin(cfg);
  var api = (cfg && cfg.popularApi) || origin + '/api/J.php';
  try {
    var res = await ctx.fetch(api, { headers: streamicHeaders(cfg) });
    if (!res.ok) return [];
    var data = await res.json();
    return Array.isArray(data) ? data : (data.events || data.streams || []);
  } catch (e) {
    ctx.error(e);
    return [];
  }
}

async function fetchMainList(ctx, cfg) {
  var origin = streamicOrigin(cfg);
  var api = (cfg && cfg.api) || origin + '/api/getEvents.php';
  try {
    var res = await ctx.fetch(api, { headers: streamicHeaders(cfg) });
    if (!res.ok) return [];
    var body = await res.text();
    if (!body) return [];
    var decoded = b64decodeUTF8(body.trim());
    if (!decoded) return [];
    var data = JSON.parse(decoded);
    return Array.isArray(data) ? data : (data.events || data.streams || []);
  } catch (e) {
    ctx.error(e);
    return [];
  }
}

async function fetchList(ctx, cfg) {
  var popular = await fetchPopularList(ctx, cfg);
  var main = await fetchMainList(ctx, cfg);
  var byId = {};
  popular.forEach(function (m, i) {
    if (!m) return;
    var id = String(m.id || 'pop_' + i);
    m._popular = true;
    byId[id] = m;
  });
  main.forEach(function (m, i) {
    if (!m) return;
    var id = String(m.id || 'evt_' + i);
    byId[id] = m;
  });
  return Object.keys(byId).map(function (k) {
    return byId[k];
  });
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
    embedRows(group).forEach(function (e) {
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

function catalogRow(m, pluginId, i) {
  var id = String(m.id || i);
  var startTime = m.startTime ? Number(m.startTime) : 0;
  var airing = isAiring(startTime);
  return {
    id: 'sic_' + id,
    title: eventTitle(m),
    category: normCategory(m.sport || m.category || 'other'),
    date: startTime > 0 ? startTime : Date.now(),
    poster: '',
    popular: m._popular === true || airing,
    airing: airing,
    sources: [{ source: 'streamic', id: id }],
    catalog: 'forja_live',
    pluginId: pluginId,
  };
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var list = await fetchList(ctx, cfg);
  return list
    .filter(function (m) {
      var startTime = m.startTime ? Number(m.startTime) : 0;
      if (m._popular === true && startTime > 0) return inCatalogWindow(startTime);
      return inCatalogWindow(startTime);
    })
    .sort(function (a, b) {
      if (a._popular === true && b._popular !== true) return -1;
      if (b._popular === true && a._popular !== true) return 1;
      return Number(a.startTime || 0) - Number(b.startTime || 0);
    })
    .slice(0, CATALOG_MAX)
    .map(function (m, i) {
      return catalogRow(m, pluginId, i);
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
