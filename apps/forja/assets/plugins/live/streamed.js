function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
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
    var api = url.pathname.match(/^\/api\/stream\/([^/]+)\/([^/]+)\/?$/);
    if (api) {
      var streamNo = url.searchParams.get('stream') || '1';
      return {
        origin: embedOrigin(cfg),
        source: api[1],
        id: api[2],
        stream: streamNo,
        path: api[1] + '/' + api[2] + '/' + streamNo,
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

async function resolveGolf(ctx, slot, cfg) {
  var origin = slot.origin || embedOrigin(cfg);
  var embedUrl = origin + '/embed/' + slot.path;
  var embedRes = await ctx.fetch(embedUrl, {
    headers: { Referer: origin + '/', 'User-Agent': ua() },
  });
  var embedHtml = await embedRes.text();
  var iframeM = embedHtml.match(/iframe src="([^"]+)"/);
  if (!iframeM) throw new Error('golf iframe not found');
  var streamedUrl = iframeM[1].replace(/&amp;/g, '&');
  var streamedHtml = await (await ctx.fetch(streamedUrl, {
    headers: { Referer: embedUrl, 'User-Agent': ua() },
  })).text();
  var fidM = streamedHtml.match(/fid="([^"]+)"/);
  if (!fidM) throw new Error('golf fid not found');
  var playerUrl =
    'https://exposestrat.com/maestrohd1.php?player=desktop&live=' +
    encodeURIComponent(fidM[1]);
  var playerHtml = await (await ctx.fetch(playerUrl, {
    headers: { Referer: streamedUrl, 'User-Agent': ua() },
  })).text();
  var m3u8M = playerHtml.match(/return\(\[("[^"]+"(?:,"[^"]+")*)\]\.join\(""\)/);
  if (!m3u8M) throw new Error('golf m3u8 not found');
  return JSON.parse('[' + m3u8M[1] + ']').join('');
}

async function resolveStream(ctx, cfg) {
  var embedUrl = String(ctx.embedUrl || ctx.url || '').trim();
  var slot = parseEmbedUrl(embedUrl, cfg);
  if (!slot) {
    if (ctx.source && ctx.matchId && ctx.stream) {
      slot = {
        origin: embedOrigin(cfg),
        source: String(ctx.source),
        id: String(ctx.matchId),
        stream: String(ctx.stream),
        path: ctx.source + '/' + ctx.matchId + '/' + ctx.stream,
      };
    }
  }
  if (!slot) throw new Error('streamed resolve: missing embed slot');

  var m3u8 = '';
  var referer = (slot.origin || embedOrigin(cfg)) + '/';
  if (slot.source === 'golf') {
    m3u8 = await resolveGolf(ctx, slot, cfg);
    referer = 'https://exposestrat.com/';
  } else {
    var fetched = await postFetch(ctx, slot, cfg);
    referer = (slot.origin || embedOrigin(cfg)) + '/';
    m3u8 = '';
    if (ctx.live && typeof ctx.live.goatUnlock === 'function') {
      m3u8 = await ctx.live.goatUnlock(fetched.bodyHex, fetched.goat, slot);
    }
    if (!m3u8) throw new Error('goat unlock failed');
    return [{
      url: m3u8,
      headers: {
        Referer: referer,
        Origin: new URL(referer).origin,
        'User-Agent': ua(),
      },
    }];
  }
  return [{
    url: m3u8,
    headers: {
      Referer: referer,
      Origin: new URL(referer).origin,
      'User-Agent': ua(),
    },
  }];
}

async function extract(ctx) {
  var action = String(ctx.action || 'resolve');
  if (action !== 'resolve') return [];
  return resolveStream(ctx, ctx.config || {});
}
