function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function embedReferer(raw) {
  try {
    return new URL(String(raw || '').trim()).origin + '/';
  } catch (_) {
    return 'https://streamic.st/';
  }
}

async function fetchList(ctx, cfg) {
  var api = cfg.api || 'https://streamic.st/api/J.php';
  var res = await ctx.fetch(api, { headers: { 'User-Agent': ua() } });
  if (!res.ok) return [];
  var data = await res.json();
  return Array.isArray(data) ? data : (data.events || data.streams || []);
}

function resolveOne(ctx, url, name) {
  var ref = embedReferer(url);
  if (/\.m3u8/i.test(url)) {
    return {
      url: url,
      name: name || 'Streamic',
      headers: { Referer: ref, Origin: ref.replace(/\/$/, ''), 'User-Agent': ua() },
    };
  }
  if (url) {
    return { webviewOnly: true, embedUrl: url, referer: ref, name: name || 'Streamic' };
  }
  return null;
}

function collectEmbeds(ctx, m) {
  var out = [];
  (m._embeds || []).forEach(function (group) {
    var lang = String(group.language || '').trim();
    (group.embeds || []).forEach(function (e) {
      var url = String(e.embed || e.url || '').trim();
      if (!url) return;
      var label = String(e.label || '').trim();
      var name = lang && label ? lang + ' · ' + label : lang || label || 'Streamic';
      var row = resolveOne(ctx, url, name);
      if (row) out.push(row);
    });
  });
  if (!out.length) {
    var direct = String(m.url || m.link || '').trim();
    if (direct) {
      var row = resolveOne(ctx, direct, 'Streamic');
      if (row) out.push(row);
    }
  }
  return out;
}

async function resolveByEvent(ctx, cfg) {
  var eventKey = String(ctx.eventId || ctx.matchId || '').replace(/^sic_/, '');
  if (!eventKey) return [];
  var list = await fetchList(ctx, cfg);
  for (var i = 0; i < list.length; i++) {
    var m = list[i];
    if (String(m.id || i) === eventKey) {
      return collectEmbeds(ctx, m);
    }
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  var cfg = ctx.config || {};
  var direct = String(ctx.url || ctx.embedUrl || '').trim();
  if (direct) {
    var row = resolveOne(ctx, direct, 'Streamic');
    return row ? [row] : [];
  }
  return resolveByEvent(ctx, cfg);
}
