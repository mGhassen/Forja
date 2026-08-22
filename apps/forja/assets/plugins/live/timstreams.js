function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
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
    return [{ webviewOnly: true, embedUrl: url, referer: ref }];
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
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  var cfg = ctx.config || {};
  var direct = String(ctx.url || ctx.embedUrl || '').trim();
  if (direct) return resolveUrl(ctx, direct);
  return resolveByEvent(ctx, cfg);
}
