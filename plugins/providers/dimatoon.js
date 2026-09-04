var SPECS = {
  origin: 'https://www.dima-toon.com',
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

function html(ctx, raw) {
  if (!ctx || typeof ctx.html !== 'function') return null;
  try {
    return ctx.html(raw);
  } catch (e) {
    return null;
  }
}

function parseEpisodeUrl(raw) {
  raw = String(raw || '').trim();
  if (raw.indexOf('dimatoon:') === 0) raw = raw.substring(9);
  return raw.trim();
}

function isBlankMp4(url) {
  var u = String(url || '').toLowerCase();
  if (!u) return true;
  if (u.indexOf('blank.mp4') >= 0) return true;
  if (u.indexOf('easy-video-player') >= 0 && u.indexOf('blank') >= 0) {
    return true;
  }
  return false;
}

function pushMp4(out, seen, url) {
  url = String(url || '').trim();
  if (!url || isBlankMp4(url) || seen[url]) return;
  if (!/^https?:\/\//i.test(url)) return;
  if (!/\.mp4(\?|#|$)/i.test(url) && url.indexOf('word.tn') < 0) return;
  seen[url] = true;
  out.push(url);
}

function collectMp4FromHtml(ctx, body) {
  var out = [];
  var seen = {};
  var $ = html(ctx, body);
  if ($) {
    $('video source[src], source[src], video[src]').each(function () {
      var el = $(this);
      pushMp4(out, seen, el.attr('src') || '');
    });
  }
  if (!out.length && body) {
    var re = /https?:\/\/[^"'\\\s<>]+\.mp4[^"'\\\s<>]*/gi;
    var m;
    while ((m = re.exec(body))) {
      pushMp4(out, seen, m[0].replace(/&amp;/g, '&'));
    }
  }
  return out;
}

function episodeSlug(url) {
  try {
    var u = new URL(String(url || ''));
    var parts = u.pathname.split('/').filter(Boolean);
    if (!parts.length) return '';
    var last = parts[parts.length - 1];
    try {
      return decodeURIComponent(last);
    } catch (e) {
      return last;
    }
  } catch (e) {
    return '';
  }
}

function extractFromWpContent(ctx, base, episodeUrl) {
  var slug = episodeSlug(episodeUrl);
  if (!slug) return Promise.resolve([]);
  var api =
    base +
    '/wp-json/wp/v2/cartoon-episode?slug=' +
    encodeURIComponent(slug) +
    '&_fields=content';
  return ctx
    .fetch(api, { headers: headers(base + '/') })
    .then(function (res) {
      if (!res.ok) return [];
      return res.json();
    })
    .then(function (rows) {
      if (!rows || !rows.length) return [];
      var content =
        (rows[0].content && rows[0].content.rendered) ||
        rows[0].content ||
        '';
      return collectMp4FromHtml(ctx, String(content || ''));
    })
    .catch(function () {
      return [];
    });
}

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = String(cfg.origin || cfg.dimatoon || SPECS.origin).replace(
    /\/$/,
    '',
  );
  var episodeUrl = parseEpisodeUrl(cfg.videoId || '');
  if (!episodeUrl || episodeUrl.indexOf('http') !== 0) {
    ctx.log('dimatoon: missing episode url');
    return Promise.resolve([]);
  }

  return ctx
    .fetch(episodeUrl, { headers: headers(base + '/') })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.text();
    })
    .then(function (body) {
      var urls = collectMp4FromHtml(ctx, body);
      if (urls.length) return urls;
      return extractFromWpContent(ctx, base, episodeUrl);
    })
    .then(function (urls) {
      if (!urls || !urls.length) return [];
      return [
        {
          url: urls[0],
          name: 'DimaToon',
          title: 'DimaToon',
          quality: '720p',
          headers: headers(episodeUrl),
        },
      ];
    })
    .catch(function (e) {
      ctx.log('dimatoon extract error: ' + (e && e.message ? e.message : e));
      return [];
    });
}
