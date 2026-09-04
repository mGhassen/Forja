var SPECS = {
  origin: 'https://www.dimakids.com',
};

var UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

function headers(referer) {
  var h = {
    'User-Agent': UA,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) {
    h.Referer = referer;
    try {
      h.Origin = new URL(referer).origin;
    } catch (e) {}
  }
  return h;
}

function parsePageUrl(raw) {
  raw = String(raw || '').trim();
  if (raw.indexOf('dimakids:') === 0) raw = raw.substring(9);
  return raw.trim();
}

function collectMp4(body) {
  var out = [];
  var seen = {};
  function push(url) {
    url = String(url || '')
      .trim()
      .replace(/&amp;/g, '&');
    if (!url || seen[url]) return;
    if (!/^https?:\/\//i.test(url)) return;
    if (!/\.mp4(\?|#|$)/i.test(url)) return;
    seen[url] = true;
    out.push(url);
  }
  var m = /const\s+videoSrc\s*=\s*["']([^"']+)["']/.exec(String(body || ''));
  if (m) push(m[1]);
  var re = /https?:\/\/[^"'\\\s<>]+\.mp4[^"'\\\s<>]*/gi;
  var hit;
  while ((hit = re.exec(String(body || '')))) {
    push(hit[0]);
  }
  return out;
}

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = String(cfg.origin || cfg.dimakids || SPECS.origin).replace(
    /\/$/,
    '',
  );
  var pageUrl = parsePageUrl(cfg.videoId || '');
  if (!pageUrl || pageUrl.indexOf('http') !== 0) {
    ctx.log('dimakids: missing page url');
    return Promise.resolve([]);
  }

  return ctx
    .fetch(pageUrl, { headers: headers(base + '/') })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.text();
    })
    .then(function (body) {
      var urls = collectMp4(body);
      if (!urls.length) return [];
      return [
        {
          url: urls[0],
          name: 'Dimakids',
          title: 'Dimakids',
          quality: '720p',
          headers: headers(pageUrl),
        },
      ];
    })
    .catch(function (e) {
      ctx.log('dimakids extract error: ' + (e && e.message ? e.message : e));
      return [];
    });
}
