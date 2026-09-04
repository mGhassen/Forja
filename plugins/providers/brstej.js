var SPECS = {
  origin: 'https://uo.brstej.com',
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
  // Foreign provider prefixes are not Brstej vids.
  if (raw.indexOf('larozaa:') === 0 || raw.indexOf('dimatoon:') === 0) {
    return '';
  }
  return raw;
}

function pushEmbed(items, seen, embedUrl, referer, name) {
  embedUrl = String(embedUrl || '').trim();
  if (!embedUrl || seen[embedUrl]) return;
  seen[embedUrl] = true;
  items.push({
    embedUrl: embedUrl,
    referer: referer,
    name: name || 'Server ' + (items.length + 1),
  });
}

function collectBrstejServers($, rawHtml, referer) {
  var items = [];
  var seen = {};
  if ($) {
    $('button[data-embed-url], .watchButton[data-embed-url]').each(function () {
      var b = $(this);
      var embed = b.attr('data-embed-url') || '';
      if (!embed) return;
      var name = (b.text() || '').trim();
      pushEmbed(items, seen, embed, referer, name);
    });
    if (!items.length) {
      var iframe = $('iframe[src]').first();
      var src = iframe.length ? iframe.attr('src') || '' : '';
      if (src) pushEmbed(items, seen, src, referer, 'Server 1');
    }
  }
  if (!items.length && rawHtml) {
    var re = /data-embed-url\s*=\s*["']([^"']+)["']/gi;
    var m;
    while ((m = re.exec(rawHtml))) {
      pushEmbed(items, seen, m[1], referer, 'Server ' + (items.length + 1));
    }
  }
  return items;
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
      // Prefer final host after hd1 → uo redirects.
      try {
        var finalUrl = String(res.url || url);
        var o = new URL(finalUrl);
        if (o.protocol && o.host) {
          base = o.protocol + '//' + o.host;
          referer = base + '/watch.php?vid=' + encodeURIComponent(vid);
        }
      } catch (e) {}
      return res.text();
    })
    .then(function (body) {
      var $ = html(ctx, body);
      var servers = collectBrstejServers($, body, referer);
      return arabicResolveEmbeds(ctx, servers, function (msg) {
        ctx.log('brstej: ' + msg);
      });
    })
    .catch(function (e) {
      ctx.log('brstej extract error: ' + (e && e.message ? e.message : e));
      return [];
    });
}
