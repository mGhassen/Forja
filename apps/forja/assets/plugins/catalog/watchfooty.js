function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var CATALOG_MAX = 120;
var API_ORIGIN = 'https://api.watchfooty.st';
var LIVE_API = API_ORIGIN + '/api/v1/matches/live';
var ALL_API = API_ORIGIN + '/api/v1/matches/all';

function inCatalogWindow(ts, live) {
  if (live) return true;
  if (!ts) return false;
  var ms = ts >= 1e12 ? ts : ts * 1000;
  var now = Date.now();
  return ms >= now - 3 * 3600000 && ms <= now + 24 * 3600000;
}

function absUrl(path) {
  var p = String(path || '').trim();
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  if (p.charAt(0) !== '/') p = '/' + p;
  return API_ORIGIN + p;
}

function normSport(raw) {
  var s = String(raw || '').trim().toLowerCase();
  if (!s) return 'football';
  if (s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('american') >= 0 && s.indexOf('football') >= 0) {
    return 'american-football';
  }
  return s.replace(/\s+/g, '-');
}

function hasStreams(item) {
  return Array.isArray(item.streams) && item.streams.length > 0;
}

function toRow(pluginId, item, airing) {
  var mid = item.matchId;
  var title =
    item.title ||
    ((item.teams && item.teams.home && item.teams.home.name) || 'Home') +
      ' vs ' +
      ((item.teams && item.teams.away && item.teams.away.name) || 'Away');
  return {
    id: 'wf_' + mid,
    title: title,
    category: normSport(item.sport),
    date: item.timestamp ? Number(item.timestamp) : Date.now(),
    poster: absUrl(item.poster),
    popular: airing,
    airing: airing,
    sources: [{ source: 'watchfooty', id: String(mid) }],
    catalog: 'forja_live',
    pluginId: pluginId,
  };
}

async function fetchList(ctx, url) {
  var res = await ctx.fetch(url, { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var list = await res.json();
  return Array.isArray(list) ? list : [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-watchfooty');
  var byId = {};

  // Site "Live only" ≈ /matches/live rows that actually have stream links.
  var liveList = await fetchList(ctx, cfg.api || LIVE_API);
  for (var i = 0; i < liveList.length; i++) {
    var item = liveList[i];
    var statusLive = item.status === 'in' || item.status === 'live';
    if (!statusLive || !hasStreams(item)) continue;
    byId[String(item.matchId)] = toRow(pluginId, item, true);
  }

  // Upcoming schedule (pre only) — skip post/finished so UI doesn't fake LIVE.
  if (!cfg.api) {
    var allList = await fetchList(ctx, ALL_API);
    for (var j = 0; j < allList.length; j++) {
      var u = allList[j];
      if (u.status !== 'pre') continue;
      if (!inCatalogWindow(u.timestamp ? Number(u.timestamp) : 0, false)) continue;
      var id = String(u.matchId);
      if (!byId[id]) byId[id] = toRow(pluginId, u, false);
    }
  }

  return Object.keys(byId)
    .map(function (k) {
      return byId[k];
    })
    .sort(function (a, b) {
      var liveA = a.airing ? 0 : 1;
      var liveB = b.airing ? 0 : 1;
      if (liveA !== liveB) return liveA - liveB;
      return Number(a.date || 0) - Number(b.date || 0);
    })
    .slice(0, CATALOG_MAX);
}
