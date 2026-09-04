var SPECS = {
  origin: 'https://streamfree.top',
  embedOrigin: 'https://embed.st',
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';
}

function buildQuery(obj) {
  return Object.keys(obj)
    .map(function (k) {
      return encodeURIComponent(k) + '=' + encodeURIComponent(String(obj[k]));
    })
    .join('&');
}

var QUALITY_PREFS = ['2160p', '1080p', '720p', '540p'];

/** Every available quality from status.qualities and/or status.sources.*.qualities */
function listAvailableQualities(status) {
  var out = [];
  var seen = {};
  function add(q) {
    var key = String(q || '');
    if (!key || seen[key]) return;
    seen[key] = 1;
    out.push(key);
  }

  var sources = status && status.sources;
  if (sources && typeof sources === 'object') {
    Object.keys(sources)
      .sort()
      .forEach(function (k) {
        var row = sources[k];
        if (!row || row.available === false) return;
        var q = row.qualities || {};
        for (var i = 0; i < QUALITY_PREFS.length; i++) {
          if (q[QUALITY_PREFS[i]]) add(QUALITY_PREFS[i]);
        }
        Object.keys(q).forEach(function (name) {
          if (q[name]) add(name);
        });
      });
  }

  var qualities = (status && status.qualities) || {};
  for (var j = 0; j < QUALITY_PREFS.length; j++) {
    if (qualities[QUALITY_PREFS[j]]) add(QUALITY_PREFS[j]);
  }
  Object.keys(qualities).forEach(function (name) {
    if (qualities[name]) add(name);
  });

  return out;
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

  var qualities = listAvailableQualities(status);
  if (!qualities.length) return [];

  var embedUrl = origin + '/embed/' + cat + '/' + sid;
  var html = await (
    await ctx.fetch(embedUrl, { headers: { 'User-Agent': ua() } })
  ).text();
  var tok = html.match(/_0x\s+=\s+(.*?);/s);
  if (!tok) {
    // Keep the embed listed — host can retry on tap.
    return [
      {
        url: embedUrl,
        name: 'StreamFree',
        headers: { Referer: embedUrl, Origin: origin, 'User-Agent': ua() },
        directPlayback: false,
        viewers: Number(ctx.viewers || 0),
      },
    ];
  }

  var tokens = JSON.parse(tok[1]);
  var viewers = Number(ctx.viewers || 0);
  var out = [];
  var seen = {};
  for (var i = 0; i < qualities.length; i++) {
    var quality = qualities[i];
    var m3uInfo = tokens[quality];
    if (!m3uInfo || typeof m3uInfo !== 'object') continue;
    var url =
      origin + '/live/' + sid + quality + '/index.m3u8?' + buildQuery(m3uInfo);
    if (seen[url]) continue;
    seen[url] = 1;
    out.push({
      url: url,
      name: 'StreamFree ' + quality,
      headers: { Referer: embedUrl, Origin: origin, 'User-Agent': ua() },
      directPlayback: preferDirectPlayback(url),
      viewers: viewers,
    });
  }

  if (out.length) return out;

  return [
    {
      url: embedUrl,
      name: 'StreamFree',
      headers: { Referer: embedUrl, Origin: origin, 'User-Agent': ua() },
      directPlayback: false,
      viewers: viewers,
    },
  ];
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
