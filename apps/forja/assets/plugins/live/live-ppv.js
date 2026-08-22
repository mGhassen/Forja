function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function ppvHeaders(cfg) {
  var origin = (cfg.webOrigin || 'https://ppv.is').replace(/\/$/, '');
  return {
    Accept: 'application/json',
    Origin: origin,
    Referer: origin + '/',
    'User-Agent': ua(),
  };
}

function embedOrigin(cfg) {
  return (cfg.embedOrigin || 'https://embed.st').replace(/\/$/, '');
}

function varint(n) {
  var bytes = [];
  var v = n >>> 0;
  while (v > 0x7f) {
    bytes.push((v & 0x7f) | 0x80);
    v >>>= 7;
  }
  bytes.push(v);
  return bytes;
}

function utf8BytesAscii(str) {
  var out = [];
  var s = String(str);
  for (var i = 0; i < s.length; i++) out.push(s.charCodeAt(i) & 0xff);
  return out;
}

function encodeBody(source, id, stream) {
  var out = [];
  function fieldStr(field, value) {
    var body = utf8BytesAscii(value);
    out.push((field << 3) | 2);
    out.push.apply(out, varint(body.length));
    for (var i = 0; i < body.length; i++) out.push(body[i]);
  }
  fieldStr(1, source);
  fieldStr(2, id);
  fieldStr(3, stream);
  return out;
}

function latin1FromBytes(bytes) {
  var s = '';
  for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i] & 0xff);
  return s;
}

function bytesToHex(buf) {
  var arr = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  var hex = '';
  for (var i = 0; i < arr.length; i++) {
    hex += arr[i].toString(16).padStart(2, '0');
  }
  return hex;
}

async function arrayBuffer(res) {
  if (res && typeof res.arrayBuffer === 'function') return res.arrayBuffer();
  if (res && res._bodyB64) {
    var bin = atob(res._bodyB64);
    var buf = new ArrayBuffer(bin.length);
    var view = new Uint8Array(buf);
    for (var i = 0; i < bin.length; i++) view[i] = bin.charCodeAt(i);
    return buf;
  }
  var text = await res.text();
  var buf = new ArrayBuffer(text.length);
  var view = new Uint8Array(buf);
  for (var i = 0; i < text.length; i++) view[i] = text.charCodeAt(i) & 0xff;
  return buf;
}

function parseEmbedUrl(raw, cfg) {
  var u = String(raw || '').trim();
  if (!u) return null;
  try {
    var url = new URL(u);
    var em = url.pathname.match(/^\/embed\/([^/]+)\/([^/]+)\/(\d+)\/?$/);
    if (em) {
      return {
        origin: url.origin,
        source: em[1],
        id: em[2],
        stream: em[3],
        path: em[1] + '/' + em[2] + '/' + em[3],
      };
    }
  } catch (_) {}
  return null;
}

async function postFetch(ctx, slot, cfg) {
  var origin = slot.origin || embedOrigin(cfg);
  var referer = origin + '/embed/' + slot.path;
  var body = encodeBody(slot.source, slot.id, slot.stream);
  var res = await ctx.fetch(origin + '/fetch', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/octet-stream',
      Origin: origin,
      Referer: referer,
      'User-Agent': ua(),
    },
    body: latin1FromBytes(body),
  });
  if (!res.ok) throw new Error('embed /fetch ' + res.status);
  var goat = res.headers && (res.headers.get ? res.headers.get('goat') : res.headers['goat']);
  if (!goat) throw new Error('missing goat header');
  var buf = await arrayBuffer(res);
  return { bodyHex: bytesToHex(buf), goat: String(goat) };
}

async function resolveEmbedSt(ctx, iframe, cfg) {
  var slot = parseEmbedUrl(iframe, cfg);
  if (!slot) return null;
  var fetched = await postFetch(ctx, slot, cfg);
  var referer = (slot.origin || embedOrigin(cfg)) + '/';
  var m3u8 = '';
  if (ctx.live && typeof ctx.live.goatUnlock === 'function') {
    m3u8 = await ctx.live.goatUnlock(fetched.bodyHex, fetched.goat, slot);
  }
  if (!m3u8) return null;
  return [{
    url: m3u8,
    headers: {
      Referer: referer,
      Origin: new URL(referer).origin,
      'User-Agent': ua(),
    },
  }];
}

async function fetchStreams(ctx, cfg) {
  var apis = cfg.apis || [
    'https://api.ppv.st/api/streams',
    'https://api.ppv.cx/api/streams',
  ];
  for (var i = 0; i < apis.length; i++) {
    try {
      var res = await ctx.fetch(apis[i], { headers: ppvHeaders(cfg) });
      if (!res.ok) continue;
      var data = await res.json();
      if (!data || data.success !== true || !Array.isArray(data.streams)) continue;
      var rows = [];
      data.streams.forEach(function (cat) {
        var category = String(cat.category || 'Other');
        (cat.streams || []).forEach(function (s) {
          if (s.id == null) return;
          var starts = Number(s.starts_at || 0);
          rows.push({
            id: 'ppv_' + String(s.id),
            title: String(s.name || ''),
            category: category.toLowerCase().replace(/\s+/g, '-'),
            date: starts > 0 ? starts * 1000 : 0,
            poster: String(s.poster || ''),
            popular: Number(s.viewers || 0) > 50,
            airing: Number(s.viewers || 0) > 0,
            sources: [{
              source: 'ppv',
              id: String(s.id),
              iframe: String(s.iframe || ''),
            }],
            catalog: 'forja_live',
            pluginId: 'live-ppv',
          });
        });
      });
      if (rows.length) return rows;
    } catch (e) {
      ctx.error(e);
    }
  }
  return [];
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

async function resolvePpv(ctx, cfg) {
  var streamId = String(ctx.matchId || ctx.config.streamId || '').replace(/^ppv_/, '');
  var iframe = String(ctx.embedUrl || ctx.config.iframe || '').trim();
  if (streamId) {
    var apis = cfg.apis || [
      'https://api.ppv.st/api/streams',
      'https://api.ppv.cx/api/streams',
    ];
    var headers = ppvHeaders(cfg);
    for (var i = 0; i < apis.length; i++) {
      try {
        var base = apis[i].replace(/\/$/, '');
        var detail = await ctx.fetch(base + '/' + streamId, { headers: headers });
        if (!detail.ok) continue;
        var body = await detail.json();
        if (!body || body.success !== true || !body.data) continue;
        var source = ppvPlayableUrl(body.data);
        if (source) {
          return [{ url: source, headers: headers }];
        }
      } catch (_) {}
    }
  }
  if (iframe) {
    try {
      var embedResolved = await resolveEmbedSt(ctx, iframe, cfg);
      if (embedResolved) return embedResolved;
    } catch (_) {}
    return [{ webviewOnly: true, embedUrl: iframe }];
  }
  return [];
}

async function extract(ctx) {
  var cfg = ctx.config || {};
  var action = String(ctx.action || 'catalog');
  if (action === 'resolve') return resolvePpv(ctx, cfg);
  return fetchStreams(ctx, cfg);
}
