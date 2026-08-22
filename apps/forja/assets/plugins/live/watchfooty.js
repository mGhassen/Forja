function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];

  var mid = String(ctx.matchId || '').replace(/^wf_/, '');
  if (!mid) return [];
  var res = await ctx.fetch('https://api.watchfooty.st/api/v1/match/' + mid, {
    headers: { 'User-Agent': ua(), Accept: 'application/json' },
  });
  if (!res.ok) return [];
  var data = await res.json();
  var match = Array.isArray(data) ? data[0] : data;
  var out = [];
  (match && match.streams || []).forEach(function (s, i) {
    if (!s.url) return;
    out.push({
      url: String(s.url),
      name: 'WatchFooty ' + (i + 1),
      headers: { Referer: 'https://watchfooty.st/', 'User-Agent': ua() },
    });
  });
  return out;
}
