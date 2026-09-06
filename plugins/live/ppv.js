var SPECS = {
  "webOrigin": "https://ppv.st",
  "apis": [
    "https://api.ppv.st/api/streams",
    "https://api.ppv.cx/api/streams"
  ]
};

function ppvHeaders(cfg) {
  var origin = ((cfg && cfg.webOrigin) || 'https://ppv.st').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

function ppvIframesFromDetail(data) {
  if (!data) return [];
  var sources = data.sources;
  if (!Array.isArray(sources)) return [];
  var out = [];
  var seen = {};
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];
    if (!s) continue;
    var url = String(s.data || s.url || '').trim();
    if (!url || !/^https?:/i.test(url) || seen[url]) continue;
    seen[url] = 1;
    out.push(url);
  }
  return out;
}

function ppvPlayableUrl(data) {
  if (!data) return '';
  var fields = [data.m3u8, data.source, data.vip_mpegts];
  for (var i = 0; i < fields.length; i++) {
    var url = String(fields[i] || '').trim();
    if (url && /\.m3u8|\.mp4/i.test(url)) return url;
  }
  return '';
}

async function unlockPpvEmbed(ctx, iframe, cfg, headers) {
  var raw = String(iframe || '').trim();
  if (!raw) return null;
  // Direct HLS from the detail API is handled above; embed pages must unlock
  // to a native URL — never hand iframe HTML to the player.
  if (/\.m3u8|\.mp4/i.test(raw)) {
    return {
      url: raw,
      headers: headers || ppvHeaders(cfg),
      directPlayback: true,
    };
  }
  try {
    if (isEmbedIndiaUrl(raw)) {
      var embedIndia = await resolveEmbedIndia(ctx, raw, cfg);
      if (embedIndia && embedIndia.length) return embedIndia[0];
    }
    if (raw.indexOf('embed.st') >= 0) {
      var embedResolved = await resolveGoatEmbed(ctx, raw, cfg);
      if (embedResolved && embedResolved.length) return embedResolved[0];
    }
    if (isSportsEmbedUrl(raw) && ctx.live && typeof ctx.live.sportsEmbedUnlock === 'function') {
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
    }
  } catch (_) {}
  return null;
}

async function resolvePpv(ctx, cfg) {
  var streamId = String(ctx.matchId || (cfg && cfg.streamId) || '').replace(/^ppv_/, '');
  var iframe = String(ctx.embedUrl || ctx.iframe || (cfg && cfg.iframe) || '').trim();
  var headers = ppvHeaders(cfg);
  var embeds = [];
  if (iframe) embeds.push(iframe);

  if (streamId) {
    var apis = (cfg && cfg.apis) || [
      'https://api.ppv.st/api/streams',
      'https://api.ppv.cx/api/streams',
    ];
    for (var i = 0; i < apis.length; i++) {
      try {
        var base = apis[i].replace(/\/$/, '');
        var detail = await ctx.fetch(base + '/' + streamId, { headers: headers });
        if (!detail.ok) continue;
        var body = await detail.json();
        if (!body || body.success !== true || !body.data) continue;
        var source = ppvPlayableUrl(body.data);
        if (source) {
          return [{ url: source, headers: headers, directPlayback: true }];
        }
        var fromDetail = ppvIframesFromDetail(body.data);
        for (var j = 0; j < fromDetail.length; j++) {
          if (embeds.indexOf(fromDetail[j]) < 0) embeds.push(fromDetail[j]);
        }
        break;
      } catch (_) {}
    }
  }

  var out = [];
  var seen = {};
  for (var k = 0; k < embeds.length; k++) {
    var row = await unlockPpvEmbed(ctx, embeds[k], cfg, headers);
    if (!row || !row.url || seen[row.url]) continue;
    seen[row.url] = 1;
    out.push(row);
  }
  return out;
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  return resolvePpv(ctx, Object.assign({}, SPECS, ctx.config || {}));
}
