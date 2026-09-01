var WATCHFOOTY_REFERER = 'https://watchfooty.st/';
var WATCHFOOTY_SOURCE_PRIORITY = {
  delta: 0,
  echo: 1,
  sigma: 2,
  pro: 3,
  platinum: 4,
  deluxe: 5,
  hd: 6,
  regular: 7,
};

var CATALOG_MAX = 120;
var API_ORIGIN = 'https://api.watchfooty.st';
var LIVE_API = API_ORIGIN + '/api/v1/matches/live';
var ALL_API = API_ORIGIN + '/api/v1/matches/all';

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'watchfooty');
}

function watchfootySourceRank(source) {
  var key = String(source || '').toLowerCase();
  return Object.prototype.hasOwnProperty.call(WATCHFOOTY_SOURCE_PRIORITY, key)
    ? WATCHFOOTY_SOURCE_PRIORITY[key]
    : 99;
}

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

function trpcBatchUrl(procedures, input) {
  return (
    API_ORIGIN +
    '/_internal/trpc/' +
    procedures +
    '?batch=1&input=' +
    encodeURIComponent(JSON.stringify(input))
  );
}

function trpcJson(batch, index) {
  if (!Array.isArray(batch) || batch.length <= index) return null;
  var chunk = batch[index];
  return (
    chunk &&
    chunk.result &&
    chunk.result.data &&
    chunk.result.data.json
  );
}

async function fetchTrpcPopularLiveViewerMap(ctx) {
  var now = new Date();
  var end = new Date(now.getTime() + 24 * 3600000);
  var input = {
    0: { json: { start: now.toISOString(), end: end.toISOString() } },
    1: { json: null, meta: { values: ['undefined'] } },
    2: { json: null, meta: { values: ['undefined'] } },
  };
  var url = trpcBatchUrl(
    'sports.getSportsLiveMatchesCount,sports.getPopularMatches,sports.getPopularLiveMatches',
    input
  );
  try {
    var res = await ctx.fetch(url, { headers: { 'User-Agent': ua() } });
    if (!res.ok) return {};
    var list = trpcJson(await res.json(), 2);
    if (!Array.isArray(list)) return {};
    var map = {};
    for (var i = 0; i < list.length; i++) {
      var row = list[i];
      var id = String(row.id || row.matchId || '');
      if (!id) continue;
      map[id] = Number(row.viewerCount || 0);
    }
    return map;
  } catch (_) {
    return {};
  }
}

async function fetchTrpcMatchLinks(ctx, mid) {
  var now = new Date();
  var end = new Date(now.getTime() + 24 * 3600000);
  var input = {
    0: { json: { start: now.toISOString(), end: end.toISOString() } },
    1: {
      json: {
        id: String(mid),
        withoutAdditionalInfo: true,
        withoutLinks: false,
      },
    },
  };
  var url = trpcBatchUrl(
    'sports.getSportsLiveMatchesCount,sports.getMatchById',
    input
  );
  try {
    var res = await ctx.fetch(url, { headers: { 'User-Agent': ua() } });
    if (!res.ok) return [];
    var match = trpcJson(await res.json(), 1);
    if (!match || !match.fixtureData) return [];
    return Array.isArray(match.fixtureData.links) ? match.fixtureData.links : [];
  } catch (_) {
    return [];
  }
}

function streamViewerMapFromTrpcLinks(links) {
  var map = {};
  for (var i = 0; i < links.length; i++) {
    var link = links[i];
    if (!link) continue;
    var viewers = Number(link.viewerCount || 0);
    if (viewers <= 0) continue;
    var keys = [link.ui, link.u, link.id];
    for (var j = 0; j < keys.length; j++) {
      var key = String(keys[j] || '').trim();
      if (!key) continue;
      map[key] = viewers;
    }
  }
  return map;
}

function viewersForStream(stream, linkViewers, catalogViewers) {
  var keys = [stream && stream.id, stream && stream.source];
  for (var i = 0; i < keys.length; i++) {
    var key = String(keys[i] || '').trim();
    if (!key) continue;
    var hit = linkViewers[key];
    if (hit > 0) return hit;
  }
  return catalogViewers;
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
  viewers = Number(viewers || 0);
  var live = !!airing || viewers > 0;
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
    popular: live || viewers > 50,
    airing: live,
    viewers: viewers,
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

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var byId = {};

  var liveList = await fetchList(ctx, cfg.api || LIVE_API);
  for (var i = 0; i < liveList.length; i++) {
    var item = liveList[i];
    var statusLive = item.status === 'in' || item.status === 'live';
    if (!statusLive) continue;
    byId[String(item.matchId)] = toRow(pluginId, item, true, 0);
  }

  if (!cfg.api) {
    var allList = await fetchList(ctx, ALL_API);
    for (var j = 0; j < allList.length; j++) {
      var u = allList[j];
      if (u.status !== 'pre') continue;
      if (!inCatalogWindow(u.timestamp ? Number(u.timestamp) : 0, false)) continue;
      var id = String(u.matchId);
      if (!byId[id]) byId[id] = toRow(pluginId, u, false, 0);
    }
  }

  var viewerMap = await fetchTrpcPopularLiveViewerMap(ctx);
  Object.keys(viewerMap).forEach(function (id) {
    var row = byId[id];
    if (!row) return;
    var viewers = Number(viewerMap[id] || 0);
    if (viewers <= 0) return;
    row.viewers = viewers;
    row.airing = true;
    row.popular = row.popular || viewers > 50;
  });

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

async function resolveWatchfootyEmbed(ctx, embed) {
  var url = String(embed || '').trim();
  if (!url) return [];
  var catalogViewers = Number(ctx.viewers || 0);

  if (/\.m3u8|\.mp4/i.test(url)) {
    return [
      {
        url: url,
        headers: { Referer: WATCHFOOTY_REFERER, 'User-Agent': ua() },
        directPlayback: preferDirectPlayback(url),
        viewers: catalogViewers,
      },
    ];
  }

  if (!isSportsEmbedUrl(url)) return [];

  var mapped = embedStUrlFromSportsEmbed(url);
  if (mapped) {
    try {
      var unlocked = await resolveGoatEmbed(ctx, mapped, ctx.config || {});
      if (unlocked) {
        return unlocked.map(function (row) {
          return Object.assign({}, row, {
            viewers: Number(row.viewers || 0) || catalogViewers,
          });
        });
      }
    } catch (_) {}
  }

  var candidates = embedStAdminCandidatesFromSportsEmbed(url);
  for (var i = 0; i < candidates.length; i++) {
    try {
      var candidate = await resolveGoatEmbed(ctx, candidates[i], ctx.config || {});
      if (candidate) {
        return candidate.map(function (row) {
          return Object.assign({}, row, {
            viewers: Number(row.viewers || 0) || catalogViewers,
          });
        });
      }
    } catch (_) {}
  }

  return [];
}

async function resolveWatchfootyMatch(ctx, mid) {
  var catalogViewers = Number(ctx.viewers || 0);
  var linkViewers = streamViewerMapFromTrpcLinks(
    await fetchTrpcMatchLinks(ctx, mid)
  );
  var res = await ctx.fetch('https://api.watchfooty.st/api/v1/match/' + mid, {
    headers: { 'User-Agent': ua(), Accept: 'application/json' },
  });
  if (!res.ok) return [];
  var data = await res.json();
  var match = Array.isArray(data) ? data[0] : data;
  var streams = ((match && match.streams) || []).slice();
  streams.sort(function (a, b) {
    return watchfootySourceRank(a && a.source) - watchfootySourceRank(b && b.source);
  });

  var out = [];
  for (var i = 0; i < streams.length; i++) {
    var s = streams[i];
    if (!s || !s.url) continue;
    var embed = String(s.url).trim();
    var resolved = await resolveWatchfootyEmbed(ctx, embed);
    if (!resolved.length) continue;
    for (var j = 0; j < resolved.length; j++) {
      var row = resolved[j];
      var label = 'WatchFooty';
      if (s.source) label += ' ' + s.source;
      if (s.quality) label += ' ' + s.quality;
      out.push({
        url: row.url,
        name: label,
        headers: row.headers || { Referer: WATCHFOOTY_REFERER, 'User-Agent': ua() },
        directPlayback: row.directPlayback === true,
        viewers: viewersForStream(s, linkViewers, catalogViewers),
      });
    }
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') {
    var embed = String(ctx.embedUrl || ctx.url || '').trim();
    if (embed) {
      var fromEmbed = await resolveWatchfootyEmbed(ctx, embed);
      if (fromEmbed.length) return fromEmbed;
    }
    var mid = String(ctx.matchId || '').replace(/^wf_/, '');
    if (!mid) return [];
    return resolveWatchfootyMatch(ctx, mid);
  }
  return [];
}
