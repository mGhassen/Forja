function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var CATALOG_MAX = 120;
var API_ORIGIN = 'https://api.watchfooty.st';
var SITE_ORIGIN = 'https://watchfooty.st';
var LIVE_API = API_ORIGIN + '/api/v1/matches/live';
var ALL_API = API_ORIGIN + '/api/v1/matches/all';
// REST /matches/live has no viewers — site exposes them on tRPC popular live (+ ticker).
var TRPC_NULL_INPUT = encodeURIComponent(JSON.stringify({ '0': { json: null } }));
var POPULAR_LIVE_TRPC =
  SITE_ORIGIN +
  '/api/trpc/sports.getPopularLiveMatches?batch=1&input=' +
  TRPC_NULL_INPUT;
var TICKER_TRPC =
  SITE_ORIGIN + '/api/trpc/ticker.getItems?batch=1&input=' + TRPC_NULL_INPUT;

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

function toRow(pluginId, item, airing, viewers) {
  var mid = item.matchId;
  var title =
    item.title ||
    ((item.teams && item.teams.home && item.teams.home.name) || 'Home') +
      ' vs ' +
      ((item.teams && item.teams.away && item.teams.away.name) || 'Away');
  var v = Number(viewers || 0);
  if (!(v > 0)) v = 0;
  return {
    id: 'wf_' + mid,
    title: title,
    category: normSport(item.sport),
    date: item.timestamp ? Number(item.timestamp) : Date.now(),
    poster: absUrl(item.poster),
    popular: airing || v > 50,
    airing: airing,
    viewers: v,
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

function trpcJson(batch) {
  return (
    batch &&
    batch[0] &&
    batch[0].result &&
    batch[0].result.data &&
    batch[0].result.data.json
  );
}

function bumpViewers(map, id, n) {
  var key = String(id || '').trim();
  var count = Number(n || 0);
  if (!key || !(count > 0)) return;
  var prev = map[key] || 0;
  if (count > prev) map[key] = count;
}

/** Match-level concurrent viewers — not on /api/v1/matches/live. */
async function fetchViewerCounts(ctx) {
  var out = {};
  var headers = {
    'User-Agent': ua(),
    Accept: 'application/json',
    Referer: SITE_ORIGIN + '/',
  };

  try {
    var popRes = await ctx.fetch(POPULAR_LIVE_TRPC, { headers: headers });
    if (popRes.ok) {
      var popList = trpcJson(await popRes.json());
      if (Array.isArray(popList)) {
        for (var i = 0; i < popList.length; i++) {
          var m = popList[i];
          if (!m) continue;
          bumpViewers(out, m.id || m.matchId, m.viewerCount);
        }
      }
    }
  } catch (_) {}

  try {
    var tickRes = await ctx.fetch(TICKER_TRPC, { headers: headers });
    if (tickRes.ok) {
      var tick = trpcJson(await tickRes.json());
      var items = tick && tick.items;
      if (Array.isArray(items)) {
        for (var j = 0; j < items.length; j++) {
          var it = items[j];
          if (!it || it.type !== 'live') continue;
          var idMatch = String(it.id || '').match(/^live-(.+)$/);
          var watchMatch = String(it.label || '').match(
            /·\s*([\d,]+)\s*watching/i,
          );
          if (!idMatch || !watchMatch) continue;
          bumpViewers(out, idMatch[1], String(watchMatch[1]).replace(/,/g, ''));
        }
      }
    }
  } catch (_) {}

  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-watchfooty');
  var byId = {};
  var viewersById = await fetchViewerCounts(ctx);

  // Keep stream-less airing rows — Status → Airing shows them; play may still fail.
  var liveList = await fetchList(ctx, cfg.api || LIVE_API);
  for (var i = 0; i < liveList.length; i++) {
    var item = liveList[i];
    var statusLive = item.status === 'in' || item.status === 'live';
    if (!statusLive) continue;
    var mid = String(item.matchId);
    byId[mid] = toRow(pluginId, item, true, viewersById[mid] || 0);
  }

  // Upcoming schedule (pre only) — skip post/finished.
  if (!cfg.api) {
    var allList = await fetchList(ctx, ALL_API);
    for (var j = 0; j < allList.length; j++) {
      var u = allList[j];
      if (u.status !== 'pre') continue;
      if (!inCatalogWindow(u.timestamp ? Number(u.timestamp) : 0, false)) continue;
      var id = String(u.matchId);
      if (!byId[id]) byId[id] = toRow(pluginId, u, false, viewersById[id] || 0);
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
      var va = Number(a.viewers || 0);
      var vb = Number(b.viewers || 0);
      if (va !== vb) return vb - va;
      return Number(a.date || 0) - Number(b.date || 0);
    })
    .slice(0, CATALOG_MAX);
}
