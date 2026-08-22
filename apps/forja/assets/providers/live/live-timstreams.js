function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function normCategory(raw) {
  var s = String(raw || 'other').toLowerCase();
  if (s.indexOf('football') >= 0 || s.indexOf('soccer') >= 0) return 'football';
  if (s.indexOf('basket') >= 0) return 'basketball';
  if (s.indexOf('hockey') >= 0 || s.indexOf('nhl') >= 0) return 'hockey';
  if (s.indexOf('mma') >= 0 || s.indexOf('ufc') >= 0) return 'mma';
  return s.replace(/\s+/g, '-');
}

function catalogRow(id, title, category, dateMs, sources, extra) {
  return Object.assign({
    id: id,
    title: title,
    category: category,
    date: dateMs,
    poster: '',
    popular: false,
    airing: false,
    sources: sources,
    catalog: 'forja_live',
    pluginId: extra.pluginId,
  }, extra || {});
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  var pluginId = 'live-timstreams';
  var api = cfg.api || 'https://timstreams.st/api/live-upcoming';

  if (action === 'resolve') {
    var url = String(ctx.url || ctx.embedUrl || '').trim();
    if (url && /\.m3u8|\.mp4/i.test(url)) {
      return [{ url: url, headers: { Referer: 'https://timstreams.st/', 'User-Agent': ua() } }];
    }
    if (url) {
      return [{ sniffPending: true, embedUrl: url, referer: 'https://timstreams.st/' }];
    }
    return [];
  }

  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua(), Accept: 'application/json' } });
  if (!res.ok) return [];
  var data = await res.json();
  var rows = [];
  (data.events || []).forEach(function (ev, idx) {
    var sources = (ev.streams || [])
      .filter(function (st) { return !st.vip; })
      .map(function (st, i) {
        return {
          source: 'timstreams',
          id: String(st.name || i),
          url: String(st.url || ''),
        };
      });
    if (!sources.length) return;
    rows.push(catalogRow(
      'ts_' + String(ev.url || idx),
      String(ev.name || 'TimStreams event'),
      normCategory(ev.genre && ev.genre.name ? ev.genre.name : 'other'),
      Date.now(),
      sources,
      { pluginId: pluginId, popular: ev.featured === true },
    ));
  });
  return rows;
}
