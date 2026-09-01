var SPECS = {
  "api": "https://timstreams.st/api/live-upcoming",
  "embedOrigin": "https://embed.st"
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

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'timstreams');
}

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

function embedReferer(raw) {
  try {
    return new URL(String(raw || '').trim()).origin + '/';
  } catch (_) {
    return 'https://timstreams.st/';
  }
}

async function fetchEvents(ctx, cfg) {
  var api = cfg.api;
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua(), Accept: 'application/json' } });
  if (!res.ok) return [];
  var data = await res.json();
  return data.events || [];
}

function findEvent(events, eventToken) {
  for (var i = 0; i < events.length; i++) {
    var ev = events[i];
    if (String(ev.url || '') === eventToken || String(i) === eventToken) return ev;
  }
  return null;
}

function pickStream(ev, streamKey) {
  var streams = (ev.streams || []).filter(function (st) { return !st.vip; });
  if (!streams.length) return null;
  for (var i = 0; i < streams.length; i++) {
    var st = streams[i];
    if (String(st.name || '') === streamKey || String(i) === streamKey) return st;
  }
  return streams[0];
}

function withName(row, name) {
  if (!row) return null;
  row.name = name || row.name || 'TimStreams';
  return row;
}

async function unlockEmbed(ctx, url, cfg) {
  var raw = String(url || '').trim();
  if (!raw) return null;

  if (isEmbedIndiaUrl(raw)) {
    try {
      var india = await resolveEmbedIndia(ctx, raw, cfg);
      if (india && india.length) return india[0];
    } catch (_) {}
  }

  if (raw.indexOf('embed.st') >= 0 || parseEmbedUrl(raw, cfg)) {
    try {
      var goat = await resolveGoatEmbed(ctx, raw, cfg);
      if (goat && goat.length) return goat[0];
    } catch (_) {}
  }

  if (isSportsEmbedUrl(raw)) {
    var mapped = embedStUrlFromSportsEmbed(raw);
    if (mapped) {
      try {
        var mappedGoat = await resolveGoatEmbed(ctx, mapped, cfg);
        if (mappedGoat && mappedGoat.length) return mappedGoat[0];
      } catch (_) {}
    }

    var candidates = embedStAdminCandidatesFromSportsEmbed(raw);
    for (var i = 0; i < candidates.length; i++) {
      try {
        var candidate = await resolveGoatEmbed(ctx, candidates[i], cfg);
        if (candidate && candidate.length) return candidate[0];
      } catch (_) {}
    }
  }

  return null;
}

async function resolveUrl(ctx, url, name, cfg) {
  var raw = String(url || '').trim();
  if (!raw) return null;
  var ref = embedReferer(raw);

  if (/\.m3u8|\.mp4/i.test(raw)) {
    return {
      url: raw,
      name: name || 'TimStreams',
      headers: { Referer: ref, Origin: ref.replace(/\/$/, ''), 'User-Agent': ua() },
      directPlayback: preferDirectPlayback(raw),
    };
  }

  var unlocked = await unlockEmbed(ctx, raw, cfg || {});
  if (unlocked) return withName(unlocked, name || 'TimStreams');

  return { webviewOnly: true, embedUrl: raw, referer: ref, name: name || 'TimStreams' };
}

async function resolveByEvent(ctx, cfg) {
  var eventToken = String(ctx.eventId || '').replace(/^ts_/, '');
  if (!eventToken) return [];
  var events = await fetchEvents(ctx, cfg);
  var ev = findEvent(events, eventToken);
  if (!ev) return [];
  var st = pickStream(ev, String(ctx.matchId || ''));
  if (!st || !st.url) return [];
  var row = await resolveUrl(ctx, String(st.url), String(st.name || 'TimStreams'), cfg);
  return row ? [row] : [];
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
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
      viewers: Number(ev.viewers || 0),
      sources: sources,
      catalog: 'forja_live',
      pluginId: pluginId,
    });
  });
  return rows;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') {
    var direct = String(ctx.url || ctx.embedUrl || '').trim();
    if (direct) {
      var row = await resolveUrl(ctx, direct, 'TimStreams', cfg);
      return row ? [row] : [];
    }
    return resolveByEvent(ctx, cfg);
  }
  return [];
}
