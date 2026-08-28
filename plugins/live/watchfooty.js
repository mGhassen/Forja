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

function watchfootySourceRank(source) {
  var key = String(source || '').toLowerCase();
  return Object.prototype.hasOwnProperty.call(WATCHFOOTY_SOURCE_PRIORITY, key)
    ? WATCHFOOTY_SOURCE_PRIORITY[key]
    : 99;
}

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

  if (ctx.live && typeof ctx.live.sportsEmbedUnlock === 'function') {
    try {
      var unlockedUrl = await ctx.live.sportsEmbedUnlock(url);
      if (unlockedUrl) {
        var origin = '';
        try {
          origin = new URL(url).origin;
        } catch (_) {}
        return [
          {
            url: String(unlockedUrl),
            headers: {
              Referer: url,
              Origin: origin || 'https://sportsembed.su',
              'User-Agent': ua(),
            },
            directPlayback: preferDirectPlayback(unlockedUrl),
          },
        ];
      }
    } catch (_) {}
  }

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

  return [];
}

async function resolveWatchfootyMatch(ctx, mid) {
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
      });
    }
    if (out.length >= 6) break;
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
