var SPECS = {
  "api": "https://timstreams.st/api/live-upcoming"
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

var GENRE_MAP = {
  1: 'football',
  2: 'motorsport',
  3: 'mma',
  4: 'hockey',
  5: 'mma',
  6: 'tennis',
  7: 'basketball',
  8: 'american-football',
  9: 'baseball',
};

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  return s.replace(/\s+/g, '-');
}

function timstreamsCategory(ev) {
  var id = ev.genre;
  if (GENRE_MAP[id]) return GENRE_MAP[id];
  if (ev.genre && ev.genre.name) return normCategory(ev.genre.name);
  return 'other';
}

function parseEventTime(ev) {
  if (!ev.time) return 0;
  var ms = Date.parse(String(ev.time));
  if (isNaN(ms)) return 0;
  return Math.floor(ms / 1000);
}

function isAiring(startTime) {
  if (!startTime) return false;
  var nowSec = Math.floor(Date.now() / 1000);
  return startTime <= nowSec && startTime >= nowSec - 6 * 3600;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-timstreams');
  var api = cfg.api;
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua(), Accept: 'application/json' } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  (data.events || []).forEach(function (ev, idx) {
    var sources = (ev.streams || [])
      .filter(function (st) { return !st.vip; })
      .map(function (st, i) {
        return {
          source: 'timstreams',
          id: String(st.name || i),
        };
      });
    if (!sources.length) return;
    var startTime = parseEventTime(ev);
    var airing = isAiring(startTime);
    rows.push({
      id: 'ts_' + String(ev.url || idx),
      title: String(ev.name || 'TimStreams event'),
      category: timstreamsCategory(ev),
      date: startTime > 0 ? startTime : Date.now(),
      poster: String(ev.logo || ''),
      popular: ev.featured === true || (ev.viewers ? Number(ev.viewers) > 100 : false),
      airing: airing,
      sources: sources,
      catalog: 'forja_live',
      pluginId: pluginId,
    });
  });
  return rows;
}
