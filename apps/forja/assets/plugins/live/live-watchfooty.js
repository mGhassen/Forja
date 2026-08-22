function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var CATALOG_MAX = 80;

function inCatalogWindow(ts, live) {
  if (live) return true;
  if (!ts) return false;
  var ms = ts >= 1e12 ? ts : ts * 1000;
  var now = Date.now();
  return ms >= now - 3 * 3600000 && ms <= now + 24 * 3600000;
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-watchfooty';
  var api = cfg.api || 'https://api.watchfooty.st/api/v1/matches/football';

  if (action === 'resolve') {
    var mid = String(ctx.matchId || '').replace(/^wf_/, '');
    var res = await ctx.fetch('https://api.watchfooty.st/api/v1/match/' + mid, {
      headers: { 'User-Agent': ua(), Accept: 'application/json' },
    });
    if (!res.ok) return [];
    var data = await res.json();
    var match = Array.isArray(data) ? data[0] : data;
    var out = [];
    (match && match.streams || []).forEach(function (s, i) {
      if (!s.url) return;
      out.push({
        url: String(s.url),
        name: 'WatchFooty ' + (i + 1),
        headers: { Referer: 'https://watchfooty.st/', 'User-Agent': ua() },
      });
    });
    return out;
  }

  var listRes = await ctx.fetch(api, { headers: { 'User-Agent': ua() } });
  if (!listRes.ok) return [];
  var list = await listRes.json();
  if (!Array.isArray(list)) return [];
  return list
    .filter(function (item) {
      var live = item.status === 'in' || item.status === 'live';
      return inCatalogWindow(item.timestamp ? Number(item.timestamp) : 0, live);
    })
    .sort(function (a, b) {
      return Number(a.timestamp || 0) - Number(b.timestamp || 0);
    })
    .slice(0, CATALOG_MAX)
    .map(function (item) {
      var mid = item.matchId;
      var title = item.title || ((item.teams && item.teams.home && item.teams.home.name) || 'Home') +
        ' vs ' + ((item.teams && item.teams.away && item.teams.away.name) || 'Away');
      var live = item.status === 'in' || item.status === 'live';
      return {
        id: 'wf_' + mid,
        title: title,
        category: 'football',
        date: item.timestamp ? Number(item.timestamp) : Date.now(),
        airing: live,
        popular: live,
        sources: [{ source: 'watchfooty', id: String(mid) }],
        catalog: 'forja_live',
        pluginId: pluginId,
      };
    });
}
