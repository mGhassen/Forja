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
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = ctx.config || {};
  var pluginId = String(cfg.providerId || 'live-watchfooty');
  var api = cfg.api || 'https://api.watchfooty.st/api/v1/matches/football';
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
      var ta = Number(a.timestamp || 0);
      var tb = Number(b.timestamp || 0);
      return ta - tb;
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
        poster: '',
        popular: live,
        airing: live,
        sources: [{ source: 'watchfooty', id: String(mid) }],
        catalog: 'forja_live',
        pluginId: pluginId,
      };
    });
}
