var SPECS = {
  "api": "https://timstreams.st/api/live-upcoming",
  "embedOrigin": "https://embed.st"
};

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
    if (ctx.live && typeof ctx.live.sportsEmbedUnlock === 'function') {
      try {
        var unlockedUrl = await ctx.live.sportsEmbedUnlock(raw);
        if (unlockedUrl) {
          var origin = '';
          try {
            origin = new URL(raw).origin;
          } catch (_) {}
          return {
            url: String(unlockedUrl),
            headers: {
              Referer: raw,
              Origin: origin || 'https://sportsembed.su',
              'User-Agent': ua(),
            },
            directPlayback: preferDirectPlayback(unlockedUrl),
          };
        }
      } catch (_) {}
    }

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

  if (isDaddyLiveUrl(raw)) {
    try {
      var daddy = await resolveDaddyLiveEmbed(ctx, raw, cfg);
      if (daddy && daddy.length) return daddy[0];
    } catch (_) {}
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

  // Unlock failed — omit (never hand embed HTML to native player).
  return null;
}

async function resolveByEvent(ctx, cfg) {
  var eventToken = String(ctx.eventId || '').replace(/^ts_/, '');
  if (!eventToken) return [];
  var events = await fetchEvents(ctx, cfg);
  var ev = findEvent(events, eventToken);
  if (!ev) return [];

  var wanted = String(ctx.matchId || ctx.embedUrl || ctx.url || '').trim();
  var streams = (ev.streams || []).filter(function (st) {
    return st && !st.vip && st.url;
  });
  if (!streams.length) return [];

  // Prefer the named source ref when Providers resolves one catalog row;
  // otherwise list every non-VIP mirror for the event.
  var selected = streams;
  if (wanted) {
    var hit = null;
    for (var i = 0; i < streams.length; i++) {
      var st = streams[i];
      if (String(st.name || '') === wanted || String(i) === wanted) {
        hit = st;
        break;
      }
      if (String(st.url || '').trim() === wanted) {
        hit = st;
        break;
      }
    }
    if (hit) selected = [hit];
  }

  var out = [];
  for (var j = 0; j < selected.length; j++) {
    var row = await resolveUrl(
      ctx,
      String(selected[j].url),
      String(selected[j].name || 'TimStreams'),
      cfg,
    );
    if (row) out.push(row);
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var direct = String(ctx.url || ctx.embedUrl || '').trim();
  if (direct) {
    var row = await resolveUrl(ctx, direct, 'TimStreams', cfg);
    return row ? [row] : [];
  }
  return resolveByEvent(ctx, cfg);
}
