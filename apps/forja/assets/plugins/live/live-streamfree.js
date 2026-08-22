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
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-streamfree';
  var origin = (cfg.origin || 'https://streamfree.top').replace(/\/$/, '');

  if (action === 'resolve') {
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

  var res = await ctx.fetch(origin + '/streams', {
    headers: { 'User-Agent': ua() },
  });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  Object.keys(data.streams || {}).forEach(function (category) {
    (data.streams[category] || []).forEach(function (s) {
      var id = s.stream_key || s.id;
      if (!id) return;
      rows.push({
        id: 'sf_' + id,
        title: String(s.name || ''),
        category: String(category).toLowerCase(),
        date: s.match_timestamp ? Number(s.match_timestamp) * 1000 : 0,
        poster: String(s.thumbnail_url || ''),
        popular: Number(s.viewers || 0) > 100,
        sources: [{ source: 'streamfree', id: String(id) }],
        catalog: 'forja_live',
        pluginId: pluginId,
      });
    });
  });
  return rows;
}
