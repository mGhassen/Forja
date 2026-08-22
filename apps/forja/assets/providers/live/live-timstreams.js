function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  return s.replace(/\s+/g, '-');
}

function embedReferer(raw) {
  try {
    return new URL(String(raw || '').trim()).origin + '/';
  } catch (_) {
    return 'https://timstreams.st/';
  }
}

async function fetchEvents(ctx, cfg) {
  var api = cfg.api || 'https://timstreams.st/api/live-upcoming';
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

function resolveUrl(ctx, url) {
  var ref = embedReferer(url);
  if (/\.m3u8|\.mp4/i.test(url)) {
    return [{ url: url, headers: { Referer: ref, Origin: ref.replace(/\/$/, ''), 'User-Agent': ua() } }];
  }
  if (url) {
    return [{ sniffPending: true, embedUrl: url, referer: ref }];
  }
  return [];
}

async function resolveByEvent(ctx, cfg) {
  var eventToken = String(ctx.eventId || '').replace(/^ts_/, '');
  if (!eventToken) return [];
  var events = await fetchEvents(ctx, cfg);
  var ev = findEvent(events, eventToken);
  if (!ev) return [];
  var st = pickStream(ev, String(ctx.matchId || ''));
  if (!st || !st.url) return [];
  return resolveUrl(ctx, String(st.url));
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-timstreams';
  var api = cfg.api || 'https://timstreams.st/api/live-upcoming';

  if (action === 'resolve') {
    var direct = String(ctx.url || ctx.embedUrl || '').trim();
    if (direct) return resolveUrl(ctx, direct);
    return resolveByEvent(ctx, cfg);
  }

  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua(), Accept: 'application/json' } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  (data.events || []).forEach(function (ev, idx) {
    var sources = (ev.streams || [])
      .filter(function (st) { return !st.vip; })
      .map(function (st, i) {
        return { source: 'timstreams', id: String(st.name || i) };
      });
    if (!sources.length) return;
    rows.push({
      id: 'ts_' + String(ev.url || idx),
      title: String(ev.name || 'TimStreams event'),
      category: normCategory(ev.genre && ev.genre.name ? ev.genre.name : 'other'),
      date: Date.now(),
      poster: '',
      popular: ev.featured === true,
      airing: false,
      sources: sources,
      catalog: 'forja_live',
      pluginId: pluginId,
    });
  });
  return rows;
}
