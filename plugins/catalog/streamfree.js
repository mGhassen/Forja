var SPECS = {
  "origin": "https://streamfree.top"
};

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function absUrl(origin, path) {
  var p = String(path || '').trim();
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  if (p.charAt(0) !== '/') p = '/' + p;
  return origin + p;
}

async function extract(ctx) {
  var action = String(ctx.action || 'catalog');
  if (action !== 'catalog') return [];

  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var pluginId = String(cfg.providerId || 'live-streamfree');
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
      // Relative `/thumbnails/...` — without origin, Dart prefixes Streamed CDN.
      var poster = absUrl(origin, s.thumbnail_url) || homeBadge || awayBadge;
      var viewers = Number(s.viewers || 0);
      var row = {
        id: 'sf_' + id,
        title: String(s.name || ''),
        category: String(category).toLowerCase(),
        date: s.match_timestamp ? Number(s.match_timestamp) * 1000 : 0,
        poster: poster,
        popular: viewers > 50,
        airing: viewers > 0,
        viewers: viewers,
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
