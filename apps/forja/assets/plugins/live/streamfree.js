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

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];

  var cfg = ctx.config || {};
  var origin = (cfg.origin || 'https://streamfree.top').replace(/\/$/, '');
  var cat = String(ctx.category || ctx.config.category || 'soccer');
  var sid = String(ctx.matchId || '').replace(/^sf_/, '');
  if (!sid) return [];

  var statusRes = await ctx.fetch(origin + '/api/stream-status/' + sid, {
    headers: { 'User-Agent': ua() },
  });
  if (!statusRes.ok) return [];
  var status = await statusRes.json();
  if (!status.available) return [];

  var qualities = status.qualities || {};
  var prefs = ['2160p', '1080p', '720p', '540p'];
  var quality = null;
  for (var i = 0; i < prefs.length; i++) {
    if (qualities[prefs[i]]) {
      quality = prefs[i];
      break;
    }
  }
  if (!quality) return [];

  var embedUrl = origin + '/embed/' + cat + '/' + sid;
  var html = await (
    await ctx.fetch(embedUrl, { headers: { 'User-Agent': ua() } })
  ).text();
  var tok = html.match(/_0x\s+=\s+(.*?);/s);
  if (!tok) return [];
  var tokens = JSON.parse(tok[1]);
  var m3uInfo = tokens[quality];
  if (!m3uInfo || typeof m3uInfo !== 'object') return [];

  var base =
    origin + '/live/' + sid + quality + '/index.m3u8?' + buildQuery(m3uInfo);
  return [
    {
      url: base,
      headers: { Referer: embedUrl, Origin: origin, 'User-Agent': ua() },
    },
  ];
}
