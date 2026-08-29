var SPECS = {
  bootstrap: 'https://larozaa.bond',
  mirrors: [
    'https://larozaa.bond',
    'https://larozaa.home',
    'https://larozaa.homes',
    'https://larozaa.com',
    'https://laaroza.pics',
  ],
};

var UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

function headers(referer) {
  var h = {
    'User-Agent': UA,
    Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.9',
  };
  if (referer) h.Referer = referer;
  return h;
}

function origin(url) {
  try {
    var u = new URL(String(url || ''));
    return u.protocol + '//' + u.host;
  } catch (e) {
    return '';
  }
}

function isLarozaHost(host) {
  return /la+r+o+z+a/i.test(String(host || ''));
}

function html(ctx, raw) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(raw);
  } catch (e) {
    return null;
  }
}

function resolveBase(ctx, cfg) {
  var boots = [cfg.bootstrap]
    .concat(Array.isArray(cfg.mirrors) ? cfg.mirrors : [])
    .map(function (b) {
      return String(b || '').replace(/\/$/, '');
    })
    .filter(Boolean);
  var seen = {};
  var ordered = [];
  for (var i = 0; i < boots.length; i++) {
    if (seen[boots[i]]) continue;
    seen[boots[i]] = true;
    ordered.push(boots[i]);
  }

  function attempt(index) {
    if (index >= ordered.length) {
      return Promise.resolve(ordered[0] || 'https://larozaa.bond');
    }
    var boot = ordered[index];
    return ctx
      .fetch(boot, { headers: headers(boot + '/') })
      .then(function (res) {
        var o = origin(res.url || boot);
        var host = '';
        try {
          host = new URL(o).host;
        } catch (e) {}
        if (o && isLarozaHost(host)) return o;
        return attempt(index + 1);
      })
      .catch(function () {
        return attempt(index + 1);
      });
  }

  return attempt(0);
}

function fetchHtml(ctx, url, referer) {
  return ctx
    .fetch(url, { headers: headers(referer || origin(url) + '/') })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.text().then(function (body) {
        return { html: body, url: res.url || url };
      });
    });
}

function parseVideoId(raw) {
  raw = String(raw || '').trim();
  if (raw.indexOf('larozaa:') === 0) return raw.substring(8);
  return raw;
}

function embedRow(embedUrl, name, referer) {
  return {
    url: embedUrl,
    name: name,
    title: name,
    type: 'arabic_embed',
    headers: headers(referer),
  };
}

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var videoId = parseVideoId(cfg.videoId || '');
  if (!videoId) {
    ctx.log('larozaa: missing videoId');
    return Promise.resolve([]);
  }

  return resolveBase(ctx, cfg)
    .then(function (base) {
      var playUrl = base + '/play.php?vid=' + encodeURIComponent(videoId);
      var playReferer = base + '/';
      return fetchHtml(ctx, playUrl, playReferer).then(function (got) {
        var $ = html(ctx, got.html);
        var rows = [];
        if ($) {
          $('.WatchList li').each(function () {
            var item = $(this);
            var embedUrl = item.attr('data-embed-url') || '';
            if (!embedUrl) return;
            var name = (item.text() || '').trim();
            rows.push(
              embedRow(
                embedUrl,
                name || 'Server ' + (rows.length + 1),
                playUrl,
              ),
            );
          });
          if (!rows.length) {
            var iframe = $('iframe[src]').first();
            var src = iframe.length ? iframe.attr('src') || '' : '';
            if (src) {
              rows.push(embedRow(src, 'Server 1', playUrl));
            }
          }
        }
        return rows;
      });
    })
    .catch(function (e) {
      ctx.log('larozaa extract error: ' + (e && e.message ? e.message : e));
      return [];
    });
}
