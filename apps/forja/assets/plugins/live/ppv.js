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

function ppvIframeFromDetail(data) {
  if (!data) return '';
  var sources = data.sources;
  if (!Array.isArray(sources)) return '';
  var picked = '';
  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];
    if (!s) continue;
    var url = String(s.data || s.url || '').trim();
    if (!url || !/^https?:/i.test(url)) continue;
    if (s.default === true) return url;
    if (!picked) picked = url;
  }
  return picked;
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

async function resolveEmbedIndia(ctx, iframe, cfg) {
  var url = String(iframe || '').trim();
  if (!url || url.indexOf('embedindia') < 0) return null;
  if (ctx.live && typeof ctx.live.sniffPpvEmbed === 'function') {
    var sniffed = await ctx.live.sniffPpvEmbed(url);
    if (sniffed) {
      var embedOrigin = '';
      try {
        embedOrigin = new URL(url).origin;
      } catch (_) {}
      return [{
        url: String(sniffed),
        headers: {
          Referer: url,
          Origin: embedOrigin,
          'User-Agent': ua(),
        },
      }];
    }
  }
  return null;
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
        var fromDetail = ppvIframeFromDetail(body.data);
        if (fromDetail) iframe = fromDetail;
      } catch (_) {}
    }
  }
  if (iframe) {
    try {
      var embedIndia = await resolveEmbedIndia(ctx, iframe, cfg);
      if (embedIndia) return embedIndia;
      var embedResolved = await resolveEmbedSt(ctx, iframe, cfg);
      if (embedResolved) return embedResolved;
    } catch (_) {}
  }
  return [];
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  return resolvePpv(ctx, ctx.config || {});
}
