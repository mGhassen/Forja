function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var CATALOG_MAX = 80;

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

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-streamic');
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
