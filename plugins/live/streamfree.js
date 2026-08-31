var SPECS = {
  "origin": "https://streamfree.top"
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';
}

function pluginIdFromCtx(ctx, cfg) {
  return String(ctx.pluginId || cfg.pluginId || 'streamfree');
}

function absUrl(origin, path) {
  var p = String(path || '').trim();
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  if (p.charAt(0) !== '/') p = '/' + p;
  return origin + p;
}

function buildQuery(obj) {
  return Object.keys(obj)
    .map(function (k) {
      return encodeURIComponent(k) + '=' + encodeURIComponent(String(obj[k]));
    })
    .join('&');
}

async function fetchCatalog(ctx, cfg) {
  var pluginId = pluginIdFromCtx(ctx, cfg);
  var origin = cfg.origin.replace(/\/$/, '');
  var res = await ctx.fetch(origin + '/streams', { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  Object.keys(data.streams || {}).forEach(function (category) {
    (data.streams[category] || []).forEach(function (s) {
      var id = s.stream_key || s.id;
      if (!id) return;
      var team1 = s.team1 || {};
      var team2 = s.team2 || {};
      var homeBadge = String(team1.logo || '');
      var awayBadge = String(team2.logo || '');
      var poster = absUrl(origin, s.thumbnail_url) || homeBadge || awayBadge;
      var row = {
        id: 'sf_' + id,
        title: String(s.name || ''),
        category: String(category).toLowerCase(),
        date: s.match_timestamp ? Number(s.match_timestamp) * 1000 : 0,
        poster: poster,
        popular: Number(s.viewers || 0) > 100,
        airing: false,
        viewers: Number(s.viewers || 0),
        sources: [{ source: 'streamfree', id: String(id) }],
        catalog: 'forja_live',
        pluginId: pluginId,
      };
      if (team1.name) row.homeTeam = String(team1.name);
      if (team2.name) row.awayTeam = String(team2.name);
      if (homeBadge) row.homeBadge = homeBadge;
      if (awayBadge) row.awayBadge = awayBadge;
      rows.push(row);
    });
  });
  return rows;
}

async function resolveStream(ctx, cfg) {
  var origin = cfg.origin.replace(/\/$/, '');
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

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  if (action === 'catalog') return fetchCatalog(ctx, cfg);
  if (action === 'resolve') return resolveStream(ctx, cfg);
  return [];
}
