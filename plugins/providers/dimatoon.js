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
  if (raw.indexOf('dimatoon:') === 0) return raw.substring(9);
  return raw;
}

function extract(ctx) {
  var cfg = Object.assign({}, SPECS, ctx.config || {});
  var base = String(cfg.origin || cfg.dimatoon || SPECS.origin).replace(/\/$/, '');
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
      var $ = html(ctx, body);
      var src = '';
      if ($) {
        var source = $('source[src]').first();
        if (source.length) src = source.attr('src') || '';
      }
      if (!src) {
        var m = /https?:\/\/[^"\s]+\.mp4[^"\s]*/.exec(body);
        if (m) src = m[0];
      }
      if (!src) return [];
      return [
        {
          url: src,
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
