var SPECS = {
  origin: 'https://streamfree.top',
  embedOrigin: 'https://embed.st',
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';
}

function tokenQuery(info) {
  // Web player order: _t &_e &_n (signed playlist auth).
  return (
    '_t=' +
    encodeURIComponent(String(info._t)) +
    '&_e=' +
    encodeURIComponent(String(info._e)) +
    '&_n=' +
    encodeURIComponent(String(info._n))
  );
}

var QUALITY_PREFS = ['2160p', '1080p', '720p', '540p'];

/**
 * Available (source, quality) pairs from status.
 * Source "1" = Direct (no path suffix); "2".."5" append after quality
 * (`/live-cdn/{key}{quality}{suffix}/index.m3u8`).
 */
function listAvailableSourceQualities(status) {
  var out = [];
  var seen = {};
  function add(src, q) {
    var source = String(src || '');
    var quality = String(q || '');
    if (!source || !quality) return;
    var key = source + '|' + quality;
    if (seen[key]) return;
    seen[key] = 1;
    out.push({ source: source, quality: quality });
  }

  function addFromMap(src, qmap) {
    if (!qmap || typeof qmap !== 'object') return;
    for (var i = 0; i < QUALITY_PREFS.length; i++) {
      if (qmap[QUALITY_PREFS[i]]) add(src, QUALITY_PREFS[i]);
    }
    Object.keys(qmap).forEach(function (name) {
      if (qmap[name]) add(src, name);
    });
  }

  var sources = status && status.sources;
  if (sources && typeof sources === 'object') {
    Object.keys(sources)
      .sort()
      .forEach(function (k) {
        var row = sources[k];
        if (!row || row.available === false) return;
        addFromMap(k, row.qualities || {});
      });
  }

  // Legacy top-level maps = source 1 / source 2.
  addFromMap('1', (status && status.qualities) || {});
  addFromMap('2', (status && status.qualities2) || {});

  return out;
}

function sourceSuffix(source) {
  var n = String(source || '1');
  return n === '1' ? '' : n;
}

async function fetchEmbedTokens(ctx, embedUrl) {
  var html = await (
    await ctx.fetch(embedUrl, { headers: { 'User-Agent': ua() } })
  ).text();
  var tok = html.match(/_0x\s+=\s+(.*?);/s);
  if (!tok) return null;
  try {
    return JSON.parse(tok[1]);
  } catch (_) {
    return null;
  }
}

async function resolveServerPath(ctx, origin, sid, embedUrl) {
  try {
    var keyRes = await ctx.fetch(origin + '/get-stream-key/' + sid, {
      headers: {
        'User-Agent': ua(),
        Referer: embedUrl,
        Origin: origin,
      },
    });
    if (keyRes.ok) {
      var key = await keyRes.json();
      if (key && key.is_external && key.external_url) {
        return { external: String(key.external_url) };
      }
      // Match website: cdn → /live-cdn/, else /live-origin/.
      if (key && key.server_name && key.server_name !== 'origin') {
        return { prefix: '/live-cdn/' };
      }
    }
  } catch (_) {}
  return { prefix: '/live-origin/' };
}

async function resolveStreamfreeTop(ctx, cfg) {
  var origin = cfg.origin.replace(/\/$/, '');
  var cat = String(ctx.category || (ctx.config && ctx.config.category) || 'soccer');
  var sid = String(ctx.matchId || '').replace(/^sf_/, '');
  if (!sid) return [];

  var statusRes = await ctx.fetch(origin + '/api/stream-status/' + sid, {
    headers: { 'User-Agent': ua() },
  });
  if (!statusRes.ok) return [];
  var status = await statusRes.json();
  if (!status.available) return [];

  var pairs = listAvailableSourceQualities(status);
  if (!pairs.length) return [];

  var viewers = Number(ctx.viewers || 0);
  var out = [];
  var seen = {};
  var tokenCache = {};
  var serverCache = {};

  for (var i = 0; i < pairs.length; i++) {
    var source = pairs[i].source;
    var quality = pairs[i].quality;
    var suffix = sourceSuffix(source);
    var embedUrl = origin + '/embed/' + cat + '/' + sid + suffix;

    if (!tokenCache[suffix]) {
      tokenCache[suffix] = await fetchEmbedTokens(ctx, embedUrl);
    }
    var tokens = tokenCache[suffix];
    if (!tokens) continue;

    var m3uInfo = tokens[quality];
    if (!m3uInfo || typeof m3uInfo !== 'object') continue;

    if (!serverCache[suffix]) {
      serverCache[suffix] = await resolveServerPath(ctx, origin, sid, embedUrl);
    }
    var server = serverCache[suffix];
    var url;
    if (server.external) {
      url = server.external;
    } else {
      url =
        origin +
        (server.prefix || '/live-origin/') +
        sid +
        quality +
        suffix +
        '/index.m3u8?' +
        tokenQuery(m3uInfo);
    }
    if (seen[url]) continue;
    seen[url] = 1;

    var label = 'StreamFree ' + quality;
    if (suffix) label += ' · src ' + suffix;

    out.push({
      url: url,
      name: label,
      headers: { Referer: embedUrl, Origin: origin, 'User-Agent': ua() },
      directPlayback: preferDirectPlayback(url),
      viewers: viewers,
    });
  }

  // Unlock miss — omit (host catalog may still list the embed for unlock-on-tap).
  return out;
}

async function resolveStream(ctx, cfg) {
  var embed = String(ctx.embedUrl || ctx.url || ctx.iframe || '').trim();
  if (embed && (embed.indexOf('embed.st') >= 0 || parseEmbedUrl(embed, cfg))) {
    try {
      var goat = await resolveGoatEmbed(ctx, embed, cfg);
      if (goat && goat.length) {
        var viewers = Number(ctx.viewers || 0);
        return goat.map(function (row) {
          row.viewers = viewers;
          return row;
        });
      }
    } catch (_) {}
  }
  return resolveStreamfreeTop(ctx, cfg);
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  return resolveStream(ctx, cfg);
}
