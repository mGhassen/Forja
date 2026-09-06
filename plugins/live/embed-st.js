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
  if (host.indexOf('wfty.st') >= 0) return false;
  // Public S3 (Foorja etc.) — MediaKit mbedtls often RST on long direct sessions.
  if (host.indexOf('amazonaws.com') >= 0) return false;
  if (host.indexOf('indianservers.st') >= 0) return true;
  if (host.indexOf('strmd.st') >= 0 && path.indexOf('/streamfree/stream/') >= 0) {
    return true;
  }
  if (
    host.indexOf('streamfree.top') >= 0 &&
    (path.indexOf('/live/') >= 0 ||
      path.indexOf('/live-cdn/') >= 0 ||
      path.indexOf('/live-origin/') >= 0)
  ) {
    return true;
  }
  return (
    path.indexOf('/delta/stream/') >= 0 ||
    path.indexOf('/echo/stream/') >= 0 ||
    path.indexOf('/streamed/stream/') >= 0
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
  if (!m3u8 && ctx.live && typeof ctx.live.sniffEmbed === 'function') {
    m3u8 = await ctx.live.sniffEmbed(embedUrl, embedUrl);
  }
  if (!m3u8) return null;
  return [
    {
      url: m3u8,
      headers: playbackHeadersForEmbedIndia(slot, embedUrl),
    },
  ];
}

function isDaddyLiveHost(host) {
  var h = String(host || '').toLowerCase();
  if (!h) return false;
  return (
    h === 'dlhd.pk' ||
    h.endsWith('.dlhd.pk') ||
    h === 'dlive.sx' ||
    h.endsWith('.dlive.sx') ||
    h === 'dlhd.sx' ||
    h.endsWith('.dlhd.sx') ||
    h === 'thedaddy.to' ||
    h.endsWith('.thedaddy.to') ||
    h === 'lovecdn.ru' ||
    h.endsWith('.lovecdn.ru') ||
    h === 'lovetier.bz' ||
    h.endsWith('.lovetier.bz')
  );
}

function isDaddyLiveUrl(url) {
  try {
    var u = new URL(String(url || '').trim());
    if (!isDaddyLiveHost(u.host)) return false;
    var path = u.pathname.toLowerCase();
    return (
      path.indexOf('/stream/stream-') >= 0 ||
      path.indexOf('/daddy.php') >= 0 ||
      path.indexOf('/premiumtv/') >= 0 ||
      path.indexOf('/watch.php') >= 0
    );
  } catch (_) {
    return false;
  }
}

function m3u8FromDaddyHtml(html) {
  var body = String(html || '');
  if (!body) return '';
  // Clappr: source:window.atob('…base64 m3u8…')
  var atobM = body.match(/window\.atob\(\s*['"]([A-Za-z0-9+/=]+)['"]\s*\)/i);
  if (atobM) {
    try {
      var decoded = atob(atobM[1]);
      if (/\.m3u8/i.test(decoded)) return decoded.trim();
    } catch (_) {}
  }
  var direct = body.match(/https?:\/\/[^\"'\s<>]+?\.m3u8[^\"'\s<>]*/i);
  if (direct) return direct[0].replace(/&amp;/g, '&');
  return '';
}

function daddyIframeFromHtml(html) {
  var body = String(html || '');
  var m = body.match(
    /iframe[^>]+src=["'](https?:\/\/[^"']+(?:premiumtv\/daddy[^"']*|daddy[^"']*\.php[^"']*))["']/i
  );
  if (m) return m[1].replace(/&amp;/g, '&');
  m = body.match(/iframe[^>]+src=["'](https?:\/\/[^"']+)["']/i);
  return m ? m[1].replace(/&amp;/g, '&') : '';
}

async function fetchDaddyHtml(ctx, url, referer) {
  var res = await ctx.fetch(String(url), {
    headers: {
      'User-Agent': ua(),
      Accept: 'text/html,application/xhtml+xml',
      Referer: referer || 'https://streamic.st/',
    },
  });
  if (!res || !res.ok) return '';
  if (typeof res.text === 'function') {
    try {
      return String(await res.text());
    } catch (_) {}
  }
  return '';
}

async function resolveDaddyLiveEmbed(ctx, embedUrl, cfg) {
  var raw = String(embedUrl || '').trim();
  if (!raw || !isDaddyLiveUrl(raw)) return null;

  var pageReferer = 'https://streamic.st/';
  try {
    pageReferer = new URL(raw).origin + '/';
  } catch (_) {}

  var html = await fetchDaddyHtml(ctx, raw, pageReferer);
  var m3u8 = m3u8FromDaddyHtml(html);
  var playerPage = raw;

  if (!m3u8) {
    var iframe = daddyIframeFromHtml(html);
    if (iframe) {
      playerPage = iframe;
      var iframeHtml = await fetchDaddyHtml(ctx, iframe, raw);
      m3u8 = m3u8FromDaddyHtml(iframeHtml);
    }
  }
  if (!m3u8) return null;

  var origin = '';
  try {
    origin = new URL(playerPage).origin;
  } catch (_) {
    origin = pageReferer.replace(/\/$/, '');
  }
  return [
    {
      url: m3u8,
      headers: {
        Referer: playerPage,
        Origin: origin,
        'User-Agent': ua(),
      },
      directPlayback: preferDirectPlayback(m3u8),
    },
  ];
}


/* ── Nest unlock (AlbaPlayer / tirfoot / OK.ru / Livepeer / S3) ───────────
 * Shared by live plugins that walk iframe trees to native HLS only.
 * Sites swap CDNs often — add a leaf helper, don't hardcode one host.
 */

function nestUa() {
  return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
}

function nestUniq(urls) {
  var out = [];
  var seen = {};
  for (var i = 0; i < urls.length; i++) {
    var u = String(urls[i] || '').trim();
    if (!u || seen[u]) continue;
    seen[u] = 1;
    out.push(u);
  }
  return out;
}

function nestHtmlUnescape(s) {
  return String(s || '')
    .replace(/&quot;/gi, '"')
    .replace(/&#34;/g, '"')
    .replace(/&amp;/gi, '&')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

function nestIsCleanPlayUrl(url) {
  var u = String(url || '').trim();
  if (!/^https?:\/\//i.test(u)) return false;
  if (/&quot;|&amp;|"|'/i.test(u)) return false;
  // Fake AWS regions (NXDOMAIN) — never open.
  if (/\.s3\.us-north-\d+\.amazonaws\.com/i.test(u)) return false;
  return true;
}

function nestHost(url) {
  try {
    return new URL(String(url || '')).host.toLowerCase();
  } catch (_) {
    return '';
  }
}

function nestIsAmazonS3Url(url) {
  return nestHost(url).indexOf('amazonaws.com') >= 0;
}

function nestIsOkCdUrl(url) {
  var h = nestHost(url);
  return (
    h.indexOf('okcdn.ru') >= 0 ||
    h.indexOf('vkuser.net') >= 0 ||
    h.indexOf('ok.ru') >= 0
  );
}

function nestIsBrightcoveUrl(url) {
  return nestHost(url).indexOf('brightcove') >= 0;
}

/** Bunny/Livepeer edge 307 — MediaKit often won't follow. */
function nestCanonicalizePlayUrl(url) {
  var raw = String(url || '').trim();
  if (!raw) return '';
  try {
    var u = new URL(raw);
    var host = u.host.toLowerCase();
    if (host === 'livepeercdn.studio' || host === 'cdn.livepeer.com') {
      u.host = 'playback.livepeer.studio';
      return u.href;
    }
  } catch (_) {}
  return raw;
}

function nestAcceptPlayUrl(url) {
  var playUrl = nestCanonicalizePlayUrl(url);
  if (!nestIsCleanPlayUrl(playUrl)) return '';
  return playUrl;
}

function nestExtractOkRuHls(html) {
  var text = nestHtmlUnescape(html);
  var out = [];
  var keys = ['hlsMasterPlaylistUrl', 'hlsPlaybackMasterPlaylistUrl'];
  for (var i = 0; i < keys.length; i++) {
    var re = new RegExp('"' + keys[i] + '"\\s*:\\s*"([^"]+)"', 'gi');
    var m;
    while ((m = re.exec(text))) {
      var url = String(m[1] || '').trim();
      if (nestIsCleanPlayUrl(url)) out.push(url);
    }
  }
  return nestUniq(out);
}

function nestExtractM3u8(html) {
  var out = nestExtractOkRuHls(html);
  var text = nestHtmlUnescape(html);
  var re = /https?:\/\/[^\s"'<>\\]+?\.m3u8[^\s"'<>\\]*/gi;
  var m;
  while ((m = re.exec(text))) {
    var url = m[0].replace(/\\+$/, '').replace(/&amp;/g, '&');
    if (nestIsCleanPlayUrl(url)) out.push(url);
  }
  var srcRe = /(?:source|file|src)\s*[:=]\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/gi;
  while ((m = srcRe.exec(text))) {
    if (nestIsCleanPlayUrl(m[1])) out.push(m[1]);
  }
  return nestUniq(out);
}

function nestExtractIframeSrcs(html) {
  var out = [];
  var re = /<iframe\b[^>]*\bsrc=["']([^"']+)["']/gi;
  var m;
  while ((m = re.exec(String(html || '')))) {
    var src = String(m[1] || '').trim();
    if (src) out.push(src);
  }
  return nestUniq(out);
}

function nestNestedEmbedUrls(html, baseUrl) {
  var out = [];
  var iframes = nestExtractIframeSrcs(html);
  for (var i = 0; i < iframes.length; i++) {
    var src = String(iframes[i] || '').trim();
    if (!src || /^javascript:/i.test(src)) continue;
    // playerv5 injects "+q+u+q+" — no scheme/path markers; skip before resolve
    // or it becomes https://host/+q+u+q+ and looks like a real URL.
    if (!/[:/.]/.test(src)) continue;
    if (
      /acscdn|doubleclick|googlesyndication|pagead2|adservice|\.js($|\?)|\.css($|\?)/i.test(
        src,
      )
    ) {
      continue;
    }
    var abs = src;
    try {
      abs = new URL(src, baseUrl).href;
    } catch (_) {
      continue;
    }
    if (!/^https?:\/\//i.test(abs)) continue;
    try {
      var nestU = new URL(abs);
      if (!nestU.hostname || nestU.hostname.indexOf('.') < 0) continue;
      if (/^\/*(\+[A-Za-z0-9]*)+$/.test(nestU.pathname)) continue;
    } catch (_) {
      continue;
    }
    out.push(abs);
  }
  return nestUniq(out);
}

function nestExtractServPages(playerHtml, baseUrl) {
  var out = [baseUrl];
  var re = /href=["']([^"']+\?serv=\d+)["']/gi;
  var m;
  while ((m = re.exec(String(playerHtml || '')))) {
    var href = String(m[1] || '').trim();
    if (!href) continue;
    try {
      out.push(new URL(href, baseUrl).href);
    } catch (_) {
      out.push(href);
    }
  }
  return nestUniq(out);
}

function nestServLabel(url, html) {
  try {
    var u = new URL(url);
    var serv = u.searchParams.get('serv');
    if (serv) {
      var re = new RegExp(
        'href=["\'][^"\']*\\?serv=' + serv + '["\'][^>]*>([\\s\\S]*?)<\\/a>',
        'i',
      );
      var m = String(html || '').match(re);
      if (m) {
        var label = String(m[1] || '')
          .replace(/<[^>]+>/g, ' ')
          .replace(/\s+/g, ' ')
          .trim();
        if (label) return label;
      }
      return 'Server ' + serv;
    }
  } catch (_) {}
  var active = String(html || '').match(
    /class=["'][^"']*aplr-link[^"']*active[^"']*["'][^>]*>([\s\S]*?)<\/a>/i,
  );
  if (active) {
    var activeLabel = String(active[1] || '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (activeLabel) return activeLabel;
  }
  return 'Server';
}

async function nestFetchHtml(ctx, url, referer) {
  var headers = {
    'User-Agent': nestUa(),
    Accept: 'text/html,application/xhtml+xml',
  };
  if (referer) headers.Referer = referer;
  try {
    var res = await ctx.fetch(url, { headers: headers });
    if (!res || !res.ok) return '';
    return await res.text();
  } catch (_) {
    return '';
  }
}

function nestPlaybackHeaders(playUrl, playerPageUrl) {
  if (nestIsBrightcoveUrl(playUrl) || nestIsAmazonS3Url(playUrl)) {
    return { 'User-Agent': nestUa() };
  }
  if (nestIsOkCdUrl(playUrl)) {
    return {
      Referer: 'https://ok.ru/',
      Origin: 'https://ok.ru',
      'User-Agent': nestUa(),
    };
  }
  var origin = '';
  try {
    origin = new URL(playerPageUrl || playUrl).origin;
  } catch (_) {}
  return {
    Referer: playerPageUrl || origin + '/',
    Origin: origin || 'https://25.streemach.fun',
    'User-Agent': nestUa(),
  };
}

function nestPlayRow(url, name, playerPageUrl) {
  var playUrl = nestCanonicalizePlayUrl(url);
  return {
    url: playUrl,
    name: name || 'Live',
    headers: nestPlaybackHeaders(playUrl, playerPageUrl),
    // S3: hls-proxy (mbedtls RST). OK.ru / Livepeer / others: direct + headers.
    directPlayback: !nestIsAmazonS3Url(playUrl),
  };
}

async function nestUnlockPlayerPage(
  ctx,
  playerUrl,
  channelReferer,
  depth,
  seenPages,
  brand,
) {
  depth = depth || 0;
  brand = brand || 'Live';
  if (depth > 4) return [];
  seenPages = seenPages || {};
  var key = String(playerUrl || '').trim();
  if (!key || seenPages[key]) return [];
  seenPages[key] = 1;

  var html = await nestFetchHtml(ctx, playerUrl, channelReferer || playerUrl);
  if (!html) return [];

  var pages = nestExtractServPages(html, playerUrl);
  var out = [];
  var seen = {};

  for (var i = 0; i < pages.length; i++) {
    var pageUrl = pages[i];
    var pageHtml =
      pageUrl === playerUrl
        ? html
        : await nestFetchHtml(ctx, pageUrl, playerUrl);
    if (!pageHtml) continue;
    seenPages[pageUrl] = 1;

    var m3u8s = nestExtractM3u8(pageHtml);
    var label = nestServLabel(pageUrl, pageHtml);
    for (var j = 0; j < m3u8s.length; j++) {
      var accepted = nestAcceptPlayUrl(m3u8s[j]);
      if (!accepted || seen[accepted]) continue;
      seen[accepted] = 1;
      out.push(nestPlayRow(accepted, brand + ' · ' + label, pageUrl));
    }

    // Nest leaves per page (Alba → tirfoot → ok.ru / Livepeer / S3).
    // Walk every ?serv= tab even if an earlier tab already unlocked HLS.
    if (!m3u8s.length && depth < 4) {
      var nested = nestNestedEmbedUrls(pageHtml, pageUrl);
      for (var k = 0; k < nested.length; k++) {
        var nestUrl = nested[k];
        if (seenPages[nestUrl]) continue;
        var nestRows = await nestUnlockPlayerPage(
          ctx,
          nestUrl,
          pageUrl,
          depth + 1,
          seenPages,
          brand,
        );
        for (var n = 0; n < nestRows.length; n++) {
          var row = nestRows[n];
          if (!row || !row.url || seen[row.url]) continue;
          seen[row.url] = 1;
          if (row.name && row.name.indexOf(label) < 0) {
            row.name =
              brand +
              ' · ' +
              label +
              ' · ' +
              String(row.name || '').replace(
                new RegExp('^' + brand.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ' · '),
                '',
              );
          }
          out.push(row);
        }
      }
    }
  }
  return out;
}

/**
 * Walk a channel / player URL to native HLS rows.
 * @param {object} ctx engine fetch context
 * @param {string} channelUrl page or direct media URL
 * @param {{ brand?: string, originReferer?: string }} opts
 */
async function nestUnlockChannel(ctx, channelUrl, opts) {
  opts = opts || {};
  var brand = opts.brand || 'Live';
  var originReferer = opts.originReferer || '';
  var raw = String(channelUrl || '').trim();
  if (!raw) return [];

  if (/\.m3u8|\.mp4/i.test(raw)) {
    if (/\.mp4/i.test(raw) && !/\.m3u8/i.test(raw)) {
      return [nestPlayRow(raw, brand, raw)];
    }
    var ready = nestAcceptPlayUrl(raw);
    return ready ? [nestPlayRow(ready, brand, raw)] : [];
  }

  if (/ok\.ru\/videoembed\//i.test(raw)) {
    var okHtml = await nestFetchHtml(ctx, raw, 'https://ok.ru/');
    if (!okHtml) return [];
    var okUrls = nestExtractM3u8(okHtml);
    var okOut = [];
    for (var oi = 0; oi < okUrls.length; oi++) {
      var okReady = nestAcceptPlayUrl(okUrls[oi]);
      if (!okReady) continue;
      okOut.push(nestPlayRow(okReady, brand + ' · OK', raw));
    }
    return okOut;
  }

  if (/albaplayer/i.test(raw)) {
    return nestUnlockPlayerPage(ctx, raw, raw, 0, {}, brand);
  }

  var pageRef = originReferer;
  if (!pageRef) {
    var host = nestHost(raw);
    pageRef = host ? 'https://' + host + '/' : raw;
  }
  var html = await nestFetchHtml(ctx, raw, pageRef);
  if (!html) return [];

  var direct = nestExtractM3u8(html);
  if (direct.length) {
    var rows = [];
    var seenDirect = {};
    for (var d = 0; d < direct.length; d++) {
      var accepted = nestAcceptPlayUrl(direct[d]);
      if (!accepted || seenDirect[accepted]) continue;
      seenDirect[accepted] = 1;
      rows.push(nestPlayRow(accepted, brand, raw));
    }
    if (rows.length) return rows;
  }

  var iframes = nestExtractIframeSrcs(html).filter(function (src) {
    return /albaplayer|streemach|player|ok\.ru\/videoembed/i.test(src);
  });
  if (!iframes.length) return [];

  var out = [];
  var seen = {};
  for (var i = 0; i < iframes.length; i++) {
    var nestRows = [];
    try {
      nestRows = await nestUnlockPlayerPage(
        ctx,
        iframes[i],
        raw,
        0,
        {},
        brand,
      );
    } catch (_) {
      nestRows = [];
    }
    for (var j = 0; j < nestRows.length; j++) {
      var row = nestRows[j];
      if (!row || !row.url || seen[row.url]) continue;
      seen[row.url] = 1;
      out.push(row);
    }
  }
  return out;
}
