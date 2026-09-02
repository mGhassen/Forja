/* Shared embed.st GOAT helpers — prepended for live/*.js plugins. */

function ua() {
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

function embedOrigin(cfg) {
  return ((cfg && cfg.embedOrigin) || 'https://embed.st').replace(/\/$/, '');
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

function playbackHeadersForSlot(slot, cfg) {
  var origin = (slot.origin || embedOrigin(cfg)).replace(/\/$/, '');
  var source = String(slot.source || '').toLowerCase();
  var path = String(slot.path || '');
  if (source === 'admin') {
    return { Referer: origin + '/', Origin: origin, 'User-Agent': ua() };
  }
  if ((source === 'delta' || source === 'echo') && path) {
    return {
      Referer: origin + '/embed/' + path,
      Origin: origin,
      'User-Agent': ua(),
    };
  }
  if (path) {
    return {
      Referer: origin + '/embed/' + path,
      Origin: origin,
      'User-Agent': ua(),
    };
  }
  return { Referer: origin + '/', Origin: origin, 'User-Agent': ua() };
}

function preferDirectPlayback(m3u8Url) {
  var path = '';
  var host = '';
  try {
    var u = new URL(String(m3u8Url || ''));
    path = u.pathname.toLowerCase();
    host = u.host.toLowerCase();
  } catch (_) {}
  if (host.indexOf('wfty.st') >= 0) return true;
  if (host.indexOf('indianservers.st') >= 0) return true;
  if (host.indexOf('streamfree.top') >= 0 && path.indexOf('/live/') >= 0) return true;
  return (
    path.indexOf('/delta/stream/') >= 0 ||
    path.indexOf('/echo/stream/') >= 0 ||
    path.indexOf('/streamfree/stream/') >= 0
  );
}

var SPORTS_EMBED_HOSTS = ['sportsembed.su', 'spiderembed.top'];
var GOAT_SLOT_SOURCES = {
  admin: 1,
  delta: 1,
  echo: 1,
  golf: 1,
  ppv: 1,
  bravo: 1,
};

function isSportsEmbedHost(host) {
  var h = String(host || '').toLowerCase();
  if (!h) return false;
  for (var i = 0; i < SPORTS_EMBED_HOSTS.length; i++) {
    var needle = SPORTS_EMBED_HOSTS[i];
    if (h === needle || h.endsWith('.' + needle)) return true;
  }
  return false;
}

function isSportsEmbedUrl(url) {
  try {
    return isSportsEmbedHost(new URL(String(url || '').trim()).host);
  } catch (_) {
    return false;
  }
}

function embedStUrlFromSportsEmbed(raw) {
  try {
    var uri = new URL(String(raw || '').trim());
    if (!isSportsEmbedHost(uri.host)) return null;
    var segs = uri.pathname.split('/').filter(function (s) {
      return s.length > 0;
    });
    if (segs.length < 5 || segs[0] !== 'embed') return null;
    var slug = segs[2];
    var source = segs[3].toLowerCase();
    var stream = segs[4];
    if (!GOAT_SLOT_SOURCES[source]) return null;
    return embedOrigin({}) + '/embed/' + source + '/' + slug + '/' + stream;
  } catch (_) {
    return null;
  }
}

function embedStAdminCandidatesFromSportsEmbed(raw) {
  try {
    var uri = new URL(String(raw || '').trim());
    if (!isSportsEmbedHost(uri.host)) return [];
    var segs = uri.pathname.split('/').filter(function (s) {
      return s.length > 0;
    });
    if (segs.length < 5 || segs[0] !== 'embed') return [];
    var slug = segs[2];
    var quality = segs[3].toLowerCase();
    var stream = segs[4];
    if (quality !== 'hd' && quality !== 'platinum') return [];
    var parts = slug.split('-').filter(function (p) {
      return p.length > 0;
    });
    if (parts.length < 2) return [];
    var ids = {};
    ids['ppv-' + slug] = 1;
    for (var i = 1; i < parts.length; i++) {
      var home = parts.slice(0, i).join('-');
      var away = parts.slice(i).join('-');
      ids['ppv-' + home + '-vs-' + away] = 1;
    }
    var out = [];
    var origin = embedOrigin({});
    for (var id in ids) {
      out.push(origin + '/embed/admin/' + id + '/' + stream);
    }
    return out;
  } catch (_) {
    return [];
  }
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
  var streamedHtml = await (
    await ctx.fetch(streamedUrl, {
      headers: { Referer: embedUrl, 'User-Agent': ua() },
    })
  ).text();
  var fidM = streamedHtml.match(/fid="([^"]+)"/);
  if (!fidM) throw new Error('golf fid not found');
  var playerUrl =
    'https://exposestrat.com/maestrohd1.php?player=desktop&live=' +
    encodeURIComponent(fidM[1]);
  var playerHtml = await (
    await ctx.fetch(playerUrl, {
      headers: { Referer: streamedUrl, 'User-Agent': ua() },
    })
  ).text();
  var m3u8M = playerHtml.match(/return\(\[("[^"]+"(?:,"[^"]+")*)\]\.join\(""\)/);
  if (!m3u8M) throw new Error('golf m3u8 not found');
  return JSON.parse('[' + m3u8M[1] + ']').join('');
}

async function resolveGoatEmbed(ctx, embedUrl, cfg) {
  var slot = parseEmbedUrl(embedUrl, cfg);
  if (!slot) return null;
  if (slot.source === 'golf') {
    var golfUrl = await resolveGolf(ctx, slot, cfg);
    return [
      {
        url: golfUrl,
        headers: {
          Referer: 'https://exposestrat.com/',
          Origin: 'https://exposestrat.com',
          'User-Agent': ua(),
        },
      },
    ];
  }
  var fetched = await postFetch(ctx, slot, cfg);
  var m3u8 = '';
  if (ctx.live && typeof ctx.live.goatUnlock === 'function') {
    m3u8 = await ctx.live.goatUnlock(fetched.bodyHex, fetched.goat, slot);
  }
  if (!m3u8) return null;
  return [
    {
      url: m3u8,
      headers: playbackHeadersForSlot(slot, cfg),
      directPlayback: preferDirectPlayback(m3u8),
    },
  ];
}

function embedIndiaOrigin(cfg) {
  return ((cfg && cfg.embedIndiaOrigin) || 'https://embedindia.st').replace(/\/$/, '');
}

function isEpiEmbedsUrl(url) {
  try {
    var host = new URL(String(url || '').trim()).host.toLowerCase();
    return host === 'epiembeds.online' || host.endsWith('.epiembeds.online');
  } catch (_) {
    return false;
  }
}

function isEmbedIndiaUrl(url) {
  try {
    var host = new URL(String(url || '').trim()).host.toLowerCase();
    return host === 'embedindia.st' || host.endsWith('.embedindia.st');
  } catch (_) {
    return false;
  }
}

function isGasmJwEmbedUrl(url) {
  return isEmbedIndiaUrl(url) || isEpiEmbedsUrl(url);
}

function parseEmbedIndiaUrl(raw) {
  var u = String(raw || '').trim();
  if (!u || !isEmbedIndiaUrl(u)) return null;
  try {
    var url = new URL(u);
    // Sports: /embed/{league}/{date}/{slug}
    // Events (UFC etc.): /embed/{slug} or /embed/{slug}/{variant}
    var em = url.pathname.match(/^\/embed\/(.+?)\/?$/);
    if (!em) return null;
    var path = em[1].replace(/\/+$/, '');
    if (!path || path.indexOf('..') >= 0) return null;
    var parts = path.split('/').filter(Boolean);
    if (!parts.length) return null;
    var gid = url.searchParams.get('gid') || '';
    return {
      origin: url.origin,
      league: parts.length >= 3 ? parts[0] : '',
      date: parts.length >= 3 ? parts[1] : '',
      slug: parts.length >= 3 ? parts[2] : parts[parts.length - 1],
      gid: gid,
      path: path,
    };
  } catch (_) {}
  return null;
}

function encodeEmbedIndiaBody(path) {
  var out = [];
  var body = utf8BytesAscii(path);
  out.push((1 << 3) | 2);
  out.push.apply(out, varint(body.length));
  for (var i = 0; i < body.length; i++) out.push(body[i]);
  return out;
}

function playbackHeadersForEmbedIndia(slot, embedUrl) {
  // Path only — ?gid= on Referer 403s *.indianservers.st (nginx). Unlock /fetch still uses gid.
  var origin = (slot.origin || embedIndiaOrigin({})).replace(/\/$/, '');
  var path = String(slot.path || '');
  var fromEmbed = String(embedUrl || '').trim();
  var referer;
  if (fromEmbed) {
    try {
      var u = new URL(fromEmbed);
      referer = origin + u.pathname;
    } catch (_) {
      referer = path ? origin + '/embed/' + path : origin + '/';
    }
  } else {
    referer = path ? origin + '/embed/' + path : origin + '/';
  }
  return { Referer: referer, Origin: origin, 'User-Agent': ua() };
}

async function postEmbedIndiaFetch(ctx, slot, cfg) {
  var origin = slot.origin || embedIndiaOrigin(cfg);
  var gid = String(slot.gid || '');
  var referer =
    origin + '/embed/' + slot.path + (gid ? '?gid=' + encodeURIComponent(gid) : '');
  var body = encodeEmbedIndiaBody(slot.path);
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
  if (!res.ok) throw new Error('embedindia /fetch ' + res.status);
  var island =
    res.headers && (res.headers.get ? res.headers.get('island') : res.headers['island']);
  if (!island) throw new Error('missing island header');
  var buf = await arrayBuffer(res);
  return { bodyHex: bytesToHex(buf), island: String(island) };
}

function epiEmbedsReferer(embedUrl) {
  try {
    return new URL(String(embedUrl || '').trim()).origin + '/';
  } catch (_) {
    return 'https://epiembeds.online/';
  }
}

async function resolveEpiEmbeds(ctx, embedUrl, cfg) {
  var raw = String(embedUrl || '').trim();
  if (!raw || !isEpiEmbedsUrl(raw)) return null;
  if (ctx.live && typeof ctx.live.sniffEmbed === 'function') {
    var ref = epiEmbedsReferer(raw);
    var m3u8 = await ctx.live.sniffEmbed(raw, ref);
    if (m3u8) {
      var origin = ref.replace(/\/$/, '');
      return [
        {
          url: m3u8,
          headers: { Referer: raw, Origin: origin, 'User-Agent': ua() },
        },
      ];
    }
  }
  return null;
}

async function resolveEmbedIndia(ctx, embedUrl, cfg) {
  if (isEpiEmbedsUrl(embedUrl)) return resolveEpiEmbeds(ctx, embedUrl, cfg);
  var slot = parseEmbedIndiaUrl(embedUrl);
  if (!slot) return null;
  var fetched = await postEmbedIndiaFetch(ctx, slot, cfg);
  var m3u8 = '';
  if (ctx.live && typeof ctx.live.gasmUnlock === 'function') {
    m3u8 = await ctx.live.gasmUnlock(fetched.bodyHex, fetched.island, slot);
  }
  if (!m3u8) return null;
  return [
    {
      url: m3u8,
      headers: playbackHeadersForEmbedIndia(slot, embedUrl),
    },
  ];
}
