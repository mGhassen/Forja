// Shared Larozaa / Brstej embed-page → direct stream extraction (provider prelude).
// Mirrors CloudStream Brstej loadLinks: PACKER unpack, JW/file regex, no embed URLs to host.

var ARABIC_STREAM_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

function arabicStreamHeaders(referer, pageUrl) {
  var h = {
    'User-Agent': ARABIC_STREAM_UA,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  var ref = referer || pageUrl || '';
  if (ref) h.Referer = ref;
  try {
    var u = new URL(String(pageUrl || referer || ''));
    h.Origin = u.protocol + '//' + u.host;
  } catch (e) {}
  return h;
}

function arabicAbsoluteUrl(href, base) {
  href = String(href || '').trim();
  if (!href) return '';
  if (href.indexOf('http://') === 0 || href.indexOf('https://') === 0) return href;
  base = String(base || '').replace(/\/$/, '');
  if (href.indexOf('//') === 0) return 'https:' + href;
  if (href.indexOf('/') === 0) return base + href;
  return base + '/' + href;
}

function arabicUnpackPacker(p, a, c, keywords) {
  var kw = String(keywords || '').split('|');
  var chars =
    '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  function toBase(n, radix) {
    if (n === 0) return '0';
    var buf = '';
    var val = n;
    while (val > 0) {
      buf = chars[val % radix] + buf;
      val = Math.floor(val / radix);
    }
    return buf;
  }

  var result = String(p || '');
  for (var i = c - 1; i >= 0; i--) {
    if (i < kw.length && kw[i]) {
      var token = toBase(i, a);
      result = result.replace(new RegExp('\\b' + token + '\\b', 'g'), kw[i]);
    }
  }
  return result;
}

function arabicFindVideoUrl(text) {
  if (!text) return '';
  var patterns = [
    /file\s*:\s*"(https?:\/\/[^"]+\.(?:m3u8|mp4)[^"]*)"/,
    /['"](https?:\/\/[^\s'"]+\.(?:m3u8|mp4)[^\s'"]*)['"]/,
    /(https?:\/\/[^\s'"]+\.(?:m3u8|mp4)[^\s'"]*)/,
  ];
  for (var i = 0; i < patterns.length; i++) {
    var m = patterns[i].exec(text);
    if (m && m[1]) return m[1];
  }
  return '';
}

function arabicExtractFromEmbedHtml(html) {
  var direct = arabicFindVideoUrl(html);
  if (direct) return direct;

  var packed = /eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?\}\('(.+)',(\d+),(\d+),'(.+?)'\.split\('\|'\)/.exec(
    html,
  );
  if (packed) {
    var unpacked = arabicUnpackPacker(
      packed[1],
      parseInt(packed[2], 10),
      parseInt(packed[3], 10),
      packed[4],
    );
    var fromPacked = arabicFindVideoUrl(unpacked);
    if (fromPacked) return fromPacked;
  }

  var evalMatch = /eval\((function\s*\([\s\S]*)\)\)/.exec(html);
  if (evalMatch) {
    try {
      var match2 = evalMatch[1].match(
        /}\((['"])([\s\S]*?)\1,\s*(\d+),\s*(\d+),\s*(['"])([\s\S]*?)\5\.split\((['"])\|\7\)/,
      );
      if (match2) {
        var p2 = match2[2]
          .replace(/\\'/g, "'")
          .replace(/\\"/g, '"')
          .replace(/\\\\/g, '\\');
        var unpacked2 = arabicUnpackPacker(
          p2,
          parseInt(match2[3], 10),
          parseInt(match2[4], 10),
          match2[6],
        );
        var fromEval = arabicFindVideoUrl(unpacked2);
        if (fromEval) return fromEval;
      }
    } catch (e) {}
  }

  return '';
}

function arabicStreamType(url) {
  var u = String(url || '').toLowerCase();
  if (u.indexOf('.m3u8') >= 0) return 'hls';
  if (u.indexOf('.mpd') >= 0) return 'dash';
  return 'mp4';
}

function arabicDirectRow(url, name, referer) {
  return {
    url: url,
    name: name,
    title: name,
    type: arabicStreamType(url),
    headers: arabicStreamHeaders(referer, referer),
  };
}

function arabicResolveEmbed(ctx, embedUrl, referer, serverName) {
  var abs = arabicAbsoluteUrl(embedUrl, referer);
  if (!abs) return Promise.resolve(null);
  return ctx
    .fetch(abs, { headers: arabicStreamHeaders(referer, abs) })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.text();
    })
    .then(function (body) {
      var direct = arabicExtractFromEmbedHtml(body);
      if (!direct) return null;
      return arabicDirectRow(direct, serverName || 'Server', abs);
    })
    .catch(function () {
      return null;
    });
}

function arabicResolveEmbeds(ctx, items, logFn) {
  if (!items || !items.length) return Promise.resolve([]);
  return Promise.all(
    items.map(function (item) {
      return arabicResolveEmbed(ctx, item.embedUrl, item.referer, item.name);
    }),
  ).then(function (rows) {
    var out = [];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i]) out.push(rows[i]);
    }
    if (logFn && !out.length) {
      logFn('no direct streams from ' + items.length + ' server(s)');
    }
    return out;
  });
}
