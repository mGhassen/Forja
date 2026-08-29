var SPECS = {
  origin: 'https://hd1.brstej.com',
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

function parseVid(raw) {
  raw = String(raw || '').trim();
  if (raw.indexOf('brstej:') === 0) raw = raw.substring(7);
  if (raw.indexOf('watch:') === 0) return raw.substring(6);
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
  var base = String(cfg.origin || cfg.brstej || SPECS.origin).replace(/\/$/, '');
  var vid = parseVid(cfg.videoId || '');
  if (!vid) {
    ctx.log('brstej: missing videoId');
    return Promise.resolve([]);
  }

  var url = base + '/play.php?vid=' + encodeURIComponent(vid);
  var referer = base + '/watch.php?vid=' + encodeURIComponent(vid);

  return ctx
    .fetch(url, { headers: headers(referer) })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.text();
    })
    .then(function (body) {
      var $ = html(ctx, body);
      var rows = [];
      if ($) {
        $('button[data-embed-url]').each(function () {
          var b = $(this);
          var embed = b.attr('data-embed-url') || '';
          if (!embed) return;
          var name = (b.text() || '').trim();
          rows.push(
            embedRow(embed, name || 'Server ' + (rows.length + 1), referer),
          );
        });
        if (!rows.length) {
          var iframe = $('iframe[src]').first();
          var src = iframe.length ? iframe.attr('src') || '' : '';
          if (src) {
            rows.push(embedRow(src, 'Server 1', referer));
          }
        }
      }
      return rows;
    })
    .catch(function (e) {
      ctx.log('brstej extract error: ' + (e && e.message ? e.message : e));
      return [];
    });
}
