var WATCHFOOTY_REFERER = 'https://watchfooty.st/';

async function resolveWatchfootyEmbed(ctx, embed) {
  var url = String(embed || '').trim();
  if (!url) return [];

  if (/\.m3u8|\.mp4/i.test(url)) {
    return [
      {
        url: url,
        headers: { Referer: WATCHFOOTY_REFERER, 'User-Agent': ua() },
        directPlayback: preferDirectPlayback(url),
      },
    ];
  }

  if (!isSportsEmbedUrl(url)) return [];

  var mapped = embedStUrlFromSportsEmbed(url);
  if (mapped) {
    try {
      var unlocked = await resolveGoatEmbed(ctx, mapped, ctx.config || {});
      if (unlocked) return unlocked;
    } catch (_) {}
  }

  var candidates = embedStAdminCandidatesFromSportsEmbed(url);
  for (var i = 0; i < candidates.length; i++) {
    try {
      var candidate = await resolveGoatEmbed(ctx, candidates[i], ctx.config || {});
      if (candidate) return candidate;
    } catch (_) {}
  }

  if (ctx.live && typeof ctx.live.sniffEmbed === 'function') {
    var sniffed = await ctx.live.sniffEmbed(url, WATCHFOOTY_REFERER);
    if (sniffed) {
      var origin = '';
      try {
        origin = new URL(url).origin;
      } catch (_) {}
      return [
        {
          url: sniffed,
          headers: {
            Referer: url,
            Origin: origin,
            'User-Agent': ua(),
          },
          directPlayback: preferDirectPlayback(sniffed),
        },
      ];
    }
  }

  return [];
}

async function resolveWatchfootyMatch(ctx, mid) {
  var res = await ctx.fetch('https://api.watchfooty.st/api/v1/match/' + mid, {
    headers: { 'User-Agent': ua(), Accept: 'application/json' },
  });
  if (!res.ok) return [];
  var data = await res.json();
  var match = Array.isArray(data) ? data[0] : data;
  var out = [];
  var streams = (match && match.streams) || [];
  for (var i = 0; i < streams.length; i++) {
    var s = streams[i];
    if (!s || !s.url) continue;
    var embed = String(s.url).trim();
    var resolved = await resolveWatchfootyEmbed(ctx, embed);
    if (resolved.length) {
      for (var j = 0; j < resolved.length; j++) {
        var row = resolved[j];
        out.push({
          url: row.url,
          name: 'WatchFooty ' + (out.length + 1),
          headers: row.headers || { Referer: WATCHFOOTY_REFERER, 'User-Agent': ua() },
          directPlayback: row.directPlayback === true,
        });
      }
      continue;
    }
    out.push({
      url: embed,
      name: 'WatchFooty ' + (i + 1),
      headers: { Referer: WATCHFOOTY_REFERER, 'User-Agent': ua() },
    });
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];

  var embed = String(ctx.embedUrl || ctx.url || '').trim();
  if (embed) {
    var fromEmbed = await resolveWatchfootyEmbed(ctx, embed);
    if (fromEmbed.length) return fromEmbed;
  }

  var mid = String(ctx.matchId || '').replace(/^wf_/, '');
  if (!mid) return [];
  return resolveWatchfootyMatch(ctx, mid);
}
